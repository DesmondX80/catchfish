shader_type spatial;
// Humuspitoinen, ruskehtava järvivesi. Aallokko tulee yhteisestä aaltomallista
// (waves.gdshaderinc): Gerstner-aallot, joiden koko riippuu tuulesta ja
// pyyhkäisymatkasta. Lisäksi pinnassa on lyhyitä väreitä, jotka seuraavat
// tuulta, ja puuskien tummia värelaikkuja. Jokainen aalto häivytetään, kun se
// on näytöllä pikseliä pienempi – muuten kaukaiset laineet välkkyvät.
// Sama varjostin piirtää kameraa seuraavan tiheän lähiveden (is_near), jonka
// verteksit liikkuvat aaltojen mukana, ja kaukaisen järviverkon, joka on
// tasainen ja jättää lähiveden alueen piirtämättä.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.05, 0.05, 0.03);
uniform vec3 shallow_color : source_color = vec3(0.13, 0.12, 0.07);
uniform vec3 sky_color : source_color = vec3(0.55, 0.65, 0.75);
#include "res://shaders/waves.gdshaderinc"

uniform float rain = 0.0; // sateen voimakkuus: pisararenkaat pinnassa
uniform float ice = 0.0; // talvi: järvi jäässä, lumen peittämä jää
uniform vec3 foam_color : source_color = vec3(0.9, 0.92, 0.92);
// Auringonvalo siroaa humusveden sisällä: aurinkoinen vesi hehkuu ruskeana,
// varjossa ei. Tästä veneen varjo erottuu pinnassa.
uniform vec3 scatter_color : source_color = vec3(0.3, 0.24, 0.13);
uniform float sun_scatter = 0.1;
uniform bool is_near = false; // lähivesi (true) vai kaukainen järviverkko
// Lähivesi piirretään vain järven kohdalle: 1 = vettä (4 m solut)
uniform sampler2D water_mask : filter_linear, repeat_disable;
uniform vec4 mask_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Satunnaisluvut 256 × 256 (kohina ja vaahtopäiden ruutujen arvonta): tekstuurista
// halvemmin kuin laskemalla
uniform sampler2D noise_tex : filter_linear, repeat_enable;
// Väreiden suuntavektorit suuntasarjoittain (lasketaan koodissa)
uniform vec2 ripple_dir_a[12];
uniform vec2 ripple_dir_b[12];

varying vec3 world_pos;
varying vec2 rest_pos; // pinnan kohta ennen aaltojen siirtymää
varying vec4 sea; // paikallinen aallokko: (Hs, L) kummallekin suuntasarjalle
varying vec4 sea_cq; // amplitudikerroin ja terävyys (c, q) kummallekin suuntasarjalle
varying float spec_f0; // pinnan heijastavuus kohtisuoraan (Godotin kaava 0,16 * SPECULAR²)
varying float scatter_weight; // veden sisältä tulevan valon osuus (ei heijastusta eikä vaahtoa)

float rhash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Pisararenkaat: jokaisessa 0,5 m ruudussa satunnainen pisara laajenevine renkaineen
vec2 rain_ripples(vec2 p) {
	const float CELL = 0.5;
	vec2 slope = vec2(0.0);
	vec2 cell = floor(p / CELL);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 c = cell + vec2(float(i), float(j));
			if (rhash(c + 9.1) > rain * 0.9 + 0.05) {
				continue; // heikossa sateessa pisaroita on harvemmassa
			}
			vec2 center = (c + vec2(rhash(c), rhash(c + 17.3))) * CELL;
			float life = fract(wave_time * 1.1 + rhash(c + 5.7));
			vec2 d = p - center;
			float dist = length(d) + 0.0001;
			float x = dist - life * 0.4;
			float ring = exp(-x * x * 900.0) * (1.0 - life);
			slope += d / dist * ring * cos(x * 70.0) * 0.6;
		}
	}
	return slope;
}

// Arvokohina 0–1 (jakso 256): yksi tekstuurinluku, solujen välillä pehmeä käyrä
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return textureLod(noise_tex, (i + f + 0.5) / 256.0, 0.0).r;
}

