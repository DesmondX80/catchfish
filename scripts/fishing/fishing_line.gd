class_name FishingLine
extends RefCounted
## Siima (CATCHFISH-86): siiman arvot yhdessä paikassa ja näkyvä siimamalli.
##
## Pelilogiikka (Fishing: line_out, tension, _constrain_lure, _fight) päättää,
## missä uistin tai kala on ja kuinka paljon siimaa on ulkona. Tämä malli on
## sen päällä näkyvä siima: pistemassaketju (Verlet), jonka ensimmäinen piste
## on vavan kärjessä ja viimeinen siiman päässä. Malli ei siirrä uistinta eikä
## muuta jännitystä.
##
## - Voimat: paino, ilmanvastus ja tuuli; vedessä veden vastus. Pinnalle
##   osunut siima lepää aaltopinnalla (Waves.swell_height) ja liikkuu kitkan
##   hidastamana. Maalla siima lepää maan pinnalla, eikä se mene pohjan alle.
## - Pituusrajoitteet iteroidaan ja lisäksi jokainen piste rajataan vavan
##   kärjestä ja siiman päästä enintään sen siimamatkan päähän ("pitkät
##   rajoitteet"), joten kireä siima on suora eikä värise.
## - Siimaa kelattaessa tai jarrun antaessa siimaa pituus muuttuu vavan
##   päästä: ensimmäinen väli venyy tai lyhenee, ja välillä pisteet jaetaan
##   tasaisesti uudelleen vanhaa muotoa pitkin.
## - Siima kiertää veneen laidan yli (rungon muoto Boat._hull_at).
## - Jäällä ketju alkaa avannosta (vavan kärjestä avantoon suora pätkä), ja
##   jään alla siima pysyy jään alapinnan alla.
## - Katkennut pätkä: viimeinen piste on vapaa.

# --- Siiman arvot (linjaus 9: pelissä yksi siima; CATCHFISH-63 voi tehdä
# siitä vaihdettavan) ---------------------------------------------------------
const NAME := "0,28 mm monofiili"
const DIAMETER := 0.00028 # m
const STRENGTH := 6.5 # kg
const MASS := 0.00007 # kg/m (nailon 1,14 g/cm³)
const COLOR := Color(0.52, 0.70, 0.92) # läpikuultava vaalea sinertävä
const OPACITY := 0.75
## Venymä lujuuden kuormalla: vain ulkoasu (linjaus 1), ei vaikuta väsytykseen
const STRETCH := 0.15
## Nykäyskuorma (linjaus 2): jarrun lähtökitka S, vavan läpi menevä osa
## nykäyksestä K (kelatessa kampi lukitsee kelan), vaimenemisen aikavakio ja
## pinnassa rimpuilun lisäveto (· paino · power)
const SHOCK_STARTUP := 0.25
const SHOCK_ROD := 0.4
const SHOCK_ROD_REELING := 0.6
const SHOCK_TAU := 0.2 # s
const SHOCK_SPLASH := 0.5
## Katkenneen siiman pätkä vavan kärjessä (m)
const SNAP_PIECE := 2.5

# --- Simulaatio ---------------------------------------------------------------
const POINTS := 32
const ITERATIONS := 6 # nopeissa tilanteissa (lento, väsytys)
const ITERATIONS_CALM := 4 # muuten (min_dt > 0)
const GRAVITY := 9.81
const AIR_TAU := 0.3 # s: ilmanvastus (putoamisnopeus noin 3 m/s)
const AIR_WIND := 0.3 # tuulen osuus siiman korkeudella (tuulikaari, vain ulkoasu)
const WATER_TAU := 0.12 # s: veden vastus pinnan alla
const SURFACE_TAU := 0.5 # s: pinnalla lepäävän siiman kitka
const SURFACE_DRIFT := 0.02 # pinnalla lepäävä siima kulkeutuu tuulen mukana hitaasti
## Lepokitka: pinnalla tai maassa levossa oleva siima pysyy paikallaan, kunnes
## siima vetää sitä (välin venymä yli STICK_STRETCH) tai pintavirta kuljettaa
const STICK_SPEED := 0.05 # m/s
const STICK_STRETCH := 0.01
const RISE_SPEED := 0.05 # m/s: löysä siima nousee pinnan alta takaisin pintaan
const FLOAT_BAND := 0.05 # m: pinnan alla näin lähellä oleva märkä siima kelluu pinnassa
const LIFT := 0.02 # m: näin paljon pinnan yläpuolelle vedetty piste irtoaa pinnasta
const GROUND_TAU := 0.04 # s: maalla siima pysähtyy nopeasti
## Taivutusjäykkyys: ketju taittuu pisteessä enintään tämän verran (piirretty
## käyrä jakaa taitteen pehmeäksi kaareksi)
const MAX_ANGLE := deg_to_rad(12.0)
## Pinnalla ja maassa lepäävä siima liikkuu vedettäessä hitaammin (kitka):
## pituusrajoitteen korjauksesta sille tulee tämä osuus
const REST_WEIGHT := 0.15
const SMOOTH := 0.1 # tasoitus askelta kohti (vapaat pisteet)
const JUMP := 6.0 # m: tätä isompi hyppy päässä aloittaa ketjun alusta (siirto)
const SAMPLES_PER_STEP := 4 # pinnan korkeuden uudet näytteet askelta kohti (kiertävästi)
const ICE_BOTTOM := -0.05 # jään alapinta siiman kannalta
const HOLE_RADIUS := 0.075 # avannon säde
const HULL_MARGIN := 0.05 # m: siima kulkee laidan ja reunalistan ulkopuolelta (myös keinuessa)
const CONTACT_STEPS := 20 # askelta: laidalla ollut piste saa taittua vielä hetken
const SHORT := 0.5 # m: tätä lyhyempi kiinnitetty siima on suora (uistin vavan kärjessä)

