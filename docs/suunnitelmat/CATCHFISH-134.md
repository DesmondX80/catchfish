# CATCHFISH-134: Keula-aalto ja pehmeämpi peräaalto kovassa vauhdissa

## Tavoite
Kovassa vauhdissa vene näyttää kyntävän vettä: keulasta lähtee nopeuteen
sidottu vaahtoviiksi matalan läpikuultavan vesiharjanteen päällä
(keula-aalto) ja täydessä vauhdissa roiskeita, ja
peräaalto alkaa perästä pehmeästi ja sen reunat ovat rikkonaiset eivätkä
viivoittimella vedetyt.

## Nykytila (tutkittu 6.11.2026)
- Kuvat 28,0 km/h tyynellä, syvässä vedessä (designerin apuskripti, RTX 4050):
  kansio `/tmp/claude-1000/-home-teekar-projektit-catchfish/cd82cab9-5bb8-42a9-b83a-d1ceb3ba0e58/scratchpad/nyky2/`
  (`a-takaa-ylhaalta.png`, `b-keula-sivulta.png`, `c-keula-edesta.png`,
  `d-pera-lahelta.png`, `e-ylhaalta.png`; ei repossa).
  CATCHFISH-108:n designer-kuvia a–g ei ole tallessa (suunnitelmassa eikä
  git-historiassa), joten nämä korvaavat ne.
- **Keulassa ei mitään.** `Wake` (`scripts/boat/wake.gd`) piirtää vain
  perän näytehistoriasta (`track(stern, right, speed)`, näyte 0,7 m välein).
  Kuvissa b ja c keulan ympärillä on peilityyntä vettä.
- **Suorakaide perässä.** Kulku-uoma alkaa uusimmasta näytteestä (0–0,7 m
  perän takana, väliin jää rako) täydellä alfalla 0,75 (raja `clamp(..., 0.75)`
  saavutetaan jo 3,8 m/s:ssa). Puolileveys iässä 0 on `0.45 + speed·0.08`
  = 1,07 m, eli 2,1 m leveä, kun peräpeili on 1,24 m (`HULL_STATIONS`
  2,2: 0,62). Uoman alkureuna on suora poikkiviiva (kuva e).
- **Viivoitinreunat.** Jokainen nauha on yksi nelikulmio, jonka kaikilla
  kärjillä on sama alfa, joten reuna on terävä. Kelvinin sivuaallot
  (puolileveys 0,18 m, alfa 0,55) ovat tasapaksuja suoria viivoja, jotka
  alkavat perästä kiinni uomassa (offset 0,6 m, eli peräpeilin sisällä).
  Varjostimen `streaks` vaihtelee vain alfaa nauhan sisällä, ei reunaa.
- `Wake` on yhteinen pelaajan veneelle ja vieraille veneille
  (`other_boat.gd:103`, moottorivene 4,4 m/s, soutuvene 1,5 m/s).
  Pelaajan soutu on noin 1,5 m/s, peruutus 3,2 m/s, täysi kaasu 7,78 m/s.
- `Wake.track` saa nopeuden `velocity.length()`, joten peruuttaessa
  nopeus on positiivinen; keula-aalto ei saa syntyä peruutuksessa.
- Vesipinta ei nouse vanan kohdalla (vaahto on litteä kerros pinnan päällä,
  `wake.gdshader`, +0,025 m). Vesipinta pysyy ennallaan; keulan kohouma
  tehdään omana harjannemeshinä (PÄÄTÖS 1).
- `--screenshots`-kuva `6-moottorivana` ei nykyään kuvaa moottorivanaa:
  vene ajaa matalikolle ja potkuri hajoaa (HUD "Airot (potkuri rikki)").
  Ei tämän tehtävän asia, kirjataan retroon.

## Toiminta pelaajan kannalta
Ei uusia näppäimiä eikä sääntöjä. Ulkoasu riippuu veneen nopeudesta
**eteenpäin** (`v = velocity · forward`, peruutus 0):

