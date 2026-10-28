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
// Väreiden kaltevuuskuvio (tools/build_ripples.py): x tuulen suuntaan, y poikki
uniform sampler2D ripple_tex : filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 world_pos;
varying vec2 rest_pos; // pinnan kohta ennen aaltojen siirtymää
varying vec4 sea; // paikallinen aallokko: (Hs, L) kummallekin suuntasarjalle
varying vec4 sea_cq; // amplitudikerroin ja terävyys (c, q) kummallekin suuntasarjalle
varying vec2 sea_fetch; // pyyhkäisymatka (m) kummallekin suuntasarjalle
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

// Kohinan koordinaatit käännettynä, jottei kohinaruudukon suunta näy
vec2 rot_noise(vec2 p, float a) {
	return vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a));
}

// Puuskat: tuulen mukana tuulta hitaammin kulkevat kymmenien metrien laikut
// ("kissankäpälät"), joissa väreet ovat tiheämpiä. Pehmeät, pyöreähköt reunat. 0–1.
float gust_patches(vec2 p) {
	if (gust < 0.2) {
		return 0.0;
	}
	vec2 q = rot_noise(p - gust_offset, 0.61) / 28.0;
	// Kohinan vääristys pyöristää ruudukon kulmat
	q += vec2(vnoise(q * 0.7 + 3.1), vnoise(q * 0.7 + 8.7)) * 0.8;
	float n = vnoise(q) * 0.7 + vnoise(rot_noise(q, 1.1) * 2.1 + 17.0) * 0.3;
	if (quality == 1) {
		n = n * 0.85 + vnoise(rot_noise(q, 2.3) * 4.3 + 3.0) * 0.15;
	}
	float cover = smoothstep(0.3, 3.0, gust) * 0.25;
	return smoothstep(0.55 - cover, 0.82 - cover, n) * smoothstep(0.2, 1.2, gust);
}

// Väreet (Korkea): saumaton kuvio satojen lyhyiden aaltojen summasta
// (suunnat ±60° tuulesta, pituudet jatkuvalta väliltä, ks. build_ripples.py).
// Kuviota käytetään kolmessa mittakaavassa ja kulmassa, ja se liikkuu tuulen
// mukana eri nopeuksilla. Kaksi karkeinta kerrosta vuorottelevat laikuittain
// (ei summana), joten kuvion toistoa ei erota. Voimakkuus vaihtelee
// laikuittain matalataajuisen kohinan mukaan. Mipmapit sulauttavat kaukaiset
// väreet tasaisiksi (ei välkettä).
const float RIPPLE_RANGE = 3.0; // build_ripples.py RANGE
// Kerrokset: ruudun koko (m), kulma tuulesta (rad), nopeus (m/s), voimakkuus
const vec4 RIPPLE_LAYER[3] = vec4[](
	vec4(6.0, 0.0, 0.32, 0.06), vec4(3.7, 0.47, 0.26, 0.06), vec4(1.05, -0.33, 0.2, 0.03)
);

// Kerroksen i kaltevuus maailman koordinaateissa
vec2 ripple_layer(int i, vec2 p, vec2 dpdx, vec2 dpdy, float base_ang) {
	vec4 layer = RIPPLE_LAYER[i];
	float ang = base_ang + layer.y;
	vec2 ax = vec2(cos(ang), sin(ang)); // kuvion x (aaltojen kulkusuunta)
	vec2 ay = vec2(-ax.y, ax.x);
	vec2 uv = vec2(dot(p, ax) - layer.z * wave_time, dot(p, ay)) / layer.x + vec2(0.31, 0.57) * float(i);
	vec2 gx = vec2(dot(dpdx, ax), dot(dpdx, ay)) / layer.x;
	vec2 gy = vec2(dot(dpdy, ax), dot(dpdy, ay)) / layer.x;
	vec2 s = (textureGrad(ripple_tex, uv, gx, gy).rg * 2.0 - 1.0) * RIPPLE_RANGE;
	return (ax * s.x + ay * s.y) * layer.w;
}

