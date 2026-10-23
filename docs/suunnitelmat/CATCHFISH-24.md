# CATCHFISH-24: Uramoodi: kalastonhoitomaksu ja kalan vapautus

(Versio 8: Teemun päätökset, hinnat 47/16/6 €, toisen vavan lupa 10 €
kalenterivuodeksi (käyttö vaatii lisäksi kalastonhoitomaksun) ja
aloitusrahat 50 €. Uusi ura alkaa ilman maksua; pelaaja maksaa sen itse.)

## Tavoite
Uramoodiin tulee todellinen kulu, kalastonhoitomaksu, joka pitää maksaa ennen
kuin saa kalastaa virvelillä tai verkolla. Lisäksi toinen vapa vaatii
tekoaltaan 10 euron lupamaksun. Saaliin voi päästää takaisin
järveen. Uramoodissa vapautettu kala antaa mainetta, ja maine nostaa kalojen
myyntihintaa. Pelaaja valitsee siis, myykö kalan heti vai vapauttaako sen
paremman hinnan vuoksi.

## Toiminta pelaajan kannalta

### Kalastonhoitomaksu (vain uramoodi)
- Maksu maksetaan kotinäkymän **Kalastustarvikeliikkeessä**, uudessa ryhmässä
  *Kalastonhoitomaksu*. Pelaaja maksaa sen itse; automaattista veloitusta ei ole.
  - **Vuosimaksu 47 €**: kalenterivuosi, voimassa kuluvan vuoden 31.12. loppuun
    (päivä, jolloin `Career.day_of_year()` on 365).
  - **Viikkomaksu 16 €**: voimassa 7 vuorokautta, eli ostopäivä ja 6 seuraavaa uran päivää.
  - **Vuorokausimaksu 6 €** (1 vrk): pelissä voimassa ostopäivän loppuun (uran
    kello lasketaan kokonaisina päivinä; reissu jatkuu silti puolenyön yli,
    ks. alla).
  - Hinnat: eraluvat.fi, 2026.
- Jos voimassa olevan maksun päälle ostaa uuden, voimassaolo jatkuu siitä,
  kumpi päättyy myöhemmin, eivätkä päivät summaudu. Painike on pois käytöstä,
  jos uusi maksu ei pidentäisi voimassaoloa (esim. vuosimaksu on jo voimassa)
  tai jos rahat eivät riitä.
- **Uuden uran alussa maksua ei ole** (Teemu päätti): sitä ei ole maksettu
  valmiiksi eikä sitä veloiteta automaattisesti. Pelaaja maksaa sen itse
  liikkeestä, esim. vuosimaksun 47 €, ennen kuin pääsee kalaan
  virveliuistimilla. Vanhoissa tallennuksissa maksua ei myöskään ole.
- Ilman voimassa olevaa maksua saa kalastaa vain ongella (koho-onki,
  pohjaonki) ja pilkillä (pilkki, tasapainopilkki), koska ne ovat
  jokaisenoikeuksia (eraluvat.fi: maksuton on onkiminen ja pilkkiminen
  yhdellä vavalla; toisesta vavasta ks. *Toisen vavan lupa*).
  Virveliuistimia (lusikka, vaappu, syvävaappu, lippa, jigi) ei voi valita,
  eikä verkkoa voi laskea (N). Kummastakin tulee ilmoitus.
- **Verkon nosto on sallittu ilman maksua**, ja saalis tulee saaviin
  normaalisti. Vain uuden verkon lasku estetään, joten verkko ei jää järveen
  jumiin, jos maksu loppuu.
- Maksun voimassaolo tarkistetaan reissun alussa (Lähde kalalle). Jos maksu
  loppuu kesken reissun (puoliyö), reissu jatkuu loppuun entisillä oikeuksilla.
- **Aloitusrahat nousevat 20 eurosta 50 euroon** (`Career.START_MONEY`,
  Teemu päätti), jotta vuosimaksun (47 €) voi maksaa heti alussa.
  Aloitusvälineet pysyvät ennallaan: lusikka 2, jigi 2 ja pilkki 2
  (`START_LURES`). Muutos koskee vain uusia uria. Vanhan tallennuksen rahat
  säilyvät ennallaan, koska `ura.json`issa on rahamäärä.
