# CATCHFISH-183: Tehokkuus 3b/7: Testiajuri, julkaisu B – uusinta, -j N, --changed, --check
v1 klo 15:20

Täydentävä suunnitelma. Pohja on CATCHFISH-172:n hyväksytty suunnitelma
(`docs/suunnitelmat/CATCHFISH-172.md`, mainissa), jonka julkaisu B -osiot,
kriteerit 18–27 ja päätökset 172/PÄÄTÖS 1–18 pätevät sellaisinaan, ellei tässä
toisin sanota. Tämä tiedosto kertoo vain, mikä julkaisu A:n (v0.57.3,
1c56302) jälkeen muuttui, mitä lisätään ja mitä on vielä linjattava.

Viittaukset: "172/98a" = 172:n osio *98a*, "172/K19" = 172:n kriteeri 19,
"172/PÄÄTÖS 5" = 172:n päätös 5. Rivinumerot ovat tämän haaran
(`origin/main` 1c56302) tiedostoista.

## Tavoite

Julkaisu B (172/PÄÄTÖS 3): epäonnistuneen testin uusinta samalla siemenellä
(172/98a), rinnakkaisajo `-j N` (172/106), muutettujen tiedostojen testit
`--changed[=REF]` ja muutoskartta (172/98b), testilistojen tarkistus `--check`.
Lisäksi uusi kohta: ajurin pitää lopettaa testin koko prosessipuu, myös
testin itse käynnistämät alaprosessit (testaajan löydös julkaisusta A).

Pelaajalle ei näy mitään uutta.

## Käyttö ja tuloste

Käyttörivi, paluukoodit ja tulosteet: 172 *Käyttö ja tuloste* sekä osiot
172/98a, 172/98b ja 172/106. Alla vain muutokset ja täydennykset.

### Mikä muuttui julkaisu A:ssa (vaikutus B:n kuvaukseen)