vec2 ripple_slope(vec2 p, vec2 dpdx, vec2 dpdy, float footprint, vec2 wind_dir, float amount) {
	vec2 slope = vec2(0.0);
	if (amount <= 0.001 || footprint > RIPPLE_LAYER[0].x / 25.0) {
		return slope;
	}
	// Laikut: voimakkuus 0,3–1,7-kertainen, laikut ajelehtivat tuulen mukana
	vec2 drift = wind_dir * wave_time * 0.4;
	vec2 pq = rot_noise(p - drift, 0.37);
	float patch_a = 0.3 + 1.4 * (vnoise(pq / 7.0) * 0.65 + vnoise(rot_noise(pq, 1.3) / 2.9 + 5.0) * 0.35);
	float patch_b = 0.3 + 1.4 * vnoise(rot_noise(pq, 2.1) / 3.7 + 11.0);
	float base_ang = atan(wind_dir.y, wind_dir.x);
	// Karkeat kerrokset vuorottelevat laikuittain; painot normitettu, jottei
	// voimakkuus notkahda välissä
	float w = smoothstep(0.25, 0.75, vnoise(rot_noise(p, 1.9) / 5.5 + 23.0));
	float aa = 1.0 - smoothstep(RIPPLE_LAYER[0].x / 60.0, RIPPLE_LAYER[0].x / 25.0, footprint);
	vec2 coarse = vec2(0.0);
	if (w > 0.0) {
		coarse += ripple_layer(0, p, dpdx, dpdy, base_ang) * w;
	}
	if (w < 1.0) {
		coarse += ripple_layer(1, p, dpdx, dpdy, base_ang) * (1.0 - w);
	}
	slope = coarse * (aa * patch_a / sqrt(w * w + (1.0 - w) * (1.0 - w)));
	float aa_fine = 1.0 - smoothstep(RIPPLE_LAYER[2].x / 60.0, RIPPLE_LAYER[2].x / 25.0, footprint);
	if (aa_fine > 0.0) {
		slope += ripple_layer(2, p, dpdx, dpdy, base_ang) * (aa_fine * patch_b);
	}
	return slope * amount;
}

