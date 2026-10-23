class_name Nets
## Verkot (pohjaverkko 30 m × 1,8 m) ja verkon saalismalli.
## Verkko pyytää kaloja, jotka uivat sen läpi: kohtaamisia tulee lajin
## tiheyden, verkkopaikan elinpaikkasopivuuden, vuorokausi- ja vuodenaika-
## aktiivisuuden sekä verkon korkeuden (kattaako se lajin uintisyvyydet) mukaan.
## Silmäkoko ratkaisee, mitkä kohdatut kalat tarttuvat: parhaiten tarttuu kala,
## jonka pituus on lajin net.k × silmäkoko (Species "net").
## Saalis lasketaan vasta nostettaessa koko pyyntiajalta 15 minuutin askelin, joten
## sama malli toimii reissun aikana ja uramoodissa reissujen yli. Elävän
## populaation kaloja (kaikuluotain) verkko ei vähennä.
##
## Verkon tiedot (sanakirja, tallennetaan uran mukana):
##   id        silmäkoko (LIST)
##   points    verkon linja [x0, z0, x1, z1, ...] metrin välein
##   laid_at   laskuhetki absoluuttisina minuutteina (päivä * 1440 + minuutit)
##   seed      saaliin satunnaisluvut (sama nosto antaa saman saaliin)
##   wear      repeämät; WEAR_LIMIT:n jälkeen verkko on pilalla

const LENGTH := 30.0 # m
const HEIGHT := 1.8 # m: pohjaverkko seisoo pohjasta ylöspäin
const MAX_IN_LAKE := 3
const STEP := 15.0 # min
## Kalan uintimatka (m) 15 minuutissa täydellä aktiivisuudella; kalibroitu niin, että
## 35 mm:n verkko tuo kesäyönä (12 h) hyvältä paikalta noin 5–12 kalaa
const SWIM := 7.0
const HABITAT_BOOST := 1.6 # kalat ovat tiheämmässä sopivilla paikoilla kuin keskimäärin
const SATURATION := 40.0 # täyttyvä verkko pyytää huonommin: exp(-kaloja / SATURATION)
const TEAR_WEIGHT := 2.5 # hauki, joka painaa yli tämän kertaa silmäkoon parhaan painon, voi repiä verkon
const TEAR_CHANCE := 0.4
const WEAR_LIMIT := 3
const SMALL_SIGMA := 0.7 # parasta pienempien kalojen valinta on jyrkempi kuin isompien

const LIST := [
	{"id": "verkko22", "name": "Verkko 22 mm", "mesh": 22.0, "price": 25, "hint": "särki, ahven, kiiski"},
	{"id": "verkko35", "name": "Verkko 35 mm", "mesh": 35.0, "price": 30, "hint": "lahna, isot ahvenet, made"},
	{"id": "verkko50", "name": "Verkko 50 mm", "mesh": 50.0, "price": 35, "hint": "hauki, iso lahna, made"},
]


static func find(id: String) -> Dictionary:
	for n in LIST:
		if n["id"] == id:
			return n
	return LIST[0]


static func optimal_length(sp: String, mesh: float) -> float:
	return Species.DATA[sp]["net"]["k"] * mesh


## Todennäköisyys, että silmäkokoon uiva kala tarttuu (0..1)
static func selectivity(sp: String, mesh: float, length_cm: float) -> float:
	var best := optimal_length(sp, mesh)
	var sigma: float = Species.DATA[sp]["net"]["sigma"] * best
	if length_cm < best:
		sigma *= SMALL_SIGMA # pienet kalat uivat silmästä läpi
	var x := (length_cm - best) / sigma
	return exp(-x * x)


static func points(net: Dictionary) -> PackedVector2Array:
	var flat: Array = net["points"]
	var pts := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		pts.append(Vector2(flat[i], flat[i + 1]))
	return pts


static func length_of(net: Dictionary) -> float:
	var pts := points(net)
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


## Piste verkon linjalla osuudella t (0 = laskun alku, 1 = loppu)
static func point_at(pts: PackedVector2Array, t: float) -> Vector2:
	if pts.size() < 2:
		return pts[0] if pts.size() == 1 else Vector2.ZERO
	var f := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)