// Ruudun c satunnaisluku 0–1 (k valitsee eri luvun samalle ruudulle)
float chash(vec2 c, float k) {
	return texelFetch(noise_tex, ivec2(mod(c + vec2(k * 37.0, k * 91.0), 256.0)), 0).r;
}

// Puuskat: tuulen mukana tuulta hitaammin kulkevat kymmenien metrien laikut
// ("kissankäpälät"), joissa väreet ovat tiheämpiä. 0–1.
float gust_patches(vec2 p) {
	if (gust < 0.2) {
		return 0.0;
	}
	vec2 q = (p - gust_offset) / 28.0;
	float n = vnoise(q);
	if (quality == 1) {
		n = n * 0.6 + vnoise(q * 2.0 + 17.0) * 0.28 + vnoise(q * 4.0 + 3.0) * 0.12;
	}
	float cover = smoothstep(0.3, 3.0, gust) * 0.25;
	return smoothstep(0.68 - cover, 0.8 - cover, n) * smoothstep(0.2, 1.2, gust);
}

// Väreet: lyhyitä aaltoja satunnaisiin suuntiin tuulen ympärillä
// (pinta-jännitys mukana nopeudessa). Kerros 1: 6–26 cm, kerros 2: 1–5 cm.
// Voimakkuus vaihtelee laikuittain, joten säännöllistä kuviota ei synny.
const int RIPPLES = 12;
// aallonpituus (m), kulmataajuus (rad/s, pintajännitys mukana), vaihe; suunnat
// suhteessa tuuleen ovat waves.gd:n RIPPLE_OFFSETS
const vec3 RIPPLE_DATA[RIPPLES] = vec3[](
	vec3(0.26, 15.4309, 0.0), vec3(0.19, 18.0855, 2.3), vec3(0.145, 20.7632, 4.1),
	vec3(0.11, 23.9612, 1.2), vec3(0.083, 27.8340, 5.3), vec3(0.064, 32.1421, 3.4),
	vec3(0.049, 37.6024, 0.8), vec3(0.038, 44.2332, 2.9), vec3(0.029, 53.6477, 5.0),
	vec3(0.022, 67.2725, 1.7), vec3(0.017, 85.8016, 3.9), vec3(0.013, 114.4390, 0.4)
);

vec2 ripple_slope(vec2 p, float footprint, int set, float amount) {
	vec2 slope = vec2(0.0);
	// Vain kerrokset, jotka näkyvät tällä etäisyydellä (aallonpituus > 3 pikseliä)
	if (amount <= 0.001 || footprint > 0.26 * 0.3) {
		return slope;
	}
	bool high = quality == 1;
	int count = high && footprint < 0.049 * 0.3 ? RIPPLES : RIPPLES / 2;
	// Väreiden aaltorintamat mutkittelevat: ei säännöllistä ristikkoa
	vec2 q = high ? p + vec2(vnoise(p * 0.8), vnoise(p * 0.8 + 5.2)) * 0.6 : p;
	// Matala: yksi yhteinen laikkukohina kaikille väreille
	float shared_patch = high ? 0.0 : vnoise(p * 0.6 + wave_time * 0.08);
	for (int i = 0; i < count; i++) {
		float len = RIPPLE_DATA[i].x;
		float aa = 1.0 - smoothstep(len * 0.08, len * 0.3, footprint);
		if (aa <= 0.0) {
			continue;
		}
		// Jokaisen väreen voimakkuus vaihtelee omina laikkuinaan
		float fi = float(i);
		float patch = high ? vnoise(p * (0.5 + 0.13 * fi) + vec2(fi * 17.0, fi * 31.0) + wave_time * 0.08) : shared_patch;
		vec2 d = set == 0 ? ripple_dir_a[i] : ripple_dir_b[i];
		float steep = (i < 6 ? 0.09 : 0.06) * patch * patch * 1.6 * amount;
		slope += d * steep * aa * cos(dot(q, d) * (TAU / len) - RIPPLE_DATA[i].y * wave_time + RIPPLE_DATA[i].z);
	}
	return slope;
}