- **Aloitustilanne:** uusi ura alkaa kesällä (1.6.) 50 eurolla ilman
  maksua. Aloitusuistimet lusikka ja jigi ovat virveliuistimia, ja pilkki
  käy vain jäällä. Ilman maksua kesällä ei siis voi kalastaa yhdelläkään
  omalla välineellä. Pelaajan pitää ensin maksaa maksu liikkeessä
  (vuosimaksun jälkeen jää 3 €; vuorokausi- tai viikkomaksu jättää enemmän)
  tai ostaa onki (3–4 €). Kotinäkymä neuvoo tässä (ks. *Ulkoasu*).
- Kertakalastuksessa ei ole maksua, eikä mikään muutu.

### Toisen vavan lupa (vain uramoodi)
Miten usea vapa toimii nyt (tarkistettu `fishing.gd`:stä):
- Vapoja on kaksi (`ROD_COUNT := 2`) vain avovedessä. Jäällä on aina yksi
  vapa (`rod_count()`).
- Toinen vapa on aina mukana: sitä ei osteta. Uistimet ja syötit tulevat
  samasta varastosta.
- Toinen siima tulee veteen vain uistelumoodissa:
  1. Pelaaja heittää vavan 1 ja painaa R, jolloin vapa 1 menee telineeseen
     (siima vedessä) ja vapa 2 tulee käteen.
  2. Kun vapa on telineessä (`trolling()`), vasen hiiri ei heitä vapaa 2,
     vaan laskee sen siiman veneen perään (`_let_out`, `fishing.gd` noin rivi 623).
  3. Tämän jälkeen myös vapa 2 voi mennä telineeseen.
- Toimii kaikilla välineillä, myös ongella.
- Yksi vapa telineessä ilman toista siimaa on edelleen yksi vapa.

Sääntö (Teemu: "toiselle vavalle pitää maksaa 10 € lupamaksu tekoaltaalle"):
**Kahdella vavalla voi siis kalastaa jo nyt.** Tämä tehtävä lisää siihen
vain luvan; uutta vapamekaniikkaa ei tarvita.

- Kalastustarvikeliikkeeseen tulee **Tekoaltaan lupa toiselle vavalle,
  10 €**. Lupa on voimassa **kalenterivuoden, 31.12. loppuun**, kuten
  vuosimaksu (Teemu päätti).
- **Toinen vapa vaatii sekä voimassa olevan luvan että voimassa olevan
  kalastonhoitomaksun** (Teemu päätti). Ne ovat erillisiä: kumpikin päättyy
  omana päivänään. Jos maksu loppuu, vuoden lupa säilyy ja toimii taas, kun
  maksun maksaa uudelleen.
- Luvan voi ostaa, vaikka kalastonhoitomaksua ei ole (Teemu päätti).
  Liikkeessä kerrotaan, että käyttö vaatii myös maksun.
- Jos toinen tai kumpikin puuttuu, vavan voi laittaa telineeseen ja ottaa
  toisen käteen, mutta toisen vavan siimaa ei voi laskea veteen niin kauan
  kuin ensimmäinen on telineessä vedessä. Tulee ilmoitus (ks. *Pelin
  aikana*). Pelaaja voi silti ottaa telinevavan käteen (R) ja kalastaa sillä.
- Oikeus tarkistetaan reissun alussa, kuten maksu.
- Ainoa estokohta on `_let_out` uistelumoodissa. Tavallinen heitto ei
  koskaan tuo toista siimaa veteen, koska telinevavan aikana ei heitetä.
- Uuden uran alussa ja vanhoissa tallennuksissa lupaa ei ole.
- Kertakalastuksessa ei ole lupaa eikä rajoitusta.

### Kalan vapautus
- Kun kala on haavissa (avovesi) tai jäällä (pilkki) eli saalisikkuna on auki
  (`Fishing.State.LANDED`), **Z vapauttaa kalan**. Vasen hiiri toimii kuten
  ennenkin: kala saaviin ja kalastus jatkuu.
- Vapautus onnistuu vain heti saaliin jälkeen; saavista ei voi vapauttaa.
  Verkon kaloja ei voi vapauttaa.
- Vapautettu kala poistuu reissun saaliista (`trip_catch`). Se ei näy saavissa
  (Tab ja 3D-saavi), eikä sitä viedä kotiin säilöön.
