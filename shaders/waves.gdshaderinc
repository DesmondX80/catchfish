// Yhteinen aaltomalli vedelle ja vanalle. Sama malli on GDScriptissä
// (scripts/world/waves.gd), jotta vene keinuu samoissa aalloissa.
uniform float wave_strength = 0.3; // 0 = tyyni, 1 = kova tuuli (muuttuu hitaasti)
uniform float wind_angle = 0.0; // aallokon pääsuunta radiaaneina (kiinteä)
uniform float wave_time = 0.0; // pelin aika sekunteina (asetetaan koodista)

const float GRAVITY = 9.81;
const int WAVES = 6;
// aallonpituus (m), suunta suhteessa tuuleen (rad), jyrkkyys
const vec3 WAVE_DATA[WAVES] = vec3[](
	vec3(14.0, 0.0, 0.010),
	vec3(8.5, 0.55, 0.012),
	vec3(5.2, -0.4, 0.014),
	vec3(3.1, 0.9, 0.015),
	vec3(2.0, -0.85, 0.016),
	vec3(1.3, 0.25, 0.016)
);

vec2 wave_dir(int i) {
	float a = wind_angle + WAVE_DATA[i].y;
	return vec2(sin(a), -cos(a));
}

// Pinnan korkeus: vain pisin aalto (vesiverkko on 4 m välein)
float swell_height(vec2 p) {
	float k = 2.0 * PI / WAVE_DATA[0].x;
	float amp = WAVE_DATA[0].z * WAVE_DATA[0].x * (0.2 + wave_strength);
	return amp * sin(dot(p, wave_dir(0)) * k - sqrt(GRAVITY * k) * wave_time);
}