var lake: LakeData
var boat: Boat

## Pisteet maailmassa; pos[0] vavan kärjessä (jäällä avannossa)
var pos := PackedVector3Array()
var prev := PackedVector3Array()
## Välien lepopituudet ja kertymä ensimmäisestä pisteestä (siimamatka)
var rest := PackedFloat32Array()
var arc := PackedFloat32Array()
var length := 0.0
## Katkennut pätkä: viimeinen piste on vapaa
var free_end := false
## Vedessä käynyt piste (kelluu pinnassa tai on pinnan alla)
var wet := PackedByteArray()
## Laidan yli kulkeva piste (piirrossa saa olla taite)
var contact := PackedByteArray()
## Ympäristö pisteittäin: vettä (1) vai maata/jäätä (0), pinnan korkeus ja sen
## muutosnopeus (aallot), pohjan tai maan korkeus
var water := PackedByteArray()
var surf := PackedFloat32Array()
var surf_rate := PackedFloat32Array()
var surf_time := PackedFloat32Array()
var surf_sample := PackedFloat32Array()
var surf_acc := PackedFloat32Array()
var ground := PackedFloat32Array()
var ground_xz := PackedVector2Array()
var initialized := false
## Suora lyhyt siima (piirretään yhtenä välinä)
var straight := false
## Seuraava pituuden muutos tasaisesti kaikkiin väleihin (heiton
## laskeutuminen: löysä siima jakautuu lentoreitille), muuten vavan päästä
var uniform := false
## Pienin simulaatioaskel: hitaasti liikkuva siima (uistin vedessä, vapa
## telineessä) simuloidaan harvemmin, kärki seuraa silti joka ruudussa
var min_dt := 0.0
var _pending_dt := 0.0
var _cursor := 0
var _time := 0.0
var _hole := Vector3.INF
var _on_ice := false
var _hull_inv := Transform3D.IDENTITY
var _hull := Transform3D.IDENTITY
var _use_hull := false
var _hull_side := 1.0 # vavan kärjen puoli rungon keskiviivasta
var _detour := 0.0 # m: laidan yli kiertävän siiman lisäpituus
## Siima on kireällä (pelilogiikan jännitys): kireä siima kiertää laidan yli
## kiertomatkan verran pidempänä
var taut := false
var _w := PackedFloat32Array() # pisteiden paino rajoitteissa (0 = kiinni)
var _resting := PackedByteArray() # piste lepää pinnalla tai maassa
var _pull := PackedFloat32Array() # veto lepäävään pisteeseen (venymä)
var _waves: Array = []
# Piirron työtaulukot (uudelleenkäytetään joka ruudussa)
var _tang := PackedVector3Array()
var _verts := PackedVector3Array()
var _dirs := PackedVector3Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
const SUB_ANGLE := deg_to_rad(1.2) # piirretyn käyrän kääntyminen välipistettä kohti
const MAX_SUB := 16
var _waves_time := -1.0


func _init(lake_data: LakeData = null, boat_node: Boat = null) -> void:
	lake = lake_data
	boat = boat_node
	# Omat taulukot jokaiselle siimalle (pakatut taulukot jaetaan viittauksena)
	pos = PackedVector3Array()
	pos.resize(POINTS)
	prev = PackedVector3Array()
	prev.resize(POINTS)
	rest = PackedFloat32Array()
	rest.resize(POINTS - 1)
	arc = PackedFloat32Array()
	arc.resize(POINTS)
	wet = PackedByteArray()
	wet.resize(POINTS)
	contact = PackedByteArray()
	contact.resize(POINTS)
	water = PackedByteArray()
	water.resize(POINTS)
	surf = PackedFloat32Array()
	surf.resize(POINTS)
	surf_rate = PackedFloat32Array()
	surf_rate.resize(POINTS)
	surf_time = PackedFloat32Array()
	surf_time.resize(POINTS)
	surf_sample = PackedFloat32Array()
	surf_sample.resize(POINTS)
	surf_acc = PackedFloat32Array()
	surf_acc.resize(POINTS)
	ground = PackedFloat32Array()
	ground.resize(POINTS)
	ground_xz = PackedVector2Array()
	ground_xz.resize(POINTS)
	_w = PackedFloat32Array()
	_w.resize(POINTS)
	_resting = PackedByteArray()
	_resting.resize(POINTS)
	_pull = PackedFloat32Array()
	_pull.resize(POINTS)
	_tang = PackedVector3Array()
	_tang.resize(POINTS)
	_verts = PackedVector3Array()
	_dirs = PackedVector3Array()
	_uv = PackedVector2Array()
	_uv2 = PackedVector2Array()


## Pisteiden jako: välit ovat lyhyimmät vavan kärjen lähellä (siima
## laskeutuu veteen), pisimmät keskellä ja taas lyhyemmät siiman päässä
## (siima painuu uistimelle). Välin pituus ∝ 0,2 + 2,4·u·(1 − u) + 0,3·u;
## F(0) = 0, F(1) = 1.
static func spacing(u: float) -> float:
	return (0.2 * u + 1.35 * u * u - 0.8 * u * u * u) / 0.75


