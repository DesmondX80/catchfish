class_name GameSeed
## Pelin satunnaisuuden siemen: --seed=N kiinnittää kaikki satunnaislukugeneraattorit,
## muuten siemen arvotaan. Siemen tulostetaan aina, jotta ajon voi toistaa.

## Perussiemen, josta alijärjestelmien siemenet johdetaan
static var base: int


## Lukee --seed=N:n tai arpoo siemenen, siementää globaalin randf():n ja tulostaa siemenen
static func setup() -> void:
	var given := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var text := arg.substr(7)
			if text.is_valid_int() and int(text) >= 0:
				base = int(text)
				given = true
			else:
				push_warning("Virheellinen --seed: %s (siemen arvotaan)" % text)
	if not given:
		randomize()
		base = randi()
	seed(base)
	print("Siemen: %d (toista: --seed=%d)" % [base, base])


## Alijärjestelmän oma siemen: yhden järjestelmän uusi arvonta ei muuta muiden lukuja
static func of(name: String) -> int:
	return ("%d:%s" % [base, name]).hash()
