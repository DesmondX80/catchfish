class_name Waves
## Sama aaltomalli kuin shaders/waves.gdshaderinc. Peli kuljettaa aikaa
## ja välittää sen shadereille, joten vene, koho, pyykit ja ankkuri keinuvat
## näkyvissä aalloissa.
##
## Aallokko lasketaan joka kohdassa tuulesta ja pyyhkäisymatkasta (kuinka
## pitkän matkan tuuli on puhaltanut veden yli, assets/lake/fetch.bin)
## JONSWAP-kasvukäyrillä: merkitsevä aallonkorkeus Hs ja huippuaallonpituus L.
## Pinta on 12 Gerstner-aallon summa. Aallonpituudet ovat kiinteät (0,3–12 m),
## ja kunkin aallon korkeus riippuu siitä, kuinka lähellä paikallista
## huippuaallonpituutta se on: selällä pidemmät aallot, suojassa lyhyet ja
## matalat. Gerstner-aallossa pinta liikkuu myös vaakasuunnassa, jolloin
## harjat terävöityvät ja pohjat levenevät.
##
## Tuulen kääntyessä yli TURN_LIMIT uusi aallokko kasvaa toiseen
## suuntasarjaan ja vanha vaimenee ristiin (TURN_TIME). Aallokon tuuli
## (wind) seuraa tuulen perusnopeutta pelin ajassa.

const GRAVITY := 9.81
const COMPONENTS := 12
## Aallonpituudet (m): 0,3 × 1,4^j
const LENGTHS: Array[float] = [0.3, 0.42, 0.588, 0.8232, 1.15248, 1.613472, 2.2588608, 3.16240512, 4.427367168, 6.1983140352, 8.67763964928, 12.148695508992]
## Suunta suhteessa tuuleen (rad, enintään ±40°), naapuriaallot eri puolilla
const OFFSETS: Array[float] = [0.1, -0.55, 0.45, -0.15, 0.6, -0.4, 0.2, -0.6, 0.35, -0.05, 0.5, -0.3]
## Vaiheet, jotta aallot eivät ole samassa tahdissa
const PHASES: Array[float] = [0.0, 2.1, 4.4, 1.3, 5.6, 3.0, 0.7, 4.9, 2.6, 5.2, 1.8, 3.7]
## Aaltoryhmät: pääaaltojen korkeus vaihtelee tuulen mukana kulkevina ryhminä,
## joten suurimmat aallot ovat noin 1,5 × Hs. Kaksi verhokäyrää: pituus (m),
## suunta suhteessa tuuleen (rad), osuus; nopeus on aaltojen ryhmänopeus.
const GROUP_LENGTHS: Array[float] = [23.0, 37.0]
const GROUP_OFFSETS: Array[float] = [0.15, -0.2]
const GROUP_SHARES: Array[float] = [0.6, 0.4]
const GROUP_PHASES: Array[float] = [0.5, 2.0]
const GROUP_DEPTH := 0.7
const GROUP_SPEED := 1.25 # m/s
const BAND := 0.5596 # ln(1,75): aallot 0,57–1,75 × huippuaallonpituus
const TAIL := 0.35 # lyhyiden aaltojen häntä huipun alapuolella
const SCALE := 1.0 # säätövakio kaikille suureille (Hs ja L)
const MAX_WIND := 15.0 # m/s
const FETCH_MAX := 4096.0 # m (fetch.bin)
const MAX_SHARP := 0.75 # Gerstner-terävyyden yläraja (1 = harja silmukalle)
## Aallonkorkeus 8 m/s tuulella 2 km selällä: local_strength = 1
const HS_REF := 0.183
## Kasvu ja laantuminen: 90 % uudesta tasosta 10 / 20 peliminuutissa
const GROW_TAU := 4.343 # peliminuuttia (10 / ln 10)
const DECAY_TAU := 8.686
const TURN_LIMIT := 0.349 # rad (20°)
const TURN_TIME := 60.0 # s, vanha suunta häivytetään ristiin uuteen
## Lähiveden reunalla siirtymä häivytetään nollaan (FADE_START × säde)
const FADE_START := 0.8

