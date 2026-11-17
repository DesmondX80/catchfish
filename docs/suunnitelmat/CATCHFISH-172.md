# CATCHFISH-172: Tehokkuus 3/7: Testiajuri – run_tests.sh ja main.gd
v3 klo 08:30 (PÄÄTÖKSET 1–11 viety tekstiin: vain työkopiolukko, `--skipmenu`, fpvtest listaan, julkaisumerkinnät A/B joka kohdassa, ratkaistut kysymykset pois avoimista)

## Tavoite

Testiajurista (`tools/run_tests.sh`) ja pelin testilippujen käsittelystä
(`scripts/main.gd`) poistetaan käsityö ja turha odotus, jotka retroissa
toistuivat:

- toistoajon vaihtelevat rivit lasketaan käsin `uniq -c | awk` -putkella,
- taustalle ajetun sarjan valmistumista ei näe yhdestä paikasta,
- rikkinäinen testiskripti tai väärin kirjoitettu lippu odottaa 600 s aikakatkaisua,
- koko sarja kestää noin 15 min yhdellä ytimellä, vaikka koneessa on 12,
- uusi testi rekisteröidään 98 rivin `elif`-ketjuun.

Pelaajalle ei näy mitään uutta. Kokonaisuus kattaa Planen alitehtävät 168, 98,
106, 136 (kohdat 3 ja 5), 130, 104 ja 97.

### Mikä on jo tehty (ei suunnitella uudelleen)

| Asia | Missä | Tila |
|---|---|---|
| `--repeat=N`, `--ref=REF`, `--log=`, `-q`, yhteenvetotaulukko, `.test-logs/` (20 lokia), `latest.log` | `tools/run_tests.sh:111-165`, `:287-349` (ennen CATCHFISH-160:tä) | valmis |
| `--seed=N`, siemen epäonnistuneen ajon tulosrivillä, `toista:`-rivi toistoajon taulukossa | `tools/run_tests.sh:124`, `:223`, `:251-262`, `:333-341`; `scripts/game_seed.gd` (CATCHFISH-171, 70acb34) | valmis |
| Sään pysäytys testeissä `TestUtil.calm_weather` | `tests/test_util.gd` (CATCHFISH-171) | valmis |
| Ajurin itsetesti valekomennolla, ajetaan CI:ssä | `tools/run_tests_selftest.sh`, `.github/workflows/tests.yml:29` | valmis, laajennetaan |
| Käsin tehtävät korvikkeet (valmismerkki scratchpadiin, `sort \| uniq -c`) | `docs/plan.md:220-242` (CATCHFISH-170) | korvataan tässä; rivit 230 ja 242 viittaavat tähän tehtävään |
| Valikkotestien taulukko (6 lippua) | `scripts/main.gd:42-48` | osittain; yhdistetään kohdassa 97 |

## Käyttö ja tuloste

Uusi käyttörivi (uudet liput merkitty *):

    tools/run_tests.sh [GODOT] [-q] [--repeat=N] [--ref=REF] [--log=TIEDOSTO] [--seed=N]
                       [-j N]* [--no-retry]* [--changed[=REF]]* [--wait]* [--check]*
                       [--scratch=POLKU]* [TESTIN_NIMI...] [-- TESTIN_LISÄLIPUT...]*

Paluukoodit: 0 kaikki läpi, 1 jokin VIRHE, SATUNNAINEN tai AIKAKATKAISU,
2 väärä käyttö, **3 toinen ajo käynnissä samassa työkopiossa** (uusi, julkaisu A), 130 keskeytetty.
`SATUNNAINEN` vasta julkaisussa B.

**Julkaisujako (PÄÄTÖS 3).** Koodaaja toteuttaa nyt vain julkaisun A.
Julkaisu B tehdään A:n julkaisun jälkeen uudessa haarassa.

| Julkaisu | Kohdat | Liput | Kriteerit |
|---|---|---|---|
| **A** | 168a, 168b, 98c, 98d, 98e, 136/5, 130, 104, 97, fpvtest listaan | `--wait`, `--scratch=POLKU`, `-- LISÄLIPUT`; pelissä `--scratchtest=`, `--skipmenu` | 1–17 |
| **B** | 98a, 98b (+ 136/3 muutoskartta, `--check`), 106 | `--no-retry`, `--changed[=REF]`, `--check`, `-j N` | 18–27 |

Julkaisussa A ei toteuteta mitään B:n lipuista; tuntematon lippu antaa
edelleen koodin 2. Tulos `SATUNNAINEN` ja tiedosto `kestot.tsv` kuuluvat B:hen.

Kohdat on numeroitu Planen alitehtävien mukaan. Jokaisessa on nykytila,
toiminta, ja kriteerit ovat osiossa *Hyväksymiskriteerit*.

### 168a: toistoajon vaihtelevat rivit — julkaisu A

**Nykytila.** `--repeat=N` tulostaa testiä kohden rivin läpi/virhe/aikakatkaisu
(`run_tests.sh:304-342`). Rivien vaihtelu katsotaan käsin:
`grep -E '^(OK|VIRHE)' .test-logs/latest.log | sort | uniq -c` (`docs/plan.md:238`).

**Toiminta.** Kun `--repeat` on vähintään 2, taulukon ja `Läpi`-rivin väliin
tulostuu päätteeseen ja lokiin jokaiselle testille vaihtelevien rivien
yhteenveto. Lippua ei tarvita.

- Tarkistusrivi on Godotin tulosteen rivi, joka alkaa (välilyöntien jälkeen)
  `OK` tai `VIRHE`.
- Rivin *malli* saadaan korvaamalla luvut (`[0-9]+([.,][0-9]+)?`, miinus
  etumerkkinä kun sitä edeltää rivin alku, väli, `(` tai `/`) merkillä `#` ja
  jättämällä tila (OK/VIRHE) pois.
- Malli on *vakaa*, jos jokainen täsmälleen sama rivi (tila ja teksti)
  esiintyy jokaisessa N ajossa yhtä monta kertaa. Vakaat rivit eivät tulostu.
- Muista malleista tulostuu rivi: monessako ajossa malli esiintyi, tilojen
  määrät ja teksti, jossa jokaisen vaihtelevan luvun kohdalla on
  `pienin…suurin` (alkuperäisessä kirjoitusasussa) ja muuttumaton luku sellaisenaan.
- Enintään 20 riviä testiä kohden, sen jälkeen `    (+n muuta)`.

Esimerkki (prototyypin todellinen tuloste, `--repeat=6 pressuretest docktest`,
ensimmäinen lohko; toinen lohko synteettisestä syötteestä):

```
Vaihtelevat rivit: pressuretest (6 ajoa)
  AJOJA  TULOS            RIVI (luvut pienin…suurin)
   6/6   OK 6             laskevassa paineessa iskuja enemmän kuin korkeapaineessa (1474…1525 / 1033…1098)
Vaihtelevat rivit: boattest (3 ajoa)
  AJOJA  TULOS            RIVI (luvut pienin…suurin)
   3/3   OK 2, VIRHE 1    jalat x -0.52…-0.38 (raja -0.50)
   1/3   VIRHE 1          vain kerran 1,5–2,5 m
Vaihtelevia rivejä ei ole: docktest (6 ajoa tuottivat samat OK/VIRHE-rivit).
```

Viimeinen rivimuoto tulostuu testille, jolla vaihtelevia rivejä ei ole.
Vaihtelu ei muuta paluukoodia.

Prototyyppi: POSIX-awk (ajettu `gawk --posix`), 60 riviä; syöte
`testi<TAB>ajo<TAB>rivi`. Tarkistettu todellisella lokilla (240 tarkistusriviä,
1 vaihteleva malli) ja synteettisellä syötteellä (tilan vaihtelu, vain osassa
ajoista esiintyvä rivi, negatiiviset luvut, pilkkudesimaalit).

### 168b: valmismerkki `.test-logs/latest.done` — julkaisu A

**Nykytila.** Valmismerkki kirjoitetaan käsin scratchpadiin
(`docs/plan.md:226`). Ajuri ei kirjoita mitään valmistuessaan.

**Toiminta.** Oletuslokilla ajettaessa ajuri

1. poistaa `.test-logs/latest.done`in heti, kun se on saanut lukon (ennen
   ensimmäistä testiä), ja
2. kirjoittaa sen lopuksi jokaisella poistumistiellä, jolla lukko on hallussa
   (valmis, väärä käyttö, keskeytys). Kirjoitus on atominen (väliaikainen
   tiedosto ja `mv`).

Sisältö on yksi rivi, avaimet ASCII:

```
exit=1 lapi=49/50 kesto=912 loki=.test-logs/20261117-081500.log paattyi=08:30:12
exit=2 virhe="tuntematon testi luretst" paattyi=08:15:00
exit=130 keskeytetty paattyi=08:16:40
```

`--log=TIEDOSTO`-ajossa merkki on `TIEDOSTO.done` ja `latest.done`iin ei kosketa.
Jos lukkoa ei saada (koodi 3), merkkiin ei kosketa: se kuuluu käynnissä
olevalle ajolle. `kill -9` ei jätä merkkiä; silloin tila näkyy lukosta
(ks. 98c). Odotus:

    until [ -f .test-logs/latest.done ]; do sleep 5; done; cat .test-logs/latest.done

### 98a: epäonnistuneen uusinta (SATUNNAINEN) — julkaisu B

**Nykytila.** Epäonnistunut testi merkitään `VIRHE (koodi)` eikä sitä ajeta
uudelleen (`run_tests.sh:254-269`). Satunnaisuus selvitetään käsin `--repeat`illa.

