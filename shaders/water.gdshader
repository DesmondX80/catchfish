shader_type spatial;
// Humuspitoinen, ruskehtava järvivesi. Pienet laineet tehdään pikselivarjostimessa
// normaaleilla, isommat aallot verteksivarjostimessa. Tuuli säätää aallokkoa.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.06, 0.055, 0.03);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.15, 0.09);
uniform vec3 sky_color : source_color = vec3(0.55, 0.65, 0.75);
uniform float wave_strength = 0.4; // 0 = tyyni, 1 = kova tuuli
uniform vec2 wind_dir = vec2(1.0, 0.0);

varying vec3 world_pos;

float wave(vec2 p, vec2 dir, float freq, float speed, float t) {
	return sin(dot(p, dir) * freq + t * speed);
}

vec2 wave_slope(vec2 p, vec2 dir, float freq, float speed, float amp, float t) {
	return dir * freq * amp * cos(dot(p, dir) * freq + t * speed);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = normalize(wind_dir);
	VERTEX.y += wave_strength * 0.06 * wave(world_pos.xz, d, 0.35, 1.3, TIME);
}

void fragment() {
	vec2 d = normalize(wind_dir);
	vec2 d2 = normalize(d + vec2(-d.y, d.x) * 0.6);
	vec2 d3 = normalize(d - vec2(-d.y, d.x) * 0.8);
	vec2 p = world_pos.xz;
	float s = 0.15 + wave_strength;
	// Pienet laineet häivytetään kaukana, muuten ne näkyvät raitakuviona
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(15.0, 60.0, dist);
	float mid = 1.0 - smoothstep(40.0, 200.0, dist);
	float far = 1.0 - smoothstep(150.0, 600.0, dist);
	vec2 slope = wave_slope(p, d, 1.1, 2.4, 0.035 * s * far, TIME)
		+ wave_slope(p, d2, 2.3, 3.6, 0.02 * s * mid, TIME)
		+ wave_slope(p, d3, 4.7, 5.1, 0.012 * s * near, TIME)
		+ wave_slope(p, vec2(d.y, -d.x), 9.0, 7.0, 0.006 * s * near, TIME);
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	vec3 base = mix(shallow_color, deep_color, clamp(facing * 1.4, 0.0, 1.0));
	ALBEDO = mix(base, sky_color * 0.45, fresnel * 0.5);
	ROUGHNESS = 0.12 + 0.12 * wave_strength;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	ALPHA = mix(0.82, 0.98, fresnel);
}
