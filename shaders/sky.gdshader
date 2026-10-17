shader_type sky;
// Taivas pilvineen. Pilvet ovat taivaalle projisoitua kohinaa, joka ajelehtii
// tuulen mukana. Pilvisyys (cover) määrää pilvien määrän, sade (darkness)
// tummentaa ne harmaiksi. Aurinko valaisee pilvien reunat.

uniform vec3 top_color : source_color = vec3(0.32, 0.5, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.78, 0.84);
uniform vec3 ground_color : source_color = vec3(0.3, 0.32, 0.3);
uniform vec3 sun_dir = vec3(0.0, 0.5, -0.8); // suunta kohti aurinkoa
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float daylight = 1.0;
uniform float cover = 0.3;
uniform float darkness = 0.0;
uniform vec2 cloud_offset = vec2(0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, 0.45, h));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, smoothstep(0.0, -0.15, h));
	}
	// Aurinko ja sen hehku, pilvet peittävät
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	float sun = smoothstep(0.9993, 0.9997, sd) * 8.0 + pow(sd, 300.0) * 1.5 + pow(sd, 8.0) * 0.12;
	col += sun_color * sun * daylight * (1.0 - cover * 0.95);

	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 0.55 + cloud_offset;
		float n = fbm(uv);
		// Kohinan arvot ovat enimmäkseen 0,3–0,7: kynnys skaalataan sille välille
		float edge = 0.74 - cover * 0.56;
		float c = smoothstep(edge - 0.08, edge + 0.22, n) * smoothstep(0.0, 0.12, h);
		// Pilven valaistus: auringon puoleinen reuna vaaleampi
		float lit = clamp(0.65 + (n - fbm(uv + normalize(sun_dir.xz + 0.001) * 0.08)) * 3.0, 0.4, 1.1);
		vec3 bright = mix(vec3(0.95), sun_color, 0.25) * lit;
		vec3 grey = vec3(0.42, 0.44, 0.47);
		vec3 cloud = mix(bright, grey, clamp(cover * 0.6 + darkness * 0.6, 0.0, 0.9)) * mix(0.15, 1.0, daylight);
		col = mix(col, cloud, c * 0.95);
	}
	// Pilvipeite harmaannuttaa koko taivaan
	vec3 overcast = vec3(0.5, 0.52, 0.55) * mix(0.15, 1.0, daylight) * (1.0 - darkness * 0.35);
	col = mix(col, overcast, smoothstep(0.6, 1.0, cover) * 0.75);
	COLOR = col;
}
