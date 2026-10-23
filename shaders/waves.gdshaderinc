// Yhteinen aaltomalli vedelle ja vanalle. Sama malli on GDScriptissä
// (scripts/world/waves.gd), jotta vene keinuu samoissa aalloissa.
// Aallokko lasketaan joka kohdassa tuulesta ja pyyhkäisymatkasta: pinta on
// 12 Gerstner-aallon summa, ja aaltojen korkeudet riippuvat paikallisesta
// huippuaallonpituudesta. Kaksi suuntasarjaa häivytetään ristiin tuulen kääntyessä.
uniform float wave_wind = 3.0; // aallokon tuuli m/s (muuttuu hitaasti)
uniform vec2 set_angle = vec2(0.0); // suuntasarjojen suunnat (rad, johon tuuli puhaltaa)
// Aaltojen (12) ja aaltoryhmien (2) suuntavektorit suuntasarjoittain (lasketaan koodissa)
uniform vec2 wave_dir_a[14];
uniform vec2 wave_dir_b[14];
// Aaltojen vaiheen poikkeutus (waves.gd warp_phase): kaksi hidasta aaltovektoria
uniform vec4 wave_warp[12];
uniform vec2 set_weight = vec2(1.0, 0.0); // suuntasarjojen painot
uniform float wave_phase[14]; // aaltojen ja aaltoryhmien vaiheet (lasketaan koodissa)
uniform float wave_time = 0.0; // pelin aika sekunteina (asetetaan koodista)
uniform float ripple_wind = 3.0; // tuulen perusnopeus väreille (m/s)
uniform float gust = 0.0; // puuskan voimakkuus (m/s)
uniform vec2 gust_offset = vec2(0.0); // puuskalaikkujen siirtymä tuulen mukana
uniform vec2 near_center = vec2(0.0); // lähiveden keskipiste
uniform float near_radius = 1.0e6; // lähiveden säde: siirtymä häivyy reunalla
uniform int quality = 1; // veden laatu: 1 = Korkea, 0 = Matala
// Pyyhkäisymatkat: kummallekin suuntasarjalle kaksi lähintä suuntaa ja niiden sekoitus
uniform vec4 fetch_rect = vec4(0.0, 0.0, 1.0, 1.0); // ruudukon alkukulma ja koko (m)
uniform sampler2D fetch_a0 : filter_linear, repeat_disable;
uniform sampler2D fetch_a1 : filter_linear, repeat_disable;
uniform sampler2D fetch_b0 : filter_linear, repeat_disable;
uniform sampler2D fetch_b1 : filter_linear, repeat_disable;
uniform vec2 fetch_mix = vec2(0.0);

const float GRAVITY = 9.81;
const int WAVES = 12;
// Aallonpituudet (m) ja suunnat suhteessa tuuleen (rad), kuten waves.gd
const float WAVE_LEN[WAVES] = float[](0.3, 0.42, 0.588, 0.8232, 1.15248, 1.613472, 2.2588608, 3.16240512, 4.427367168, 6.1983140352, 8.67763964928, 12.148695508992);
// ln(aallonpituus)
const float WAVE_LOG[WAVES] = float[](-1.203973, -0.867501, -0.531028, -0.194556, 0.141916, 0.478388, 0.814861, 1.151333, 1.487805, 1.824277, 2.160750, 2.497222);
// Aaltoryhmät (verhokäyrä), kuten waves.gd
const float GROUP_LEN[2] = float[](23.0, 37.0);
const float GROUP_SHARE[2] = float[](0.6, 0.4);
const float GROUP_DEPTH = 0.7;
const float WARP_AMOUNT = 1.6;
const float BAND = 0.5596;
const float TAIL = 0.35;
const float SCALE = 1.0;
const float FETCH_MAX = 4096.0;
const float MAX_SHARP = 0.75;
const float FADE_START = 0.8;

// Paikallinen aallokko (Hs, L) tuulesta ja pyyhkäisymatkasta (JONSWAP)
vec2 sea_state(float u, float fetch_m) {
	float uu = max(u, 0.5);
	float hs = 0.0016 * uu * sqrt(fetch_m / GRAVITY);
	hs = min(hs, 0.243 * uu * uu / GRAVITY);
	float tp = 0.286 * pow(GRAVITY * fetch_m / (uu * uu), 1.0 / 3.0) * uu / GRAVITY;
	tp = min(tp, 7.14 * uu / GRAVITY);
	float lp = GRAVITY * tp * tp / TAU;
	hs *= smoothstep(0.8, 2.0, u) * SCALE;
	return vec2(hs, max(lp * SCALE, 0.05));
}

