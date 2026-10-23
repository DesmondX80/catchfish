shader_type spatial;
// Maasto ja järven pohja (väri verteksiväristä). Ruskeassa humusvedessä
// auringonvalo siroaa, joten pohjaan ei piirry terävää varjoa: varjo häipyy
// syvyyden mukaan. Muuten syvältä näkyisi veneen varjo irrallisena läiskänä
// veneen vieressä (aurinko vinosti, pohja metrien päässä pinnasta).
render_mode cull_back;

uniform float shadow_fade = 1.2; // 1/m: kuinka nopeasti varjo sumenee syvemmällä

varying float depth;

void vertex() {
	depth = max(-(MODEL_MATRIX * vec4(VERTEX, 1.0)).y, 0.0);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float shadow = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		shadow = mix(1.0, ATTENUATION, exp(-shadow_fade * depth));
	}
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * shadow * LIGHT_COLOR / PI;
}
