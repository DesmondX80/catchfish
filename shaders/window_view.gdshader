shader_type spatial;
// Mökin ikkunasta näkyvä maisema: taivas, metsänreuna ja järvi.
// Valoa hehkuva, ei valaistu: ikkunat valaisevat huonetta.
render_mode unshaded, cull_disabled;

uniform float seed = 0.0;
uniform float snow = 0.0; // vuodenaika: lumi maassa ja puissa
uniform float autumn = 0.0; // ruska metsänreunassa

float tree_line(float x) {
	float h = 0.0;
	for (int i = 0; i < 4; i++) {
		float f = 7.0 + float(i) * 11.3;
		h += abs(sin(x * f + seed * 3.1 + float(i) * 1.7)) * (0.05 / (1.0 + float(i) * 0.6));
	}
	// Kuusten terävät latvat
	h += max(0.0, sin(x * 41.0 + seed) * 0.5 + 0.2) * 0.04;
	return 0.42 + h;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y); // y ylös
	vec3 sky = mix(vec3(0.95, 0.82, 0.62), vec3(0.55, 0.72, 0.9), smoothstep(0.4, 1.0, uv.y));
	vec3 col = sky;
	float trees = tree_line(uv.x);
	if (uv.y < trees) {
		col = mix(vec3(0.1, 0.17, 0.11), vec3(0.18, 0.26, 0.15), uv.y);
		// Ruska: lehtipuiden keltaiset läikät kuusten lomassa
		float birch = step(0.6, fract(sin(floor(uv.x * 38.0) * 12.9898 + seed) * 43758.5));
		col = mix(col, vec3(0.75, 0.5, 0.12), autumn * birch * 0.8);
		col = mix(col, vec3(0.7, 0.74, 0.78), snow * 0.35);
	}
	if (uv.y < 0.36) {
		// Järvi heijastaa taivasta, rannassa tumma vyö
		col = mix(vec3(0.42, 0.5, 0.58), vec3(0.75, 0.72, 0.62), smoothstep(0.0, 0.36, uv.y) * 0.5);
		col *= 0.85 + 0.15 * sin(uv.y * 160.0 + uv.x * 8.0);
	}
	if (uv.y < 0.18) {
		col = mix(vec3(0.24, 0.3, 0.16), vec3(0.4, 0.34, 0.2), autumn); // ranta ja nurmi ikkunan alla
		col = mix(col, vec3(0.9, 0.92, 0.95), snow);
	}
	ALBEDO = col * 1.15;
}