| 172:n kohta | Nykytila mainissa | Mitä B:n kuvauksessa pitää huomioida |
|---|---|---|
| 172/98a *Nykytila* (`run_tests.sh:254-269`) | Ajosilmukka on nyt `run_tests.sh:521-587`. Jokaisen ajon tuloste on omassa tiedostossaan `$run_dir/N.out` (`:547`), tulokset taulukoissa `r_name`, `r_status`, `r_code`, `r_secs`, `r_errs`, `r_seed`, `r_out` (`:513-519`). Siemen luetaan `Siemen: N` -riviltä (`:567`). | Uusinta lisätään tähän silmukkaan. 172/(a) askel 2 ("ajokohtaiset tulostetiedostot") on valmis; B rakentaa sen päälle. |
| 172/98a uusinnan tulos | `ajot.tsv` (`:594-611`) ja `rivit.tsv` (`:612-613`) syntyvät `r_*`-taulukoista; `Tarkistusrivit`-rivi (`:618`, `:714`) lasketaan `rivit.tsv`:stä. | 172 ei sano, miten uusinta näkyy TSV:issä. Avoin kysymys L1. |
| 172/98a `Epäonnistuneet:`-rivi | `:715`; valmismerkki `done_msg` (`:721`) on muotoa `lapi=N/M kesto=S loki=…`. | `Satunnaiset: …` omalle rivilleen `Epäonnistuneet`-rivin jälkeen. Valmismerkkiin lisätään `satunnaiset=a,b` vain, kun niitä on (ei muuta nykyistä muotoa muuten). |
| 172/106 *Nykytila* (`run_tests.sh:219-271`) | Silmukka `:521-587`. Godot ajetaan etualalla `timeout --foreground` (`:554`, `:558`); lukon tiedostokuvaaja suljetaan Godotilta `9>&-` (172/PÄÄTÖS 16 d). | Taustaprosesseissa `9>&-` säilyy. `--foreground` jätetään pois, ks. *Prosessipuun lopetus*. |
| 172/106 tulosjärjestys | `ajot.tsv` (`:595-601`), toistotaulukko (`:673-707`) ja vaihteluyhteenvedon ajolista olettavat, että saman testin ajot ovat `r_*`-taulukoissa peräkkäin listan järjestyksessä. Tulostetiedoston numero on `${#r_name[@]} + 1`. | Rinnakkaisajossa tulokset tallennetaan **ennalta varattuun paikkaan** (paikka = ajon järjestysnumero listassa × toisto), ei valmistumisjärjestyksessä, ja tulostetiedosto nimetään paikan mukaan. Muuten taulukko, TSV ja vaihtelulohkot menevät sekaisin. |
| 172/106 Ctrl+C | `interrupted` (`:198-207`) kirjoittaa vain viestin ja `exit 130`; lapsiprosesseja ei lopeteta. Bash ajaa trapin vasta, kun etualan komento on päättynyt. | Ks. *Prosessipuun lopetus*: myös `-j 1` ajaa Godotin taustalla ja odottaa `wait`illa, jotta trap laukeaa heti. |
| 172/106 `Läpi`-rivi | `:713`. Työnjohtajan vahti lukee rivin alkua. | Ennallaan: `-j`:llä (N ≥ 2) loppuun ` (rinnakkain N)`. |
| 172/98c lukko, 168b valmismerkki | `take_lock` (`:138-169`), `on_exit` (`:190-196`), `usage_error` (`:171-179`). | `--check` ei ota lukkoa eikä kirjoita valmismerkkiä (ks. *--check*). `--changed`: lukko otetaan ennen muutoslaskentaa, joten myös "Ei ajettavia testejä" kirjoittaa valmismerkin. |
| 172/98b testitaulukon muoto | `scripts/test_flags.gd`: `const MENU` (6, `:20-27`), `GAME` (45, `:30-76`), `SHOTS` (15, `:79-95`), rivi muotoa `\t"--piketest": "pike_follow_test",`. | Muoto vastaa 172:ta. **Huom.:** `--shopbgtest` on `MENU`-taulukossa (`:26`) ja silti ajurin listassa, joten `--changed` ja `--check` lukevat `GAME`- **ja** `MENU`-taulukon (172/98b puhuu vain "testitaulukosta"). |
| 172/98b `--check` (1) "jokainen `tests/*_test.gd`" | `tests/`-kansiossa 67 `.gd`-tiedostoa: 66 taulukoissa + `test_util.gd`. Kaikki taulukoissa (prototyyppi alla). | Laajennetaan koskemaan kaikkia `tests/*.gd` paitsi `test_util.gd`, jolloin myös rekisteröimätön kuvaskripti jää kiinni. |
| Käyttörivi ja ohjekommentti | `run_tests.sh:1-29`, `usage_error` `:174`. `docs/plan.md:132` (käyttörivi), `:266` *Pitkät ajot*, `:282` *Toistoajot*, `:1100` ("Julkaisu B … vielä tekemättä"). `README.md:289-305`. | Päivitetään uusilla lipuilla (kriteeri 27). |
| Itsetesti | `tools/run_tests_selftest.sh` kopioi vain `run_tests.sh`:n väliaikaiskansioon (`:8-13`), valekomento `:19-50`. | `--check` oikeaa työkopiota vasten ajetaan alkuperäisellä polulla `"$src" --check`, ei kopiolla (kopiossa ei ole `scripts/`ia). `--changed` tarvitsee itsetestissä oman väliaikaisen git-repon. |
| CI | `.github/workflows/tests.yml:29` ajaa itsetestin, `ubuntu-latest`. | Ei muutosta (172/PÄÄTÖS 5). `setsid` ja `/proc` ovat Ubuntussa. |

### Prosessipuun lopetus (uusi kohta)

**Nykytila (kokeiltu tässä työkopiossa).**

1. `timeout --foreground` lopettaa aikarajalla vain suoran lapsen. Kokeessa
   `timeout --foreground 1 bash -c 'sleep 97 & sleep 98; wait'` → koodi 124,
   molemmat `sleep`it jäivät henkiin. Ilman `--foreground`ia `timeout` tekee
   itsestään prosessiryhmän johtajan ja lopettaa koko ryhmän: samat `sleep`it
   kuolivat.
2. **Godot irrottaa omat alaprosessinsa.** `OS.execute_with_pipe` ja
   `OS.create_process` käynnistävät lapsen omaan istuntoon (kokeessa lapsen
   pid = pgid = sid). Siksi Planen ehdotus `setsid` + `kill -- -PGID` **ei
   riitä**: kokeessa `timeout 8 godot --headless -- --scratchtest=spawn.gd`
   ilman `--foreground`ia jätti molemmat Godotin käynnistämät `sleep`it henkiin
   (koodi 124). Sama koskee seedtestin kolmea alaprosessia
   (`tests/seed_test.gd:133-172`): ne elävät noin 6,0–6,8 s seedtestin
   alusta, ja jos ajuri tappaa seedtestin siinä välissä, ne jäävät orvoiksi.
