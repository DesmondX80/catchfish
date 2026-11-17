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

# Valekomento: speciestest läpi, luretest 7 VIRHE-riviä ja koodi 1 (siemen 42),
# boattest jää jumiin, docktest vaihtelee ajosta toiseen (laskuri tiedostossa
# docktest.n; FAKE_MANY=1 lisää 25 vaihtelevaa riviä). FAKE_DELAY=S viivästää
# jokaista testiä. Argumentit kaiutetaan lokiin.
fake="$tmp/fake-godot"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
echo "argumentit: $*"
[ -n "${FAKE_DELAY:-}" ] && sleep "$FAKE_DELAY"
case " $* " in
	*" --speciestest "*) echo "OK   lajit"; echo "OK   koot"; exit 0 ;;
	*" --luretest "*)
		echo "Siemen: 42 (toista: --seed=42)"
		echo "OK   uistin 1"
		for i in 1 2 3 4 5 6 7; do echo "VIRHE uistin $i syvyys"; done
		exit 1 ;;
	*" --boattest "*) exec sleep 30 ;;
	*" --docktest "*)
		cnt="$(dirname "$0")/docktest.n"
		n=$(( $(cat "$cnt" 2>/dev/null || echo 0) + 1 ))
		echo "$n" >"$cnt"
		echo "OK   vakaa 7 m (raja 10)"
		case $n in
			1) echo "OK   jalat x -0.38 (raja -0.50)"; echo "VIRHE vain kerran 1,5–2,5 m" ;;
			2) echo "VIRHE jalat x -0.52 (raja -0.50)" ;;
			*) echo "OK   jalat x -0.45 (raja -0.50)" ;;
		esac
		if [ -n "${FAKE_MANY:-}" ]; then
			for w in a b c d e f g h i j k l m n o p q r s t u v w x y; do echo "OK   mitta $w $n"; done
		fi
		[ $n -eq 2 ] || [ $n -eq 1 ] && exit 1
		exit 0 ;;
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
check "VIRHE-testi: siemen tulosrivillä" has '^>> VIRHE +luretest +[0-9]+ s \(koodi 1, siemen 42\)$'

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
check "--repeat: toista-rivi siemenellä" has '^    toista: tools/run_tests.sh --seed=42 luretest$'
check "--repeat: toista-rivi kerran" test "$(grep -c '^    toista:' <<<"$out")" -eq 1
check "--repeat: ei toista-riviä läpi menneelle" lacks 'toista: .*speciestest'

# Siemen.
run -q --seed=5 speciestest
check "--seed: paluukoodi 0" test $rc -eq 0
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "--seed=5 välittyy testille" grep -qE '^argumentit: .* --speciestest --seed=5$' "$tmp/$log"
run -q --seed=5 seedtest
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "--seed: seedtest pitää oman siemenensä" grep -qE '^argumentit: .* --seed=171 --seedtest$' "$tmp/$log"
run --seed=x speciestest
check "--seed=x: paluukoodi 2" test $rc -eq 2
run --seed=-1 speciestest
check "--seed=-1: paluukoodi 2" test $rc -eq 2

# Oma lokipolku.
run --log="$tmp/oma.log" speciestest
check "--log: loki annetussa polussa" grep -q '^Läpi 1/1' "$tmp/oma.log"

# Lokeja säilytetään 20 (saman sekunnin ajot saavat eri nimet, joten
# aiempia lokeja ei tarvitse poistaa).
for i in $(seq -w 1 25); do : >"$tmp/.test-logs/20000101-0000$i.log"; done
run speciestest
check "lokeja säilytetään 20" \
	test "$(find "$tmp/.test-logs" -name '2*.log' | wc -l)" -eq 20

# Lokinimi: kaksi ajoa samalla sekunnilla (date pysäytetty) → kaksi lokia.
mkdir -p "$tmp/bin"
real_date="$(command -v date)"
cat >"$tmp/bin/date" <<EOF
#!/usr/bin/env bash
[ "\$1" = "+%Y%m%d-%H%M%S" ] && { echo 20991231-235959; exit 0; }
exec "$real_date" "\$@"
EOF
chmod +x "$tmp/bin/date"
PATH="$tmp/bin:$PATH" run -q speciestest
check "lokinimi: ensimmäinen ajo" has '^Loki: \.test-logs/20991231-235959\.log$'
PATH="$tmp/bin:$PATH" run -q luretest
check "lokinimi: saman sekunnin ajo saa päätteen -2" has '^Loki: \.test-logs/20991231-235959-2\.log$'
check "lokinimi: ensimmäisessä lokissa oma Läpi-rivi" grep -q '^Läpi 1/1' "$tmp/.test-logs/20991231-235959.log"
check "lokinimi: toisessa lokissa oma Läpi-rivi" grep -q '^Läpi 0/1' "$tmp/.test-logs/20991231-235959-2.log"

