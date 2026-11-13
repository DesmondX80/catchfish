# CATCHFISH-171: Testien determinismi ja epävakaat testit (--seed, sää kiinni)
v1 klo 11:41

## Tavoite

Testin tulos riippuu vain koodista, ei arpaonnesta. Tehtävässä on kolme osaa:

1. `--seed=N` kiinnittää pelin kaikki satunnaislukugeneraattorit (sää,
   kalakanta, kalastus, linnut, muut veneet, äänet, puhe ja globaali `randf()`).
   Siemen kirjoitetaan aina lokiin, joten kaatuneen ajon voi toistaa samoilla
   arvoilla (Plane-alitehtävä 166).
2. Sää pysäytetään yhteisellä apufunktiolla jokaisessa testissä, joka ei testaa
   itse säätä. Tällöin testi on deterministinen myös ilman `--seed`iä
   (alitehtävä 165).
3. Listan epävakaat testit korjataan juurisyyn mukaan: pressuretest,
   sonartest, motorspeedtest, boattest, settingstest ja lisäksi tutkimuksessa
   löytyneet anchortest ja docktest.

Tavoitteena on, että jokainen listan testi menee läpi `--repeat=10`:llä. Muussa
tapauksessa syy on selvitetty ja testi korjattu, tai testi merkitään
tunnetusti epävakaaksi.

## Toiminta pelaajan kannalta

Pelaajalle ei muutu mitään. Sää, kalakanta ja muu satunnaisuus arvotaan
edelleen joka käynnistyksellä eri tavalla: ilman `--seed`iä siemen arvotaan
kellosta, kuten nyt.

Kehittäjälle:

- `godot ... -- --seed=12345 --boattest` arpoo kaiken siemenestä 12345.
  Kaksi samanlaista ajoa antaa samat tulosrivit (headless, `--fixed-fps 30`).
- Ensimmäinen pelin tulostama rivi on aina `Siemen: N (toista: --seed=N)`.
  Rivi tulee myös ilman lippua ja tavallisessa pelissä (vain stdout, ei
  näy käyttöliittymässä).
- Siemen luetaan `Main._ready`n alussa. "Mene kotiin" lataa pääscenen
  uudelleen, jolloin siemen arvotaan uudelleen; `--seed`illä käytetään
  sama siemen uudestaan.
- `tools/run_tests.sh --seed=N` välittää lipun jokaiselle testille. Kaatuneen
  ajon tulosrivi kertoo siemenen:
  `>> VIRHE         sonartest [3/10]  8 s (koodi 1, siemen 2718281828)`.

## Ulkoasu ja äänet

Ei muutoksia. Kuvia ei tarvita (vain testit, testiajuri ja siemenen välitys).

## Juurisyyt

Merkinnät: **todennettu** = toistettu ajamalla tai näkyy lokista; **arvaus** =
paras hypoteesi, ei todennettu. CI-lokit on haettu kaikista epäonnistuneista
*Testit*-ajoista 29.10.–13.11. (19 kpl). CATCHFISH-160 (commit 5894df3,
12.11. klo 10.46) pysäytti sään pressure-, boat- ja motorspeedtestissä.

### pressuretest (Plane: raportoitu kolmesti)

- **Todennettu:** kaikki CI:n pressuretest-kaatumiset (13 ajoa, 29.10.–12.11.
  klo 6.44) ovat ajalta ennen CATCHFISH-160:tä ja kaikissa sama rivi "sään
  selkeytyessä paine nousee ...". Juurisyy ja korjaus: CATCHFISH-160
  (`_change_in = INF`).
- **Todennettu (10 ajoa, tämä haara):** 10/10 läpi, säärivit joka ajolla samat
  (1021 hPa, nousee nopeasti, kerroin 0.85).
- **Todennettu:** jäljelle jää yksi vaihteleva rivi, "laskevassa paineessa
  iskuja enemmän" (1470–1528 / 1015–1085). Suhde on 22 ajossa ollut
  1,37–1,48, ja raja on > 1,3. Vaihtelu tulee satunnaisesta kalakannasta
  (`FishPopulation._rng.randomize()`). Marginaali riittää; `--seed`
  kiinnittää rivin.
- Korjaus: ei muutoksia testiin. Sää-apufunktiota ei käytetä, koska testi
  käyttää omaa `Weather`-oliotaan ja testaa nimenomaan säätä.

### motorspeedtest (alitehtävä 146: peruutus 10,88–10,91 km/h, raja 11,0)

- **Todennettu:** CI:n ainoa kaatuminen ("peruutusnopeus 10.95 km/h",
  ajo 43170227026) on ajalta ennen CATCHFISH-160:tä. Syy oli elävä tuuli
  (CATCHFISH-160:n suunnitelma).
- **Todennettu (10 ajoa):** 10/10 läpi, peruutusnopeus joka ajolla 11.53 km/h,
  kaikki rivit samat. Satunnainen alkuaallokko (ks. sää-apufunktio) ei vaikuta
  nopeuteen.
- Korjaus: nykyinen käsin kirjoitettu sään pysäytys korvataan
  apufunktiolla. Lukujen pitää pysyä samoina.