| v | Tilanne | Keula-aalto (viiksi + harjanne) | Roiske |
|---|---|---|---|
| < 1,2 m/s | hidas soutu, ajelehdinta | ei | ei |
| 1,5 m/s | soutu | heikko, lyhyt viiksi (alfa ~0,03), harjanne ei näy | ei |
| 4,4 m/s | vieras moottorivene, ~16 km/h | selvä viiksi (alfa ~0,36), harjanne 0,06 m | ei |
| ≥ 6,5 m/s | ~23 km/h → täysi kaasu 28 km/h | täysi (alfa 0,6), harjanne 0,10 m | kyllä |

Voimakkuus `k = clamp((v − 1,2) / 5,3, 0, 1)` (0 → 1 välillä 1,2–6,5 m/s).
Peruutuksessa, jäällä ja paikallaan keula-aaltoa ei ole. Peräaallon
käyttäytyminen nopeuden ja iän mukaan (leviäminen, haalistuminen,
14 s elinaika) pysyy ennallaan; vain sen alku ja reunat muuttuvat.

## Ulkoasu ja äänet

### Keula-aalto (vaahtoviikset)
- Kaksi vaahtonauhaa, yksi kummallekin kyljelle. Ne piirretään joka ruutu
  veneen **nykyisestä** asennosta (ei historiasta), joten ne seuraavat
  keulaa myös käännöksissä.
- Alkupiste rungon ääriviivalla (`Boat.OUTLINE`): hitaasti keulapiikin
  lähellä (z = −1,9, x = ±0,32), täydessä vauhdissa vähän taaempana
  (z = −1,5, x = ±0,54), koska keula nousee (`planing` 0,06 rad) ja vene
  kulkee liu'ussa. Välissä lineaarisesti k:n mukaan.
- Nauha kulkee rungon kylkeä pitkin perään ja aukeaa ulospäin: etäisyys
  ääriviivasta 0,05 m alussa → 0,2 m peräpeilin kohdalla (x ±0,82 perässä).
  Perän takana nauha jatkuu suoraan Kelvinin sivuaaltoon (ks. alla), jolloin
  koko V alkaa keulasta kuten oikeassa vanassa.
- Hitaalla vauhdilla viiksi on lyhyt: pituus `0,8 m + k · (koko kylki)`,
  eli k = 1:llä keulasta peräpeiliin asti.
- Leveys (puolileveys) 0,06 m (k = 0) → 0,22 m (k = 1). Alfa 0,6 · k,
  kärjessä (alkupiste) pyöristetty häivytys 0,3 m:n matkalla, reunat
  pehmeät kuten peräaallossa.
- Väri ja valo: sama `wake.gdshader` (vaahto, `light`-uniform yöhön),
  sama `streaks`-kuvio. Rungon sisälle ei piirretä (`inside_boat`).

### Keulan vesiharjanne (PÄÄTÖS 1)
Matala läpikuultava veden kohouma kummallakin kyljellä keula-aallon
kohdalla. Vaahtoviiksi kulkee harjanteen harjalla.

- **Muoto ylhäältä:** harjanne seuraa rungon ääriviivaa (`Boat.OUTLINE`)
  keula-aallon alkupisteestä (sama kuin viiksen, z −1,9 → −1,5 k:n mukaan)
  taaksepäin. Pituus pitkin kylkeä `0,6 m + 1,6 m · k`, eli k = 1:llä
  2,2 m (alkupisteestä z = −1,5 noin z = +0,7:ään, leveimmän kohdan taakse).
- **Poikkiprofiili** (kohtisuoraan ääriviivasta ulospäin, mitat k = 1):
  - sisäreuna ääriviivalla (0 m), korkeus 0,4 · h (vesi nousee kylkeä
    vasten; sisäreuna jää rungon kyljen taakse piiloon)
  - harja 0,12 m ulkona, korkeus h
  - ulkoreuna 0,12 + 0,5 m = 0,62 m ulkona, korkeus 0 (loiva, kupera
    rinne; vähintään 3 väliväliä, ettei rinne näytä tasolta)
  - leveys skaalautuu `0,5 + 0,5 · k`, joten hitaasti harjanne on kapeampi.
- **Korkeus pituussuunnassa:** `h = 0,10 m · k · e(s)`, missä s = 0 … 1 on
  suhteellinen paikka alkupisteestä loppuun: e nousee 0:sta 1:een
  s = 0 … 0,3 (smoothstep) ja laskee 1:stä 0:aan s = 0,3 … 1. Huippu siis
  keulaolkapäällä, ja harjanne sulautuu pintaan kyljen puolivälissä.
  Esimerkit: 28 km/h h_max 0,10 m, 16 km/h (k ≈ 0,6) 0,06 m, soutu
  1,5 m/s (k ≈ 0,06) 0,006 m eli ei käytännössä näy.
