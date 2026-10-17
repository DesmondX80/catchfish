shader_type spatial;
// Perävana ja airojen pyörteet: vaahtoa veden pinnalla. Verteksit seuraavat
// samaa aallokkoa kuin vesi, joten vana ei uppoa aallonharjoihin.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/waves.gdshaderinc"

uniform vec3 foam_color : source_color = vec3(0.85, 0.87, 0.85);
uniform float light = 1.0; // vuorokauden valoisuus

varying vec2 foam_uv;

void vertex() {
	VERTEX.y = swell_height(VERTEX.xz) + 0.025;
	foam_uv = VERTEX.xz;
}

void fragment() {
	if (inside_boat(foam_uv)) {
		discard;
	}
	// Vaahdon epätasainen rakenne: kaksi ristikkäistä aaltokuviota
	float streaks = 0.55 + 0.45 * sin(foam_uv.x * 3.1 + sin(foam_uv.y * 2.3) * 2.0) * sin(foam_uv.y * 2.7 + foam_uv.x * 0.7);
	ALBEDO = foam_color * mix(0.25, 1.0, light);
	ALPHA = COLOR.a * clamp(streaks, 0.25, 1.0);
}