float fetch_enc(sampler2D t0, sampler2D t1, float m, vec2 p) {
	vec2 uv = (p - fetch_rect.xy) / fetch_rect.zw;
	return mix(textureLod(t0, uv, 0.0).r, textureLod(t1, uv, 0.0).r, m);
}

// Kummankin suuntasarjan aallokko kohdassa p: (Hs A, L A, Hs B, L B)
vec4 local_sea(vec2 p) {
	vec2 a = vec2(0.0, 1.0);
	vec2 b = vec2(0.0, 1.0);
	if (set_weight.x > 0.0) {
		float e = fetch_enc(fetch_a0, fetch_a1, fetch_mix.x, p);
		a = sea_state(wave_wind, FETCH_MAX * e * e);
	}
	if (set_weight.y > 0.0) {
		float e = fetch_enc(fetch_b0, fetch_b1, fetch_mix.y, p);
		b = sea_state(wave_wind, FETCH_MAX * e * e);
	}
	return vec4(a, b);
}

// Aallon j osuus paikallisesta aallokosta (ennen normitusta); loglp = ln L, inv_lp = 1 / L
float spec_weight(int j, float loglp, float inv_lp) {
	float x = (WAVE_LOG[j] - loglp) / BAND;
	float b = max(0.0, 1.0 - x * x);
	float r = WAVE_LEN[j] * inv_lp;
	return b * b + TAIL * r * smoothstep(0.25, 0.4, r) * (1.0 - smoothstep(0.6, 1.0, r));
}

// Aaltorintamat mutkittelevat: vaiheen poikkeutus ja sen kaltevuus (rad/m)
vec3 warp_phase(int j, vec2 x0) {
	vec4 w = wave_warp[j];
	float a1 = dot(x0, w.xy);
	float a2 = dot(x0, w.zw) + float(j) * 1.7;
	return WARP_AMOUNT * vec3(sin(a1) + sin(a2), w.xy * cos(a1) + w.zw * cos(a2));
}

vec2 wave_dir(int s, int j) {
	return s == 0 ? wave_dir_a[j] : wave_dir_b[j];
}

// Suuntasarjan amplitudikerroin ja Gerstner-terävyys: (c, q)
vec2 set_scale(float hs, float lp) {
	if (hs <= 0.0) {
		return vec2(0.0);
	}
	float loglp = log(lp);
	float inv_lp = 1.0 / lp;
	float norm = 0.0;
	float ka = 0.0;
	for (int j = 0; j < WAVES; j++) {
		float w = spec_weight(j, loglp, inv_lp);
		norm += w * w;
		ka += TAU / WAVE_LEN[j] * w;
	}
	if (norm < 1e-6) {
		return vec2(0.0);
	}
	float root = sqrt(norm);
	float c = hs * 0.35355339 / root * smoothstep(0.0, 0.3, root);
	float sharp = clamp((hs / lp - 0.02) * 20.0, 0.0, MAX_SHARP);
	return vec2(c, sharp / max(ka * c, 1e-6) / (set_weight.x + set_weight.y));
}

// Kummankin suuntasarjan (c, q) paikallisesta aallokosta (lasketaan verteksissä)
vec4 sea_scales(vec4 sea) {
	vec2 a = set_weight.x > 0.0 ? set_scale(sea.x, sea.y) : vec2(0.0);
	vec2 b = set_weight.y > 0.0 ? set_scale(sea.z, sea.w) : vec2(0.0);
	return vec4(a, b);
}

// Aallot, joiden osuus voi olla nollasta poikkeava: 0,25–1,75 × huippuaallonpituus
ivec2 wave_range(float loglp) {
	float base = (loglp + 1.203973) / 0.336472;
	return ivec2(clamp(int(floor(base - 4.12)), 0, WAVES - 1), clamp(int(ceil(base + 1.67)), 0, WAVES - 1));
}

// Aaltoryhmän verhokäyrä (keskimäärin 1 neliöllisesti): suurimmat aallot n. 1,5 × Hs
float group_envelope(vec2 x0, int s) {
	float e = 0.0;
	for (int g = 0; g < 2; g++) {
		e += GROUP_SHARE[g] * sin(TAU / GROUP_LEN[g] * dot(x0, wave_dir(s, WAVES + g)) - wave_phase[WAVES + g]);
	}
	return (1.0 + GROUP_DEPTH * e) / sqrt(1.0 + GROUP_DEPTH * GROUP_DEPTH * 0.26);
}