- **Nopeus:** sama k kuin viiksillä (nopeus eteenpäin). Peruutus,
  paikallaan ja alle 1,2 m/s: k = 0, harjannetta ei piirretä lainkaan.
  Harjanne seuraa veneen nykyistä asentoa joka ruutu (ei historiaa), myös
  käännöksissä.
- **Pinnan aallot:** kärkien korkeus on `surface_height(xz) + harjanteen
  korkeus` (sama aallokko kuin vedessä ja vanassa), joten harjanne ei uppoa
  aaltoihin eikä leiju niiden päällä.
- **Ei rungon läpi, ei sisältä:** kaikki kärjet ovat ääriviivalla tai sen
  ulkopuolella, ja varjostin hylkää rungon sisäpuolen (`inside_boat`) kuten
  vesi ja vana. Keulan nousu (`planing` ≤ 0,06 rad) nostaa keulaa n. 0,13 m,
  joten harjanteen sisäreuna (≤ 0,04 m) jää kyljen ja pohjan väliin
  näkymättömiin; FPV- ja yläkuvassa veneen sisään ei näy vettä.
- **Materiaali:** oma varjostin `shaders/bow_ridge.gdshader`, valaistu
  (ei unshaded) kuten vesi, jotta kohouma erottuu valosta ja varjosta:
  - väri sama kuin veden matala väri (`shallow_color` 0,13/0,12/0,07),
    taivaan heijastus Fresnelillä (`sky_color`, sama kuin vedellä)
  - sileä pinta (roughness ~0,1, specular kuten vedellä), jolloin rinne
    heijastaa taivaan ja auringon eri kulmassa kuin tasainen vesi
  - läpikuultava: alfa 0,6 harjalla → 0 sisä- ja ulkoreunalla ja
    harjanteen päissä (e(s) samaan tapaan), joten reunaa ei näe
  - normaalit lasketaan profiilin kaltevuudesta (kärkinormaalit), ei
    derivaatoilla; jos derivaattoja käytetään, ennen `discard`ia
  - yöllä valaistu materiaali tummuu itsestään auringon mukana; ei omaa
    hehkua. Varjoa ei heitetä.
- **Piirtojärjestys:** vesi → harjanne → vaahto. Viiksen kärjet saavat saman
  harjannekorkeuden (+0,025 m), ettei viiksi jää harjanteen alle.
- **Suorituskyky:** 2 kylkeä × noin 10 pituussegmenttiä × 4 poikkiväliä
  = noin 80 nelikulmiota venettä kohti, rakennetaan joka ruutu samaan
  tapaan kuin vana (ImmediateMesh). Pelaaja + 2 vierasta venettä ≈ 240
  nelikulmiota.

### Keularoiske (vain kun v ≥ 5,0 m/s)
- Pieniä valkoisia pisaroita (samaan tyyliin kuin haavin tippuvat pisarat
  `landing_net.gd`, `CPUParticles3D`) molemmilta keulaolkapäiltä
  keula-aallon alkupisteestä: lentävät ulos ja hieman taakse
  (0,8–1,8 m/s sivulle, 0,5–1,2 m/s ylös), putoavat painovoimalla
  takaisin veteen, elinaika 0,5 s. Määrä 0 → 40 pisaraa/kylki k:n mukaan
  (v 5,0 → 7,8 m/s). Väri vaalea vedensininen-valkoinen, puoliläpinäkyvä,
  himmenee yöllä kuten vaahto. Ei varjoa.
- Kuvissa roiske näkyy keulan sivulla hentona sumuna, ei suihkulähteenä.
- Roiske tehdään (PÄÄTÖS 2).

### Peräaalto
- **Ei rakoa:** kulku-uoma ja sivuaallot jatkuvat uusimmasta näytteestä
  nykyiseen peräpeiliin asti (yksi lisänauha "elävään" peräpisteeseen).