**Toiminta.** Kun `--repeat` on 1 ja testi päättyy koodiin, joka ei ole 0
eikä 124 (aikakatkaisu), ajuri ajaa sen heti kerran uudelleen **samalla
siemenellä** (ensimmäisen ajon `Siemen: N` -riviltä; jos riviä ei ole tai
testillä on oma `--seed`, samoilla argumenteilla).

| 1. ajo | Uusinta | Tulos | Paluukoodi |
|---|---|---|---|
| VIRHE | VIRHE | `VIRHE (koodi)` – toistuu siemenellä | 1 |
| VIRHE | OK | `SATUNNAINEN` – ei toistu samalla siemenellä (ajoitus tai siementämätön arvonta) | 1 |
| VIRHE | AIKAKATKAISU | `VIRHE (koodi)` | 1 |
| AIKAKATKAISU | ei uusita (maksaisi toiset 600 s) | `AIKAKATKAISU` | 1 |

```
>> VIRHE         boattest  7 s (koodi 1, siemen 4070231588)
>> UUSINTA OK    boattest  6 s (siemen 4070231588) -> SATUNNAINEN
...
boattest              SATUNNAINEN       7 s
    VIRHE jalat veneen sisällä kalastaessa (x -0.52)
    toista: tools/run_tests.sh --seed=4070231588 --repeat=10 boattest
...
Läpi 49/50, kesto yhteensä 14 min 2 s
Satunnaiset: boattest
```

Taulukossa näkyvät ensimmäisen ajon VIRHE-rivit. `Epäonnistuneet:`-riville
tulevat vain toistuvat, satunnaiset omalle rivilleen. `--no-retry` kytkee
uusinnan pois; `--repeat=N` (N ≥ 2) kytkee sen aina pois. Molempien ajojen
tuloste menee lokiin (`::group::boattest` ja `::group::boattest [uusinta]`).

### 98b ja 136 kohta 3: `--changed` ja muutoskartta — julkaisu B

`--changed` (98) ja `--only-changed` (136) ovat sama asia: aja vain testit,
joihin muutetut tiedostot vaikuttavat. Toteutetaan yksi lippu `--changed`.

**Nykytila.** Ajettavat testit nimetään käsin. Testitiedoston ja testin nimen
yhteys on vain `main.gd`:n ketjussa (`pike_follow_test.gd` ↔ `--piketest`).

**Toiminta (PÄÄTÖS 4: yksi lippu, ei aliasta; PÄÄTÖS 6: karttatiedosto).**
`--changed` laskee muutetut tiedostot: `git diff --name-only
$(git merge-base origin/main HEAD)` (commitoidut ja commitoimattomat) sekä
jäljittämättömät (`git status --porcelain`). `--changed=REF` vaihtaa vertailukohdan.
Jokainen tiedosto käy muutoskartan läpi; ensimmäinen osuva sääntö ratkaisee:

| Tiedosto | Ajettavat testit |
|---|---|
| `docs/**`, `*.md`, `.claude/**`, `.github/**`, `tools/*.py`, `export_presets.cfg`, `.gitignore` | ei testejä |
| `tools/run_tests.sh`, `tools/run_tests_selftest.sh` | ei pelitestejä; rivi `>> Aja myös: tools/run_tests_selftest.sh` |
| `tests/X.gd`, joka on rekisteröity testitaulukkoon (kohta 97) ja jonka lippu on ajurin listassa | sen lipun kaikki listarivit (esim. `linetest` ja `linetest-talvi`) |
| muu `tests/*.gd` paitsi `test_util.gd` (kuvaskriptit, ikkunatestit) | ei testejä; rivi `>> Ei ajurin listassa (aja käsin): tests/water_shots.gd` |
| tiedosto, jolla on rivi muutoskartassa `tools/test_map.txt` | kartan testit (kaikki listarivit, myös `-talvi`) |
| kaikki muu (`scripts/**`, `shaders/**`, `scenes/**`, `assets/**`, `data/**`, `project.godot`, `tests/test_util.gd`) | kaikki testit |

Testitiedoston ja testin yhteys luetaan `scripts/test_flags.gd`:stä (kohta 97:
yksi rivi lippua kohden, muoto `"--piketest": "pike_follow_test",`).