## Nimelliset välit pituudelle len
func _nominal(len: float) -> void:
	length = len
	arc[0] = 0.0
	for i in POINTS - 1:
		rest[i] = len * (spacing(float(i + 1) / (POINTS - 1)) - spacing(float(i) / (POINTS - 1)))
		arc[i + 1] = arc[i] + rest[i]


## Ketju alusta: pisteet jänteelle a–b, ylimääräinen siima roikkuu kaarella
func reset(a: Vector3, b: Vector3, len: float) -> void:
	len = maxf(len, 0.01)
	_nominal(len)
	var span := a.distance_to(b)
	# Ylimääräinen siima kaarelle sivulle (vedessä se lepää pinnalla)
	var sag := sqrt(maxf(0.0, 3.0 * span * maxf(0.0, len - span) / 8.0)) if not free_end else 0.0
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var side := Vector3(-flat.z, 0.0, flat.x).normalized() if flat.length() > 0.01 else Vector3.RIGHT
	for i in POINTS:
		var t := arc[i] / len
		var p: Vector3
		if free_end:
			p = a + Vector3.DOWN * arc[i]
		else:
			p = a.lerp(b, t) + (side * 0.8 + Vector3.DOWN * 0.6) * sag * 4.0 * t * (1.0 - t)
		if lake != null and lake.is_water(p.x, p.z) and not _on_ice:
			p.y = maxf(p.y, minf(0.0, lerpf(a.y, b.y, t)))
		pos[i] = p
		prev[i] = p
		wet[i] = 0
		contact[i] = 0
		surf_time[i] = -1.0
		ground_xz[i] = Vector2(INF, INF)
	initialized = true
	straight = false
	for i in POINTS:
		_sample(i, true)
	_collide()


## Pituus muuttuu vavan päästä: ensimmäinen väli venyy tai lyhenee. Kun se
## on liian lyhyt tai pitkä, pisteet jaetaan uudelleen vanhaa muotoa pitkin
## (siiman pää pysyy paikallaan siimamatkan mukaan).
func set_length(len: float) -> void:
	len = maxf(len, 0.01)
	var d := len - length
	if absf(d) < 1e-6:
		return
	if uniform:
		uniform = false
		_nominal(len)
		return
	var nominal0 := len * spacing(1.0 / (POINTS - 1))
	var r0 := rest[0] + d
	if r0 >= 0.4 * nominal0 and r0 <= 2.0 * nominal0:
		rest[0] = r0
		for i in range(1, POINTS):
			arc[i] += d
		length = len
		return
	# Uusi siimamatka i:lle vanhan ketjun koordinaateissa: pää pysyy paikallaan
	_resample(len, length - len)


## Katkennut pätkä: vavan kärkeen jää len metriä siimaa, pää on vapaa
func cut(len: float) -> void:
	free_end = true
	if not initialized:
		return
	_resample(minf(len, length), 0.0)
	if len > length:
		set_length(len)


## Kiinnitetään molemmat päät taas (uusi uistin solmittu)
func tie() -> void:
	free_end = false


## Pisteet uudelleen vanhaa muotoa pitkin: uuden pisteen i paikka vanhan
## ketjun siimamatkalla offset + uusi siimamatka
func _resample(len: float, offset: float) -> void:
	var old_pos := pos.duplicate()
	var old_prev := prev.duplicate()
	var old_arc := arc.duplicate()
	var old_wet := wet.duplicate()
	_nominal(len)
	var j := 0
	for i in POINTS:
		var a := clampf(offset + arc[i], 0.0, old_arc[POINTS - 1])
		while j < POINTS - 2 and old_arc[j + 1] < a:
			j += 1
		var seg := old_arc[j + 1] - old_arc[j]
		var t := clampf((a - old_arc[j]) / seg, 0.0, 1.0) if seg > 1e-6 else 0.0
		pos[i] = old_pos[j].lerp(old_pos[j + 1], t)
		prev[i] = old_prev[j].lerp(old_prev[j + 1], t)
		wet[i] = old_wet[j] if t < 0.5 else old_wet[j + 1]
		ground_xz[i] = Vector2(INF, INF) # ympäristö uudelleen kiertävästi
	for i in POINTS:
		_sample(i, false)