# Valmismerkki .test-logs/latest.done.
done_f="$tmp/.test-logs/latest.done"
run -q speciestest
check "valmismerkki: läpi → exit=0 lapi=1/1" grep -qE '^exit=0 lapi=1/1 kesto=[0-9]+ loki=\.test-logs/[^ ]+\.log paattyi=[0-9:]+$' "$done_f"
run -q luretest
check "valmismerkki: VIRHE → exit=1" grep -qE '^exit=1 lapi=0/1 ' "$done_f"
run -q eiolemassa
check "valmismerkki: väärä käyttö → exit=2" grep -qE '^exit=2 virhe="tuntematon testi eiolemassa" paattyi=' "$done_f"
before="$(cat "$done_f")"
run -q --log="$tmp/oma2.log" speciestest
check "valmismerkki: --log=X → X.done" grep -qE '^exit=0 lapi=1/1 ' "$tmp/oma2.log.done"
check "valmismerkki: --log ei koske latest.doneen" test "$(cat "$done_f")" = "$before"
GODOT="$fake" FAKE_DELAY=2 "$runner" -q speciestest >"$tmp/bg.out" 2>&1 &
bgpid=$!
for _ in $(seq 50); do grep -q "pid=$bgpid " "$tmp/.test-logs/run.lock" 2>/dev/null && break; sleep 0.1; done
sleep 0.3
check "valmismerkki: ei ajon aikana" test ! -e "$done_f"
kill -TERM $bgpid
wait $bgpid
rc=$?
check "keskeytys: paluukoodi 130" test $rc -eq 130
check "valmismerkki: keskeytys → exit=130 keskeytetty" grep -qE '^exit=130 keskeytetty paattyi=' "$done_f"

# Lukko: yksi ajo kerrallaan samassa työkopiossa.
GODOT="$fake" FAKE_DELAY=3 "$runner" -q speciestest >"$tmp/bg.out" 2>&1 &
bgpid=$!
for _ in $(seq 50); do grep -q "pid=$bgpid " "$tmp/.test-logs/run.lock" 2>/dev/null && break; sleep 0.1; done
latest_before="$(readlink "$tmp/.test-logs/latest.log")"
run -q speciestest
check "lukko: paluukoodi 3" test $rc -eq 3
check "lukko: ilmoitus ja PID" has "toinen ajo on käynnissä tässä työkopiossa \(pid=$bgpid alkoi=[0-9:]+ komento=\"-q speciestest\"\)"
check "lukko: odotusohje" has '^Odota: until \[ -f \.test-logs/latest\.done \]'
check "lukko: latest.log ennallaan" test "$(readlink "$tmp/.test-logs/latest.log")" = "$latest_before"
check "lukko: latest.done ennallaan (ei olemassa)" test ! -e "$done_f"
run -q --wait luretest
check "--wait: odotusrivi" has '^>> Odotetaan: toinen ajo on käynnissä tässä työkopiossa \(pid='
check "--wait: ajo odottaa ja ajetaan" has '^>> VIRHE +luretest'
check "--wait: taustaajo valmistui ensin" grep -q '^Läpi 1/1' "$tmp/bg.out"
wait $bgpid
check "lukko: taustaajo läpi" test $? -eq 0
# kill -9: lukko vapautuu, vaikka valekomento jää käyntiin.
GODOT="$fake" FAKE_DELAY=30 setsid "$runner" -q speciestest >"$tmp/bg.out" 2>&1 &
bgpid=$!
for _ in $(seq 50); do grep -q "pid=$bgpid " "$tmp/.test-logs/run.lock" 2>/dev/null && break; sleep 0.1; done
kill -9 $bgpid
wait $bgpid 2>/dev/null
run -q speciestest
check "lukko: kill -9:n jälkeen uusi ajo käynnistyy" test $rc -eq 0
kill -9 -- -$bgpid 2>/dev/null
# Eri työkopiot ajavat rinnakkain.
tmp2="$tmp/kopio2"
mkdir -p "$tmp2/tools"
cp "$src" "$tmp2/tools/run_tests.sh"
GODOT="$fake" FAKE_DELAY=2 "$runner" -q speciestest >"$tmp/bg.out" 2>&1 &
bgpid=$!
for _ in $(seq 50); do grep -q "pid=$bgpid " "$tmp/.test-logs/run.lock" 2>/dev/null && break; sleep 0.1; done
out="$(GODOT="$fake" "$tmp2/tools/run_tests.sh" -q speciestest 2>&1)"
rc=$?
check "lukko: toinen työkopio ajaa rinnakkain" test $rc -eq 0
wait $bgpid
check "lukko: ensimmäinen työkopio läpi" test $? -eq 0

