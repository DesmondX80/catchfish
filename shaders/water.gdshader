shader_type spatial;
// Humuspitoinen, ruskehtava järvivesi rauhallisella aallokolla.
// Aallot ovat siniaaltojen summa kiinteisiin suuntiin. Nopeus noudattaa
// syvän veden dispersiota (w = sqrt(g k)), joten pitkät aallot liikkuvat
// rauhallisesti. Jokainen aalto häivytetään, kun se on näytöllä pikseliä
// pienempi – muuten kaukaiset laineet välkkyvät.
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

varying vec3 world_pos;
varying float shore_dist; // metreinä rantaan (verteksiväristä)
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

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rhash(i), rhash(i + vec2(1.0, 0.0)), f.x),
		mix(rhash(i + vec2(0.0, 1.0)), rhash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Vaahtopäät: tuulen voimistuessa (n. 4 m/s alkaen) aallonharjat murtuvat
// valkoisiksi. Jokaisessa tuulen mukana kulkevassa 7 m ruudussa voi syntyä
// vaahtopää, joka leimahtaa kirkkaaksi harjan suuntaiseksi viiruksi, jää
// jälkeensä leviäväksi ja harvenevaksi vaahdoksi ja katoaa. Kovalla tuulella
// pintaan jää lisäksi tuulen suuntaisia vaahtojuovia. Rannan lähellä aallot
// ovat vielä liian pieniä murtumaan: vaahtopäitä on vasta n. 200 m rannasta.
// Palauttaa peittävyyden 0–1.
float whitecaps(vec2 p, float footprint) {
	float offshore = smoothstep(140.0, 220.0, shore_dist);
	float amount = clamp((wave_strength - 0.45) / 0.55, 0.0, 1.0) * offshore;
	if (amount <= 0.0) {
		return 0.0;
	}
	vec2 dir = wave_dir(0);
	vec2 q = vec2(dot(p, vec2(-dir.y, dir.x)), dot(p, dir)); // x poikki tuulen, y tuulen mukaan
	// Vaahtopäät ajelehtivat tuulen mukana
	vec2 m = q - vec2(0.0, 1.2 * wave_time);
	const float CELL = 6.0;
	vec2 base_cell = floor(m / CELL);
	// Pitsimäinen rakenne, venynyt tuulen suuntaan
	float lace = vnoise(m * vec2(2.5, 1.2)) * 0.55 + vnoise(m * vec2(9.0, 5.0)) * 0.3 + vnoise(m * 23.0) * 0.15;
	float foam = 0.0;
	// Vaahtopää voi ulottua naapuriruutuun, joten katsotaan ympäröivät ruudut
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 cell = base_cell + vec2(float(i), float(j));
			float period = 5.0 + rhash(cell + 3.3) * 4.0;
			float t = wave_time / period + rhash(cell + 7.7);
			float life = fract(t);
			vec2 seed = cell + floor(t) * 13.1; // joka kierroksella uusi paikka ja koko
			if (rhash(seed + 1.9) > amount * 0.75 + 0.05) {
				continue;
			}
			vec2 center = (cell + vec2(rhash(seed), rhash(seed + 4.1))) * CELL;
			vec2 d = m - center;
			float half_len = (0.6 + rhash(seed + 2.6) * 1.2) * (0.7 + amount * 0.5);
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
			foam = max(foam, f * mix(0.45, 0.95, core) * (1.0 - life * 0.4) * grow);
		}
	}
	// Tuulen suuntaiset vaahtojuovat kovalla tuulella
	float streak_amount = clamp((wave_strength - 0.85) / 0.15, 0.0, 1.0) * offshore;
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
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	shore_dist = COLOR.r * 500.0;
	VERTEX.y += swell_height(world_pos.xz) * (1.0 - ice);
}

void fragment() {
	if (inside_boat(world_pos.xz)) {
		discard;
	}
	vec2 p = world_pos.xz;
	// Kuinka monta metriä yksi pikseli kattaa tässä kohdassa
	float footprint = length(fwidth(p));
	float strength = 0.2 + wave_strength;
	vec2 slope = vec2(0.0);
	for (int i = 0; i < WAVES; i++) {
		float wavelength = WAVE_DATA[i].x;
		float k = 2.0 * PI / wavelength;
		float omega = sqrt(GRAVITY * k);
		float amp = WAVE_DATA[i].z * wavelength * strength;
		// Häivytys, kun aalto kutistuu muutaman pikselin kokoiseksi
		float aa = 1.0 - smoothstep(wavelength * 0.08, wavelength * 0.3, footprint);
		vec2 d = wave_dir(i);
		slope += d * k * amp * aa * cos(dot(p, d) * k - omega * wave_time);
	}
	if (rain > 0.01) {
		float near_rain = 1.0 - smoothstep(10.0, 40.0, length(world_pos - CAMERA_POSITION_WORLD));
		slope += rain_ripples(p) * rain * near_rain;
	}
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 5.0);
	vec3 base = mix(shallow_color, deep_color, clamp(facing * 1.3, 0.0, 1.0));
	ALBEDO = mix(base, sky_color * 0.5, fresnel * 0.6);
	// Karheus kasvaa etäisyyden mukaan: kaukana kimallus sulautuu tasaiseksi
	ROUGHNESS = clamp(0.18 + footprint * 0.4 + wave_strength * 0.08, 0.18, 0.5);
	METALLIC = 0.0;
	SPECULAR = 0.4;
	// Jyrkästi alas katsottaessa pinnan läpi näkee (ruskea humusvesi), loivassa kulmassa pinta heijastaa
	ALPHA = mix(0.55, 0.97, fresnel);
	scatter_weight = 1.0 - fresnel;
	if (ice < 0.5) {
		float foam = whitecaps(p, footprint);
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