3. Ympäristömuuttuja periytyy Godotin alaprosesseille istunnon vaihdosta
   huolimatta: `CATCHFISH_AJO=koe-123 timeout 8 godot … spawn.gd` → molemmat
   `sleep`it löytyivät `/proc/PID/environ`ista ja lopetettiin. Haku
   `grep -lsz '^CATCHFISH_AJO=koe-123$' /proc/[0-9]*/environ` kesti noin 2 ms.
4. Etualan putki `… | tee` jää odottamaan, jos orpo alaprosessi pitää
   ajurin tulosteputken auki (kokeessa `create_process`illa käynnistetty
   lapsi: ajo jumittui aikarajaan asti).

**Toiminta.**

- Ajuri merkitsee jokaisen Godot-ajon ympäristömuuttujalla
  `CATCHFISH_AJO=<ajurin pid>-<ajon paikka>` (esim. `41237-7`). Muuttuja
  periytyy Godotille ja sen kaikille alaprosesseille.
- Godot ajetaan `timeout -k 10 "$timeout_s"` -komennolla **ilman**
  `--foreground`ia ja stdin `/dev/null`ista (taustaryhmän prosessi ei saa
  lukea päätettä). `timeout` muodostaa oman prosessiryhmänsä ja lopettaa sen
  kokonaan; `-k 10` lähettää KILLin, jos Godot ei kuole TERMiin 10 sekunnissa.
- **Jokaisen ajon jälkeen** (OK, VIRHE, aikakatkaisu) ajuri lopettaa kaikki
  prosessit, joilla on ajon merkki (`kill -TERM`, 2 s:n päästä elossa olevat
  `kill -KILL`). Siivous tehdään putken kirjoittajan puolella ennen kuin
  tuloste suljetaan, jotta `tee` (ilman `-q`:ta, `-j 1`) ei jää odottamaan.
- **Ctrl+C ja SIGTERM** (`interrupted`): ajuri lopettaa kaikkien käynnissä
  olevien ajojen prosessiryhmät (`kill -TERM -- -<timeoutin pid>`) ja sen
  jälkeen kaikki prosessit, joiden merkki alkaa `<ajurin pid>-`, kirjoittaa
  `>> Keskeytetty.` ja valmismerkin `exit=130 keskeytetty` (kuten nyt).
  Ilmoitus, jos orpoja löytyi: `>> Lopetettiin n testin jälkeen jäänyttä
  prosessia.` (rivi myös tavallisen ajon siivouksesta, jos n > 0, testin
  tulosrivin alle; ajon tulos ei muutu).
- Jotta trap laukeaa heti, Godot-ajo käynnistetään taustalle ja ajuri odottaa
  `wait`illa myös `-j 1`:llä (bash ajaa trapin vasta etualan komennon
  päätyttyä). `-j 1`:n päätetuloste pysyy rivilleen samana kuin nyt (172/K20).
- `kill -9` ajurille ei ole siepattavissa: silloin käynnissä olevat ajot
  jatkavat aikarajaansa asti, ja lukko vapautuu (172/98c). Kirjataan
  `docs/plan.md`:hen.
- Aikakatkaisu tunnistetaan koodista 124, ja koodista 137, kun ajon kesto
  on vähintään aikaraja (`-k`:n pakkolopetus). Muut koodit kuten nyt.
- Jos `/proc` puuttuu, merkkihakua ei tehdä ja ajuri varoittaa kerran
  (`>> Varoitus: /proc puuttuu, testien alaprosesseja ei siivota`).
- `--ref`-ajon tuonti (`run_tests.sh:366`) saa saman merkin ja käsittelyn.

### 98a uusinta: täydennykset 172/98a:han

- Uusinnan argumentit: ensimmäisen ajon argumentit + ` --seed=<siemen>`, jos
  argumenteissa ei ole `--seed=`iä (`:526`:n ehto) ja siemen saatiin
  `Siemen:`-riviltä; muuten samat argumentit. Lisäliput (`-- …`) tulevat
  siemenen jälkeen kuten nyt.