Muutoskartta `tools/test_map.txt` (uusi) kertoo pelikoodin tiedostoille
testit: rivi `polku<TAB>testi testi …`, `#` aloittaa kommentin. Tiedoston
alussa on kommentti: rivit ovat käsin arvioituja, ja `--changed` on
pikatarkistus, joka ei korvaa koko sarjaa (PÄÄTÖS 6). Kartta on
suuntaa antava pikatarkistus (Plane 98: "ensimmäinen palaute tulee nopeasti,
ja koko sarja ajetaan silti ennen pushia"); tiedosto, jota kartassa ei ole,
ajaa kaikki testit. Aloitussisältö: Planen esimerkki (136) ja rivit, joissa
tiedoston ja testin yhteys näkyy nimestä. Rivejä ei ole tarkistettu ajamalla.

```
scripts/boat/boat.gd	boattest docktest proptest otherboatstest anchortest motorspeedtest
scripts/boat/anchor.gd	anchortest boattest
scripts/boat/other_boat.gd	otherboatstest
scripts/boat/other_boat_crew.gd	otherboatstest
scripts/boat/other_boats.gd	otherboatstest
scripts/boat/tackle_box.gd	tackletest
scripts/boat/catch_tub.gd	tubtest
scripts/boat/wake.gd	waketest
scripts/boat/angler.gd	anglertest
scripts/fishing/fishing_line.gd	linetest
scripts/fishing/gill_net.gd	nettest
scripts/fishing/nets.gd	nettest
scripts/fishing/net_control.gd	nettest
scripts/ui/echo_sounder.gd	sonartest
scripts/ui/fish_book_view.gd	booktest
scripts/fish_book.gd	booktest
scripts/world/birds.gd	birdtest birdsoundtest
scripts/audio/angler_voice.gd	voicetest
scripts/game_seed.gd	seedtest
```

Kaikki muut `scripts/`-tiedostot (mm. `fishing.gd`, `weather.gd`, `waves.gd`,
`hud.gd`, `main.gd`) ajavat kaikki testit, koska niiden vaikutusta ei voi
rajata nimestä. `--check` varmistaa, että kartan polut ja testien nimet ovat
olemassa.

```
$ tools/run_tests.sh -q --changed
>> Muutokset verrattuna: origin/main (b40085e), 3 tiedostoa
>>   tests/line_test.gd -> linetest linetest-talvi
>>   docs/plan.md -> ei testejä
>>   tests/water_shots.gd -> ei ajurin listassa (aja käsin)
>> Ajetaan 2 testiä.
```

Jos ajettavaa ei ole: `>> Ei ajettavia testejä.`, koodi 0, taulukkoa ei
tulosteta. `--changed` ja nimetyt testit yhdessä: väärä käyttö (koodi 2).
`--changed` on koodaajan pikatarkistus; koko sarjan ajaa edelleen testaaja ja
työnjohtaja. Tuloste päättyy riviin `>> Pikatarkistus: koko sarja ajetaan
ennen julkaisua.`

`--check` (uusi, ei aja testejä, ei tarvitse Godotia): tarkistaa, että
(1) jokainen `tests/*_test.gd` on testitaulukossa ja (2) jokainen taulukon
`--…test`-lippu on joko ajurin listassa tai ajurin uudessa poissulkulistassa
`not_listed` (ikkunaa vaativat ja käsin ajettavat: inputtest, pausetest,
menutest, settingstest, careertest, timepicktest, tvtest, autotest, perftest,
flicker). Puute tulostuu rivinä `VIRHE …` ja koodi on 1. `--check` ajetaan
itsetestin lopussa oikeaa työkopiota vasten, joten CI vahtii sitä.

Löydös: `--fpvtest` (`main.gd:325`, `docs/plan.md:169`) puuttuu ajurin
listasta, vaikka se menee ikkunatta läpi (15 OK-riviä, 6 s, ajettu
b40085e:llä). **Julkaisu A** lisää sen listaan aakkosjärjestykseen:
`"fpvtest|--fixed-fps 30 -- --day=180 --fpvtest"` (PÄÄTÖS 8).

### 98c: yksi sarja kerrallaan (lukko) — julkaisu A

**Nykytila.** Lukkoa ei ole. Kaksi ajoa samassa työkopiossa kirjoittavat
samaan `latest.log`-linkkiin.

**Toiminta (PÄÄTÖS 1: vain työkopiokohtainen lukko).** Jokainen ajo ottaa
lukon `.test-logs/run.lock` (`flock`, ei odota). Lukkotiedostoon kirjoitetaan
`pid=… alkoi=HH:MM:SS komento="…"`. Jos lukko on varattu:

```
run_tests.sh: toinen ajo on käynnissä tässä työkopiossa (pid=41237 alkoi=08:15:02 komento="-q").
Odota: until [ -f .test-logs/latest.done ]; do sleep 5; done   tai aja lipulla --wait
```

ja koodi on 3; lokiin, `latest.log`iin ja `latest.done`iin ei kosketa.
`--wait` jää odottamaan lukkoa ja tulostaa saman tiedon rivillä, joka alkaa
`>> Odotetaan:`. Lukko vapautuu prosessin päättyessä (myös `kill -9`), joten
vanhentunutta lukkoa ei siivota. Jos `flock`-komentoa ei ole, ajuri varoittaa
(`>> Varoitus: flock puuttuu, ajetaan ilman lukkoa`) ja jatkaa. Lukko koskee
myös `--ref`- ja `--log`-ajoja.

Konelukkoa ei tehdä: eri työkopioiden ajot kulkevat rinnakkain. Tämä poikkeaa
tietoisesti Planen 98:n sanasta "koneella" (PÄÄTÖS 1). Konekohtainen lisälukko
`-j`-ajoille (N ≥ 2) lisätään julkaisussa B vain, jos kriteerin 22 ajoissa
näkyy kuormasta johtuvia aikakatkaisuja.

### 98d: argumenttivihje — julkaisu A

**Nykytila.** Godot tunnistetaan vain ensimmäisestä argumentista
(`run_tests.sh:94-100`). `tools/run_tests.sh -q godot-4.7.2 luretest` antaa
`tuntematon testi godot-4.7.2` ja käyttörivin (`:128`) ilman selitystä.

**Toiminta.** Jos tuntematon nimi on ohjelma (`*/*` tai löytyy `PATH`ista,
sama ehto kuin rivillä 97) tai sen nimessä on `godot`, ilmoituksen alle tulee vihje:

```
run_tests.sh: tuntematon testi godot-4.7.2
Vihje: Godot annetaan ensimmäisenä argumenttina: tools/run_tests.sh godot-4.7.2 -q luretest
```

Vihjeen komento on käyttäjän oma komento oikeassa järjestyksessä. Koodi 2
kuten nyt. Muita nimiehdotuksia ei tehdä (Plane 98 pyytää vain tämän).

### 98e: lokinimen törmäys — julkaisu A

**Nykytila.** Lokin nimi on sekunnin tarkkuudella (`run_tests.sh:160`), ja
`: >"$log"` (`:163`) tyhjentää saman sekunnin aiemman lokin. Itsetesti kiertää
tämän (`run_tests_selftest.sh:144-145`).

**Toiminta.** Jos `AAAAKKPP-HHMMSS[-ref].log` on jo olemassa, nimeen lisätään
`-2`, `-3`, … ennen `.log`-päätettä (luonti `set -o noclobber`illa, jolloin
kaksi prosessia ei saa samaa nimeä). Siivouksen lauseke
(`^[0-9]{8}-[0-9]{6}.*\.log$`) kattaa uudet nimet. Itsetestin kiertotie
poistetaan ja tilalle tulee tarkistus: kaksi peräkkäistä ajoa samalla
sekunnilla tuottaa kaksi eri lokia.

### 106: rinnakkaisajo `-j N` — julkaisu B

**Nykytila.** Testit ajetaan peräkkäin (`run_tests.sh:219-271`). Koko sarja
noin 15 min, josta otherboatstest yksin 4–6 min.

**Toiminta.** `-j N` (myös `-jN` ja `--jobs=N`; N positiivinen kokonaisluku,
oletus 1 = nykyinen käytös) ajaa enintään N Godot-prosessia yhtä aikaa.

- Ajot (testi × toisto) laitetaan jonoon pisimmästä lyhimpään edellisen ajon
  kestojen mukaan (`.test-logs/kestot.tsv`, `nimi<TAB>sekunnit`, päivitetään
  jokaisen läpi menneen ajon jälkeen). Testi, jolla ei ole kestoa, ajetaan
  ensimmäisten joukossa. Näin otherboatstest ei jää viimeiseksi yksin.
- Jokainen ajo kirjoittaa tulosteensa omaan väliaikaistiedostoonsa. Kun ajo
  valmistuu, pääprosessi lisää sen lokiin kokonaisena `::group::`-lohkona ja
  tulostaa tulosrivin `>>`. Loki ja `>>`-rivit ovat siis
  valmistumisjärjestyksessä, mutta lohkot eivät sekoitu keskenään.
- Ilman `-q`:ta Godotin tuloste tulee päätteeseen lohkona ajon valmistuttua
  (ei rivi kerrallaan).
- Yhteenvetotaulukko on aina listan järjestyksessä, kuten nyt.
- KESTO on ajon oma seinäkelloaika kuormitettuna; `kesto yhteensä` on koko
  ajon seinäkelloaika.
- Uusinta (98a) ajetaan saman ajon paikalla heti.
- Ctrl+C lopettaa kaikki lapsiprosessit.
- Jos N on suurempi kuin `nproc`, ajuri varoittaa ja käyttää `nproc`ia.
- `-j 1`:n tuloste on rivilleen sama kuin nykyinen (itsetestin nykyiset
  tarkistukset menevät läpi muuttamatta).

```
$ tools/run_tests.sh -q -j 4
>> Rinnakkain 4 ajoa.
>> OK            shopbgtest  1 s
>> OK            booktest  6 s
...
Läpi 50/50, kesto yhteensä 4 min 40 s (rinnakkain 4)
```

**Prototyyppi** (12 testin osajoukko: boat, dock, anchor, motorspeed, sonar,
pressure, species, seasonfish, book, shopbg, lure, cast; `--seed=7`, WSL,
12 ydintä):

| | Seinäkello | Tarkistusrivit verrattuna peräkkäisajoon |
|---|---|---|
| peräkkäin | 122 s | 267 riviä (vertailukohta) |
| 4 rinnakkain | 60 s | 267/267 samat, kaikki koodi 0 |
| 6 rinnakkain | 54 s | 267/267 samat, kaikki koodi 0 |

Yksi testi käyttää yhden ytimen kokonaan (user ≈ real) ja muistia 328–331 Mt
(shopbgtest 200 Mt). Yksittäinen testi hidastui rinnakkain 1,1–1,6-kertaiseksi
(anchortest 16,9 → 23,0 s neljällä, 26,9 s kuudella). Osajoukon kestoa
rajoitti pisin testi (luretest 34 s). Koko sarjan kestoa ei ole mitattu
(designer ei aja koko sarjaa); arvio neljällä 4–6 min, alarajana
otherboatstestin kesto kuormitettuna.

**Riskit ja kannanotot**

| Riski | Arvio | Ratkaisu |
|---|---|---|
| Ikkuna- ja GPU-testit | Eivät ole ajurin listassa (`run_tests.sh:18-19`), joten `-j` ei koske niitä. | Ei muutosta. Ikkuna-ajot edelleen yksi kerrallaan; GPU-lukko on CATCHFISH-174. |
| `user://`-tallennukset | Testiajossa `persist = false` kaikissa neljässä autoloadissa (`catch_log.gd:17`, `settings.gd:88`, `career.gd:57`, `fish_book.gd:30`), joten testit eivät kirjoita. Lukeminen rinnakkain on vaaratonta. | Ei muutosta. booktest tarkistaa jo `not FishBook.persist` ja `not CatchLog.persist`. |
| Godotin oma loki `user://logs/godot.log` | Jokainen prosessi kierrättää lokeja; rinnakkain kierrätys voi kilpailla. Prototyypissä ei virheitä (24 rinnakkaista ajoa). | Hyväksytään; jos virheitä ilmenee, ajuri antaa Godotille `--log-file` omaan väliaikaistiedostoon. Ei prototyypattu. |
| `.test-logs/` | Yksi kirjoittaja (pääprosessi) lokiin; ajot kirjoittavat vain omiin väliaikaistiedostoihinsa. Lukko estää toisen ajurin. | Rakenne yllä. |
| `.godot/`-tuontivälimuisti | Pelin ajo ei kirjoita sinne; tuonti tehdään ennen ajoa (`--ref`issä ajuri itse, `run_tests.sh:208`). | Jos `.godot/` puuttuu työkopiosta, ajuri lopettaa: `aja ensin godot --headless --import` (koodi 2). |
| Siemenet | Jokainen prosessi arpoo oman siemenensä (`GameSeed.setup`), `--seed=N` välittyy kaikille. Siemen luetaan ajon omasta tulosteesta, joten `toista:`-rivit pysyvät oikeina. | Ei muutosta. |
| Ilman `--fixed-fps`-lippua ajettavat testit (booktest, pressuretest, seasonfishtest, shopbgtest, speciestest) | Ruudun pituus riippuu kuormasta. Prototyypissä näiden rivit pysyivät samoina 4 ja 6 rinnakkain. | Koko sarjan vertailu on hyväksymiskriteeri 22. |
| Seinäkelloon sidotut testit | `grep get_ticks tests/*_test.gd`: vain settingstest (ikkunatesti, ei listassa). | Ei muutosta. |
| Aikakatkaisu kuormassa | 600 s testiä kohden; otherboatstest 4–6 min × 1,6 voi lähestyä rajaa. | Varoitus kun N > `nproc`; suositus N = 4. Jos kriteerin 22 ajossa jokin testi ylittää 400 s, palataan asiaan ennen julkaisua. |
| Muisti | 330 Mt/prosessi; WSL:ssä 6 Gt, vapaana noin 3 Gt. N = 4 → 1,3 Gt, N = 8 → 2,6 Gt. | Suositus N = 4 dokumentteihin; ei kovaa rajaa. |
| Kaksi agenttia eri työkopioissa, kumpikin `-j 4` | 8 prosessia, 2,6 Gt: mahtuu, mutta kolmas ei. Konelukkoa ei ole (PÄÄTÖS 1). | Jos kriteerin 22 tai 23 ajoissa näkyy kuormasta johtuvia aikakatkaisuja, julkaisuun B lisätään konekohtainen lukko `-j`-ajoille (N ≥ 2). |

### 136 kohta 5: koneluettava tarkistusriviyhteenveto — julkaisu A

**Nykytila.** Plane: "koneluettava yhteenveto testien tarkistusriveistä (nimi,
arvo, raja), jotta raporttien luvut saadaan suoraan lokista". Testit
tulostavat vapaamuotoisia rivejä (`OK   köysi ei venynyt (yli 0.06 m)`), joissa
nimi, arvo ja raja ovat samassa tekstissä; yhteistä `_check`-funktiota ei ole
(jokaisessa testissä oma). Luvut poimitaan raportteihin käsin.

