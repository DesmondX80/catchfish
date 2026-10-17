class_name FishPopulation
extends Node
## Järven kalat. Kaloja ei piirretä (humusvesi on tummaa), vaan ne ovat dataa:
## sijainti, syvyys, paino ja nälkä. Kalat hakeutuvat lajilleen sopiviin
## elinpaikkoihin ja liikkuvat hitaasti kotialueellaan.

const GRID := 24.0 # spatiaalisen hakemiston solukoko (m)
const WANDER_INTERVAL := 2.0 # jokainen kala liikkuu kerran tässä ajassa

var lake: LakeData
var fish: Array[Dictionary] = []
var _grid := {}
var _rng := RandomNumberGenerator.new()
var _wander_cursor := 0
var _wander_budget := 0.0


func setup(lake_data: LakeData) -> void:
	lake = lake_data
	_rng.randomize()
	var area_km2 := lake.water.count(1) * lake.cell_size * lake.cell_size / 1e6
	for sp in Species.DATA:
		var data: Dictionary = Species.DATA[sp]
		var total := int(data["per_km2"] * area_km2)
		var school: int = data["school"]
		var spawned := 0
		while spawned < total:
			var center := _random_habitat(sp)
			for i in mini(school, total - spawned):
				var p := center + Vector2(_rng.randfn(0, 8), _rng.randfn(0, 8)) * (1.0 if school > 1 else 0.0)
				if not lake.is_water(p.x, p.y):
					p = center
				fish.append(_new_fish(sp, p))
				spawned += 1
	_rebuild_grid()


func count_by_species() -> Dictionary:
	var counts := {}
	for f in fish:
		counts[f["sp"]] = counts.get(f["sp"], 0) + 1
	return counts


func _new_fish(sp: String, p: Vector2) -> Dictionary:
	return {
		"key": Vector2i.ZERO,
		"sp": sp,
		"pos": p,
		"home": p,
		"depth": _preferred_depth(sp, p),
		"weight": Species.random_weight(sp, _rng),
		"hunger": _rng.randf_range(0.3, 1.0),
		"wary": 0.0,
	}


## Elinpaikan sopivuus 0..1
func habitat_score(sp: String, p: Vector2) -> float:
	if not lake.is_water(p.x, p.y):
		return 0.0
	var data: Dictionary = Species.DATA[sp]
	var depth := lake.depth_at(p.x, p.y)
	var shore := lake.shore_distance(p.x, p.y)
	var dr: Array = data["depth"]
	var sr: Array = data["shore"]
	var score := 1.0
	if depth < dr[0]:
		score *= clampf(depth / dr[0], 0.0, 1.0)
	elif not data["bottom"] and depth > dr[1] + 1.0:
		score *= 0.5
	elif data["bottom"] and depth < dr[0] + 0.5:
		score *= 0.4
	if shore < sr[0]:
		score *= 0.15 + 0.85 * shore / sr[0]
	elif shore > sr[1]:
		score *= clampf(1.0 - (shore - sr[1]) / sr[1], 0.1, 1.0)
	if data["reeds"] > 0.0:
		var reeds := lake.reeds_near(p.x, p.y, 25.0)
		score *= lerpf(1.0, 0.25 + 1.5 * minf(reeds * 4.0, 1.0), data["reeds"])
	return clampf(score, 0.0, 1.0)


func _random_habitat(sp: String) -> Vector2:
	var size := lake.world_size()
	for attempt in 400:
		var p := Vector2(lake.origin_x + _rng.randf() * size.x, lake.origin_z + _rng.randf() * size.y)
		if _rng.randf() < habitat_score(sp, p):
			return p
	# Varalla: mikä tahansa vesipiste
	while true:
		var p := Vector2(lake.origin_x + _rng.randf() * size.x, lake.origin_z + _rng.randf() * size.y)
		if lake.is_water(p.x, p.y):
			return p
	return Vector2.ZERO


func _preferred_depth(sp: String, p: Vector2) -> float:
	var data: Dictionary = Species.DATA[sp]
	var bottom := lake.depth_at(p.x, p.y)
	var dr: Array = data["depth"]
	if data["bottom"]:
		return maxf(0.2, bottom - _rng.randf_range(0.1, 0.6))
	return clampf(_rng.randf_range(dr[0], dr[1]), 0.2, maxf(0.2, bottom - 0.1))