### boattest "jalat veneen sisällä kalastaessa" (alitehtävä 112: 3/60)

- **Todennettu:** CI:ssä kaatunut neljästi (40872603800, 42232930666,
  42232930688, 42413921077), kaikki ennen CATCHFISH-160:tä. Syy oli tuuli,
  joka käänsi veneen ja sai kalastajan istumaan vinossa
  (CATCHFISH-160:n suunnitelma, raja noin 16°).
- **Todennettu (40 ajoa tällä haaralla):** 40/40 läpi. Ainoa vaihteleva rivi on
  "ankkuria lasketaan (syvyys 6.1 / 6.2 m)", koska syvän paikan haku käyttää
  globaalia `randf_range()`ia ilman siementä (`tests/boat_test.gd:101`).
- **Arvaus:** satunnainen alkuaallokko on yhä mukana. `main.gd:141` kutsuu
  `Waves.reset(weather.wind_base, ...)` arvotulla 1–5 m/s:n tuulella ennen
  testin `_ready`ä, ja aallokko laantuu noin 20 peliminuutissa, joten
  koko 9 sekunnin testin ajan vene keinuu satunnaisessa aallokossa.
  40 ajossa tämä ei kaatanut testiä.
- Korjaus: sää-apufunktio, joka nollaa myös aallokon (`Waves.reset`).
  Globaali `seed()` (`--seed`) kiinnittää syvän paikan haun.

### sonartest "vene ajaa kalan yli" (alitehtävä 123: 1/8)

Kaksi erillistä syytä, molemmat testissä:

1. **Todennettu (diagnostiikka 20 ajossa, kaatui 1):** kaatuneessa ajossa
   ensimmäinen kaiku (1,46 m) tuli sarakkeesta, joka luettiin heti
   `_prepare_pass`in jälkeen. Vene oli silloin vielä aloituslaiturilla, ja
   sen alla oli satunnaisesti ahvenparvi. Vene siirretään ylityksen alkuun
   vasta seuraavalla fysiikka-askeleella (vaihe 1). Kaiku oli lähin, joten
   "kaari" alkoi pienimmästä etäisyydestä ja tarkistus kaatui. Sama kuvio
   näkyy CI:ssä (ajo 40895344529: "1.21 m → 1.21 m → 3.53 m") ja tämän
   haaran toistossa ("1.62 m → 1.62 m → 3.40 m", 1/10).
2. **Todennettu (Python-simulointi `EchoSounder`in kaavalla + prototyyppi
   30 ajoa):** testi valitsee kalakannasta ensimmäisen yli 1 kg:n kalan.
   Kalan uiskentelun suunta ja tahti tulevat sen indeksistä
   (`EchoSounder._rand(k, 5..7)`). Indeksi on 0, 1, 2 tai harvoin 3
   satunnaisen hauen painon mukaan. Indeksillä 3 kala uiskentelee 292°:n
   suuntaan, lähes kohtisuoraan ajolinjaa vastaan, ja on ylityksen aikana noin
   2,8 m sivussa. Pienin etäisyys on 2,93–2,97 m (raja < 2,5), joten
   tarkistus kaatuu aina. Simulointi: indeksit 0, 1, 2 ja 5 → 40/40 läpi,
   indeksi 3 → 0/40, indeksi 4 → 7/40. Prototyypissä indeksi 3 osui kerran
   30:stä ja kaatui ("3.60 m → 2.93 m → 3.49 m").

Korjaus (prototyypattu): testi siirtää veneen ylityksen alkuun jo
`_prepare_pass`issa ja lukee vain ylityksen alun jälkeen otetut sarakkeet.
Kalaksi valitaan aina indeksi 0, jonka paino asetetaan 2,0 kg:ksi.
Prototyypissä 20/20 läpi ja kaikki rivit samat: "19 kaikua, 3.45 m → 2.02 m
→ 3.40 m" ja "139 kaikua, 2.00–3.58 m".

### anchortest "tuulessa pohjasta nostettaessa köysi ei kulkenut rungon läpi"

Testi on epävakaiden listalla, mutta ei Planen alitehtävissä.

- **Todennettu:** CI 42232930666 (6.11.) ja tämän haaran toisto 1/10.
- **Todennettu (prototyyppi):** kun sää pysäytetään apufunktiolla, 10/10 menee
  läpi ja kaikki rivit ovat samat 10 eri satunnaissiemenellä.
- **Todennettu (prototyyppi, alkutuulen suunta 0,0 / 1,6 / 2,4 / 3,2 / 4,0 /
  4,7 / 5,5 rad):** suunnalla 2,4 rad sama tarkistus kaatuu joka kerta,
  muilla se menee läpi. Testi asettaa tuulen veneen suhteen (sivutuuli),
  mutta alkuaallokon suunta jää `Waves.reset`istä vanhaksi
  suuntasarjaksi ja ristihäivyttyy myrskyn aallokkoon. Tietyssä
  aallokon suunnassa näkyvä köysi kulkee `_behind_stem`-mittarin mukaan
  rungon läpi.