- Kalakirja ja ennätyslista toimivat kuten nyt: kala on kirjattu jo
  haavinnassa, ja vapautus ei muuta kirjausta. Kalakirjaan ei tule erillistä
  vapautettujen laskuria.
- Kalakanta ei muutu: saatu kala korvataan uudella jo nyt
  (`population.remove_and_replace`).
- Vapautus toimii myös kertakalastuksessa, mutta mainetta saa vain uramoodissa.
- Z ei tee mitään muissa tiloissa.

### Maine (vain uramoodi)
- Maine on uusi kokonaisluku, joka tallennetaan uraan (`ura.json`). Uusi ura
  ja vanha tallennus alkavat nollasta. Maine ei laske.
- Vapautettu kala antaa mainetta:
  - alle 50 g kala: 0 pistettä
  - muuten 1 piste alkavaa kiloa kohden (0,40 kg → 1, 1,00 kg → 1,
    3,20 kg → 4)
  - lisäksi +5, jos kala on vähintään lajinsa ison kalan rajan painoinen
    (taulukko alla).
  - Esimerkkejä: ahven 0,45 kg → 1 + 5 = 6; hauki 6,2 kg → 7 + 5 = 12;
    kiiski 0,04 kg → 0.

**Ison kalan rajat (Teemu hyväksynyt):**

| Laji | Painojakauma `Species.DATA` (mediaani, hajonta, min–max) | Raja | Maine rajan kalasta |
|---|---|---|---|
| Hauki | 1,6 kg, 0,7, 0,4–14 kg | **5,0 kg** | 5 + 5 = 10 |
| Lahna | 1,0 kg, 0,55, 0,25–6 kg | **2,5 kg** | 3 + 5 = 8 |
| Made | 0,7 kg, 0,55, 0,2–5 kg | **1,7 kg** | 2 + 5 = 7 |
| Ahven | 0,15 kg, 0,6, 0,04–1,6 kg | **0,40 kg** | 1 + 5 = 6 |
| Särki | 0,12 kg, 0,55, 0,03–1,4 kg | **0,30 kg** | 1 + 5 = 6 |
| Kiiski | 0,03 kg, 0,45, 0,01–0,18 kg | **0,06 kg** | 1 + 5 = 6 |

Perustelu: pelin kalan paino arvotaan log-normaalijakaumasta
(`Species.random_weight`: mediaani × e^(hajonta × normaalijakauma)). Raja on
lajin painojakauman 95. persentiili (mediaani × e^(1,645 × hajonta))
pyöristettynä selkeään lukuun. Laskettuina persentiilit ovat: hauki 5,06,
lahna 2,47, made 1,73, ahven 0,40, särki 0,30 ja kiiski 0,063 kg. Jokaisen
lajin kaloista noin joka 20. on siis "iso", joten lisäpisteet ovat yhtä
harvinaisia kaikilla lajeilla. Rajat sopivat myös suomalaiseen käsitykseen
isosta kalasta: hauki 5 kg ja ahven 400 g ovat "hyviä kaloja". Varaus:
jakauma kuvaa kalakantaa, eikä kaikkia kaloja saada yhtä helposti
(syötti, uistin, verkon silmäkoko), joten pelissä saatujen kalojen osuus
voi olla eri. Kiiskistä noin 87 % on alle 50 g eikä anna mainetta ollenkaan,
mutta harvinainen 60 g kiiski antaa 6. Vanhojen tallennusten lajit (kuha,
taimen) eivät enää tule saaliiksi, joten ne puuttuvat taulukosta.

### Maineen vaikutus: parempi myyntihinta
- Myyntihintaan tulee **+1 % jokaista täyttä 10 mainetta kohden, enintään
  +25 %** (250 mainetta). Esim. 27 mainetta → +2 %, 250 tai enemmän → +25 %.
- Lisä kerrotaan päivän kilohintaan (`Career.price`) ennen pyöristystä
  senttiin. Se näkyy myyntinäkymän kilohinnoissa ja vaikuttaa myytäessä
  saatavaan summaan (`Career.sell`).
- Lisä lasketaan myyntihetken maineesta.

## Ulkoasu ja äänet

