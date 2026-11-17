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
# docktest.n; FAKE_MANY=1 lisää 25 vaihtelevaa riviä). casttest epäonnistuu
# parittomilla ja onnistuu parillisilla kerroilla (laskuri casttest.n, siemen 77
# tai annettu --seed). anchortest ja anglertest käynnistävät alaprosessin omaan
# istuntoonsa kuten Godot (sleep 3171 / 3172) ja jäävät jumiin. trolltest ei
# kuole TERMiin (timeout -k pakkolopettaa, koodi 137). FAKE_DELAY=S
# viivästää jokaista testiä, FAKE_STEPS=N tulostaa N riviä 0,1 s:n välein.
# Argumentit kaiutetaan lokiin.
fake="$tmp/fake-godot"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
echo "argumentit: $*"
[ -n "${FAKE_DELAY:-}" ] && sleep "$FAKE_DELAY"
if [ -n "${FAKE_STEPS:-}" ]; then
	for i in $(seq "$FAKE_STEPS"); do echo "rivi $i ${*: -1}"; sleep 0.1; done
fi
case " $* " in
	*" --anchortest "*) setsid sleep 3171 & exec sleep 30 ;;
	*" --anglertest "*) setsid sleep 3172 & exec sleep 30 ;;
	*" --casttest "*)
		cnt="$(dirname "$0")/casttest.n"
		n=$(( $(cat "$cnt" 2>/dev/null || echo 0) + 1 ))
		echo "$n" >"$cnt"
		s=77
		for a in "$@"; do case "$a" in --seed=*) s="${a#--seed=}" ;; esac; done
		echo "Siemen: $s"
		if [ $((n % 2)) -eq 1 ]; then echo "VIRHE heitto $n"; exit 1; fi
		echo "OK   heitto $n"
		exit 0 ;;
	*" --speciestest "*) echo "OK   lajit"; echo "OK   koot"; exit 0 ;;
	*" --luretest "*)
		echo "Siemen: 42 (toista: --seed=42)"
		echo "OK   uistin 1"
		for i in 1 2 3 4 5 6 7; do echo "VIRHE uistin $i syvyys"; done
		exit 1 ;;
	*" --boattest "*) exec sleep 30 ;;
	*" --trolltest "*) trap '' TERM; exec sleep 30 ;;
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
pass_note=""
check() { # check KUVAUS EHTO...
	local desc="$1$pass_note"
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

# Julkaisu A:n tarkistukset; ajetaan kahdesti: sellaisenaan ja -j1-lipulla
# (kriteeri 20). J1 on -j1-kierroksella komennon lopussa näkyvä " -j1".
legacy_checks() {
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
for i in $(seq -w 1 25); do
	for f in "" .rivit.tsv .ajot.tsv .done; do : >"$tmp/.test-logs/20000101-0000$i.log$f"; done
done
run speciestest
check "lokeja säilytetään 20" \
	test "$(find "$tmp/.test-logs" -name '2*.log' | wc -l)" -eq 20
# Jokaisella säilyneellä lokilla on kolme kaveria, poistetuilla ei yhtään.
kept_old="$(find "$tmp/.test-logs" -name '20000101-*.log' | wc -l)"
check "siivous poistaa lokin kaveritiedostot" \
	test "$(find "$tmp/.test-logs" -name '20000101-*.log.*' | wc -l)" -eq $((kept_old * 3))
check "siivous poisti vanhoja lokeja" test "$kept_old" -lt 25
check "oletusajon jälkeen latest.done luettavissa" grep -q '^exit=0 ' "$tmp/.test-logs/latest.done"

# Lokinimi: kaksi ajoa samalla sekunnilla (date pysäytetty) → kaksi lokia.
mkdir -p "$tmp/bin"
real_date="$(command -v date)"
cat >"$tmp/bin/date" <<EOF
#!/usr/bin/env bash
[ "\$1" = "+%Y%m%d-%H%M%S" ] && { echo 20991231-235959; exit 0; }
exec "$real_date" "\$@"
EOF
chmod +x "$tmp/bin/date"
rm -f "$tmp/.test-logs/20991231-235959"*
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
check "lukko: ilmoitus ja PID" has "toinen ajo on käynnissä tässä työkopiossa \(pid=$bgpid alkoi=[0-9:]+ komento=\"-q speciestest$J1\"\)"
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

# Koneluettava yhteenveto: .ajot.tsv ja .rivit.tsv (uusinta pois, ks. uusinnan
# tarkistukset alempana; sarake uusinta PÄÄTÖS 19).
run -q --no-retry luretest speciestest
ajot="$tmp/.test-logs/latest.ajot.tsv"
rivit="$tmp/.test-logs/latest.rivit.tsv"
tab=$'\t'
check "tsv: ajot-otsikko" test "$(head -n 1 "$ajot")" = "testi${tab}ajo${tab}tulos${tab}koodi${tab}kesto_s${tab}siemen${tab}ok_riveja${tab}virhe_riveja${tab}uusinta"
check "tsv: luretest-ajo" grep -qE "^luretest${tab}1${tab}VIRHE${tab}1${tab}[0-9]+${tab}42${tab}1${tab}7${tab}0\$" "$ajot"
check "tsv: speciestest-ajo" grep -qE "^speciestest${tab}1${tab}OK${tab}0${tab}[0-9]+${tab}${tab}2${tab}0${tab}0\$" "$ajot"
check "tsv: rivit-otsikko" test "$(head -n 1 "$rivit")" = "testi${tab}ajo${tab}tila${tab}rivi${tab}luvut${tab}uusinta"
check "tsv: luretestin 8 riviä" test "$(grep -c "^luretest${tab}" "$rivit")" -eq 8
check "tsv: luretest 1 OK" test "$(grep -c "^luretest${tab}1${tab}OK${tab}" "$rivit")" -eq 1
check "tsv: luretest 7 VIRHE" test "$(grep -c "^luretest${tab}1${tab}VIRHE${tab}" "$rivit")" -eq 7
check "tsv: luvut-sarake" grep -qx "luretest${tab}1${tab}VIRHE${tab}uistin 3 syvyys${tab}3${tab}0" "$rivit"
check "tsv: Tarkistusrivit-rivi" has '^Tarkistusrivit: OK 3, VIRHE 7$'
check "tsv: Tarkistusrivit Läpi-rivin alla" \
	test "$(grep -A1 '^Läpi' <<<"$out" | tail -n 1)" = "Tarkistusrivit: OK 3, VIRHE 7"
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "tsv: lokin vieressä" test -f "$tmp/$log.ajot.tsv" -a -f "$tmp/$log.rivit.tsv"
run -q --repeat=3 luretest
check "tsv: --repeat=3 → 3 ajoriviä" test "$(grep -c "^luretest${tab}[1-3]${tab}VIRHE" "$ajot")" -eq 3
check "tsv: luvut miinuksella" bash -c "rm -f '$tmp/docktest.n'; GODOT='$fake' '$runner' -q docktest >/dev/null 2>&1; grep -qx 'docktest${tab}1${tab}OK${tab}jalat x -0.38 (raja -0.50)${tab}-0.38 -0.50${tab}0' '$rivit'"

# Argumenttivihje: Godot väärässä paikassa.
run -q "$fake" speciestest
check "vihje: paluukoodi 2" test $rc -eq 2
check "vihje: tuntematon testi" has "tuntematon testi $fake"
check "vihje: komento oikeassa järjestyksessä" has "^Vihje: Godot annetaan ensimmäisenä argumenttina: tools/run_tests.sh $fake -q speciestest$J1\$"
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
}

J1=""
legacy_checks
# Sama -j1-lipulla: kääre lisää lipun ennen --:ta tai loppuun.
real_runner="$runner"
runner="$tmp/j1-run_tests.sh"
cat >"$runner" <<EOF
#!/usr/bin/env bash
a=()
added=0
for x in "\$@"; do
	if [ \$added -eq 0 ] && [ "\$x" = "--" ]; then a+=(-j1); added=1; fi
	a+=("\$x")
done
[ \$added -eq 1 ] || a+=(-j1)
exec "$real_runner" "\${a[@]}"
EOF
chmod +x "$runner"
J1=" -j1"
pass_note=" (-j1)"
sleep 1 # ensimmäisen ajon lokinimi ilman saman sekunnin päätettä
legacy_checks
runner="$real_runner"
J1=""
pass_note=""

# Uusinta (kriteeri 18): epäonnistunut testi ajetaan heti uudelleen samalla siemenellä.
rm -f "$tmp/casttest.n"
run casttest
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "uusinta: satunnainen paluukoodi 1" test $rc -eq 1
check "uusinta: taulukossa SATUNNAINEN" has '^casttest +SATUNNAINEN +[0-9]+ s$'
check "uusinta: taulukossa ensimmäisen ajon VIRHE-rivi" has '^    VIRHE heitto 1$'
check "uusinta: tulosrivi" has '^>> UUSINTA OK    casttest  [0-9]+ s \(siemen 77\) -> SATUNNAINEN$'
check "uusinta: Satunnaiset-rivi" has '^Satunnaiset: casttest$'
check "uusinta: ei Epäonnistuneet-riviä" lacks '^Epäonnistuneet:'
check "uusinta: ensimmäisen ajon siemen uusinnan argumenteissa" grep -qE '^argumentit: .* --casttest --seed=77$' "$tmp/$log"
check "uusinta: lohko [uusinta] lokissa" grep -q '^::group::casttest \[uusinta\]$' "$tmp/$log"
check "uusinta: valmismerkissä satunnaiset" grep -qE '^exit=1 lapi=0/1 kesto=[0-9]+ loki=[^ ]+ satunnaiset=casttest paattyi=' "$tmp/.test-logs/latest.done"
check "uusinta: ajot.tsv ensimmäinen ajo SATUNNAINEN" grep -qE "^casttest${tab}1${tab}SATUNNAINEN${tab}1${tab}[0-9]+${tab}77${tab}0${tab}1${tab}0\$" "$tmp/.test-logs/latest.ajot.tsv"
check "uusinta: ajot.tsv uusinnan rivi" grep -qE "^casttest${tab}1${tab}OK${tab}0${tab}[0-9]+${tab}77${tab}1${tab}0${tab}1\$" "$tmp/.test-logs/latest.ajot.tsv"
check "uusinta: rivit.tsv molemmat ajot" test "$(grep -cE "^casttest${tab}1${tab}(OK|VIRHE)${tab}heitto [12]${tab}[12]${tab}[01]\$" "$tmp/.test-logs/latest.rivit.tsv")" -eq 2
check "uusinta: rivit.tsv = lokin ajolohkojen OK/VIRHE-rivit" test "$(($(wc -l <"$tmp/.test-logs/latest.rivit.tsv") - 1))" -eq "$(sed -n '/^::group::/,/^::endgroup::/p' "$tmp/$log" | grep -cE '^[[:space:]]*(OK|VIRHE)')"
run -q luretest
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "uusinta: toistuva VIRHE (1)" has '^luretest +VIRHE \(1\) +[0-9]+ s$'
check "uusinta: toistuva tulosrivi" has '^>> UUSINTA VIRHE luretest  [0-9]+ s \(koodi 1, siemen 42\) -> VIRHE$'
check "uusinta: toistuva Epäonnistuneet-rivillä" has '^Epäonnistuneet: luretest$'
check "uusinta: toistuva ei Satunnaiset-riviä" lacks '^Satunnaiset'
check "uusinta: kaksi ajoa lokissa" test "$(grep -c '^::group::luretest' "$tmp/$log")" -eq 2
check "uusinta: siemen 42 uusinnassa" grep -qE '^argumentit: .* --luretest --seed=42$' "$tmp/$log"
check "uusinta: ajot.tsv VIRHE ja uusinta" test "$(grep -cE "^luretest${tab}1${tab}VIRHE${tab}1${tab}" "$tmp/.test-logs/latest.ajot.tsv")" -eq 2
TEST_TIMEOUT=1 run -q boattest
check "uusinta: aikakatkaisua ei uusita" lacks 'UUSINTA'
check "uusinta: aikakatkaisu yksi ajo" test "$(grep -c '^>> ' <<<"$out")" -eq 1
TEST_TIMEOUT=1 run -q trolltest
check "uusinta: TERMiin kuolematon (koodi 137) on AIKAKATKAISU" has '^trolltest +AIKAKATKAISU '
check "uusinta: koodia 137 ei uusita" lacks 'UUSINTA'
check "uusinta: koodi 137 ajot.tsv:ssä" grep -qE "^trolltest${tab}1${tab}AIKAKATKAISU${tab}137${tab}" "$tmp/.test-logs/latest.ajot.tsv"
run -q --no-retry luretest
check "uusinta: --no-retry ei uusi" lacks 'UUSINTA'
run -q --repeat=2 luretest
check "uusinta: --repeat=2 ei uusi" lacks 'UUSINTA'
rm -f "$tmp/casttest.n"
run -q --seed=5 casttest -- --oma=1
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "uusinta: oma --seed pysyy, lisäliput lopussa" test "$(grep -cE '^argumentit: .* --casttest --seed=5 --oma=1$' "$tmp/$log")" -eq 2
rm -f "$tmp/casttest.n"
run -q -- --oma=1 2>/dev/null
rm -f "$tmp/casttest.n"
run -q casttest -- --oma=1
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "uusinta: siemen ennen lisälippuja" grep -qE '^argumentit: .* --casttest --seed=77 --oma=1$' "$tmp/$log"

# Rinnakkaisajo -j N (kriteeri 19).
rm -f "$tmp/.test-logs/kestot.tsv"
run -q speciestest luretest
check "kestot.tsv: -j 1 kirjaa läpi menneen" grep -qE "^speciestest${tab}[0-9]+\$" "$tmp/.test-logs/kestot.tsv"
check "kestot.tsv: epäonnistunutta ei kirjata" bash -c "! grep -q '^luretest' '$tmp/.test-logs/kestot.tsv'"
run -q -j 2 speciestest
check "-j 2 ilman .godot/-kansiota: paluukoodi 2" test $rc -eq 2
check "-j 2 ilman .godot/-kansiota: ilmoitus" has '\.godot/ puuttuu: aja ensin godot --headless --import'
mkdir -p "$tmp/.godot"
start_t=$(date +%s%N)
FAKE_DELAY=2 run -q -j 2 speciestest baittest
el_ms=$(( ($(date +%s%N) - start_t) / 1000000 ))
log="$(sed -n 's/^Loki: //p' <<<"$out")"
check "-j 2: kaksi 2 s:n testiä alle 4 s:ssa ($el_ms ms)" test "$el_ms" -lt 4000
check "-j 2: paluukoodi 0" test $rc -eq 0
check "-j 2: Rinnakkain-rivi" has '^>> Rinnakkain 2 ajoa\.$'
check "-j 2: Läpi-rivillä (rinnakkain 2)" has '^Läpi 2/2, kesto yhteensä 0 min [0-9]+ s \(rinnakkain 2\)$'
check "-j 2: taulukko listan järjestyksessä" \
	test "$(grep -nE '^(baittest|speciestest) ' <<<"$out" | cut -d' ' -f1 | tr '\n' ' ')" = "$(grep -n '^baittest ' <<<"$out" | cut -d' ' -f1) $(grep -n '^speciestest ' <<<"$out" | cut -d' ' -f1) "
check "-j 2: kestot.tsv päivittyy" grep -qE "^baittest${tab}[0-9]+\$" "$tmp/.test-logs/kestot.tsv"
# Rajoitin: neljä 2 s:n testiä kahdella rinnakkaisella kestää vähintään 4 s.
start_t=$(date +%s%N)
FAKE_DELAY=2 run -q -j 2 speciestest baittest sonartest birdtest
el_ms=$(( ($(date +%s%N) - start_t) / 1000000 ))
check "-j 2: enintään kaksi yhtä aikaa (neljä 2 s:n testiä $el_ms ms >= 4000)" test "$el_ms" -ge 4000
check "-j 2: neljä testiä läpi" test $rc -eq 0
# N > ytimet: varoitus ja ytimien määrä (valekomento nproc = 2).
mkdir -p "$tmp/bin-nproc"
printf '#!/bin/sh\necho 2\n' >"$tmp/bin-nproc/nproc"
chmod +x "$tmp/bin-nproc/nproc"
PATH="$tmp/bin-nproc:$PATH" run -q -j 5 speciestest baittest
check "-j 5 kahdella ytimellä: varoitus" has '^>> Varoitus: -j 5 on enemmän kuin ytimiä \(2\), käytetään -j 2\.$'
check "-j 5 kahdella ytimellä: Läpi-rivi (rinnakkain 2)" has '^Läpi 2/2, .*\(rinnakkain 2\)$'
# Lohkot ehjinä: jokaisen ::group::-lohkon rivit ovat sen testin omia.
FAKE_STEPS=10 run -q -j 3 speciestest baittest sonartest
log="$(sed -n 's/^Loki: //p' <<<"$out")"
blocks_ok() {
	awk '
		/^::group::/ { g = substr($0, 10); sub(/ .*/, "", g); inb = 1; nb++; next }
		/^::endgroup::$/ { inb = 0; next }
		/^rivi / { n++; if (!inb || $3 != "--" g) bad++ }
		END { exit !(nb == 3 && n == 30 && bad == 0) }' "$1"
}
check "-j 3: lokin lohkot ehjiä" blocks_ok "$tmp/$log"
FAKE_STEPS=10 run -j 3 speciestest baittest sonartest
check "-j 3 ilman -q:ta: tuloste lohkoina" test "$(grep -c '^::group::' <<<"$out")" -eq 3
run -q -j 0 speciestest
check "-j 0: paluukoodi 2" test $rc -eq 2
run -q -j x speciestest
check "-j x: paluukoodi 2" test $rc -eq 2
run -q --jobs=0 speciestest
check "--jobs=0: paluukoodi 2" test $rc -eq 2
rm -f "$tmp/docktest.n"
run -q -j2 --repeat=3 docktest speciestest
check "-j2 --repeat=3: kolme ajoa testiä kohden" test "$(grep -cE '^>> (OK|VIRHE) +(docktest|speciestest) \[[1-3]/3\]' <<<"$out")" -eq 6
check "-j2 --repeat=3: vaihteluyhteenveto" has '^   3/3   OK 2, VIRHE 1    jalat x -0\.52…-0\.38 \(raja -0\.50\)$'
check "-j2 --repeat=3: taulukko" has '^docktest +1/3 +2 +0 +[0-9]+ s$'
rm -f "$tmp/casttest.n"
run -q -j 2 casttest speciestest
check "-j 2: uusinta rinnakkain" has '^casttest +SATUNNAINEN '

# Aikaraja lopettaa testin alaprosessit (kriteeri 28).
pkill -x -f 'sleep 317[12]' 2>/dev/null
TEST_TIMEOUT=2 run -q anchortest
check "aikaraja: AIKAKATKAISU" has '^anchortest +AIKAKATKAISU '
check "aikaraja: ilmoitus siivotusta prosessista" has '^>> Lopetettiin 1 testin jälkeen jäänyttä prosessia\.$'
sleep 3
check "aikaraja: alaprosessi ei ole elossa" bash -c "! pgrep -x -f 'sleep 3171' >/dev/null"
run -q speciestest
check "aikaraja: ei siivousriviä, kun ei orpoja" lacks 'Lopetettiin'

# Keskeytys lopettaa alaprosessit (kriteeri 29). set -m: muuten taustaprosessi
# perii SIGINTin ohitettuna eikä ajuri voi siepata sitä.
interrupt_check() { # interrupt_check SIGNAALI KUVAUS AJURIN_ARGUMENTIT...
	local sig="$1" desc="$2" p
	shift 2
	pkill -x -f 'sleep 317[12]' 2>/dev/null
	set -m
	GODOT="$fake" "$runner" "$@" >"$tmp/bg.out" 2>&1 &
	bgpid=$!
	set +m
	for _ in $(seq 100); do
		pgrep -x -f 'sleep 3171' >/dev/null && { [ "$*" != "${*/anglertest/}" ] || break; pgrep -x -f 'sleep 3172' >/dev/null && break; }
		sleep 0.1
	done
	t0=$(date +%s%N)
	kill "-$sig" $bgpid
	# Aikaraja 15 s: jumiin jäänyt ajuri (esim. tee orvon alaprosessin putkessa)
	# pakkolopetetaan, jolloin tarkistukset kaatuvat eivätkä jää odottamaan.
	for _ in $(seq 150); do kill -0 $bgpid 2>/dev/null || break; sleep 0.1; done
	hung=0
	if kill -0 $bgpid 2>/dev/null; then
		hung=1
		kill -KILL $bgpid 2>/dev/null
		pkill -x -f 'sleep 317[12]' 2>/dev/null
	fi
	wait $bgpid
	rc=$?
	t_ms=$(( ($(date +%s%N) - t0) / 1000000 ))
	check "$desc: ajuri ei jää jumiin (15 s)" test $hung -eq 0
	check "$desc: paluukoodi 130" test $rc -eq 130
	check "$desc: ajuri päättyy alle 5 s:ssa ($t_ms ms)" test $t_ms -lt 5000
	check "$desc: alaprosessit lopetettu" bash -c "! pgrep -x -f 'sleep 317[12]' >/dev/null"
	check "$desc: ajurilla ei lapsia" bash -c "! pgrep -P $bgpid >/dev/null"
	check "$desc: merkittyjä prosesseja ei ole" bash -c "! grep -lsz '^CATCHFISH_AJO=$bgpid-' /proc/[0-9]*/environ >/dev/null"
	check "$desc: latest.done exit=130" grep -q '^exit=130 keskeytetty' "$tmp/.test-logs/latest.done"
	check "$desc: Keskeytetty-rivi" grep -q '^>> Keskeytetty\.$' "$tmp/bg.out"
	check "$desc: siivottujen määrä" grep -q "^>> Lopetettiin $n_orphans testin jälkeen jäänyttä prosessia\.\$" "$tmp/bg.out"
	run -q speciestest
	check "$desc: lukko vapaa" test $rc -eq 0
}
n_orphans=1
interrupt_check INT "Ctrl+C (INT)" -q anchortest
interrupt_check TERM "TERM" -q anchortest
interrupt_check INT "Ctrl+C ilman -q:ta" anchortest
n_orphans=2
interrupt_check INT "Ctrl+C -j 2" -q -j 2 anchortest anglertest

# --changed (kriteeri 24): väliaikainen git-repo valetiedostoilla.
srcroot="$(dirname "$(dirname "$src")")"
repo="$tmp/repo"
mkdir -p "$repo/tools" "$repo/scripts/boat" "$repo/scripts/fishing" "$repo/tests" "$repo/docs" "$repo/.godot"
cp "$src" "$repo/tools/run_tests.sh"
cp "$srcroot/tools/test_map.txt" "$repo/tools/test_map.txt"
cp "$srcroot/scripts/test_flags.gd" "$repo/scripts/test_flags.gd"
for f in "$srcroot"/tests/*.gd; do : >"$repo/tests/$(basename "$f")"; done
: >"$repo/scripts/boat/boat.gd"
: >"$repo/scripts/fishing/fishing.gd"
printf '.test-logs/\n.godot/\n' >"$repo/.gitignore"
git -C "$repo" init -q
git -C "$repo" -c user.name=t -c user.email=t@t add -A
git -C "$repo" -c user.name=t -c user.email=t@t commit -qm alku
git -C "$repo" update-ref refs/remotes/origin/main HEAD
crun() { # crun ARGUMENTIT...: ajuri väliaikaisessa repossa, muutokset nollataan jälkeenpäin
	out="$(cd "$repo" && GODOT="$fake" TEST_TIMEOUT="${TEST_TIMEOUT:-600}" "$repo/tools/run_tests.sh" "$@" 2>&1)"
	rc=$?
}
creset() {
	git -C "$repo" checkout -q -- .
	git -C "$repo" clean -fdq
}
echo x >>"$repo/tests/lure_test.gd"
crun -q --changed
check "--changed: muutettu testi" has '^>>   tests/lure_test\.gd -> luretest$'
check "--changed: vertailukohta" has '^>> Muutokset verrattuna: origin/main \([0-9a-f]+\), 1 tiedostoa$'
check "--changed: vain luretest ajetaan" test "$(grep -cE '^>> (OK|VIRHE|AIKAKATKAISU) ' <<<"$out")" -eq 1
check "--changed: luretest taulukossa" has '^luretest +VIRHE'
check "--changed: pikatarkistusrivi lopussa" test "$(tail -n 1 <<<"$out")" = ">> Pikatarkistus: koko sarja ajetaan ennen julkaisua."
git -C "$repo" -c user.name=t -c user.email=t@t commit -qam muutos
crun -q --changed
check "--changed: commitoitu muutos mukana" has '^>>   tests/lure_test\.gd -> luretest$'
git -C "$repo" reset -q --hard origin/main
echo x >"$repo/docs/x.md"
crun -q --changed
check "--changed: docs -> ei testejä" has '^>>   docs/x\.md -> ei testejä$'
check "--changed: Ei ajettavia testejä" has '^>> Ei ajettavia testejä\.$'
check "--changed: ei ajettavaa, paluukoodi 0" test $rc -eq 0
check "--changed: ei ajettavaa, ei taulukkoa" lacks '^TESTI '
check "--changed: ei ajettavaa, valmismerkki" grep -qE '^exit=0 lapi=0/0 ' "$repo/.test-logs/latest.done"
creset
echo x >>"$repo/scripts/boat/boat.gd"
TEST_TIMEOUT=1 crun -q -j 4 --changed
check "--changed: kartan testit" has '^>>   scripts/boat/boat\.gd -> anchortest boattest docktest motorspeedtest otherboatstest otherboatstest-talvi proptest$'
check "--changed: kartan testit ajetaan" has '^>> Ajetaan 7 testiä\.$'
creset
echo x >>"$repo/scripts/fishing/fishing.gd"
TEST_TIMEOUT=1 crun -q -j 8 --no-retry --changed
check "--changed: kartaton tiedosto -> kaikki" has '^>>   scripts/fishing/fishing\.gd -> kaikki testit$'
check "--changed: kaikki ajetaan" has "^>> Ajetaan $(grep -c '^	"[a-z-]*|' "$src") testiä\\.\$"
creset
: >"$repo/tests/uusi_shots.gd"
crun -q --changed
check "--changed: jäljittämätön kuvaskripti" has '^>>   tests/uusi_shots\.gd -> ei ajurin listassa \(aja käsin\)$'
creset
echo x >>"$repo/tests/shop_bg_test.gd"
crun -q --changed
check "--changed: MENU-lipun testi" has '^>>   tests/shop_bg_test\.gd -> shopbgtest$'
check "--changed: shopbgtest ajetaan" has '^>> OK +shopbgtest '
creset
echo x >>"$repo/tools/test_map.txt"
crun -q --changed
check "--changed: kartta -> ei pelitestejä" has '^>>   tools/test_map\.txt -> ei pelitestejä$'
check "--changed: kartta -> Aja myös --check" has '^>> Aja myös: tools/run_tests\.sh --check$'
creset
echo x >>"$repo/tools/run_tests_selftest.sh"
crun -q --changed
check "--changed: ajuri -> Aja myös itsetesti" has '^>> Aja myös: tools/run_tests_selftest\.sh$'
creset
: >"$repo/tests/lure_test.gd.uid"
mkdir -p "$repo/export"
: >"$repo/export/x.exe"
crun -q --changed
check "--changed: .gd.uid kuten .gd" has '^>>   tests/lure_test\.gd\.uid -> luretest$'
check "--changed: export -> ei testejä" has '^>>   export/x\.exe -> ei testejä$'
creset
crun -q --changed luretest
check "--changed + testin nimi: paluukoodi 2" test $rc -eq 2
crun -q --changed --scratch=x.gd
check "--changed + --scratch: paluukoodi 2" test $rc -eq 2
crun -q --changed --ref=HEAD
check "--changed + --ref: paluukoodi 2" test $rc -eq 2
crun -q --changed=EIOLE
check "--changed=EIOLE: paluukoodi 2" test $rc -eq 2
check "--changed=EIOLE: ilmoitus" has 'vertailukohta ei ratkea: EIOLE'
crun -q --only-changed
check "--only-changed: paluukoodi 2 (ei aliasta)" test $rc -eq 2
crun -q --changed=HEAD
check "--changed=HEAD: puhdas työkopio" has '^>> Ei ajettavia testejä\.$'
git -C "$repo" update-ref -d refs/remotes/origin/main
crun -q --changed
check "--changed ilman origin/mainia: paluukoodi 2" test $rc -eq 2
check "--changed ilman origin/mainia: ilmoitus" has 'vertailukohta ei ratkea: origin/main'

# --check (kriteeri 25): jokainen tarkistus kaatuu omalla mutaatiollaan.
chk="$tmp/chk"
make_chk() {
	rm -rf "$chk"
	mkdir -p "$chk/tools"
	cp "$src" "$chk/tools/run_tests.sh"
	cp "$srcroot/tools/test_map.txt" "$chk/tools/"
	cp -r "$srcroot/scripts" "$srcroot/tests" "$chk/"
}
cchk() { out="$("$chk/tools/run_tests.sh" --check 2>&1)"; rc=$?; }
make_chk
cchk
check "--check: kopio läpi" test $rc -eq 0
check "--check: Tarkistus läpi" has '^Tarkistus läpi\.$'
check "--check: ei .test-logs-kansiota" test ! -e "$chk/.test-logs"
: >"$chk/tests/x_test.gd"
cchk
check "--check C1: ylimääräinen tests/x_test.gd" has '^VIRHE tests/x_test\.gd ei ole testitaulukossa \(scripts/test_flags\.gd\)$'
check "--check C1: paluukoodi 1" test $rc -eq 1
check "--check C1: virheiden määrä" has '^Tarkistus: 1 virhettä$'
make_chk
sed -i '/"--luretest": "lure_test",/d' "$chk/scripts/test_flags.gd"
cchk
check "--check C1: rivi pois taulukosta" has '^VIRHE tests/lure_test\.gd ei ole testitaulukossa'
make_chk
sed -i 's/^\t"--seedtest": "seed_test",/&\n\t"--uusitest": "uusi_test",/' "$chk/scripts/test_flags.gd"
cchk
check "--check C2: skripti puuttuu" has '^VIRHE --uusitest: skripti tests/uusi_test\.gd puuttuu$'
check "--check C3: ei listassa" has '^VIRHE --uusitest ei ole ajurin listassa eikä not_listed-listassa \(tools/run_tests\.sh\)$'
make_chk
sed -i '/^\t"luretest|/d' "$chk/tools/run_tests.sh"
cchk
check "--check C3: rivi pois ajurin listasta" has '^VIRHE --luretest ei ole ajurin listassa eikä not_listed-listassa'
check "--check C3: paluukoodi 1" test $rc -eq 1
make_chk
sed -i 's/--day=180 --luretest"/--day=180 --luretset"/' "$chk/tools/run_tests.sh"
cchk
check "--check C4: kirjoitusvirhe ajurin rivin lipussa" has '^VIRHE ajurin rivi luretest: ei testilippua argumenteissa$'
make_chk
sed -i 's/^not_listed=(menutest /not_listed=(flickr menutest /' "$chk/tools/run_tests.sh"
cchk
check "--check C5: olematon nimi not_listed-listassa" has '^VIRHE not_listed: flickr ei ole testitaulukossa$'
make_chk
sed -i 's/^not_listed=(menutest /not_listed=(luretest menutest /' "$chk/tools/run_tests.sh"
cchk
check "--check C3: sekä listassa että not_listed" has '^VIRHE --luretest on sekä ajurin listassa että not_listed-listassa'
make_chk
printf 'scripts/boat/bote.gd\tboattest\nscripts/boat/boat.gd\tboattset\nscripts/game_seed.gd seedtest\n' >>"$chk/tools/test_map.txt"
cchk
check "--check C6: olematon polku" has '^VIRHE tools/test_map\.txt:[0-9]+: scripts/boat/bote\.gd ei ole olemassa$'
check "--check C6: olematon testi" has '^VIRHE tools/test_map\.txt:[0-9]+: boattset ei ole ajurin listassa$'
check "--check C6: toistuva polku" has '^VIRHE tools/test_map\.txt:[0-9]+: scripts/boat/boat\.gd toistuu \(myös rivillä [0-9]+\)$'
check "--check C6: rivillä ei sarkainta" has '^VIRHE tools/test_map\.txt:[0-9]+: rivillä ei ole sarkainta'
check "--check C6: paluukoodi 1" test $rc -eq 1
make_chk
out="$("$chk/tools/run_tests.sh" --check luretest 2>&1)"
rc=$?
check "--check + testin nimi: paluukoodi 2" test $rc -eq 2
out="$("$chk/tools/run_tests.sh" -q --check 2>&1)"
rc=$?
check "-q --check: paluukoodi 2" test $rc -eq 2
# Ajon aikana (lukko varattu): --check toimii eikä koske valmismerkkiin.
GODOT="$fake" FAKE_DELAY=3 "$chk/tools/run_tests.sh" -q speciestest >"$tmp/bg.out" 2>&1 &
bgpid=$!
for _ in $(seq 50); do grep -q "pid=$bgpid " "$chk/.test-logs/run.lock" 2>/dev/null && break; sleep 0.1; done
cchk
check "--check ajon aikana: paluukoodi 0" test $rc -eq 0
check "--check ajon aikana: latest.done ennallaan (ei olemassa)" test ! -e "$chk/.test-logs/latest.done"
wait $bgpid
# Oikea työkopio (alkuperäinen polku): CI vahtii testilistoja.
out="$("$src" --check 2>&1)"
rc=$?
check "--check: oikea työkopio läpi" test $rc -eq 0
[ $rc -eq 0 ] || echo "$out"

echo
if [ $failures -gt 0 ]; then
	echo "Itsetesti: $failures virhettä"
	exit 1
fi
echo "Itsetesti läpi."