- **Arvaus:** tämä on pelin käytös (köysi rungon läpi 10 m/s:n tuulessa
  tietyssä aallokossa), ei pelkkä testin vika. Ei kuvattu. Ks. avoin kysymys T1.
- Korjaus tässä tehtävässä: sää-apufunktio oletussuunnalla 0,6 rad (läpi
  joka kerta).

### docktest (uusi löydös, ei listalla)

- **Todennettu:** mainin CI-ajo 43388507534 (13.11., commit 075b40f) kaatui:
  "kota, kärkeen: runko ei mennyt kannen alle (syvin 0.19 m)", raja < 0,08.
- **Todennettu (10 ajoa):** 10/10 läpi, mutta "vene liukui laituria pitkin"
  vaihtelee 2,8–5,5 m ja kolahdusten määrä 1–2. Testi ei kiinnitä säätä,
  joten satunnainen tuuli (1–5 m/s ja puuskat) työntää venettä.
- **Arvaus:** CI:n 0,19 m syntyi puuskasta laiturin kärkeä vasten.
  Paikallisesti ei toistunut.
- Korjaus: sää-apufunktio.

### settingstest "jää jumiin ikkunassa" (alitehtävä 122)

- **Todennettu:** näytönohjaimella 6/6 läpi, 34–35 s/ajo. Ohjelmistorenderöijällä
  (llvmpipe) 1/1 läpi, 158 s.
- **Arvaus:** "jumi" on llvmpipe-ajo, joka näyttää jumilta (4–5-kertainen
  kesto, `docs/plan.md`:n huomautus 0.30.0:sta), tai oikea ikuinen silmukka.
  Testissä on kaksi tapaa jäädä pyörimään ilman aikarajaa:
  (a) `_button(...)` palauttaa `null` (painiketta ei löydy tai se ei ole
  näkyvissä), jolloin `_click(null)` kaatuu ajonaikaiseen virheeseen ennen
  `_next()`iä ja sama vaihe toistuu joka ruudulla (vaiheet 0, 3 ja 4);
  (b) vaiheessa 9 `split("\n")[1]` kaatuu, jos HUD-tekstissä on vain yksi rivi.
  Vain vaiheissa 3 (25 s) ja 7 (40 s) on aikaraja. Planen 122:n alkuperäistä
  kuvausta ei ole luettu, ks. kysymys L4.
- **Todennettu (sivulöydös):** vaiheen 9 tarkistus "HUD näyttää lämpötilan"
  tulostaa väärän rivin ("Saavi: 0 kalaa ..."), mutta menee läpi, koska
  `"°C" in text` etsii koko tekstistä.
- Korjaus: koko testille vahtiajastin seinäkellolla ja painikkeiden
  null-tarkistus (ks. toteutus).

### Muut CI-havainnot (ei tässä tehtävässä)

- trollstriketest "kädet täynnä: käsivapa jäi käteen" kerran haarassa
  `claude/audio-log` (40897777493). Mainissa ei ole toistunut. Kirjataan vain tiedoksi.

## Toteutus pääpiirteissään

Pelikoodiin tulee vain siemenen välitys. Pelin käytös ei muutu.

### 1. `scripts/game_seed.gd` (uusi, `class_name GameSeed`, ei autoload)

- `static var base: int`.
- `static func setup() -> void`: lukee `--seed=N`:n
  (`OS.get_cmdline_user_args()`, N ≥ 0 kokonaisluku). Jos lippu puuttuu tai on
  virheellinen, arvotaan `randomize(); base = randi()`. Virheellisestä
  lipusta tulostetaan varoitus. Lopuksi `seed(base)` globaalille
  `randf()`ille ja tulostus `print("Siemen: %d (toista: --seed=%d)" % [base, base])`.
- `static func of(name: String) -> int`: alijärjestelmän oma siemen
  `("%d:%s" % [base, name]).hash()`. Näin yhden järjestelmän uusi arvonta ei
  muuta muiden lukuja.
- `Main._ready()`n ensimmäinen rivi: `GameSeed.setup()` (ennen
  `return_to_menu`-haaraa ja valikkotestejä).

### 2. Seitsemän `_rng.randomize()`-kutsua → `_rng.seed = GameSeed.of("<nimi>")`

| Tiedosto | Nimi |
|---|---|
| `scripts/world/weather.gd:70` | `weather` |
| `scripts/fishing/fish_population.gd:26` | `fish_population` |
| `scripts/fishing/fishing.gd:201` | `fishing` |
| `scripts/world/birds.gd:96` | `birds` |
| `scripts/boat/other_boats.gd:116` | `other_boats` |
| `scripts/audio/game_audio.gd:82` | `game_audio` |
| `scripts/audio/angler_voice.gd:82` | `angler_voice` |

Globaalin `randf()`/`randi()`n käyttäjät kiinnittyvät `seed(base)`illa:
`net_control.gd:171` (verkon `seed`), `fish_visuals.gd:15` ja testien
paikkahaut (`boat_test.gd:101`, `sync_test.gd:66`, `pike_follow_test.gd:105`,
`ice_test.gd:131`).