### Saalisikkuna (`hud.gd` `_on_caught`)
Nykyinen alarivi "Vasen hiiri: jatka kalastusta" vaihtuu muotoon
```
Vasen hiiri: kala saaviin   •   Z: vapauta kala
```
Uramoodissa näkyy saatava maine, jos sitä tulee: `Z: vapauta kala (+6 mainetta)`.
Verkon noston yhteenvetoon ei tule vapautusta.

### Vapautettaessa
- Kala katoaa haavista tai jäältä, ja veneen vieressä tai avannossa kuuluu
  olemassa oleva `fish_splash`-ääni.
- Saalisikkuna sulkeutuu, ja tila palaa valmiiksi heittoon (kuten vasemmalla
  hiirellä).
- HUD-ilmoitus samalla `show_message`-tyylillä kuin muut ilmoitukset:
  - uramoodi: `Ahven 0,45 kg vapautettu – maine +6 (yhteensä 33)`
  - maineeton kala uramoodissa ja kertakalastus: `Kiiski 0,04 kg vapautettu`
- Kalastaja sanoo vapautusrepliikin (ks. *Kalastajan repliikki*).

### Kalastajan repliikki
Yksi repliikki, joka sanotaan **aina** vapautettaessa (Teemu päätti):
- `release`: "Mene kasvamaan."

Miten puhe toimii nyt (tarkistettu koodista):
- Repliikit ovat kahdessa paikassa samoilla tunnisteilla:
  - `scripts/audio/angler_voice.gd` `LINES` (tekstitys)
  - `tools/make_voice.py` `LINES` (äänitiedostot)
- Äänet syntetisoidaan Piper-puhesynteesillä (`fi_FI-harri-medium`):
  `python3 tools/make_voice.py release`. Ajo vaatii uv:n, ja
  äänimalli (~60 Mt) ladataan ensimmäisellä kerralla `data/piper/`-kansioon.
  Tulokset ovat `assets/sounds/voice/<tunniste>.wav`. Ne tuodaan Godotiin
  (`--headless --import` → `.wav.import`) ja viedään versionhallintaan.
  Ääntämys pitää kuunnella. Esim. `eagle` tarvitsi eri kirjoitusasun
  (`SPOKEN`-sanakirja), koska Piper venyttää huudahduksia.
- `AnglerVoice.setup` lataa jokaisen `LINES`-tunnisteen `.wav`-tiedoston.
  Tapahtumat tulevat `Fishing.voice`-signaalista, ja `EVENTS` antaa
  tapahtumalle repliikit ja todennäköisyyden.
- **Tärkeää:** `_finish_landing` sanoo juuri ennen vapautusta repliikin
  "big"/"small"/"landed", ja tavallisten repliikkien välillä on vähintään 6 s
  tauko (`MIN_GAP`). Vapautusrepliikki jäisi siksi yleensä sanomatta. Se pitää
  sanoa kiireellisenä (keskeyttää edellisen) kuten lajin tunnistushuuto.
  Kiireellinen polku sanoo tapahtuman nimisen repliikin suoraan `LINES`istä,
  joten repliikin tunniste on sama kuin tapahtuman (`release`). `say()`:n
  valintalogiikkaa ei tarvitse muuttaa. Ainoa muutos on, että
  `Fishing.voice`-kytkentä (`setup`: `say(event,
  event.begins_with(URGENT_PREFIX))`) käsittelee myös `release`-tapahtuman
  kiireellisenä, esim. pienellä kiireellisten tapahtumien listalla. Toisto- ja
  taukoestot eivät koske kiireellisiä repliikkejä, joten repliikki kuuluu joka
  kerta.

### Kotinäkymä (`career_view.gd` `show_home`)
Rahan rivin alle tulevat rivit samalla tyylillä (koko 18):
```
Rahaa: 12,40 €
Maine: 33  (myyntihinnat +3 %)
Kalastonhoitomaksu: voimassa 31.12. asti
Toisen vavan lupa: voimassa 31.12. asti      (tai: ei lupaa – yksi vapa)
```
Jos lupa on voimassa mutta maksu ei, luvan rivin perään tulee
`(vaatii myös kalastonhoitomaksun)`.
Maksamattomana viimeinen rivi on keltainen (sama väri kuin `_flash`,
`Color(1.0, 0.85, 0.5)`):
```
Kalastonhoitomaksu: ei maksettu – vain onki ja pilkki sallittu
```
Jos maksua ei ole eikä pelaajalla ole vuodenaikaan sopivaa onkea tai pilkkiä,
lisärivi samalla värillä:
- jos rahat riittävät vähintään halvimpaan onkeen tai pilkkiin (3 €) tai
  säilössä on myytävää: `Kalastonhoitomaksu pitää maksaa ennen
  virvelikalastusta – maksa se kalastustarvikeliikkeessä. Ilman maksua saa
  onkia ja pilkkiä (osta onki liikkeestä).`
  Tämä neuvo näkyy siis myös uuden uran alussa, koska aloitusvälineissä ei
  ole onkea.
