shader_type spatial;
// Mökin vanhan kuvaputki-TV:n ruutu: pyörivä kalastusohjelma. Kolme kuvaa
// vuorottelee leikkauksin (LOOP sekunnin kierto):
//   1. veneilijä iltajärvellä, vapa taipuu tärpistä
//   2. lähikuva kohosta, joka nykii ja painuu pinnan alle
//   3. hauki hyppää pinnasta roiskeineen
// Päällä kuvaputken kaarevuus, juovat, kohina ja kanavan logo.
// Valoa hehkuva, ei valaistu.
render_mode unshaded;

const float LOOP = 24.0;
const float SHOT = 8.0;
uniform float brightness = 1.0;
uniform float time = 0.0; // ohjelman kello (CabinScene päivittää, jotta TV:n valo osuu leikkauksiin)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float box(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float ellipse(vec2 p, vec2 c, vec2 r) {
	return (length((p - c) / r) - 1.0) * min(r.x, r.y);
}

// Etäisyys janaan ab
float segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// Etäisyys toisen asteen Bézier-käyrään (näytteistämällä, riittää siimoille)
float curve(vec2 p, vec2 a, vec2 c, vec2 b) {
	float d = 1e3;
	vec2 prev = a;
	for (int i = 1; i <= 12; i++) {
		float t = float(i) / 12.0;
		vec2 q = mix(mix(a, c, t), mix(c, b, t), t);
		d = min(d, segment(p, prev, q));
		prev = q;
	}
	return d;
}

float fill(float d, float aa) {
	return 1.0 - smoothstep(0.0, aa, d);
}

vec3 sky(vec2 uv, float horizon) {
	float k = clamp((uv.y - horizon) / (1.0 - horizon), 0.0, 1.0);
	return mix(vec3(1.0, 0.62, 0.32), vec3(0.32, 0.42, 0.68), pow(k, 0.7));
}

float tree_line(float x) {
	float h = 0.0;
	for (int i = 0; i < 3; i++) {
		float f = 9.0 + float(i) * 13.7;
		h += abs(sin(x * f + float(i) * 2.3)) * (0.03 / (1.0 + float(i) * 0.5));
	}
	return h + max(0.0, sin(x * 53.0) * 0.5 + 0.2) * 0.025;
}

// 1. Veneilijä iltajärvellä
vec3 shot_boat(vec2 uv, float t) {
	float horizon = 0.55;
	vec3 col = sky(uv, horizon);
	vec2 sun = vec2(0.72, 0.66);
	col += vec3(1.0, 0.75, 0.4) * fill(length(uv - sun) - 0.06, 0.01);
	col += vec3(0.6, 0.35, 0.15) * exp(-length(uv - sun) * 6.0) * 0.6;
	if (uv.y < horizon + tree_line(uv.x * 0.8 + 0.3)) {
		col = vec3(0.12, 0.1, 0.12);
	}
	if (uv.y < horizon) {
		// Vesi heijastaa taivasta, auringon kimallus pystyjuovana
		col = mix(vec3(0.35, 0.3, 0.38), vec3(0.85, 0.55, 0.35), smoothstep(0.0, horizon, uv.y) * 0.7);
		float wave = sin(uv.y * 220.0 / (uv.y + 0.08) * 0.05 + t * 2.0 + uv.x * 6.0);
		float glitter = exp(-abs(uv.x - sun.x) * 18.0) * step(0.55, wave);
		col += vec3(1.0, 0.8, 0.45) * glitter * 0.6;
		col *= 0.9 + 0.1 * wave;
	}
	// Vene keinuu, kalastaja seisoo vapa kädessä
	float bob = sin(t * 1.6) * 0.006;
	float tilt = sin(t * 1.3) * 0.03;
	vec2 bp = uv - vec2(0.38, 0.44 + bob);
	bp = mat2(vec2(cos(tilt), -sin(tilt)), vec2(sin(tilt), cos(tilt))) * bp;
	float hull = box(bp, vec2(0.0, 0.0), vec2(0.16 - max(0.0, -bp.y) * 1.6, 0.025));
	float body = box(bp, vec2(0.04, 0.085), vec2(0.022, 0.06));
	float head = length(bp - vec2(0.04, 0.165)) - 0.022;
	float cap = box(bp, vec2(0.05, 0.185), vec2(0.03, 0.007));
	float man = min(min(hull, body), min(head, cap));
	// Tärppi viiden sekunnin kohdalla: vapa taipuu ja nykii
	float strike = smoothstep(4.6, 5.0, t) * (0.7 + 0.3 * sin(t * 18.0));
	vec2 hand = vec2(0.07, 0.11);
	vec2 tip = hand + vec2(0.17, 0.16 - strike * 0.11);
	vec2 bend = hand + vec2(0.1, 0.13 - strike * 0.02);
	float rod = curve(bp, hand, bend, tip) - 0.002;
	vec2 lure = vec2(0.32 + strike * 0.03, -0.06);
	float line = curve(bp, tip, mix(tip, lure, 0.5) + vec2(0.0, -0.04 * (1.0 - strike)), lure) - 0.0007;
	vec3 silhouette = vec3(0.06, 0.05, 0.07);
	col = mix(col, silhouette, fill(man, 0.003));
	col = mix(col, silhouette, fill(rod, 0.002));
	col = mix(col, vec3(0.75, 0.7, 0.6), fill(line, 0.002) * 0.6);
	// Siiman kohdalla väreilevät renkaat
	float ring = abs(length((bp - lure) * vec2(1.0, 4.0)) - fract(t * 0.8) * 0.06);
	col += vec3(0.5, 0.4, 0.3) * fill(ring - 0.002, 0.003) * (1.0 - fract(t * 0.8)) * step(bp.y, lure.y + 0.01);
	return col;
}