# Vaihtelevat rivit toistoajossa.
check_variation() { # check_variation TUNNISTE
	rm -f "$tmp/docktest.n"
	run -q --repeat=3 docktest speciestest
	check "vaihtelu$1: lohko" has '^Vaihtelevat rivit: docktest \(3 ajoa\)$'
	check "vaihtelu$1: otsikko" has '^  AJOJA  TULOS            RIVI \(luvut pienin…suurin\)$'
	check "vaihtelu$1: pienin…suurin ja OK/VIRHE" has '^   3/3   OK 2, VIRHE 1    jalat x -0\.52…-0\.38 \(raja -0\.50\)$'
	check "vaihtelu$1: yhdessä ajossa 1/3" has '^   1/3   VIRHE 1          vain kerran 1,5–2,5 m$'
	check "vaihtelu$1: vakaa rivi ei tulostu" lacks 'vakaa 7 m'
	check "vaihtelu$1: vakaa testi" has '^Vaihtelevia rivejä ei ole: speciestest \(3 ajoa tuottivat samat OK/VIRHE-rivit\)\.$'
	check "vaihtelu$1: ennen Läpi-riviä" \
		test "$(grep -n '^Vaihtelevat rivit' <<<"$out" | cut -d: -f1)" -lt "$(grep -n '^Läpi' <<<"$out" | cut -d: -f1)"
}
check_variation ""
# Sama mawkilla ja gawk --posixilla, jos ne on asennettu (CI:n awk voi olla mawk).
if command -v mawk >/dev/null 2>&1; then
	mkdir -p "$tmp/mawk"
	ln -sf "$(command -v mawk)" "$tmp/mawk/awk"
	PATH="$tmp/mawk:$PATH" check_variation " (mawk)"
fi
if command -v gawk >/dev/null 2>&1; then
	mkdir -p "$tmp/gawkp"
	printf '#!/bin/sh\nexec "%s" --posix "$@"\n' "$(command -v gawk)" >"$tmp/gawkp/awk"
	chmod +x "$tmp/gawkp/awk"
	PATH="$tmp/gawkp:$PATH" check_variation " (gawk --posix)"
fi
rm -f "$tmp/docktest.n"
FAKE_MANY=1 run -q --repeat=3 docktest
check "vaihtelu: enintään 20 riviä" \
	test "$(sed -n '/^Vaihtelevat rivit: docktest/,/^---/p' <<<"$out" | grep -c '^ \{2,\}[0-9]\+/3 ')" -eq 20
check "vaihtelu: (+7 muuta)" has '^    \(\+7 muuta\)$'
rm -f "$tmp/docktest.n"
run -q docktest
check "vaihtelu: --repeat=1 ei lohkoa" lacks 'Vaihtel'
check "vaihtelu: paluukoodi ennallaan" test $rc -eq 1

