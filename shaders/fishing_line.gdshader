shader_type spatial;
// Siima (CATCHFISH-86): läpikuultava vaalea sinertävä monofiili kameraan päin
// kääntyvänä nauhana. Nauha on aina vähintään min_pixels pikselin levyinen;
// kun siima on ohuempi kuin se, peittävyyttä vähennetään samassa suhteessa
// (alaraja min_coverage), joten siima ei portaitu, ei välky eikä katoa kaukana.
// Valaistus: taivaan valo (ympäristö) ja aurinko langan suunnan mukaan
// (Kajiya–Kay), auringon puolella heikko pehmeä kiilto. Pinnan alla siima
// häipyy humusveteen syvyyden mukaan (syvyys pinnasta kärjissä, UV2.x), joten
// tulos ei riipu veden ja siiman piirtojärjestyksestä.
// Kärjet: VERTEX = keskilinjan piste maailmassa, NORMAL = siiman suunta,
// UV.x = puoli (−1 / 1).
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform vec3 line_color : source_color = vec3(0.65, 0.82, 0.95);
uniform float opacity = 0.6;
// Näkyvä paksuus (m): kiilto ja valon taittuminen levittävät ohutta siimaa
uniform float apparent_diameter = 0.0006;
uniform float min_pixels = 1.5;
uniform float min_coverage = 0.35;
uniform vec3 water_color : source_color = vec3(0.07, 0.065, 0.035);
uniform float fade_start = 0.05; // m pinnan alla
uniform float fade_end = 0.45;
uniform float glint = 0.5;
uniform float glint_sharpness = 24.0;

varying vec3 v_tangent;
varying float v_cover;
varying float v_depth;
varying float v_side;

void vertex() {
	vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 t = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	t = length(t) > 1e-6 ? normalize(t) : vec3(0.0, 1.0, 0.0);
	vec3 to_eye = normalize(-view_pos);
	vec3 side = cross(t, to_eye);
	side = length(side) > 1e-6 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	// Pikselin koko tällä etäisyydellä (perspektiivi)
	float px = max(-view_pos.z, 0.01) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float width = max(apparent_diameter, px * min_pixels);
	v_cover = clamp(apparent_diameter / width, min_coverage, 1.0);
	VERTEX = view_pos + side * UV.x * 0.5 * width;
	// Normaali kameraan päin kohtisuoraan siimaa vastaan
	vec3 n = to_eye - t * dot(to_eye, t);
	NORMAL = length(n) > 1e-6 ? normalize(n) : to_eye;
	v_tangent = t;
	v_depth = UV2.x;
	v_side = UV.x;
}

void fragment() {
	float under = smoothstep(0.0, fade_end, v_depth);
	float fade = 1.0 - smoothstep(fade_start, fade_end, v_depth);
	ALBEDO = mix(line_color, water_color, under * 0.85);
	ROUGHNESS = 0.4;
	ALPHA = opacity * v_cover * fade;
}

void light() {
	// Lanka: valo riippuu langan ja valon suunnan välisestä kulmasta
	float tl = dot(v_tangent, LIGHT);
	float diffuse = sqrt(max(0.0, 1.0 - tl * tl)) * 0.75;
	DIFFUSE_LIGHT += diffuse * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float th = dot(v_tangent, h);
	float spec = pow(sqrt(max(0.0, 1.0 - th * th)), glint_sharpness) * glint;
	SPECULAR_LIGHT += spec * ATTENUATION * LIGHT_COLOR * smoothstep(-0.1, 0.3, dot(NORMAL, LIGHT) + 0.3) / PI;
}