- muuten (konkurssi, Teemun päätös: ei erikoiskäsittelyä):
  `Rahat eivät riitä onkeen eikä kalastonhoitomaksuun – voit aloittaa uuden
  uran.`

Uuden uran painike ja sen ilmoitus "Uusi ura alkoi: maanantai 1.6.
aamulla" pysyvät entisellään (vahvistus kahdella painalluksella).

### Kalojen myynti (`show_market`)
Kilohinnat sisältävät maineen lisän. Selitysrivin (koko 13, harmaa) perään
tulee esim. `Maineen hintalisä: +3 %.`, kun lisä on yli 0.

### Kalastustarvikeliike (`show_shop`)
Uusi ryhmä ylimmäksi, otsikko samalla keltaisella kuin muut ryhmät:
```
Kalastonhoitomaksu (virveli ja verkot; onki ja pilkki yhdellä vavalla ilman)
Voimassa: ei maksettu   /   Voimassa: 14.6. asti
Vuosimaksu (31.12. asti) – 47,00 €          [Maksa]
Viikkomaksu (7 vrk) – 16,00 €               [Maksa]
Vuorokausimaksu (tämä päivä) – 6,00 €       [Maksa]
```
Ilmoitus maksun jälkeen: `Kalastonhoitomaksu maksettu: voimassa 31.12. asti`.

Saman ryhmän alle tai omaksi ryhmäksi:
```
Tekoaltaan lupa toiselle vavalle (31.12. asti, vaatii myös kalastonhoitomaksun) – 10,00 €   [Maksa]
```
Painike on pois käytöstä, jos rahat eivät riitä tai lupa on jo voimassa.
Ilmoitus maksun jälkeen: `Toisen vavan lupa maksettu: voimassa 31.12. asti`.

### Pelin aikana
- Uramoodissa ilman maksua virveliuistimia ei voi valita kalapakista (L).
  Valinnasta tulee HUD-ilmoitus `Virvelikalastus vaatii kalastonhoitomaksun`.
  Jos kalapakki pystyy näyttämään ne himmennettyinä (kuten loppuneet
  uistimet), käytetään sitä. Koodaaja tarkistaa `tackle_box.gd`:stä, ettei
  välineitä vain katoa ilman selitystä.
- Reissun alussa ilman maksua tervetuloilmoitukseen lisätään rivi
  `Kalastonhoitomaksu maksamatta – vain onki ja pilkki`.
- N (lasku) ilman maksua: `Verkkokalastus vaatii kalastonhoitomaksun`. Nosto
  toimii.
- Toisen siiman lasku uistelussa ilman oikeutta. Ilmoitus kertoo, mikä
  puuttuu:
  - lupa puuttuu: `Toinen vapa vaatii tekoaltaan luvan (10 €) – R ottaa
    telinevavan käteen`
  - maksu puuttuu: `Toinen vapa vaatii kalastonhoitomaksun – R ottaa
    telinevavan käteen`
  - molemmat puuttuvat: `Toinen vapa vaatii kalastonhoitomaksun ja tekoaltaan
    luvan – R ottaa telinevavan käteen`
- Saavinäkymä (Tab) uramoodissa: lisärivi `Tällä reissulla vapautettu: 3
  kalaa, maine +8`, kun vapautuksia on.

### F1-ohje ja README
- F1 (`help_text`, osio KALASTUS): `Z            saalis haavissa tai jäällä:
  vapauta kala (uramoodissa maine)`.
- README: kalan vapautus, uramoodin kalastonhoitomaksu, toisen vavan lupa,
  maine ja hintalisä.