// Vaahtopäät: tuulen voimistuessa (n. 4 m/s alkaen selällä) aallonharjat
// murtuvat valkoisiksi. Jokaisessa tuulen mukana kulkevassa 6 m ruudussa voi
// syntyä vaahtopää, joka leimahtaa kirkkaaksi harjan suuntaiseksi viiruksi, jää
// jälkeensä leviäväksi ja harvenevaksi vaahdoksi ja katoaa. Kovalla tuulella
// pintaan jää lisäksi tuulen suuntaisia vaahtojuovia. Määrä riippuu
// paikallisesta aallokosta (strength: 1 = 8 m/s tuuli 2 km selällä), joten
// ylätuulen rannan suojassa vaahtopäitä ei ole. Murtuva harja osuu aallon
// harjalle ja sen etupuolelle (crest: pinnan korkeus -1..1, front: kaltevuus
// alas tuulen suuntaan, > 0 harjan etupuolella).
// Palauttaa peittävyyden 0–1.
float whitecaps(vec2 p, float footprint, float strength, vec2 dir, float crest, float front) {
	float amount = clamp((strength - 0.45) / 0.55, 0.0, 1.0);
	if (amount <= 0.0) {
		return 0.0;
	}
	vec2 q = vec2(dot(p, vec2(-dir.y, dir.x)), dot(p, dir)); // x poikki tuulen, y tuulen mukaan
	// Vaahtopäät ajelehtivat tuulen mukana
	vec2 m = q - vec2(0.0, 1.2 * wave_time);
	const float CELL = 6.0;
	vec2 base_cell = floor(m / CELL);
	// Pitsimäinen rakenne, venynyt tuulen suuntaan
	float lace = vnoise(m * vec2(2.5, 1.2)) * 0.55 + vnoise(m * vec2(9.0, 5.0)) * 0.3 + vnoise(m * 23.0) * 0.15;
	float on_crest = smoothstep(0.05, 0.5, crest) * smoothstep(-0.25, 0.15, front);
	float foam = 0.0;
	// Vaahtopää voi ulottua naapuriruutuun, joten katsotaan ympäröivät ruudut
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 cell = base_cell + vec2(float(i), float(j));
			float period = 5.0 + chash(cell, 1.0) * 4.0;
			float t = wave_time / period + chash(cell, 2.0);
			float life = fract(t);
			vec2 seed = cell + floor(t) * vec2(13.0, 7.0); // joka kierroksella uusi paikka ja koko
			if (chash(seed, 3.0) > amount * 0.75 + 0.05) {
				continue;
			}
			vec2 center = (cell + vec2(chash(seed, 4.0), chash(seed, 5.0))) * CELL;
			vec2 d = m - center;
			float half_len = (0.6 + chash(seed, 6.0) * 1.2) * (0.7 + amount * 0.5);
			float grow = smoothstep(0.0, 0.12, life);
			// Harjan suuntainen viiru: terävä etureuna, vaahto jää taakse leviämään
			float across = d.x / (half_len * (0.4 + 0.6 * grow) * (1.0 + life * 0.3));
			if (abs(across) > 1.0 || d.y > 0.3 || d.y < -4.0) {
				continue;
			}
			float back = 0.2 + life * 1.6;
			// Harjan kaartuma: reunat jäävät keskeltä jälkeen ja ohenevat
			float bend = d.y + across * across * 0.35;
			float along = bend > 0.0 ? exp(-bend * bend * 60.0) : exp(bend / back);
			float shape = along * (1.0 - smoothstep(0.55, 1.0, abs(across)));
			// Murtuva harja on kirkas, jälkeen jäävä vaahto läpikuultavaa ja harvenevaa
			float edge = 0.38 + life * 0.4;
			float f = smoothstep(edge, edge + 0.12, shape * (0.35 + lace) * 1.15);
			float core = bend > 0.0 ? 1.0 : exp(bend / 0.3);
			// Kirkas murtuma vain aallon harjalla ja sen etupuolella, jälkivaahto
			// jää läpikuultavana myös rinteeseen
			float bright = core * mix(0.5, 0.95, on_crest) + 0.5 * (1.0 - core);
			foam = max(foam, f * bright * (1.0 - life * 0.4) * grow);
		}
	}
	// Tuulen suuntaiset vaahtojuovat kovalla tuulella
	float streak_amount = clamp((strength - 0.85) / 0.15, 0.0, 1.0);
	if (streak_amount > 0.0) {
		vec2 s = q - vec2(0.0, 0.6 * wave_time);
		float lane = vnoise(vec2(s.x * 0.9, s.y * 0.04));
		float bits = vnoise(s * vec2(5.0, 0.7)) * 0.7 + vnoise(s * 14.0) * 0.3;
		foam = max(foam, smoothstep(0.78, 0.95, lane) * smoothstep(0.45, 0.85, bits) * 0.22 * streak_amount);
	}
	// Kaukana yksityiskohdat sulautuvat keskimääräiseksi vaalennukseksi
	float far = smoothstep(0.08, 0.5, footprint);
	return mix(foam, amount * 0.05 + streak_amount * 0.02, far);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_pos = wp.xz;
	sea = local_sea(wp.xz);
	sea_cq = sea_scales(sea);
	world_pos = wp;
	if (is_near && ice < 0.5) {
		// Lähivesi liikkuu aaltojen mukana (UV.x = verteksiväli metreinä);
		// verkossa on vain siirtymä, joten maailman ja mallin akselit ovat samat
		vec3 d = wave_displacement(wp.xz, sea, sea_cq, UV.x);
		VERTEX += d;
		world_pos += d;
	}
}

