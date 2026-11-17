#!/usr/bin/env bash
# Ajaa ikkunattomat (headless) testit peräkkäin, tulostaa lopuksi yhteenvetotaulukon
# ja kirjoittaa koko ajon lokiin.
# Käyttö: tools/run_tests.sh [GODOT] [LIPUT] [TESTIN_NIMI...] [-- TESTIN_LISÄLIPUT...]
#   GODOT           Godot-ohjelma (oletus: $GODOT, sitten godot-4.7.2, sitten godot)
#   TESTIN_NIMI     ajaa vain nimetyt testit, esim. luretest docktest
#   --repeat=N      aja jokainen valittu testi N kertaa (oletus 1); N >= 2 tulostaa
#                   lisäksi testeittäin rivit, jotka vaihtelivat ajosta toiseen
#   --ref=REF       aja testit REF:n (esim. origin/main) väliaikaisessa työkopiossa
#   --log=TIEDOSTO  lokin polku (oletus .test-logs/AAAAKKPP-HHMMSS.log)
#   --seed=N        välitä testeille --seed=N (kiinteä satunnaisuus; oletus: siemen
#                   arvotaan joka ajolla). Testin oma --seed (seedtest) pysyy.
#   --wait          odota, jos toinen ajo on käynnissä samassa työkopiossa
#   --scratch=POLKU aja kokeiluskripti (extends Node) testinä scratchtest
#                   (pelin lippu --scratchtest=POLKU)
#   -q, --quiet     ei Godotin tulostetta päätteeseen, vain tulosrivit ja taulukko
#   -- LISÄLIPUT    lisätään jokaisen valitun testin argumenttien loppuun
# Testi epäonnistuu, jos se palauttaa muun kuin 0 (testit lopettavat koodilla 1,
# kun lokissa on VIRHE-rivi) tai ei valmistu aikarajassa ($TEST_TIMEOUT, oletus 600 s).
# Epäonnistuneen ajon tulosrivi kertoo siemenen Godotin "Siemen: N" -riviltä, ja
# toistoajon taulukko näyttää komennon, joka toistaa ajon samalla siemenellä.
# Työkopiossa voi olla käynnissä yksi ajo kerrallaan (lukko .test-logs/run.lock).
# Ajon lopuksi kirjoitetaan valmismerkki .test-logs/latest.done (--log=X: X.done),
# ja lokin viereen tarkistusrivit ja ajot sarkaineroteltuina (X.rivit.tsv,
# X.ajot.tsv; linkit .test-logs/latest.rivit.tsv ja latest.ajot.tsv).
# Paluukoodi: 0 kaikki läpi, 1 jokin VIRHE tai AIKAKATKAISU, 2 väärä käyttö,
# 3 toinen ajo käynnissä tässä työkopiossa, 130 keskeytetty.
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
	echo "Käyttö: tools/run_tests.sh [GODOT] [-q] [--repeat=N] [--ref=REF] [--log=TIEDOSTO] [--seed=N] [--wait] [--scratch=POLKU] [TESTIN_NIMI...] [-- TESTIN_LISÄLIPUT...]" >&2
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

interrupted() {
	echo
	if [ $log_ready -eq 1 ]; then
		say ">> Keskeytetty."
	else
		echo ">> Keskeytetty."
	fi
	done_msg="keskeytetty"
	exit 130
}
trap on_exit EXIT
trap interrupted INT TERM

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
		-*) usage_error "tuntematon lippu $arg" ;;
		*)
			is_test_name "$arg" || usage_error "tuntematon testi $arg" "$(godot_hint "$arg")"
			selected+=("$arg")
			;;
	esac
