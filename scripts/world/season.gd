class_name Season
extends RefCounted
## Vuodenaika päivämäärän mukaan Raahen leveysasteella (64,6° P).
## Arvot muuttuvat liukuvasti päivästä toiseen, joten esim. ruska ja
## lehtien putoaminen etenevät vähitellen.

var day := 165
var name := "kesä"
var snow := 0.0 # lumipeite maassa 0..1
var leaves := 1.0 # koivun lehtien määrä 0 (paljas) .. 1
var autumn := 0.0 # ruska: 0 vihreä .. 1 keltainen/oranssi
var spring := 0.0 # puhkeava lehti: 1 = vaalea kevätvihreä
var grass_dry := 0.0 # ruohon kuivuus/ruskeus 0 vihreä .. 1 ruskea
var reeds_dry := 0.0 # kaislojen kellastuminen 0 .. 1


## Liukuva siirtymä päivien a ja b välillä (0 ennen a:ta, 1 b:n jälkeen)
static func _ramp(d: float, a: float, b: float) -> float:
	return clampf((d - a) / (b - a), 0.0, 1.0)


static func from_day(day_of_year: int) -> Season:
	var s := Season.new()
	var d := float(day_of_year)
	s.day = day_of_year
	# Lumi: tulee marraskuussa (päivät 305–335), sulaa huhtikuussa (100–125)
	s.snow = maxf(1.0 - _ramp(d, 100.0, 125.0), _ramp(d, 305.0, 335.0))
	# Koivu: puhkeaa 135–155, ruska 244–274, lehdet putoavat 274–295
	s.leaves = _ramp(d, 135.0, 155.0) * (1.0 - _ramp(d, 274.0, 295.0))
	s.spring = 1.0 - _ramp(d, 150.0, 172.0) if d >= 135.0 else 0.0
	s.autumn = _ramp(d, 244.0, 274.0)
	# Ruoho vihertyy toukokuussa ja ruskettuu syyskuusta alkaen
	s.grass_dry = maxf(1.0 - _ramp(d, 125.0, 152.0), _ramp(d, 240.0, 285.0))
	s.reeds_dry = maxf(1.0 - _ramp(d, 140.0, 175.0), _ramp(d, 235.0, 270.0))
	if s.snow > 0.6:
		s.name = "talvi"
	elif d < 152.0:
		s.name = "kevät"
	elif d < 244.0:
		s.name = "kesä"
	elif d < 274.0:
		s.name = "ruska-aika"
	elif d < 305.0:
		s.name = "myöhäissyksy"
	else:
		s.name = "alkutalvi"
	return s


## Ruohon ja aluskasvillisuuden värin muutos: vihreä -> kuiva ruskea
func tint_grass(c: Color) -> Color:
	var dry := Color(0.42, 0.36, 0.22) * (0.75 + c.v * 0.6)
	return c.lerp(dry, grass_dry * 0.85)


## Lumi peittää maan; sulamisaikana lumi jää laikuiksi (patch 0..1 = solukohtainen satunnaisluku)
func snowy(c: Color, patch: float, shade := 0.0) -> Color:
	var cover := clampf(snow * 1.6 - patch * 0.6 + shade * 0.4, 0.0, 1.0) if snow < 0.99 else 1.0
	return c.lerp(Color(0.9, 0.92, 0.95), cover)


func birch_leaf_color(base: Color) -> Color:
	var c := base.lerp(Color(0.55, 0.75, 0.25), spring * 0.7) # kevään vaalea vihreä
	return c.lerp(Color(0.88, 0.62, 0.12), autumn) # ruska


func reed_color(c: Color) -> Color:
	return c.lerp(Color(0.68, 0.58, 0.36), reeds_dry * 0.8)