void fragment() {
	vec2 p = rest_pos;
	if (is_near) {
		// Lähivesi vain järven kohdalle (padon takana oleva matala maa ei jää veden alle)
		if (textureLod(water_mask, (p - mask_rect.xy) / mask_rect.zw, 0.0).r <= 0.001) {
			discard;
		}
	} else {
		// Lähiveden alueella piirtää lähivesi: läpikuultavaa vettä ei kahta kerrosta
		vec2 d = abs(p - near_center);
		if (max(d.x, d.y) < near_radius - 0.02) {
			discard;
		}
	}
	if (inside_boat(world_pos.xz)) {
		discard;
	}
	// Kuinka monta metriä yksi pikseli kattaa tässä kohdassa
	float footprint = length(fwidth(p));
	vec3 nsum = vec3(0.0);
	vec3 elev = vec3(0.0);
	float lost = 0.0;
	set_surface(p, 0, set_weight.x, sea.y, sea_cq.x, sea_cq.y, footprint, nsum, elev, lost);
	set_surface(p, 1, set_weight.y, sea.w, sea_cq.z, sea_cq.w, footprint, nsum, elev, lost);
	// Aallon harja ja etupuoli vaahtopäille: korkeus -1..1 ja kaltevuus tuulen suuntaan
	float crest = elev.y > 0.0 ? elev.x / elev.y : 0.0;
	vec2 wind_dir = vec2(sin(set_angle.x), -cos(set_angle.x));
	float front = elev.z > 0.0 ? -dot(nsum.xz, wind_dir) / elev.z : 0.0;
	// Paikallinen aallokko 0–1 (1 = 8 m/s tuuli 2 km selällä)
	float hs = length(vec2(sea.x * set_weight.x, sea.z * set_weight.y));
	float strength = hs / 0.183;
	// Väreet: tuulen mukaan, ylätuulen rannan suojassa heikommat, puuskalaikuissa tiheämmät
	float gm = gust_patches(p);
	float shelter = smoothstep(0.05, 0.3, max(sea.y * step(0.001, set_weight.x), sea.w * step(0.001, set_weight.y)));
	float ripple_amount = smoothstep(0.5, 4.0, ripple_wind * mix(0.35, 1.0, shelter) + gm * (gust * 1.5 + 1.0));
	vec2 slope = ripple_slope(p, footprint, 0, ripple_amount) * set_weight.x * set_weight.x;
	if (set_weight.y > 0.0) {
		slope += ripple_slope(p, footprint, 1, ripple_amount) * set_weight.y * set_weight.y;
	}
	if (rain > 0.01) {
		float near_rain = 1.0 - smoothstep(10.0, 40.0, length(world_pos - CAMERA_POSITION_WORLD));
		slope += rain_ripples(p) * rain * near_rain;
	}
	vec3 n = normalize(vec3(-nsum.x - slope.x, 1.0 - nsum.y, -nsum.z - slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 5.0);
	vec3 base = mix(shallow_color, deep_color, clamp(facing * 1.3, 0.0, 1.0));
	ALBEDO = mix(base, sky_color * 0.5, fresnel * 0.6);
	// Puuskalaikut ovat tummempia ja himmeämpiä
	ALBEDO *= 1.0 - 0.3 * gm;
	// Karheus kasvaa etäisyyden mukaan: kaukana kimallus sulautuu tasaiseksi
	// Kaukana häivytettyjen aaltojen kaltevuus muuttuu karheudeksi: pinta ei muutu peiliksi
	ROUGHNESS = clamp(0.18 + footprint * 0.4 + min(strength, 1.5) * 0.08 + gm * 0.15 + sqrt(lost) * 1.5
			+ ripple_amount * 0.1 * smoothstep(0.005, 0.08, footprint), 0.18, 0.6);
	METALLIC = 0.0;
	SPECULAR = 0.4;
	// Jyrkästi alas katsottaessa pinnan läpi näkee (ruskea humusvesi), loivassa kulmassa pinta heijastaa
	ALPHA = mix(0.55, 0.97, fresnel);
	scatter_weight = 1.0 - fresnel;
	if (ice < 0.5) {
		float foam = whitecaps(p, footprint, strength, wind_dir, crest, front) * set_weight.x * set_weight.x;
		if (set_weight.y > 0.0) {
			foam += whitecaps(p, footprint, strength, vec2(sin(set_angle.y), -cos(set_angle.y)), crest, front) * set_weight.y * set_weight.y;
		}
		scatter_weight *= 1.0 - foam;
		ALBEDO = mix(ALBEDO, foam_color, foam);
		ALPHA = mix(ALPHA, 1.0, foam);
		ROUGHNESS = mix(ROUGHNESS, 0.85, foam);
		SPECULAR = mix(SPECULAR, 0.2, foam);
	}
	if (ice > 0.5) {
		// Jää: lumipeite, jonka seassa tuulen paljastamia sinertäviä jäälaikkuja
		vec2 q = world_pos.xz;
		float n = sin(q.x * 0.11 + sin(q.y * 0.07) * 2.0) * 0.5 + sin(q.y * 0.13 - q.x * 0.05) * 0.5;
		// Tuulen muovaamat lumikinokset: pehmeät aallot tuulen suuntaan
		float drift = sin(dot(q, vec2(0.8, 0.6)) * 0.9 + sin(q.x * 0.21) * 1.5) * 0.5 + 0.5;
		vec3 snow_col = vec3(0.95, 0.95, 0.96) * (0.95 + drift * 0.05);
		ALBEDO = mix(snow_col, vec3(0.6, 0.68, 0.74), smoothstep(0.78, 0.97, n) * 0.6);
		NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
		ROUGHNESS = 0.75;
		SPECULAR = 0.3;
		ALPHA = 1.0;
	}
	spec_f0 = 0.16 * SPECULAR * SPECULAR;
}

// Oma valaistus, jotta veneen varjo näkyy pinnassa rungosta alkaen: varjossa
// pinnan sironta ja auringon kimallus sammuvat (pohjan varjo häipyy syvyyden
// mukaan, ks. terrain.gdshader).
void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		// Sironta lisätään suoraan (ei kerrota ALBEDOlla, joka on enimmäkseen taivaan heijastusta)
		SPECULAR_LIGHT += scatter_color * sun_scatter * scatter_weight * (1.0 - ice) * ATTENUATION * LIGHT_COLOR / PI;
	}
	// GGX-kimallus
	vec3 h = normalize(VIEW + LIGHT);
	float ndh = clamp(dot(NORMAL, h), 0.0, 1.0);
	float ndv = clamp(dot(NORMAL, VIEW), 0.001, 1.0);
	float a = ROUGHNESS * ROUGHNESS;
	float a2 = a * a;
	float d = ndh * ndh * (a2 - 1.0) + 1.0;
	float dist = a2 / (PI * d * d);
	float vis = 0.5 / (ndl * sqrt(ndv * ndv * (1.0 - a2) + a2) + ndv * sqrt(ndl * ndl * (1.0 - a2) + a2) + 0.0001);
	float f = spec_f0 + (1.0 - spec_f0) * pow(1.0 - clamp(dot(LIGHT, h), 0.0, 1.0), 5.0);
	SPECULAR_LIGHT += dist * vis * f * ndl * ATTENUATION * LIGHT_COLOR * SPECULAR_AMOUNT;
}