## Aallokon tuuli (m/s): seuraa tuulen perusnopeutta hitaasti (ei puuskia)
static var wind := 3.0
## Kaksi suuntasarjaa ristihäivytykseen: suunta (rad, johon tuuli puhaltaa) ja paino
static var set_angle := [0.0, 0.0]
static var set_weight := [1.0, 0.0]
static var active := 0
static var _fade := 1.0
static var time := 0.0
## Väreet ja puuskalaikut: tuulen perusnopeus, puuska ja laikkujen siirtymä
static var ripple_wind := 3.0
static var gust := 0.0
static var gust_offset := Vector2.ZERO
## Lähiveden keskipiste ja säde: siirtymä häivyy reunalla (INF = ei häivytystä)
static var near_center := Vector2.ZERO
static var near_radius := INF
static var lake: LakeData
## Pyyhkäisymatkat suunnittain tekstuureina varjostimelle
static var _fetch_textures: Array[ImageTexture] = []
static var _k := PackedFloat32Array()
static var _omega := PackedFloat32Array()
static var _phase := PackedFloat32Array()
static var _phase_time := NAN


## Järven pyyhkäisymatkat käyttöön (kutsutaan, kun järvi on ladattu)
static func setup(lake_data: LakeData) -> void:
	lake = lake_data
	_fetch_textures.clear()
	for plane in lake.fetch_planes:
		var img := Image.create_from_data(lake.fetch_cols, lake.fetch_rows, false, Image.FORMAT_R8, plane)
		_fetch_textures.append(ImageTexture.create_from_image(img))


static func _init_tables() -> void:
	if _k.size() == COMPONENTS:
		return
	# Aaltojen jälkeen kaksi aaltoryhmien verhokäyrää
	_k.resize(COMPONENTS + 2)
	_omega.resize(COMPONENTS + 2)
	_phase.resize(COMPONENTS + 2)
	for j in COMPONENTS:
		_k[j] = TAU / LENGTHS[j]
		_omega[j] = sqrt(GRAVITY * _k[j])
	for g in 2:
		_k[COMPONENTS + g] = TAU / GROUP_LENGTHS[g]
		_omega[COMPONENTS + g] = _k[COMPONENTS + g] * GROUP_SPEED


## Aaltojen vaiheet ajanhetkellä time (64-bittisenä, ei hyppäystä tunnin välein)
static func _phases() -> PackedFloat32Array:
	_init_tables()
	if time != _phase_time:
		_phase_time = time
		for j in COMPONENTS:
			_phase[j] = fmod(_omega[j] * time + PHASES[j], TAU)
		for g in 2:
			_phase[COMPONENTS + g] = fmod(_omega[COMPONENTS + g] * time + GROUP_PHASES[g], TAU)
	return _phase


## Aallokko heti tuulen mukaiseksi (pelin alku, todellisen sään ensimmäinen havainto)
static func reset(wind_base: float, wind_direction: float) -> void:
	wind = clampf(wind_base, 0.0, MAX_WIND)
	active = 0
	set_angle = [wind_direction, wind_direction]
	set_weight = [1.0, 0.0]
	_fade = 1.0


## Ruudun päivitys: aallokon kasvu pelin ajassa, tuulen kääntyminen ja aika
static func step(delta: float, wind_base: float, wind_direction: float, gust_now: float, time_scale: float) -> void:
	var target := clampf(wind_base, 0.0, MAX_WIND)
	var tau := GROW_TAU if target > wind else DECAY_TAU
	wind += (target - wind) * (1.0 - exp(-delta * time_scale / 60.0 / tau))
	# Uusi suuntasarja vasta, kun edellinen ristihäivytys on valmis
	if _fade >= 1.0 and absf(angle_difference(set_angle[active], wind_direction)) > TURN_LIMIT:
		active = 1 - active
		set_angle[active] = wind_direction
		_fade = 0.0
	_fade = minf(1.0, _fade + delta / TURN_TIME)
	# Painot sinillä ja kosinilla: aallokon energia ei notkahda kesken häivytyksen
	set_weight[active] = sin(_fade * PI / 2.0)
	set_weight[1 - active] = cos(_fade * PI / 2.0) if _fade < 1.0 else 0.0
	ripple_wind = wind_base
	gust = gust_now
	# Puuskalaikut kulkevat tuulen mukana tuulta hitaammin
	gust_offset += Vector2(sin(wind_direction), -cos(wind_direction)) * (wind_base + gust_now) * 0.5 * delta
	gust_offset = Vector2(fposmod(gust_offset.x, 7168.0), fposmod(gust_offset.y, 7168.0))
	time += delta


