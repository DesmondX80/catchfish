#!/usr/bin/env bash
# Ajaa ikkunattomat (headless) testit peräkkäin ja kertoo, mitkä epäonnistuivat.
# Käyttö: tools/run_tests.sh [GODOT] [TESTIN_NIMI...]
#   GODOT       Godot-ohjelman polku (oletus: $GODOT tai "godot")
#   TESTIN_NIMI ajaa vain nimetyt testit, esim. luretest docktest-talvi
# Testi epäonnistuu, jos se palauttaa muun kuin 0 (testit lopettavat koodilla 1,
# kun lokissa on VIRHE-rivi) tai ei valmistu aikarajassa.
# Ikkunaa vaativat testit (inputtest, pausetest, menutest, settingstest,
# careertest, timepicktest, tvtest) eivät ole mukana.
set -u

godot="${1:-${GODOT:-godot}}"
shift || true
timeout_s="${TEST_TIMEOUT:-600}"
cd "$(dirname "$0")/.."

# nimi|argumentit
tests=(
	"anchortest|--fixed-fps 30 -- --day=180 --anchortest"
	"anglertest|--fixed-fps 30 -- --day=180 --anglertest"
	"anglertest-talvi|--fixed-fps 30 -- --day=40 --anglertest"
	"baittest|--fixed-fps 30 -- --day=180 --baittest"
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
)

failed=()
for entry in "${tests[@]}"; do
	name="${entry%%|*}"
	args="${entry#*|}"
	if [ $# -gt 0 ] && [[ ! " $* " == *" $name "* ]]; then
		continue
	fi
	echo "::group::$name"
	start=$(date +%s)
	# shellcheck disable=SC2086
	timeout "$timeout_s" "$godot" --headless $args
	code=$?
	echo "::endgroup::"
	secs=$(( $(date +%s) - start ))
	if [ $code -eq 0 ]; then
		echo "OK    $name (${secs} s)"
	else
		[ $code -eq 124 ] && echo "AIKAKATKAISU $name (${timeout_s} s)"
		echo "VIRHE $name (koodi $code, ${secs} s)"
		failed+=("$name")
	fi
done

if [ ${#failed[@]} -gt 0 ]; then
	echo "Epäonnistuneet testit: ${failed[*]}"
	exit 1
fi
echo "Kaikki testit läpi."