- **Pehmeä alku:** kulku-uoman alfa kasvaa perästä 0:sta täyteen 1,2 m:n
  matkalla (smoothstep etäisyydestä peräpeiliin), joten poikkiviivaa ei näy.
  Alkureuna on lisäksi epätasainen (sama kohina kuin reunoissa).
- **Kapeampi alku:** puolileveys iässä 0 = 0,5 m (peräpeilin levyinen
  potkurivirta), kasvaa `0,5 + ikä · (0,1 + 0,02 · speed)` m. 7,8 m/s:ssa
  4 s vanhana 1,52 m (nyt 1,55 m), joten loppupää näyttää samalta kuin nyt.
- **Pehmeät, rikkonaiset reunat** (kulku-uoma ja Kelvinin aallot): alfa
  laskee reunaa kohti nollaan. Kulku-uomassa häivytys uloimmalla 35 %:lla
  puolileveydestä; sivuaalloissa koko poikkileikkaus on pehmeä (huippu
  keskellä, 0 reunoilla). Häivytysrajaa siirtää maailman koordinaateista
  laskettu kohina ±15 % puolileveydestä, joten reuna on aaltoileva eikä suora.
- **Sivuaallot:** puolileveys 0,18 → 0,3 m (pehmeä profiili näyttää muuten
  ohuemmalta), alkukohta perässä 0,6 → 0,82 m sivulle (keula-aallon
  jatkeeksi, peräpeilin ulkopuolelle). Alfa 0,55 ennallaan.
  `other_boat.gd` peräaaltofysiikan 0,6 m (`wake_wave`) jätetään ennalleen:
  ero 0,2 m ei näy keinunnassa.
- Kuvio pysyy vaaleana vaahtona samalla värillä kuin nyt.

### Äänet
- Ei uusia ääniä. Vauhti voimistaa jo nyt kyljen liplatusta
  (`game_audio.gd:277`, `lap`), ja moottori peittää muun. Ei uutta ääntä (PÄÄTÖS 3).

## Toteutus pääpiirteissään
- `scripts/boat/wake.gd`:
  - Uusi rajapinta veneen nykyiselle asennolle joka fysiikkaruudulla,
    esim. `track(stern, right, speed)` rinnalle `set_hull(pos, forward,
    forward_speed)` tai `track`-funktioon lisäparametrit. Keula-aallon
    viiksiin ja peräpään "elävään" nauhaan tarvitaan veneen keskipiste,
    suunta ja nopeus eteenpäin.
  - Keula-aallon nauhat rakennetaan `_rebuild`:ssa ääriviivasta
    (`Boat.OUTLINE`, samat mitat kuin `HULL_STATIONS`) muutaman
    segmentin murtoviivana, jotta ne seuraavat kyljen kaarta.
  - Kulku-uoman ja sivuaaltojen leveys- ja alfafunktiot suunnitelman lukujen
    mukaan; poikkileikkauksen pehmeys joko lisäkärjillä (reuna alfa 0,
    sisäkärjet täysi) tai välittämällä poikittainen koordinaatti
    (UV, −1 … 1) ja nauhatyyppi varjostimelle. Suositus: UV, koska silloin
    kohinareuna on varjostimessa.
  - Harjanne: oma `MeshInstance3D`-lapsi (top_level, ImmediateMesh,
    varjo pois) omalla materiaalilla (`shaders/bow_ridge.gdshader`,
    `#include waves.gdshaderinc`: `surface_height`, `inside_boat`).
    Materiaali esim. `Wake.ridge_material`.
  - Roiske: kaksi `CPUParticles3D`-lasta (top_level), joiden paikka, suunta
    ja `amount_ratio`/`emitting` päivitetään joka ruutu.
- `shaders/wake.gdshader`: reunan ja alkureunan häivytys ja kohina
  UV:n perusteella. **Jos käytetään derivaattoja (`fwidth`, `dFdx`), ne
  lasketaan ennen `discard`ia** (CATCHFISH-120-windows: NVIDIA antaa
  nolladerivaatat `discard`in jälkeen).
- `scripts/boat/boat.gd:463` ja `scripts/boat/other_boat.gd:269`: kutsuihin
  veneen asento ja nopeus eteenpäin (`velocity.dot(fwd)`). Vieraat veneet
  saavat keula-aallon ja harjanteen samasta luokasta (PÄÄTÖS 4).
