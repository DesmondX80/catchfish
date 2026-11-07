extends Node
## Kalastustarvikeliikkeen taustakuvan testi (CATCHFISH-84):
## godot --headless -- --shopbgtest
## Tarkistaa kuvatiedoston (koko, ei alfaa, tiedostokoko, kirkkaus) ja sen, että
## kuva näkyy alkuvalikon uranäkymissä vain liikkeessä: koti → liike → osto ja
## maksu (kuva ei välähdä, vieritys säilyy) → Takaisin → myynti ja nukkuminen →
## liike → Esc alkuvalikkoon → kartta, asetukset ja kalakirja.

const PATH := "res://assets/shop/shop_interior.png"

var _log: Array[String] = []


func _ready() -> void:
	get_tree().root.size = Vector2i(1600, 900) # headless-ikkuna on muuten liian korkea vieritykseen
	await get_tree().process_frame
	_image_checks()
	await _view_checks()
	for l in _log:
		print(l)
	get_tree().quit(1 if _log.any(func(l): return l.begins_with("VIRHE")) else 0)


func _check(name: String, ok: bool) -> void:
	_log.append("%s %s" % ["OK  " if ok else "VIRHE", name])


func _image_checks() -> void:
	var bytes := FileAccess.get_file_as_bytes(PATH)
	_check("kuvatiedosto on olemassa (%d tavua)" % bytes.size(), bytes.size() > 0)
	_check("tiedosto enintään 1,6 Mt (%.2f Mt)" % (bytes.size() / 1e6), bytes.size() <= 1600000)
	var img := Image.new()
	_check("PNG latautuu", img.load_png_from_buffer(bytes) == OK)
	_check("koko 1920x1080 (%dx%d)" % [img.get_width(), img.get_height()], img.get_width() == 1920 and img.get_height() == 1080)
	_check("RGB ilman alfaa", img.get_format() == Image.FORMAT_RGB8)
	var tex: Texture2D = load(PATH)
	_check("tekstuuri latautuu Godotiin 1920x1080", tex != null and tex.get_width() == 1920 and tex.get_height() == 1080)
	if img.get_format() != Image.FORMAT_RGB8 or img.get_width() != 1920:
		return
	# Luminanssi (Rec. 709) koko kuvasta, vasemmasta 40 %:sta ja oikeasta 60 %:sta
	var data := img.get_data()
	var w := img.get_width()
	var h := img.get_height()
	var split := int(w * 0.4)
	var left := 0.0
	var right := 0.0
	var top := 0.0
	var bright := 0
	for y in h:
		var row := y * w * 3
		for x in w:
			var i := row + x * 3
			var l := (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) / 255.0
			if x < split:
				left += l
			else:
				right += l
			top = maxf(top, l)
			if l > 0.8:
				bright += 1
	var n := float(w * h)
	var mean := (left + right) / n
	left /= split * h
	right /= (w - split) * h
	_check("keskiluminanssi 0,18–0,32 (%.3f)" % mean, mean >= 0.18 and mean <= 0.32)
	_check("vasen 40 %% tummempi kuin oikea 60 %% (%.3f < %.3f)" % [left, right], left < right)
	_check("kirkkain kohta enintään 0,98 (%.3f)" % top, top <= 0.98)
	# Ei suurta kirkasta pintaa: vain lampun hehku ja pienet kohdat ovat yli 0,8
	_check("yli 0,8:n kirkkaita pikseleitä alle 1 %% (%.2f %%)" % (100.0 * bright / n), bright < 0.01 * n)


func _view_checks() -> void:
	var menu: StartMenu = get_parent().menu
	_check("alkuvalikko on auki", menu != null)
	if menu == null:
		return
	var bg := menu.shop_bg
	var career: CareerView = menu._career
	_check("taustakuva on liikkeen kuva", bg.texture != null and bg.texture.resource_path == PATH)
	_check("kuva peittää koko ruudun kuvasuhde säilyen", bg.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED
		and bg.expand_mode == TextureRect.EXPAND_IGNORE_SIZE and bg.anchor_right == 1.0 and bg.anchor_bottom == 1.0)
	_check("kuva ei ota hiirtä", bg.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("kuva piirtyy mökin päälle ja uran paneelin alle", bg.get_index() < career.get_index())
	_check("alkuvalikossa ei kuvaa", not bg.visible)

	menu.open_career()
	await get_tree().process_frame
	_check("kotinäkymässä ei kuvaa", career.visible and not bg.is_visible_in_tree())

	career.show_shop()
	await get_tree().process_frame
	_check("liikkeessä kuva näkyy", bg.is_visible_in_tree())

	# Osto ja maksu rakentavat näkymän uudelleen: kuva ei saa välähtää piiloon
	var toggles := [0]
	var count := func(): toggles[0] += 1
	bg.visibility_changed.connect(count)
	Career.money = 1000.0
	career.show_shop()
	for i in 5: # vierityslista asettuu
		await get_tree().process_frame
	career._shop_scroll.scroll_vertical = 120
	await get_tree().process_frame
	var scroll_before := career._shop_scroll.scroll_vertical
	career._buy(Lures.LIST[0])
	for i in 5:
		await get_tree().process_frame
	_check("osto ei hyppää vieritystä (%d → %d)" % [scroll_before, career._shop_scroll.scroll_vertical], scroll_before > 0 and career._shop_scroll.scroll_vertical == scroll_before)
	career._pay_fee(Career.FEES[0])
	await get_tree().process_frame
	_check("osto ja maksu eivät välähdä kuvaa (näkyvyys vaihtui %d kertaa)" % toggles[0], toggles[0] == 0 and bg.is_visible_in_tree())
	bg.visibility_changed.disconnect(count)

	career.show_home() # Takaisin
	await get_tree().process_frame
	_check("Takaisin kotiin poistaa kuvan", not bg.visible)
	# Myynti ja nukkuminen piilottavat kuvan myös suoraan liikkeestä tultaessa
	career.show_shop()
	career.show_market()
	await get_tree().process_frame
	_check("myynnissä ei kuvaa", not bg.visible)
	career.show_shop()
	career.show_sleep()
	await get_tree().process_frame
	_check("nukkumisessa ei kuvaa", not bg.visible)

	career.show_shop()
	await get_tree().process_frame
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	menu._unhandled_input(esc)
	await get_tree().process_frame
	_check("Esc liikkeestä vie alkuvalikkoon", menu._main.visible and not career.visible)
	_check("Esc poistaa kuvan", not bg.visible)

	# Kalareissulle lähtö liikkeen jälkeen: kartalla ei kuvaa
	menu.open_career()
	career.show_shop()
	menu.career_mode = true
	menu._show_map()
	await get_tree().process_frame
	_check("kartalla ei kuvaa", not bg.visible)
	menu._show_main()
	Settings.real_world = false # ei säähakua verkosta testissä
	menu._show_settings()
	await get_tree().process_frame
	_check("asetuksissa ei kuvaa", not bg.visible)
	menu._show_main()
	menu._show_book()
	await get_tree().process_frame
	_check("kalakirjassa ei kuvaa", not bg.visible)