**Toiminta.** Ajuri kirjoittaa jokaisesta ajosta kaksi sarkaineroteltua
tiedostoa lokin viereen (`--log=X` → `X.rivit.tsv`, `X.ajot.tsv`) ja linkit
`.test-logs/latest.rivit.tsv` ja `.test-logs/latest.ajot.tsv`:

`latest.rivit.tsv`, rivi tarkistusriviä kohden:

```
testi	ajo	tila	rivi	luvut
pressuretest	1	OK	laskevassa paineessa iskuja enemmän kuin korkeapaineessa (1474 / 1045)	1474 1045
anchortest	1	VIRHE	köysi ei venynyt (yli 0.06 m)	0.06
```

`rivi` on tarkistusrivin teksti ilman tilaa, `luvut` rivin luvut
järjestyksessä välilyönnein (sama lukujen tunnistus kuin 168a:ssa). Arvoa ja
rajaa ei eroteta toisistaan, koska testien rivit eivät kerro, kumpi luku on
kumpi (yhteinen `TestUtil.check` on Backlogissa, PÄÄTÖS 9).

`latest.ajot.tsv`, rivi ajoa kohden:

```
testi	ajo	tulos	koodi	kesto_s	siemen	ok_riveja	virhe_riveja
boattest	1	OK	0	7	4070231588	41	0
luretest	1	VIRHE	1	34	42	1	7
```

`tulos` on OK, VIRHE, AIKAKATKAISU tai PUUTTUU (julkaisussa B lisäksi
SATUNNAINEN; uusinta-ajo ei saa omaa riviä). Muoto: PÄÄTÖS 9. Lisäksi yhteenvetoon tulee `Läpi`-rivin alle rivi

    Tarkistusrivit: OK 1873, VIRHE 0

Taulukon sarakkeita ei muuteta. `.tsv`-tiedostot siivotaan lokien mukana
(sama 20 viimeisintä). Esimerkkikäyttö raporttiin:
`awk -F'\t' '$1=="boattest" && $3=="OK"' .test-logs/latest.rivit.tsv | wc -l`.

### 130: `--scratchtest=POLKU` ja osa-ajo — julkaisu A

**Nykytila.** Kertakäyttöinen kokeiluskripti vaatii rivin `main.gd`:n ketjuun
tai SceneTree-käynnistysskriptin, joka ei pääse autoloadeihin
(`docs/plan.md:284-287`).

**Toiminta.** `--scratchtest=POLKU` käynnistää pelin kuten testit (valikko
ohitetaan, `persist = false`) ja lisää `Main`in lapseksi annetun skriptin
(`extends Node`). Polku on `res://…` tai levyn absoluuttinen polku, joten
kokeilu voi olla scratchpadissa eikä likaa työkopiota.

    timeout 590 godot-4.7.2 --headless --fixed-fps 30 -- --day=180 --scratchtest=/tmp/…/scratchpad/koe.gd

`--scratchtest` voittaa muut testiliput. Skripti lopettaa itse
(`get_tree().quit(koodi)`). Latausvirhe: kuten 104.

Prototyyppi: `res://tests/scratch_x.gd` ja absoluuttinen scratchpad-polku
toimivat molemmat (koodi 0, 6,2 s, skripti näki `main.boat`in ja
`main.sky.day_of_year`in); puuttuva tiedosto → `VIRHE testiskripti ei
lataudu: res://tests/eiole.gd`, koodi 1, 5,4 s.

Ajurissa `--scratch=POLKU` ajaa skriptin kuin listan testin nimellä
`scratchtest` (argumentit `--fixed-fps 30 -- --day=180 --scratchtest=POLKU`),
jolloin loki, aikaraja, `--repeat`, vaihteluyhteenveto ja `--seed` toimivat
myös tilapäiselle testille. Suhteellinen polku muutetaan absoluuttiseksi.
`--scratch` ja nimetyt testit voi antaa yhdessä.

**Osa-ajo.** Plane (130): "run_tests.sh:lle tapa ajaa yksittäisen testin
osa"; muotoa ei ole määritelty. Testit ovat peräkkäisiä skriptejä, eikä
yhdessäkään listan testissä ole nyt osiolippua. Ajuriin tulee läpivienti:
`--`-erottimen jälkeiset argumentit lisätään jokaisen valitun testin
argumenttien loppuun.

    tools/run_tests.sh -q otherboatstest -- --otherboatstest-part=collisions
    tools/run_tests.sh -q anchortest -- --audio-log

Läpivienti vaatii vähintään yhden nimetyn testin tai `--scratch`in (muuten
koodi 2), ja tulosrivillä näkyy `(lisäliput: …)`. Testien omat osioliput
(esim. `--otherboatstest-part`, Plane 136 kohta 1) kuuluvat CATCHFISH-175:een;
tämä tehtävä tekee vain ajurin puolen (PÄÄTÖS 10).

### 104: testiskriptin latausvirhe → koodi 1 heti — julkaisu A

**Nykytila.** `add_child(load("res://tests/x.gd").new())` (`main.gd:260-380`).
Jäsennysvirheessä `load` palauttaa skriptin, jota ei voi instantioida, `new`
kaatuu, testisolmua ei synny ja peli jää pyörimään. Prototyyppi: rikottu
`species_test.gd` → `SCRIPT ERROR: Parse Error`, `Nonexistent function 'new'`,
ajo päättyi vasta aikarajaan (koodi 124). CATCHFISH-171:n PÄÄTÖS 9 kirjasi saman.

**Toiminta.** Lataus kulkee yhden funktion kautta, joka tarkistaa, että
tiedosto on olemassa, `load` palauttaa `GDScript`in ja `can_instantiate()` on
tosi. Muuten tulostuu

    VIRHE testiskripti ei lataudu: res://tests/species_test.gd

ja peli lopettaa koodilla 1. Koskee pelitestejä, kuvaskriptejä, valikkotestejä
ja scratch-testiä. Prototyyppi: sama rikottu skripti → koodi 1, 5,3 s.
Ajurissa tämä näkyy tavallisena `VIRHE (1)` -rivinä ja VIRHE-rivi taulukossa.

Rajaus: testin *ajonaikainen* virhe (esim. null-viittaus `_ready`ssä) jättää
testin edelleen roikkumaan aikarajaan asti. Sitä ei ratkaista tässä (ks.
*Havainnot tehtävän ulkopuolelta*).

### 97: testilippujen taulukko `elif`-ketjun tilalle — julkaisu A

**Nykytila.**

- `main.gd:42-48`: valikkotestien sanakirja (6 lippua, `begins_with`).
- `main.gd:49`: mikä tahansa `--`-alkuinen argumentti paitsi `--audio-log` ja
  `--seed=` ohittaa valikon.
- `main.gd:258-348`: 45 `elif "--x" in args` -haaraa (tarkka lippu).
- `main.gd:349-380`: 15 kuvaskriptiä `begins_with("--xshots=")`; ensimmäinen
  (`--seasonshot=`) on `if`, loput `if/elif`, joten `--seasonshot=` ja toinen
  kuvalippu latautuisivat molemmat. Yhdistelmää ei ole dokumentoitu
  (`README.md`, `docs/plan.md`, `tests/season_shot.gd`).

**Toiminta.** Uusi `scripts/test_flags.gd` (`class_name TestFlags`, ei
autoload, staattiset funktiot kuten `GameSeed`) sisältää kolme taulukkoa
nykyisessä järjestyksessä, yksi lippu rivillä:

- `MENU` (etuliite, valikko näkyy): nykyiset 6.
- `GAME` (tarkka lippu, peli käynnistyy): nykyiset 45, `--autotest` ensin.
- `SHOTS` (etuliite `--x=`, peli käynnistyy): nykyiset 15, `--seasonshot=` ensin.

Säännöt:

- Ensimmäinen osuma taulukon järjestyksessä voittaa, järjestys
  `--scratchtest=` → `GAME` → `SHOTS`. Sama kuin nyt, paitsi että
  `--seasonshot=` yhdessä toisen kuvalipun kanssa lataa vain
  `season_shot.gd`:n.
- Valikon ohitus käyttää samaa taulukkoa (Plane 97): valikko ohitetaan vain,
  kun argumenteissa on `GAME`- tai `SHOTS`-taulukon lippu tai
  `--scratchtest=`. Nykyinen ehto "mikä tahansa `--`-alkuinen paitsi
  `--audio-log` ja `--seed=`" (`main.gd:49`) poistuu. Muutos: pelkkä apulippu
  (`-- --day=40`, `-- --waterquality=matala`) ei enää ohita valikkoa.
  Dokumentoitua käyttöä tälle ei ole (`grep` `README.md`, `docs/plan.md`,
  `tests/`: ei komentoa, jossa olisi vain apulippuja).
- Uusi lippu `--skipmenu` (PÄÄTÖS 11) ohittaa valikon ilman testiä ja
  käynnistää pelin aloituspaikasta 0 kuten testit:
  `godot -- --day=40 --skipmenu`. Lippu on tarkka (`arg == "--skipmenu"`), ei
  lataa testiskriptiä ja yhdistyy apulippuihin. Koska autoloadit asettavat
  `persist = false` mille tahansa `--`-lipulle, `--skipmenu`-ajo ei lue eikä
  kirjoita pelaajan tallennuksia eikä asetuksia (sama kuin testiajoissa;
  kirjataan `README.md`:hen). Testilipun kanssa `--skipmenu` on tarpeeton
  mutta sallittu.