- `scripts/main.gd`: harjanteen materiaali saa samat uniformit kuin
  vanan materiaali (`Waves.apply`, `boat_pos`, `boat_yaw`, `other_boats`,
  `other_boat_count`, `sky_color`) pelaajalle ja vieraille veneille
  (`main.gd:469–493`).
- `scripts/main.gd`: uusi lippu `--waketest` ja `--wakeshots=KANSIO`;
  `tools/run_tests.sh`: `--waketest` sarjaan; `docs/plan.md`, osio *Testaus*:
  kuvaskripti listaan.
- Suorituskyky: viikset lisäävät ~2 × 6 nelikulmiota ja elävä perän nauha
  3 nelikulmiota, harjanne ~80 nelikulmiota venettä kohti, roiske enintään
  80 partikkelia. `--perftest`-ajo ennen ja
  jälkeen; ei saa näkyvästi hidastaa.
- README ja `docs/plan.md`: lyhyt maininta keula-aallosta ja pehmeästä
  peräaallosta. F1-ohjeeseen ei muutosta (ei näppäimiä).

### Testi `tests/wake_test.gd` (`--waketest`, headless)
Luo `Wake`-solmun ja syöttää sille suoran ajon fysiikkaruuduittain
(ei koko peliä tarvita, mutta `main`-ympäristö kelpaa), ja tarkistaa
`_verts`/`_colors`-taulukoista (tai testiä varten lisätystä apufunktiosta):
1. 7,8 m/s eteenpäin 6 s: keulan alueella (rungon etupuolisko, ääriviivasta
   ≤ 0,5 m ulospäin) on vaahtokärkiä molemmin puolin, suurin alfa
   0,55–0,65; yksikään keula-aallon kärki ei ole rungon ääriviivan sisällä.
2. 1,0 m/s: keula-aallon kärkiä ei ole. 1,5 m/s: alfa ≤ 0,05.
3. Peruutus 3,2 m/s (nopeus eteenpäin negatiivinen): keula-aallon kärkiä ei
   ole, roiske ei emittoi.
4. Roiske emittoi 7,8 m/s:ssa, ei 4,4 m/s:ssa.
5. Peräaallon alku: kulku-uoman kärki on enintään 0,1 m:n päässä nykyisestä
   peräpisteestä (ei rakoa), ja perän kohdalla (≤ 0,1 m) alfa ≤ 0,05;
   1,5 m perän takana alfa ≥ 90 % huipusta.
6. Kulku-uoman leveys perän kohdalla ≤ 1,1 m (nyt 2,1 m).
7. Reunat: jos pehmeys tehdään kärjillä, jokaisen nauhan uloimpien kärkien
   alfa on 0; jos UV:lla, uloimpien kärkien |u| = 1 (ja varjostin häivyttää).
8. Pysähdyksen jälkeen (v = 0, 1 s): keula-aallon kärkiä ei ole.
9. Harjanne 7,8 m/s: suurin korkeus (pinnan yläpuolella, aallokko 0)
   0,09–0,11 m; 4,4 m/s: 0,05–0,07 m; 1,0 m/s, peruutus 3,2 m/s ja
   paikallaan: ei kärkiä (tai kaikki korkeus 0 ja alfa 0).
10. Harjanteen kaikki kärjet ovat rungon ääriviivalla tai ulkopuolella
    (etäisyys ≥ −0,01 m) ja enintään 0,65 m ääriviivasta.
11. Harjanteen ja viiksen reuna- ja päätykärkien alfa on 0; harjan alfa
    0,55–0,65 täydessä vauhdissa.
12. Viiksen kärkien korkeus ≥ harjanteen korkeus samassa kohdassa.

### Kuvat `tests/wake_shots.gd` (`--wakeshots=KANSIO`, ikkuna)
Kuten `motor_speed_test.gd`: suora syvä väylä (> 2,5 m, ~180 m), tuuli 0,
klo 12, vene pidetään suunnassa ja HUD:n ohjeet piilossa
(`GameInput.force_active`, `hud.set_paused_view(false)`). Kuvat:
- `01-28kmh-takaa-ylhaalta`, `02-28kmh-keula-sivulta`,
  `03-28kmh-keula-edesta`, `04-28kmh-pera-lahelta`, `05-28kmh-ylhaalta`
