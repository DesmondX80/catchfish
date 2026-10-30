#!/usr/bin/env bash
# Ajaa ikkunattomat (headless) testit peräkkäin, tulostaa lopuksi yhteenvetotaulukon
# ja kirjoittaa koko ajon lokiin.
# Käyttö: tools/run_tests.sh [GODOT] [LIPUT] [TESTIN_NIMI...]
#   GODOT           Godot-ohjelma (oletus: $GODOT, sitten godot-4.7.2, sitten godot)
#   TESTIN_NIMI     ajaa vain nimetyt testit, esim. luretest docktest
#   --repeat=N      aja jokainen valittu testi N kertaa (oletus 1)
#   --ref=REF       aja testit REF:n (esim. origin/main) väliaikaisessa työkopiossa
#   --log=TIEDOSTO  lokin polku (oletus .test-logs/AAAAKKPP-HHMMSS.log)
#   -q, --quiet     ei Godotin tulostetta päätteeseen, vain tulosrivit ja taulukko
# Testi epäonnistuu, jos se palauttaa muun kuin 0 (testit lopettavat koodilla 1,
# kun lokissa on VIRHE-rivi) tai ei valmistu aikarajassa ($TEST_TIMEOUT, oletus 600 s).
# Paluukoodi: 0 kaikki läpi, 1 jokin VIRHE tai AIKAKATKAISU, 2 väärä käyttö.
# Ikkunaa vaativat testit (inputtest, pausetest, menutest, settingstest,
# careertest, timepicktest, tvtest) eivät ole mukana.
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
	"docktest|--fixed-fps 30 -- --day=180 --docktest"
	"headwindtest|--fixed-fps 30 -- --day=180 --headwindtest"
	"icetest|--fixed-fps 30 -- --day=40 --icetest"
	"luretest|--fixed-fps 30 -- --day=180 --luretest"
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
	"seasonfishtest|-- --day=180 --seasonfishtest"
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
	"wavesoundtest|--fixed-fps 30 -- --day=180 --wavesoundtest"
	"wavesoundtest-talvi|--fixed-fps 30 -- --day=40 --wavesoundtest"
	"wavetest|--fixed-fps 30 -- --day=180 --wavetest"
)

usage_error() {
	echo "run_tests.sh: $1" >&2
	echo "Käyttö: tools/run_tests.sh [GODOT] [--repeat=N] [--ref=REF] [--log=TIEDOSTO] [-q] [TESTIN_NIMI...]" >&2
	exit 2
}

is_test_name() {
	local entry
	for entry in "${tests[@]}"; do
		[ "${entry%%|*}" = "$1" ] && return 0
	done
	return 1
}

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
log=""
quiet=0
selected=()
for arg in "$@"; do
	case "$arg" in
		--repeat=*) repeat="${arg#--repeat=}" ;;
		--ref=*) ref="${arg#--ref=}"; ref_given=1 ;;
		--log=*) log="${arg#--log=}" ;;
		-q|--quiet) quiet=1 ;;
		-*) usage_error "tuntematon lippu $arg" ;;
		*)
			is_test_name "$arg" || usage_error "tuntematon testi $arg"
			selected+=("$arg")
			;;
	esac
done
[[ "$repeat" =~ ^[1-9][0-9]*$ ]] || usage_error "--repeat vaatii positiivisen kokonaisluvun"
[ $ref_given -eq 1 ] && [ -z "$ref" ] && usage_error "--ref vaatii refin, esim. --ref=origin/main"

