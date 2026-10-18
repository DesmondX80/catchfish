extends Node
## Pelaajan asetukset, tallennetaan koneelle (user://asetukset.cfg).

const PATH := "user://asetukset.cfg"

## Todellinen kellonaika ja sää (Saloinen, Raahe)
var real_world := false
## Testiajot eivät tallenna asetuksia pelaajan koneelle
var persist := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		real_world = cfg.get_value("peli", "todellinen_aika_ja_saa", false)
	# Testiajot eivät käytä pelaajan asetuksia
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			real_world = false
			persist = false


func save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("peli", "todellinen_aika_ja_saa", real_world)
	cfg.save(PATH)