- `06-16kmh-ylhaalta` (4,4 m/s, vieraan moottoriveneen vauhti)
- `07-soutu-ylhaalta` (1,5 m/s)
- `08-peruutus-ylhaalta` (peruutuskaasu −0,4)
- `11-28kmh-harjanne-matalalta` (kamera kyljen vierellä 0,4 m korkeudella,
  4 m sivussa, katse keulaolkapäähän: kohouma erottuu horisonttia vasten)
- `12-28kmh-fpv` (FPV-kamera: veneen sisällä ei vettä)
- `09-28kmh-kaannos-ylhaalta` (täysi kaasu, ohjaus täysin sivuun 2 s)
- `10-28kmh-ilta` (klo 22,5, vaahto ja roiske himmeinä)
Apuskriptin pohja (designerin kokeilu, ei repossa):
`/tmp/claude-1000/-home-teekar-projektit-catchfish/cd82cab9-5bb8-42a9-b83a-d1ceb3ba0e58/scratchpad/wakeshot.gd`.

## Hyväksymiskriteerit
- [ ] 28 km/h:ssa keulan molemmilta puolilta lähtee vaahtoviiksi, joka
      kulkee kylkeä pitkin ja jatkuu perän takana Kelvinin sivuaaltona
      (kuvat 01, 02, 05).
- [ ] 28 km/h:ssa keulan kyljissä näkyy matala läpikuultava vesikohouma,
      joka on korkein keulaolkapäällä ja sulautuu pintaan kyljen
      puolivälissä; sivukuvassa kohouma erottuu, reunoja ei näe
      (kuvat 02, 11).
- [ ] Harjanne ei pistä rungon läpi eikä näy veneen sisällä (kuvat 05, 12).
- [ ] Harjanne on 16 km/h:ssa matalampi, soudettaessa ei näy, peruuttaessa
      ja paikallaan ei ole (kuvat 06–08).
- [ ] Yöllä harjanne tummuu veden mukana eikä hohda (kuva 10).
- [ ] 28 km/h:ssa keulaolkapäiltä lentää hentoja roiskepisaroita, jotka
      putoavat veteen (kuvat 02, 03); 16 km/h:ssa ei roisketta (kuva 06).
- [ ] 16 km/h:ssa keula-aalto näkyy heikompana; soudettaessa korkeintaan
      tuskin näkyvä; peruuttaessa ja paikallaan ei lainkaan (kuvat 06–08).
- [ ] Keula-aalto seuraa keulaa käännöksessä eikä jää irralleen (kuva 09).
- [ ] Peräaalto alkaa peräpeilistä ilman rakoa ja ilman suoraa poikkiviivaa;
      alku on noin peräpeilin levyinen (kuvat 04, 05).
- [ ] Kulku-uoman ja sivuaaltojen reunat ovat pehmeät ja aaltoilevat, eivät
      suorat viivat (kuva 05, suurennos).
- [ ] Rungon sisälle ei piirry vaahtoa eikä pisaroita veneen sisään.
- [ ] Vieraiden moottoriveneiden vanassa on sama keula-aalto, harjanne
      (4,4 m/s: k ≈ 0,6) ja pehmeä peräaalto, ei roisketta (PÄÄTÖS 4,
      `--otherboatshots` kuva 3).
- [ ] Yöllä (kuva 10) vaahto ja roiske eivät hehku valkoisina.
- [ ] Jäällä vanaa ja roisketta ei näy (`wake.visible = false`, `boat.gd:157`;
      roiske samoin).
- [ ] Uusi `--waketest` ja koko testisarja (`tools/run_tests.sh -q`) läpi.
- [ ] `--perftest` (sis. vieraat veneet): ruudun aika ei kasva yli 0,3 ms nykyisestä.
- [ ] Designer tarkistaa kuvat sekä WSL:n RTX 4050 -ajolla että Windowsin
      NVIDIA-ajurilla (varjostinmuutos).
- [ ] README ja `docs/plan.md` päivitetty, `--wakeshots` listattu osioon
      *Testaus*.

## Avoimet kysymykset Teemulle
Kaikki ratkaistu 6.11.2026, ks. *Päätökset*. Alkuperäiset vaihtoehdot alla.