done
[[ "$repeat" =~ ^[1-9][0-9]*$ ]] || usage_error "--repeat vaatii positiivisen kokonaisluvun"
[ $seed_given -eq 1 ] && ! [[ "$seed" =~ ^[0-9]+$ ]] && usage_error "--seed vaatii ei-negatiivisen kokonaisluvun"
[ $ref_given -eq 1 ] && [ -z "$ref" ] && usage_error "--ref vaatii refin, esim. --ref=origin/main"
[ $scratch_given -eq 1 ] && [ -z "$scratch" ] && usage_error "--scratch vaatii polun, esim. --scratch=koe.gd"

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
	[ ${#selected[@]} -gt 0 ] || usage_error "-- LISÄLIPUT vaatii testin nimen tai --scratch-lipun"
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

workdir="$root"
# Jokaisen ajon tuloste omaan tiedostoonsa: $run_dir/N.out (N = ajon järjestysnumero)
run_dir="$(mktemp -d)"

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
	(cd "$workdir" && timeout --foreground "$timeout_s" "$godot_path" --headless --import) 9>&- >>"$log" 2>&1
fi

# Tarkistusrivit (OK/VIRHE) ajojen tulostetiedostoista. POSIX-awk (myös mawk):
# ei gensubia eikä matchin taulukkomuotoa.
# Syöte: rivi ajoa kohden "testi<TAB>ajo<TAB>tulostetiedosto".
#   mode=tsv       rivi tarkistusriviä kohden: testi, ajo, tila, rivi, luvut
#   mode=vaihtelu  testeittäin rivit, jotka eivät toistuneet samoina joka ajossa
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
			print test "\t" run "\t" st "\t" text "\t" nums
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

# Tulokset, yksi alkio ajoa kohden.
r_name=()
r_status=()
r_code=()
r_secs=()
r_errs=()
r_seed=()
r_out=()

total_start=$(date +%s)
for entry in "${tests[@]}"; do
	name="${entry%%|*}"
	args="${entry#*|}"
	# Siemen testin argumenttien loppuun (kaikissa on --), ellei testillä ole omaa
	[ -n "$seed" ] && [[ " $args " != *" --seed="* ]] && args+=" --seed=$seed"
	[ -n "$extra_str" ] && args+=" $extra_str"
	if [ ${#selected[@]} -gt 0 ] && [[ ! " ${selected[*]} " == *" $name "* ]]; then
		continue
	fi
	if [ -n "$ref" ]; then
		missing_note=""
		if [ "$name" = scratchtest ]; then
			[ $ref_has_scratch -eq 1 ] || missing_note="ei --scratchtest-lippua $ref:ssa"
		elif [[ "$ref_entries" != *"\"$name|"* ]]; then
			missing_note="ei $ref:n testilistassa"
		fi
		if [ -n "$missing_note" ]; then
			say ">> $(pad PUUTTUU 13) $name ($missing_note)"
			r_name+=("$name"); r_status+=("PUUTTUU"); r_code+=(""); r_secs+=(0); r_errs+=(""); r_seed+=(""); r_out+=("")
			continue
		fi
	fi
	for ((i = 1; i <= repeat; i++)); do
		label="$name"
		[ "$repeat" -gt 1 ] && label="$name [$i/$repeat]"
		out_file="$run_dir/$((${#r_name[@]} + 1)).out"
		say_raw "::group::$label"
		start=$(date +%s)
		# --foreground: Ctrl+C menee myös Godotille. 9>&-: lukko ei periydy
		# Godotille, joten se vapautuu ajurin kuollessa (kill -9).
		# shellcheck disable=SC2086
		if [ $quiet -eq 1 ]; then
			(cd "$workdir" && timeout --foreground "$timeout_s" "$godot_path" --headless $args) 9>&- >"$out_file" 2>&1
			code=$?
		else
			{
				(cd "$workdir" && timeout --foreground "$timeout_s" "$godot_path" --headless $args) 2>&1 | tee "$out_file"
				code=${PIPESTATUS[0]}
			} 9>&-
		fi
		cat "$out_file" >>"$log"
		secs=$(( $(date +%s) - start ))
		say_raw "::endgroup::"
		errs=""
		# Pelin tulostama siemen, jolla ajo toistuu (--seed=N)
		run_seed="$(sed -n 's/^Siemen: \([0-9][0-9]*\).*/\1/p' "$out_file" | head -n 1)"
		seed_note=""
		[ -n "$run_seed" ] && seed_note="siemen $run_seed"
		if [ $code -eq 0 ]; then
			status="OK"
			say ">> $(pad OK 13) $label  $secs s$extra_note"
		elif [ $code -eq 124 ]; then
			status="AIKAKATKAISU"
			say ">> $(pad AIKAKATKAISU 13) $label  $secs s${seed_note:+ ($seed_note)}$extra_note"
		else
			status="VIRHE ($code)"
			say ">> $(pad VIRHE 13) $label  $secs s (koodi $code${seed_note:+, $seed_note})$extra_note"
		fi
		if [ "$status" != "OK" ]; then
			n_errs=$(grep -c '^[[:space:]]*VIRHE' "$out_file")
			errs="$(grep '^[[:space:]]*VIRHE' "$out_file" | head -n $max_errs | sed 's/^[[:space:]]*/    /')"
			[ "$n_errs" -gt $max_errs ] && errs+=$'\n'"    (+$((n_errs - max_errs)) muuta)"
		fi
		r_name+=("$name"); r_status+=("$status"); r_code+=("$code"); r_secs+=("$secs"); r_errs+=("$errs"); r_seed+=("$run_seed"); r_out+=("$out_file")
	done
done
total_secs=$(( $(date +%s) - total_start ))

# Koneluettavat yhteenvedot lokin viereen: X.ajot.tsv (rivi ajoa kohden) ja
# X.rivit.tsv (rivi tarkistusriviä kohden). Ajolista vaihteluyhteenvedolle.
runs_list="$run_dir/ajot.list"
: >"$runs_list"
printf 'testi\tajo\ttulos\tkoodi\tkesto_s\tsiemen\tok_riveja\tvirhe_riveja\n' >"$log.ajot.tsv"
prev=""
for ((k = 0; k < ${#r_name[@]}; k++)); do
	if [ "${r_name[k]}" != "$prev" ]; then
		prev="${r_name[k]}"
		run_idx=0
	fi
	run_idx=$((run_idx + 1))
	if [ "${r_status[k]}" = "PUUTTUU" ]; then
		printf '%s\t%s\tPUUTTUU\t\t0\t\t0\t0\n' "${r_name[k]}" "$run_idx" >>"$log.ajot.tsv"
		continue
	fi
	ok_n=$(grep -c '^[[:space:]]*OK' "${r_out[k]}")
	err_n=$(grep -c '^[[:space:]]*VIRHE' "${r_out[k]}")
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${r_name[k]}" "$run_idx" "${r_status[k]%% *}" \
		"${r_code[k]}" "${r_secs[k]}" "${r_seed[k]}" "$ok_n" "$err_n" >>"$log.ajot.tsv"
	printf '%s\t%s\t%s\n' "${r_name[k]}" "$run_idx" "${r_out[k]}" >>"$runs_list"
done
printf 'testi\tajo\ttila\trivi\tluvut\n' >"$log.rivit.tsv"
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
	for ((k = 0; k < ${#r_name[@]}; k++)); do
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
				add_missing "$prev"
			else
				say "$(pad "$prev" 22)$(pad "$t_ok/$t_n" 8)$(printf '%3s    ' "$t_err")$(printf '%4s     ' "$t_to")$(printf '%5s s' $((t_secs / t_n)))"
				[ "$t_ok" -lt "$t_n" ] && add_failed "$prev"
				[ -n "$t_errs" ] && say "$t_errs"
			fi
		fi
		[ $k -eq ${#r_name[@]} ] && break
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
say "Läpi $passed/$runs, kesto yhteensä $((total_secs / 60)) min $((total_secs % 60)) s"
say "Tarkistusrivit: OK $checks_ok, VIRHE $checks_err"
[ ${#failed[@]} -gt 0 ] && say "Epäonnistuneet: ${failed[*]}"
[ ${#missing[@]} -gt 0 ] && say "Puuttuu $ref:n testilistasta: ${missing[*]}"
[ $missing_scratch -eq 1 ] && say "Puuttuu $ref:stä: --scratchtest-lippu (scripts/test_flags.gd), scratchtest ei ajettu"
say "Loki: $log_shown"
say "============================================================"

done_msg="lapi=$passed/$runs kesto=$total_secs loki=$log_shown"
[ $passed -eq $runs ] || exit 1
exit 0
