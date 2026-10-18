class_name RealWeather
extends Node
## Todellinen sää Saloisissa (Raahe, 92160).
## Ensisijaisesti Ilmatieteen laitoksen havainnot Raahen Lapaluodon asemalta
## (n. 5 km Saloisista): lämpötila, tuuli, puuskat, pilvisyys (oktaa) ja
## sääkoodi (wawa), josta saadaan sateen laatu ja voimakkuus. Jos haku ei
## onnistu, käytetään Open-Meteon säätietoja Saloisten koordinaateille.
## Molemmat aineistot: CC BY 4.0.
##
## Ilmatieteen laitoksen palvelimen varmenteen myöntäjä (HARICA) puuttuu Godotin
## mukana tulevasta varmennelistasta, joten sen juurivarmenteet ovat pelissä
## mukana (assets/certs/harica_roots.crt) ja niitä käytetään vain FMI:n haussa.

signal updated(data: Dictionary)
signal failed(message: String)

const LAT := 64.62
const LON := 24.45
const FMI_PARAMS := "t2m,ws_10min,wg_10min,wd_10min,n_man,wawa"
const FMI_ROOTS := "res://assets/certs/harica_roots.crt"

var last: Dictionary = {}
var _http: HTTPRequest
var _stage := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_completed)


func fetch() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return # haku on jo käynnissä
	var start := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) - 3600) + "Z"
	var url := "https://opendata.fmi.fi/wfs?service=WFS&version=2.0.0&request=getFeature" \
		+ "&storedquery_id=fmi::observations::weather::simple&place=Raahe&maxlocations=1&timestep=10" \
		+ "&parameters=" + FMI_PARAMS + "&starttime=" + start
	_stage = "fmi"
	var roots := X509Certificate.new()
	if roots.load(FMI_ROOTS) == OK:
		_http.set_tls_options(TLSOptions.client(roots))
	if _http.request(url) != OK:
		_fetch_open_meteo()


func _fetch_open_meteo() -> void:
	_stage = "open-meteo"
	_http.set_tls_options(TLSOptions.client()) # järjestelmän tavalliset varmenteet
	var url := "https://api.open-meteo.com/v1/forecast?latitude=%.2f&longitude=%.2f" % [LAT, LON] \
		+ "&current=temperature_2m,precipitation,snowfall,cloud_cover,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code" \
		+ "&wind_speed_unit=ms&timezone=Europe%2FHelsinki"
	if _http.request(url) != OK:
		failed.emit("Säätietoja ei saatu haettua")


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200
	var data := {}
	if ok:
		data = parse_fmi(body.get_string_from_utf8()) if _stage == "fmi" else parse_open_meteo(body.get_string_from_utf8())
	if data.is_empty():
		push_warning("Säähaku (%s) epäonnistui: tulos %d, HTTP %d" % [_stage, result, code])
		if _stage == "fmi":
			_fetch_open_meteo.call_deferred()
		else:
			failed.emit("Säätietoja ei saatu haettua (ei verkkoyhteyttä?)")
		return
	last = data
	updated.emit(data)


## Ilmatieteen laitoksen havainnot: viimeisin luku kustakin suureesta
static func parse_fmi(xml: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("<BsWfs:Time>([^<]*)</BsWfs:Time>\\s*<BsWfs:ParameterName>([^<]*)</BsWfs:ParameterName>\\s*<BsWfs:ParameterValue>([^<]*)</BsWfs:ParameterValue>")
	var latest := {}
	var times := {}
	for m in re.search_all(xml):
		var value := m.get_string(3).strip_edges()
		if value == "NaN" or value == "":
			continue
		latest[m.get_string(2)] = float(value)
		times[m.get_string(2)] = m.get_string(1)
	if not (latest.has("t2m") and latest.has("ws_10min") and latest.has("wd_10min")):
		return {}
	var wawa := int(latest.get("wawa", 0.0))
	var precip := precipitation_from_wawa(wawa)
	# Pilvisyys oktina (0–8); jos puuttuu, päätellään sääkoodista
	var cloud: float = latest["n_man"] / 8.0 if latest.has("n_man") else (0.95 if precip[0] > 0.0 else 0.4)
	if precip[0] > 0.0:
		cloud = maxf(cloud, 0.9)
	return {
		"source": "Ilmatieteen laitos, Raahe Lapaluoto",
		"time": _local_clock(times["t2m"]),
		"temperature": latest["t2m"],
		"wind_speed": latest["ws_10min"],
		"wind_gust": latest.get("wg_10min", latest["ws_10min"]),
		"wind_from_deg": latest["wd_10min"],
		"cloud": clampf(cloud, 0.0, 1.0),
		"precipitation": precip[0],
		"snow": precip[1],
	}


## WMO 4680 -sääkoodi (automaattiasema): [sateen voimakkuus 0..1, onko lunta]
static func precipitation_from_wawa(code: int) -> Array:
	match code:
		40, 41, 50, 51, 60, 61, 80, 81:
			return [0.25, false]
		52, 62, 82, 54, 55, 64, 65:
			return [0.5, false]
		42, 53, 63, 83, 84, 56, 66:
			return [0.85, false]
		67, 68:
			return [0.5, true]
		70, 71, 85:
			return [0.25, true]
		72, 86:
			return [0.5, true]
		73, 87, 74, 75, 76, 89:
			return [0.85, true]
	return [0.0, false]


## Open-Meteo (varalla): mallin nykyhetken arvot
static func parse_open_meteo(text: String) -> Dictionary:
	var json = JSON.parse_string(text)
	if not (json is Dictionary and json.has("current")):
		return {}
	var c: Dictionary = json["current"]
	var mm: float = c.get("precipitation", 0.0)
	var snow: bool = c.get("snowfall", 0.0) > 0.0
	return {
		"source": "Open-Meteo, Saloinen",
		"time": String(c.get("time", "")).right(5),
		"temperature": c.get("temperature_2m", 0.0),
		"wind_speed": c.get("wind_speed_10m", 0.0),
		"wind_gust": c.get("wind_gusts_10m", c.get("wind_speed_10m", 0.0)),
		"wind_from_deg": c.get("wind_direction_10m", 0.0),
		"cloud": clampf(c.get("cloud_cover", 0.0) / 100.0, 0.0, 1.0),
		# mm/h -> 0..1: 0,3 mm/h heikko, 1 mm/h kohtalainen, 4 mm/h rankka
		"precipitation": 0.0 if mm <= 0.0 else clampf(0.2 + log(mm / 0.3 + 1.0) * 0.28, 0.2, 1.0),
		"snow": snow,
	}


## UTC-aikaleima (2026-10-18T08:50:00Z) paikalliseksi kellonajaksi
static func _local_clock(utc: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(utc.trim_suffix("Z"))
	var bias: int = Time.get_time_zone_from_system()["bias"] * 60
	var t := Time.get_datetime_dict_from_unix_time(int(unix) + bias)
	return "%02d:%02d" % [t["hour"], t["minute"]]


## Sää sanoin valikkoon, esim. "6,7 °C, melkein selkeää, tuuli 2,5 m/s koillisesta"
static func summary(data: Dictionary) -> String:
	var w := Weather.new()
	w.cloud_cover = data["cloud"]
	w.rain = data["precipitation"]
	w.snow = data["snow"]
	w.wind_direction = deg_to_rad(data["wind_from_deg"] + 180.0)
	var text := "%s °C, %s, tuuli %s m/s %s" % [
		_fi(data["temperature"]), w.description().to_lower(), _fi(data["wind_speed"]), w.from_text()]
	w.free()
	return text


static func _fi(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")
