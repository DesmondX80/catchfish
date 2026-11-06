shader_type spatial;
// Keulan vesiharjanne (keula-aalto, CATCHFISH-134): matala läpikuultava veden
// kohouma kummallakin kyljellä. Väri kuten matalan veden väri ja taivaan
// heijastus Fresnelillä, sileä pinta, joten rinne heijastaa taivaan ja auringon
// eri kulmassa kuin tasainen vesi. Valaistu: tummuu yöllä auringon mukana.
// VERTEX.y on korkeus pinnan yläpuolella, normaalit tulevat koodista
// (profiilin kaltevuus). Alfa tulee kärkien väreistä (0 reunoilla ja päissä).
// Ei derivaattoja, joten discard on turvallinen (CATCHFISH-120).
render_mode blend_mix, depth_draw_never, cull_disabled, specular_schlick_ggx;

#include "res://shaders/waves.gdshaderinc"

uniform vec3 shallow_color : source_color = vec3(0.13, 0.12, 0.07);
uniform vec3 sky_color : source_color = vec3(0.55, 0.65, 0.75);

varying vec2 ridge_xz;

void vertex() {
	// Mesh on veneen koordinaatistossa (vain kierto pystyakselin ympäri)
	ridge_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	VERTEX.y += surface_height(ridge_xz) + 0.004;
}

void fragment() {
	if (inside_boat(ridge_xz)) {
		discard;
	}
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 5.0);
	ALBEDO = mix(shallow_color, sky_color * 0.5, fresnel * 0.6);
	METALLIC = 0.0;
	ROUGHNESS = 0.1;
	SPECULAR = 0.4;
	ALPHA = COLOR.a;
}