- Uusinta ei käynnisty koodeilla 0, 124 ja 137 (aikakatkaisu) eikä
  keskeytyksessä.
- `-j`-ajossa uusinta menee jonon kärkeen ja käyttää samaa paikkaa (tulos
  korvaa paikan tuloksen, ensimmäisen ajon VIRHE-rivit säilyvät `r_errs`issa
  172/98a:n esimerkin mukaisesti).
- TSV-näkyvyys: avoin kysymys L1.

### 98b `--changed`: täydennykset 172/98b:hen

- Testitiedoston lippu luetaan `GAME`- ja `MENU`-taulukoista. Lipun
  listarivit ovat ne ajurin listan rivit, joiden argumenteissa lippu on
  erillisenä sanana (esim. `--anglertest` → `anglertest`, `anglertest-talvi`;
  `--audiologtest`-rivillä on myös `--audio-log`, joka ei ole taulukossa).
  Prototyyppi: 41 taulukon lippua osuu listaan, kukin listarivi osuu
  täsmälleen yhteen lippuun (51 riviä); 10 lippua ei ole listassa (alla).
- Muutoslista: `git diff --name-only --no-renames <vertailukohta>` (jolloin
  uudelleennimetystä tulee sekä vanha että uusi polku) + jäljittämättömät.
  Poistettu tiedosto käsitellään polkunsa mukaan.
- Lisäsäännöt sääntötaulukkoon (ennen "kaikki muu" -riviä; avoin kysymys L3):
  - `*.gd.uid` → kuten vastaava `.gd`,
  - `tools/test_map.txt` → ei pelitestejä; rivi `>> Aja myös: tools/run_tests.sh --check`,
  - `export/**` → ei testejä.
- Yhdistelmät (avoin kysymys L2): `--changed` + testin nimi → koodi 2 (172),
  `--changed` + `--scratch` → koodi 2, `--changed` + `--ref` → koodi 2;
  `--repeat`, `-j`, `--seed`, `-q`, `--no-retry` ja `-- LISÄLIPUT` ovat sallittuja.
- Vertailukohta: oletus `git merge-base origin/main HEAD`. Jos se ei ratkea
  (ei `origin/main`ia, ei git-repoa) tai `--changed=REF` ei ratkea → koodi 2
  ja ilmoitus `--changed: vertailukohta ei ratkea: REF`.
- Lukko otetaan ennen muutoslaskentaa (98c), joten `>> Ei ajettavia testejä.`
  kirjoittaa valmismerkin `exit=0 lapi=0/0 …`.

### `--check`: tarkennus 172/98b:hen

`tools/run_tests.sh --check`: ei aja testejä, ei tarvitse Godotia, ei ota
lukkoa, ei kirjoita `.test-logs/`iin eikä valmismerkkiä (voi ajaa, vaikka sarja
on käynnissä samassa työkopiossa). Lukee työkopiosta, jossa skripti on
(`$root`). Muiden argumenttien kanssa → koodi 2 (avoin kysymys L4).

Lähteet: `scripts/test_flags.gd` (`MENU`, `GAME`, `SHOTS`), `tests/*.gd`,
ajurin `tests`-lista, ajurin uusi `not_listed`-lista ja `tools/test_map.txt`.
Lippu "nimenä" = lippu ilman alun `--`:ta ja lopun `=`:ää (`--menutest=` → `menutest`).

| # | Tarkistus | Virherivi (esimerkki) |
|---|---|---|
| C1 | Jokainen `tests/*.gd` paitsi `test_util.gd` on jonkin taulukon arvona | `VIRHE tests/uusi_test.gd ei ole testitaulukossa (scripts/test_flags.gd)` |
| C2 | Jokaisen taulukon arvon skripti on olemassa (`tests/<arvo>.gd`) | `VIRHE --uusitest: skripti tests/uusi_test.gd puuttuu` |
| C3 | Jokainen `GAME`- ja `MENU`-lippu on joko vähintään yhden ajurin listarivin argumenteissa tai `not_listed`issä, ei molemmissa | `VIRHE --uusitest ei ole ajurin listassa eikä not_listed-listassa (tools/run_tests.sh)` |
| C4 | Jokaisen ajurin listarivin argumenteissa on täsmälleen yksi `GAME`- tai `MENU`-lippu | `VIRHE ajurin rivi luretset: ei testilippua argumenteissa` |
| C5 | Jokainen `not_listed`-nimi on taulukossa | `VIRHE not_listed: flickr ei ole testitaulukossa` |
| C6 | `test_map.txt`: rivillä TAB; polku on olemassa työkopiossa; polku ei toistu; jokainen testi on ajurin listarivin nimi | `VIRHE tools/test_map.txt:12: scripts/boat/bote.gd ei ole olemassa` |

