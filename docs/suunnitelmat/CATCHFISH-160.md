# CATCHFISH-160: GitHub Actions vihreäksi (pressuretest, boattest, motorspeedtest)

## Tavoite
Testit antavat saman tuloksen joka ajolla, myös CI:ssä, jolloin punainen
GitHub Actions tarkoittaa oikeaa vikaa eikä huonoa arpaonnea. Kaikkien kolmen
testin satunnaisuus tulee samasta lähteestä: `Weather` arpoo sään siemenettä
(`_rng.randomize()`), ja testit antavat sään elää kesken mittauksen.

## Toiminta pelaajan kannalta
Pelaajalle ei muutu mitään tässä tehtävässä (vain testit ja työtapa).
Tutkimuksessa löytyi kuitenkin pelikoodin vika, joka on kirjattu kohtaan
*Avoimet kysymykset* (kysymys 1): istuva kalastaja kääntyy koko vartalollaan
kameran suuntaan, ja jo noin 16 asteen kulmassa veneen keulasuunnasta
jalkaterä menee testin mittarilla rungon ulkopuolelle.

## Ulkoasu ja äänet
Ei muutoksia.

## Juurisyyt

Merkinnät: **todennettu** = toistettu ajamalla tai näkyy lokista,
**arvaus** = ei todennettu.

### pressuretest (CI:ssä 8/12 valmiista ajosta 6.–12.11., paikallisesti noin 27 %)

- **Todennettu:** CI:n lokeissa (ajot 40901899114 ... 43170227026) kaatuu aina
  sama tarkistus "sään selkeytyessä paine nousee ja syönti heikkenee", tavallisimmin
  "1021 hPa, tasainen, kerroin 0.96–0.97", joskus "laskee, kerroin 1.00–1.16".
- **Todennettu (simulointi 2000 kertaa, testin säävaihe sellaisenaan):** kaatuu
  536/2000 (27 %). Syy: `Weather._process` vähentää `_change_in`-ajastinta
  (30–90 peliminuuttia jokaisen `set_kind`-kutsun jälkeen) ja kutsuu `_pick_next()`.
  - Tärkein (523/536): testin viimeisen 60 minuutin aikana ajastin laukeaa ja
    selkeä vaihtuu puolipilviseksi (`NEXT[CLEAR]`: 60 % PARTLY, tavoite 1016 ± 3 hPa),
    jolloin paine kääntyy laskuun ja trendi jää alle 1,5 hPa/3 h.
  - Loput: 180 minuutin "sadejakson" aikana sää on ehtinyt vaihtua
    (RAIN → CLOUDY → PARTLY), paine ei ole laskenut ja selkeän tavoite saavutetaan
    heti, jolloin trendi on tasainen.
- **Todennettu (simulointi 2000 kertaa):** kun säätila ei vaihdu itsestään
  (`_change_in` = INF jokaisen testin `set_kind`-kutsun jälkeen), kaatumisia 0/2000 ja
  tulos on siemenestä riippumaton: lopputrendi 2,66 hPa/3 h (raja > 1,5), kerroin 0,85;
  ensimmäisen tunnin trendi −3,13 (raja < −1,5).
- **Arvaus / selvittämättä:** miksi CI kaatuu useammin (noin 2/3) kuin paikallisesti
  (noin 1/4). Mahdollisesti `randomize()`-siemenen (kello + käynnistyksen
  mikrosekunnit) jakauma CI-koneessa. Korjauksen jälkeen tulos ei riipu siemenestä,
  joten tätä ei tarvitse selvittää.
- Vika on **testissä**, ei pelissä: pelissä sää saa vaihtua satunnaisesti.

### boattest (CI:ssä 3/12 valmiista ajosta)

- **Todennettu:** CI:ssä kaatuu "jalat veneen sisällä kalastaessa (asento 0)",
  vasen jalka x ≈ −0,42, z ≈ −0,51 / −0,34 (rungon koordinaateissa).
- **Todennettu (8 ajoa diagnostiikkatulosteilla):** kalastajan kulma rungon suhteen on
  `aim_yaw = camera_rig.yaw − boat.yaw` (`scripts/fishing/fishing.gd`, `_aim_angler`).
  Kameran yaw pysyy paikallaan, mutta vene kääntyy testin kaasujakson
  (ruudut 30–60, kaasu 0,24) ja tuulen vuoksi 0,04–0,28 rad. Tuuli arvotaan
  (1–5 m/s, satunnainen suunta). Ajo, jossa aim_yaw = 0,282 rad (tuuli 5,0 m/s),
  kaatui; 0,272 rad meni läpi. Raja on siis noin 0,275 rad ≈ 16°.