## Fysiikka-askel. start = vavan kärki (jäällä avanto), end = siiman pää
## (uistin, koho tai kala; katkenneella pätkällä ei käytetä), len = siiman
## pituus, wind = tuulen nopeus (m/s), hole = avanto (Vector3.INF = ei jäällä).
func step(dt: float, start: Vector3, end: Vector3, len: float, wind: Vector3, use_hull: bool, hole := Vector3.INF, on_ice := false) -> void:
	_pending_dt += dt
	if initialized and _pending_dt < min_dt - 1e-5:
		pos[0] = start
		if not free_end:
			pos[POINTS - 1] = end
		return
	dt = _pending_dt
	_pending_dt = 0.0
	_hole = hole
	_on_ice = on_ice
	if len < SHORT and not free_end:
		_straight(start, end, len) # uistin roikkuu kärjessä: suora
		return
	if not initialized or pos[0].distance_to(start) > JUMP or (not free_end and pos[POINTS - 1].distance_to(end) > JUMP):
		reset(start, end, len)
	straight = false # suorasta lyhyestä siimasta jatketaan sellaisenaan
	# Laidan yli kiertyvä siima tarvitsee kiertomatkan verran lisää (vain ulkoasu:
	# pelilogiikan siima on suora jänne)
	set_length(len + _detour)
	_time += dt
	_use_hull = use_hull and boat != null and lake != null
	if _use_hull:
		_hull = boat.hull.global_transform
		_hull_inv = _hull.affine_inverse()
		# Vapa veneen pohjalla (kärki rungon sisällä): ei kiertoa
		var tip_l := _hull_inv * start
		_use_hull = not _inside_hull(tip_l) and not _inside_hull(_hull_inv * end)
		_hull_side = 1.0 if tip_l.x >= 0.0 else -1.0
	_sample_env(dt)
	for i in POINTS:
		if contact[i] > 0:
			contact[i] -= 1
	var last := POINTS if free_end else POINTS - 1
	var air_target := wind * AIR_WIND
	var drift := Vector3(wind.x, 0.0, wind.z) * SURFACE_DRIFT
	var k_air := exp(-dt / AIR_TAU)
	var k_water := exp(-dt / WATER_TAU)
	var k_surface := exp(-dt / SURFACE_TAU)
	var k_ground := exp(-dt / GROUND_TAU)
	var start_pos := pos.duplicate()
	for i in POINTS:
		_w[i] = 1.0
		_resting[i] = 1 if ((water[i] == 1 and wet[i] == 1 and pos[i].y >= surf[i] - FLOAT_BAND and not taut) or (water[i] == 0 and pos[i].y <= ground[i] + 0.01)) else 0
	# Siiman pää pinnalla (uistin tai koho) on kuin lepäävä piste
	var e := pos[POINTS - 1]
	if not free_end and absf(e.y - surf[POINTS - 1]) < 0.05:
		_resting[POINTS - 1] = 1
	_pull_through_runs()
	for i in range(1, last):
		var p := pos[i]
		var v := (p - prev[i]) / dt
		prev[i] = p
		var resting := false
		if water[i] == 1 and wet[i] == 1:
			if p.y >= surf[i] - FLOAT_BAND and not taut:
				# Pinnalla: kitka hidastaa, pintavirta kuljettaa hitaasti
				# (kireä siima ei lepää pinnalla vaan menee sen läpi)
				var h := drift + (Vector3(v.x, 0.0, v.z) - drift) * k_surface
				v = Vector3(h.x, surf_rate[i], h.z)
				resting = true
			else:
				# Pinnan alla: veden vastus, löysä siima nousee hiljalleen pintaan
				# (jään alla vajoaa hiljalleen, nailon on vettä raskaampaa)
				var target := Vector3(0.0, -RISE_SPEED if _on_ice else RISE_SPEED, 0.0)
				v = target + (v - target) * k_water
		elif water[i] == 0 and p.y <= ground[i] + 0.01:
			v = v * k_ground # maalla
			v.y = minf(v.y, 0.0)
			resting = true
		else:
			v = air_target + (v - air_target) * k_air + Vector3(0.0, -GRAVITY * dt, 0.0)
		if resting:
			_w[i] = REST_WEIGHT
			# Siirtymäkohdassa (kosketuskohta, uistimelle painuva kohta) lepokitka
			# ei estä taivutusrajaa; levossa olevat kiemurat pinnalla pysyvät
			var edge := _resting[i - 1] == 0 or (i + 1 < POINTS and _resting[i + 1] == 0)
			if Vector2(v.x, v.z).length() < STICK_SPEED and _pull[i] < STICK_STRETCH and not (edge and _bent(i)):
				_w[i] = 0.0 # lepokitka: pysyy paikallaan
				v.x = 0.0
				v.z = 0.0
		pos[i] = p + v * dt
	pos[0] = start
	if not free_end:
		pos[POINTS - 1] = end
	_w[0] = 0.0
	if not free_end:
		_w[POINTS - 1] = 0.0
	_smooth()
	# Rauhallinen siima (min_dt > 0) liikkuu hitaasti: vähemmän kierroksia
	var iterations := ITERATIONS_CALM if min_dt > 0.0 else ITERATIONS
	for it in iterations:
		_solve(it % 2 == 1)
		if min_dt <= 0.0 or it >= iterations - 2:
			_tethers()
		if it >= iterations - (1 if min_dt > 0.0 else 2):
			_collide()
	_surface_rules(start_pos)
	_straighten()
	if _use_hull:
		_collide() # pintaan asettunut piste ei saa jäädä rungon sisään
	var touching := false
	for i in POINTS:
		if contact[i] > 0:
			touching = true
			break
	if touching and taut and not free_end:
		_detour = lerpf(_detour, clampf(measured_length() - len, 0.0, 2.0), 0.3)
	else:
		_detour = move_toward(_detour, 0.0, dt * 0.5)


## Lyhyt siima (uistin vavan kärjessä) suorana kärjestä päähän
func _straight(a: Vector3, b: Vector3, len: float) -> void:
	_nominal(maxf(len, 0.01))
	for i in POINTS:
		var p := a.lerp(b, arc[i] / length)
		prev[i] = p
		pos[i] = p
		wet[i] = 0
		contact[i] = 0
		ground_xz[i] = Vector2(INF, INF)
		surf_time[i] = -1.0
	_detour = 0.0
	initialized = true
	straight = true


## Kevyt tasoitus vapaille pisteille: löysä siima muodostaa pehmeän kaaren
## eikä nurjahda sahalaidaksi (pituusrajoitteet palauttavat pituuden)
func _smooth() -> void:
	var prev_p := pos[0]
	for i in range(1, POINTS - 1):
		var p := pos[i]
		if _w[i] == 1.0 and contact[i] == 0:
			pos[i] = p + ((prev_p + pos[i + 1]) * 0.5 - p) * SMOOTH
		prev_p = p