`not_listed` aloitussisältö (prototyypillä laskettu nykyisestä mainista):
`menutest settingstest timepicktest careertest tvtest autotest flicker
pausetest inputtest perftest` (10, sama kuin 172/98b).

Tuloste (prototyypin luvut nykyisestä mainista):

```
$ tools/run_tests.sh --check
OK   testitaulukko: 66 lippua (45 peli, 6 valikko, 15 kuva), 66 skriptiä tests/-kansiossa
OK   ajurin lista: 51 riviä, 41 lippua; käsin ajettavat (not_listed): 10
OK   muutoskartta: 19 riviä
Tarkistus läpi.
```

Virheessä: VIRHE-rivit, sitten `Tarkistus: n virhettä`, koodi 1.

Prototyyppi: taulukoiden luku awkilla
(`/^const [A-Z_]+ := \{/` → taulukko, rivit `^\t"--…": "…",`): 45 + 6 + 15;
C1 ja C3 laskettu: ei puutteita, 10 lippua listan ulkopuolella; C4: jokainen
51 rivistä osuu yhteen lippuun; 172:n karttarivien 19 polkua ovat olemassa.
Tulosteen muotoa ei ole ajettu (ei toteutusta).

## Ulkoasu ja äänet

Ei muutoksia peliin, ei kuvia. Päätetulosteen muodot: 172 ja tämä suunnitelma.

## Toteutus pääpiirteissään

Järjestys 172/(a) askeleet 5–8, ja prosessipuun lopetus ensin, koska `-j` ja
uusinta rakentuvat sen ajotavan päälle:

1. Prosessipuun lopetus: Godot taustalle + `wait`, merkki, `timeout -k` ilman
   `--foreground`ia, siivous ajon jälkeen ja trapissa (`-j 1`, tuloste ennallaan).
2. 98a uusinta.
3. 106 `-j N` ja `.test-logs/kestot.tsv` (päivitetään myös `-j 1`:llä, jotta
   ensimmäinen rinnakkaisajo saa järjestyksen).
4. 98b `--changed`, `tools/test_map.txt`, `--check` ja `not_listed`.
5. Dokumentit: `README.md`, `docs/plan.md` (172/PÄÄTÖS 7: `CLAUDE.md` ja
   `.claude/` työnjohtajalle).

Tiedostot: `tools/run_tests.sh`, `tools/run_tests_selftest.sh`,
`tools/test_map.txt` (uusi), `README.md`, `docs/plan.md`. Pelikoodiin
(`scripts/`, `tests/`) ei kosketa.

Itsetestin valekomentoon (172 *Tiedostot*) lisäksi: testi, joka käynnistää
alaprosessin omaan istuntoon kuten Godot (`setsid sleep 3171 &`, sitten
`exec sleep 30`). Itsetestissä Ctrl+C:n kokeilu taustalle käynnistetylle
ajurille tarvitsee `set -m`in tai `setsid`in: ei-interaktiivisessa bashissa
`&`-prosessi perii SIGINTin ohitettuna, eikä sitä voi silloin siepata.

Headless ja ikkunan koko: ei pakoteta, ikkunatesteihin ei kosketa.

Muutokseen liittyvät nykyiset testit: `tools/run_tests_selftest.sh` (kaikki
nykyiset tarkistukset), seedtest (alaprosessit), koko ajurin lista (172/K22–23).

### Sivuvaikutuslista