- Tuntematon testilippu (designerin lisäys, ei Planessa; ilman tätä väärin
  kirjoitettu lippu jäisi valikkoon aikarajaan asti): argumentti, joka on muotoa `--<kirjaimia>test` (ei
  `=`-osaa eikä muuta päätettä) eikä ole `GAME`ssa tai `MENU`ssa, tulostaa
  `VIRHE tuntematon testilippu --luretst` ja lopettaa koodilla 1. Jos lippu on
  `MENU`n etuliite ilman `=`-merkkiä (`--menutest`), vihje on
  `--menutest vaatii kansion: --menutest=KANSIO`. Apuliput (`--day=`,
  `--anchortest-shots=`, `--perftest-lines`, `--bookshots=`, `--short` ym.)
  eivät osu muotoon ja toimivat kuten nyt.
- Uusi testi rekisteröidään yhdellä rivillä `TestFlags.GAME`iin (ja ajurin
  listaan).

`main.gd` lyhenee noin 110 riviä (prototyypissä 508 → 396, `test_flags.gd` 94
riviä). Prototyypillä ajettu boattest (`--seed=5`, koodi 0), scratch-testi ja
latausvirhe.

Ei muuteta: neljän autoloadin omat `--`-silmukat (`catch_log.gd:16`,
`settings.gd:77`, `career.gd:55`, `fish_book.gd:28`) ja testien omat
apulippujen luvut.

## Ulkoasu ja äänet

Ei muutoksia peliin, ei kuvia. Pääteulostulon muodot ovat osiossa *Käyttö ja
tuloste*; designer vertaa toteutuksen tulosteen niihin.

## Toteutus pääpiirteissään

### (a) Riippuvuudet ja toteutusjärjestys

```
97 taulukko ──┬─> 104 latausvirhe (sama latausfunktio)
              ├─> 130 scratch-testi (sama latausfunktio)
              ├─> tuntematon testilippu
              └─> 98b --changed ja --check (lukevat test_flags.gd:n)
98c lukko ────┬─> 168b latest.done (merkin omistaa lukon haltija)
              └─> 106 -j N (yksi ajuri työkopiota kohden)
ajokohtaiset tulostetiedostot ─┬─> 168a vaihtelevat rivit
                               ├─> 136/5 .tsv
                               ├─> 98a uusinta
                               └─> 106 -j N
98d vihje, 98e lokinimi, 130 läpivienti: riippumattomia
```

- Lukko ja `-j N` eivät ole sama asia: lukko rajaa *ajureita* (yksi
  työkopiota kohden, PÄÄTÖS 1), `-j` rajaa *Godot-prosesseja* yhden ajurin
  sisällä. `-j` tarvitsee työkopiolukon (yksi kirjoittaja lokiin), lukko ei
  `-j`:tä.
- `--changed` (98) ja `--only-changed` (136) ovat sama asia; muutoskartta
  (136/3) on `--changed`in sisältö.

Järjestys (jokainen askel on oma commit ja itsetesti menee läpi sen jälkeen):

Julkaisu A (askeleet 1–4 ja 8):

1. `scripts/test_flags.gd` + `main.gd` (97, 104, 130, `--skipmenu`,
   tuntematon testilippu); fpvtest ajurin listaan.
2. Ajurin ajosilmukka: jokaisen ajon tuloste omaan tiedostoonsa ja tulokset
   yhteen taulukkoon (ei näkyvää muutosta; pohja 168a:lle, 136/5:lle, 98a:lle ja 106:lle).
3. 98c lukko, 168b `latest.done`, 98e lokinimi.
4. 168a vaihtelevat rivit, 136/5 `.tsv`-tiedostot ja `Tarkistusrivit`-rivi,
   98d vihje, 130 `--scratch` ja läpivienti.

Julkaisu B (askeleet 5–8, uusi haara A:n julkaisun jälkeen):

5. 98a uusinta.
6. 106 `-j N` ja `kestot.tsv`.
7. 98b `--changed` ja `--check`.
8. Dokumentit (kummassakin julkaisussa omansa).

### (c) Julkaisut: kaksi julkaisua (PÄÄTÖS 3)

- **Julkaisu A (askeleet 1–4 ja niiden dokumentit):** taulukko, latausvirhe,
  scratch-testi ja läpivienti, `--skipmenu`, työkopiolukko, valmismerkki,
  lokinimi, vaihtelevat rivit, `.tsv`-tiedostot, vihje, fpvtest listaan.
- **Julkaisu B (askeleet 5–7):** uusinta, `-j N`, `--changed`, `--check`.

Perustelut:

1. A sisältää ainoan pelikoodin muutoksen (`main.gd`), joka vaatii koko
   sarjan ja kuvaskriptien savutestin. Se kannattaa saada mainiin erikseen
   pienenä, koska jokainen rinnakkainen haara koskee samaan ketjuun
   lisätessään testin (yhdistämisristiriidat).
2. A:n ajurimuutokset lisäävät tulostetta mutta eivät muuta ajojärjestystä.
   B kirjoittaa ajosilmukan uusiksi (taustaprosessit, uusinta), ja sen
   hyväksyntä vaatii koko sarjan ajon rinnakkain ja vertailun peräkkäisajoon.
   Jos B palautuu, A:n hyödyt (retron pyytämä vaihteluyhteenveto ja
   valmismerkki) ovat jo käytössä.
3. B:n testaus nopeutuu A:n työkaluilla (`latest.done`, `.tsv`, vaihtelevat rivit).
4. Yhtenä julkaisuna muutos olisi noin 600–800 riviä bashia ja itsetestiä
   yhdessä katselmoinnissa; palautuskierrosten raja (2) tulisi helposti vastaan.

Molemmat ovat patch-versioita (PÄÄTÖS 3).

### Tiedostot

- `scripts/test_flags.gd` (uusi): taulukot, `skips_menu(args)` (tosi myös
  lipulla `--skipmenu`),
  `unknown_test_flag(args)`, `find(args)` (palauttaa polun tai tyhjän),
  `instantiate(path)` (tarkistukset, VIRHE-rivi, `null`).
- `scripts/main.gd`: `_ready` (rivit 40-53) ja `_start_game`n loppu (rivit
  258-380) käyttävät `TestFlags`ia. Tuntemattoman testilipun tarkistus
  `_ready`ssä ennen valikkoa ja pelin rakentamista. Latausvirheessä
  `get_tree().quit(1)`.
- `tools/run_tests.sh`: yllä kuvatut liput. Vaihteluyhteenveto upotettuna
  POSIX-awk-skriptinä (CI:n `awk` voi olla mawk: ei `gensub`ia, ei
  `match`in taulukkomuotoa). `-j` käyttää bashin `wait -n`:ää (bash 4.3+);
  rinnakkaisajossa `timeout` ilman `--foreground`-lippua ja keskeytyksessä
  lapsiprosessit lopetetaan `trap`issa.
- `tools/run_tests_selftest.sh`: uudet tarkistukset (alla). Valekomentoon
  lisätään: testi, jonka luku vaihtelee ajosta toiseen (laskuri tiedostossa),
  testi, joka epäonnistuu ensimmäisellä ja onnistuu toisella kerralla, ja
  ympäristömuuttujalla säädettävä viive.
