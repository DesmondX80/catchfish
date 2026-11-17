#!/usr/bin/env bash
# Ajaa ikkunattomat (headless) testit, tulostaa lopuksi yhteenvetotaulukon ja
# kirjoittaa koko ajon lokiin.
# Käyttö: tools/run_tests.sh [GODOT] [LIPUT] [TESTIN_NIMI...] [-- TESTIN_LISÄLIPUT...]
#   GODOT           Godot-ohjelma (oletus: $GODOT, sitten godot-4.7.2, sitten godot)
#   TESTIN_NIMI     ajaa vain nimetyt testit, esim. luretest docktest
#   --repeat=N      aja jokainen valittu testi N kertaa (oletus 1); N >= 2 tulostaa
#                   lisäksi testeittäin rivit, jotka vaihtelivat ajosta toiseen
#   --ref=REF       aja testit REF:n (esim. origin/main) väliaikaisessa työkopiossa
#   --log=TIEDOSTO  lokin polku (oletus .test-logs/AAAAKKPP-HHMMSS.log)
#   --seed=N        välitä testeille --seed=N (kiinteä satunnaisuus; oletus: siemen
#                   arvotaan joka ajolla). Testin oma --seed (seedtest) pysyy.
#   -j N, --jobs=N  aja enintään N testiä rinnakkain (oletus 1, suositus 4);
#                   pisimmät ensin edellisten kestojen mukaan (.test-logs/kestot.tsv)
#   --no-retry      älä aja epäonnistunutta testiä uudelleen
#   --changed[=REF] aja vain testit, joihin muutetut tiedostot vaikuttavat
#                   (vertailukohta oletuksena git merge-base origin/main HEAD;
#                   muutoskartta tools/test_map.txt). Pikatarkistus, ei korvaa sarjaa.
#   --check         tarkista testilistat (scripts/test_flags.gd, tests/, ajurin
#                   lista, tools/test_map.txt); ei aja testejä, ei yhdisty muihin
#   --wait          odota, jos toinen ajo on käynnissä samassa työkopiossa
#   --scratch=POLKU aja kokeiluskripti (extends Node) testinä scratchtest
#                   (pelin lippu --scratchtest=POLKU)
#   -q, --quiet     ei Godotin tulostetta päätteeseen, vain tulosrivit ja taulukko
#   -- LISÄLIPUT    lisätään jokaisen valitun testin argumenttien loppuun
# Testi epäonnistuu, jos se palauttaa muun kuin 0 (testit lopettavat koodilla 1,
# kun lokissa on VIRHE-rivi) tai ei valmistu aikarajassa ($TEST_TIMEOUT, oletus 600 s).
# Epäonnistuneen ajon tulosrivi kertoo siemenen Godotin "Siemen: N" -riviltä, ja
# toistoajon taulukko näyttää komennon, joka toistaa ajon samalla siemenellä.
# Kun --repeat on 1, epäonnistunut testi (ei aikakatkaisu) ajetaan heti uudelleen
# samalla siemenellä: jos uusinta menee läpi, tulos on SATUNNAINEN.
# Jokainen Godot-ajo merkitään ympäristömuuttujalla CATCHFISH_AJO=<ajurin pid>-<paikka>,
# ja ajon jälkeen (myös keskeytyksessä) lopetetaan kaikki merkityt prosessit,
# myös testin itse käynnistämät alaprosessit (/proc/*/environ).
# Työkopiossa voi olla käynnissä yksi ajo kerrallaan (lukko .test-logs/run.lock).
# Ajon lopuksi kirjoitetaan valmismerkki .test-logs/latest.done (--log=X: X.done),
# ja lokin viereen tarkistusrivit ja ajot sarkaineroteltuina (X.rivit.tsv,
# X.ajot.tsv; linkit .test-logs/latest.rivit.tsv ja latest.ajot.tsv).
# Paluukoodi: 0 kaikki läpi, 1 jokin VIRHE, SATUNNAINEN tai AIKAKATKAISU,
# 2 väärä käyttö, 3 toinen ajo käynnissä tässä työkopiossa, 130 keskeytetty.
# Ikkunaa vaativat ja käsin ajettavat testit (not_listed alla) eivät ole mukana.
set -u

timeout_s="${TEST_TIMEOUT:-600}"
max_errs=5   # epäonnistuneen testin VIRHE-rivejä taulukossa
keep_logs=20 # säilytettävät lokit .test-logs/:ssa

# nimi|argumentit
tests=(
	"anchortest|--fixed-fps 30 -- --day=180 --anchortest"
	"anglertest|--fixed-fps 30 -- --day=180 --anglertest"
	"anglertest-talvi|--fixed-fps 30 -- --day=40 --anglertest"
	"audiologtest|--fixed-fps 30 -- --day=180 --audio-log --audiologtest"
	"baittest|--fixed-fps 30 -- --day=180 --baittest"
	"birdsoundtest|--fixed-fps 30 -- --day=180 --birdsoundtest"
	"birdtest|--fixed-fps 30 -- --day=180 --birdtest"
	"boattest|--fixed-fps 30 -- --day=180 --boattest"
	"booktest|-- --day=180 --booktest"
	"casttest|--fixed-fps 30 -- --day=180 --casttest"
	"channeltest|--fixed-fps 30 -- --day=180 --channeltest"
	"docktest|--fixed-fps 30 -- --day=180 --docktest"
	"fightdepthtest|--fixed-fps 30 -- --day=180 --fightdepthtest"
	"fpvtest|--fixed-fps 30 -- --day=180 --fpvtest"
	"headwindtest|--fixed-fps 30 -- --day=180 --headwindtest"
	"icetest|--fixed-fps 30 -- --day=40 --icetest"
	"luretest|--fixed-fps 30 -- --day=180 --luretest"
	"linetest|--fixed-fps 30 -- --day=180 --linetest"
	"linetest-talvi|--fixed-fps 30 -- --day=40 --linetest"
	"motorspeedtest|--fixed-fps 30 -- --day=180 --motorspeedtest"
	"nettest|--fixed-fps 30 -- --day=180 --nettest"
	"nettest-talvi|--fixed-fps 30 -- --day=40 --nettest"
	"otherboatstest|--fixed-fps 30 -- --day=180 --otherboatstest"
	"otherboatstest-talvi|--fixed-fps 30 -- --day=40 --otherboatstest"
	"overlaptest|--fixed-fps 30 -- --day=180 --overlaptest"
	"overlaptest-talvi|--fixed-fps 30 -- --day=40 --overlaptest"
	"paddletest|--fixed-fps 30 -- --day=180 --paddletest"
	"piketest|--fixed-fps 30 -- --day=180 --piketest"
	"pressuretest|-- --day=180 --pressuretest"
	"proptest|--fixed-fps 30 -- --day=180 --proptest"
	"releasetest|--fixed-fps 30 -- --day=180 --releasetest"
	"releasetest-talvi|--fixed-fps 30 -- --day=40 --releasetest"
	"seamtest|--fixed-fps 30 -- --day=180 --seamtest"
	"seasonfishtest|-- --day=180 --seasonfishtest"
	"seedtest|--fixed-fps 30 -- --day=180 --seed=171 --seedtest"
	"shopbgtest|-- --shopbgtest"
	"sonartest|--fixed-fps 30 -- --day=180 --sonartest"
	"speciestest|-- --speciestest"
	"synctest|--fixed-fps 30 -- --day=180 --synctest"
	"tackletest|--fixed-fps 30 -- --day=180 --tackletest"
	"tackletest-talvi|--fixed-fps 30 -- --day=40 --tackletest"
	"trolltest|--fixed-fps 30 -- --day=180 --trolltest"
	"trollstriketest|--fixed-fps 30 -- --day=180 --trollstriketest"
	"tubtest|--fixed-fps 30 -- --day=180 --tubtest"
	"tubtest-talvi|--fixed-fps 30 -- --day=40 --tubtest"
	"voicetest|--fixed-fps 30 -- --day=180 --voicetest"
	"waketest|--fixed-fps 30 -- --day=180 --waketest"
	"waketest-talvi|--fixed-fps 30 -- --day=40 --waketest"
	"wavesoundtest|--fixed-fps 30 -- --day=180 --wavesoundtest"
	"wavesoundtest-talvi|--fixed-fps 30 -- --day=40 --wavesoundtest"
	"wavetest|--fixed-fps 30 -- --day=180 --wavetest"
)