## Osuus lajin uintisyvyyksistä, jonka pohjasta 1,8 m nouseva verkko kattaa
static func height_factor(sp: String, t: Dictionary, depth: float) -> float:
	if Species.DATA[sp]["bottom"] or depth <= HEIGHT:
		return 1.0
	var dr: Array = t["depth"]
	var top := minf(dr[1], depth)
	var low := minf(dr[0], top - 0.5)
	var overlap := top - maxf(low, depth - HEIGHT)
	return clampf(overlap / maxf(top - low, 0.1), 0.0, 1.0)


## Verkon saalis aikaväliltä (absoluuttiset minuutit). day_of_year: Callable(abs_min) -> int.
## Palauttaa {"fish": [{species, weight, length, at}], "tears": int}; at = kalan kohta verkossa 0..1
static func catch_between(net: Dictionary, lake: LakeData, from_abs: float, to_abs: float, day_of_year: Callable) -> Dictionary:
	var result := {"fish": [], "tears": 0}
	var pts := points(net)
	if pts.size() < 2 or to_abs <= from_abs:
		return result
	var mesh: float = find(net["id"])["mesh"]
	var length := length_of(net)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(net["seed"]), int(from_abs), int(to_abs)])
	# Elinpaikka arvioidaan verkon päistä ja keskeltä
	var samples := [point_at(pts, 0.0), point_at(pts, 0.5), point_at(pts, 1.0)]
	var depth := 0.0
	for p in samples:
		depth += lake.depth_at(p.x, p.y) / samples.size()
	var by_day := {} # vuodenpäivä -> laji -> [traits, kerroin]
	var t_abs := from_abs
	while t_abs < to_abs:
		var dt := minf(STEP, to_abs - t_abs)
		var mid := t_abs + dt * 0.5
		var doy: int = day_of_year.call(mid)
		if not by_day.has(doy):
			by_day[doy] = _day_factors(lake, samples, depth, doy, length)
		var hour := fmod(mid, 1440.0) / 60.0
		var factors: Dictionary = by_day[doy]
		for sp in factors:
			var lam: float = factors[sp] * Species.activity(sp, hour) * dt / STEP
			lam *= exp(-result["fish"].size() / SATURATION)
			for i in _poisson(rng, lam):
				var w := Species.random_weight(sp, rng)
				var l := Species.length_cm(sp, w)
				var best_kg: float = Species.DATA[sp]["length_a"] * pow(optimal_length(sp, mesh), 3.0) / 1000.0
				if sp == "hauki" and w > best_kg * TEAR_WEIGHT and rng.randf() < TEAR_CHANCE:
					result["tears"] += 1 # iso hauki repii itsensä irti
					continue
				if rng.randf() < selectivity(sp, mesh, l):
					result["fish"].append({"species": sp, "weight": snappedf(w, 0.01), "length": snappedf(l, 0.5), "at": rng.randf()})
		t_abs += dt
	return result


## Lajien kohtaamisten odotusarvo 15 minuutissa täydellä vuorokausiaktiivisuudella
static func _day_factors(lake: LakeData, samples: Array, depth: float, doy: int, length: float) -> Dictionary:
	var factors := {}
	if Season.from_day(doy).frozen():
		return factors # jäiden aikaan verkko ei pyydä
	for sp in Species.DATA:
		var t := Species.traits(sp, doy, false)
		var hab := 0.0
		for p in samples:
			hab += FishPopulation.habitat(lake, sp, t, p) / samples.size()
		var density: float = Species.DATA[sp]["per_km2"] / 1e6 * hab * HABITAT_BOOST # kalaa / m²
		factors[sp] = density * length * SWIM * t["activity"] * height_factor(sp, t, depth)
	return factors


static func _poisson(rng: RandomNumberGenerator, lam: float) -> int:
	if lam <= 0.0:
		return 0
	var limit := exp(-lam)
	var k := 0
	var p := rng.randf()
	while p > limit:
		k += 1
		p *= rng.randf()
	return k