## Kireä siima (pelilogiikan jännitys, jänne vähintään siiman pituinen) on
## suora: veden vastus ei jätä vesirajaan notkoa. Kun siima löystyy (kala
## kääntyy kohti venettä), se kaartuu taas vapaasti.
func _straighten() -> void:
	if not taut or free_end:
		return
	var a := pos[0]
	var chord := pos[POINTS - 1] - a
	if chord.length() < length * 0.999:
		return
	for i in POINTS:
		if contact[i] > 0:
			return # laidan yli kiertävä siima ei ole suora
	for i in range(1, POINTS - 1):
		pos[i] = a + chord * (arc[i] / length)


## Veto lepääville pisteille: oma venymä tai, jos piste rajaa vapaan osan
## (ilmassa tai laidan yli), koko vapaan osan suurin venymä. Kireä ilmassa
## oleva siima vetää siis pinnalta, vaikka veto ei näy viereisessä välissä.
func _pull_through_runs() -> void:
	var i := 0
	while i < POINTS:
		_pull[i] = _stretch(i)
		i += 1
	var start := -1 # edellinen lepäävä piste
	var run := 0.0
	for k in range(1, POINTS):
		run = maxf(run, pos[k].distance_to(pos[k - 1]) / maxf(rest[k - 1], 1e-6) - 1.0)
		if _resting[k] == 1 or k == POINTS - 1:
			if start >= 0:
				_pull[start] = maxf(_pull[start], run)
			_pull[k] = maxf(_pull[k], run)
			start = k
			run = 0.0


## Pisteen viereisten välien suurin venymä (lepokitka irtoaa vedosta)
func _stretch(i: int) -> float:
	var s := 0.0
	if i > 0 and rest[i - 1] > 1e-6:
		s = pos[i].distance_to(pos[i - 1]) / rest[i - 1] - 1.0
	if i < POINTS - 1 and rest[i] > 1e-6:
		s = maxf(s, pos[i].distance_to(pos[i + 1]) / rest[i] - 1.0)
	return s


## Taittuuko ketju pisteessä i tai sen naapureissa yli rajan (lepokitka irtoaa)
func _bent(i: int) -> bool:
	var lim := cos(MAX_ANGLE * 1.15)
	for j in [i - 1, i, i + 1]:
		if j <= 0 or j >= POINTS - 1 or contact[j] > 0:
			continue
		var a := pos[j] - pos[j - 1]
		var b := pos[j + 1] - pos[j]
		var la := a.length()
		var lb := b.length()
		if la > 1e-6 and lb > 1e-6 and a.dot(b) / (la * lb) < lim:
			return true
	return false


## Välien pituudet ja taivutusraja samassa kierroksessa (molempiin suuntiin
## vuorotellen); päät ovat kiinni
func _solve(backward: bool) -> void:
	var n := POINTS - 1
	var c := cos(MAX_ANGLE)
	for k in n:
		var i := n - 1 - k if backward else k
		var a := pos[i]
		var b := pos[i + 1]
		var d := b - a
		var dist := d.length()
		var wa := _w[i]
		var wb := _w[i + 1]
		var w := wa + wb
		if dist > 1e-7 and w > 0.0:
			var corr := d * ((dist - rest[i]) / (dist * w))
			pos[i] = a + corr * wa
			pos[i + 1] = b - corr * wb
		# Taivutusraja pisteessä i + 1 (välit i ja i + 1)
		if i + 2 > n or contact[i + 1] > 0:
			continue
		var r1 := rest[i]
		var r2 := rest[i + 1]
		var min_d2 := r1 * r1 + r2 * r2 + 2.0 * r1 * r2 * c
		a = pos[i]
		b = pos[i + 2]
		d = b - a
		var d2 := d.length_squared()
		if d2 >= min_d2 or d2 < 1e-14:
			continue
		wb = _w[i + 2]
		w = wa + wb
		if w <= 0.0:
			continue
		dist = sqrt(d2)
		var corr2 := d * ((dist - sqrt(min_d2)) / (dist * w))
		pos[i] = a + corr2 * wa
		pos[i + 2] = b - corr2 * wb


## Pitkät rajoitteet: piste enintään siimamatkansa päässä kärjestä ja päästä
func _tethers() -> void:
	var a := pos[0]
	var b := pos[POINTS - 1]
	# Laidan yli kiertyvä siima ei ole suora: rajoitteet vain kosketukseen asti
	var first := POINTS
	var last := -1
	if _use_hull:
		for i in POINTS:
			if contact[i] > 0:
				first = mini(first, i)
				last = i
	for i in range(1, POINTS - 1):
		var p := pos[i]
		var d := p - a
		var dist := d.length()
		if dist > arc[i] and i <= first:
			p = a + d * (arc[i] / dist)
		if not free_end and i >= last:
			var e := p - b
			var de := e.length()
			var lim := length - arc[i]
			if de > lim:
				p = b + e * (lim / de)
		pos[i] = p