### 3. `tests/test_util.gd` (uusi, `class_name TestUtil`)

```
## Tyyni, pysäytetty sää ja aallokko sen mukaiseksi: sää ei muutu kesken testin
static func calm_weather(main: Node, wind := 0.0, direction := 0.6) -> void
```

Asettaa: `set_process(false)`, `real_mode = false`, `wind_base` ja
`_wind_target` = wind, `gust` ja `_gust_target` = 0, `_gust_timer` = INF,
`wind_direction` = direction, `kind` = CLEAR, `cloud_cover` ja
`_cover_target` = 0,1, `rain` ja `_rain_target` = 0, `pressure` ja
`_pressure_target` = 1013, `pressure_trend` = 0 (jolloin
`feeding_factor()` = 1,0), `_change_in` = INF, ja lopuksi
`Waves.reset(wind, direction)`. Oletussuunta 0,6 rad on `Weather`in oletus.
Designerin prototyyppi (ei commitoitu) oli tämä sama funktio.

Kutsu testin `_ready`ssä heti `main = get_parent()`n jälkeen, ennen testin
omia tuuliasetuksia. Testit, jotka asettavat tuulen itse (bait,
fight_depth, line, headwind, channel, prop, anchor `_gale`, wave_sound),
jatkavat niin, mutta sää ei enää elä niiden välissä. `wave_sound_test`
kutsuu apufunktiota voimakkuuskohtaisesti (`calm_weather(main, strength * 8.0, 0.0)`)
nykyisten neljän rivin tilalle.

Käyttäjät (36 testiä, kaikki `run_tests.sh`:n listalla):
anchor, angler, audio_log, bait, bird_sound, bird, boat, book, cast,
channel, dock, fight_depth, headwind, ice, lure, line, motor_speed, net,
other_boats, overlap, paddle, pike_follow, prop, release, seam, season_fish,
sonar, species, sync, tackle, troll, troll_strike, tub, voice, wake,
wave_sound. Nykyiset käsin kirjoitetut pysäytykset korvataan:
`boat_test.gd:18–22`, `motor_speed_test.gd:28–32`, `line_test.gd:42`,
`fight_depth_test.gd:43`, `other_boats_test.gd:_calm` (säärivit; `sky.minutes`
jää), `anchor_test.gd:_calm` (jää ennalleen, koska se nollaa tuulen
kesken testin, mutta `_ready` kutsuu lisäksi apufunktiota).

Ei apufunktiota: pressuretest (testaa säätä omalla oliollaan), wavetest
(ensimmäinen tarkistus mittaa pelin alun aallokkoa ja muut asettavat
`Waves`in itse), shopbgtest (valikkotesti, `main.weather` on null),
settingstest (todellinen sää).

### 4. sonartest (`tests/sonar_test.gd`)

- `_prepare_pass`: kalaksi aina `main.population.fish[0]`, paino 2,0 kg,
  paikka ja syvyys kuten nyt. Muut kalat siirretään kuten nyt.
- Vaihe 0: `boat.pos = _start`, `boat.velocity = Vector2.ZERO` ja
  `_pass_sample = main.hud.sounder._sample` heti `_prepare_pass`in jälkeen.
- `_check_arc`: vain sarakkeet, joiden `seed > _pass_sample`.
- Rajat (`low >= 1.98 and low < 2.5`, kaari) ennallaan.

### 5. settingstest (`tests/settings_test.gd`)

- Vahtiajastin: `_ready`ssä `_started_ms = Time.get_ticks_msec()`. Jos
  `_process`issa on kulunut yli 180 s, tulee
  `VIRHE settingstest: aikaraja 180 s ylittyi vaiheessa %d` ja `_done()`.
- `_click`: jos control on null, tulee `VIRHE painiketta ei löytynyt
  (vaihe %d)` ja `_done()`. Ajonaikaista virhettä ei synny.
- Vaihe 9: lämpötilarivi haetaan riveistä, joissa on "°C", ja se tulostetaan
  tarkistukseen. Ehto ("°C" HUD-tekstissä) ennallaan.
- Vaiheiden 3 ja 7 aikarajat (25 s ja 40 s) ennallaan.

### 6. `tools/run_tests.sh` ja `tools/run_tests_selftest.sh`

- Uusi lippu `--seed=N` (N ei-negatiivinen kokonaisluku, muuten
  `usage_error`): `--seed=N` lisätään jokaisen testin argumenttien loppuun
  (kaikissa on `--`). `usage`-riville ja otsikkokommenttiin.
- Kun ajo epäonnistuu (VIRHE tai AIKAKATKAISU), tulosriville lisätään siemen
  Godotin tulosteen `Siemen: N` -riviltä: `(koodi 1, siemen N)`. Toistoajon
  taulukkoon sama ensimmäisen epäonnistuneen ajon VIRHE-rivien alle:
  `    toista: tools/run_tests.sh --seed=N <nimi>`.