- **Todennettu:** kun sää pysäytetään tyyneksi (`weather.set_process(false)`,
  `wind_base`, `gust`, `_wind_target` = 0), aim_yaw on ruudulla 199 joka ajolla
  sama −0,041 rad ja kaikki jalkatarkistukset menevät läpi (3/3 samoin luvuin).
- **Todennettu (kulmakokeilu, kamera asetettu kulmaan ruudulla 121):** aim_yaw
  ±0,5, ±1,0 ja ±1,57 rad → jalat rungon ulkopuolella (90°:ssa x ≈ ±0,86);
  0 ja 3,0 rad → sisällä. Eli **pelissä** kalastaja istuu keskituhdolla koko
  vartalo kameran suuntaan, ja kun pelaaja katsoo sivulle yli noin 16°, jalat
  menevät mittarin mukaan laidan läpi. Testin kommentti
  ("isommalla työnnöllä vene ehtii ... kääntyä niin, että kalastaja on vinossa ja
  jalka laidan läpi", CATCHFISH-108) viittaa siihen, että vika on tunnettu ja
  kaasu on viritetty sen kiertämiseksi.
- **Arvaus:** näkyykö jalka ruudulla oikeasti laidan läpi vai mittaako `_inside`
  pohjan leveydellä liian ahtaasti. Ei kuvattu; ks. avoin kysymys 1.

### motorspeedtest (CI:ssä 1/12, paikallisesti 3/3 läpi)

- **Todennettu:** CI 12.11. "peruutusnopeus 10.95 km/h (noin 11,5)", raja 11,0–12,0.
- **Todennettu (4 ajoa):** testi asettaa `_ready`ssä `main.weather.wind_base = 0`,
  mutta sää jatkaa: `wind_base` palaa kohti arvottua `_wind_target`ia
  (0,05 m/s sekunnissa) ja puuskat jatkuvat. Peruutusvaiheessa (testin
  51.–81. s) tuuli oli 1,7–4,4 m/s ja peruutusnopeus 11,35–11,63 km/h ajosta
  riippuen. "Tyynellä" ei siis ole tyyntä.
- **Todennettu (2 ajoa):** tyynellä säällä (sää pysäytetty kuten yllä) tulos on
  joka ajolla sama: huippu 28,01, 0 → 26,6 km/h 5,2 s, 50 % 19,43,
  peruutus 11,53 km/h. Kaikki rajojen sisällä.
- Vika on **testissä**.

## Toteutus pääpiirteissään

Pelikoodiin ei muutoksia (paitsi jos Teemu päättää kysymyksessä 1 korjata jalat
tässä tehtävässä).

1. `tests/pressure_test.gd`: säätila ei vaihdu itsestään testin aikana. Jokaisen
   testin `set_kind`-kutsun jälkeen `w._change_in = INF` (kommentti: "säätila
   vaihtuu vain testin käskystä"). Vaihtoehto: pieni apufunktio testissä, joka
   tekee molemmat. Tarkistusten rajat ennallaan.
2. `tests/boat_test.gd`: `_ready`ssä sää tyyneksi ja pysähdyksiin samalla tavalla
   kuin `line_test.gd`/`fight_depth_test.gd` (`main.weather.set_process(false)`
   ja `wind_base`, `gust`, `_wind_target` nollaan). Kaasu 0,24 ennallaan.
   Jos Teemu valitsee kysymyksessä 1 vaihtoehdon B, lisäksi jalkatarkistus
   usealla katselukulmalla.
3. `tests/motor_speed_test.gd`: nykyinen `wind_base = 0` korvataan samalla
   tyynellä, pysäytetyllä säällä. Rajat ennallaan.
4. `docs/plan.md` (*Työtapa*) ja `CLAUDE.md` (*Työtapa* ja *Agenttitiimi* /
   julkaisu): julkaisun jälkeen työnjohtaja tarkistaa mainin GitHub Actions
   -ajon (`gh run list --workflow Testit -L 3`, `gh run watch`), ja punainen ajo
   kirjataan Planeen tai korjataan ennen seuraavaa tehtävää.
5. Versio: korjaus → patch-nosto (työnjohtaja).

## Hyväksymiskriteerit

- [ ] `tools/run_tests.sh -q --repeat=20 pressuretest` 20/20 läpi, ja
      "sään selkeytyessä" -rivin luvut (hPa, trendi, kerroin) ovat joka ajossa samat
      (simuloinnin mukaan 1021 hPa, nousee nopeasti, kerroin 0.85).
- [ ] `tools/run_tests.sh -q --repeat=10 boattest` 10/10 läpi.
- [ ] `tools/run_tests.sh -q --repeat=5 motorspeedtest` 5/5 läpi, ja
      peruutusnopeus on joka ajossa sama (noin 11,5 km/h; tyynellä mitattu 11.53).
- [ ] Testien rajat (`> 1.5`, `< 1.0`, `11.0–12.0` jne.) ja tarkistusten määrä
      eivät muutu, eli testit eivät löysty.
- [ ] Mutaatiotarkistus pressuretestille: jos `KIND_PRESSURE[Kind.CLEAR]` laitetaan
      tilapäisesti arvoon 1000, "sään selkeytyessä" -tarkistus kaatuu (testi
      mittaa yhä paineen nousua). Muutos perutaan.
- [ ] Koko sarja `tools/run_tests.sh -q` läpi paikallisesti (testaaja).
- [ ] GitHub Actions *Testit* vihreä haaran pushissa ja releasen jälkeen mainissa.
- [ ] `docs/plan.md` ja `CLAUDE.md` kertovat Actions-tarkistuksesta julkaisun jälkeen.

## Avoimet kysymykset Teemulle

1. **Kalastajan jalat menevät laidan läpi, kun kamera katsoo sivulle (pelikoodin vika).**
   Mittarin mukaan jo noin 16° kulmassa keulasta, 90°:ssa reilusti. Vaihtoehdot:
   - A) Tässä tehtävässä vain testi deterministiseksi (tyyni sää); jalkojen
     korjaukselle uusi Plane-tehtävä, jota varten designer ottaa ensin kuvat
     (`angler_shots`, kulmat 0°, 45°, 90°) ja katsoo, näkyykö vika oikeasti.
   - B) Korjataan tässä: istuessa lantio ja jalat pysyvät keulaa kohti tai
     kääntyvät rajatusti (esim. enintään ±15°), ja loput kääntymisestä tehdään
     ylävartalolla ja päällä. boattest tarkistaa jalat kulmilla 0, ±0,5, ±1,0, ±1,57.
     Isompi työ, vaatii ulkoasun tarkistuksen kuvista.
   - C) Jätetään pelin käytös ennalleen (vika hyväksytään), testiin vain tyyni sää.
   Ehdotan A:ta, jotta CI saadaan vihreäksi heti.