## Toteutus pääpiirteissään
- `scripts/career.gd`:
  - Uudet tallennettavat kentät: maksun viimeinen voimassaolopäivä uran
    päivänä (0 = ei maksua) ja maine. Vapautettujen määrä tallennetaan, jos
    sitä tarvitaan.
  - Maksut vakioina: tunniste, nimi, hinta.
  - Toisen vavan luvan tallennettava kenttä: viimeinen voimassaolopäivä,
    sama 31.12.-laskenta kuin vuosimaksussa. Lisäksi `rod_permit_valid()`,
    `pay_rod_permit()` ja `second_rod_allowed()` (lupa ja maksu
    voimassa).
  - `fee_valid()`, `fee_until_text()`, `pay_fee(kind)` (palauttaa onnistuiko).
  - Staattinen mainelaskenta (`release_fame(species, weight)`) ja ison kalan
    rajat vakiona.
  - `add_fame()` ja hintalisä `price_bonus()`.
  - `price()` käyttää hintalisää.
  - `new_career`, `load_game` (oletusarvot vanhoille tallennuksille) ja
    `save_game` päivitetään.
- `scripts/career.gd` `START_MONEY`: 20.0 → 50.0. `new_career()` ei aseta
  maksua (ura alkaa ilman maksua).
- `scripts/game_input.gd`: uusi toiminto `release_fish` = `KEY_Z`.
- `scripts/fishing/fishing.gd`:
  - LANDED-tilassa Z: uusi signaali (esim. `released(entry)`), `fish_splash`,
    kalan malli piiloon, tila READY ja `voice.emit("release")`.
  - Välinerajoitus: uusi lippu (esim. `license := true`). Kun lippu on pois,
    `lures()` jättää virveliuistimet pois (kind ≠ bobber/bottom avovedessä;
    jäällä kaikki pilkit sallittu).
- `scripts/main.gd`:
  - Reissun alussa lippu `Career.fee_valid()`:n mukaan.
  - `released` poistaa kalan `trip_catch`ista ja kirjaa maineen uramoodissa.
  - Ilmoitus HUDiin.
- `scripts/fishing/fishing.gd`: toisen vavan lippu (esim.
  `second_rod := true`). Uramoodissa reissun alussa se asetetaan
  `Career.second_rod_allowed()`:n mukaan. Kun lippu on pois, `_unhandled_input`in uistelupolku (`trolling()`
  → `_let_out`) antaa ilmoituksen eikä laske siimaa.
- `scripts/fishing/net_control.gd`: lasku estetty ilman maksua, nosto sallittu.
- `scripts/ui/hud.gd`: saalisikkunan teksti, saavin lisärivi, F1-rivi.
- `scripts/ui/career_view.gd`: kotinäkymän rivit (myös konkurssiteksti),
  liikkeen maksuryhmä ja toisen vavan lupa, myynnin hintalisärivi.
- `scripts/boat/tackle_box.gd`: estettyjen virveliuistimien näyttö.
- `scripts/audio/angler_voice.gd` ja `tools/make_voice.py`: repliikki
  `release` molempien `LINES`iin ja kiireellinen `release`-tapahtuma.
  `assets/sounds/voice/release.wav` generoidaan työkalulla.