# Testitaulukon (scripts/test_flags.gd: GAME, MENU) liput, jotka eivät ole
# yllä olevassa listassa: ikkunaa vaativat ja käsin ajettavat. Nimi = lippu
# ilman alun --:ta ja lopun =:ää. --check vahtii, että jokainen lippu on
# jommassakummassa.
not_listed=(menutest settingstest timepicktest careertest tvtest autotest flicker pausetest inputtest perftest)

usage_line="Käyttö: tools/run_tests.sh [GODOT] [-q] [--repeat=N] [--ref=REF] [--log=TIEDOSTO] [--seed=N] [-j N] [--no-retry] [--changed[=REF]] [--wait] [--check] [--scratch=POLKU] [TESTIN_NIMI...] [-- TESTIN_LISÄLIPUT...]"
orig_args="$*"
orig_argv=("$@")
root="$(cd "$(dirname "$0")/.." && pwd)" || exit 2
lock_file="$root/.test-logs/run.lock"
lock_held=0
done_msg=""  # valmismerkin lisätiedot exit-koodin jälkeen
log=""
log_ready=0
run_dir=""
ref_dir=""

# Lokin polku luetaan ennen muita lippuja, koska valmismerkki on sen vieressä.
for arg in "$@"; do
	[ "$arg" = "--" ] && break
	case "$arg" in --log=*) log="${arg#--log=}" ;; esac
done
[ -n "$log" ] && log="$(realpath -m "$log")"
if [ -n "$log" ]; then
	done_file="$log.done"
else
	done_file="$root/.test-logs/latest.done"
fi
done_shown="${done_file#"$root"/}"

# Tulosrivi päätteeseen ja lokiin.
say() {
	printf '%s\n' "$*" | tee -a "$log"
}

# Godotin tuloste ja ::group::-rivit: -q-tilassa vain lokiin.
say_raw() {
	if [ $quiet -eq 1 ]; then
		printf '%s\n' "$*" >>"$log"
	else
		say "$*"
	fi
}

pad() { # pad TEKSTI LEVEYS
	printf "%-${2}s" "$1"
}

# take_lock TAPA: työkopion lukko .test-logs/run.lock (flock, fd 9).
#   ei     varattu lukko: ilmoitus ja koodi 3
#   odota  varattu lukko: odotetaan (--wait)
#   hiljaa varattu lukko: palauttaa 1 (väärän käytön valmismerkkiä varten)
# Lukon haltija poistaa valmismerkin heti ja kirjoittaa sen lopuksi (on_exit).
take_lock() {
	mkdir -p "$root/.test-logs" 2>/dev/null || return 1
	if ! command -v flock >/dev/null 2>&1; then
		[ "$1" != hiljaa ] && echo ">> Varoitus: flock puuttuu, ajetaan ilman lukkoa"
		lock_held=1
		rm -f "$done_file"
		return 0
	fi
	exec 9<>"$lock_file" || return 1
	if ! flock -n 9; then
		local holder
		holder="$(head -n 1 "$lock_file" 2>/dev/null)"
		case "$1" in
			hiljaa)
				exec 9>&-
				return 1
				;;
			odota)
				echo ">> Odotetaan: toinen ajo on käynnissä tässä työkopiossa ($holder)."
				flock 9 || return 1
				;;
			*)
				echo "run_tests.sh: toinen ajo on käynnissä tässä työkopiossa ($holder)." >&2
				echo "Odota: until [ -f $done_shown ]; do sleep 5; done   tai aja lipulla --wait" >&2
				exit 3
				;;
		esac
	fi
	lock_held=1
	printf 'pid=%s alkoi=%s komento="%s"\n' "$$" "$(date +%H:%M:%S)" "$orig_args" >"$lock_file"
	rm -f "$done_file"
}

usage_error() { # usage_error VIESTI [VIHJE]
	echo "run_tests.sh: $1" >&2
	[ -n "${2:-}" ] && echo "$2" >&2
	echo "$usage_line" >&2
	# Valmismerkki myös väärästä käytöstä, jos lukko on saatavilla.
	[ $lock_held -eq 1 ] || take_lock hiljaa || exit 2
	done_msg="virhe=\"${1//\"/\'}\""
	exit 2
}

cleanup() {
	[ -n "$run_dir" ] && rm -rf "$run_dir"
	[ -n "$ref_dir" ] || return
	git -C "$root" worktree remove --force "$ref_dir" >/dev/null 2>&1 || rm -rf "$ref_dir"
	git -C "$root" worktree prune >/dev/null 2>&1
	ref_dir=""
}

# Valmismerkki jokaisella poistumistiellä, jolla lukko on hallussa (atominen kirjoitus).
on_exit() {
	local rc=$?
	cleanup
	[ $lock_held -eq 1 ] || return
	printf 'exit=%s%s paattyi=%s\n' "$rc" "${done_msg:+ $done_msg}" "$(date +%H:%M:%S)" \
		>"$done_file.tmp.$$" 2>/dev/null && mv -f "$done_file.tmp.$$" "$done_file"
}

# Alaprosessien siivous ympäristömerkillä CATCHFISH_AJO (/proc/*/environ).
# Godot käynnistää omat alaprosessinsa omaan istuntoonsa, joten prosessiryhmän
# lopetus ei tavoita niitä; ympäristömuuttuja periytyy silti.
have_proc=0
[ -r /proc/self/environ ] && have_proc=1

proc_alive() { # proc_alive PID: elossa eikä zombi
	[ -e "/proc/$1" ] && ! grep -qs '^State:[[:space:]]*Z' "/proc/$1/status"
}