2. **Muut säästä riippuvat testit.** CI:ssä ovat lisäksi kerran kaatuneet anchortest
   ("tuulessa pohjasta nostettaessa köysi ei kulkenut rungon läpi", 6.11.) ja
   sonartest ("vene ajaa kalan yli", 29.10.). Syytä ei selvitetty. Vaihtoehdot:
   - A) Erillinen tehtävä: käydään kaikki testit läpi, ja sää kiinnitetään
     jokaisessa, joka ei nimenomaan testaa säätä.
   - B) Lisätään tähän tehtävään.
   Ehdotan A:ta.
3. **Actions-tarkistuksen laajuus.** Riittääkö, että työnjohtaja katsoo mainin ajon
   tuloksen julkaisun jälkeen ja kirjaa punaisen Planeen (ehdotus), vai odotetaanko
   vihreää ennen raporttia Teemulle (julkaisuraportti viivästyy 15–25 min)?

## Päätökset

- **PÄÄTÖS 1 (Teemu, 12.11.):** vaihtoehto A. Tässä tehtävässä vain testikorjaukset
  (sää pysäytetään). Kalastajan jaloista tehdään oma Backlog-tehtävä, jossa vika
  tarkistetaan ensin kuvista. boattestin kaasu 0,24 ja jalkatarkistus pysyvät ennallaan.
- **PÄÄTÖS 2 (työnjohtaja):** vaihtoehto A. anchortestin ja sonartestin sään
  kiinnittämisestä tehdään oma Backlog-tehtävä, eikä niitä kosketa tässä.
- **PÄÄTÖS 3 (työnjohtaja):** julkaisuraportti ei odota mainin Actions-ajoa.
  Työnjohtaja käynnistää julkaisun jälkeen ajon seurannan taustalle. Kun tulos
  tulee, punainen ajo kirjataan heti Planeen ja kerrotaan Teemulle. Tämä
  kirjataan `docs/plan.md`:hen ja `CLAUDE.md`:hen kohdan 4 mukaisesti.