| Muutettu asia | Käyttäjät (grep) | Tarkistettu |
|---|---|---|
| `timeout --foreground` pois, Godot taustalle | `run_tests.sh:366`, `:554`, `:558`; ikkunatestit eivät kulje ajurin kautta | tarkistettu grepillä; `-j 1` -tuloste kriteerillä 20 |
| Stdin `/dev/null`ista | `grep -n 'stdin\|get_line\|read_string_from_stdin' scripts tests`: ei osumia | tarkistettu |
| Merkin perusteella lopetus | Vain prosessit, joilla on ajurin oma `CATCHFISH_AJO=<pid>-` -merkki; toisen työkopion ajurilla eri pid | tarkistettu ajatuksena, ei ajettu rinnakkain |
| Koodi 137 → AIKAKATKAISU | `run_tests.sh:573`, `ajot.tsv`:n tulos-sarake | ei ajettu (ei toteutusta) |
| `Satunnaiset:`-rivi, valmismerkin `satunnaiset=` | Työnjohtajan vahti lukee `Läpi`-riviä; `latest.done` luetaan `cat`illa | tarkistettu: `Läpi`-rivin alku ennallaan |
| `kestot.tsv` `.test-logs/`ssa | Siivous `:329-332` poistaa vain päivättyjä lokeja | tarkistettu: ei osu |
| `--check` itsetestissä oikeaa työkopiota vasten | CI:n checkout sisältää `scripts/` ja `tests/` | tarkistettu `tests.yml`:stä |

## Hyväksymiskriteerit

172/K18–K27 pätevät seuraavin muutoksin; uudet kriteerit 28–31.
"Ei prototyypattu" ellei toisin mainita.

**Muutokset 172:n kriteereihin**

- **K18 täydennys.** Uusinnan TSV-rivit L1:n päätöksen mukaan. Uusinta ei
  käynnisty koodilla 137 (aikakatkaisu `-k`:lla).
- **K21 korvaava muoto.** `pgrep -f 'godot.*--headless'` osuisi myös toisen
  työkopion ajoihin. Uusi tarkistus: `tools/run_tests.sh -q -j 4 & sleep 20;
  kill -INT %1; sleep 3` interaktiivisessa kuoressa (tai `kill -TERM`
  ajurin pid:lle), ajurin pid luetaan `.test-logs/run.lock`in `pid=`-kentästä
  ennen keskeytystä: `grep -lsz "^CATCHFISH_AJO=$PID-" /proc/[0-9]*/environ`
  on tyhjä, `pgrep -P $PID` on tyhjä ja `latest.done` alkaa `exit=130`.
- **K22 ennallaan**, lisäksi kirjataan `>> Lopetettiin n … prosessia` -rivien
  määrä (odotus 0).
- **K24 täydennys.** Itsetestin väliaikainen git-repo saa `origin/main`in
  (`git update-ref refs/remotes/origin/main …`), `scripts/test_flags.gd`:n
  kopion ja tyhjät `tests/*.gd`-tiedostot. Lisäksi: muutettu
  `tests/shop_bg_test.gd` (`MENU`-lippu) → ajetaan `shopbgtest`;
  `tools/test_map.txt` → ei pelitestejä ja `Aja myös: … --check` (jos L3 = A);
  `--changed --scratch=x.gd` → koodi 2; ei `origin/main`ia → koodi 2 ja
  `vertailukohta ei ratkea`; tyhjä muutoslista → `latest.done` alkaa `exit=0`.
- **K25 täydennys.** Jokainen tarkistus C1–C6 kaatuu omalla mutaatiollaan
  tilapäisessä kopiossa (rivi pois taulukosta, ylimääräinen `tests/x_test.gd`,
  rivi pois ajurin listasta, kirjoitusvirhe ajurin rivin lipussa, olematon
  nimi `not_listed`issä, olematon polku ja testi kartassa): koodi 1 ja virherivi
  nimeää puutteen. `--check` ajon aikana (lukko varattu) → koodi 0 eikä
  `latest.done` muutu. `--check luretest` → koodi 2 (jos L4 = A).
  Itsetesti ajaa lopuksi `"$src" --check` (alkuperäinen polku). Prototyypattu
  osin: luvut 45/6/15, 51 riviä, 41 lippua, 10 listan ulkopuolella.

**Uudet kriteerit**

