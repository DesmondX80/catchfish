# CATCHFISH-91: run_tests.sh: yhteenvetotaulukko, loki ja toistoajo

## Tavoite
Testiajon tulos näkyy yhdellä silmäyksellä lopun taulukosta, koko loki jää
tiedostoon, ja epävakaaksi epäilty testi voidaan ajaa N kertaa (myös
origin/mainissa) yhdellä komennolla. Peli ei muutu: ei versionnostoa eikä
releasea, muutos mainiin.

## Toiminta käyttäjän kannalta

Nykytila (`tools/run_tests.sh`): ensimmäinen argumentti on Godot, loput
testien nimiä; jokaisen testin jälkeen rivi `OK    nimi (12 s)` tai
`VIRHE nimi (koodi 1, 12 s)`, joka näyttää samalta kuin testien omat
`OK   tarkistus` / `VIRHE tarkistus` -rivit.

### Komentorivi
```
tools/run_tests.sh [GODOT] [LIPUT] [TESTIN_NIMI...]
  --repeat=N      aja jokainen valittu testi N kertaa (oletus 1)
  --ref=REF       aja testit REF:n (esim. origin/main) väliaikaisessa työkopiossa
  --log=TIEDOSTO  lokin polku (oletus alla)
  -q, --quiet     ei Godotin tulostetta päätteeseen, vain tulosrivit ja taulukko
```
- **Godotin valinta:** `$GODOT` → `godot-4.7.2`, jos löytyy PATHista → `godot`.
  Ensimmäinen argumentti tulkitaan Godotiksi, jos se ei ole lippu eikä
  listan testinimi (näin `tools/run_tests.sh ~/godot-bin/godot` CI:ssä ja
  `tools/run_tests.sh luretest` paikallisesti toimivat molemmat).
- Tuntematon testinimi → virheilmoitus ja koodi 2 heti alussa (nyt se
  ohitetaan hiljaa ja "Kaikki testit läpi" voi tulla ilman yhtään testiä).
- `TEST_TIMEOUT` säilyy ennallaan.

### Ajon aikana
`::group::nimi` / `::endgroup::` säilyvät ennallaan (CI). Testin jälkeen
tulosrivi erottuvalla etuliitteellä, esim.
```
>> OK            luretest   48 s
>> VIRHE         trolltest  71 s (koodi 1)
>> AIKAKATKAISU  boattest  600 s
```
Toistoajossa `>> OK  luretest [3/10]  48 s`.

### Lopun taulukko
```
==================== Testien yhteenveto ====================
TESTI                 TULOS          KESTO
anchortest            OK              21 s
luretest              VIRHE (1)       48 s
    VIRHE uistin syvyys 1.2 m (odotettu 2.0)
trolltest             AIKAKATKAISU   600 s
...
------------------------------------------------------------
Läpi 33/35, kesto yhteensä 14 min 3 s
Epäonnistuneet: luretest trolltest
Loki: .test-logs/20261029-141203.log
============================================================
```
- Epäonnistuneen testin alle enintään 5 sen omaa `VIRHE`-alkuista riviä
  sisennettynä (kaikki testit tulostavat tarkistuksensa muodossa
  `VIRHE <tarkistus>`), ja "(+N muuta)", jos niitä on enemmän.
- Viimeinen rivi ennen alareunaa kertoo lokin polun.

Toistoajossa taulukko on testikohtainen:
```
TESTI                 LÄPI    VIRHE  AIKAKAT.  KESTO (ka.)
luretest              7/10      3       0          48 s
```
ja `--ref`-ajossa otsikkoon `(origin/main @ 03f7125)`.

### Loki
- Oletus `<työkopio>/.test-logs/AAAAKKPP-HHMMSS.log` ja symlinkki
  `.test-logs/latest.log` viimeisimpään. `.test-logs/` lisätään `.gitignore`:en.
- Lokiin menee kaikki: Godotin tuloste, tulosrivit ja taulukko (`tee`).
- `--ref`-ajossa loki kirjoitetaan kutsuvaan työkopioon, nimessä ref,
  esim. `20261029-141203-origin-main.log`, jotta se säilyy työkopion poiston jälkeen.

