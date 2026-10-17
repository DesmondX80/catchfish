shader_type spatial;
// Maastokuvio: neljä sävyä epäsäännöllisinä läiskinä. Kuvio lasketaan
// mallin omista koordinaateista, joten se pysyy kankaassa kiinni.
render_mode specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.34, 0.37, 0.21);
uniform vec3 dark_green : source_color = vec3(0.17, 0.23, 0.11);
uniform vec3 brown : source_color = vec3(0.36, 0.27, 0.16);
uniform vec3 black : source_color = vec3(0.09, 0.1, 0.07);
uniform float scale = 9.0; // läiskien tiheys (1/m)

varying vec3 local_pos;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1, 0, 0));
	float n010 = hash3(i + vec3(0, 1, 0));
	float n110 = hash3(i + vec3(1, 1, 0));
	float n001 = hash3(i + vec3(0, 0, 1));
	float n101 = hash3(i + vec3(1, 0, 1));
	float n011 = hash3(i + vec3(0, 1, 1));
	float n111 = hash3(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = local_pos * scale;
	float a = noise3(p) * 0.65 + noise3(p * 2.3 + 5.1) * 0.35;
	float b = noise3(p * 1.4 + 17.3) * 0.7 + noise3(p * 3.1 + 2.7) * 0.3;
	vec3 col = base_color;
	col = mix(col, dark_green, step(0.55, a));
	col = mix(col, brown, step(0.62, b) * (1.0 - step(0.55, a)));
	col = mix(col, black, step(0.7, a) * step(0.5, b));
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