- Uusi testi listaan: `"seedtest|--fixed-fps 30 -- --day=180 --seed=171 --seedtest"`.
- Selftest: valekomento tulostaa `Siemen: 42`, ja sen pitää näkyä luretestin
  VIRHE-rivillä (`siemen 42`) ja toista-rivillä. `--seed=5` välittyy
  valekomennolle (valekomento kaiuttaa argumenttinsa lokiin). `--seed=x` →
  paluukoodi 2.
- `.github/workflows/tests.yml` ennallaan (satunnainen siemen, ks. L1).

### 7. Uusi testi `tests/seed_test.gd` (`--seedtest`, headless)

`main.gd`:n testivalintaan `elif "--seedtest" in args`. Tarkistukset:

- `GameSeed.base == 171` (lippu luettiin).
- Kaikkien seitsemän järjestelmän `_rng.seed == GameSeed.of(nimi)`:
  `main.weather`, `main.population`, `main.fishing`, `main.birds`,
  `main.other_boats`, `main.audio`, `main.voice`.
- Kaksi uutta `Weather`-oliota (`add_child`, `_ready` arpoo) antavat samat
  `wind_base`, `wind_direction`, `kind` ja `pressure`. Kun
  `GameSeed.base` on tilapäisesti 172, ainakin yksi arvo eroaa (palautetaan
  171:ksi).
- Kaksi `FishPopulation.setup(main.lake)`-kutsua tuoreisiin olioihin antavat
  saman kalamäärän ja samat 50 ensimmäisen kalan `pos` ja `weight`.

### 8. Dokumentit