### `--ref`
1. `git worktree add --detach <scratch>/run-tests-<ref>-XXXX <ref>`
   (`mktemp -d`), tulostaa ref:n ja commit-tiivisteen.
2. `godot --headless --import` siellä (tuloste lokiin, ei taulukkoon).
3. Ajaa valitut testit siellä nykyisen skriptin testilistalla. Jos testiä
   ei ole ref:n `tools/run_tests.sh`-listassa, rivi `PUUTTUU` eikä sitä
   ajeta (muuten peli käynnistyisi ja jäisi aikarajaan).
4. Siivoaa (`git worktree remove --force`) myös keskeytettäessä (`trap`, Ctrl+C).
- Ei tee `git fetch`:iä itse; tulostaa vihjeen, jos ref on `origin/...`.

### Paluukoodit
0 = kaikki ajot läpi, 1 = jokin VIRHE/AIKAKATKAISU, 2 = väärä käyttö
(tuntematon testi tai lippu, Godotia ei löydy, ref ei ratkea).

## Ulkoasu ja äänet
Vain päätetuloste, ei värejä (CI-lokit ja tiedostoloki pysyvät luettavina).
Suomenkieliset sanat kuten nykyisessä skriptissä: OK, VIRHE, AIKAKATKAISU.

## Toteutus pääpiirteissään
- `tools/run_tests.sh`: argumenttien jäsennys, tulokset taulukkoon
  (nimi, tila, kesto, VIRHE-rivit) taulukoina bash-taulukoissa, `tee` lokiin,
  `--repeat`-silmukka, `--ref`-työkopio ja `trap`-siivous. Testilista pysyy
  samana. Yksi skripti, ei erillistä `flaky_check.sh`:ta (yksi testilista).
- `.gitignore`: `.test-logs/`.
- `.github/workflows/tests.yml`: ei muutosta pakollisesti; komento
  `tools/run_tests.sh ~/godot-bin/godot` toimii kuten ennen.
- Dokumentaatio: `README.md` (rivit ~224), `docs/plan.md` osio *Testaus* ja
  CLAUDE.md:n Testaus-kohta (Godot-latausohje → `godot-4.7.2`).
- Testi: ks. avoin kysymys 4 (käsin ajettavat kriteerit tai pieni itsetesti
  valekomennolla).

## Hyväksymiskriteerit
- [ ] `tools/run_tests.sh speciestest` ajaa testin `godot-4.7.2`:lla ilman
      Godot-argumenttia ja tulostaa taulukon, jossa rivi `speciestest OK <s>`.
- [ ] `tools/run_tests.sh godot-4.7.2 speciestest` ja
      `GODOT=godot-4.7.2 tools/run_tests.sh speciestest` toimivat samoin.
- [ ] Koko sarja: taulukossa jokainen 35 testiä täsmälleen kerran, tila ja
      kesto; lopussa läpimenojen määrä ja lokin polku.
- [ ] Tulosrivit (`>> ...`) ja taulukko erottuvat testien omista
      `OK`/`VIRHE`-riveistä (`grep '^>>'` antaa vain tulosrivit).
- [ ] Epäonnistunut testi (esim. tilapäisesti rikottu tarkistus koodaajan
      työkopiossa, ei commitoida): taulukossa `VIRHE (1)`, alla sen
      `VIRHE`-rivit, paluukoodi 1.
- [ ] `TEST_TIMEOUT=5 tools/run_tests.sh luretest` → `AIKAKATKAISU`, paluukoodi 1.
- [ ] `tools/run_tests.sh eiolemassa` → virheilmoitus, paluukoodi 2, ei ajoja.
- [ ] Loki `.test-logs/<aika>.log` sisältää Godotin tulosteen ja taulukon;
      `latest.log` osoittaa siihen; `git status` ei näytä lokeja.
