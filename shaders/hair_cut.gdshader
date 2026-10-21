shader_type spatial;
// Kalastajan hiukset ja parta: päähineen reunan yläpuolinen tukka leikataan
// pois, jotta lippalakki ja pipo istuvat päätä vasten. Korkeus lasketaan pään
// luun koordinaateissa (head_inv), joten leikkaus seuraa päätä.
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.26, 0.16, 0.08);
uniform mat4 head_inv; // mallin koordinaateista pään luun koordinaatteihin
uniform float cut = 1.0e6; // leikkauskorkeus pään luusta, mallin yksiköissä

varying float head_height;

void vertex() {
	head_height = (head_inv * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (head_height > cut) {
		discard;
	}
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
