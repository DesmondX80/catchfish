class_name SkyTime
extends Node
## Pelin kello, aurinko ja taivas. Auringon korkeus lasketaan Raahen
## leveysasteelle valitulle päivälle, joten kesäkuussa yö jää hämäräksi.
## Pilvisyys himmentää valon, pehmentää varjot ja harmaannuttaa taivaan;
## sade tuo usvaa.

signal hour_changed(hour: float)

const LATITUDE := 64.6
const TIME_SCALES := [1.0, 10.0, 60.0]

@export var day_of_year := 165 # kesäkuun puoliväli
var minutes := 5.0 * 60.0 + 30.0 # 05:30
var time_scale_index := 1
## Todellinen aika: kello ja päivämäärä tietokoneen kellosta, aika kulkee reaaliajassa
var real_time := false

var sun: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
var weather: Weather
var horizon_color := Color(0.72, 0.78, 0.84) # vedenpinnan heijastukselle
var _cloud_offset := Vector2.ZERO


func setup(sun_light: DirectionalLight3D, env: Environment, weather_node: Weather) -> void:
	sun = sun_light
	environment = env
	weather = weather_node
	sky_material = env.sky.sky_material
	_update_sun()


func time_scale() -> float:
	return 1.0 if real_time else TIME_SCALES[time_scale_index]


func cycle_time_scale() -> void:
	if not real_time:
		time_scale_index = (time_scale_index + 1) % TIME_SCALES.size()


## Asettaa kellon ja päivämäärän tietokoneen kellosta
func sync_to_system_clock() -> void:
	var t := Time.get_datetime_dict_from_system()
	minutes = t["hour"] * 60.0 + t["minute"] + t["second"] / 60.0
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": t["year"], "month": 1, "day": 1})
	var today := Time.get_unix_time_from_datetime_dict({"year": t["year"], "month": t["month"], "day": t["day"]})
	day_of_year = int((today - jan1) / 86400.0) + 1


func hour() -> float:
	return fmod(minutes / 60.0, 24.0)


func clock_text() -> String:
	var m := int(minutes) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


func _process(delta: float) -> void:
	var before := int(hour())
	if real_time:
		sync_to_system_clock()
	else:
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
	var cover := weather.cloud_cover if weather else 0.3
	var rain := weather.rain if weather else 0.0

	sun.light_color = Color(1.0, 0.62, 0.4).lerp(Color(1.0, 0.97, 0.9), low)
	sun.light_energy = lerpf(0.05, 1.15, light) * (1.0 - cover * 0.75)
	sun.shadow_opacity = 1.0 - cover * 0.8 # pilvisellä varjot ovat haaleat

	var top := Color(0.12, 0.16, 0.32).lerp(Color(0.32, 0.5, 0.78), light)
	var horizon := Color(0.55, 0.45, 0.45).lerp(Color(0.72, 0.78, 0.84), low).lerp(Color(0.2, 0.22, 0.3), 1.0 - light)
	var overcast := Color(0.5, 0.52, 0.55) * lerpf(0.2, 1.0, light)
	var grey := smoothstep(0.5, 1.0, cover) * 0.75
	horizon_color = horizon.lerp(overcast, grey)

	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = top.lerp(horizon, 0.5).lerp(overcast, grey)
	environment.ambient_light_energy = lerpf(0.25, 0.8, light) * (1.0 + cover * 0.2)
	environment.fog_light_color = Color(0.25, 0.28, 0.35).lerp(Color(0.68, 0.74, 0.8), light).lerp(overcast, grey)
	environment.fog_density = 0.0006 + rain * 0.005 # sade heikentää näkyvyyttä

	sky_material.set_shader_parameter("top_color", top)
	sky_material.set_shader_parameter("horizon_color", horizon)
	sky_material.set_shader_parameter("ground_color", horizon * 0.6)
	sky_material.set_shader_parameter("sun_dir", dir)
	sky_material.set_shader_parameter("sun_color", sun.light_color)
	sky_material.set_shader_parameter("daylight", light)
	sky_material.set_shader_parameter("cover", cover)
	sky_material.set_shader_parameter("darkness", rain)
	if weather:
		# Pilvet ajelehtivat tuulen mukana (todellisessa ajassa, jotta liike näkyy)
		_cloud_offset += weather.vector() * get_process_delta_time() * 0.0015
		sky_material.set_shader_parameter("cloud_offset", _cloud_offset)
