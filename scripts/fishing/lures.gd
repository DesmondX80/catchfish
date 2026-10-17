class_name Lures
## Uistimet.
## sink-tyyppi: uppoaa levossa (sink m/s), nousee vedettäessä (lift m/s nopeuden m/s kohden)
## dive-tyyppi: kelluu levossa (float m/s), sukeltaa vedettäessä max_dive-syvyyteen
## cast: heitto-ominaisuus (paino, ilmanvastus) – suurempi lentää pidemmälle
## snag: alttius tarttua pohjaan, kun uistin laahaa pohjaa

const LIST := [
	{"id": "lusikka", "name": "Lusikka 15 g", "kind": "sink", "sink": 0.45, "lift": 0.55, "cast": 1.0, "snag": 0.12, "color": Color(0.85, 0.75, 0.3)},
	{"id": "vaappu", "name": "Kelluva vaappu 9 cm", "kind": "dive", "float": 0.15, "max_dive": 1.6, "cast": 0.75, "snag": 0.05, "color": Color(0.2, 0.6, 0.3)},
	{"id": "syvavaappu", "name": "Syvävaappu 3 m", "kind": "dive", "float": 0.12, "max_dive": 3.0, "cast": 0.7, "snag": 0.12, "color": Color(0.85, 0.3, 0.2)},
	{"id": "lippa", "name": "Lippa 6 g", "kind": "sink", "sink": 0.3, "lift": 0.8, "cast": 0.65, "snag": 0.06, "color": Color(0.9, 0.9, 0.9)},
	{"id": "jigi", "name": "Jigi 10 g", "kind": "sink", "sink": 0.8, "lift": 0.3, "cast": 0.85, "snag": 0.05, "color": Color(0.95, 0.85, 0.15)},
]
