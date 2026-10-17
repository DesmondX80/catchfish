class_name Species
## Kalalajien ominaisuudet. Arvot ovat suuntaa-antavia ja niitä on helppo säätää tästä.
##
## depth          viihtymissyvyys (m) [min, max]
## shore          suosittu etäisyys rannasta (m) [min, max]
## reeds          kaislikon läheisyyden merkitys elinpaikalle (0..1)
## bottom         pysytteleekö pohjan lähellä
## activity       syöntiaktiivisuus vuorokauden tunnin mukaan [[tunti, arvo], ...]
## lures          kiinnostus uistintyyppeihin (0..1)
## speed          mieluisin uistimen nopeus (m/s) [paras, sallittu poikkeama]
## detect         havaintoetäisyys (m) – tummassa humusvedessä kala vaistoaa uistimen värinän
## aggression     iskuherkkyys
## power          voima suhteessa painoon (väsytys)
## weight         painojakauma: [mediaani kg, hajonta (log), min, max]
## length_a       paino (g) = length_a * pituus (cm)^3
## per_km2        kalojen määrä neliökilometrillä
## school         parven koko

const DATA := {
	"hauki": {
		"name": "Hauki",
		"color": Color(0.38, 0.45, 0.25),
		"depth": [0.4, 2.8],
		"shore": [0.0, 90.0],
		"reeds": 0.9,
		"bottom": false,
		"activity": [[0, 0.25], [4, 0.6], [7, 1.0], [12, 0.6], [17, 0.9], [21, 0.8], [24, 0.25]],
		"lures": {"lusikka": 1.0, "vaappu": 0.9, "syvavaappu": 0.5, "lippa": 0.45, "jigi": 0.5},
		"speed": [0.9, 0.6],
		"detect": 10.0,
		"aggression": 0.9,
		"power": 1.0,
		"weight": [1.6, 0.7, 0.4, 14.0],
		"length_a": 0.0063,
		"per_km2": 400,
		"school": 1,
	},
	"ahven": {
		"name": "Ahven",
		"color": Color(0.5, 0.52, 0.3),
		"depth": [0.8, 3.5],
		"shore": [0.0, 200.0],
		"reeds": 0.4,
		"bottom": false,
		"activity": [[0, 0.05], [5, 0.4], [9, 1.0], [15, 1.0], [20, 0.5], [23, 0.05], [24, 0.05]],
		"lures": {"lusikka": 0.5, "vaappu": 0.5, "syvavaappu": 0.4, "lippa": 1.0, "jigi": 0.95},
		"speed": [0.6, 0.5],
		"detect": 6.0,
		"aggression": 1.4,
		"power": 0.8,
		"weight": [0.15, 0.6, 0.04, 1.6],
		"length_a": 0.0125,
		"per_km2": 2500,
		"school": 30,
	},
	"kuha": {
		"name": "Kuha",
		"color": Color(0.55, 0.55, 0.48),
		"depth": [2.2, 5.0],
		"shore": [60.0, 2000.0],
		"reeds": 0.0,
		"bottom": true,
		"activity": [[0, 1.0], [4, 0.8], [7, 0.25], [12, 0.1], [18, 0.3], [21, 0.9], [24, 1.0]],
		"lures": {"lusikka": 0.35, "vaappu": 0.6, "syvavaappu": 1.0, "lippa": 0.3, "jigi": 1.0},
		"speed": [0.6, 0.45],
		"detect": 7.0,
		"aggression": 0.7,
		"power": 0.75,
		"weight": [1.1, 0.6, 0.3, 8.0],
		"length_a": 0.0085,
		"per_km2": 250,
		"school": 4,
	},
	"taimen": {
		"name": "Taimen",
		"color": Color(0.62, 0.58, 0.45),
		"depth": [0.2, 2.5],
		"shore": [40.0, 2000.0],
		"reeds": 0.0,
		"bottom": false,
		"activity": [[0, 0.5], [3, 1.0], [7, 0.6], [12, 0.2], [18, 0.5], [22, 1.0], [24, 0.5]],
		"lures": {"lusikka": 0.9, "vaappu": 1.0, "syvavaappu": 0.4, "lippa": 0.9, "jigi": 0.2},
		"speed": [1.3, 0.6],
		"detect": 9.0,
		"aggression": 0.8,
		"power": 1.35,
		"weight": [1.3, 0.5, 0.4, 6.0],
		"length_a": 0.011,
		"per_km2": 60,
		"school": 1,
	},
}


static func activity(species_id: String, hour: float) -> float:
	var curve: Array = DATA[species_id]["activity"]
	for i in curve.size() - 1:
		var a: Array = curve[i]
		var b: Array = curve[i + 1]
		if hour >= a[0] and hour <= b[0]:
			return lerpf(a[1], b[1], (hour - a[0]) / float(b[0] - a[0]))
	return curve[0][1]


static func random_weight(species_id: String, rng: RandomNumberGenerator) -> float:
	var w: Array = DATA[species_id]["weight"]
	return clampf(w[0] * exp(rng.randfn(0.0, w[1])), w[2], w[3])


static func length_cm(species_id: String, weight_kg: float) -> float:
	return pow(weight_kg * 1000.0 / DATA[species_id]["length_a"], 1.0 / 3.0)