## Kalat liikkuvat pienissä erissä joka ruudulla, ettei peli nyki
func _process(delta: float) -> void:
	if fish.is_empty():
		return
	_wander_budget += fish.size() * delta / WANDER_INTERVAL
	while _wander_budget >= 1.0:
		_wander_budget -= 1.0
		_wander(_wander_cursor)
		_wander_cursor = (_wander_cursor + 1) % fish.size()


func _wander(i: int) -> void:
	var f := fish[i]
	f["hunger"] = minf(1.0, f["hunger"] + 0.004 * WANDER_INTERVAL)
	f["wary"] = maxf(0.0, f["wary"] - WANDER_INTERVAL)
	var target: Vector2 = f["home"] + Vector2(_rng.randfn(0, 25), _rng.randfn(0, 25))
	var p: Vector2 = f["pos"].move_toward(target, _rng.randf_range(0.0, 0.5) * WANDER_INTERVAL)
	if lake.is_water(p.x, p.y):
		f["pos"] = p
		f["depth"] = clampf(lerpf(f["depth"], _preferred_depth(f["sp"], p), 0.1), 0.2, maxf(0.2, lake.depth_at(p.x, p.y) - 0.1))
		_update_grid(i)


func _grid_key(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / GRID), floori(p.y / GRID))


func _update_grid(i: int) -> void:
	var key := _grid_key(fish[i]["pos"])
	var old: Vector2i = fish[i]["key"]
	if key == old:
		return
	_grid[old].erase(i)
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(i)
	fish[i]["key"] = key


func _rebuild_grid() -> void:
	_grid.clear()
	for i in fish.size():
		var key := _grid_key(fish[i]["pos"])
		fish[i]["key"] = key
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(i)


func fish_near(p: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	var r := ceili(radius / GRID)
	var center := Vector2i(floori(p.x / GRID), floori(p.y / GRID))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for i in _grid.get(center + Vector2i(dx, dz), []):
				if fish[i]["pos"].distance_to(p) <= radius:
					result.append(i)
	return result


## Tarkistaa iskeekö jokin kala uistimeen. Palauttaa kalan indeksin tai -1.
## lure_speed on uistimen nopeus vedessä (m/s), twitch lyhyt nykäisy (0..1).
func check_lure(lure_xz: Vector2, lure_depth: float, lure_speed: float, twitch: float, lure: Dictionary, hour: float, wind: float, dt: float) -> int:
	var best := -1
	for i in fish_near(lure_xz, 10.0):
		var f: Dictionary = fish[i]
		if f["wary"] > 0.0:
			continue
		var data: Dictionary = Species.DATA[f["sp"]]
		var d: float = f["pos"].distance_to(lure_xz)
		if d > data["detect"]:
			continue
		var interest: float = 1.0 - d / data["detect"]
		interest *= exp(-pow((f["depth"] - lure_depth) / 1.2, 2.0))
		interest *= data["lures"].get(lure["id"], 0.3)
		var sp_speed: Array = data["speed"]
		var effective_speed := lure_speed + twitch * 0.8
		interest *= exp(-pow((effective_speed - sp_speed[0]) / sp_speed[1], 2.0))
		interest *= Species.activity(f["sp"], hour)
		interest *= f["hunger"]
		# Pieni tuulen väreily rohkaisee kaloja, kova tuuli samentaa
		interest *= 1.0 + clampf(wind / 4.0, 0.0, 1.0) * 0.3 - clampf((wind - 7.0) / 4.0, 0.0, 0.4)
		var strike_rate: float = interest * data["aggression"] * 1.4 # iskuja sekunnissa
		if _rng.randf() < 1.0 - exp(-strike_rate * dt):
			best = i
			break
	return best


## Kala, joka kävi uistimessa mutta ei tarttunut, on hetken varovainen
func spook(index: int) -> void:
	fish[index]["wary"] = 600.0
	fish[index]["hunger"] *= 0.5


## Saalis poistetaan, ja tilalle syntyy uusi kala jonnekin muualle
func remove_and_replace(index: int) -> void:
	var sp: String = fish[index]["sp"]
	var old_key: Vector2i = fish[index]["key"]
	fish[index] = _new_fish(sp, _random_habitat(sp))
	fish[index]["key"] = old_key
	_update_grid(index)


## Kaikuluotaimen keila: kalat pisteen alla [syvyys, paino]
func fish_under(p: Vector2, depth: float) -> Array:
	var result := []
	var radius := 1.0 + depth * 0.35
	for i in fish_near(p, radius):
		result.append([fish[i]["depth"], fish[i]["weight"]])
	return result
