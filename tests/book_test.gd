extends Node
## Kalakirjan testi: godot --headless -- --day=180 --booktest
## Tarkistaa lajin avautumisen, saaliiden määrän ja ennätyksen, vanhan saaliskirjan
## siirron kirjaan, kirjan sivut (saamaton laji varjokuvana) ja taukovalikon
## Kalakirja-painikkeen sekä saalisikkunan "uusi laji" -ilmoituksen.
## Kuvat sivuista: godot --fixed-fps 30 -- --day=180 --booktest --bookshots=KANSIO

var main: Node
var _dir := ""
var _log: Array[String] = []


func _ready() -> void:
	main = get_parent()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bookshots="):
			_dir = arg.split("=")[1]
	await get_tree().process_frame
	_data_checks()
	await _view_checks()
	_menu_checks()
	_hud_checks()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _entry(sp: String, kg: float, date: String) -> Dictionary:
	return {"species": sp, "name": Species.DATA[sp]["name"] if Species.DATA.has(sp) else sp, "weight": kg,
		"length": Species.length_cm(sp, kg) if Species.DATA.has(sp) else 40.0, "lure": "Lusikka 15 g",
		"time": "10.00", "place": "Iso-Pappilansaari", "date": date}


func _data_checks() -> void:
	_check("testiajo ei tallenna kalakirjaa", not FishBook.persist)
	_check("kirja on aluksi tyhjä", FishBook.unlocked_count() == 0)
	# Vanhan saaliskirjan saaliit kirjaan; poistuneet lajit (kuha) jätetään pois
	FishBook.rebuild([_entry("hauki", 1.2, "2026-06-01 10:00:00"), _entry("hauki", 2.4, "2026-06-03 18:30:00"),
		_entry("kuha", 1.0, "2026-06-02 12:00:00"), _entry("ahven", 0.2, "2026-06-04 09:00:00")])
	_check("vanhoista saaliista avautuu hauki ja ahven", FishBook.unlocked("hauki") and FishBook.unlocked("ahven") and FishBook.unlocked_count() == 2)
	_check("kuha ei ole kirjassa", not FishBook.unlocked("kuha"))
	_check("haukia 2 kpl, ennätys 2,4 kg", FishBook.count("hauki") == 2 and is_equal_approx(FishBook.best("hauki")["weight"], 2.4))
	_check("ensimmäinen hauki 1.6.", FishBook.first_date("hauki") == "2026-06-01 10:00:00")
	_check("uusi laji avautuu (made)", FishBook.add(_entry("made", 0.9, "2026-06-05 23:10:00")))
	_check("toinen made ei ole uusi laji", not FishBook.add(_entry("made", 0.5, "2026-06-06 23:10:00")))
	_check("pienempi made ei muuta ennätystä", is_equal_approx(FishBook.best("made")["weight"], 0.9) and FishBook.count("made") == 2)


func _view_checks() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20 # HUD:n ja ohjeen päälle kuten valikoissa
	add_child(layer)
	var view := FishBookView.new()
	layer.add_child(view)
	view.open()
	await get_tree().process_frame
	var texts := []
	for b in view._buttons.values():
		texts.append(b.text)
	_check("lajilistassa saadut lajit määrineen: %s" % ", ".join(texts), view._buttons["hauki"].text == "Hauki  (2)" and view._buttons["made"].text == "Made  (2)")
	_check("saamaton laji listassa nimettömänä", view._buttons["lahna"].text == "? ? ?")
	_check("edistyminen 3 / 6 lajia", view._progress.text == "Löydetty 3 / 6 lajia")
	_check("kirja aukeaa ensimmäisen saadun lajin sivulle", view.selected == "hauki")
	var stats: String = view._stats.text
	_check("hauen sivulla määrä, ennätys ja ensimmäinen saalis", "Saaliita: 2 kpl" in stats and "2,40 kg" in stats and "3.6.2026 klo 18.30" in stats and "1.6.2026 klo 10.00" in stats)
	_check("hauen sivulla kuvaus ja tieteellinen nimi", view._latin.text == "Esox lucius" and view._text.text.begins_with("Väijyvä petokala"))
	_check("vinkissä hauen paras viehe (lusikka)", "lusikka 15 g" in stats)
	await _shot("kalakirja_hauki")
	view.show_species("lahna")
	await _shot("kalakirja_tuntematon")
	_check("saamaton laji: ei nimeä eikä tietoja", view._name.text == "Tuntematon laji" and view._stats.text == "" and view._latin.text == "")
	_check("saamaton laji varjokuvana", view._picture.modulate.v < 0.2)
	view.show_species("made")
	_check("saadun lajin kuva normaali", view._picture.modulate == Color.WHITE and view._name.text == "Made")
	layer.queue_free()


func _shot(name: String) -> void:
	if _dir == "":
		return
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name + ".png"))


func _menu_checks() -> void:
	var pm: PauseMenu = main.pause_menu
	var labels := pm._buttons.map(func(b): return b.text)
	_check("taukovalikossa Kalakirja-painike", "Kalakirja" in labels)
	pm._show_book()
	_check("taukovalikosta aukeaa kalakirja", pm._book.visible and not pm._box.visible)
	pm._book.closed.emit()
	_check("kalakirjasta takaisin taukovalikkoon", not pm._book.visible and pm._box.visible)


func _hud_checks() -> void:
	FishBook.add(_entry("kiiski", 0.05, "2026-06-07 08:00:00"))
	main.hud._on_caught(_entry("kiiski", 0.05, "2026-06-07 08:00:00"), false)
	_check("saalisikkunassa uusi laji kalakirjaan", main.hud._catch_label.text.begins_with("UUSI LAJI KALAKIRJAAN!"))
	FishBook.add(_entry("kiiski", 0.06, "2026-06-07 08:10:00"))
	main.hud._on_caught(_entry("kiiski", 0.06, "2026-06-07 08:10:00"), false)
	_check("toisesta kiiskestä ei ilmoitusta", not main.hud._catch_label.text.begins_with("UUSI LAJI"))
	main.hud._catch_panel.visible = false
