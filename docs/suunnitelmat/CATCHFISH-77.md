# CATCHFISH-77: Vesi aidomman näköiseksi

(Lopullinen versio: Teemun ja työnjohtajan päätökset, ks. *Päätetyt*.)

## Tavoite
Järven pinta näyttää ja käyttäytyy kuin oikea pieni sisäjärvi tuulessa.
- Heikolla tuulella pinnassa on pientä väreilyä.
- Kovalla tuulella aallokko on lyhyttä, jyrkkää ja teräväharjaista.
- Aallot ovat sitä suurempia, mitä pidemmän matkan tuuli on puhaltanut veden
  yli. Tuulen puoleisen rannan suojassa on tyyntä, ja selällä on aallokkoa.
- Tuulen puuskat näkyvät pinnassa tummina, tuulen mukana kulkevina väreinä.

## Nykytila (vertailukuvat)
Kuvat on otettu nykyisestä mainista (`--foamshots`):
`/tmp/claude-1000/-home-teekar-projektit-catchfish/d20ab9a6-e9aa-4586-a059-7c6eccc7d923/scratchpad/vesi-nyt/`
(1-heikko, 2-kohtalainen, 3-kova, 4-kova-kauas, 5-kova-ylhaalta,
6-kova-rannassa). Ikkuna toimi WSL:ssä.

Mitä kuvista ja koodista näkyy (`shaders/water.gdshader`,
`shaders/waves.gdshaderinc`, `scripts/world/waves.gd`, `main.gd` `_process`):
- **Aallot ovat liian pitkiä ja hitaita.**
  - Pisin aalto on 14 m (jakso 3 s). Kovalla tuulella (8 m/s) sen korkeus on
    0,34 m, ja jo 2,4 m/s tuulella 0,14 m.
  - Aallot muistuttavat meren mainingeista. Pienellä järvellä
    (pyyhkäisymatka enintään noin 2–3 km) 8 m/s tuuli tekee noin 4 m pitkää,
    1,6 s jaksoista ja noin 0,18 m korkeaa aallokkoa (taulukko alla).
- **Aallot ovat pyöreitä.** Pinta on kuuden siniaallon summa, joten harjat ja
  pohjat ovat samanmuotoisia. Kovallakaan tuulella ei synny teräviä harjoja.
- **Säännöllinen kuvio.** Kuusi kiinteää aaltoa tekee toistuvan
  ruutumaisen kuvion (näkyy hyvin kuvissa 1 ja 6). Alle metrin väreitä ei ole
  ollenkaan, joten veneen vieressä pinta on sileä ja "muovinen".
- **Vain pisin aalto liikuttaa pintaa.** Vesiverkon solut ovat 4 m, joten
  muut aallot ovat pelkkää valaistusta. Siksi pinnan ääriviiva on aina
  suora, myös kovalla tuulella.
- **Tuulen vaikutus on sama koko järvellä.** Aallokko (`Waves.strength` =
  tuuli / 8 m/s, puuskat eivät vaikuta) on joka paikassa yhtä suuri.
  - Rannan suojassa on yhtä isot aallot kuin selällä (kuva 6, 53 m rannasta).
    Vain vaahtopäät puuttuvat alle 200 m päässä rannasta.
  - Aaltojen suunta asetetaan kerran pelin alussa, eikä se seuraa tuulen
    kääntymistä.
  - Puuskat eivät näy pinnassa.
  - Yli 8 m/s tuuli ei kasvata aaltoja (todellinen sää voi antaa enemmän).
- **Vaahtopäät** (#35) ovat valkoisia läiskiä tasaisella pinnalla (kuvat 3
  ja 5), koska harjaa, jolla ne olisivat, ei ole.

## Toiminta pelaajan kannalta
Pelaaja ei tee mitään uutta. Muutos näkyy vedessä, veneen, kohon, verkon
pyykkien ja ankkurin keinunnassa ja kuuluu aaltoäänissä.