- [ ] `-q`: päätteeseen vain `>>`-rivit ja taulukko, loki silti täydellinen.
- [ ] `--repeat=3 speciestest` → kolme ajoa, taulukossa `3/3`.
- [ ] `--ref=origin/main --repeat=2 speciestest` → ajo väliaikaisessa
      työkopiossa, otsikossa ref ja tiiviste; lopuksi `git worktree list` ei
      näytä väliaikaista kopiota. Sama Ctrl+C:llä kesken ajon.
- [ ] `--ref`-ajossa testi, jota ref:n listassa ei ole → `PUUTTUU`.
- [ ] GitHub Actions -ajo haarasta menee läpi ja `::group::`-ryhmät näkyvät
      Actionsin lokissa kuten ennen.
- [ ] README, docs/plan.md ja CLAUDE.md kuvaavat uudet liput ja `godot-4.7.2`:n.

## Ratkaistut kysymykset (työnjohtaja, 2026-10-29)

Työkalun yksityiskohtia, joten työnjohtaja ratkaisi:
1. Loki `.test-logs/` työkopiossa (gitignore), säilytetään 20 viimeisintä (vanhemmat poistetaan ajon alussa).
2. Oletus pysyy (kaikki päätteeseen), `-q` erikseen. Agenttien ohjeisiin `-q`.
3. Toistoajo run_tests.sh:n lippuina `--repeat`/`--ref`, ei erillistä skriptiä.
4. Tehdään pieni itsetesti `tools/run_tests_selftest.sh` valekomennolla (GODOT=valeskripti: OK, VIRHE-rivit + koodi 1, nukkuu → aikakatkaisu, tuntematon nimi → 2, --repeat, loki ja `>>`-rivit). Lisätään omaksi askeleekseen `.github/workflows/tests.yml`:iin ennen varsinaisia testejä. `--ref` testataan käsin.
5. Koodaaja päivittää samassa haarassa `.claude/agents/testaaja.md`:n ja `koodaaja.md`:n: `tools/run_tests.sh -q`, ja väite "epäonnistuu myös mainissa" tarkistetaan `--ref=origin/main --repeat=N NIMI`.
6. 5 VIRHE-riviä testiä kohden riittää.
Huom: CLAUDE.md:n Godot-ohje on jo päivitetty `godot-4.7.2`:een (CATCHFISH-94, mainissa); siihen vain uudet liput.

## Alkuperäiset avoimet kysymykset
1. **Lokin sijainti.** Ehdotus `.test-logs/` työkopiossa (gitignore).
   Vaihtoehdot: scratchpad/`/tmp` (ei roskaa repoon, mutta katoaa) tai
   `.godot/test-logs/` (jo ignoroitu, mutta Godotin kansio).
   Säilytetäänkö kaikki lokit vai esim. 20 viimeisintä?
2. **Hiljainen tila oletuksena paikallisesti?** Ehdotus: oletus kuten nyt
   (kaikki päätteeseen), `-q` erikseen. Vaihtoehto: `-q` oletuksena aina,
   kun `GITHUB_ACTIONS` ei ole asetettu (agenttien ajoissa eniten hyötyä).
3. **Toistoajo samassa skriptissä vai erillinen `tools/flaky_check.sh`?**
   Ehdotus: liput `--repeat`/`--ref` run_tests.sh:ssa (yksi testilista).
   Vaihtoehto: ohut `flaky_check.sh NIMI N [REF]`, joka kutsuu run_tests.sh:ta.
4. **Testi työkalulle.** Työtapa vaatii uudelle ominaisuudelle testin.
   Ehdotus: ei automaattitestiä, hyväksymiskriteerit ajetaan käsin.
   Vaihtoehto: pieni `tools/run_tests_selftest.sh` valekomennolla
   (`GODOT=` skripti, joka palauttaa 0/1/nukkuu), ajetaan myös CI:ssä.
5. **Agenttien ohjeet.** Päivitetäänkö `.claude/agents/testaaja.md` ja
   `koodaaja.md` käyttämään esim. `tools/run_tests.sh -q` ja `--ref`-tarkistusta
   ("epäonnistuu myös mainissa" -väitteet), vai tekeekö sen työnjohtaja?
6. **Taulukon VIRHE-rivit:** riittääkö 5 ensimmäistä per testi?
