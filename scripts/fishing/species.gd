class_name Species
## Kalalajien ominaisuudet. Arvot ovat suuntaa-antavia ja niitä on helppo säätää tästä.
## Lajisto: Haapajärven tekoaltaan kalakanta – ahven, särki, hauki, kiiski, lahna ja made.
## Särkikalat, kiiski ja made syövät mieluiten syöttiä (pilkki + toukka), uistimiin harvoin.
##
## depth          viihtymissyvyys (m) [min, max]
## shore          suosittu etäisyys rannasta (m) [min, max]
## reeds          kaislikon läheisyyden merkitys elinpaikalle (0..1)
## bottom         pysytteleekö pohjan lähellä
## activity       syöntiaktiivisuus vuorokauden tunnin mukaan [[tunti, arvo], ...]
## season         aktiivisuuden kerroin [avovesikausi, talvi] – made syö kylmässä vedessä
## light_shy      valoa karttava: syö pilvisellä säällä myös päivällä (made)
## lures          kiinnostus uistintyyppeihin ja syöttiin (koho, pohja = mato) (0..1)
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
		"season": [1.0, 0.7],
		"lures": {"lusikka": 1.0, "vaappu": 0.9, "syvavaappu": 0.5, "lippa": 0.45, "jigi": 0.5, "pilkki": 0.3, "tasuri": 0.8, "koho": 0.05, "pohja": 0.08},
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
		"season": [1.0, 0.8],
		"lures": {"lusikka": 0.5, "vaappu": 0.5, "syvavaappu": 0.4, "lippa": 1.0, "jigi": 0.95, "pilkki": 1.0, "tasuri": 0.85, "koho": 0.8, "pohja": 0.6},
		"speed": [0.6, 0.5],
		"detect": 6.0,
		"aggression": 1.4,
		"power": 0.8,
		"weight": [0.15, 0.6, 0.04, 1.6],
		"length_a": 0.0125,
		"per_km2": 2500,
		"school": 30,
	},
	"sarki": {
		"name": "Särki",
		"color": Color(0.6, 0.62, 0.6),
		"depth": [0.4, 3.0],
		"shore": [0.0, 150.0],
		"reeds": 0.6,
		"bottom": false,
		"activity": [[0, 0.2], [5, 0.7], [10, 1.0], [16, 0.9], [21, 0.6], [24, 0.2]],
		"season": [1.0, 0.7],
		"lures": {"lusikka": 0.04, "vaappu": 0.03, "syvavaappu": 0.02, "lippa": 0.2, "jigi": 0.15, "pilkki": 1.0, "tasuri": 0.12, "koho": 1.0, "pohja": 0.8},
		"speed": [0.25, 0.35],
		"detect": 4.0,
		"aggression": 0.6,
		"power": 0.7,
		"weight": [0.12, 0.55, 0.03, 1.4],
		"length_a": 0.0128,
		"per_km2": 2000,
		"school": 25,
	},
	"kiiski": {
		"name": "Kiiski",
		"color": Color(0.5, 0.46, 0.3),
		"depth": [1.5, 5.0],
		"shore": [20.0, 2000.0],
		"reeds": 0.0,
		"bottom": true,
		"activity": [[0, 0.6], [5, 0.8], [10, 0.6], [16, 0.6], [21, 0.9], [24, 0.6]],
		"season": [1.0, 1.1],
		"lures": {"lusikka": 0.04, "vaappu": 0.02, "syvavaappu": 0.05, "lippa": 0.15, "jigi": 0.55, "pilkki": 1.0, "tasuri": 0.3, "koho": 0.7, "pohja": 1.0},
		"speed": [0.15, 0.35],
		"detect": 3.0,
		"aggression": 1.0,
		"power": 0.5,
		"weight": [0.03, 0.45, 0.01, 0.18],
		"length_a": 0.0145,
		"per_km2": 1000,
		"school": 15,
	},
	"lahna": {
		"name": "Lahna",
		"color": Color(0.58, 0.52, 0.36),
		"depth": [1.5, 4.5],
		"shore": [30.0, 2000.0],
		"reeds": 0.2,
		"bottom": true,
		"activity": [[0, 0.7], [4, 1.0], [8, 0.5], [16, 0.4], [20, 0.9], [24, 0.7]],
		"season": [1.0, 0.35],
		"lures": {"lusikka": 0.02, "vaappu": 0.01, "syvavaappu": 0.02, "lippa": 0.04, "jigi": 0.08, "pilkki": 0.7, "tasuri": 0.04, "koho": 0.9, "pohja": 1.0},
		"speed": [0.1, 0.3],
		"detect": 4.0,
		"aggression": 0.35,
		"power": 0.6,
		"weight": [1.0, 0.55, 0.25, 6.0],
		"length_a": 0.0143,
		"per_km2": 400,
		"school": 10,
	},
	"made": {
		"name": "Made",
		"color": Color(0.45, 0.4, 0.22),
		"depth": [2.0, 5.0],
		"shore": [10.0, 2000.0],
		"reeds": 0.0,
		"bottom": true,
		"activity": [[0, 1.0], [5, 0.6], [8, 0.15], [16, 0.15], [20, 0.7], [24, 1.0]],
		"season": [0.25, 1.6],
		"light_shy": true,
		"lures": {"lusikka": 0.05, "vaappu": 0.03, "syvavaappu": 0.08, "lippa": 0.05, "jigi": 0.3, "pilkki": 1.0, "tasuri": 0.5, "koho": 0.3, "pohja": 1.0},
		"speed": [0.1, 0.3],
		"detect": 5.0,
		"aggression": 0.7,
		"power": 0.75,
		"weight": [0.7, 0.55, 0.2, 5.0],
		"length_a": 0.0072,
		"per_km2": 200,
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