## Pohja, maa, jää ja veneen runko
func _collide() -> void:
	var last := POINTS if free_end else POINTS - 1
	for i in range(1, last):
		var p := pos[i]
		if p.y < ground[i]:
			p.y = ground[i] # ei pohjan eikä maan alle
		if _on_ice and _hole != Vector3.INF and p.y > ICE_BOTTOM:
			# Jään alla (avannon ulkopuolella) siima pysyy jään alapinnan alla,
			# avannossa veden pinnan alla
			if Vector2(p.x - _hole.x, p.z - _hole.z).length() > HOLE_RADIUS:
				p.y = ICE_BOTTOM
			else:
				p.y = minf(p.y, 0.0)
		if _use_hull and Vector2(p.x - _hull.origin.x, p.z - _hull.origin.z).length_squared() < 7.0:
			var l := _hull_inv * p
			if _inside_hull(l):
				p = _hull * _push_out(l, _hull_side)
				prev[i] = p # kitka rungon pintaa vasten (ei liu'u eikä värise)
				contact[i] = CONTACT_STEPS
		pos[i] = p


## Vesi: pinnalle osunut siima jää pinnalle (kelluu aalloilla), pinnalta
## kireällä siimalla nostettu irtoaa
func _surface_rules(start_pos: PackedVector3Array) -> void:
	var last := POINTS if free_end else POINTS - 1
	for i in range(1, last):
		if water[i] == 0:
			wet[i] = 0
			continue
		var p := pos[i]
		var s := surf[i]
		if wet[i] == 0:
			if p.y < s and _time - surf_time[i] > 0.05:
				_sample(i, false) # pinnan korkeus tuoreeksi ennen kuin piste osuu siihen
				s = surf[i]
			if p.y < s:
				wet[i] = 1
				if start_pos[i].y >= s - 0.01 and s - p.y < 0.3 and not taut:
					p.y = s # osui pintaan ylhäältä: jää pinnalle
					prev[i].y = s
		elif p.y > s + LIFT:
			wet[i] = 0 # nousi pinnalta
		elif p.y > s - FLOAT_BAND and not taut:
			# Kelluu pinnalla; kireä siima menee pinnan läpi suoraan (ei taitetta)
			p.y = s
			prev[i].y = s
		pos[i] = p


## Ympäristön näytteet: pohja ja maa, kun piste on siirtynyt, ja aaltopinnan
## korkeus kiertävästi muutamalle pisteelle askelta kohti. Välissä pinnan
## korkeus ennustetaan muutosnopeudella, joten pinta liikkuu tasaisesti.
func _sample_env(dt: float) -> void:
	for i in POINTS:
		if water[i] == 1 and surf_time[i] >= 0.0:
			# Pinnan korkeus näytteestä aikaderivaatoilla (toisen asteen ennuste)
			var tau := minf(_time - surf_time[i], 0.5)
			surf[i] = surf_sample[i] + surf_rate[i] * tau + 0.5 * surf_acc[i] * tau * tau
		var p := pos[i]
		if water[i] == 0 or Vector2(p.x, p.z).distance_squared_to(ground_xz[i]) > 0.25:
			_sample_ground(i) # maalla ja liikkuessa pohja heti
	# Aaltopinta vain pinnan lähellä oleville pisteille (kaukana pinnasta
	# korkeudella ei ole väliä), kiertävästi muutama askelta kohti
	var done := 0
	var samples := SAMPLES_PER_STEP + int(maxf(0.0, Waves.wind - 4.0) / 2.0) # isommat aallot kovalla tuulella
	for k in POINTS:
		var i := _cursor
		_cursor = (_cursor + 1) % POINTS
		var h := pos[i].y - surf[i]
		if water[i] == 1 and h < 0.3 and h > -0.2:
			_sample(i, false)
			done += 1
			if done >= samples:
				break


## Pohja tai maa pisteen kohdalla (ja onko se vettä)
func _sample_ground(i: int) -> void:
	if lake == null:
		water[i] = 1
		ground[i] = -100.0
		return
	var p := pos[i]
	ground_xz[i] = Vector2(p.x, p.z)
	var is_water := lake.is_water(p.x, p.z)
	if _on_ice and is_water and _hole != Vector3.INF:
		# Avannosta jään alle: koko ketju on vedessä (jään alapinta katto)
		water[i] = 1
		ground[i] = lake.height_at(p.x, p.z) + 0.01
	elif _on_ice and is_water:
		# Jäällä (ei avantoa): jää on lattia
		water[i] = 0
		ground[i] = 0.005
	else:
		water[i] = 1 if is_water else 0
		ground[i] = lake.height_at(p.x, p.z) + 0.01
	if water[i] == 0:
		surf[i] = ground[i]
		surf_rate[i] = 0.0


func _sample(i: int, first: bool) -> void:
	if lake == null:
		water[i] = 1
		ground[i] = -100.0
		surf[i] = 0.0
		return
	var p := pos[i]
	var xz := Vector2(p.x, p.z)
	if first or xz.distance_squared_to(ground_xz[i]) > 0.01:
		_sample_ground(i)
	if water[i] == 0:
		return
	if _on_ice or p.y > surf[i] + 1.5:
		# Jäällä ei ole aaltoja; korkealla ilmassa pinnan korkeudella ei ole väliä
		if first or surf_time[i] < 0.0:
			surf[i] = 0.0
			surf_sample[i] = 0.0
			surf_rate[i] = 0.0
			surf_acc[i] = 0.0
			surf_time[i] = _time
		return
	if _time - _waves_time > 0.5 or _waves_time > _time or _waves.is_empty():
		_waves = Waves.sampler(xz) # aallokko (tuuli ja pyyhkäisymatka) puolen sekunnin välein
		_waves_time = _time
	var h := Waves.height_rates_with(xz, _waves)
	surf[i] = h.x
	surf_sample[i] = h.x
	surf_rate[i] = h.y
	surf_acc[i] = h.z
	surf_time[i] = _time