28. [ ] **Aikaraja lopettaa alaprosessit** (itsetesti): valekomennon testi,
    joka käynnistää `setsid sleep 3171 &` ja jää jumiin; `TEST_TIMEOUT=2` →
    `AIKAKATKAISU`, ja 3 s ajurin päättymisen jälkeen `pgrep -x -f 'sleep 3171'`
    on tyhjä. Samassa työkopiossa `origin/main`in ajurilla sama kokeilu jättää
    `sleep 3171`:n henkiin (todistaa, että kriteeri mittaa korjausta).
    Nykytilan vuoto prototyypattu (`sleep 97/98` ja Godotin `sleep 78/79`
    jäivät henkiin), korjaus ei.
29. [ ] **Keskeytys lopettaa alaprosessit** (itsetesti): sama valetesti ja
    `FAKE_DELAY`; ajuri taustalla (`set -m`), `kill -INT` ja erikseen
    `kill -TERM` ajurille → 3 s:n päästä `sleep 3171` ei ole elossa,
    `latest.done` alkaa `exit=130`, lukko vapaa (uusi ajo ei saa koodia 3).
    Sama `-j 2`:lla kahdella valetestillä. Ei prototyypattu.
30. [ ] **Oikea Godot ja irrotettu alaprosessi** (testaaja): kokeiluskripti
    ```
    extends Node
    func _ready() -> void:
    	OS.execute_with_pipe("sleep", ["1830"], false)
    	OS.create_process("sleep", ["1831"])
    	await get_tree().create_timer(60.0).timeout
    	get_tree().quit(0)
    ```
    `TEST_TIMEOUT=8 tools/run_tests.sh -q --scratch=POLKU` → `AIKAKATKAISU`,
    ja 3 s myöhemmin `pgrep -x -f 'sleep 183[01]'` on tyhjä; ilman `-q`:ta
    sama ajo päättyy alle 20 sekunnissa (`tee` ei jää odottamaan).
    Prototyypattu nykytila: `timeout`illa sekä `--foreground`in kanssa että
    ilman molemmat `sleep`it jäivät henkiin; `CATCHFISH_AJO`-merkillä ne
    löytyivät ja lopetettiin. Ajurin korjausta ei ole prototyypattu.
31. [ ] **Mutaatiot** (172/K26:n lisäksi): (c) ajon jälkeinen merkkisiivous
    pois → kriteerit 28 ja 30 kaatuvat; (d) trapin ryhmä- ja merkkilopetus pois
    → kriteeri 29 kaatuu; (e) `timeout --foreground` takaisin → kriteeri 28
    kaatuu ilman merkkisiivousta (ajetaan yhdessä (c):n kanssa). Muodot
    kirjataan *Päätöksiin* kuten 172/PÄÄTÖS 16. Ei prototyypattu.

## Avoimet kysymykset Teemulle

Ei avoimia kysymyksiä. Julkaisu B:n linjaukset on tehty 172:ssa
(172/PÄÄTÖS 1, 2, 3, 5). Uudet kysymykset ovat ajurin sisäisiä, ja ne ovat
alla työnjohtajalle.

## Avoimet kysymykset työnjohtajalle

**L1. Uusinta TSV-tiedostoissa** (172 ei määrää).
- A: Kumpaankin TSV:hen uusi viimeinen sarake `uusinta` (0/1); uusinta saa
  omat rivinsä (`ajo` = sama kuin ensimmäisellä). Ensimmäisen ajon `tulos`
  on `SATUNNAINEN` tai `VIRHE`, uusinnan `OK`/`VIRHE`. Vanhat sarakkeet
  paikoillaan; `rivit.tsv`:n rivimäärä vastaa lokin OK/VIRHE-rivejä (172/K12 pätee).
- B: Uusinta ei TSV:hin; ensimmäisen ajon rivillä `SATUNNAINEN`. 172/K12:n
  vertailu pätee vain ajoon ilman uusintaa.
- Oletus, jos ei linjata: A.

**L2. `--changed`-yhdistelmät.**
- A: `--scratch` ja `--ref` → koodi 2; `--repeat`, `-j`, `--seed`, `-q`,
  `--no-retry` ja `-- LISÄLIPUT` sallittuja.
- B: kuten A, mutta `-- LISÄLIPUT` → koodi 2 (lisäliput eivät sovi kaikkiin
  testeihin, kun valinta ei ole käyttäjän).
- Oletus, jos ei linjata: A.