### 1. Aallokon koko tuulen ja pyyhkäisymatkan mukaan
Aallokko lasketaan joka kohdassa järveä kahdesta asiasta:
- tuulen perusnopeus (m/s, ei puuskia)
- pyyhkäisymatka eli kuinka pitkän matkan tuuli on puhaltanut veden yli
  ennen tätä kohtaa (ylätuulen rantaan).

Kaavana käytetään pyyhkäisymatkan rajoittaman aallokon kasvukäyriä (JONSWAP:
merkitsevä aallonkorkeus Hs, huippujakso Tp ja siitä aallonpituus L).
Tavoitearvot:

| Tuuli | Selkä (2 km) Hs / L / jakso | Ranta, ylätuuleen 300 m Hs / L |
|---|---|---|
| 0–1 m/s | lähes peili, vain hento väre | peili |
| 2 m/s | 0,05 m / 1,5 m / 1,0 s | 0,02 m / 0,4 m |
| 4 m/s | 0,09 m / 2,4 m / 1,25 s | 0,04 m / 0,7 m |
| 6 m/s | 0,14 m / 3,2 m / 1,4 s | 0,05 m / 0,9 m |
| 8 m/s | 0,18 m / 3,9 m / 1,6 s | 0,07 m / 1,1 m |
| 12 m/s | 0,27 m / 5,1 m / 1,8 s | 0,11 m / 1,4 m |
| 15 m/s (yläraja) | 0,34 m / 5,9 m / 1,9 s | 0,13 m / 1,7 m |

- Yksittäiset aallot vaihtelevat: suurimmat ovat noin 1,5–2 × Hs.
- Kaikkien suureiden kerroin on yksi säätövakio, joka on nyt 1,0. Sitä voi
  säätää myöhemmin.
- Yläraja on 15 m/s. Simuloitu sää antaa enintään 8 m/s, todellinen sää
  enemmän.
- Koot ovat todelliset, eikä niitä suurenneta (Teemu päätti).
- Pyyhkäisymatka lasketaan ylätuulen suuntaan vesisoluja pitkin, joten saaret
  ja niemet suojaavat.
- **Aallokon kasvu ja laantuminen tapahtuvat pelin ajassa** (Teemu päätti).
  - Tuulen voimistuessa aallokko saavuttaa uuden tason noin
    10 peliminuutissa, ja tuulen heiketessä se laantuu noin 20 peliminuutissa.
  - Ajan nopeutus (T) nopeuttaa siis myös aallokon muutosta.
  - Nykyinen noin 50 sekunnin oikean ajan liukuma (`main.gd`,
    `move_toward(..., delta * 0.02)`) korvataan tällä.
  - Pelin alussa ja todellisen sään ensimmäisellä havainnolla aallokko
    asetetaan heti tuulen mukaiseksi kuten nyt.

### 2. Aaltojen muoto: terävät harjat, leveät pohjat
- Aallot ovat trokoidisia (Gerstner): pinta liikkuu myös vaakasuunnassa,
  jolloin harjat terävöityvät ja pohjat levenevät.
- Terävyys kasvaa jyrkkyyden (Hs/L) mukaan. Heikolla tuulella aallot ovat
  pyöreähköjä, ja kovalla tuulella harjat ovat selvästi kapeampia kuin
  pohjat. Harja ei kuitenkaan koskaan mene silmukalle.
- Aallot eivät enää ole muutama kiinteä siniaalto. Pääaallokko (3–4 aaltoa
  tuulen suunnan ympärillä, pituudet huippuaallonpituuden mukaan) liikuttaa
  pintaa veneen lähellä myös muodoltaan.
- Lyhyet aallot ja alle metrin väreet tuovat pintaan epäsäännöllisyyttä.
  Säännöllistä ruutukuviota ei näy.
- Väreet seuraavat tuulta: heikolla tuulella vain hento väre, ja
  tyynellä (alle 1 m/s) pinta on lähes peilityyni.

