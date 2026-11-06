shader_type spatial;
// Perävana, keula-aallon vaahtoviikset ja airojen pyörteet: vaahtoa veden
// pinnalla. Verteksit seuraavat samaa aallokkoa kuin vesi, joten vana ei uppoa
// aallonharjoihin; VERTEX.y on lisäkorkeus (viiksi keulan vesiharjanteen päällä).
// UV.x = poikittainen paikka nauhassa (−1 … 1), UV.y = etäisyys peräpeilistä,
// UV2.x = nauhan tyyppi (wake.gd TYPE_*). Kulku-uoman ja aaltojen reunat
// pehmennetään ja rikotaan maailman koordinaateista lasketulla kohinalla.
// Ei derivaattoja (fwidth/dFdx), joten discard on turvallinen (CATCHFISH-120).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/waves.gdshaderinc"

uniform vec3 foam_color : source_color = vec3(0.85, 0.87, 0.85);
uniform float light = 1.0; // vuorokauden valoisuus

varying vec2 foam_uv;
varying vec3 strip; // poikittainen paikka, etäisyys perästä, tyyppi

// Arvokohina 0–1 ilman sin-funktiota (tarkka myös kaukana origosta)
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float edge_noise(vec2 p) {
	return 0.65 * value_noise(p * 1.6) + 0.35 * value_noise(p * 4.3 + 17.0);
}

void vertex() {
	// Peräaalto on maailman koordinaateissa, viikset veneen koordinaatistossa
	// (vain kierto pystyakselin ympäri, joten VERTEX.y on myös maailman korkeus)
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	foam_uv = world_xz;
	strip = vec3(UV, UV2.x);
	VERTEX.y += surface_height(world_xz) + 0.025;
}

void fragment() {
	if (inside_boat(foam_uv)) {
		discard;
	}
	// Vaahdon epätasainen rakenne: kaksi ristikkäistä aaltokuviota
	float streaks = 0.55 + 0.45 * sin(foam_uv.x * 3.1 + sin(foam_uv.y * 2.3) * 2.0) * sin(foam_uv.y * 2.7 + foam_uv.x * 0.7);
	float a = COLOR.a * clamp(streaks, 0.25, 1.0);
	float type = strip.z;
	if (type < 2.5) {
		// Reunan häivytysraja vaihtelee 70–100 % puolileveydestä (±15 %)
		float n = edge_noise(foam_uv);
		float edge = 1.0 - 0.3 * n;
		float u = abs(strip.x);
		if (type < 0.5 || type > 1.5) {
			// Kulku-uoma ja viiksi: häivytys uloimmalla 35 %:lla
			a *= 1.0 - smoothstep(edge - 0.35, edge, u);
		} else {
			// Sivuaalto: pehmeä koko poikkileikkaus, huippu keskellä
			a *= 1.0 - smoothstep(0.1, edge, u);
		}
		if (type < 0.5) {
			// Kulku-uoman alkureuna epätasainen (täysi vähintään 1 m perästä)
			float n2 = edge_noise(foam_uv * 1.3 + 41.0);
			a *= smoothstep(0.0, 0.7, strip.y - 0.5 * n2 + 0.2);
		}
	}
	ALBEDO = foam_color * mix(0.25, 1.0, light);
	ALPHA = a;
}
