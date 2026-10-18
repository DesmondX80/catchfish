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

varying vec3 world_pos;

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

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
}