# Polut absoluuttisiksi ennen hakemiston vaihtoa.
godot_path="$(command -v "$godot" 2>/dev/null)" || usage_error "Godotia ei löydy: $godot"
[[ "$godot_path" == */* ]] && godot_path="$(realpath "$godot_path")"
[ -n "$log" ] && log="$(realpath -m "$log")"

cd "$(dirname "$0")/.." || exit 2
root="$(pwd)"

ref_hash=""
ref_slug=""
if [ -n "$ref" ]; then
	ref_hash="$(git rev-parse --short --verify --quiet "$ref^{commit}")" \
		|| usage_error "ref ei ratkea: $ref"
	ref_slug="-$(printf '%s' "$ref" | tr -c 'A-Za-z0-9._' '-')"
fi

# Loki: oletuksena .test-logs/, josta säilytetään $keep_logs viimeisintä.
default_log=0
if [ -z "$log" ]; then
	default_log=1
	mkdir -p .test-logs
	ls -1 .test-logs/ | grep -E '^[0-9]{8}-[0-9]{6}.*\.log$' | sort \
		| head -n -$((keep_logs - 1)) | while read -r old; do rm -f ".test-logs/$old"; done
	log="$root/.test-logs/$(date +%Y%m%d-%H%M%S)$ref_slug.log"
fi
mkdir -p "$(dirname "$log")"
: >"$log" || usage_error "lokia ei voi kirjoittaa: $log"
[ $default_log -eq 1 ] && ln -sfn "$(basename "$log")" .test-logs/latest.log
log_shown="${log#"$root"/}"

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

workdir="$root"
ref_dir=""
out_file="$(mktemp)"
cleanup() {
	rm -f "$out_file"
	[ -n "$ref_dir" ] || return
	git -C "$root" worktree remove --force "$ref_dir" >/dev/null 2>&1 || rm -rf "$ref_dir"
	git -C "$root" worktree prune >/dev/null 2>&1
	ref_dir=""
}
trap cleanup EXIT
trap 'echo; say ">> Keskeytetty."; exit 130' INT TERM

ref_entries=""
if [ -n "$ref" ]; then
	[[ "$ref" == origin/* ]] && say ">> Vihje: aja ensin git fetch, jos $ref ei ole ajan tasalla."
	ref_dir="$(mktemp -d "${TMPDIR:-/tmp}/run-tests${ref_slug}-XXXX")"
	say ">> Ajetaan $ref @ $ref_hash väliaikaisessa työkopiossa $ref_dir"
	git worktree add --detach "$ref_dir" "$ref" >>"$log" 2>&1 \
		|| { say ">> Työkopiota ei voitu luoda."; exit 2; }
	workdir="$ref_dir"
	ref_entries="$(git show "$ref:tools/run_tests.sh" 2>/dev/null)"
	say ">> Tuodaan projekti (--headless --import)"
	(cd "$workdir" && timeout --foreground "$timeout_s" "$godot_path" --headless --import) >>"$log" 2>&1
fi

# Tulokset, yksi alkio ajoa kohden.
r_name=()
r_status=()
r_secs=()
r_errs=()

total_start=$(date +%s)
for entry in "${tests[@]}"; do
	name="${entry%%|*}"
	args="${entry#*|}"
	if [ ${#selected[@]} -gt 0 ] && [[ ! " ${selected[*]} " == *" $name "* ]]; then
		continue
	fi
	if [ -n "$ref" ] && [[ "$ref_entries" != *"\"$name|"* ]]; then
		say ">> $(pad PUUTTUU 13) $name (ei $ref:n testilistassa)"
		r_name+=("$name"); r_status+=("PUUTTUU"); r_secs+=(0); r_errs+=("")
		continue
	fi
	for ((i = 1; i <= repeat; i++)); do
		label="$name"
		[ "$repeat" -gt 1 ] && label="$name [$i/$repeat]"
		say_raw "::group::$label"
		start=$(date +%s)
		# --foreground: Ctrl+C menee myös Godotille.
		# shellcheck disable=SC2086
		if [ $quiet -eq 1 ]; then
			(cd "$workdir" && timeout --foreground "$timeout_s" "$godot_path" --headless $args) >"$out_file" 2>&1
			code=$?
		else
			(cd "$workdir" && timeout --foreground "$timeout_s" "$godot_path" --headless $args) 2>&1 | tee "$out_file"
			code=${PIPESTATUS[0]}
		fi
		cat "$out_file" >>"$log"
		secs=$(( $(date +%s) - start ))
		say_raw "::endgroup::"
		errs=""
		if [ $code -eq 0 ]; then
			status="OK"
			say ">> $(pad OK 13) $label  $secs s"
		elif [ $code -eq 124 ]; then
			status="AIKAKATKAISU"
			say ">> $(pad AIKAKATKAISU 13) $label  $secs s"
		else
			status="VIRHE ($code)"
			say ">> $(pad VIRHE 13) $label  $secs s (koodi $code)"
		fi
		if [ "$status" != "OK" ]; then
			n_errs=$(grep -c '^[[:space:]]*VIRHE' "$out_file")
			errs="$(grep '^[[:space:]]*VIRHE' "$out_file" | head -n $max_errs | sed 's/^[[:space:]]*/    /')"
			[ "$n_errs" -gt $max_errs ] && errs+=$'\n'"    (+$((n_errs - max_errs)) muuta)"
		fi
		r_name+=("$name"); r_status+=("$status"); r_secs+=("$secs"); r_errs+=("$errs")
	done
done
total_secs=$(( $(date +%s) - total_start ))

# Yhteenvetotaulukko.
title="Testien yhteenveto"
[ -n "$ref" ] && title+=" ($ref @ $ref_hash)"
bar="===================="
say ""
say "$bar $title $bar"
runs=0
passed=0
failed=()
missing=()
add_failed() {
	[[ " ${failed[*]} " == *" $1 "* ]] || failed+=("$1")
}
if [ "$repeat" -eq 1 ]; then
	say "TESTI                 TULOS          KESTO"
	for ((k = 0; k < ${#r_name[@]}; k++)); do
		if [ "${r_status[k]}" = "PUUTTUU" ]; then
			say "$(pad "${r_name[k]}" 22)PUUTTUU"
			missing+=("${r_name[k]}")
			continue
		fi
		runs=$((runs + 1))
		say "$(pad "${r_name[k]}" 22)$(pad "${r_status[k]}" 13)$(printf '%5s s' "${r_secs[k]}")"
		if [ "${r_status[k]}" = "OK" ]; then
			passed=$((passed + 1))
		else
			add_failed "${r_name[k]}"
			[ -n "${r_errs[k]}" ] && say "${r_errs[k]}"
		fi
	done
else
	# Toistoajossa rivi testiä kohden; rivi tulostetaan, kun testin nimi vaihtuu.
	say "TESTI                 LÄPI    VIRHE  AIKAKAT.  KESTO (ka.)"
	prev=""
	for ((k = 0; k <= ${#r_name[@]}; k++)); do
		if [ -n "$prev" ] && { [ $k -eq ${#r_name[@]} ] || [ "${r_name[k]}" != "$prev" ]; }; then
			if [ "$t_missing" -eq 1 ]; then
				say "$(pad "$prev" 22)PUUTTUU"
				missing+=("$prev")
			else
				say "$(pad "$prev" 22)$(pad "$t_ok/$t_n" 8)$(printf '%3s    ' "$t_err")$(printf '%4s     ' "$t_to")$(printf '%5s s' $((t_secs / t_n)))"
				[ "$t_ok" -lt "$t_n" ] && add_failed "$prev"
				[ -n "$t_errs" ] && say "$t_errs"
			fi
		fi
		[ $k -eq ${#r_name[@]} ] && break
		if [ "${r_name[k]}" != "$prev" ]; then
			prev="${r_name[k]}"
			t_n=0; t_ok=0; t_err=0; t_to=0; t_secs=0; t_errs=""; t_missing=0
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
		# Ensimmäisen epäonnistuneen ajon VIRHE-rivit.
		[ -z "$t_errs" ] && [ -n "${r_errs[k]}" ] && t_errs="${r_errs[k]}"
	done
fi
say "------------------------------------------------------------"
say "Läpi $passed/$runs, kesto yhteensä $((total_secs / 60)) min $((total_secs % 60)) s"
[ ${#failed[@]} -gt 0 ] && say "Epäonnistuneet: ${failed[*]}"
[ ${#missing[@]} -gt 0 ] && say "Puuttuu $ref:n testilistasta: ${missing[*]}"
say "Loki: $log_shown"
say "============================================================"

[ $passed -eq $runs ] || exit 1
exit 0
