#!/usr/bin/env bash
# Itsetesti tools/run_tests.sh:lle valekomennolla, ei vaadi Godotia.
# Kopioi skriptin väliaikaiseen hakemistoon, jolloin lokit (.test-logs/)
# eivät mene työkopioon. --ref testataan käsin.
# Käyttö: tools/run_tests_selftest.sh
set -u

src="$(cd "$(dirname "$0")" && pwd)/run_tests.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/tools"
cp "$src" "$tmp/tools/run_tests.sh"
runner="$tmp/tools/run_tests.sh"

# Valekomento: speciestest läpi, luretest 7 VIRHE-riviä ja koodi 1, boattest jää jumiin.
fake="$tmp/fake-godot"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
case " $* " in
	*" --speciestest "*) echo "OK   lajit"; echo "OK   koot"; exit 0 ;;
	*" --luretest "*)
		echo "OK   uistin 1"
		for i in 1 2 3 4 5 6 7; do echo "VIRHE uistin $i syvyys"; done
		exit 1 ;;
	*" --boattest "*) exec sleep 30 ;;
esac
exit 0
EOF
chmod +x "$fake"

failures=0
check() { # check KUVAUS EHTO...
	local desc="$1"
	shift
	if "$@"; then
		echo "OK   $desc"
	else
		echo "VIRHE $desc"
		failures=$((failures + 1))
	fi
}

run() { # run [ARGUMENTIT...]: tuloste $out, paluukoodi $rc
	out="$(GODOT="$fake" TEST_TIMEOUT="${TEST_TIMEOUT:-600}" "$runner" "$@" 2>&1)"
	rc=$?
}
has() { grep -qE -- "$1" <<<"$out"; }
lacks() { ! grep -qE -- "$1" <<<"$out"; }

# Läpi menevä testi, GODOT ympäristömuuttujasta.
run speciestest
check "OK-testi: paluukoodi 0" test $rc -eq 0
check "OK-testi: taulukon rivi" has '^speciestest +OK +[0-9]+ s$'
check "OK-testi: tulosrivi >>" has '^>> OK +speciestest'
check "OK-testi: läpimenot" has '^Läpi 1/1, kesto yhteensä'
check "OK-testi: lokin polku" has '^Loki: \.test-logs/[0-9]{8}-[0-9]{6}\.log$'
check "OK-testi: ::group::" has '^::group::speciestest$'
check "OK-testi: Godotin tuloste päätteessä" has '^OK   lajit$'
check ">>-rivit erottuvat testien riveistä" \
	test "$(grep -c '^>>' <<<"$out")" -eq 1

# Loki ja latest.log.
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "loki on olemassa" test -f "$tmp/$log"
check "latest.log osoittaa lokiin" \
	test "$(readlink "$tmp/.test-logs/latest.log")" = "$(basename "$log")"
check "lokissa Godotin tuloste" grep -q '^OK   lajit$' "$tmp/$log"
check "lokissa taulukko" grep -q '^Läpi 1/1' "$tmp/$log"

# Epäonnistuva testi, Godot ensimmäisenä argumenttina.
out="$("$runner" "$fake" luretest 2>&1)"
rc=$?
check "VIRHE-testi: paluukoodi 1" test $rc -eq 1
check "VIRHE-testi: taulukossa VIRHE (1)" has '^luretest +VIRHE \(1\) +[0-9]+ s$'
check "VIRHE-testi: 5 VIRHE-riviä sisennettynä" \
	test "$(grep -c '^    VIRHE uistin' <<<"$out")" -eq 5
check "VIRHE-testi: (+2 muuta)" has '^    \(\+2 muuta\)$'
check "VIRHE-testi: epäonnistuneet" has '^Epäonnistuneet: luretest$'

# Aikakatkaisu.
TEST_TIMEOUT=1 run boattest speciestest
check "aikakatkaisu: paluukoodi 1" test $rc -eq 1
check "aikakatkaisu: taulukossa AIKAKATKAISU" has '^boattest +AIKAKATKAISU +[0-9]+ s$'
check "aikakatkaisu: muut ajetaan" has '^speciestest +OK'
check "aikakatkaisu: läpi 1/2" has '^Läpi 1/2,'

# Väärä käyttö.
run eiolemassa
check "tuntematon testi: paluukoodi 2" test $rc -eq 2
check "tuntematon testi: ilmoitus" has 'tuntematon testi eiolemassa'
check "tuntematon testi: ei ajoja" lacks '^>>'
run --eiole speciestest
check "tuntematon lippu: paluukoodi 2" test $rc -eq 2
run --repeat=0 speciestest
check "--repeat=0: paluukoodi 2" test $rc -eq 2
out="$("$runner" /ei/ole/godot speciestest 2>&1)"
rc=$?
check "Godotia ei löydy: paluukoodi 2" test $rc -eq 2

# Hiljainen tila.
run -q luretest
check "-q: ei Godotin tulostetta" lacks '^OK   uistin 1$'
check "-q: ei ::group::-rivejä" lacks '^::'
check "-q: tulosrivi näkyy" has '^>> VIRHE +luretest'
check "-q: taulukko näkyy" has '^luretest +VIRHE \(1\)'
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "-q: lokissa Godotin tuloste" grep -q '^OK   uistin 1$' "$tmp/$log"
check "-q: lokissa ::group::" grep -q '^::group::luretest$' "$tmp/$log"

# Toistoajo.
run -q --repeat=3 speciestest luretest
check "--repeat: kolme ajoa testiä kohden" \
	test "$(grep -cE '^>> OK +speciestest \[[1-3]/3\]' <<<"$out")" -eq 3
check "--repeat: speciestest 3/3" has '^speciestest +3/3 +0 +0 +[0-9]+ s$'
check "--repeat: luretest 0/3" has '^luretest +0/3 +3 +0 +[0-9]+ s$'
check "--repeat: läpi 3/6" has '^Läpi 3/6,'
check "--repeat: paluukoodi 1" test $rc -eq 1

# Oma lokipolku.
run --log="$tmp/oma.log" speciestest
check "--log: loki annetussa polussa" grep -q '^Läpi 1/1' "$tmp/oma.log"

# Lokeja säilytetään 20.
for i in $(seq -w 1 25); do : >"$tmp/.test-logs/20000101-0000$i.log"; done
run speciestest
check "lokeja säilytetään 20" \
	test "$(find "$tmp/.test-logs" -name '2*.log' | wc -l)" -eq 20

echo
if [ $failures -gt 0 ]; then
	echo "Itsetesti: $failures virhettä"
	exit 1
fi
echo "Itsetesti läpi."