### 3. Tuulen suunta ja puuskat
- **Tuulen kääntyminen.** Kun tuuli kääntyy yli noin 20°, uusi aallokko
  kasvaa uuteen suuntaan, ja vanha vaimenee ristiin häivyttäen noin minuutin
  kuluessa. Aaltoja ei käännetä paikallaan, koska se siirtäisi kaukaisia
  aaltoja holtittomasti, mikä on syy siihen, että suunta nyt kiinnitetään.
- **Puuskat.** Kun `weather.gust` kasvaa, pinnalla kulkee tuulen mukana
  laikkuja, joissa väreet ovat tiheämpiä ja pinta tummempi ja himmeämpi
  ("kissankäpälät").
  - Laikut ovat kymmenien metrien kokoisia, liikkuvat tuulen nopeutta
    hitaammin ja häviävät puuskan laantuessa.
  - Puuskat vaikuttavat vain väreisiin, eivät veneen keinuntaan eivätkä
    pääaallokkoon.

### 4. Vaahtopäät (#35) uuteen aallokkoon
- Vaahtopäät syntyvät aallonharjoille. Nykyinen ajelehtiva solumalli ja
  pitsimäinen jälkivaahto säilyvät, mutta murtuma osuu harjan etupuolelle.
- Vaahtopäiden määrä riippuu tuulesta ja paikallisesta aallokosta
  (pyyhkäisymatka), ei enää rannan etäisyydestä.
  - Ylätuulen rannan suojassa ei ole vaahtopäitä.
  - Alatuulen rannan edessä voi olla vaahtopäitä, koska aallokko on siellä
    suurimmillaan.
- Kynnys on ennallaan: vaahtopäät alkavat noin 4 m/s:sta selällä
  (Beaufortin asteikko 3).

### 5. Vene, koho, pyykit ja ankkuri
- Ne keinuvat samassa aallokossa kuin näkyvä pinta. Nykyinen yhteinen
  aaltomalli (`Waves.swell_height`) säilyy rajapintana, ja se laskee samat
  pääaallot ja pyyhkäisymatkan kuin varjostin.
- Vene keinuu kovalla tuulella nopeammin ja lyhyemmin (1,5–2 s jakso)
  kuin nyt (3 s), ja suojan puolella se on lähes paikallaan.
- Kohon kallistelu (`fishing.gd`, nyt `Waves.strength`) ja aaltoäänet
  (`game_audio.gd`, nyt `Waves.strength`) käyttävät veneen kohdan
  paikallista aallokkoa. Suojassa on hiljaisempaa ja selällä kovempi loiske.
  Itse ääniä ei muuteta.

### 6. Talvi
Ei muutosta (jää ja lumi kuten nyt).

### 7. Asetus: Veden laatu (Korkea / Matala)
- Asetuksissa on uusi valinta **Veden laatu**, jossa on kaksi tasoa. Se on
  samassa asetusruudukossa kuin hiiren herkkyys ja äänet (`SettingsControls`),
  eli alkuvalikon *Asetukset* ja Esc-valikon *Asetukset*.
  - **Korkea:** koko suunnitelma. Lähivesi on tiheä (noin 0,25–0,5 m
    keskellä), kaikki pääaallot liikuttavat pintaa, väreitä on
    kahdessa kerroksessa, ja puuskalaikut ovat yksityiskohtaiset. Tämä on
    työpöytäversion oletus.
  - **Matala:** kevyt lähivesi. Verkossa on noin neljäsosa Korkean
    vertekseistä (noin 1 m keskellä), pintaa liikuttaa 2 pääaaltoa, väreitä on
    yksi kerros, ja puuskalaikut ovat yksinkertaisempaa kohinaa. Vaahtopäät
    ja pyyhkäisymatkan vaikutus ovat samat. Tämä on selainversion oletus
    (`OS.has_feature("web")`).
