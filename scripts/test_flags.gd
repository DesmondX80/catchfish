class_name TestFlags
## Testilippujen taulukot: mikä käynnistyslippu lataa minkä tests/-skriptin.
## Uusi testi rekisteröidään yhdellä rivillä taulukkoon GAME (ja ajurin listaan
## tools/run_tests.sh). Main käyttää tätä valikon ohitukseen ja testin lataukseen.

const TEST_DIR := "res://tests/"
## Kokeiluskripti levyltä tai projektista: --scratchtest=POLKU
const SCRATCH_PREFIX := "--scratchtest="
## Ohittaa valikon ilman testiä
const SKIP_MENU := "--skipmenu"

## Paljaat apuliput (--<kirjaimia> ilman =-osaa ja väliviivaa), jotka eivät lataa
## testiä. Uusi tällainen lippu lisätään tähän, muuten se on tuntematon testilippu.
const HELPERS: Array[String] = [
	"--mouse",
	"--short",
]

## Valikkotestit (etuliite): valikko jää näkyviin ja testi ladataan sen päälle
const MENU := {
	"--menutest=": "menu_test",
	"--settingstest=": "settings_test",
	"--timepicktest=": "time_pick_test",
	"--careertest=": "career_test",
	"--tvtest=": "tv_test",
	"--shopbgtest": "shop_bg_test",
}

## Pelitestit (tarkka lippu): peli käynnistyy aloituspaikasta 0
const GAME := {
	"--autotest": "autotest",
	"--flicker": "flicker",
	"--icetest": "ice_test",
	"--pausetest": "pause_test",
	"--inputtest": "input_test",
	"--perftest": "perf",
	"--luretest": "lure_test",
	"--trolltest": "troll_test",
	"--speciestest": "species_test",
	"--tubtest": "tub_test",
	"--casttest": "cast_test",
	"--voicetest": "voice_test",
	"--audiologtest": "audio_log_test",
	"--wavesoundtest": "wave_sound_test",
	"--baittest": "bait_test",
	"--docktest": "dock_test",
	"--anglertest": "angler_test",
	"--piketest": "pike_follow_test",
	"--sonartest": "sonar_test",
	"--boattest": "boat_test",
	"--overlaptest": "overlap_test",
	"--synctest": "sync_test",
	"--motorspeedtest": "motor_speed_test",
	"--proptest": "prop_test",
	"--seasonfishtest": "season_fish_test",
	"--pressuretest": "pressure_test",
	"--anchortest": "anchor_test",
	"--headwindtest": "headwind_test",
	"--paddletest": "paddle_test",
	"--tackletest": "tackle_test",
	"--birdsoundtest": "bird_sound_test",
	"--birdtest": "bird_test",
	"--trollstriketest": "troll_strike_test",
	"--fpvtest": "fpv_test",
	"--booktest": "book_test",
	"--nettest": "net_test",
	"--releasetest": "release_test",
	"--wavetest": "wave_test",
	"--seamtest": "seam_test",
	"--linetest": "line_test",
	"--otherboatstest": "other_boats_test",
	"--channeltest": "channel_test",
	"--waketest": "wake_test",
	"--fightdepthtest": "fight_depth_test",
	"--seedtest": "seed_test",
}

## Kuvaskriptit (etuliite --x=): peli käynnistyy aloituspaikasta 0
const SHOTS := {
	"--seasonshot=": "season_shot",
	"--screenshots=": "screenshots",
	"--anglershots=": "angler_shots",
	"--boatshots=": "boat_shots",
	"--fpvshots=": "fpv_shots",
	"--watershots=": "water_shots",
	"--foamshots=": "foam_shots",
	"--shadowshots=": "shadow_shots",
	"--jittershots=": "jitter_shots",
	"--otherboatshots=": "other_boats_shots",
	"--lineshots=": "line_shots",
	"--seamshots=": "seam_shots",
	"--channelshots=": "channel_shots",
	"--wakeshots=": "wake_shots",
	"--audio-preview=": "audio_preview",
}


## Ladattavan pelitestin tai kuvaskriptin polku, tyhjä jos lippua ei ole.
## Ensimmäinen osuma voittaa järjestyksessä --scratchtest= -> GAME -> SHOTS.
static func find(args: PackedStringArray) -> String:
	for arg in args:
		if arg.begins_with(SCRATCH_PREFIX):
			return arg.substr(SCRATCH_PREFIX.length())
	for flag in GAME:
		if flag in args:
			return TEST_DIR + GAME[flag] + ".gd"
	for prefix in SHOTS:
		for arg in args:
			if arg.begins_with(prefix):
				return TEST_DIR + SHOTS[prefix] + ".gd"
	return ""


## Valikkotestin polku, tyhjä jos lippua ei ole
static func find_menu(args: PackedStringArray) -> String:
	for prefix in MENU:
		for arg in args:
			if arg.begins_with(prefix):
				return TEST_DIR + MENU[prefix] + ".gd"
	return ""


## Ohitetaanko aloitusvalikko: peli- tai kuvalippu, --scratchtest= tai --skipmenu.
## Apuliput (--day=, --seed=, --audio-log ym.) eivät yksin ohita valikkoa.
static func skips_menu(args: PackedStringArray) -> bool:
	return SKIP_MENU in args or find(args) != ""


## Virheilmoitus väärin kirjoitetusta testilipusta, tyhjä jos kaikki liput tunnetaan.
## Virhe on paljas --<kirjaimia>-argumentti (ei =-osaa, ei väliviivaa), joka ei ole
## GAME- tai MENU-lippu, --skipmenu eikä apulippu (HELPERS), tai --scratchtest=
## ilman polkua (jäisi muuten valikkoon aikarajaan asti).
static func unknown_test_flag(args: PackedStringArray) -> String:
	var pattern := RegEx.create_from_string("^--[a-z]+$")
	for arg in args:
		if arg == SCRATCH_PREFIX:
			return "VIRHE --scratchtest vaatii polun: --scratchtest=POLKU"
		if pattern.search(arg) == null or GAME.has(arg) or MENU.has(arg) or arg == SKIP_MENU or arg in HELPERS:
			continue
		var text := "VIRHE tuntematon testilippu %s" % arg
		if MENU.has(arg + "="):
			text += "\nVihje: %s vaatii kansion: %s=KANSIO" % [arg, arg]
		return text
	return ""


## Testisolmu skriptistä tai null, jos skripti ei lataudu (puuttuu, jäsennysvirhe).
## Virheestä tulostuu VIRHE-rivi; kutsuja lopettaa pelin koodilla 1.
static func instantiate(path: String) -> Node:
	if path != "" and (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var script := load(path) as GDScript
		if script != null and script.can_instantiate():
			var node := script.new() as Node
			if node != null:
				return node
	print("VIRHE testiskripti ei lataudu: %s" % path)
	return null