- `docs/plan.md` *Testaus*: kappale `--seed`istä (`Siemen:`-rivi, toisto
  `tools/run_tests.sh --seed=N NIMI`) ja `TestUtil.calm_weather`ista ("uusi
  testi kutsuu tätä, ellei se testaa säätä"); `--seedtest` testilistaan.
  *Tunnetusti epävakaat testit*: lista päivitetään tuloksen mukaan
  (työnjohtaja).
- `README.md` testiosio: rivi `tools/run_tests.sh --seed=12345 boattest   # toista kaatunut ajo samalla siemenellä`.
- F1-ohje ennallaan (ei pelaajalle näkyvää).

### Headless ja ikkunan koko

Ikkunan kokoa ei pakoteta. settingstest ajetaan ikkunassa näytönohjaimella
(`CLAUDE.md`, *Testaus*).

### Muutokseen liittyvät nykyiset testit

sonartest, boattest, anchortest, docktest, motorspeedtest, pressuretest,
settingstest, sekä kaikki kohdan 3 36 testiä, joihin apufunktio lisätään.
Lisäksi `tools/run_tests_selftest.sh`.

### Sivuvaikutuslista

| Muutettu asia | Käyttäjät (grep) | Tarkistettu |
|---|---|---|
| `_rng.randomize()` → siemen | 7 tiedostoa yllä; `cabin_scene.gd` (siemen 11), `catch_tub.gd` (17), `gill_net.gd` (21), `nets.gd` (hash), `lake_world.gd` (vakiot), `waves.gd` (77) ovat jo kiinteitä | tarkistettu |
| globaali `seed()` | `net_control.gd:171`, `fish_visuals.gd:15`, testien `randf`-haut; `headwind_test`, `shadow_shots`, `foam_shots` ja `water_shots` kutsuvat itse `seed()`iä (jatkavat niin) | tarkistettu |
| `Main._ready` | valikko, `return_to_menu`, valikkotestit (`--settingstest=` ym.), testien `_start_game` | tarkistettu |
| `Weather`-sisäkentät apufunktiossa | testit, jotka koskevat säähän (grep `weather` tests/) | tarkistettu |
| `Waves.reset` testin alussa | wavetest (ei apufunktiota), seamtest ja overlaptest (käyttävät `Waves`ia; apufunktio tyyneksi muuttaa alkuaallokon, vaikutus nähdään ajossa) | ei tarkistettu ajamalla: seam- ja overlaptest |
| `feeding_factor` 1,0 testeissä (ennen arvottu 0,75–1,5) | troll, troll_strike, bait, lure, ice, species, voice, release | ei tarkistettu ajamalla |
| `run_tests.sh` | CI `tests.yml:51`, selftest, `docs/plan.md`, `README.md` | tarkistettu |
| `class_name` testikansiossa | ensimmäinen laatuaan; vienti `export_filter="all_resources"` vie `tests/`in jo nyt | tarkistettu |
| Pelaajan näkymä | ei käyttöliittymämuutoksia; `print` stdoutiin | tarkistettu |

## Hyväksymiskriteerit

Prototyyppi tehtiin designerin väliaikaiseen kopioon (ei commitoitu).

1. [ ] **Siemen lokiin.** `timeout 590 godot-4.7.2 --headless --fixed-fps 30 -- --day=180 --seed=42 --sonartest`
   tulostaa rivin `Siemen: 42 (toista: --seed=42)`. Kaksi ajoa ilman
   `--seed`iä tulostaa eri siemenen. *(Ei prototyypattu tällä tarkalla
   muodolla; tulostus prototyypattu.)*
2. [ ] **Sama siemen → sama tulos.** `tools/run_tests.sh -q --seed=42 --repeat=3 pressuretest boattest docktest sonartest anchortest motorspeedtest`:
   `grep -E '^(OK|VIRHE)' .test-logs/latest.log | sort | uniq -c` → jokainen
   rivi tasan 3 kertaa testiä kohden (ei vaihtelevia rivejä). *(Prototyypattu
   siemenellä 12345: pressuretest, boattest ja docktest 3/3 identtiset.)*
3. [ ] **Toistot ilman siementä.** `tools/run_tests.sh -q --repeat=10 sonartest boattest anchortest docktest motorspeedtest pressuretest`
   → 10/10 jokaisella. Sonar-, anchor-, dock- ja motorspeedtestissä jokainen
   rivi esiintyy 10 kertaa (sää kiinni, siemenestä riippumaton). Sallitut
   vaihtelevat rivit: pressuretest "laskevassa paineessa iskuja ... (n / m)"
   (kalakanta, suhde > 1,3) ja boattest "ankkuria lasketaan (syvyys ...)".
   Toistoajo taustalle valmismerkillä (*Pitkät ajot*). *(Prototyypattu:
   sonartest 20/20 identtiset, anchortest 10/10 identtiset, motorspeedtest
   10/10 identtiset jo nyt, boattest 40/40, pressuretest 10/10. docktest
   apufunktiolla ei prototyypattu.)*
4. [ ] **Luvut ennallaan.** motorspeedtest: peruutus 11.53 km/h, huippu ja
   kiihtyvyys samat kuin mainissa. sonartest: "19 kaikua, 3.45 m → 2.02 m →
   3.40 m" ja "139 kaikua, 2.00–3.58 m". pressuretest: säärivit 1025 / 0.79,
   1024 / −3.1 / 1.35 ja 1021 / 0.85.
5. [ ] **Rajat ennallaan.** `git diff origin/main -- tests/` ei muuta yhtään
   olemassa olevan tarkistuksen raja-arvoa eikä poista tarkistusta.
   Muutokset: uudet tarkistukset (seedtest, settingstestin aikaraja ja
   null-tarkistus) ja tarkistusten tekstit.
6. [ ] **seedtest** on `run_tests.sh`:n listalla ja menee läpi;
   `--repeat=10` 10/10 ja rivit samat.
7. [ ] **settingstest** näytönohjaimella 10 kertaa peräkkäin
   (`for i in $(seq 10); do GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA timeout 300 godot-4.7.2 --fixed-fps 30 --disable-vsync -- --settingstest=KANSIO; echo $?; done`):
   10/10 paluukoodi 0, kukin alle 60 s (nyt 34–35 s), lokissa `RTX 4050`.
   "HUD näyttää lämpötilan" -rivi näyttää °C-rivin. *(Nykytila prototyypattu:
   6/6 läpi.)*
8. [ ] **Koko sarja apufunktion kanssa.** `tools/run_tests.sh -q --repeat=3`
   (testaaja, taustalle noin 45 min) → kaikki läpi. Lisäksi verrataan
   `uniq -c`:llä, ettei yksikään testi vaihtele niin, että se kaatuu
   (ks. L3).
9. [ ] **run_tests.sh.** `tools/run_tests_selftest.sh` menee läpi uusilla
   tarkistuksilla (`siemen 42` VIRHE-rivillä, toista-rivi, `--seed=5`
   välittyy, `--seed=x` → 2). Kaatunut oikea ajo näyttää siemenen
   tulosrivillä.
10. [ ] **Mutaatiotarkistukset** (`docs/plan.md`, *Mutaatiotarkistus käsin*;
    muoto kirjataan *Päätöksiin*):
    - a) `echo_sounder.gd`: `var slant := f[0]` (vinoetäisyys ilman
      vaakaetäisyyttä) → sonartest kaatuu "vene ajaa kalan yli" (ei kaarta).
    - b) `weather.gd`: takaisin `_rng.randomize()` → seedtest kaatuu
      (`_rng.seed` ja kahden Weatherin vertailu).
    - c) `test_util.gd`: `set_process(false)` pois → `tools/run_tests.sh -q --repeat=5 docktest anchortest`
      näyttää vaihtelevia rivejä tai VIRHEen (ennen korjausta docktestin
      "liukui" 2,8–5,5 m ja anchortest 1/10 VIRHE).
    - d) `settings_test.gd`: `_button("Asetukset")` → `_button("Asetuksetx")`
      → testi päättyy VIRHEeseen "painiketta ei löytynyt" alle 180 s:ssa
      eikä jää jumiin.
11. [ ] **Dokumentit:** `docs/plan.md` *Testaus* (`--seed`, `TestUtil.calm_weather`,
    `--seedtest`) ja `README.md`:n testiosio päivitetty.

Ristiriitataulukko (sama paikka, useampi kriteeri):