## Paikallinen aallokko tuulesta (m/s) ja pyyhkäisymatkasta (m): (Hs, L) metreinä
static func sea_state(u: float, fetch_m: float) -> Vector2:
	var uu := maxf(u, 0.5)
	var hs := 0.0016 * uu * sqrt(fetch_m / GRAVITY)
	hs = minf(hs, 0.243 * uu * uu / GRAVITY) # täysin kehittynyt aallokko
	var tp := 0.286 * pow(GRAVITY * fetch_m / (uu * uu), 1.0 / 3.0) * uu / GRAVITY
	tp = minf(tp, 7.14 * uu / GRAVITY)
	var lp := GRAVITY * tp * tp / TAU
	# Alle 1 m/s tuulella ei synny aaltoja
	hs *= smoothstep(0.8, 2.0, u) * SCALE
	return Vector2(hs, maxf(lp * SCALE, 0.05))


## Pyyhkäisymatka (m) suuntasarjalle s kohdassa p, kuten varjostin sen näkee
## (bilineaarinen 16 m:n ruudukossa, kahden lähimmän suunnan välillä)
static func set_fetch(s: int, p: Vector2) -> float:
	if lake == null or lake.fetch_planes.is_empty():
		return 2000.0 # ei järveä: avoin selkä
	var di := wrapf(set_angle[s], 0.0, TAU) / (TAU / lake.fetch_dirs)
	var i0 := floori(di) % lake.fetch_dirs
	var f := di - floorf(di)
	var e := lerpf(_fetch_bilinear(i0, p), _fetch_bilinear((i0 + 1) % lake.fetch_dirs, p), f)
	return FETCH_MAX * e * e


static func _fetch_bilinear(plane: int, p: Vector2) -> float:
	var data: PackedByteArray = lake.fetch_planes[plane]
	var fx := (p.x - lake.origin_x) / lake.fetch_cell - 0.5
	var fz := (p.y - lake.origin_z) / lake.fetch_cell - 0.5
	var c := floori(fx)
	var r := floori(fz)
	var tx := fx - c
	var tz := fz - r
	var w := lake.fetch_cols
	var c0 := clampi(c, 0, w - 1)
	var c1 := clampi(c + 1, 0, w - 1)
	var r0 := clampi(r, 0, lake.fetch_rows - 1)
	var r1 := clampi(r + 1, 0, lake.fetch_rows - 1)
	var top := lerpf(data[r0 * w + c0], data[r0 * w + c1], tx)
	var bottom := lerpf(data[r1 * w + c0], data[r1 * w + c1], tx)
	return lerpf(top, bottom, tz) / 255.0


## Aallon osuus paikallisesta aallokosta (ennen normitusta)
static func _weight(length: float, lp: float) -> float:
	var x := log(length / lp) / BAND
	var b := maxf(0.0, 1.0 - x * x)
	var r := length / lp
	return b * b + TAIL * r * smoothstep(0.25, 0.4, r) * (1.0 - smoothstep(0.6, 1.0, r))


## Kohdan p aallot: [indeksi, suunta, amplitudi, vaakasiirron amplitudi,
## suuntasarja] jokaiselle aallolle, jonka korkeus ei ole nolla
static func _components(p: Vector2) -> Array:
	_init_tables()
	var out := []
	var wsum: float = set_weight[0] + set_weight[1]
	for s in 2:
		var weight: float = set_weight[s]
		if weight <= 0.0:
			continue
		var sea := sea_state(wind, set_fetch(s, p))
		if sea.x <= 0.0:
			continue
		var norm := 0.0
		var ka := 0.0
		var w := PackedFloat32Array()
		w.resize(COMPONENTS)
		for j in COMPONENTS:
			w[j] = _weight(LENGTHS[j], sea.y)
			norm += w[j] * w[j]
			ka += _k[j] * w[j]
		if norm < 1e-6:
			continue
		var root := sqrt(norm)
		var c := sea.x * 0.35355339 / root * smoothstep(0.0, 0.3, root)
		# Terävyys jyrkkyyden mukaan: heikolla tuulella pyöreähköt, kovalla terävät harjat
		var sharp := clampf((sea.x / sea.y - 0.02) * 20.0, 0.0, MAX_SHARP)
		var q := sharp / maxf(ka * c, 1e-6) / wsum
		for j in COMPONENTS:
			if w[j] <= 0.0:
				continue
			var a: float = c * w[j] * weight
			var ang: float = set_angle[s] + OFFSETS[j]
			out.append([j, Vector2(sin(ang), -cos(ang)), a, q * a, s])
	return out


## Lähiveden reunan häivytys (sama kuin varjostimessa)
static func near_fade(p: Vector2) -> float:
	if is_inf(near_radius):
		return 1.0
	var d := (p - near_center).abs()
	return 1.0 - smoothstep(FADE_START * near_radius, near_radius, maxf(d.x, d.y))