// Suuntasarjan s siirtymä (c, q: sea_scales). spacing = verkon verteksiväli:
// lyhyet aallot, joita verkko ei pysty esittämään, jätetään pois. Matalalla
// vain kaksi pääaaltoa.
vec3 set_displacement(vec2 x0, int s, float weight, float lp, float c, float q, float spacing) {
	vec3 d = vec3(0.0);
	if (weight <= 0.0 || c <= 0.0) {
		return d;
	}
	float env = group_envelope(x0, s);
	float loglp = log(lp);
	float inv_lp = 1.0 / lp;
	ivec2 range = wave_range(loglp);
	if (quality == 0) {
		range.x = clamp(int(floor((loglp + 1.203973) / 0.336472)), 0, WAVES - 2);
		range.y = range.x + 1;
	}
	for (int j = range.x; j <= range.y; j++) {
		float len = WAVE_LEN[j];
		float a = c * spec_weight(j, loglp, inv_lp) * weight * smoothstep(2.0 * spacing, 4.0 * spacing, len);
		if (a <= 0.0) {
			continue;
		}
		vec2 dir = wave_dir(s, j);
		float th = TAU / len * dot(x0, dir) - wave_phase[j] + warp_phase(j, x0).x;
		// Ryhmä muuttaa vain korkeutta: vaakasiirto ja harjan terävyys eivät kasva silmukalle
		d.y += a * env * sin(th);
		d.xz += dir * (q * a * cos(th));
	}
	return d;
}

// Lähiveden reunalla siirtymä häivytetään nollaan (kaukainen vesi on tasainen)
float near_fade(vec2 p) {
	vec2 d = abs(p - near_center);
	return 1.0 - smoothstep(FADE_START * near_radius, near_radius, max(d.x, d.y));
}

// Pinnan siirtymä (x, korkeus, z) siirtymättömässä kohdassa x0
vec3 wave_displacement(vec2 x0, vec4 sea, vec4 cq, float spacing) {
	vec3 d = set_displacement(x0, 0, set_weight.x, sea.y, cq.x, cq.y, spacing);
	d += set_displacement(x0, 1, set_weight.y, sea.w, cq.z, cq.w, spacing);
	return d * near_fade(x0);
}

// Pinnan korkeus maailman kohdassa p (kiintopisteiterointi kuten waves.gd)
float surface_height(vec2 p) {
	vec4 sea = local_sea(p);
	vec4 cq = sea_scales(sea);
	vec2 x0 = p;
	for (int i = 0; i < 3; i++) {
		x0 = p - wave_displacement(x0, sea, cq, 0.001).xz;
	}
	return wave_displacement(x0, sea, cq, 0.001).y;
}

// Suuntasarjan s osuus pinnan normaaliin ja korkeuteen. Aalto häivytetään, kun se
// on näytöllä muutaman pikselin kokoinen – muuten kaukaiset laineet välkkyvät.
// n: (Σ dx k a cos, Σ q k a sin, Σ dz k a cos), elev: (Σ a sin, Σ a, Σ k a),
// lost: häivytettyjen aaltojen kaltevuuden varianssi (karheudeksi)
void set_surface(vec2 x0, int s, float weight, float lp, float c, float q, float footprint, inout vec3 n, inout vec3 elev, inout float lost) {
	if (weight <= 0.0 || c <= 0.0) {
		return;
	}
	float env = group_envelope(x0, s);
	float loglp = log(lp);
	float inv_lp = 1.0 / lp;
	ivec2 range = wave_range(loglp);
	if (quality == 0) {
		// Matala: vain pääaallot (0,57–1,75 × L), lyhyiden aaltojen häntä jää pois
		range.x = clamp(int(floor((loglp + 1.203973) / 0.336472 - 1.67)), 0, WAVES - 1);
	}
	for (int j = range.x; j <= range.y; j++) {
		float len = WAVE_LEN[j];
		float a = c * spec_weight(j, loglp, inv_lp) * weight;
		if (a <= 0.0) {
			continue;
		}
		float k = TAU / len;
		elev.y += a;
		elev.z += k * a;
		float aa = 1.0 - smoothstep(len * 0.08, len * 0.3, footprint);
		lost += 0.5 * k * k * a * a * (1.0 - aa * aa);
		if (aa <= 0.0) {
			continue;
		}
		vec2 dir = wave_dir(s, j);
		vec3 warp = warp_phase(j, x0);
		float th = k * dot(x0, dir) - wave_phase[j] + warp.x;
		float sn = sin(th);
		// Kaltevuus: aaltovektori ja mutkittelun kaltevuus
		n.xz += (dir * k + warp.yz) * (a * env * aa * cos(th));
		n.y += q * k * a * aa * sn;
		elev.x += a * env * sn * aa;
	}
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