| Paikka | Kriteerit | Yhtä aikaa? |
|---|---|---|
| sonartestin kalan valinta | 3 (identtiset rivit), 4 (samat luvut kuin nyt), 10a (mutaatio kaatuu) | kyllä: indeksi 0 antoi nykyiset yleisimmät luvut, mutaatio poistaa kaaren |
| apufunktio motorspeedtestissä | 3, 4 (11.53 ennallaan) | kyllä: alkuaallokko ei vaikuttanut nopeuteen 10 ajossa |
| apufunktio anchortestissä | 3 (läpi), T1 (suunta 2,4 kaatuu) | kyllä oletussuunnalla 0,6; suunta 2,4 on avoin kysymys |

## Avoimet kysymykset Teemulle

**T1. Ankkuriköysi kulkee rungon läpi myrskyssä tietyssä aallokossa.**
Prototyypissä alkutuulen suunnalla 2,4 rad anchortest kaatuu joka kerta
tarkistukseen "tuulessa pohjasta nostettaessa köysi ei kulkenut rungon läpi"
(10 m/s, ristihäivyttyvä aallokko). Muilla kuudella testatulla suunnalla
testi menee läpi. Todennäköisesti näkyvä köysi leikkaa keulan hetkellisesti
kovassa aallokossa; kuvaa ei ole otettu.
- A) Tässä tehtävässä vain testi deterministiseksi (suunta 0,6 rad). Köyden
  kulusta tehdään Backlog-tehtävä, jossa designer kuvaa tilanteen ensin
  (`--anchortest-shots`, suunta 2,4).
- B) Tutkitaan ja korjataan tässä (köyden pisteet rungon ulkopuolelle myös
  aallokossa), anchortest ajetaan kaikilla seitsemällä suunnalla. Työ
  kasvaa ja vaatii kuvat.
- C) anchortest ajaa nostot kahdella suunnalla (0,6 ja 2,4) ja jää
  epävakaiden listalle, kunnes vika korjataan.
- **Oletus, jos ei linjata:** A.

**T2. Näytetäänkö siemen pelaajalle?** Siemen tulostuu vain stdoutiin, jota
Windows-exe ei näytä.
- A) Ei näytetä (vain kehittäjille).
- B) F1-ohjeen alareunaan pieni teksti "Siemen 2718281828", jotta pelaaja voi
  kertoa sen vikailmoituksessa.
- **Oletus, jos ei linjata:** A.

## Avoimet kysymykset työnjohtajalle

**L1. Siemen CI:ssä ja `run_tests.sh`:n oletus.**
- A) Satunnainen siemen jokaisella ajolla. Kaatunut ajo kertoo siemenen ja
  toistuu `--seed=N`:llä. Pitää esillä siemenestä riippuvat viat.
- B) Kiinteä siemen (esim. 171) oletuksena ja CI:ssä. Täysin toistettava,
  mutta siemenestä riippuva vika voi jäädä piiloon (esim. sonartestin
  indeksi 3).
- C) CI kiinteällä, paikallinen ajo satunnaisella.
- **Oletus, jos ei linjata:** A.

**L2. Sää-apufunktion käyttötapa.**
- A) Jokainen testi kutsuu `TestUtil.calm_weather(main)`ia itse
  (Planen "yhteinen apufunktio", näkyy testissä).
- B) `main.gd` pysäyttää sään automaattisesti kaikissa testiajoissa, ja
  säätä testaavat testit kutsuvat `TestUtil.live_weather(main)`ia. Uusi
  testi ei voi unohtaa pysäytystä, mutta käytös on piilossa.
- **Oletus, jos ei linjata:** A.

**L3. Toistomäärä koko sarjalle.** Apufunktio muuttaa 36 testiä. *Toistoajot*-
säännöllä (`--repeat=10` alle 60 s:n testeille) se tarkoittaisi noin 150 min.
- A) Listan seitsemän testiä `--repeat=10`, muut koko sarjana `--repeat=3`
  (noin 45 min taustalla, testaaja).
- B) Kaikki `--repeat=10` (noin 150 min).
- **Oletus, jos ei linjata:** A.

**L4. Planen alkuperäiset raportit.** Designer ei lukenut Planen tehtäviä
122 (settingstest-jumi), 112 (boattest 3/60), 123 ja 146. Jos 122 kertoo jumin
tapahtuneen näytönohjaimella tai jonkin muun vaiheen kuin yllä
mainittujen kohdalla, settingstestin korjaus voi olla väärä.
- A) Työnjohtaja tarkistaa 122:n ja 112:n kuvauksen ja kirjaa poikkeamat
  *Päätöksiin*.
- B) Edetään yllä olevilla hypoteeseilla (vahtiajastin kattaa kaikki
  vaiheet).
- **Oletus, jos ei linjata:** B, ja vahtiajastin varmistaa, ettei testi jää
  koskaan jumiin.

**L5. docktest ja anchortest epävakaiden listalla.** docktest ei ole Planen
alitehtävissä, mutta kaatui mainissa tänään. Korjataanko se samalla
apufunktiolla tässä tehtävässä?
- **Oletus, jos ei linjata:** kyllä, se kuuluu alitehtävään 165.

## Päätökset