// Vaahtopäät: tuulen voimistuessa (n. 4 m/s alkaen selällä) aallonharjat
// murtuvat valkoisiksi. Jokaisessa tuulen mukana kulkevassa 6 m ruudussa voi
// syntyä erikokoinen vaahtopää, joka leimahtaa harjan suuntaiseksi viiruksi,
// jää leviäväksi ja harvenevaksi pitsiksi ja katoaa. Vaahto on sidottu aallon
// harjaan ja sen etupuolelle (crest: pinnan korkeus -1..1, front: kaltevuus alas
// tuulen suuntaan, > 0 harjan etupuolella): pohjissa sitä ei ole. Reunat ovat
// pehmeät ja läpikuultavat. Kovalla tuulella pintaan jää lisäksi katkonaisia,
// mutkittelevia vaahtojuovia. Määrä riippuu paikallisesta aallokosta
// (strength: 1 = 8 m/s tuuli 2 km selällä), joten ylätuulen rannan suojassa
// vaahtopäitä ei ole. Palauttaa peittävyyden 0–1.
float whitecaps(vec2 p, float footprint, float strength, vec2 dir, float crest, float front) {
	float amount = clamp((strength - 0.45) / 0.55, 0.0, 1.0);
	if (amount <= 0.0) {
		return 0.0;
	}
	vec2 q = vec2(dot(p, vec2(-dir.y, dir.x)), dot(p, dir)); // x poikki tuulen, y tuulen mukaan
	// Kirkas vaahto on harjalla ja sen etupuolella: pohjissa ja tasaisella ei vaahtoa
	float crest_band = smoothstep(0.05, 0.35, crest) * smoothstep(-0.3, 0.2, front);
	// Kaukana yksityiskohdat sulautuvat keskimääräiseksi vaalennukseksi
	float far = smoothstep(0.08, 0.5, footprint);
	float foam = 0.0;
	if (crest > -0.25 && far < 1.0) {
		// Murtuma-alueet ajelehtivat tuulen mukana; harja kulkee niiden läpi
		vec2 m = q - vec2(0.0, 1.2 * wave_time);
		const float CELL = 6.0;
		// Murtuma-alue ulottuu keskipisteestään enintään 2,85 m sivuille ja 2,1 m
		// eteen ja taakse, joten tarvitaan vain ne enintään 2 × 2 ruutua, joihin sen
		// keskipiste voi osua
		vec2 cell_lo = floor((m - vec2(2.85, 2.1)) / CELL);
		vec2 cell_hi = floor((m + vec2(2.85, 2.1)) / CELL);
		float lace = -1.0; // lasketaan vasta, kun murtuma-alue osuu kohtaan
		for (int i = 0; i <= 1; i++) {
			for (int j = 0; j <= 1; j++) {
				vec2 cell = cell_lo + vec2(float(i), float(j));
				if (cell.x > cell_hi.x || cell.y > cell_hi.y) {
					continue;
				}
				float period = 5.0 + chash(cell, 1.0) * 4.0;
				float t = wave_time / period + chash(cell, 2.0);
				float life = fract(t);
				vec2 seed = cell + floor(t) * vec2(13.0, 7.0); // joka kierroksella uusi paikka ja koko
				if (chash(seed, 3.0) > amount * 0.95 + 0.05) {
					continue;
				}
				vec2 center = (cell + vec2(chash(seed, 4.0), chash(seed, 5.0))) * CELL;
				vec2 d = m - center;
				// Koot vaihtelevat: enimmäkseen pieniä, joskus pitkä murtuma
				float size = chash(seed, 6.0);
				float half_len = (0.35 + size * size * 2.0) * (0.7 + amount * 0.5);
				float grow = smoothstep(0.0, 0.12, life);
				// Harjan suuntainen soikio
				vec2 e = vec2(d.x / (half_len * (0.5 + 0.5 * grow)), d.y / (0.6 + half_len * 0.5));
				float r2 = dot(e, e);
				if (r2 > 1.0) {
					continue;
				}
				if (lace < 0.0) {
					// Pitsimäinen rakenne, venynyt tuulen suuntaan
					vec2 lm = rot_noise(m, 0.2);
					lace = vnoise(lm * vec2(2.5, 1.2)) * 0.55 + vnoise(lm * vec2(9.0, 5.0)) * 0.3 + vnoise(lm * 23.0) * 0.15;
				}
				// Pehmeä, rikkonainen reuna
				float region = 1.0 - smoothstep(0.1, 1.0, r2 + (lace - 0.5) * 0.6);
				// Murtuma leimahtaa kirkkaana harjalla ja haalistuu; läpikuultava
				// pitsi jää harjan taakse
				float fresh = crest_band * mix(1.0, 0.45, smoothstep(0.1, 0.6, life));
				float trail = 0.45 * smoothstep(-0.25, 0.2, crest) * smoothstep(0.1, 0.4, life);
				float v = region * (fresh + trail) * (1.0 - life) * grow;
				// Pitsi rikkoo vaahdon: tiheässä vaahdossa pieniä reikiä, reunoilla
				// vain irrallisia, läpikuultavia läikkiä
				foam = max(foam, smoothstep(0.08, 0.45, v * (0.2 + lace)));
			}
		}
	}
	// Tuulen suuntaiset vaahtojuovat kovalla tuulella: mutkittelevat, katkeilevat
	// ja haalistuvat
	float streak_amount = clamp((strength - 0.85) / 0.15, 0.0, 1.0);
	if (streak_amount > 0.0 && far < 1.0) {
		vec2 s = q - vec2(0.0, 0.6 * wave_time);
		// Juova mutkittelee kahdessa mittakaavassa ja katkeilee muutaman metrin pätkiksi
		float x = s.x + (vnoise(vec2(s.y * 0.045, s.x * 0.02) + 3.1) - 0.5) * 9.0
				+ (vnoise(vec2(s.y * 0.17, s.x * 0.05) + 9.7) - 0.5) * 2.6;
		float lane = vnoise(vec2(x * 0.37, s.y * 0.05)) * 0.6 + vnoise(vec2(x * 0.83 + 7.3, s.y * 0.09 + 1.7)) * 0.4;
		float pieces = smoothstep(0.4, 0.75, vnoise(vec2(x * 0.21 + 4.4, s.y * 0.3)));
		float bits = vnoise(rot_noise(s, 0.3) * vec2(5.0, 0.9)) * 0.7 + vnoise(s * 14.0) * 0.3;
		foam = max(foam, smoothstep(0.66, 0.82, lane) * pieces * smoothstep(0.4, 0.8, bits) * 0.13 * streak_amount);
	}
	return mix(foam, amount * 0.05 + streak_amount * 0.02, far);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_pos = wp.xz;
	vec2 fetch_m;
	sea = local_sea_fetch(wp.xz, fetch_m);
	sea_fetch = fetch_m;
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
	vec2 dpdx = dFdx(p);
	vec2 dpdy = dFdy(p);
	float footprint = length(abs(dpdx) + abs(dpdy));
	// Väreet syntyvät tuulesta jo muutaman metrin pyyhkäisymatkalla: selvästi
	// 2 m/s alkaen, alle 1 m/s pinta on lähes peili. Suoja heikentää niitä vain
	// ylätuulen rannan ensimmäisillä 10–20 metrillä. Puuskalaikuissa tiheämmät.
	// Sama kaava kuin waves.gd ripple_amount.
	float gm = gust_patches(p);
	float fetch_now = (sea_fetch.x * set_weight.x + sea_fetch.y * set_weight.y) / max(set_weight.x + set_weight.y, 0.001);
	float shelter = mix(0.45, 1.0, smoothstep(1.0, 15.0, fetch_now));
	float ripple_wind_now = ripple_wind + gm * (gust * 1.5 + 1.0);
	float ripple_amount = (smoothstep(0.6, 2.2, ripple_wind_now) * 0.55 + smoothstep(2.2, 7.0, ripple_wind_now) * 0.45) * shelter;
	// Matalalla väreitä ei piirretä: lyhimpien aaltojen (alle 1,5 m) kaltevuutta
	// korostetaan väreiden tilalla, jottei pinta ole kapeassa lahdessa peili
	float short_boost = quality == 0 ? ripple_amount * 1.5 : 0.0;
	vec3 nsum = vec3(0.0);
	vec3 elev = vec3(0.0);
	float lost = 0.0;
	set_surface(p, 0, set_weight.x, sea.y, sea_cq.x, sea_cq.y, footprint, short_boost, nsum, elev, lost);
	set_surface(p, 1, set_weight.y, sea.w, sea_cq.z, sea_cq.w, footprint, short_boost, nsum, elev, lost);
	// Aallon harja ja etupuoli vaahtopäille: korkeus -1..1 ja kaltevuus tuulen suuntaan
	float crest = elev.y > 0.0 ? elev.x / elev.y : 0.0;
	vec2 wind_dir = vec2(sin(set_angle.x), -cos(set_angle.x));
	float front = elev.z > 0.0 ? -dot(nsum.xz, wind_dir) / elev.z : 0.0;
	// Paikallinen aallokko 0–1 (1 = 8 m/s tuuli 2 km selällä)
	float hs = length(vec2(sea.x * set_weight.x, sea.z * set_weight.y));
	float strength = hs / 0.183;
	vec2 slope = vec2(0.0);
	if (quality == 1) {
		slope = ripple_slope(p, dpdx, dpdy, footprint, wind_dir, ripple_amount) * set_weight.x * set_weight.x;
		if (set_weight.y > 0.0) {
			slope += ripple_slope(p, dpdx, dpdy, footprint, vec2(sin(set_angle.y), -cos(set_angle.y)), ripple_amount) * set_weight.y * set_weight.y;
		}
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
	// Kaukana väreiden kaltevuus muuttuu karheudeksi. Matalalla väreitä ei piirretä:
	// niiden tilalla karheus vaihtelee tuulen mukana ajelehtivina laikkuina, jolloin
	// kimallus ja taivaan heijastus elävät
	float ripple_rough = ripple_amount * 0.1 * smoothstep(0.005, 0.08, footprint);
	if (quality == 0) {
		vec2 lq = rot_noise(p - wind_dir * wave_time * 0.5, 0.37);
		float live = vnoise(lq / 2.3) * 0.6 + vnoise(rot_noise(lq, 1.7) / 0.9 + 7.0) * 0.4;
		ripple_rough = max(ripple_rough, ripple_amount * (0.04 + 0.22 * live * live));
	}
	ROUGHNESS = clamp(0.18 + footprint * 0.1 + min(strength, 1.5) * 0.08 + gm * 0.15 + sqrt(lost) * 1.5
			+ ripple_rough, 0.18, 0.6);
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