# kill_marked MERKKI [etuliite]: lopettaa prosessit, joiden CATCHFISH_AJO on
# MERKKI (tai alkaa sillä), TERM ja 2 s:n päästä KILL. Tulostaa niiden määrän.
kill_marked() {
	local pat="^CATCHFISH_AJO=$1" f p i alive pids=()
	if [ $have_proc -eq 0 ]; then
		echo 0
		return
	fi
	[ "${2:-}" = etuliite ] || pat+='$'
	for f in $(grep -lsz -- "$pat" /proc/[0-9]*/environ 2>/dev/null); do
		p="${f#/proc/}"
		p="${p%/environ}"
		[ "$p" = "$$" ] || [ "$p" = "$BASHPID" ] && continue
		pids+=("$p")
	done
	if [ ${#pids[@]} -eq 0 ]; then
		echo 0
		return
	fi
	kill -TERM "${pids[@]}" 2>/dev/null
	for ((i = 0; i < 20; i++)); do
		alive=()
		for p in "${pids[@]}"; do proc_alive "$p" && alive+=("$p"); done
		[ ${#alive[@]} -eq 0 ] && break
		sleep 0.1
	done
	[ ${#alive[@]} -gt 0 ] && kill -KILL "${alive[@]}" 2>/dev/null
	echo ${#pids[@]}
}

interrupting=0
declare -A run_pid=() run_start=() # käynnissä olevat ajot: paikka -> pid, alkuaika
s_retry=()
interrupted() {
	local tf p n k id
	interrupting=1
	echo
	# Käynnissä olevien ajojen prosessiryhmät (timeout on ryhmänsä johtaja).
	if [ -n "$run_dir" ]; then
		for tf in "$run_dir"/*.tpid; do
			[ -f "$tf" ] && read -r p <"$tf" && kill -TERM -- "-$p" 2>/dev/null
		done
	fi
	# Ajojen aliprosessit siivoavat oman merkkinsä ajon päätyttyä (timeout -k
	# pakkolopettaa viimeistään 10 s:n päästä); lopuksi kaikki ajurin merkit.
	wait 2>/dev/null
	n=$(kill_marked "$$-" etuliite)
	if [ -n "$run_dir" ]; then
		for k in "${!run_pid[@]}"; do
			id="$k"
			[ "${s_retry[k]:-0}" -eq 1 ] && id="${k}u"
			[ -f "$run_dir/$id.rc" ] && read -r _ p <"$run_dir/$id.rc" && n=$((n + p))
		done
	fi
	if [ $log_ready -eq 1 ]; then
		say ">> Keskeytetty."
		[ "$n" -gt 0 ] && say ">> Lopetettiin $n testin jälkeen jäänyttä prosessia."
	else
		echo ">> Keskeytetty."
		[ "$n" -gt 0 ] && echo ">> Lopetettiin $n testin jälkeen jäänyttä prosessia."
	fi
	done_msg="keskeytetty"
	exit 130
}
trap on_exit EXIT
trap interrupted INT TERM

# Testitaulukot scripts/test_flags.gd:stä: rivi "TAULUKKO<TAB>LIPPU<TAB>SKRIPTI".
read_flag_tables() { # read_flag_tables TIEDOSTO
	awk '
		/^const [A-Z_]+ := \{/ { tbl = $2; next }
		/^\}/ { tbl = ""; next }
		tbl != "" && /^\t"--[^"]*": "[^"]*",/ {
			split($0, p, "\"")
			print tbl "\t" p[2] "\t" p[4]
		}' "$1"
}

flag_name() { # flag_name LIPPU: --menutest= -> menutest
	local f="${1#--}"
	printf '%s' "${f%=}"
}

# args_have_flag ARGUMENTIT LIPPU: lippu erillisenä sanana (=-loppuinen etuliitteenä).
args_have_flag() {
	local w
	for w in $1; do
		if [[ "$2" == *= ]]; then
			[[ "$w" == "$2"* ]] && return 0
		else
			[ "$w" = "$2" ] && return 0
		fi
	done
	return 1
}

# Peli- ja valikkotestien liput (GAME, MENU) ja niiden skriptit.
load_flags() {
	t_flags=()
	declare -gA t_script=() t_table=()
	local tbl flag script
	while IFS=$'\t' read -r tbl flag script; do
		t_table[$flag]="$tbl"
		t_script[$flag]="$script"
		t_flags+=("$flag")
	done < <(read_flag_tables "$root/scripts/test_flags.gd")
}

# Ajurin listan rivit, joiden argumenteissa on LIPPU.
rows_for_flag() { # rows_for_flag LIPPU
	local entry rows=()
	for entry in "${tests[@]}"; do
		args_have_flag "${entry#*|}" "$1" && rows+=("${entry%%|*}")
	done
	printf '%s' "${rows[*]}"
}

check_errs=0
check_err() {
	echo "VIRHE $*"
	check_errs=$((check_errs + 1))
}

# --check: testitaulukko, tests/-kansio, ajurin lista ja muutoskartta yhtä pitäviksi.
run_check() {
	local flags_file="$root/scripts/test_flags.gd" map="$root/tools/test_map.txt"
	local f base flag entry name nm found before line path tlist t lineno=0
	local n_game=0 n_menu=0 n_shots=0 n_files=0 n_rows=0 n_map=0 in_nl
	local -A values=() listed=() map_seen=()
	if [ ! -f "$flags_file" ]; then
		check_err "scripts/test_flags.gd puuttuu"
		echo "Tarkistus: $check_errs virhettä"
		exit 1
	fi
	local all=() tbl script
	local -A all_script=() all_table=()
	while IFS=$'\t' read -r tbl flag script; do
		all+=("$flag")
		all_script[$flag]="$script"
		all_table[$flag]="$tbl"
		values[$script]=1
		case "$tbl" in
			GAME) n_game=$((n_game + 1)) ;;
			MENU) n_menu=$((n_menu + 1)) ;;
			SHOTS) n_shots=$((n_shots + 1)) ;;
		esac
	done < <(read_flag_tables "$flags_file")

	# C1 ja C2: tests/*.gd ja taulukon arvot
	before=$check_errs
	for f in "$root"/tests/*.gd; do
		[ -f "$f" ] || continue
		base="$(basename "$f" .gd)"
		[ "$base" = test_util ] && continue
		n_files=$((n_files + 1))
		[ -n "${values[$base]:-}" ] || check_err "tests/$base.gd ei ole testitaulukossa (scripts/test_flags.gd)"
	done
	for flag in "${all[@]}"; do
		[ -f "$root/tests/${all_script[$flag]}.gd" ] || check_err "$flag: skripti tests/${all_script[$flag]}.gd puuttuu"
	done
	[ $check_errs -eq $before ] && echo "OK   testitaulukko: ${#all[@]} lippua ($n_game peli, $n_menu valikko, $n_shots kuva), $n_files skriptiä tests/-kansiossa"

	# C3, C4 ja C5: ajurin lista ja not_listed
	before=$check_errs
	for entry in "${tests[@]}"; do
		name="${entry%%|*}"
		n_rows=$((n_rows + 1))
		found=()
		for flag in "${all[@]}"; do
			[ "${all_table[$flag]}" = SHOTS ] && continue
			args_have_flag "${entry#*|}" "$flag" && found+=("$flag")
		done
		if [ ${#found[@]} -eq 0 ]; then
			check_err "ajurin rivi $name: ei testilippua argumenteissa"
		elif [ ${#found[@]} -gt 1 ]; then
			check_err "ajurin rivi $name: useita testilippuja argumenteissa: ${found[*]}"
		else
			listed[${found[0]}]=1
		fi
	done
	for flag in "${all[@]}"; do
		[ "${all_table[$flag]}" = SHOTS ] && continue
		nm="$(flag_name "$flag")"
		in_nl=0
		[[ " ${not_listed[*]} " == *" $nm "* ]] && in_nl=1
		if [ -n "${listed[$flag]:-}" ] && [ $in_nl -eq 1 ]; then
			check_err "$flag on sekä ajurin listassa että not_listed-listassa (tools/run_tests.sh)"
		elif [ -z "${listed[$flag]:-}" ] && [ $in_nl -eq 0 ]; then
			check_err "$flag ei ole ajurin listassa eikä not_listed-listassa (tools/run_tests.sh)"
		fi
	done
	for nm in "${not_listed[@]}"; do
		found=()
		for flag in "${all[@]}"; do
			[ "${all_table[$flag]}" = SHOTS ] && continue
			[ "$(flag_name "$flag")" = "$nm" ] && found+=("$flag")
		done
		[ ${#found[@]} -gt 0 ] || check_err "not_listed: $nm ei ole testitaulukossa"
	done
	[ $check_errs -eq $before ] && echo "OK   ajurin lista: $n_rows riviä, ${#listed[@]} lippua; käsin ajettavat (not_listed): ${#not_listed[@]}"

	# C6: muutoskartta
	before=$check_errs
	if [ ! -f "$map" ]; then
		check_err "tools/test_map.txt puuttuu"
	else
		while IFS= read -r line || [ -n "$line" ]; do
			lineno=$((lineno + 1))
			[[ -z "${line//[[:space:]]/}" || "$line" == \#* ]] && continue
			if [[ "$line" != *$'\t'* ]]; then
				check_err "tools/test_map.txt:$lineno: rivillä ei ole sarkainta (polku<TAB>testit)"
				continue
			fi
			n_map=$((n_map + 1))
			path="${line%%$'\t'*}"
			tlist="${line#*$'\t'}"
			[ -e "$root/$path" ] || check_err "tools/test_map.txt:$lineno: $path ei ole olemassa"
			if [ -n "${map_seen[$path]:-}" ]; then
				check_err "tools/test_map.txt:$lineno: $path toistuu (myös rivillä ${map_seen[$path]})"
			else
				map_seen[$path]=$lineno
			fi
			[ -n "${tlist//[[:space:]]/}" ] || check_err "tools/test_map.txt:$lineno: $path: ei testejä"
			for t in $tlist; do
				is_test_name "$t" || check_err "tools/test_map.txt:$lineno: $t ei ole ajurin listassa"
			done
		done <"$map"
	fi
	[ $check_errs -eq $before ] && echo "OK   muutoskartta: $n_map riviä"

	if [ $check_errs -gt 0 ]; then
		echo "Tarkistus: $check_errs virhettä"
		exit 1
	fi
	echo "Tarkistus läpi."
	exit 0
}

is_test_name() {
	local entry
	for entry in "${tests[@]}"; do
		[ "${entry%%|*}" = "$1" ] && return 0
	done
	return 1
}

# Tuntematon testin nimi, joka näyttää Godotilta: vihje oikeasta paikasta.
godot_hint() { # godot_hint NIMI
	local a rest=() skipped=0
	if [[ "$1" == */* ]] || [[ "$1" == *godot* ]] || command -v "$1" >/dev/null 2>&1; then
		for a in "${orig_argv[@]}"; do
			if [ $skipped -eq 0 ] && [ "$a" = "$1" ]; then
				skipped=1
				continue
			fi
			rest+=("$a")
		done
		echo "Vihje: Godot annetaan ensimmäisenä argumenttina: tools/run_tests.sh $1${rest[*]:+ ${rest[*]}}"
	fi
}

# --check ei ota lukkoa, ei kirjoita .test-logs/:iin eikä tarvitse Godotia.
for arg in "$@"; do
	[ "$arg" = "--" ] && break
	if [ "$arg" = "--check" ]; then
		if [ $# -ne 1 ]; then
			echo "run_tests.sh: --check ei yhdisty muihin argumentteihin" >&2
			echo "$usage_line" >&2
			exit 2
		fi
		run_check
	fi
done

# Godot: ensimmäinen argumentti, jos se ei ole lippu eikä testin nimi ja on ohjelma.
godot=""
if [ $# -gt 0 ] && [[ "$1" != -* ]] && ! is_test_name "$1" \
		&& { [[ "$1" == */* ]] || command -v "$1" >/dev/null 2>&1; }; then
	godot="$1"
	shift
fi
if [ -z "$godot" ]; then
	if [ -n "${GODOT:-}" ]; then
		godot="$GODOT"
	elif command -v godot-4.7.2 >/dev/null 2>&1; then
		godot="godot-4.7.2"
	else
		godot="godot"
	fi
fi

repeat=1
ref=""
ref_given=0
quiet=0
seed=""
seed_given=0
wait_lock=0
scratch=""
scratch_given=0
jobs=1
no_retry=0
changed=0
changed_ref=""
selected=()
extra=()
while [ $# -gt 0 ]; do
	arg="$1"
	shift
	case "$arg" in
		--) extra=("$@"); break ;;
		--repeat=*) repeat="${arg#--repeat=}" ;;
		--ref=*) ref="${arg#--ref=}"; ref_given=1 ;;
		--log=*) ;; # luettu jo yllä
		--seed=*) seed="${arg#--seed=}"; seed_given=1 ;;
		--wait) wait_lock=1 ;;
		--scratch=*) scratch="${arg#--scratch=}"; scratch_given=1 ;;
		-q|--quiet) quiet=1 ;;
		-j)
			[ $# -gt 0 ] || usage_error "-j vaatii luvun, esim. -j 4"
			jobs="$1"
			shift
			;;
		-j*) jobs="${arg#-j}" ;;
		--jobs=*) jobs="${arg#--jobs=}" ;;
		--no-retry) no_retry=1 ;;
		--changed) changed=1 ;;
		--changed=*)
			changed=1
			changed_ref="${arg#--changed=}"
			[ -n "$changed_ref" ] || usage_error "--changed= vaatii refin, esim. --changed=origin/main"
			;;
		-*) usage_error "tuntematon lippu $arg" ;;
		*)
			is_test_name "$arg" || usage_error "tuntematon testi $arg" "$(godot_hint "$arg")"
			selected+=("$arg")
			;;
	esac
done
[[ "$repeat" =~ ^[1-9][0-9]*$ ]] || usage_error "--repeat vaatii positiivisen kokonaisluvun"
[[ "$jobs" =~ ^[1-9][0-9]*$ ]] || usage_error "-j vaatii positiivisen kokonaisluvun"
[ $seed_given -eq 1 ] && ! [[ "$seed" =~ ^[0-9]+$ ]] && usage_error "--seed vaatii ei-negatiivisen kokonaisluvun"
[ $ref_given -eq 1 ] && [ -z "$ref" ] && usage_error "--ref vaatii refin, esim. --ref=origin/main"
[ $scratch_given -eq 1 ] && [ -z "$scratch" ] && usage_error "--scratch vaatii polun, esim. --scratch=koe.gd"
if [ $changed -eq 1 ]; then
	[ ${#selected[@]} -eq 0 ] || usage_error "--changed ei yhdisty testin nimiin: ${selected[*]}"
	[ $scratch_given -eq 0 ] || usage_error "--changed ei yhdisty --scratch-lippuun"
	[ $ref_given -eq 0 ] || usage_error "--changed ei yhdisty --ref-lippuun"
fi

# Kokeiluskripti testiksi scratchtest; polku absoluuttiseksi.
scratch_path=""
if [ -n "$scratch" ]; then
	scratch_path="$(realpath -m "$scratch")"
	[[ "$scratch_path" == *[[:space:]]* ]] && usage_error "--scratch-polussa ei voi olla välilyöntejä: $scratch_path"
	tests+=("scratchtest|--fixed-fps 30 -- --day=180 --scratchtest=$scratch_path")
	selected+=("scratchtest")
fi

# Läpivienti: -- jälkeiset liput jokaisen valitun testin argumenttien loppuun.
extra_str="${extra[*]}"
extra_note=""
if [ -n "$extra_str" ]; then
	[ ${#selected[@]} -gt 0 ] || [ $changed -eq 1 ] || usage_error "-- LISÄLIPUT vaatii testin nimen, --scratch- tai --changed-lipun"
	extra_note=" (lisäliput: $extra_str)"
fi

# Polut absoluuttisiksi ennen hakemiston vaihtoa.
godot_path="$(command -v "$godot" 2>/dev/null)" || usage_error "Godotia ei löydy: $godot"
[[ "$godot_path" == */* ]] && godot_path="$(realpath "$godot_path")"

cd "$root" || exit 2

if [ $wait_lock -eq 1 ]; then
	take_lock odota || usage_error "lukkoa ei voi ottaa: $lock_file"
else
	take_lock ei || usage_error "lukkoa ei voi ottaa: $lock_file"
fi

ref_hash=""
ref_slug=""
if [ -n "$ref" ]; then
	ref_hash="$(git rev-parse --short --verify --quiet "$ref^{commit}")" \
		|| usage_error "ref ei ratkea: $ref"
	ref_slug="-$(printf '%s' "$ref" | tr -c 'A-Za-z0-9._' '-')"
fi

# --changed: muutetut tiedostot muutoskartan läpi; ensimmäinen osuva sääntö ratkaisee.
# Viestit kerätään ja tulostetaan, kun loki on valmis.
changed_msgs=()
changed_none=0
if [ $changed -eq 1 ]; then
	if [ -n "$changed_ref" ]; then
		base_label="$changed_ref"
		base="$(git rev-parse --verify --quiet "$changed_ref^{commit}" 2>/dev/null)" \
			|| usage_error "--changed: vertailukohta ei ratkea: $changed_ref"
	else
		base_label="origin/main"
		base="$(git merge-base origin/main HEAD 2>/dev/null)" \
			|| usage_error "--changed: vertailukohta ei ratkea: origin/main"
	fi
	mapfile -t changed_files < <({
		git diff --name-only --no-renames "$base" 2>/dev/null
		git ls-files --others --exclude-standard 2>/dev/null
	} | sort -u)
	load_flags
	declare -A script_flag=() map_tests=() run_set=()
	for flag in "${t_flags[@]}"; do script_flag[${t_script[$flag]}]="$flag"; done
	if [ -f tools/test_map.txt ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			[[ -z "${line//[[:space:]]/}" || "$line" == \#* || "$line" != *$'\t'* ]] && continue
			map_tests[${line%%$'\t'*}]="${line#*$'\t'}"
		done <tools/test_map.txt
	fi
	run_all=0
	hint_selftest=0
	hint_check=0
	changed_msgs+=(">> Muutokset verrattuna: $base_label ($(git rev-parse --short "$base")), ${#changed_files[@]} tiedostoa")
	for path in "${changed_files[@]}"; do
		p="$path"
		[[ "$p" == *.gd.uid ]] && p="${p%.uid}"
		rows=""
		case "$p" in
			docs/*|*.md|.claude/*|.github/*|tools/*.py|export_presets.cfg|.gitignore|export/*)
				result="ei testejä" ;;
			tools/run_tests.sh|tools/run_tests_selftest.sh)
				result="ei pelitestejä"; hint_selftest=1 ;;
			tools/test_map.txt)
				result="ei pelitestejä"; hint_check=1 ;;
			tests/test_util.gd)
				result="kaikki testit"; run_all=1 ;;
			tests/*.gd)
				base_name="${p#tests/}"
				base_name="${base_name%.gd}"
				flag="${script_flag[$base_name]:-}"
				[ -n "$flag" ] && rows="$(rows_for_flag "$flag")"
				if [ -n "$rows" ]; then
					result="$rows"
				else
					result="ei ajurin listassa (aja käsin)"
				fi
				;;
			*)
				if [ -n "${map_tests[$p]:-}" ]; then
					# Kartan testi -> sen lipun kaikki listarivit (myös -talvi)
					for t in ${map_tests[$p]}; do
						for entry in "${tests[@]}"; do
							[ "${entry%%|*}" = "$t" ] || continue
							for flag in "${t_flags[@]}"; do
								[ "${t_table[$flag]}" = SHOTS ] && continue
								args_have_flag "${entry#*|}" "$flag" && rows+=" $(rows_for_flag "$flag")"
							done
						done
						[[ " $rows " == *" $t "* ]] || rows+=" $t"
					done
					# Listan järjestykseen ja kertaalleen
					sorted=()
					for entry in "${tests[@]}"; do
						[[ " $rows " == *" ${entry%%|*} "* ]] && sorted+=("${entry%%|*}")
					done
					rows="${sorted[*]}"
					result="$rows"
				else
					result="kaikki testit"
					run_all=1
				fi
				;;
		esac
		for t in $rows; do run_set[$t]=1; done
		changed_msgs+=(">>   $path -> $result")
	done
	[ $hint_selftest -eq 1 ] && changed_msgs+=(">> Aja myös: tools/run_tests_selftest.sh")
	[ $hint_check -eq 1 ] && changed_msgs+=(">> Aja myös: tools/run_tests.sh --check")
	for entry in "${tests[@]}"; do
		name="${entry%%|*}"
		{ [ $run_all -eq 1 ] || [ -n "${run_set[$name]:-}" ]; } && selected+=("$name")
	done
	if [ ${#selected[@]} -eq 0 ]; then
		changed_none=1
		changed_msgs+=(">> Ei ajettavia testejä.")
	else
		changed_msgs+=(">> Ajetaan ${#selected[@]} testiä.")
	fi
fi

# Loki: oletuksena .test-logs/, josta säilytetään $keep_logs viimeisintä (ja
# niiden .tsv-tiedostot). Saman sekunnin lokit saavat päätteen -2, -3, …
default_log=0
if [ -z "$log" ]; then
	default_log=1
	mkdir -p .test-logs
	ls -1 .test-logs/ | grep -E '^[0-9]{8}-[0-9]{6}.*\.log$' | sort \
		| head -n -$((keep_logs - 1)) | while read -r old; do
			rm -f ".test-logs/$old" ".test-logs/$old.rivit.tsv" ".test-logs/$old.ajot.tsv" ".test-logs/$old.done"
		done
	log_base="$root/.test-logs/$(date +%Y%m%d-%H%M%S)$ref_slug"
	log="$log_base.log"
	n=1
	# noclobber: luonti epäonnistuu, jos nimi on jo olemassa
	until (set -o noclobber; : >"$log") 2>/dev/null; do
		n=$((n + 1))
		[ $n -gt 99 ] && usage_error "lokia ei voi luoda: $log"
		log="$log_base-$n.log"
	done
	ln -sfn "$(basename "$log")" .test-logs/latest.log
else
	mkdir -p "$(dirname "$log")"
	: >"$log" || usage_error "lokia ei voi kirjoittaa: $log"
fi
log_ready=1
log_shown="${log#"$root"/}"

quick_note=">> Pikatarkistus: koko sarja ajetaan ennen julkaisua."
for m in "${changed_msgs[@]}"; do say "$m"; done
if [ $changed_none -eq 1 ]; then
	say "$quick_note"
	done_msg="lapi=0/0 kesto=0 loki=$log_shown"
	exit 0
fi
[ $have_proc -eq 1 ] || say ">> Varoitus: /proc puuttuu, testien alaprosesseja ei siivota"

workdir="$root"
# Jokaisen ajon tuloste omaan tiedostoonsa: $run_dir/ID.out (ID = ajon paikka,
# uusinnalla pääte u), paluukoodi ja siivottujen määrä $run_dir/ID.rc.
run_dir="$(mktemp -d)"

# godot_marked MERKKI ID ARGUMENTIT...: ajaa Godotin aikarajalla ja lopettaa
# sen jälkeen kaikki prosessit, joilla on ajon merkki. Ajetaan taustalla omassa
# aliprosessissaan, jonka tuloste on ajon tuloste: siivous tehdään ennen kuin
# tuloste suljetaan, jotta tee ei jää odottamaan orvon alaprosessin putkea.
# timeout ilman --foregroundia muodostaa oman prosessiryhmänsä ja lopettaa sen
# kokonaan; -k 10 pakkolopettaa, jos Godot ei kuole TERMiin.
godot_marked() {
	local mark="$1" id="$2" code n
	shift 2
	cd "$workdir" || exit 2
	CATCHFISH_AJO="$mark" timeout -k 10 "$timeout_s" "$godot_path" "$@" </dev/null &
	echo $! >"$run_dir/$id.tpid"
	wait $!
	code=$?
	n=$(kill_marked "$mark")
	rm -f "$run_dir/$id.tpid"
	echo "$code $n" >"$run_dir/$id.rc"
}

# spawn MERKKI ID ULOS NÄYTÄ ARGUMENTIT...: Godot taustalle (pid: $!), jotta
# keskeytyksen trap laukeaa heti. NÄYTÄ=1: tuloste myös päätteeseen rivi kerrallaan.
# 9>&-: lukko ei periydy Godotille, joten se vapautuu ajurin kuollessa (kill -9).
spawn() {
	local mark="$1" id="$2" out="$3" show="$4"
	shift 4
	if [ "$show" -eq 1 ]; then
		{ godot_marked "$mark" "$id" "$@" 2>&1 | tee "$out"; } 9>&- &
	else
		godot_marked "$mark" "$id" "$@" 9>&- >"$out" 2>&1 &
	fi
}

ref_entries=""
ref_has_scratch=0
if [ -n "$ref" ]; then
	[[ "$ref" == origin/* ]] && say ">> Vihje: aja ensin git fetch, jos $ref ei ole ajan tasalla."
	ref_dir="$(mktemp -d "${TMPDIR:-/tmp}/run-tests${ref_slug}-XXXX")"
	say ">> Ajetaan $ref @ $ref_hash väliaikaisessa työkopiossa $ref_dir"
	git worktree add --detach "$ref_dir" "$ref" >>"$log" 2>&1 \
		|| { say ">> Työkopiota ei voitu luoda."; exit 2; }
	workdir="$ref_dir"
	ref_entries="$(git show "$ref:tools/run_tests.sh" 2>/dev/null)"
	git cat-file -e "$ref:scripts/test_flags.gd" 2>/dev/null && ref_has_scratch=1
	say ">> Tuodaan projekti (--headless --import)"
	spawn "$$-tuonti" tuonti "$run_dir/tuonti.out" 0 --headless --import
	wait $!
	cat "$run_dir/tuonti.out" >>"$log"
fi

# Rinnakkaisajo: enintään ytimien määrä, ja tuonnin pitää olla tehty.
if [ "$jobs" -gt 1 ]; then
	cores="$(nproc 2>/dev/null || echo 1)"
	if [ "$jobs" -gt "$cores" ]; then
		say ">> Varoitus: -j $jobs on enemmän kuin ytimiä ($cores), käytetään -j $cores."
		jobs="$cores"
	fi
	[ -d "$workdir/.godot" ] || usage_error ".godot/ puuttuu: aja ensin godot --headless --import"
fi
[ "$jobs" -gt 1 ] && say ">> Rinnakkain $jobs ajoa."

# Tarkistusrivit (OK/VIRHE) ajojen tulostetiedostoista. POSIX-awk (myös mawk):
# ei gensubia eikä matchin taulukkomuotoa.
# Syöte: rivi ajoa kohden "testi<TAB>ajo<TAB>tulostetiedosto<TAB>uusinta(0/1)".
#   mode=tsv       rivi tarkistusriviä kohden: testi, ajo, tila, rivi, luvut, uusinta
#   mode=vaihtelu  testeittäin rivit, jotka eivät toistuneet samoina joka ajossa
#                  (uusinnat eivät ole mukana)
read -r -d '' check_awk <<'AWK'
BEGIN { FS = "\t" }

# Pilkkoo tekstin luvuiksi num[1..n] ja niiden väleiksi lit[0..n]; palauttaa n.
# Miinus kuuluu lukuun, kun sitä edeltää rivin alku, väli, ( tai /.
function split_nums(s,    rest, n, pre, c, neg) {
	n = 0
	rest = s
	while (match(rest, /[0-9]+([.,][0-9]+)?/)) {
		pre = substr(rest, 1, RSTART - 1)
		neg = ""
		if (substr(pre, length(pre), 1) == "-") {
			if (length(pre) >= 2) c = substr(pre, length(pre) - 1, 1)
			else if (n == 0) c = " "
			else c = "x"
			if (c == " " || c == "(" || c == "/") {
				neg = "-"
				pre = substr(pre, 1, length(pre) - 1)
			}
		}
		lit[n] = pre
		n++
		num[n] = neg substr(rest, RSTART, RLENGTH)
		rest = substr(rest, RSTART + RLENGTH)
	}
	lit[n] = rest
	return n
}

function val(s) {
	gsub(/,/, ".", s)
	return s + 0
}

{
	test = $1
	run = $2 + 0
	file = $3
	uus = $4 + 0
	if (mode == "vaihtelu" && uus) next
	if (!(test in seen)) {
		seen[test] = 1
		tests[++ntests] = test
		nruns[test] = 0
	}
	if (run > nruns[test]) nruns[test] = run
	while ((getline line < file) > 0) {
		if (line !~ /^[ \t]*(OK|VIRHE)/) continue
		gsub(/\t/, " ", line)
		sub(/^ */, "", line)
		if (substr(line, 1, 2) == "OK") {
			st = "OK"
			text = substr(line, 3)
		} else {
			st = "VIRHE"
			text = substr(line, 6)
		}
		sub(/^ */, "", text)
		n = split_nums(text)
		if (mode == "tsv") {
			nums = ""
			for (j = 1; j <= n; j++) nums = nums (j > 1 ? " " : "") num[j]
			print test "\t" run "\t" st "\t" text "\t" nums "\t" uus
			continue
		}
		# Malli: luvut merkillä #, tila pois
		tpl = lit[0]
		for (j = 1; j <= n; j++) tpl = tpl "#" lit[j]
		k = test SUBSEP tpl
		if (!(k in tidx)) {
			tidx[k] = ++ntpl[test]
			tname[test, ntpl[test]] = tpl
			tn[k] = n
			for (j = 0; j <= n; j++) tlit[k, j] = lit[j]
		}
		if (!((k, run) in truns)) {
			truns[k, run] = 1
			nrun_t[k]++
		}
		tstat[k, st]++
		for (j = 1; j <= n; j++) {
			v = val(num[j])
			if (!((k, j) in mn) || v < mnv[k, j]) { mn[k, j] = num[j]; mnv[k, j] = v }
			if (!((k, j) in mx) || v > mxv[k, j]) { mx[k, j] = num[j]; mxv[k, j] = v }
		}
		# Täsmälleen sama rivi (tila ja teksti): esiintymät ajoittain
		e = k SUBSEP st " " text
		if (!(e in eidx)) {
			eidx[e] = ++nex[k]
			exl[k, nex[k]] = e
		}
		ecount[e, run]++
	}
	close(file)
}

END {
	if (mode != "vaihtelu") exit
	for (t = 1; t <= ntests; t++) {
		test = tests[t]
		N = nruns[test]
		nvar = 0
		for (i = 1; i <= ntpl[test]; i++) {
			k = test SUBSEP tname[test, i]
			# Vakaa: jokainen sama rivi yhtä monta kertaa jokaisessa ajossa
			stable = 1
			for (x = 1; x <= nex[k] && stable; x++) {
				e = exl[k, x]
				c1 = ecount[e, 1] + 0
				for (r = 2; r <= N; r++) {
					if (ecount[e, r] + 0 != c1) {
						stable = 0
						break
					}
				}
			}
			if (stable) continue
			nvar++
			if (nvar == 1) {
				print "Vaihtelevat rivit: " test " (" N " ajoa)"
				print "  AJOJA  TULOS            RIVI (luvut pienin…suurin)"
			}
			if (nvar > 20) continue
			res = ""
			if (tstat[k, "OK"] > 0) res = "OK " tstat[k, "OK"]
			if (tstat[k, "VIRHE"] > 0) res = res (res != "" ? ", " : "") "VIRHE " tstat[k, "VIRHE"]
			txt = tlit[k, 0]
			for (j = 1; j <= tn[k]; j++) {
				if (mnv[k, j] == mxv[k, j]) txt = txt mn[k, j]
				else txt = txt mn[k, j] "…" mx[k, j]
				txt = txt tlit[k, j]
			}
			printf "%6s   %-17s%s\n", nrun_t[k] "/" N, res, txt
		}
		if (nvar > 20) printf "    (+%d muuta)\n", nvar - 20
		if (nvar == 0) print "Vaihtelevia rivejä ei ole: " test " (" N " ajoa tuottivat samat OK/VIRHE-rivit)."
	}
}
AWK

# Ajot (testi × toisto) paikkoihin 1..nslots listan järjestyksessä. Tulokset
# tallennetaan paikan mukaan, ei valmistumisjärjestyksessä, joten taulukko ja
# TSV:t ovat aina listan järjestyksessä myös rinnakkaisajossa.
#   s_*  ajon tiedot, r_*  ensimmäisen ajon tulos, u_*  uusinnan tulos
s_args=()
s_label=()
r_name=()
r_status=()
r_code=()
r_secs=()
r_errs=()
r_seed=()
r_out=()
u_status=()
u_code=()
u_secs=()
u_seed=()
u_out=()
nslots=0
for entry in "${tests[@]}"; do
	name="${entry%%|*}"
	args="${entry#*|}"
	# Siemen testin argumenttien loppuun (kaikissa on --), ellei testillä ole omaa
	[ -n "$seed" ] && [[ " $args " != *" --seed="* ]] && args+=" --seed=$seed"
	if [ ${#selected[@]} -gt 0 ] && [[ ! " ${selected[*]} " == *" $name "* ]]; then
		continue
	fi
	missing_note=""
	if [ -n "$ref" ]; then
		if [ "$name" = scratchtest ]; then
			[ $ref_has_scratch -eq 1 ] || missing_note="ei --scratchtest-lippua $ref:ssa"
		elif [[ "$ref_entries" != *"\"$name|"* ]]; then
			missing_note="ei $ref:n testilistassa"
		fi
	fi
	if [ -n "$missing_note" ]; then
		nslots=$((nslots + 1))
		r_name[nslots]="$name"; r_status[nslots]="PUUTTUU"; r_code[nslots]=""; r_secs[nslots]=0
		r_errs[nslots]=""; r_seed[nslots]=""; r_out[nslots]=""; s_label[nslots]="$missing_note"
		continue
	fi
	for ((i = 1; i <= repeat; i++)); do
		nslots=$((nslots + 1))
		label="$name"
		[ "$repeat" -gt 1 ] && label="$name [$i/$repeat]"
		r_name[nslots]="$name"
		s_args[nslots]="$args"
		s_label[nslots]="$label"
	done
done

# Jono: listan järjestys, rinnakkain pisimmät ensin (.test-logs/kestot.tsv);
# testit, joilla ei ole kestoa, ensimmäisinä.
durations_file="$root/.test-logs/kestot.tsv"
queue=()
if [ "$jobs" -gt 1 ]; then
	declare -A dur=()
	if [ -f "$durations_file" ]; then
		while IFS=$'\t' read -r dn ds; do
			[[ "$ds" =~ ^[0-9]+$ ]] && dur[$dn]="$ds"
		done <"$durations_file"
	fi
	mapfile -t queue < <(for ((k = 1; k <= nslots; k++)); do
		printf '%s\t%s\n' "${dur[${r_name[k]}]:-999999}" "$k"
	done | sort -t $'\t' -k1,1nr -k2,2n | cut -f2)
else
	for ((k = 1; k <= nslots; k++)); do queue+=("$k"); done
fi

# Läpi menneen ajon kesto talteen seuraavan rinnakkaisajon järjestystä varten.
save_duration() { # save_duration NIMI SEKUNNIT
	[ "$1" = scratchtest ] && return
	{
		[ -f "$durations_file" ] && awk -F'\t' -v n="$1" '$1 != n' "$durations_file"
		printf '%s\t%s\n' "$1" "$2"
	} >"$durations_file.tmp.$$" 2>/dev/null && mv -f "$durations_file.tmp.$$" "$durations_file"
}

# Ajon VIRHE-rivit taulukkoon (enintään $max_errs).
error_lines() { # error_lines TULOSTETIEDOSTO
	local n_errs e
	n_errs=$(grep -c '^[[:space:]]*VIRHE' "$1")
	e="$(grep '^[[:space:]]*VIRHE' "$1" | head -n $max_errs | sed 's/^[[:space:]]*/    /')"
	[ "$n_errs" -gt $max_errs ] && e+=$'\n'"    (+$((n_errs - max_errs)) muuta)"
	printf '%s' "$e"
}

running=0

# start_slot PAIKKA: käynnistää ajon (tai uusinnan); palauttaa 1, jos mitään ei käynnistetty.
start_slot() {
	local k="$1" id="$1" label="${s_label[$1]}" args="${s_args[$1]}" show=0
	if [ "${r_status[k]:-}" = "PUUTTUU" ]; then
		say ">> $(pad PUUTTUU 13) ${r_name[k]} (${s_label[k]})"
		return 1
	fi
	if [ "${s_retry[k]:-0}" -eq 1 ]; then
		id="${k}u"
		label="$label [uusinta]"
		# Uusinta ensimmäisen ajon siemenellä, ellei argumenteissa ole omaa
		[ -n "${r_seed[k]}" ] && [[ " $args $extra_str " != *" --seed="* ]] && args+=" --seed=${r_seed[k]}"
	fi
	[ -n "$extra_str" ] && args+=" $extra_str"
	[ "$jobs" -eq 1 ] && say_raw "::group::$label"
	[ "$jobs" -eq 1 ] && [ $quiet -eq 0 ] && show=1
	run_start[$k]=$(date +%s)
	# shellcheck disable=SC2086
	spawn "$$-$k" "$id" "$run_dir/$id.out" "$show" --headless $args
	run_pid[$k]=$!
	return 0
}

# finish_slot PAIKKA: valmistuneen ajon tulos, tulosrivi ja tarvittaessa uusinta jonoon.
finish_slot() {
	local k="$1" id="$1" label="${s_label[$1]}" retry="${s_retry[$1]:-0}" code orphans secs out status
	local run_seed seed_note timed_out=0
	[ "$retry" -eq 1 ] && id="${k}u"
	wait "${run_pid[$k]}" 2>/dev/null
	unset "run_pid[$k]"
	secs=$(( $(date +%s) - run_start[$k] ))
	code=1
	orphans=0
	[ -f "$run_dir/$id.rc" ] && read -r code orphans <"$run_dir/$id.rc"
	out="$run_dir/$id.out"
	if [ "$jobs" -gt 1 ]; then
		# Rinnakkain: ajon tuloste kokonaisena lohkona valmistumisjärjestyksessä
		if [ "$retry" -eq 1 ]; then say_raw "::group::$label [uusinta]"; else say_raw "::group::$label"; fi
		[ $quiet -eq 0 ] && cat "$out"
	fi
	cat "$out" >>"$log"
	say_raw "::endgroup::"
	# Aikakatkaisu: 124, tai 137, kun -k pakkolopetti Godotin aikarajan jälkeen
	{ [ "$code" -eq 124 ] || { [ "$code" -eq 137 ] && [ "$secs" -ge "$timeout_s" ]; }; } && timed_out=1
	# Pelin tulostama siemen, jolla ajo toistuu (--seed=N)
	run_seed="$(sed -n 's/^Siemen: \([0-9][0-9]*\).*/\1/p' "$out" | head -n 1)"
	seed_note=""
	[ -n "$run_seed" ] && seed_note="siemen $run_seed"
	if [ "$retry" -eq 1 ]; then
		if [ "$code" -eq 0 ]; then
			status="OK"
			r_status[k]="SATUNNAINEN"
			say ">> $(pad "UUSINTA OK" 13) $label  $secs s${seed_note:+ ($seed_note)}$extra_note -> SATUNNAINEN"
		elif [ $timed_out -eq 1 ]; then
			status="AIKAKATKAISU"
			say ">> $(pad "UUSINTA AIKAKATKAISU" 13) $label  $secs s${seed_note:+ ($seed_note)}$extra_note -> VIRHE"
		else
			status="VIRHE"
			say ">> $(pad "UUSINTA VIRHE" 13) $label  $secs s (koodi $code${seed_note:+, $seed_note})$extra_note -> VIRHE"
		fi
		u_status[k]="$status"; u_code[k]="$code"; u_secs[k]="$secs"; u_seed[k]="$run_seed"; u_out[k]="$out"
		s_retry[k]=2
	else
		if [ "$code" -eq 0 ]; then
			status="OK"
			say ">> $(pad OK 13) $label  $secs s$extra_note"
		elif [ $timed_out -eq 1 ]; then
			status="AIKAKATKAISU"
			say ">> $(pad AIKAKATKAISU 13) $label  $secs s${seed_note:+ ($seed_note)}$extra_note"
		else
			status="VIRHE ($code)"
			say ">> $(pad VIRHE 13) $label  $secs s (koodi $code${seed_note:+, $seed_note})$extra_note"
		fi
		r_status[k]="$status"; r_code[k]="$code"; r_secs[k]="$secs"; r_seed[k]="$run_seed"; r_out[k]="$out"
		r_errs[k]=""
		[ "$status" != "OK" ] && r_errs[k]="$(error_lines "$out")"
	fi
	[ "$orphans" -gt 0 ] && say ">> Lopetettiin $orphans testin jälkeen jäänyttä prosessia."
	[ "$code" -eq 0 ] && save_duration "${r_name[k]}" "$secs"
	# Uusinta: vain kun --repeat on 1, ei --no-retry, ei aikakatkaisua eikä keskeytystä.
	# Menee jonon kärkeen ja käyttää samaa paikkaa.
	if [ "$retry" -eq 0 ] && [ "$code" -ne 0 ] && [ $timed_out -eq 0 ] && [ "$repeat" -eq 1 ] \
			&& [ $no_retry -eq 0 ] && [ $interrupting -eq 0 ]; then
		s_retry[k]=1
		queue=("$k" "${queue[@]}")
	fi
}

total_start=$(date +%s)
while [ ${#queue[@]} -gt 0 ] || [ $running -gt 0 ]; do
	while [ $running -lt "$jobs" ] && [ ${#queue[@]} -gt 0 ]; do
		k="${queue[0]}"
		queue=("${queue[@]:1}")
		start_slot "$k" && running=$((running + 1))
	done
	[ $running -eq 0 ] && continue
	if [ "$jobs" -eq 1 ]; then
		for k in "${!run_pid[@]}"; do wait "${run_pid[$k]}" 2>/dev/null; done
	else
		# Ennen odotusta: jo valmistuneet (rc-tiedosto kirjoitetaan juuri ennen loppua)
		ready=0
		for k in "${!run_pid[@]}"; do
			id="$k"
			[ "${s_retry[k]:-0}" -eq 1 ] && id="${k}u"
			[ -f "$run_dir/$id.rc" ] && ready=1
		done
		[ $ready -eq 0 ] && wait -n 2>/dev/null
	fi
	for k in "${!run_pid[@]}"; do
		id="$k"
		[ "${s_retry[k]:-0}" -eq 1 ] && id="${k}u"
		if [ -f "$run_dir/$id.rc" ] || ! kill -0 "${run_pid[$k]}" 2>/dev/null; then
			finish_slot "$k"
			running=$((running - 1))
		fi
	done
done
total_secs=$(( $(date +%s) - total_start ))

# Koneluettavat yhteenvedot lokin viereen: X.ajot.tsv (rivi ajoa kohden) ja
# X.rivit.tsv (rivi tarkistusriviä kohden). Ajolista vaihteluyhteenvedolle.
# Uusinta saa omat rivinsä (sarake uusinta = 1, ajo sama kuin ensimmäisellä).
runs_list="$run_dir/ajot.list"
: >"$runs_list"
printf 'testi\tajo\ttulos\tkoodi\tkesto_s\tsiemen\tok_riveja\tvirhe_riveja\tuusinta\n' >"$log.ajot.tsv"
tsv_run() { # tsv_run NIMI AJO TULOS KOODI KESTO SIEMEN TULOSTE UUSINTA
	local ok_n err_n
	ok_n=$(grep -c '^[[:space:]]*OK' "$7")
	err_n=$(grep -c '^[[:space:]]*VIRHE' "$7")
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$ok_n" "$err_n" "$8" >>"$log.ajot.tsv"
	printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$7" "$8" >>"$runs_list"
}
prev=""
for ((k = 1; k <= nslots; k++)); do
	if [ "${r_name[k]}" != "$prev" ]; then
		prev="${r_name[k]}"
		run_idx=0
	fi
	run_idx=$((run_idx + 1))
	if [ "${r_status[k]}" = "PUUTTUU" ]; then
		printf '%s\t%s\tPUUTTUU\t\t0\t\t0\t0\t0\n' "${r_name[k]}" "$run_idx" >>"$log.ajot.tsv"
		continue
	fi
	[ -n "${r_out[k]:-}" ] || continue # ei ajettu (keskeytys)
	tsv_run "${r_name[k]}" "$run_idx" "${r_status[k]%% *}" "${r_code[k]}" "${r_secs[k]}" "${r_seed[k]}" "${r_out[k]}" 0
	[ -n "${u_out[k]:-}" ] && tsv_run "${r_name[k]}" "$run_idx" "${u_status[k]}" "${u_code[k]}" "${u_secs[k]}" "${u_seed[k]}" "${u_out[k]}" 1
done
printf 'testi\tajo\ttila\trivi\tluvut\tuusinta\n' >"$log.rivit.tsv"
awk -v mode=tsv "$check_awk" "$runs_list" >>"$log.rivit.tsv"
if [ $default_log -eq 1 ]; then
	ln -sfn "$(basename "$log").rivit.tsv" .test-logs/latest.rivit.tsv
	ln -sfn "$(basename "$log").ajot.tsv" .test-logs/latest.ajot.tsv
fi
read -r checks_ok checks_err < <(awk -F'\t' 'NR > 1 { c[$3]++ } END { print c["OK"] + 0, c["VIRHE"] + 0 }' "$log.rivit.tsv")

# Toistokomento: testin nimi tai kokeiluskripti, ja lisäliput.
repro_args() { # repro_args NIMI
	if [ "$1" = scratchtest ]; then
		printf '%s' "--scratch=$scratch_path"
	else
		printf '%s' "$1"
	fi
	[ -n "$extra_str" ] && printf ' -- %s' "$extra_str"
}

# Yhteenvetotaulukko.
title="Testien yhteenveto"
[ -n "$ref" ] && title+=" ($ref @ $ref_hash)"
bar="===================="
say ""
say "$bar $title $bar"
runs=0
passed=0
failed=()
random=()
missing=()
add_failed() {
	[[ " ${failed[*]} " == *" $1 "* ]] || failed+=("$1")
}
# Kokeiluskripti ei ole REF:n testilistassa vaan REF:stä puuttuu lippu: oma rivi.
missing_scratch=0
add_missing() {
	if [ "$1" = scratchtest ]; then
		missing_scratch=1
	else
		missing+=("$1")
	fi
}
if [ "$repeat" -eq 1 ]; then
	say "TESTI                 TULOS          KESTO"
	for ((k = 1; k <= nslots; k++)); do
		if [ "${r_status[k]}" = "PUUTTUU" ]; then
			say "$(pad "${r_name[k]}" 22)PUUTTUU"
			add_missing "${r_name[k]}"
			continue
		fi
		runs=$((runs + 1))
		say "$(pad "${r_name[k]}" 22)$(pad "${r_status[k]}" 13)$(printf '%5s s' "${r_secs[k]}")"
		if [ "${r_status[k]}" = "OK" ]; then
			passed=$((passed + 1))
		else
			# Satunnaiset omalle rivilleen, Epäonnistuneet-riville vain toistuvat
			if [ "${r_status[k]}" = "SATUNNAINEN" ]; then
				[[ " ${random[*]} " == *" ${r_name[k]} "* ]] || random+=("${r_name[k]}")
			else
				add_failed "${r_name[k]}"
			fi
			[ -n "${r_errs[k]}" ] && say "${r_errs[k]}"
		fi
	done
else
	# Toistoajossa rivi testiä kohden; rivi tulostetaan, kun testin nimi vaihtuu.
	say "TESTI                 LÄPI    VIRHE  AIKAKAT.  KESTO (ka.)"
	prev=""
	for ((k = 1; k <= nslots + 1; k++)); do
		if [ -n "$prev" ] && { [ $k -gt $nslots ] || [ "${r_name[k]}" != "$prev" ]; }; then
			if [ "$t_missing" -eq 1 ]; then
				say "$(pad "$prev" 22)PUUTTUU"
				add_missing "$prev"
			else
				say "$(pad "$prev" 22)$(pad "$t_ok/$t_n" 8)$(printf '%3s    ' "$t_err")$(printf '%4s     ' "$t_to")$(printf '%5s s' $((t_secs / t_n)))"
				[ "$t_ok" -lt "$t_n" ] && add_failed "$prev"
				[ -n "$t_errs" ] && say "$t_errs"
			fi
		fi
		[ $k -gt $nslots ] && break
		if [ "${r_name[k]}" != "$prev" ]; then
			prev="${r_name[k]}"
			t_n=0; t_ok=0; t_err=0; t_to=0; t_secs=0; t_errs=""; t_missing=0; t_failed=0
		fi
		case "${r_status[k]}" in
			PUUTTUU) t_missing=1; continue ;;
			OK) t_ok=$((t_ok + 1)); passed=$((passed + 1)) ;;
			AIKAKATKAISU) t_to=$((t_to + 1)) ;;
			*) t_err=$((t_err + 1)) ;;
		esac
		t_n=$((t_n + 1))
		t_secs=$((t_secs + r_secs[k]))
		runs=$((runs + 1))
		# Ensimmäisen epäonnistuneen ajon VIRHE-rivit ja toistokomento sen siemenellä.
		if [ "${r_status[k]}" != "OK" ] && [ $t_failed -eq 0 ]; then
			t_failed=1
			t_errs="${r_errs[k]}"
			if [ -n "${r_seed[k]}" ]; then
				[ -n "$t_errs" ] && t_errs+=$'\n'
				t_errs+="    toista: tools/run_tests.sh --seed=${r_seed[k]} $(repro_args "$prev")"
			fi
		fi
	done
	# Rivit, jotka vaihtelivat ajosta toiseen (luvut pienin…suurin).
	variation="$(awk -v mode=vaihtelu "$check_awk" "$runs_list")"
	[ -n "$variation" ] && say "$variation"
fi
say "------------------------------------------------------------"
parallel_note=""
[ "$jobs" -gt 1 ] && parallel_note=" (rinnakkain $jobs)"
say "Läpi $passed/$runs, kesto yhteensä $((total_secs / 60)) min $((total_secs % 60)) s$parallel_note"
say "Tarkistusrivit: OK $checks_ok, VIRHE $checks_err"
[ ${#failed[@]} -gt 0 ] && say "Epäonnistuneet: ${failed[*]}"
[ ${#random[@]} -gt 0 ] && say "Satunnaiset: ${random[*]}"
[ ${#missing[@]} -gt 0 ] && say "Puuttuu $ref:n testilistasta: ${missing[*]}"
[ $missing_scratch -eq 1 ] && say "Puuttuu $ref:stä: --scratchtest-lippu (scripts/test_flags.gd), scratchtest ei ajettu"
say "Loki: $log_shown"
say "============================================================"
[ $changed -eq 1 ] && say "$quick_note"

done_msg="lapi=$passed/$runs kesto=$total_secs loki=$log_shown"
if [ ${#random[@]} -gt 0 ]; then
	random_csv="${random[*]}"
	done_msg+=" satunnaiset=${random_csv// /,}"
fi
[ $passed -eq $runs ] || exit 1
exit 0