PÄÄTÖS 1: T1 vaihtoehto A. Tässä tehtävässä anchortest tehdään vain deterministiseksi (suunta 0,6 rad). Ankkuriköyden kulku rungon läpi suunnalla 2,4 rad kirjataan Planeen omaksi Backlog-tehtäväksi, jossa designer kuvaa tilanteen ensin. Työnjohtaja ratkaisi rajauksen perusteella; Teemu priorisoi Backlog-tehtävän.

PÄÄTÖS 2: T2 vaihtoehto A. Siemen tulostuu vain stdoutiin eikä näy pelaajalle. Tehtävä koskee testejä, eikä käyttöliittymään lisätä mitään.

PÄÄTÖS 3: L1 vaihtoehto A. CI:ssä ja run_tests.sh:ssa siemen on oletuksena satunnainen ja kirjataan lokiin; --seed=N toistaa ajon.

PÄÄTÖS 4: L2 vaihtoehto A. Jokainen testi, joka ei testaa säätä, kutsuu TestUtil.calm_weather(main):ia itse.

PÄÄTÖS 5: L3 vaihtoehto A. Listan testit (pressure, sonar, motorspeed, boat, settings, anchor, dock) ajetaan --repeat=10; koko sarja --repeat=3 taustalla. Lisäksi boattest ajetaan --repeat=60, koska alkuperäinen raportti (112) oli 3/60 eikä 40/40 vielä sulje vikaa pois.

PÄÄTÖS 6: L4 vaihtoehto B, tarkistettu Planesta. 122: jumi tapahtui ikkunassa myös origin/mainissa (4ebfb83); koodaajalla --fixed-fps 30 -lipulla, testaajalla myös ilman sitä. Näytönohjaimesta ei ole mainintaa. Vahtiajastin (180 s) toteutetaan, ja testaaja ajaa settingstestin näytönohjaimella sekä --fixed-fps 30 -lipulla että ilman. Ajokomento kirjataan testitiedoston alkuun ja docs/plan.md:n testilistaan (122 vaatii). 112: L-jalan x oli kaatuessa noin −0,41…−0,46.

PÄÄTÖS 7: L5 kyllä. docktest korjataan samalla sää-apufunktiolla.

PÄÄTÖS 8 (koodaaja, työnjohtaja hyväksyi): `tools/run_tests.sh --seed=N` ei lisää lippua testille, jonka argumenteissa on jo oma `--seed=` (seedtest, `--seed=171`). Muuten seedtest saisi kaksi siementä, `GameSeed` lukisi viimeisen ja tarkistus "GameSeed.base = 171" kaatuisi. Selftest tarkistaa tämän ("seedtest pitää oman siemenensä"). Ei koske `origin/main`ia (lippu on uusi).

PÄÄTÖS 9 (mutaatioiden muoto, koodaaja):
- 10a: `echo_sounder.gd:55` `var slant := sqrt(f[0] * f[0] + dist * dist)` → `var slant: float = f[0]`. Suunnitelman muoto `var slant := f[0]` ei käänny (tyyppiä ei voi päätellä Variantista), jolloin peli ei käynnisty ja ajo päättyy aikakatkaisuun eikä testin VIRHEeseen; siksi tyypitetty muoto. Tulos: sonartest koodi 1, "vene ajaa kalan yli: ... 2.00 m → 2.00 m → 2.00 m" ja "vene paikallaan ... 2.00–2.00 m" VIRHE.
- 10b: `weather.gd` `_rng.seed = GameSeed.of("weather")` → `_rng.randomize()` → seedtest koodi 1, VIRHE "weather: siemen GameSeed.of(\"weather\")" ja "sama siemen, sama sää".
- 10c: `test_util.gd` rivi `w.set_process(false)` poistettu → `--repeat=5 docktest anchortest` 10/10 läpi, mutta anchortestin tuulirivit vaihtelevat (esim. "köysi ei venynyt (yli 0.06 / 0.07 / 0.08 m)", "vene 1.37–1.41 m/s"). docktestin rivit pysyivät samoina, koska apufunktion tyyni tuuli ja `_change_in = INF` pitävät elävänkin sään tyynenä.
- 10d: kuten hyväksymiskriteereissä (`_button("Asetukset")` → `_button("Asetuksetx")`).

PÄÄTÖS 10: Sonartestin `_pass_sample`-suodin (`c["seed"] <= _pass_sample`) ei suodata mitään, koska luotain ottaa vielä yhden näytteen laiturilla. Varsinaisen korjauksen tekee veneen siirto `_prepare_pass`in jälkeen. Vaihtoehto A: suodinta ei korjata tässä tehtävässä, vaan siitä tehdään Backlog-tehtävä. Testi on deterministinen ja menee 10/10 läpi. Työnjohtaja ratkaisi.

PÄÄTÖS 11: Korjaus PÄÄTÖKSEEN 9 (10c): docktestin rivit eivät pysy aina samoina mutaatiolla 10c. Testaajan ajossa docktest vaihteli (3.0 / 5.0 m). Koodaajan viidellä ajolla rivit pysyivät samoina. Mutaatio jää silti kiinni anchortestin vaihtelusta.

PÄÄTÖS 12: Versio 0.57.2 (patch). Tehtävä korjaa epävakaat testit; pelaajalle ei näy uutta.