- Testit:
  - Uusi headless-testi (esim. `--releasetest`):
    - maksun voimassaolo (päivä, 7 vrk, 31.12. ja vuodenvaihde, päällekkäinen osto)
    - maksu liian pienillä rahoilla
    - mainekaava taulukon rajoilla
    - hintalisä (0, 27 → 2 %, 300 → 25 %)
    - vapautus poistaa kalan saaliista eikä se mene säilöön
    - välinerajoitus ilman maksua
    - verkon nosto toimii ilman maksua, lasku ei
    - toisen vavan siimaa ei voi laskea ilman lupaa tai ilman maksua,
      molempien kanssa voi
    - luvan voimassaolo 31.12. asti ja vuodenvaihde
    - konkurssitilanteen tunnistus (kotinäkymän teksti)
    - vanha `ura.json` ilman uusia kenttiä latautuu.
  - `career_test.gd` (ikkuna). Testiajossa `Career.persist` on false, joten
    ura alkaa aina `new_career()`lla: 50 € eikä maksua. Muutokset
    vaiheittain:
    - **Vaihe 1 (koti).**
      - Tarkistus `aloitusrahat 20 €` / `"Rahaa: 20,00 €"` muuttuu muotoon
        `aloitusrahat 50 €` / `"Rahaa: 50,00 €"`.
      - Uusi tarkistus: `Kalastonhoitomaksu: ei maksettu` ja neuvo
        näkyvät, ja `Career.fee_valid()` on epätosi.
    - **Vaiheet 2–3 (liike).**
      - Ensimmäinen `Osta`-painike on edelleen lusikka 6 €: maksuryhmän
        painikkeiden teksti on `Maksa`, joten `Osta`-indeksit eivät muutu.
        Jos painikkeen tekstiksi tulee jotain muuta, indeksi pitää
        tarkistaa.
      - Tarkistus `14 € jäljellä` muuttuu muotoon `44 € jäljellä`
        (`Career.money` 44,0), lusikka 3.
    - **Uusi vaihe heti tämän jälkeen: maksu.** 44 € ei riitä vuosimaksuun
      (47 €), joten testi maksaa vuorokausimaksun (`Maksa`, 6 €).
      Tarkistetaan:
      - rahaa 38 €
      - `Career.fee_valid()` on tosi
      - vuosimaksun `Maksa` on pois käytöstä (rahat eivät riitä).

      Kuva `u2-kauppa` otetaan maksun jälkeen, jotta maksuryhmä näkyy.
    - **Vaihe 7 (reissu).** Maksu on voimassa, joten virveliuistimet
      toimivat, ja `lure()` on lusikka (ei muutosta).
    - **Vaihe 8 (menetetty uistin).** Ei muutosta: lusikka 3 → 2.
    - **Vaiheet 11–13 (myynti).** Ei muutosta. Tarkistus vertaa erotusta, ja
      `_fish_value` lasketaan `Career.price()`lla, joka sisältää
      hintalisän (maine 0 → +0 %).
    - **Vaihe 16 (nukuttu päivään 2).** Uusi tarkistus: vuorokausimaksu on
      päättynyt (`Career.fee_valid()` epätosi).
    - Muut vaiheet ennallaan.
  - Muut testit eivät käytä aloitusrahoja (tarkistettu `tests/`-kansiosta).
  - `--voicetest` tarkistetaan, ja tarvittaessa siihen lisätään `release`.
- README, F1-ohje ja `docs/plan.md` (tehty-merkintä). Aloitusrahoja ei nyt
  mainita README:ssä eikä `docs/plan.md`:ssä (tarkistettu). Jos ne lisätään
  uramoodin kuvaukseen, summa on 50 €.

## Hyväksymiskriteerit
- [ ] Uusi ura alkaa 50 eurolla (kotinäkymä: `Rahaa: 50,00 €`), ja
      vuosimaksun voi maksaa heti. Vanhan tallennuksen rahat eivät muutu.
- [ ] Uuden uran alussa maksua ei ole eikä sitä veloiteta automaattisesti.
      Kotinäkymä näyttää maksun tilan keltaisena ja neuvoo, että maksu
      pitää maksaa ennen virvelikalastusta (ilman maksua onki ja pilkki).
- [ ] Liikkeessä voi maksaa vuosi- (47 €), viikko- (16 €) ja vuorokausimaksun
      (6 €). Rahat vähenevät oikean summan, ja voimassaolon päivämäärä näkyy
      oikein kotinäkymässä ja liikkeessä.
- [ ] Maksun painike on pois käytöstä, jos rahat eivät riitä tai maksu ei
      pidentäisi voimassaoloa.
- [ ] Vuorokausimaksu päättyy ostopäivän lopussa, viikkomaksu 7 päivän jälkeen ja
      vuosimaksu 31.12. lopussa (myös nukkumalla).
- [ ] Ilman maksua uramoodin reissulla onki ja pilkki toimivat. Virveliuistinta
      ei voi valita eikä verkkoa laskea, ja kummastakin tulee ilmoitus.
- [ ] Ilman maksua järvessä olevan verkon voi nostaa, ja saalis tulee saaviin.
- [ ] Päällekkäinen maksu ei summaa päiviä: voimassa on myöhempi
      päättymispäivä.
- [ ] Liikkeessä voi maksaa toisen vavan luvan (10 €). Painike on pois
      käytöstä, jos rahat eivät riitä tai lupa on voimassa.
