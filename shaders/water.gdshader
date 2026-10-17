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

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += swell_height(world_pos.xz);
}

void fragment() {
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
	ALPHA = mix(0.85, 0.98, fresnel);
}