## Onko piste rungon sisällä (rungon koordinaateissa, +Z perään)
static func _inside_hull(l: Vector3) -> bool:
	if absf(l.z) > 2.2 or l.y > 0.7 or l.y < -0.3:
		return false
	var h := Boat._hull_at(l.z)
	if l.y > h.y + HULL_MARGIN or l.y < h.z - HULL_MARGIN:
		return false
	return absf(l.x) < _half_width(h, l.y)


## Rungon puolileveys korkeudella y (kölistä laitaan levenevä kylki)
static func _half_width(h: Vector3, y: float) -> float:
	var t := clampf((y - h.z) / maxf(h.y - h.z, 0.01), 0.0, 1.0)
	return h.x * (0.6 + 0.4 * sqrt(t)) + HULL_MARGIN


## Lähin kohta rungon ulkopuolella: laidan yli, kyljestä sivulle tai kölin alle
static func _push_out(l: Vector3, side_hint := 1.0) -> Vector3:
	var h := Boat._hull_at(l.z)
	var top := h.y + HULL_MARGIN
	var bottom := h.z - HULL_MARGIN
	var hw := _half_width(h, l.y)
	var up := top - l.y
	var side := hw - absf(l.x)
	var down := l.y - bottom
	if up <= side and up <= down:
		l.y = top + 0.001
	elif side <= down:
		# Keskiviivan lähellä (keulavanta, köli) vavan kärjen puolelle, ettei
		# piste hyppää laidalta toiselle
		var sx := signf(l.x) if absf(l.x) > 0.1 else side_hint
		l.x = (sx if sx != 0.0 else 1.0) * (hw + 0.001)
	else:
		l.y = bottom - 0.001
	return l


## Lento: siima loivana kaarena vavan kärjestä uistimeen. Ylimääräinen siima
## roikkuu painovoiman ja tuulen suuntaan (tuulikaari vain ulkoasua).
## Edellinen muoto jää nopeudeksi, joten laskeutuessa simulaatio jatkuu siitä.
func fly(dt: float, a: Vector3, b: Vector3, len: float, wind: Vector3) -> void:
	free_end = false
	_nominal(maxf(len, 0.01))
	var span := a.distance_to(b)
	var sag := sqrt(maxf(0.0, 3.0 * span * maxf(0.0, length - span) / 8.0))
	var chord := (b - a) / maxf(span, 1e-4)
	var side := Vector3(wind.x, 0.0, wind.z)
	side -= chord * side.dot(chord) # tuulen osa jännettä vastaan kohtisuoraan
	var bow := (Vector3.DOWN * GRAVITY * AIR_TAU + side * AIR_WIND).normalized()
	for i in POINTS:
		var t := arc[i] / length
		var p := a.lerp(b, t) + bow * sag * 4.0 * t * (1.0 - t)
		if lake != null:
			# Kaari pysyy veden ja maan yläpuolella
			# (pehmeä maksimi: ei kulmaa kaaren ja pinnan välillä)
			var floor_y := minf(0.03 if lake.is_water(p.x, p.z) else lake.height_at(p.x, p.z) + 0.03, lerpf(a.y, b.y, t))
			var dy := p.y - floor_y
			var k := 0.4 * 4.0 * t * (1.0 - t)
			p.y = floor_y + 0.5 * (dy + sqrt(dy * dy + k * k))
		prev[i] = pos[i] if initialized else p
		pos[i] = p
		wet[i] = 0
		contact[i] = 0
	initialized = true
	straight = false
	_time += dt
	for i in POINTS:
		ground_xz[i] = Vector2(INF, INF)
		surf_time[i] = -1.0


## Siirto vavan mukana (ruudun tahdissa, kun uistin roikkuu kärjessä)
func carry(move: Transform3D) -> void:
	for i in POINTS:
		pos[i] = move * pos[i]
		prev[i] = move * prev[i]


## Ruudun tahdissa: ensimmäinen piste näkyvään vavan kärkeen. Jos kärki
## siirtyy (vapa telineeseen), siima seuraa heti: piste enintään
## siimamatkansa päässä kärjestä (nopeus säilyy).
func pin_start(tip: Vector3) -> void:
	pos[0] = tip
	prev[0] = tip
	if taut and not free_end and tip.distance_to(pos[POINTS - 1]) >= length * 0.999:
		_straighten() # kireä siima pysyy suorana (pää on kiinni uistimessa tai kalassa)
		return
	for i in range(1, POINTS if free_end else POINTS - 1):
		var d := pos[i] - tip
		var dist := d.length()
		if dist > arc[i] + 1e-4:
			var moved := tip + d * (arc[i] / dist) - pos[i]
			pos[i] += moved
			prev[i] += moved


## Ketjun pituus (testit)
func measured_length() -> float:
	var s := 0.0
	for i in POINTS - 1:
		s += pos[i].distance_to(pos[i + 1])
	return s


# --- Piirto -------------------------------------------------------------------

## Siima kameraan päin kääntyvänä nauhana (leveys ja peittävyys varjostimessa,
## shaders/fishing_line.gdshader). Ketju piirretään pehmeänä käyränä
## (Hermite-käyrä keskiarvotangentein, välipisteitä taitteen mukaan). lead =
## suora alkupätkä ennen ketjua (jäällä vavan kärjestä avantoon), INF = ei.
## Kärkiin: NORMAL = siiman suunta, UV.x = puoli (−1/1), UV2.x = syvyys pinnan alla.
func build_mesh(mesh: ArrayMesh, lead := Vector3.INF) -> void:
	_build(mesh, lead)