- [ ] Lupa on voimassa 31.12. loppuun, ja kotinäkymä ja liike näyttävät sen.
- [ ] Ilman lupaa tai ilman kalastonhoitomaksua vavan voi laittaa
      telineeseen, mutta toisen vavan siimaa ei voi laskea veteen. Ilmoitus
      kertoo, mikä puuttuu, ja telinevavan saa käteen R:llä.
- [ ] Kun sekä lupa että maksu ovat voimassa, kaksi vapaa toimii kuten
      ennen.
- [ ] Konkurssitilanteessa kotinäkymä kertoo, ettei rahat riitä, ja ehdottaa
      uutta uraa.
- [ ] Maksulla kaikki välineet toimivat kuten ennen.
- [ ] Kertakalastuksessa ei ole maksua eikä lupaa, eikä mikään rajoitu.
- [ ] Saalisikkunassa näkyy `Z: vapauta kala`, uramoodissa myös saatava maine.
- [ ] Z haavissa tai jäällä olevalle kalalle:
  - kala katoaa ja `fish_splash` kuuluu
  - ilmoitus näkyy, ja kalastaja sanoo joka kerta "Mene kasvamaan."
    (ääni ja tekstitys), vaikka hän olisi juuri kommentoinut saalista
  - samalla ei heitetä.
- [ ] Vapautettu kala ei ole saavissa (Tab, 3D) eikä kotona säilössä, mutta
      se on kalakirjassa ja (kertakalastuksessa) ennätyslistassa kuten ennen.
- [ ] Maine kasvaa kaavan ja hyväksytyn ison kalan taulukon mukaan. Alle 50 g
      kalasta ei saa mainetta, eikä kertakalastuksessa saa mainetta.
- [ ] Z ei tee mitään muissa tiloissa eikä verkon kaloille.
- [ ] Myyntihinnoissa on hintalisä +1 % / 10 mainetta (enintään +25 %), ja
      myynnistä saatu summa vastaa näytettyjä hintoja.
- [ ] Kotinäkymässä näkyy maine ja hintalisä, ja myyntinäkymässä hintalisä.
- [ ] Maksu ja maine säilyvät uudelleenkäynnistyksen yli, ja vanha `ura.json`
      latautuu virheettä (maine 0, maksua ei).
- [ ] F1-ohjeessa ja README:ssä on vapautus, maksu, maine ja hintalisä.
- [ ] Uusi testi ja kaikki vanhat ikkunattomat testit menevät läpi, ja
      `--careertest` toimii.
- [ ] Designer tarkistaa kuvat: saalisikkuna, kotinäkymä, liikkeen
      maksuryhmä ja toisen vavan lupa sekä myyntinäkymä.

## Päätetyt (Teemu)
- Uramoodin aloitusrahat 50 € (ennen 20 €); aloitusvälineet ennallaan.
- Uuden uran alussa maksua ei ole, eikä sitä veloiteta automaattisesti;
  pelaaja maksaa sen itse liikkeessä (v7:n automaattinen veloitus peruttu).
- Ison kalan taulukko hyväksytty sellaisenaan.
- Yksi repliikki "Mene kasvamaan.", sanotaan aina, kiireellisenä.
- Verkon nosto sallittu ilman maksua, lasku estetty.
- Konkurssi: ei erikoiskäsittelyä; kotinäkymä kertoo ja ehdottaa uutta uraa.
- Päällekkäinen maksu: myöhempi päättymispäivä jää, ei summausta.
- Hinnat 47 / 16 / 6 € (eraluvat.fi 2026).
- Toinen vapa vaatii tekoaltaan 10 euron luvan, joka on voimassa
  kalenterivuoden (31.12. asti), ja lisäksi voimassa olevan
  kalastonhoitomaksun. Liike myy luvan myös ilman maksua.
- Luvan voi ostaa myös ilman voimassa olevaa kalastonhoitomaksua; liike ja
  kotinäkymä kertovat, että käyttö vaatii myös maksun (työnjohtaja).

## Toteutuksen aikana päätetyt (työnjohtaja)
- Asettelu: maksuryhmän jälkeen liike ei mahtunut ruutuun (Takaisin jäi
  näkymättömiin). Liikkeen tuoterivit ovat vierityslaatikossa
  (ScrollContainer, hiiren rulla). Otsikko ja rahat pysyvät ylhäällä,
  ilmoitusrivi ja Takaisin alhaalla.

## Avoimet kysymykset Teemulle
Ei avoimia kysymyksiä.