- **Pelattavuus ei riipu laadusta.** Veneen, kohon, pyykkien ja ankkurin
  keinunta ja aaltoäänet lasketaan samasta GDScript-mallista (kaikki
  pääaallot) molemmilla tasoilla. Matalalla näkyvä pinta voi poiketa niistä
  muutamia senttejä, mikä hyväksytään.
- Valinta tulee voimaan heti, myös kesken kalareissun Esc-valikosta, ja se
  tallennetaan kuten muut asetukset.
- Testiajot käyttävät aina Korkeaa (kuten muutkin asetukset nollataan
  testeissä), ellei testi itse vaihda tasoa.

## Ulkoasu ja äänet
- Lähikuvassa (FPV, kolmas persoona) näkyvät:
  - aallokon ääriviiva: terävät harjat ja leveät pohjat
  - aurinkokimallus hajoaa pieniksi välähdyksiksi väreissä
  - tummat puuskalaikut.
- Kaukana pinta sulautuu kuten nyt. Kaukaiset aallot häivytetään pikselikoon
  mukaan, eikä välkettä tule (#78 Välkkyminen on korjattu, ja se ei saa
  palata).
- Veden väri, humusveden sironta ja veneen varjo (#48) pysyvät ennallaan
  (Teemu päätti).
- Tyynellä pinta heijastaa taivasta kuten nyt. Rantojen ja puiden
  peiliheijastus ei kuulu tähän tehtävään (oma Plane-tehtävä).
- Vana (`wake.gdshader`) kulkee aaltopinnan mukana.
- Ääniä ei lisätä. Aaltoäänen voimakkuus seuraa paikallista aallokkoa
  (kohta 5).
- **Asetusrivi:** asetusruudukossa (3 saraketta: nimi, säädin, arvo) uusi
  rivi:
  ```
  Veden laatu        [ Korkea ▾ ]
  ```
  - Säädin on `OptionButton` (Korkea, Matala), ja nimen tyyli on sama kuin
    muilla riveillä (`_label`, koko 16).
  - Kolmanteen sarakkeeseen tulee lyhyt selite pienellä harmaalla: Korkealla
    "tarkat aallot", Matalalla "kevyempi, selaimelle".
  - Rivi sijoitetaan hiiren asetusten jälkeen ennen äänenvoimakkuuksia.
- HUD, ohjeet ja näppäimet eivät muutu.
- README:n ja `docs/plan.md`:n maailma-kuvaus päivitetään (aallokko tuulen
  ja pyyhkäisymatkan mukaan). Asetukset-kuvaukseen lisätään Veden laatu.

## Toteutus pääpiirteissään
1. **Pyyhkäisymatka-aineisto.**
   - Uusi apuskripti `tools/build_fetch.py` lukee `assets/lake/water.bin`- ja
     `lake.json`-tiedostot ja laskee jokaiseen karkeaan soluun (esim. 16 m)
     pyyhkäisymatkan 16 tuulensuuntaan.
   - Tulos tallentuu tiedostoon `assets/lake/fetch.bin` (noin 0,9 Mt,
     metreinä kvantisoituna).
   - MML-lähdeaineistoa ei tarvita, joten `build_lake.py`:hin ei kosketa.
   - `LakeData` lataa aineiston. Uusi funktio `fetch_at(x, z, suunta)`
     interpoloi kahden lähimmän suunnan ja solujen välillä.
   - Varjostimelle aineisto välitetään tekstuurina (16 suuntaa = neljä
     RGBA8-kanavaa, kaksi kuvaa tai atlas). Lisäksi tehdään
     rantaetäisyystekstuuri (`shore.bin`), koska lähiverkko ei voi käyttää
     staattisia verteksivärejä.
2. **Aaltomalli** (`waves.gdshaderinc` ja `waves.gd` pidetään
   samansisältöisinä kuten nyt):
   - Tuuli (m/s) ja pyyhkäisymatka antavat Hs:n, Tp:n ja L:n (taulukko).
   - Pääaallot ovat 3–4 Gerstner-aaltoa: pituudet 0,6–1,6 × L ja suunnat
     ±40° tuulesta.
   - Kaksi suuntasarjaa ristihäivytyksellä tuulen kääntyessä.
   - `Waves.swell_height(p)` palauttaa Gerstner-pinnan korkeuden kohdassa p.
     Vaakasiirto otetaan huomioon 1–2 kiintopisteiterointia, jotta vene
     istuu näkyvällä pinnalla.
   - `Waves.local_strength(p)` (0–1) annetaan äänille ja kohon kallistelulle.
   - `main.gd`:
     - `Waves.strength` / `angle` korvataan tuulen nopeudella ja suunnalla
     - kääntymisen tunnistus ja ristihäivytys
     - aallokon tuuli liukuu kohti `weather.wind_base`a pelin ajassa:
       kasvu noin 10 peliminuutissa, laantuminen noin 20 peliminuutissa
       (`sky.time_scale()`).
3. **Lähivesi** (`scripts/world/lake_world.gd`):
   - Kameraa seuraava tiheä vesiverkko, jossa on keskellä tiheämpi (noin
     0,25–0,5 m) ja reunoilla harvempi rengas (yhteensä noin 120 m säde).
   - Lähiverkon verteksit siirtyvät pääaaltojen mukaan.
   - Verkko siirtyy kameran mukana solun kokoisin askelin, jotta aallot eivät
     "ui".
   - Nykyinen 4 m järviverkko jää kauaksi. Se jättää lähiveden alueen
     piirtämättä, ja lähivesi jättää maan ja oman reunansa ulkopuolen
     piirtämättä. Läpikuultavaa vettä ei saa olla kahta kerrosta päällekkäin.
   - Lähiveden reunalla siirtymä häivytetään nollaan, jotta sauma ei näy.
   - Verkon tiheys riippuu Veden laatu -asetuksesta. Verkko rakennetaan
     uudelleen, kun asetus muuttuu (signaali `Settings`istä).
4. **`water.gdshader`:**
   - Gerstner-normaalit pääaalloista.
   - Lyhyet aallot ja väreet satunnaistetuilla suunnilla ja vaiheilla, jotta
     toistuvaa kuviota ei tule, pikselikokoon häivytettyinä kuten nyt.
   - Puuskalaikut ajelehtivasta kohinasta: uusi uniform `gust`, joka tulee
     `weather.gust`ista.
   - Vaahtopäät harjan ja paikallisen aallokon mukaan.
   - Tyynellä väreet pienenevät (kuviota ei ole).
   - `wake.gdshader` käyttää samaa siirtymää.
   - Laatutaso välitetään varjostimille uniformina (esim. `quality` 0/1).
     Matalalla jätetään pois toinen värekerros ja yksityiskohtaiset
     puuskalaikut, ja pinnan siirtymään käytetään 2 pääaaltoa.
     Vaihtoehtoisesti tehdään kaksi varjostinvarianttia, jos uniform-haara
     on Compatibility-renderöijässä hitaampi. Koodaaja mittaa.
6. **Asetus:**
   - `scripts/settings.gd`:
     - uusi `water_quality` ("korkea" / "matala")
     - tallennus `asetukset.cfg`:hen, osio `grafiikka`, avain `veden_laatu`
     - oletus `OS.has_feature("web")`:n mukaan, ja testiajoissa Korkea
     - signaali muutoksesta.
   - `scripts/ui/settings_controls.gd`: uusi rivi `OptionButton`illa.
   - `lake_world.gd` ja `main.gd` kuuntelevat muutosta.
7. **Käyttäjät:** `boat.gd`, `fishing.gd` (koho), `gill_net.gd`, `anchor.gd`
   ja `game_audio.gd` saavat korkeuden ja paikallisen aallokon uudesta
   mallista. Rajapinta `swell_height` säilyy.
8. **Testit:**
   - Uusi headless-testi `--wavetest` (`tests/wave_test.gd`):
     - Hs ja L taulukon mukaan (±30 %) selällä ja ylätuulen rannassa
       4, 8 ja 12 m/s tuulella
     - ylätuulen ranta alle 50 % selän aallokosta 8 m/s tuulella
     - saaren suojapuoli tyynempi kuin tuulenpuoli
     - harjat terävämpiä kuin pohjat 8 m/s tuulella (harjan kaarevuus vs.
       pohjan, suhde > 1,5)
     - tuulen 90° kääntyminen ei hyppäytä pintaa (pinnan korkeuden muutos
       ruudussa rajattu)
     - aallokon kasvu: tuuli 2 → 8 m/s saavuttaa noin 90 % tasosta
       10 ± 3 peliminuutissa ja laantuu 8 → 2 m/s noin 20 ± 5 peliminuutissa,
       myös ajan nopeutuksella
     - `swell_height` on sama molemmilla laatutasoilla
     - `fetch.bin` vastaa `water.bin`:iä (sama ruudukko).
   - Uusi kuvatyökalu `--watershots=KANSIO` (ikkuna), samoista paikoista ja
     kulmista kuin `vesi-nyt`-kuvat:
     - tuulet 0,5 / 2 / 4 / 8 / 12 m/s selällä FPV- ja kolmannen persoonan
       korkeudelta
     - 8 m/s ylätuulen ja alatuulen rannassa
     - puuska käynnissä
     - ylhäältä.

     Työkalu ajetaan kummallakin laatutasolla (esim. `--waterquality=matala`)
     ja tulostaa kummallekin keskimääräisen ruudun ajan (ms) samasta
     kuvakulmasta 300 ruudun ajalta. Tuloksia verrataan mainiin.
   - Päivitetään:
     - `--foamshots`: "rannan lähellä ei vaahtopäitä" muuttuu muotoon
       "ylätuulen rannassa ei vaahtopäitä"
     - `--baittest`: koho aaltopinnalla
     - `--flicker` / `--jittershots`: välkkeen raja ennallaan, ja ne ajetaan
       molemmilla laatutasoilla
     - `--settingstest` (ikkuna): Veden laatu -rivi on olemassa, vaihto
       Matalaksi tallentuu ja tulee voimaan heti (lähiverkon verteksimäärä
       pienenee).
9. README, `docs/plan.md` (taulukko *Maailma*, tehty-merkintä, testilista).

## Hyväksymiskriteerit
- [ ] 8 m/s tuulella selällä aallot ovat noin 4 m pitkiä ja noin 0,2 m
      korkeita (Hs), ja harjat ovat näkyvästi teräviä ja pohjat leveitä
      (`--watershots`, `--wavetest`).
- [ ] 2 m/s tuulella pinnassa on vain pientä aallokkoa ja väreitä, ja alle
      1 m/s pinta on lähes peilityyni.
- [ ] Ylätuulen rannan suojassa aallokko on selvästi pienempi kuin selällä,
      ja saaren suojapuoli on tyynempi.
- [ ] Pinnassa ei näy toistuvaa ruutukuviota millään tuulella.
- [ ] Puuskat näkyvät tuulen mukana kulkevina tummina värelaikkuina eivätkä
      keinuta venettä.
- [ ] Tuulen kääntyessä aallokko kääntyy minuutissa ilman hyppäyksiä.
- [ ] Vaahtopäät ovat aallonharjoilla. Niitä on kovalla tuulella selällä ja
      alatuulen rannassa, mutta ei ylätuulen rannassa eikä alle 4 m/s
      tuulella.
- [ ] Vene, koho, pyykit ja ankkuri keinuvat näkyvän pinnan mukana: ne
      eivät uppoa pinnan alle eivätkä leiju sen yllä (`--baittest`,
      `--boatshots`).
- [ ] Vana kulkee pinnalla.
- [ ] Aaltoäänet ovat suojassa hiljaisempia kuin selällä.
- [ ] Lähiveden reunan sauma ei näy, eikä läpikuultavaa vettä ole kahta
      kerrosta (veneen varjo #48 näkyy kuten ennen, `--shadowshots`).
- [ ] Välkettä ei tule kaukana eikä kameran liikkuessa (`--flicker`,
      `--jittershots`).
- [ ] Talvella jää ja lumi näkyvät kuten ennen (`--icetest`).
- [ ] Ruudun aika mainiin verrattuna (`--watershots`, sama kuvakulma):
      Korkea noin +1–2 ms ja Matala noin +1,5 ms (Radeon 740M); nykytila
      hyväksytty (Teemu).
- [ ] Asetuksissa (alkuvalikko ja Esc-valikko) on Veden laatu
      Korkea/Matala. Valinta tulee voimaan heti ja säilyy uudelleenkäynnistyksen
      yli. Työpöydän oletus on Korkea ja selaimen Matala.
- [ ] Matalalla aallokon koko, pyyhkäisymatkan vaikutus ja vaahtopäät
      näkyvät, ja veneen keinunta on sama kuin Korkealla.
- [ ] Aallokko kasvaa tuulen voimistuessa noin 10 peliminuutissa ja laantuu
      noin 20 peliminuutissa, ja ajan nopeutus (T) nopeuttaa muutosta.
- [ ] Kaikki ikkunattomat testit menevät läpi, ja uusi `--wavetest` on
      `tools/run_tests.sh`:ssä.
- [ ] Designer tarkistaa `--watershots`-kuvat molemmilla laatutasoilla
      verrattuna kansion `vesi-nyt` kuviin.

## Päätetyt
- Aallokko todellisissa koissa (taulukko), kerroin 1,0 (Teemu).
- Suorituskyky: uusi Veden laatu -asetus (Teemu). Kaksi tasoa: Korkea (koko
  suunnitelma, työpöydän oletus, tavoite noin +1 ms) ja Matala (kevyt
  lähivesi, selainversion oletus). Asetus on asetusvalikossa nykyisten
  asetusten tapaan ja tallentuu (työnjohtaja).
- Rantojen peiliheijastus ei kuulu tähän tehtävään. Siitä tulee oma
  Plane-tehtävä (työnjohtaja).
- Veden väri ennallaan (Teemu).
- Aallokon kasvu pelin ajassa: noin 10 min kasvu ja 20 min laantuminen
  (Teemu).
- Rantaetäisyystekstuuria (`shore.bin` varjostimelle) ei tehdä:
  vaahtopäät riippuvat pyyhkäisymatkasta, ja lähivesi rajataan
  `water.bin`-maskilla (työnjohtaja).
- Pyyhkäisymatka välitetään varjostimelle 16 erillisenä R8-tekstuurina
  (suuntasarjalle kaksi lähintä suuntaa ja sekoitus) RG8-atlaksen sijaan,
  jottei tuulen kääntyminen aiheuta laskentanykäystä (työnjohtaja).
- Matalalla myös pikselivarjostin on kevyempi: pääaaltojen lyhyiden aaltojen
  häntä ja väreiden laikkukohina jäävät pois normaaleista (työnjohtaja).
- Ristihäivytys tuulen kääntyessä kestää 60 s oikeaa aikaa (ei peliaikaa),
  jottei ajan nopeutus x60 tee siitä sekunnin hyppäystä (työnjohtaja).
- Aaltoryhmät (verhokäyrä) ja mutkittelevat aaltorintamat (vaiheen
  poikkeutus) lisätään, jotta suurimmat aallot ovat n. 1,5–2 × Hs eikä
  ruutukuviota synny (työnjohtaja).
- Suorituskyky: Korkea noin +1–2 ms, Matala noin +1,5 ms (740M), hyväksytty
  nykytila (Teemu).

## Avoimet kysymykset Teemulle
Ei avoimia kysymyksiä.