func _build(mesh: ArrayMesh, lead: Vector3) -> void:
	mesh.clear_surfaces()
	if straight:
		_verts.resize(4)
		_dirs.resize(4)
		_uv2.resize(4)
		var d := (pos[POINTS - 1] - pos[0]).normalized()
		_emit(0, pos[0], d, -1.0)
		_emit(1, pos[POINTS - 1], d, -1.0)
		_finish_mesh(mesh, 2)
		return
	# Tangentit pisteissä: suuntien keskiarvo (päissä ja laidan yli taitteessa
	# välin oma suunta)
	for i in POINTS:
		if i == 0 or i == POINTS - 1 or contact[i] > 0:
			_tang[i] = Vector3.ZERO
			continue
		var d0 := pos[i] - pos[i - 1]
		var d1 := pos[i + 1] - pos[i]
		var l0 := d0.length()
		var l1 := d1.length()
		var t := (d0 / l0 if l0 > 1e-6 else Vector3.ZERO) + (d1 / l1 if l1 > 1e-6 else Vector3.ZERO)
		var tl := t.length()
		_tang[i] = t / tl if tl > 1e-6 else Vector3.ZERO
	var cap := (POINTS - 1) * MAX_SUB + 2
	_verts.resize(cap * 2)
	_dirs.resize(cap * 2)
	_uv2.resize(cap * 2)
	var count := 0
	if lead != Vector3.INF:
		count = _emit(count, lead, (pos[0] - lead).normalized(), -1.0)
	var d_first := (pos[1] - pos[0]).normalized() if lead == Vector3.INF else (pos[0] - lead).normalized()
	count = _emit(count, pos[0], d_first, surf[0] - pos[0].y if water[0] == 1 else -1.0)
	for i in POINTS - 1:
		var p0 := pos[i]
		var p1 := pos[i + 1]
		var seg := p0.distance_to(p1)
		if seg < 1e-5:
			continue
		var chord := (p1 - p0) / seg
		var t0 := _tang[i] if _tang[i] != Vector3.ZERO else chord
		var t1 := _tang[i + 1] if _tang[i + 1] != Vector3.ZERO else chord
		# Välipisteitä käyrän kääntymisen mukaan (myös S-mutka: tangentit jänteen eri puolilla)
		var turn := t0.angle_to(chord) + chord.angle_to(t1)
		var n := clampi(int(ceil(turn / SUB_ANGLE)), 1, MAX_SUB)
		var wet0 := water[i] == 1
		var wet1 := water[i + 1] == 1
		var sh0 := _shown_surface(i)
		var sh1 := _shown_surface(i + 1)
		var prev_p := p0
		for k in range(1, n + 1):
			var u := float(k) / n
			var p := p1
			if k < n:
				var u2 := u * u
				var u3 := u2 * u
				p = p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + t0 * (seg * (u3 - 2.0 * u2 + u)) + p1 * (3.0 * u2 - 2.0 * u3) + t1 * (seg * (u3 - u2))
			var dir := (p - prev_p).normalized()
			prev_p = p
			# Syvyys pinnan alla: pinnan korkeus välillä lineaarisesti
			var depth := Vector2(lerpf(sh0, sh1, u) - p.y if (wet0 or wet1) else -1.0, 0.0)
			var kk := count * 2
			_verts[kk] = p
			_verts[kk + 1] = p
			_dirs[kk] = dir
			_dirs[kk + 1] = dir
			_uv2[kk] = depth
			_uv2[kk + 1] = depth
			count += 1
	_finish_mesh(mesh, count)


func _finish_mesh(mesh: ArrayMesh, count: int) -> void:
	if count < 2:
		return
	_verts.resize(count * 2)
	_dirs.resize(count * 2)
	_uv2.resize(count * 2)
	if _uv.size() != count * 2:
		_uv.resize(count * 2)
		for k in count:
			_uv[k * 2] = Vector2(-1.0, 0.0)
			_uv[k * 2 + 1] = Vector2(1.0, 0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _dirs
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)


## Pinnan korkeus piirtoa varten (varjostin häivyttää syvyyden mukaan). Jään
## alla siima ei näy: pinta nostetaan niin, että piste on syvällä.
func _shown_surface(i: int) -> float:
	var p := pos[i]
	if _on_ice and _hole != Vector3.INF and p.y < -0.01 and Vector2(p.x - _hole.x, p.z - _hole.z).length() > HOLE_RADIUS:
		return p.y + 1.0
	return surf[i] if water[i] == 1 else p.y + 1.0


## Nauhan kärkipari: sama keskilinjan piste kummallekin puolelle
func _emit(count: int, p: Vector3, dir: Vector3, depth: float) -> int:
	var k := count * 2
	_verts[k] = p
	_verts[k + 1] = p
	_dirs[k] = dir
	_dirs[k + 1] = dir
	var d := Vector2(depth, 0.0)
	_uv2[k] = d
	_uv2[k + 1] = d
	return count + 1


## Piirretyn käyrän pisteet (testit: taitekulmat): siiman keskilinja
static func curve_points(mesh: ArrayMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mesh == null or mesh.get_surface_count() == 0:
		return out
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, v.size(), 2):
		out.append(v[i])
	return out