## Aaltoryhmän verhokäyrä suuntasarjalle s kohdassa x0 (keskimäärin 1 neliöllisesti)
static func group_envelope(s: int, x0: Vector2, phase: PackedFloat32Array) -> float:
	var e := 0.0
	for g in 2:
		var ang: float = set_angle[s] + GROUP_OFFSETS[g]
		e += GROUP_SHARES[g] * sin(_k[COMPONENTS + g] * x0.dot(Vector2(sin(ang), -cos(ang))) - phase[COMPONENTS + g])
	return (1.0 + GROUP_DEPTH * e) / sqrt(1.0 + GROUP_DEPTH * GROUP_DEPTH * 0.26)


static func _displacement(x0: Vector2, comps: Array, phase: PackedFloat32Array) -> Vector3:
	var d := Vector3.ZERO
	var env := [group_envelope(0, x0, phase) if set_weight[0] > 0.0 else 0.0, group_envelope(1, x0, phase) if set_weight[1] > 0.0 else 0.0]
	for c in comps:
		var j: int = c[0]
		var dir: Vector2 = c[1]
		var th := _k[j] * x0.dot(dir) - phase[j]
		# Ryhmä muuttaa vain korkeutta: vaakasiirto ja harjan terävyys eivät kasva silmukalle
		d.y += c[2] * env[c[4]] * sin(th)
		var h: float = c[3] * cos(th)
		d.x += dir.x * h
		d.z += dir.y * h
	return d * near_fade(x0)


## Pinnan siirtymä (x, korkeus, z) siirtymättömässä kohdassa x0
static func displacement(x0: Vector2) -> Vector3:
	return _displacement(x0, _components(x0), _phases())


## Pinnan korkeus maailman kohdassa p. Gerstner-pinta liikkuu myös sivuttain,
## joten etsitään kohta x0, joka siirtyy p:hen (kiintopisteiterointi).
static func swell_height(p: Vector2) -> float:
	var comps := _components(p)
	if comps.is_empty():
		return 0.0
	var phase := _phases()
	var x0 := p
	for i in 3:
		var d := _displacement(x0, comps, phase)
		x0 = p - Vector2(d.x, d.z)
	return _displacement(x0, comps, phase).y


## Paikallinen merkitsevä aallonkorkeus (m) kohdassa p
static func local_hs(p: Vector2) -> float:
	var e := 0.0
	for s in 2:
		var weight: float = set_weight[s]
		if weight > 0.0:
			var hs := sea_state(wind, set_fetch(s, p)).x * weight
			e += hs * hs
	return sqrt(e)


## Paikallinen aallokko 0–1 (1 = 8 m/s tuuli 2 km selällä): äänet ja kohon keinunta
static func local_strength(p: Vector2) -> float:
	return clampf(local_hs(p) / HS_REF, 0.0, 1.0)


## Aseta shaderin aaltoparametrit
static func apply(material: ShaderMaterial) -> void:
	material.set_shader_parameter("wave_wind", wind)
	material.set_shader_parameter("set_angle", Vector2(set_angle[0], set_angle[1]))
	material.set_shader_parameter("set_weight", Vector2(set_weight[0], set_weight[1]))
	material.set_shader_parameter("wave_phase", _phases())
	material.set_shader_parameter("wave_time", fmod(time, 3600.0))
	material.set_shader_parameter("ripple_wind", ripple_wind)
	material.set_shader_parameter("gust", gust)
	material.set_shader_parameter("gust_offset", gust_offset)
	material.set_shader_parameter("near_center", near_center)
	material.set_shader_parameter("near_radius", 1.0e6 if is_inf(near_radius) else near_radius)
	material.set_shader_parameter("quality", 1 if Settings.water_quality == "korkea" else 0)
	if lake == null or _fetch_textures.is_empty():
		return
	material.set_shader_parameter("fetch_rect", Vector4(lake.origin_x, lake.origin_z, lake.fetch_cols * lake.fetch_cell, lake.fetch_rows * lake.fetch_cell))
	var mix := Vector2.ZERO
	for s in 2:
		var di := wrapf(set_angle[s], 0.0, TAU) / (TAU / lake.fetch_dirs)
		var i0 := floori(di) % lake.fetch_dirs
		material.set_shader_parameter("fetch_%s0" % ["a", "b"][s], _fetch_textures[i0])
		material.set_shader_parameter("fetch_%s1" % ["a", "b"][s], _fetch_textures[(i0 + 1) % lake.fetch_dirs])
		mix[s] = di - floorf(di)
	material.set_shader_parameter("fetch_mix", mix)
