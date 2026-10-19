class_name Lures
## Uistimet.
## sink-tyyppi: uppoaa levossa (sink m/s), nousee vedettäessä (lift m/s nopeuden m/s kohden),
##             mutta pysyy aina pinnan alla
## dive-tyyppi: kelluu levossa pinnalle (float m/s), vedettäessä ui max_dive-syvyydessä
## cast: heitto-ominaisuus (paino, ilmanvastus) – suurempi lentää pidemmälle
## snag: alttius tarttua pohjaan, kun uistin laahaa pohjaa
## price: hinta uramoodin kalastustarvikeliikkeessä (€)
## pull: uistimen vesivastus (kg) nopeudella 1 m/s – kasvaa nopeuden neliönä.
##       Sukeltava vaappu vastustaa paljon, jigi vähän.

## Pilkit (talvi): pystysuoraan avannosta, nykäistään ylös ja annetaan vajota
const ICE := [
	{"id": "pilkki", "price": 3, "name": "Pilkki + toukka 4 g", "kind": "sink", "sink": 0.5, "lift": 0.3, "cast": 0.5, "snag": 0.0, "pull": 0.03, "color": Color(0.85, 0.82, 0.75)},
	{"id": "tasuri", "price": 9, "name": "Tasapainopilkki 7 cm", "kind": "sink", "sink": 0.7, "lift": 0.3, "cast": 0.5, "snag": 0.0, "pull": 0.05, "color": Color(0.3, 0.75, 0.35)},
]

const LIST := [
	{"id": "lusikka", "price": 6, "pull": 0.12, "name": "Lusikka 15 g", "kind": "sink", "sink": 0.9, "lift": 1.15, "cast": 1.0, "snag": 0.12, "color": Color(0.85, 0.75, 0.3)},
	{"id": "vaappu", "price": 12, "pull": 0.22, "name": "Kelluva vaappu 9 cm", "kind": "dive", "float": 0.45, "max_dive": 1.6, "cast": 0.75, "snag": 0.05, "color": Color(0.2, 0.6, 0.3)},
	{"id": "syvavaappu", "price": 14, "pull": 0.35, "name": "Syvävaappu 3 m", "kind": "dive", "float": 0.4, "max_dive": 3.0, "cast": 0.7, "snag": 0.12, "color": Color(0.85, 0.3, 0.2)},
	{"id": "lippa", "price": 5, "pull": 0.08, "name": "Lippa 6 g", "kind": "sink", "sink": 0.6, "lift": 0.9, "cast": 0.65, "snag": 0.06, "color": Color(0.9, 0.9, 0.9)},
	{"id": "jigi", "price": 4, "pull": 0.05, "name": "Jigi 10 g", "kind": "sink", "sink": 1.1, "lift": 0.9, "cast": 0.85, "snag": 0.05, "color": Color(0.95, 0.85, 0.15)},
]


static func all() -> Array:
	return LIST + ICE


static func name_of(id: String) -> String:
	for l in all():
		if l["id"] == id:
			return l["name"]
	return id