// 2. Lähikuva kohosta
vec3 shot_float(vec2 uv, float t) {
	// Vesi ylhäältä viistosti: tummuu kaukana, väreet liikkuvat
	vec3 col = mix(vec3(0.1, 0.2, 0.22), vec3(0.3, 0.42, 0.42), uv.y);
	float ripples = sin(uv.x * 30.0 + sin(uv.y * 12.0 + t) * 2.0 + t * 1.5) * sin(uv.y * 50.0 - t * 2.2);
	col += vec3(0.25, 0.3, 0.28) * smoothstep(0.6, 1.0, ripples) * 0.5;
	// Kohon liike: lepo, varovaiset nykäisyt, sitten painuu pinnan alle
	float dip = smoothstep(3.0, 3.1, t) * (1.0 - smoothstep(3.3, 3.5, t)) * 0.03
		+ smoothstep(4.4, 4.5, t) * (1.0 - smoothstep(4.7, 4.9, t)) * 0.04
		+ smoothstep(5.6, 5.9, t) * 0.25;
	float bob = sin(t * 2.4) * 0.008;
	vec2 c = vec2(0.5, 0.45 + bob - dip);
	float waterline = 0.45 + sin(uv.x * 18.0 + t * 2.0) * 0.004;
	// Rengasaallot kohon ympärillä, isot kun koho painuu
	float r = length((uv - vec2(0.5, 0.45)) * vec2(1.0, 3.2));
	float waves = 0.0;
	for (int i = 0; i < 3; i++) {
		float age = fract(t * 0.5 + float(i) / 3.0);
		waves += fill(abs(r - age * 0.35) - 0.004, 0.006) * (1.0 - age);
	}
	float sunk = smoothstep(5.6, 6.2, t);
	col += vec3(0.5, 0.55, 0.5) * waves * (0.35 + sunk * 0.8);
	// Koho: punainen yläosa, valkoinen vyö, antenni; vain pinnan yläpuoli näkyy
	float above = step(waterline, uv.y);
	float stick = box(uv, c + vec2(0.0, 0.1), vec2(0.004, 0.05));
	float top = ellipse(uv, c + vec2(0.0, 0.035), vec2(0.035, 0.05));
	float belt = ellipse(uv, c, vec2(0.04, 0.025));
	col = mix(col, vec3(0.9, 0.9, 0.85), fill(belt, 0.004) * above);
	col = mix(col, vec3(0.9, 0.12, 0.08), fill(top, 0.004) * above);
	col = mix(col, vec3(0.95, 0.85, 0.2), fill(stick, 0.003) * above);
	// Kohon heijastus veden alla
	vec2 m = vec2(uv.x, 2.0 * waterline - uv.y);
	float refl = min(ellipse(m, c + vec2(0.0, 0.035), vec2(0.035, 0.05)), ellipse(m, c, vec2(0.04, 0.025)));
	col = mix(col, vec3(0.5, 0.15, 0.12), fill(refl, 0.01) * (1.0 - above) * 0.35 * (1.0 + ripples * 0.3));
	// Siima ylhäältä
	float line = segment(uv, c + vec2(0.0, 0.15), vec2(0.62, 1.0)) - 0.0008;
	col = mix(col, vec3(0.8, 0.8, 0.75), fill(line, 0.002) * 0.6 * step(waterline, uv.y));
	return col;
}