- `.github/workflows/tests.yml`: ei muutosta kummassakaan julkaisussa (PÄÄTÖS 5).
- Dokumentit (koodaaja, PÄÄTÖS 7): `README.md` (testiosio, rivit 289-305;
  lisäksi `--skipmenu` ja `--scratchtest`) ja `docs/plan.md` *Testaus*
  (käyttörivi 131, testilistaan `--fpvtest` ajurin testinä ja
  `--scratchtest`, *Pitkät ajot* 220-230, *Toistoajot* 232-242: "tulossa
  (CATCHFISH-172)" -maininnat pois ja käsin tehdyt putket korvataan uusilla).
  F1-ohje ennallaan.
- `CLAUDE.md` ja `.claude/agents/*.md`: **koodaaja ei koske** (PÄÄTÖS 7).
  Työnjohtaja päivittää ne julkaisun yhteydessä: valmismerkki, lukon koodi 3,
  `koodaaja.md:29` (uusi testi rekisteröidään `scripts/test_flags.gd`:hen),
  "itsetesti kahdesti peräkkäin ennen pushia" (Plane 98; ei ole ohjeissa nyt)
  ja julkaisussa B `-j 4`.

### Headless ja ikkunan koko

Ikkunan kokoa ei pakoteta. Mikään muutos ei koske ikkunatestien sisältöä.

### Muutokseen liittyvät nykyiset testit

`tools/run_tests_selftest.sh` (kaikki nykyiset tarkistukset pysyvät).
`main.gd`:n muutos koskee jokaista testiä: kaikki ajurin listan testit,
ikkunatestit settingstest, menutest, careertest, timepicktest, tvtest,
inputtest ja pausetest sekä kuvaskriptit (savutesti: yksi `GAME`-, yksi
`SHOTS`- ja yksi `MENU`-lippu ikkunassa). seedtest (siemenen ja valikon
ohituksen suhde).

### Sivuvaikutuslista

| Muutettu asia | Käyttäjät (grep) | Tarkistettu |
|---|---|---|
| `main.gd`:n testiketju | 45 pelitestiä, 15 kuvaskriptiä, 6 valikkotestiä; `comm` tiedostolistan ja ketjun välillä: kaikki `tests/*.gd` paitsi `test_util.gd` ovat ketjussa | tarkistettu (prototyyppi generoi taulukon ketjusta: 45 + 15) |
| Valikon ohitus `main.gd:49` → vain taulukon liput | `--audio-log`, `--seed=` jäävät valikkoon kuten nyt (`docs/plan.md:212`); pelkkä apulippu ei enää ohita valikkoa; `_start_game`n `other_boats.auto_spawn` (`main.gd:252`) käyttää `CatchLog.persist`iä, ei muutu | tarkistettu grepillä; autoloadien `persist = false` kaikille `--`-lipuille ei muutu |
| `--seasonshot=` + toinen kuvalippu | ei dokumentoitua käyttöä (`README.md`, `docs/plan.md`, `tests/season_shot.gd:2`) | tarkistettu grepillä; käytös muuttuu, kirjattu yllä |
| Tuntematon `--…test` → koodi 1 | apuliput (`grep cmdline_user_args scripts tests`): `--perftest-lines`, `--x-shots=`, `--bookshots=`, `--birdshots=`, `--watershots-only=`, `--watershots-scale=`, `--anglershots-only=`, `--jitter-hz=`, `--start=`, `--mouse`, `--short`, `--spot=reeds`, `--waterquality=`, `--day=`: mikään ei ole muotoa `--<kirjaimia>test` | tarkistettu |
| `other_boats.auto_spawn` (`main.gd:251-253`) lukee `--perftest` ja `--autotest` suoraan | ei muutu | tarkistettu |
| `class_name TestFlags` vientiin | `GameSeed` ja `TestUtil` ovat jo samanlaisia; vienti vie kaiken | tarkistettu (CATCHFISH-171) |
| `run_tests.sh`:n tuloste | itsetesti, CI (`tests.yml:51`), `README.md`, `docs/plan.md`, `CLAUDE.md`, agenttiohjeet; työnjohtajan vahti lukee `Läpi n/m` -riviä | tarkistettu: `Läpi`-rivin alku ei muutu (`-j`:llä loppuun lisätään `(rinnakkain N)`) |
| Uusi paluukoodi 3 | CI ajaa yhden ajurin kerrallaan; agenttien komennot | tarkistettu: ei vaikuta CI:hin |
| `.test-logs/`:n uudet tiedostot (`latest.done`, `run.lock`, `*.tsv`, `kestot.tsv`) | `.gitignore:21` kattaa hakemiston; lokien siivous `run_tests.sh:158` | tarkistettu; siivous laajennetaan `.tsv`:hen |
| `--ref`-ajo | REF:n vanha `main.gd` (ei taulukkoa) ja vanha testilista | ei tarkistettu ajamalla: kriteeri 14 |
| Godotin `user://logs` rinnakkain | ks. riskitaulukko | osin: 24 rinnakkaista ajoa ilman virheitä |

### Havainnot tehtävän ulkopuolelta (ei toteuteta, ehdotus Backlogiin)

- Testin ajonaikainen skriptivirhe jättää ajon roikkumaan 600 s. Ajuri voisi
  merkitä `SCRIPT ERROR` -rivit, tai testeille yhteinen vahtiajastin.
- Neljä autoloadia asettaa `persist = false` mille tahansa `--`-argumentille,
  myös `--seed=`ille ja `--audio-log`ille, joilla `main.gd:49` jättää valikon
  näkyviin: pelaaja, joka pelaa lipulla `--seed=N`, ei saa tallennuksia.
  Yhtenäistäminen `TestFlags.skips_menu`in kanssa muuttaisi pelin käytöstä.

## Hyväksymiskriteerit

Komennot ajetaan työkopion juuressa. "Itsetesti" = `tools/run_tests_selftest.sh`
(ei vaadi Godotia); jokaiselle itsetestikriteerille tulee nimetty `check`-rivi.

Prototyypattu on vain se, missä lukee prototyypin tulos: kriteerit 3 ja 4
(latausvirhe, scratch-testi pelissä), 8 (awk-yhteenveto) ja osin 22
(12 testin osajoukko). Kaikki muut kriteerit on merkitty "ei prototyypattu":
niiden toimivuutta ei ole kokeiltu, ja testaaja todentaa ne ensimmäisenä.

### Julkaisu A (kriteerit 1–17, toteutetaan nyt)

1. [ ] **Taulukko.** `grep -c 'elif "--' scripts/main.gd` on 0 ja
   `grep -c 'res://tests/' scripts/main.gd` on 0; `scripts/test_flags.gd`:ssä
   on 45 `GAME`-, 15 `SHOTS`- ja 6 `MENU`-riviä, yksi lippu rivillä.
   (Prototyypissä taulukko generoitiin ketjusta: 45 + 15.)
2. [ ] **Kaikki listan testit läpi.** `tools/run_tests.sh -q` → koodi 0,
   jokainen ajurin listan testi OK (testaaja, taustalle valmismerkillä).
   Ei prototyypattu (designer ei aja koko sarjaa).
2b. [ ] **fpvtest listassa (PÄÄTÖS 8).** `tools/run_tests.sh -q --repeat=10 fpvtest`
   → 10/10 ja `Vaihtelevia rivejä ei ole` tai vaihtelevat rivit kirjattuna
   raporttiin. Yksi ajo prototyypattu (15 OK, 6 s); toisto ei prototyypattu.
3. [ ] **Latausvirhe.** Tilapäisessä työkopiossa (mutaatioresepti)
   `tests/species_test.gd`:hen lisätään rivi `var slant := [][0]` ennen
   `_ready`ä: `timeout 590 godot-4.7.2 --headless -- --speciestest` päättyy
   alle 30 sekunnissa koodilla 1 ja tulosteessa on
   `VIRHE testiskripti ei lataudu: res://tests/species_test.gd`
   (prototyyppi: 5,3 s). `tools/run_tests.sh -q speciestest` → `VIRHE (1)`,
   sama rivi taulukossa. Sama `origin/main`issa päättyy aikakatkaisuun.
4. [ ] **Scratch-testi.** Skripti, joka tulostaa `OK   scratch` ja kutsuu
   `get_tree().quit(0)`, ajetaan sekä polulla `res://tests/…` että
   scratchpadin absoluuttisella polulla: koodi 0 ja rivi tulosteessa
   (prototyyppi: 6,2 s). `--scratchtest=res://tests/eiole.gd` → koodi 1 ja
   `VIRHE testiskripti ei lataudu`.
5. [ ] **Tuntematon testilippu.** `timeout 60 godot-4.7.2 --headless -- --day=180 --luretst`
   → koodi 1 alle 30 s, rivi `VIRHE tuntematon testilippu --luretst`.
   `-- --menutest` → koodi 1 ja vihje `--menutest=KANSIO`.
   `-- --day=180 --perftest-lines --luretest` ajaa luretestin normaalisti. Ei prototyypattu.
6. [ ] **Valikon ohitus taulukosta.** seedtest läpi; `timeout 20 godot-4.7.2 --headless -- --seed=5`,
   `-- --audio-log` ja `-- --day=40` jäävät valikkoon (päättyvät aikarajaan
   124 ilman VIRHE-riviä; tarkistus lisätään seedtestin tai uuden pienen
   testin kautta niin, ettei se nojaa aikarajaan: `TestFlags.skips_menu`
   palauttaa epätoden listoille `["--seed=5"]`, `["--audio-log"]`,
   `["--day=40"]` ja toden listoille `["--day=40", "--luretest"]`,
   `["--boatshots=x"]`, `["--scratchtest=x"]`, `["--skipmenu"]`). Ei prototyypattu.
6b. [ ] **`--skipmenu` (PÄÄTÖS 11).** `timeout 60 godot-4.7.2 --headless --fixed-fps 30 -- --day=40 --skipmenu --scratchtest=POLKU`
   ei kelpaa todisteeksi (scratch ohittaa valikon itse), joten: uusi pieni
   headless-testi tai seedtestin lisätarkistus varmistaa `skips_menu`n
   (kriteeri 6), ja käsin ikkunassa `godot-4.7.2 -- --day=40 --skipmenu`
   avaa pelin suoraan talvimaisemaan ilman valikkoa ja `godot-4.7.2 -- --day=40`
   avaa valikon (testaaja näytönohjaimella, yksi kuvakaappaus kummastakin
   riittää). `README.md`:ssä on rivi `--skipmenu`ista ja maininta, ettei ajo
   käytä tallennuksia. Ei prototyypattu.
7. [ ] **Ikkunatestit ja kuvaskriptit.** Näytönohjaimella settingstest
   (`docs/plan.md:195`) läpi, `--menutest=KANSIO` tuottaa kuvansa ja yksi
   kuvaskripti (`--boatshots=KANSIO`) tuottaa kuvansa. Kuvia ei verrata
   sisällöltään; kriteeri on, että skriptit latautuvat. Ei prototyypattu.
8. [ ] **Vaihtelevat rivit** (itsetesti): valekomennon vaihteleva testi
   `--repeat=3` → lohko `Vaihtelevat rivit: NIMI (3 ajoa)`, rivillä
   `pienin…suurin` oikeilla arvoilla; OK/VIRHE-vaihtelu näkyy muodossa
   `OK 2, VIRHE 1`; vain yhdessä ajossa esiintyvä rivi `1/3`; vakaalle
   testille `Vaihtelevia rivejä ei ole: NIMI`; `--repeat=1` ei tulosta
   lohkoa. Lisäksi oikealla pelillä: `tools/run_tests.sh -q --repeat=6 pressuretest`
   tulostaa rivin `laskevassa paineessa iskuja enemmän kuin korkeapaineessa (a…b / c…d)`
   (prototyyppi: 1474…1525 / 1033…1098) ja `--seed=7 --repeat=3 docktest`
   rivin `Vaihtelevia rivejä ei ole`.
9. [ ] **Valmismerkki** (itsetesti): onnistuneen ajon jälkeen `latest.done`
   alkaa `exit=0 lapi=1/1`; epäonnistuneen `exit=1`; tuntemattoman testin
   `exit=2`; ajon aikana (valekomennon viive) tiedostoa ei ole; `--log=X` →
   `X.done` eikä `latest.done` muutu. Ei prototyypattu.
10. [ ] **Lukko (PÄÄTÖS 1)** (itsetesti): kun viivästetty ajo on käynnissä
    taustalla, toinen ajo samassa hakemistossa palauttaa koodin 3, tulostaa
    `toinen ajo on käynnissä` ja PID:n, eikä `latest.log` tai `latest.done`
    muutu; `--wait` odottaa ja päättyy koodilla 0; taustaprosessin
    `kill -9`:n jälkeen uusi ajo käynnistyy. Kaksi eri hakemistoa (kaksi
    itsetestin väliaikaiskopiota) ajaa yhtä aikaa ilman koodia 3.
    Ei prototyypattu.
11. [ ] **Lokinimi** (itsetesti): kaksi ajoa saman sekunnin aikana tuottaa
    kaksi eri lokia (`…-2.log`), kumpikin sisältää oman `Läpi`-rivinsä;
    "lokeja säilytetään 20" menee läpi ilman rivien 144-145 kiertotietä.
    Ei prototyypattu.
12. [ ] **Koneluettava yhteenveto** (itsetesti): `latest.ajot.tsv`:ssä
    otsikkorivi ja rivi ajoa kohden; valekomennon luretest → `VIRHE	1	…	42	1	7`;
    `--repeat=3` → 3 riviä testiä kohden. `latest.rivit.tsv`:ssä valekomennon
    luretestistä 8 riviä (1 OK, 7 VIRHE), sarakkeessa `luvut` rivin luvut;
    päätteessä `Tarkistusrivit: OK n, VIRHE m`. Oikealla pelillä:
    `tools/run_tests.sh -q boattest` jälkeen `latest.rivit.tsv`:n rivimäärä
    (ilman otsikkoa) on sama kuin `grep -cE '^\s*(OK|VIRHE)' .test-logs/latest.log`.
    Ei prototyypattu.
13. [ ] **Argumenttivihje** (itsetesti): `run_tests.sh -q VALEGODOT speciestest`
    → koodi 2, `tuntematon testi …` ja rivi `Vihje: Godot annetaan
    ensimmäisenä argumenttina: tools/run_tests.sh VALEGODOT -q speciestest`;
    `eiolemassa` → ei vihjettä (nykyinen tarkistus ennallaan). Ei prototyypattu.
13b. [ ] **`--scratch` ja läpivienti** (itsetesti): `--scratch=x.gd` →
    valekomennon argumenteissa `--scratchtest=/abs/…/x.gd`, taulukossa
    `scratchtest`; `speciestest -- --oma=1` → argumenttien lopussa `--oma=1`
    ja tulosrivillä `(lisäliput: --oma=1)`; `-- --oma=1` ilman testiä → koodi 2.
    Ei prototyypattu.
14. [ ] **`--ref` ennallaan.** `tools/run_tests.sh -q --ref=origin/main speciestest`
    → koodi 0, otsikossa `(origin/main @ …)`. Ei prototyypattu.
15. [ ] **Nykyinen tuloste ennallaan.** Itsetestin kaikki nykyiset
    tarkistukset (b40085e:n `run_tests_selftest.sh`) menevät läpi muuttamatta,
    paitsi rivien 144-145 kiertotie. `tools/run_tests_selftest.sh` → `Itsetesti läpi.`
    myös komennolla `PATH`issa `awk` = `mawk`, jos se on asennettu (CI ajaa itsetestin joka tapauksessa).
    Itsetesti ajetaan kahdesti peräkkäin (Plane 98: ajoitusoletukset). Awk
    prototyypattu `gawk --posix`illa, ei mawkilla.
16. [ ] **Mutaatiot** (muoto kirjataan *Päätöksiin*): (a) `TestFlags.instantiate`n
    `can_instantiate`-tarkistus pois → kriteerin 3 ajo päättyy aikakatkaisuun;
    (b) vaihteluyhteenvedon vakausehto aina tosi → itsetestin kriteerin 8
    tarkistus kaatuu; (c) lukon otto pois → kriteerin 10 tarkistus kaatuu.
    Ei prototyypattu.
17. [ ] **Dokumentit (PÄÄTÖS 7: koodaaja vain `README.md` ja `docs/plan.md`).**
    `grep -n 'tulossa (CATCHFISH-172)' docs/plan.md` on tyhjä; `README.md` ja
    `docs/plan.md` kuvaavat `latest.done`in, vaihteluyhteenvedon, lukon
    (koodi 3), `.tsv`-tiedostot, `--scratchtest`in, `--scratch`in,
    läpiviennin ja `--skipmenu`in. `git diff origin/main --stat -- CLAUDE.md .claude`
    on tyhjä koodaajan luovuttamassa commitissa.

### Julkaisu B (kriteerit 18–27, ei toteuteta tässä haarassa)

18. [ ] **Uusinta** (itsetesti): valekomennon testi, joka epäonnistuu
    ensimmäisellä ja onnistuu toisella kerralla → taulukossa `SATUNNAINEN`,
    rivi `Satunnaiset: NIMI`, koodi 1, uusinnan argumenteissa ensimmäisen
    ajon siemen (`--seed=42`); aina epäonnistuva → `VIRHE (1)` ja kaksi ajoa
    lokissa; aikakatkaisua ei uusita; `--no-retry` ja `--repeat=2` eivät
    uusi; `.tsv`:ssä `SATUNNAINEN` (PÄÄTÖS 2). Ei prototyypattu.
19. [ ] **`-j` perusasiat** (itsetesti): `-j 2` kahdella viivästetyllä
    testillä (viive 2 s) valmistuu alle 4 sekunnissa; taulukko listan
    järjestyksessä; lokissa jokainen `::group::`–`::endgroup::`-lohko ehjä
    (lohkojen välissä ei toisen testin rivejä); `-j 0` ja `-j x` → koodi 2;
    `-j 2 --repeat=3` → 3 ajoa testiä kohden ja vaihteluyhteenveto;
    `Läpi`-rivillä `(rinnakkain 2)`. Ei prototyypattu (prototyyppi ajoi
    rinnakkain `xargs -P`:llä, ei ajurin omalla toteutuksella).
20. [ ] **`-j 1` = nykyinen.** Itsetestin kaikki aiemmat tarkistukset menevät
    läpi myös, kun ajuria kutsutaan lipulla `-j 1`. Ei prototyypattu.
21. [ ] **Keskeytys.** `tools/run_tests.sh -q -j 4 & sleep 20; kill -INT %1; sleep 3; pgrep -f 'godot.*--headless'`
    on tyhjä ja `latest.done` alkaa `exit=130`. Ei prototyypattu.
22. [ ] **Koko sarja rinnakkain = peräkkäin.** `tools/run_tests.sh -q --seed=7`
    ja `tools/run_tests.sh -q --seed=7 -j 4`: kummassakin kaikki listan testit
    OK, ja jokaisen testin OK/VIRHE-rivit ovat samat (vertailu lokeista
    lohkoittain; skripti testaajan scratchpadiin). Kirjataan molempien
    seinäkelloaika ja `-j 4` -ajon pisin yksittäinen testi. Tavoite: `-j 4`
    alle puolet peräkkäisajon kestosta (prototyyppi 12 testillä: 60 s vs.
    122 s; koko sarjalla ei prototyypattu). Jos jonkin testin kesto ylittää
    400 s, asia palaa työnjohtajalle ennen hyväksyntää.
23. [ ] **Toisto rinnakkain.** `tools/run_tests.sh -q -j 4 --repeat=3` (koko
    sarja, satunnainen siemen) → kaikki läpi; mahdolliset SATUNNAINEN- tai
    VIRHE-tulokset kirjataan siemenineen. Kuormasta johtuvat aikakatkaisut
    kriteereissä 22–23 laukaisevat PÄÄTÖKSEN 1 konelukon. Ei prototyypattu.
24. [ ] **`--changed`** (itsetesti, tilapäinen git-repo valetiedostoilla):
    muutettu `tests/lure_test.gd` → ajetaan vain luretest; muutettu
    `docs/x.md` → `Ei ajettavia testejä.`, koodi 0; muutettu
    `scripts/boat/boat.gd` → kartan kuusi testiä; muutettu
    `scripts/fishing/fishing.gd` (ei kartassa) → kaikki; jäljittämätön `tests/uusi_shots.gd` →
    `ei ajurin listassa`; `--changed luretest` → koodi 2; `--changed=EIOLE` → koodi 2;
    `--only-changed` → koodi 2 (ei aliasta, PÄÄTÖS 4). Ei prototyypattu.
25. [ ] **`--check`.** `tools/run_tests.sh --check` → koodi 0 työkopiossa;
    kun `scripts/test_flags.gd`:stä poistetaan yksi `GAME`-rivi tai ajurin
    listasta yksi testi (tilapäisessä kopiossa), koodi 1 ja puute nimetty;
    samoin kun `tools/test_map.txt`:ssä on olematon polku tai testin nimi.
    Itsetesti ajaa `--check`in lopuksi. Ei prototyypattu.
26. [ ] **Mutaatiot:** (a) uusinnan siemenen välitys pois → kriteerin 18
    tarkistus kaatuu; (b) `-j`:n lohkokirjoitus suoraan lokiin taustaprosessista
    (ei pääprosessin kautta) tai rajoitin pois → kriteerin 19 tarkistus kaatuu.
    Ei prototyypattu.
27. [ ] **Dokumentit.** `README.md`, `docs/plan.md` (*Testaus*, *Pitkät ajot*)
    kuvaavat `-j N`:n (suositus 4), uusinnan, `--changed`in ja `--check`in.

## Avoimet kysymykset Teemulle

Ei avoimia kysymyksiä. Teemun linjaukset: PÄÄTÖS 1 (lukko), PÄÄTÖS 2
(SATUNNAINEN), PÄÄTÖS 3 (julkaisut) ja PÄÄTÖS 11 (`--skipmenu`).

## Avoimet kysymykset työnjohtajalle

Ei avoimia kysymyksiä. v2:n kysymykset on ratkaistu:

| Kysymys (v2) | Ratkaisu |
|---|---|
| L1 `--changed` = `--only-changed` | PÄÄTÖS 4 |
| L2 lukon laajuus | PÄÄTÖS 1 |
| L3 `-j`:n oletus ja CI | PÄÄTÖS 5 |
| L4 muutoskartta | PÄÄTÖS 6 |
| L5 ohjetiedostot | PÄÄTÖS 7 |
| L6 fpvtest listaan | PÄÄTÖS 8 |
| L7 SATUNNAINEN | PÄÄTÖS 2 |
| L8 julkaisujen määrä | PÄÄTÖS 3 |
| L9 koneluettava muoto | PÄÄTÖS 9 |
| L10 osa-ajo | PÄÄTÖS 10 |
| L11 valikon ohitus | PÄÄTÖS 11 |

## Päätökset

PÄÄTÖS 1: Lukko on vain työkopiokohtainen (L2 = C). Teemun linjaus 17.11.2026.
Konelukkoa ei tehdä julkaisussa A. Konekohtainen lisälukko `-j`-ajoille (N ≥ 2)
lisätään julkaisussa B vain, jos kriteerin 22 ajoissa näkyy kuormasta johtuvia
aikakatkaisuja. Perustelu: prototyypissä 4 ja 6 rinnakkaista ajoa antoivat samat
tarkistusrivit (267/267), eikä koodaajan pikatestin pidä odottaa toisen
työkopion sarjaa. Poikkeaa tietoisesti Planen 98:n sanasta "koneella".

PÄÄTÖS 2: SATUNNAINEN → paluukoodi 1, uusinta samalla siemenellä (L7 = A).
Teemun linjaus 17.11.2026.

PÄÄTÖS 3: Kaksi julkaisua (L8). Teemun linjaus 17.11.2026. Julkaisu A:
kriteerit 1–17, julkaisu B: kriteerit 18–27. Molemmat patch-versioita. B
tehdään A:n julkaisun jälkeen uudessa haarassa ja työkopiossa origin/mainista.

PÄÄTÖS 4: Yksi lippu `--changed[=REF]`, ei `--only-changed`-aliasta (L1 = A).
Työnjohtaja.

PÄÄTÖS 5: `-j`:n oletus on 1 kaikkialla, CI ennallaan, `-j 4` dokumentoitu
suositus paikallisesti (L3 = A). CI:n rinnakkaisajo viedään Backlogiin omana
tehtävänään. Työnjohtaja.

PÄÄTÖS 6: Muutoskartta `tools/test_map.txt` aloitussisällöllä, kartaton
tiedosto ajaa kaikki testit (L4 = A). Kuuluu julkaisuun B. Karttatiedoston
alkuun kommentti, että rivit ovat käsin arvioituja ja että `--changed` on
pikatarkistus, joka ei korvaa koko sarjaa. Työnjohtaja.

PÄÄTÖS 7: `CLAUDE.md` ja `.claude/agents/*.md` päivittää työnjohtaja
julkaisun yhteydessä (L5 = B), mukaan lukien "itsetesti kahdesti ennen
pushia". Koodaaja päivittää vain `README.md`:n ja `docs/plan.md`:n.

PÄÄTÖS 8: fpvtest lisätään ajurin listaan julkaisussa A, testaaja ajaa
`--repeat=10` (L6 = A). Työnjohtaja.

PÄÄTÖS 9: Koneluettava yhteenveto on TSV ilman testimuutoksia (L9 = A).
Yhteinen `TestUtil.check(nimi, arvo, raja, ok)` viedään Backlogiin. Työnjohtaja.

PÄÄTÖS 10: Osa-ajo on ajurin läpivienti `NIMI -- LISÄLIPUT` (L10 = A). Testien
omat osioliput kuuluvat CATCHFISH-175:een. Työnjohtaja.

PÄÄTÖS 11: Valikon ohittavat vain taulukon testi- ja kuvaliput sekä uusi lippu
`--skipmenu` (L11 = B). Teemun linjaus 17.11.2026. Pelkkä apulippu
(`godot -- --day=40`) avaa valikon; `godot -- --day=40 --skipmenu` käynnistää
pelin suoraan. `--skipmenu` dokumentoidaan `README.md`:hen ja saa oman
hyväksymiskriteerinsä julkaisussa A.

PÄÄTÖS 12: Tuntematon testilippu (kohta 97, kriteeri 5): virhe on mikä tahansa
paljas `--<kirjaimia>`-argumentti (ei `=`-osaa, ei väliviivaa), joka ei ole
`GAME`- tai `MENU`-lippu, `--skipmenu` eikä `TestFlags`in apulippulistassa
(nyt `--mouse` ja `--short`). Korvaa kohdan 97 säännön "muotoa
`--<kirjaimia>test`", koska se ei osunut kriteerin 5 esimerkkiin `--luretst`
(koodaajan koe: aikakatkaisu 124). Uusi paljas apulippu rekisteröidään
apulippulistaan; tämä kirjataan `docs/plan.md`:hen. Työnjohtaja, koodaajan
vaihtoehto B.

PÄÄTÖS 13: Jos komennossa on sekä `MENU`-lippu että `GAME`- tai `SHOTS`-lippu,
`MENU`-lippu voittaa (valikko ja valikkotesti), kuten vanhassa koodissa, jossa
valikkotarkistus oli ensin. Työnjohtaja.

PÄÄTÖS 14: `--skipmenu`-ajo ei lue eikä kirjoita tallennuksia eikä asetuksia,
kuten muutkin `--`-lipulla käynnistetyt ajot (autoloadien `persist = false`).
Autoloadeihin ei kosketa. `README.md`:ssä mainitaan tämä. Teemun linjaus
17.11.2026.
Tarkennus (koodaaja): CatchLog lukee ennätyslistan testiajossakin (`catch_log.gd:19`), mutta ei tallenna; README ja plan.md kertovat tämän.

PÄÄTÖS 15: Ajokohtaiset tiedostot nimetään lokin mukaan (`LOKI.rivit.tsv`,
`LOKI.ajot.tsv`, `LOKI.done`), ja oletusajossa `.test-logs/latest.done`,
`latest.rivit.tsv` ja `latest.ajot.tsv` ovat olemassa (linkki tai tiedosto).
`--log=X`-ajossa vain `X.*`, `latest.*`-nimiin ei kosketa. Lokien siivous (20
viimeisintä) poistaa myös lokin kaveritiedostot. Väärä käyttö: koodi 2,
valmismerkki vain, jos lukko on vapaana. `--ref` + `--scratch`: PUUTTUU, jos
REF:ssä ei ole `scripts/test_flags.gd`:tä. Lisäliput näkyvät `toista:`-rivillä.
Vaihtelulohko taulukon ja viivarivin väliin, `Tarkistusrivit` heti `Läpi`-rivin
alle. Työnjohtaja, koodaajan tulkinnat.

PÄÄTÖS 16: Kriteerin 16 mutaatioiden muodot (koodaaja). (a) Pelkän
`can_instantiate`-ehdon poisto ei ole viallinen käytös: `instantiate` tarkistaa
myös `node != null` ja `main.gd:_add_test` tuloksen `null`in, joten ajo päättyi
silti koodiin 1 (5 s). Mutaatio on siksi `_add_test`in palautus vanhaan muotoon
`add_child(load(path).new())` (kaikki tarkistukset pois, kuten `origin/main`):
kriteerin 3 rikottu `species_test.gd` → `timeout 60 godot-4.7.2 --headless --
--speciestest` päättyi koodiin 124 (60 s). Aikaraja 60 s eikä 590 s, koska
mutatoimaton ajo päättyy 5 sekunnissa. (b) Vaihteluyhteenvedossa ennen riviä
`if (stable) continue` asetetaan `stable = 1` → itsetestissä 17 VIRHE-riviä
(kaikki vaihtelutarkistukset kolmella awkilla). (c) `if ! flock -n 9; then` →
`if false; then` → 7 VIRHE-riviä (lukko ja `--wait`). Lisäksi (d) lukon
tiedostokuvaajan sulku `9>&-` pois Godot-ajosta → `lukko: kill -9:n jälkeen uusi
ajo käynnistyy` kaatuu. Mutaatiot ajettiin väliaikaiskopioissa scratchpadissa.

PÄÄTÖS 17: Palautus 1: main.gd:n tuntemattoman lipun ja MENU-etusijan kytkennät
testataan alaprosessiajolla seedtestissä (testaajan mutantit W1 ja W2).
Toteutus (koodaaja): seedtest käynnistää kaksi alaprosessia rinnakkain
(`OS.execute_with_pipe`, `--headless --path <projekti> -- …`, tuloste putkeen,
aikaraja 40 s ja `OS.kill`): `--day=180 --luretst` → koodi 1 ja rivi
`VIRHE tuntematon testilippu --luretst`; `--day=180 --luretest --shopbgtest` →
shopbgtestin rivi `kuvatiedosto on olemassa` ilman aikakatkaisua. Mutantit:
W1 (`main.gd`: `if unknown != "":` → `if false:`) → seedtest koodi 1, 48 s;
W2 (valikkotestin tarkistus `skips_menu`n jälkeen) → seedtest koodi 1, 47 s.
`main.gd`:hen ei koskettu. Seedtestin kesto kasvoi noin 5 s → 9 s.
