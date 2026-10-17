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

// Veneen runko: vettä ei piirretä veneen sisälle (vene istuu vesirajan alapuolella)
uniform vec2 boat_pos = vec2(1e6);
uniform float boat_yaw = 0.0;

bool inside_boat(vec2 world_xz) {
	vec2 d = world_xz - boat_pos;
	// Veneen paikalliset koordinaatit: z perään päin, x oikealle
	float lx = dot(d, vec2(cos(boat_yaw), -sin(boat_yaw)));
	float lz = dot(d, vec2(sin(boat_yaw), cos(boat_yaw)));
	if (lz < -2.15 || lz > 2.18) {
		return false;
	}
	// Rungon puolileveys vesirajassa (boat.gd: _hull_mesh, n. 0,86 x laidan leveys)
	float w;
	if (lz < -1.8) w = mix(0.05, 0.4, (lz + 2.2) / 0.4);
	else if (lz < -1.0) w = mix(0.4, 0.68, (lz + 1.8) / 0.8);
	else if (lz < 0.0) w = mix(0.68, 0.76, lz + 1.0);
	else if (lz < 1.2) w = mix(0.76, 0.72, lz / 1.2);
	else w = mix(0.72, 0.62, (lz - 1.2) / 1.0);
	return abs(lx) < w * 0.86 - 0.015;
}