# Koneluettava yhteenveto: .ajot.tsv ja .rivit.tsv.
run -q luretest speciestest
ajot="$tmp/.test-logs/latest.ajot.tsv"
rivit="$tmp/.test-logs/latest.rivit.tsv"
tab=$'\t'
check "tsv: ajot-otsikko" test "$(head -n 1 "$ajot")" = "testi${tab}ajo${tab}tulos${tab}koodi${tab}kesto_s${tab}siemen${tab}ok_riveja${tab}virhe_riveja"
check "tsv: luretest-ajo" grep -qE "^luretest${tab}1${tab}VIRHE${tab}1${tab}[0-9]+${tab}42${tab}1${tab}7\$" "$ajot"
check "tsv: speciestest-ajo" grep -qE "^speciestest${tab}1${tab}OK${tab}0${tab}[0-9]+${tab}${tab}2${tab}0\$" "$ajot"
check "tsv: rivit-otsikko" test "$(head -n 1 "$rivit")" = "testi${tab}ajo${tab}tila${tab}rivi${tab}luvut"
check "tsv: luretestin 8 riviä" test "$(grep -c "^luretest${tab}" "$rivit")" -eq 8
check "tsv: luretest 1 OK" test "$(grep -c "^luretest${tab}1${tab}OK${tab}" "$rivit")" -eq 1
check "tsv: luretest 7 VIRHE" test "$(grep -c "^luretest${tab}1${tab}VIRHE${tab}" "$rivit")" -eq 7
check "tsv: luvut-sarake" grep -qx "luretest${tab}1${tab}VIRHE${tab}uistin 3 syvyys${tab}3" "$rivit"
check "tsv: Tarkistusrivit-rivi" has '^Tarkistusrivit: OK 3, VIRHE 7$'
check "tsv: Tarkistusrivit Läpi-rivin alla" \
	test "$(grep -A1 '^Läpi' <<<"$out" | tail -n 1)" = "Tarkistusrivit: OK 3, VIRHE 7"
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "tsv: lokin vieressä" test -f "$tmp/$log.ajot.tsv" -a -f "$tmp/$log.rivit.tsv"
run -q --repeat=3 luretest
check "tsv: --repeat=3 → 3 ajoriviä" test "$(grep -c "^luretest${tab}[1-3]${tab}VIRHE" "$ajot")" -eq 3
check "tsv: luvut miinuksella" bash -c "rm -f '$tmp/docktest.n'; GODOT='$fake' '$runner' -q docktest >/dev/null 2>&1; grep -qx 'docktest${tab}1${tab}OK${tab}jalat x -0.38 (raja -0.50)${tab}-0.38 -0.50' '$rivit'"

# Argumenttivihje: Godot väärässä paikassa.
run -q "$fake" speciestest
check "vihje: paluukoodi 2" test $rc -eq 2
check "vihje: tuntematon testi" has "tuntematon testi $fake"
check "vihje: komento oikeassa järjestyksessä" has "^Vihje: Godot annetaan ensimmäisenä argumenttina: tools/run_tests.sh $fake -q speciestest\$"
run eiolemassa
check "vihje: ei tavalliselle nimelle" lacks 'Vihje'

# --scratch ja läpivienti.
out="$(cd "$tmp" && GODOT="$fake" "$runner" -q --scratch=koe.gd 2>&1)"
rc=$?
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "--scratch: paluukoodi 0" test $rc -eq 0
check "--scratch: absoluuttinen polku argumenteissa" grep -qE "^argumentit: --headless --fixed-fps 30 -- --day=180 --scratchtest=$tmp/koe\.gd\$" "$tmp/$log"
check "--scratch: taulukossa scratchtest" has '^scratchtest +OK +[0-9]+ s$'
check "--scratch: vain kokeilu ajetaan" test "$(grep -c '^>>' <<<"$out")" -eq 1
run -q --scratch="$tmp/koe.gd" speciestest
check "--scratch ja nimetty testi" test "$(grep -cE '^(scratchtest|speciestest) +OK' <<<"$out")" -eq 2
run -q speciestest -- --oma=1
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "läpivienti: argumenttien lopussa" grep -qE '^argumentit: .* --speciestest --oma=1$' "$tmp/$log"
check "läpivienti: tulosrivillä lisäliput" has '^>> OK +speciestest +[0-9]+ s \(lisäliput: --oma=1\)$'
run -q --seed=5 speciestest -- --oma=1
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "läpivienti: siemenen jälkeen" grep -qE '^argumentit: .* --speciestest --seed=5 --oma=1$' "$tmp/$log"
run -q --repeat=2 luretest -- --oma=1
check "läpivienti: toista-rivillä" has '^    toista: tools/run_tests.sh --seed=42 luretest -- --oma=1$'
run -q -- --oma=1
check "läpivienti ilman testiä: paluukoodi 2" test $rc -eq 2

echo
if [ $failures -gt 0 ]; then
	echo "Itsetesti: $failures virhettä"
	exit 1
fi
echo "Itsetesti läpi."
