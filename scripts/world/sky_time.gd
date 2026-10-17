class_name SkyTime
extends Node
## Pelin kello ja aurinko. Auringon korkeus lasketaan Raahen leveysasteelle
## valitulle päivälle, joten kesäkuussa yö jää hämäräksi.

signal hour_changed(hour: float)

const LATITUDE := 64.6
const TIME_SCALES := [1.0, 10.0, 60.0]

@export var day_of_year := 165 # kesäkuun puoliväli
var minutes := 5.0 * 60.0 + 30.0 # 05:30
var time_scale_index := 1

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ProceduralSkyMaterial
var cloudiness := 0.3


func setup(sun_light: DirectionalLight3D, env: Environment) -> void:
	sun = sun_light
	environment = env
	sky_material = env.sky.sky_material
	_update_sun()


func time_scale() -> float:
	return TIME_SCALES[time_scale_index]


func cycle_time_scale() -> void:
	time_scale_index = (time_scale_index + 1) % TIME_SCALES.size()


func hour() -> float:
	return fmod(minutes / 60.0, 24.0)


func clock_text() -> String:
	var m := int(minutes) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


func _process(delta: float) -> void:
	var before := int(hour())
	minutes += delta * time_scale() / 60.0
	if int(hour()) != before:
		hour_changed.emit(hour())
	_update_sun()


## Auringon korkeus- ja atsimuuttikulma (radiaaneina) yksinkertaisella mallilla
func sun_angles() -> Vector2:
	var lat := deg_to_rad(LATITUDE)
	var decl := deg_to_rad(23.44) * sin(TAU * (day_of_year - 81) / 365.0)
	var hour_angle := deg_to_rad(15.0 * (hour() - 12.0))
	var elevation := asin(sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos(hour_angle))
	var azimuth := atan2(sin(hour_angle), cos(hour_angle) * sin(lat) - tan(decl) * cos(lat)) + PI
	return Vector2(elevation, azimuth)


## Valoisuus 0 (yö) .. 1 (päivä)
func daylight() -> float:
	return clampf((rad_to_deg(sun_angles().x) + 6.0) / 18.0, 0.0, 1.0)


func _update_sun() -> void:
	if sun == null:
		return
	var angles := sun_angles()
	var elevation := maxf(angles.x, deg_to_rad(-4.0))
	# Atsimuutti pohjoisesta myötäpäivään; Godotissa pohjoinen = -Z, itä = +X
	var dir := Vector3(sin(angles.y) * cos(elevation), sin(elevation), -cos(angles.y) * cos(elevation))
	sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	var light := daylight()
	var low := clampf(rad_to_deg(angles.x) / 12.0, 0.0, 1.0)
	sun.light_color = Color(1.0, 0.62, 0.4).lerp(Color(1.0, 0.97, 0.9), low)
	sun.light_energy = lerpf(0.05, 1.15, light) * (1.0 - cloudiness * 0.5)
	environment.ambient_light_energy = lerpf(0.25, 0.8, light)
	environment.fog_light_color = Color(0.25, 0.28, 0.35).lerp(Color(0.68, 0.74, 0.8), light)
	sky_material.sky_top_color = Color(0.12, 0.16, 0.32).lerp(Color(0.32, 0.5, 0.78), light)
	sky_material.sky_horizon_color = Color(0.55, 0.45, 0.45).lerp(Color(0.72, 0.78, 0.84), low).lerp(Color(0.2, 0.22, 0.3), 1.0 - light)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.sky_energy_multiplier = lerpf(0.25, 1.0, light)
