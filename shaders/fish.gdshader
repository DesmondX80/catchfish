shader_type spatial;
// Kala: ruumis aaltoilee uidessa (liike voimistuu kohti pyrstöä), lajikuvio
// piirretään UV-koordinaateista, ja humusvesi haalistaa kalan syvyyden mukaan.
// UV.x = 0 kuono .. 1 pyrstö, UV.y = kulma ympäri ruumista (0 = selkä).
// COLOR.rgb = perusväri (selkä/kylki/vatsa), COLOR.a = 1 ruumis, 0.5 selkäevä, 0 muu evä.
render_mode cull_disabled, specular_schlick_ggx;

uniform int pattern = 0; // 0 ei, 1 ahvenen juovat, 2 hauen täplät, 3 taimenen täplät, 4 kuhan juovat
uniform vec3 pattern_color : source_color = vec3(0.1, 0.12, 0.05);
uniform vec3 fin_color : source_color = vec3(0.45, 0.4, 0.25);
uniform vec3 dorsal_color : source_color = vec3(0.3, 0.32, 0.22);
uniform vec3 water_color : source_color = vec3(0.07, 0.065, 0.035);
uniform float clarity = 1.5; // metriä: suurempi = kirkkaampi vesi
uniform float swim_rate = 0.0; // yksittäiselle kalalle; parvessa INSTANCE_CUSTOM.g

varying float depth_below;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float t = UV.x;
	float phase = INSTANCE_CUSTOM.r * 6.2831;
	float rate = INSTANCE_CUSTOM.g > 0.0 ? INSTANCE_CUSTOM.g : swim_rate;
	float amp = 0.04 + 0.06 * min(rate / 8.0, 1.0);
	float bend = sin(6.2831 * t * 0.9 - TIME * rate + phase);
	VERTEX.x += amp * bend * (0.12 + t * t);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth_below = max(-world.y, 0.0);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float is_fin = 1.0 - step(0.75, COLOR.a);
	float is_dorsal = step(0.25, COLOR.a) * is_fin;
	float u = UV.x;
	// 0 = selkä, 1 = vatsa (UV.y kiertää ruumiin ympäri)
	float k = min(UV.y, 1.0 - UV.y) * 2.0;
	float mark = 0.0;
	if (pattern == 1 || pattern == 4) {
		// Poikkijuovat selästä kylkiin ruumiin keskiosassa
		float bars = smoothstep(0.45, 0.8, sin(u * 3.1416 * 13.0));
		mark = bars * step(0.22, u) * step(u, 0.82) * (1.0 - smoothstep(0.55, 0.75, k));
		mark *= pattern == 4 ? 0.45 : 0.9;
	} else if (pattern == 2 || pattern == 3) {
		// Täplät kyljissä: hauella vaaleat, taimenella tummat
		vec2 cell = vec2(u * 26.0, UV.y * 18.0);
		vec2 id = floor(cell);
		vec2 f = fract(cell) - 0.5 + (vec2(hash(id), hash(id + 3.7)) - 0.5) * 0.5;
		float spot = 1.0 - smoothstep(0.18, 0.3, length(f));
		float density = pattern == 2 ? 0.75 : 0.45;
		mark = spot * step(0.12, u) * step(u, 0.9) * step(hash(id + 1.3), density);
		mark *= smoothstep(0.08, 0.2, k) * (1.0 - smoothstep(0.6, 0.75, k));
	}
	vec3 col = mix(base, pattern_color, mark * (1.0 - is_fin));
	col = mix(col, mix(fin_color, dorsal_color, is_dorsal), is_fin);
	// Silmät kuonon takana kyljissä
	float eye = 1.0 - smoothstep(0.014, 0.024, length(vec2(u - 0.075, (k - 0.42) * 0.25)));
	col = mix(col, vec3(0.03), eye * (1.0 - is_fin));
	// Humusvesi: syvyys haalistaa kalan veden väriin
	float visible = exp(-depth_below / clarity);
	ALBEDO = mix(water_color, col, visible);
	ROUGHNESS = 0.45;
	SPECULAR = 0.35 * visible;
}