1. **(Ratkaistu: 1b)** **Onko keula-aalto vain vaahtoa vai nouseeko vesi?**
   a) Litteä vaahtoviiksi + roiske, vesipinta ei nouse (kuten nykyinen
      peräaalto) – **suositus**, halpa ja sopii nykyiseen tyyliin.
   b) Lisäksi keulan kylkiin matala läpikuultava vesiharjanne (oma mesh,
      ~0,1 m korkea), joka näkyy sivukuvassa kohoumana.
   c) Vesipinta oikeasti nousee keula- ja peräaallon kohdalla
      (`water.gdshader`, iso muutos, oma tehtävä).
2. **(Ratkaistu: 2a)** **Keularoiske**
   a) Kyllä, pisarat ≥ 5,0 m/s (~18 km/h) kuten yllä – **suositus**.
   b) Ei roisketta, pelkkä vaahtoviiksi.
   c) Roiske jo ≥ 4,4 m/s, jolloin myös vieraat moottoriveneet roiskivat.
3. **(Ratkaistu: 3a)** **Ääni keula-aallolle**
   a) Ei uutta ääntä, nykyinen nopeuden mukaan voimistuva liplatus riittää
      – **suositus**.
   b) Uusi kohiseva vesiääni (keulan "suhina"), joka voimistuu nopeuden
      mukaan yli 4 m/s; tehtäisiin `tools/`-äänityökalulla.
4. **(Ratkaistu: 4a)** **Vieraat veneet** (sama `Wake`-luokka; CATCHFISH-108:ssa niiden
   ajo päätettiin pitää "täsmälleen ennallaan", mutta se koski nopeutta):
   a) Saavat saman keula-aallon ja pehmeän peräaallon (4,4 m/s: viiksi
      alfa ~0,36, ei roisketta) – **suositus**, yhtenäinen ulkoasu.
   b) Vain pehmeä peräaalto, ei keula-aaltoa.
   c) Ei muutosta vieraisiin veneisiin.
5. **(Ratkaistu: 5a)** **Peräaallon alku: pehmeä vai valkoinen potkurivirta?** Oikeasti
   perän takana vesi on kuohuvinta. Suunnitelmassa alfa nousee 0:sta
   täyteen 1,2 m:n matkalla.
   a) Kuten suunnitelmassa (0 → täysi 1,2 m) – **suositus**.
   b) Alku 40 %:n alfalla ja täyteen 0,6 m:ssä (valkoisempi heti perässä,
      mutta ilman suoraa poikkiviivaa kohinan ansiosta).

## Päätökset (Teemu 6.11.2026)
- PÄÄTÖS 1: Keula-aalto = vaahtoviikset **+ matala läpikuultava vesiharjanne**
  (oma mesh, ~0,1 m korkea, vaihtoehto 1b). Vesipinta (`water.gdshader`) ei muutu.
- PÄÄTÖS 2: Keularoiske kyllä, v ≥ 5,0 m/s (2a).
- PÄÄTÖS 3: Ei uutta ääntä (3a).
- PÄÄTÖS 4: Vieraat veneet saavat saman keula-aallon (myös harjanteen) ja pehmeän peräaallon (4a).
- PÄÄTÖS 5: Peräaallon alku 0 → täysi 1,2 m:n matkalla (5a).
- PÄÄTÖS 6 (työnjohtaja): Harjanteen harjan alfa = 0,6 · min(1, k / 0,3), eli täysi 0,6 vasta k ≥ 0,3 (≈ 2,8 m/s). Perustelu: soudussa harjanteen ei pidä näkyä läikkänä. Testi 11 (alfa 0,55–0,65 täydessä vauhdissa) ennallaan.
- PÄÄTÖS 7 (työnjohtaja): Viiksen loppupää häivytetään 0,3 m:n matkalla vain, kun viiksi loppuu ennen peräpeiliä (häivytys pienenee jatkuvasti k:n mukaan); peräpeiliin asti ylettyvä viiksi jatkuu täydellä alfalla Kelvinin sivuaaltoon ilman aukkoa. Testi 11 tarkistaa kärjen, reunat ja vapaan loppupään; lisätarkistus: k = 1:llä viiksen ja Kelvinin aallon liitoskohdassa ei alfa-aukkoa.
