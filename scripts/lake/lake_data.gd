class_name LakeData
extends RefCounted
## Järven korkeus-, vesi- ja maastotyyppiruudukot (tools/build_lake.py tekee ne).
## Maailman koordinaatit: X = itään, Z = etelään, Y = ylös, 0 = vedenpinta.

enum Ground { FOREST, FIELD, BOG, OPEN, ROCK, REEDS }

var name := ""
var attribution := ""
var depth_estimated := true
var cell_size := 4.0
var cols := 0
var rows := 0
var origin_x := 0.0
var origin_z := 0.0
var max_depth := 1.0
var start_position := Vector3.ZERO
var start_yaw := 0.0
var dock_length := 10.0
var rocks: Array = []
var places: Array = [] # [{name, x, z}]
var buildings: Array = [] # [{points: [[x, z], ...], height}]
var towers: Array = []

var heights := PackedFloat32Array()
var water := PackedByteArray()
var ground := PackedByteArray()
var shore := PackedByteArray() # uint16 little-endian, metrit rantaviivaan


static func load_from(dir: String) -> LakeData:
	var lake := LakeData.new()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("lake.json")))
	lake.name = meta.get("name", "")
	lake.attribution = meta.get("attribution", "")
	lake.depth_estimated = meta.get("depth_estimated", true)
	lake.cell_size = meta["cell_size"]
	lake.cols = int(meta["cols"])
	lake.rows = int(meta["rows"])
	lake.origin_x = meta["origin_x"]
	lake.origin_z = meta["origin_z"]
	lake.max_depth = meta.get("max_depth", 4.0)
	var start: Dictionary = meta["start"]
	lake.start_position = Vector3(start["x"], 0.0, start["z"])
	lake.start_yaw = deg_to_rad(start["yaw_deg"])
	lake.dock_length = start.get("dock_length", 10.0)
	lake.rocks = meta.get("rocks", [])
	lake.places = meta.get("places", [])
	lake.buildings = meta.get("buildings", [])
	lake.towers = meta.get("towers", [])

	lake.heights = FileAccess.get_file_as_bytes(dir.path_join("heights.bin")).to_float32_array()
	lake.water = FileAccess.get_file_as_bytes(dir.path_join("water.bin"))
	lake.ground = FileAccess.get_file_as_bytes(dir.path_join("ground.bin"))
	lake.shore = FileAccess.get_file_as_bytes(dir.path_join("shore.bin"))
	assert(lake.heights.size() == lake.cols * lake.rows, "heights.bin on väärän kokoinen")
	return lake


func world_size() -> Vector2:
	return Vector2(cols * cell_size, rows * cell_size)


func cell_height(c: int, r: int) -> float:
	c = clampi(c, 0, cols - 1)
	r = clampi(r, 0, rows - 1)
	return heights[r * cols + c]


func cell_is_water(c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return false
	return water[r * cols + c] == 1


func cell_ground(c: int, r: int) -> int:
	c = clampi(c, 0, cols - 1)
	r = clampi(r, 0, rows - 1)
	return ground[r * cols + c]


## Maaston tai pohjan korkeus (bilineaarinen interpolointi)
func height_at(x: float, z: float) -> float:
	var fx := (x - origin_x) / cell_size
	var fz := (z - origin_z) / cell_size
	var c := floori(fx)
	var r := floori(fz)
	var tx := fx - c
	var tz := fz - r
	var h00 := cell_height(c, r)
	var h10 := cell_height(c + 1, r)
	var h01 := cell_height(c, r + 1)
	var h11 := cell_height(c + 1, r + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func is_water(x: float, z: float) -> bool:
	return cell_is_water(floori((x - origin_x) / cell_size), floori((z - origin_z) / cell_size))


## Veden syvyys metreinä (0 maalla)
func depth_at(x: float, z: float) -> float:
	if not is_water(x, z):
		return 0.0
	return maxf(0.0, -height_at(x, z))


func cell_shore_distance(c: int, r: int) -> float:
	c = clampi(c, 0, cols - 1)
	r = clampi(r, 0, rows - 1)
	return shore.decode_u16((r * cols + c) * 2)


## Etäisyys rantaviivaan metreinä (vedessä lähimpään maahan, maalla lähimpään veteen)
func shore_distance(x: float, z: float) -> float:
	return cell_shore_distance(floori((x - origin_x) / cell_size), floori((z - origin_z) / cell_size))


func ground_at(x: float, z: float) -> int:
	return cell_ground(floori((x - origin_x) / cell_size), floori((z - origin_z) / cell_size))


func cell_center(c: int, r: int) -> Vector2:
	return Vector2(origin_x + (c + 0.5) * cell_size, origin_z + (r + 0.5) * cell_size)


## Lähin paikannimi, esim. "Saunasaari" (tyhjä, jos mikään ei ole lähellä)
func nearest_place(x: float, z: float, max_distance := 600.0) -> String:
	var best := ""
	var best_d := max_distance
	for place in places:
		var d := Vector2(place["x"] - x, place["z"] - z).length()
		if d < best_d:
			best_d = d
			best = place["name"]
	return best


## Lähellä olevan kaislikon tai rannan läheisyys (0..1), käytetään kalojen elinpaikkoina
func reeds_near(x: float, z: float, radius := 20.0) -> float:
	var steps := 4
	var hits := 0
	var total := 0
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			total += 1
			if ground_at(x + i * radius / steps, z + j * radius / steps) == Ground.REEDS:
				hits += 1
	return float(hits) / total