**L3. Muutoskartan lisäsäännöt** (`*.gd.uid` kuten `.gd`;
`tools/test_map.txt` → ei pelitestejä ja `Aja myös: tools/run_tests.sh --check`;
`export/**` → ei testejä).
- A: kaikki kolme.
- B: ei lisäsääntöjä (nämä ajavat kaikki testit, kuten 172:n "kaikki muu").
- Oletus, jos ei linjata: A.

**L4. `--check` muiden argumenttien kanssa.**
- A: muut argumentit → koodi 2 (`--check ei yhdisty muihin lippuihin`).
- B: muut argumentit ohitetaan.
- Oletus, jos ei linjata: A.

**L5. Alaprosessien siivous ympäristömerkillä `/proc`in kautta** (Linux;
WSL ja CI kunnossa; ilman `/proc`ia varoitus ja ei siivousta).
- A: merkki ja `/proc`-haku (kokeiltu toimivaksi, ks. *Prosessipuun lopetus*).
- B: vain prosessiryhmän lopetus (`setsid` / `timeout` ilman
  `--foreground`ia). Ei korjaa testaajan löydöstä, koska Godot irrottaa
  alaprosessinsa omaan istuntoonsa.
- Oletus, jos ei linjata: A.

**L6. Pakkolopetus `timeout -k 10`** ja koodi 137 → AIKAKATKAISU.
- A: kyllä, 10 s.
- B: ei `-k`:ta (nykyinen: TERMiin reagoimaton Godot jää odottamaan).
- Oletus, jos ei linjata: A.

**L7. Päätösten numerointi.** Tässä tiedostossa päätökset jatkavat 172:n
numerointia (ensimmäinen on PÄÄTÖS 19), ja 172:n päätöksiin viitataan
muodossa "172/PÄÄTÖS n". Perustelu: paljas "PÄÄTÖS 5" viestissä on silloin
yksiselitteinen, koska sama numero ei ole käytössä kahdessa tiedostossa, ja
172:n kriteerinumerointi jatkuu samalla tavalla (28–31).
- A: jatketaan numerosta 19.
- B: alusta (PÄÄTÖS 1), viittaukset 172:een aina etuliitteellä.
- Oletus, jos ei linjata: A.

## Päätökset

Numerointi jatkuu 172:n päätöksistä (ensimmäinen tässä tiedostossa on
PÄÄTÖS 19), ellei L7:ssä toisin linjata. Viittaukset 172:n päätöksiin:
"172/PÄÄTÖS n".

PÄÄTÖS 19: Uusinta kirjataan TSV:hin (L1 = A). Kumpaankin TSV:hen uusi
viimeinen sarake `uusinta` (0/1), ja uusinta saa omat rivinsä. Työnjohtaja
17.11.2026.

PÄÄTÖS 20: `--changed` yhdessä `--scratch`in tai `--ref`in kanssa → koodi 2;
`--repeat`, `-j`, `--seed`, `-q`, `--no-retry` ja `-- LISÄLIPUT` ovat sallittuja
(L2 = A). Työnjohtaja 17.11.2026.

PÄÄTÖS 21: Muutoskartan lisäsäännöt otetaan käyttöön kaikki kolme (L3 = A):
`*.gd.uid` kuten `.gd`, `tools/test_map.txt` → `--check`-vihje ilman
pelitestejä, `export/**` → ei testejä. Työnjohtaja 17.11.2026.

PÄÄTÖS 22: `--check` ei yhdisty muihin argumentteihin; muut argumentit →
koodi 2 (L4 = A). Työnjohtaja 17.11.2026.

PÄÄTÖS 23: Alaprosessit siivotaan ympäristömerkillä `CATCHFISH_AJO` ja
`/proc`-haulla (L5 = A); ilman `/proc`ia varoitus eikä siivousta. Pelkkä
ryhmätappo ei riitä, koska Godot irrottaa alaprosessit omaan istuntoonsa.
Työnjohtaja 17.11.2026.

PÄÄTÖS 24: Pakkolopetus `timeout -k 10`, ja koodi 137 tulkitaan
AIKAKATKAISUKSI (L6 = A). Työnjohtaja 17.11.2026.

PÄÄTÖS 25: Päätökset jatkavat 172:n numerointia (L7 = A); viittaukset 172:n
päätöksiin muodossa "172/PÄÄTÖS n". Työnjohtaja 17.11.2026.