// 3. Hauki hyppää pinnasta
vec3 shot_jump(vec2 uv, float t) {
	float horizon = 0.62;
	vec3 col = sky(uv, horizon) * vec3(0.9, 1.0, 1.15);
	if (uv.y < horizon + tree_line(uv.x + 1.7) * 0.7) {
		col = vec3(0.1, 0.16, 0.12);
	}
	if (uv.y < horizon) {
		col = mix(vec3(0.16, 0.24, 0.3), vec3(0.45, 0.5, 0.58), smoothstep(0.0, horizon, uv.y));
		col *= 0.92 + 0.08 * sin(uv.y * 140.0 + uv.x * 5.0 + t * 2.0);
	}
	float water = 0.3;
	// Hyppykaari 2.0–3.4 s, toinen pienempi hyppy 5.2–6.2 s
	float j1 = clamp((t - 2.0) / 1.4, 0.0, 1.0);
	float j2 = clamp((t - 5.2) / 1.0, 0.0, 1.0);
	bool second = t > 4.5;
	float k = second ? j2 : j1;
	float height = second ? 0.2 : 0.34;
	vec2 start = second ? vec2(0.5, water - 0.05) : vec2(0.25, water - 0.05);
	vec2 end = start + vec2(second ? 0.2 : 0.35, 0.0);
	vec2 fp = mix(start, end, k) + vec2(0.0, sin(k * 3.14159) * height);
	float angle = cos(k * 3.14159) * 0.9; // nokka ylös noustessa, alas laskiessa
	if (k > 0.0 && k < 1.0) {
		vec2 q = uv - fp;
		q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * q;
		float body = ellipse(q, vec2(0.0), vec2(0.11, 0.025));
		float tail = box(q, vec2(-0.13, 0.0), vec2(0.022, 0.03 - (q.x + 0.15) * 0.4));
		float fish = min(body, tail);
		vec3 skin = mix(vec3(0.2, 0.3, 0.12), vec3(0.75, 0.75, 0.55), smoothstep(0.01, -0.02, q.y));
		// Hauen vaaleat täplät kyljessä
		vec2 cell = q * vec2(80.0, 110.0);
		float spot = step(length(fract(cell) - 0.5), 0.3) * step(0.45, hash(floor(cell)));
		skin = mix(skin, vec3(0.8, 0.82, 0.55), spot * step(-0.012, q.y) * 0.7);
		col = mix(col, skin, fill(fish, 0.003));
		col = mix(col, vec3(0.05), fill(length(q - vec2(0.085, 0.006)) - 0.004, 0.002)); // silmä
	}
	// Roiskeet ja renkaat hypyn alussa ja lopussa
	for (int s = 0; s < 4; s++) {
		vec2 at = s == 0 ? vec2(0.25, water) : s == 1 ? vec2(0.6, water) : s == 2 ? vec2(0.5, water) : vec2(0.7, water);
		float t0 = s == 0 ? 2.0 : s == 1 ? 3.4 : s == 2 ? 5.2 : 6.2;
		float age = (t - t0) / 1.5;
		if (age > 0.0 && age < 1.0) {
			float rr = length((uv - at) * vec2(1.0, 4.0));
			col += vec3(0.7, 0.75, 0.8) * fill(abs(rr - age * 0.15) - 0.003, 0.005) * (1.0 - age);
			for (int d = 0; d < 7; d++) {
				float dx = (hash(vec2(float(d), float(s))) - 0.5) * 0.12;
				float vy = 0.35 + hash(vec2(float(s), float(d) + 7.0)) * 0.4;
				float tt = age * 1.5;
				vec2 drop = at + vec2(dx * tt * 3.0, vy * tt - 1.6 * tt * tt);
				if (drop.y > water - 0.01) {
					col += vec3(0.8, 0.85, 0.9) * fill(length(uv - drop) - 0.006, 0.004);
				}
			}
		}
	}
	return col;
}

void fragment() {
	// Kuvaputken kaarevuus: kulmat taipuvat, reunan yli musta
	vec2 p = UV * 2.0 - 1.0;
	p *= 1.0 + dot(p, p) * vec2(0.06, 0.08);
	vec2 uv = p * 0.5 + 0.5;
	uv.y = 1.0 - uv.y; // y ylös
	float t = mod(time, LOOP);
	int shot = int(t / SHOT);
	float st = t - float(shot) * SHOT;
	vec3 col;
	if (shot == 0) {
		col = shot_boat(uv, st);
	} else if (shot == 1) {
		col = shot_float(uv, st);
	} else {
		col = shot_jump(uv, st);
	}
	// Kanavan logo vasemmassa yläkulmassa: pieni kala
	vec2 lp = (uv - vec2(0.1, 0.88)) * vec2(1.0, 1.3);
	float logo = min(ellipse(lp, vec2(0.0), vec2(0.035, 0.014)), box(lp, vec2(-0.043, 0.0), vec2(0.01, 0.016 - (lp.x + 0.05) * 0.5)));
	col = mix(col, vec3(1.0, 0.95, 0.8), fill(logo, 0.004) * 0.75);
	// Leikkauksen kohdalla hetken kohinaa ja kuvan hyppäys
	float cut = 1.0 - smoothstep(0.0, 0.18, st);
	float noise = hash(floor(uv * vec2(160.0, 120.0)) + floor(time * 30.0));
	col = mix(col, vec3(noise), cut * 0.8);
	col += (noise - 0.5) * 0.06;
	// Juovat, vierivä kirkkausraita ja himmeät reunat
	// Juovat häivytetään kaukaa katsottaessa, ettei synny moiré-kuviota
	float lines = 480.0 * uv.y;
	col *= 1.0 - 0.16 * (0.5 + 0.5 * sin(lines)) * (1.0 - smoothstep(0.3, 0.8, fwidth(lines)));
	col *= 0.95 + 0.05 * sin(uv.y * 6.0 - time * 3.0);
	col *= 1.0 - dot(p, p) * 0.25;
	float inside = step(abs(p.x), 1.0) * step(abs(p.y), 1.0);
	ALBEDO = col * inside * brightness;
}
