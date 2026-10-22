# Catchfish

Kalastussimulaattori Godot 4 -pelimoottorilla. Pelialueena on Raahen
Haapajärven tekoallas, joka on mallinnettu Maanmittauslaitoksen avoimesta
aineistosta. Lähdet soutuveneellä laiturista ja heittelet virvelillä uistinta.

## Pelaa

- **Selaimessa:** <https://desmondx80.github.io/catchfish/> (uusin julkaisu;
  klikkaa peliruutua, niin hiiri kaappautuu peliin)
- **Windows:** lataa `Catchfish.exe`
  [uusimmasta julkaisusta](https://github.com/DesmondX80/catchfish/releases/latest)

Selainversio tehdään jokaisesta GitHub-julkaisusta automaattisesti
(`.github/workflows/pages.yml`).

## Käynnistys Godotissa

1. Asenna [Godot 4.7](https://godotengine.org/download) (tavallinen versio, ei .NET).
2. Avaa Godotissa *Import* → valitse tämän kansion `project.godot`.
3. Paina F5.

Ensimmäinen käynnistys kestää muutaman sekunnin, kun järvi, metsä ja kalat luodaan.

## Ohjaus

| Näppäin | Toiminto |
|---|---|
| W / S | kaasu (moottori) tai soutu eteen/taakse |
| A / D | ohjaus |
| Q | perämoottori käyntiin / sammuksiin (sammuksissa soudetaan) |
| X | ankkuri alas / ylös (lasketaan keulasta pohjaan, köysi kiristyy jos yrität lähteä) |
| V | mela käteen / pois: melalla pääsee irti laiturista, kun airot eivät mahdu (W/S melonta, A/D melotaan toiselta puolelta) |
| Hiiri | kameran ja heittosuunnan kääntö, rulla = zoomaus |
| Vasen hiiri | pidä = heittovoima (tähtäin näyttää osumapisteen), päästä = heitto; tärpätessä vastaisku; lopuksi haavinta |
| Oikea hiiri | kelaa (Shift = nopeasti) |
| Välilyönti | nykäisy |
| E / C | jarru kireämmälle / löysemmälle |
| L | kalapakki auki: kamera katsoo pakkia, ja uistin, koho-onki tai pohjaonki valitaan klikkaamalla sen lokeroa (L, Esc tai oikea hiiri sulkee). Talvella pieni pilkkirasia |
| F / G | kohon syvyys matalammalle / syvemmälle (ennen heittoa) |
| R | vetouistelu: heitetty vapa telineeseen ja toinen käteen, tai vapa telineestä käteen |
| T | ajan nopeus (x1 / x10 / x60) |
| Tab | kalasaavi: kamera saavin yläpuolelle ja sivulle saaliin painot |
| F1 | ohje |
| Esc | tauko (myös ohjeet ja kalakirja) |

## Simulaatio lyhyesti

- **Vene**: oma vesifysiikka (työntövoima, vastus, sivuttaisvastus), tuuli
  ajelehdittaa, ankkuri pitää paikallaan, matalikolla vene osuu pohjaan.
  Laituriin vene kolahtaa ja pysähtyy, viistossa törmäyksessä se liukuu
  laituria pitkin.
  Perämoottorin potkuri ulottuu lähes metrin syvyyteen: matalassa se osuu
  pohjaan ja vääntyy, ja liian monesta osumasta se menee rikki, jolloin
  loppureissu soudetaan. Matalasta varoitetaan, ja vapaalla potkuri ei pyöri.
- **Aika ja sää**: aurinko liikkuu Raahen leveysasteella kesäkuussa,
  tuuli vaihtelee ja puuskittelee.
- **Uistimet**: uppoavat (lusikka, lippa, jigi) vajoavat levossa nopeasti
  pohjaan. Lusikka ui kelatessa ja uistellessa 1,5 metrin syvyydessä
  ja nopeasti kelatessa 1 metrissä (syvältä se nousee sinne hiljalleen).
  Kun kelaus tai uistelu pysähtyy, lusikka vajoaa pohjaan; lippa ja jigi nousevat vedettäessä
  hiljalleen, mutta pysyvät pinnan alla.
  Vaaput kelluvat levossa pinnalla ja uivat kelatessa ja uistellessa
  tavoitesyvyydessään. Pohjaa laahaava uistin voi tarttua kiinni.
- **Kalat**: tekoaltaan kalakanta eli ahven, särki, hauki, kiiski, lahna
  ja made. Jokaisella lajilla on oma elinpaikka (syvyys, rannan ja
  kaislikon läheisyys), vuorokausirytmi, vuodenaikarytmi, mieluisat
  uistimet ja uistinnopeus. Hauki ja ahven iskevät uistimiin; särki,
  kiiski, lahna ja made syövät mieluiten syöttiä, eli niitä saa parhaiten
  talvella pilkillä ja toukalla. Made on talven kala ja syö pimeällä. Kalat
  elävät vuodenaikojen mukaan: hauki kutee heti jäiden lähdettyä matalissa
  kaislikkolahdissa ja syö kudun jälkeen ahnaasti, ahven, särki ja lahna kutevat
  touko–kesäkuussa matalassa, kesähelteellä kalat hakeutuvat syvempään ja
  syksyllä syönti vilkastuu. Ilmanpaine vaikuttaa syöntiin: kun paine laskee
  (sää muuttuu, rintama tulossa), kalat syövät kiivaasti; tasaisessa
  korkeapaineessa syönti on laiskaa. HUD näyttää paineen ja sen suunnan. Kalat ovat dataa: niitä ei näe,
  mutta kaikuluotain näyttää ne.
- **Kaikuluotain**: kuva piirtyy kuten oikeassa luotaimessa. Veneen ajaessa
  kalan yli siitä piirtyy kaari, ja kaiun väri kertoo voimakkuuden (iso kala
  keltainen tai punainen). Pohjan laatu erottuu: kova pohja (hiekka, kivikko)
  antaa kirkkaan kaiun ja toisen heijastuksen kaksinkertaisessa syvyydessä,
  muta pehmeän ja himmeän kaiun, ja vesikasvillisuus näkyy pohjasta nousevina
  tupsuina. Luotaimen alareunassa lukee pohjan laatu.
- **Hauki seuraa uistinta**: hauki voi lähteä seuraamaan heitettyä uistinta
  ja tulla näkyviin pinnan lähellä veneen vieressä. Kelaa tasaisesti, niin se
  iskee usein viime hetkellä; nykäisy veneen lähellä houkuttelee. Jos uistin
  pysähtyy tai kelaat liian lujaa, hauki kääntyy pois.
- **Vetouistelu**: veneessä on kaksi vapaa. Heitä uistin veneen perään ja
  paina R, niin vapa menee perälaudan vapatelineeseen ja toinen vapa tulee
  käteen. Kun molemmat vavat ovat telineissä, soutele tai aja moottorilla:
  uistimet kulkevat perässä omassa uintisyvyydessään. Tärpin tullessa vavan
  kärki nykäisee, ja veneen vauhti voi koukuttaa kalan itsestään. R ottaa
  tärppäävän vavan käteen väsytettäväksi.
- **Onki ja syötit**: koho-ongella mato roikkuu kohon alla syvyydessä, jonka
  säädät ennen heittoa (F/G). Koho kelluu aallokon mukana ja kallistelee
  tuulen voimakkuuden mukaan. Pohjaongella paino on pohjassa ja mato noin
  puolen metrin korkeudella pohjasta. Tärpissä kala maistelee ensin: koho
  nykii tai vavan kärki värähtelee, ja vastaisku tehdään vasta, kun koho
  painuu pinnan alle tai siima kiristyy. Särki, lahna, kiiski, ahven ja made
  syövät matoa, hauki tuskin koskaan.
- **Kalastajan puhe**: kalastaja kommentoi tapahtumia lyhyillä
  repliikeillä ("No nyt tärppäs!", "Ei perhana tule mitään."), ja repliikki
  näkyy myös tekstityksenä.
- **Väsytys**: kala ryntäilee ja lepää, jarru antaa siimaa, liian kireä
  jarru katkaisee siiman ja löysä siima päästää kalan irti. Kalan lajin
  näkee vasta, kun kala tulee tummassa humusvedessä näkyviin veneen
  lähelle tai rimpuilee pinnassa.
- **Kalakirja** (alkuvalikko tai Esc-valikko): jokaisella lajilla on oma sivu,
  jossa on kuvaus, kuva, saaliiden määrä, oma ennätys ja ensimmäinen saalis.
  Laji avautuu kirjaan, kun saat sen ensimmäisen kerran (siihen asti sivulla
  on vain varjokuva). Kirjaan tulevat sekä kertakalastuksen että uramoodin
  saaliit.
- **Linnut**: taivaalla lentää variksia, korppeja, sorsia, hanhiparvia
  (V-muodostelmassa), lokkeja ja harvinaisempana merikotka. Ne lentävät
  järven yli tai kaartelevat hetken veneen lähistöllä ja ääntelevät
  lähellä. Talvella sorsat, hanhet ja lokit ovat muuttaneet pois, ja
  hanhia näkee eniten muuttoaikaan keväällä ja syksyllä. Kun kalastaja
  näkee merikotkan, hän huudahtaa "Oho! Merikotka!".
- Lajien arvot ovat tiedostossa `scripts/fishing/species.gd` ja uistinten
  `scripts/fishing/lures.gd`.

## Järven data

Valmiiksi käsitelty järvi on kansiossa `assets/lake/`. Sen voi tehdä
uudelleen MML:n aineistosta:

1. Lataa [Karttapaikan](https://asiointi.maanmittauslaitos.fi/karttapaikka/)
   tiedostopalvelusta alueelta *Maastotietokanta, kaikki kohteet* (GeoPackage)
   ja *Korkeusmalli 2 m* (GeoTIFF), koordinaatisto ETRS-TM35FIN.
2. Tallenna ne nimillä `data/mml/maastotietokanta_kaikki.gpkg` ja
   `data/mml/korkeusmalli_2m.tif`.
3. Aja (vaatii Pythonin, NumPyn ja GDALin):

   ```bash
   python3 tools/build_lake.py --mml data/mml
   ```

Rantaviiva tulee maastotietokannan järvikuviosta ja maasto korkeusmallista.
Tekoaltaasta ei ole syvyyskarttaa, mutta altaan pohja on vanhaa maastoa, ja
maastotietokannan korkeuskäyrät jatkuvat veden alla. **Syvyydet tulevat
käyristä**: 15 m:n käyrä on 3,3 m:n ja 12,5 m:n käyrä 5,8 m:n syvyydessä
(vedenpinta 18,3 m), ja niiden välillä syvyys interpoloidaan. Vanhan jokiuoman
syvänteet (12,5 m:n käyrien sisällä) syvenevät enintään 7 metriin, joka on
paikallistiedon mukaan altaan syvin kohta. Rannoilla vesi syvenee heti noin
0,8 metriin, ja maatuvat vesialueet ovat matalia.

Raakadataa ei ole versionhallinnassa (`.gitignore`).

## Lisenssit

Sisältää Maanmittauslaitoksen Maastotietokannan ja Korkeusmalli 2 m
-aineistoa (CC BY 4.0).

Kalastajahahmo on Quaterniuksen "Adventurer"-malli (CC0, ks.
`assets/characters/LICENSE.txt`).

Perämoottorin, airojen, melan, aaltojen, tuulen ja taivaan lintujen äänet ovat Freesoundin CC0-nauhoituksia:

- perämoottori: kyles, [637744](https://freesound.org/people/kyles/sounds/637744/)
- airovedot: SkibkaMusic, [478973](https://freesound.org/people/SkibkaMusic/sounds/478973/)
- melanvedot: Danjocross, [503208](https://freesound.org/people/Danjocross/sounds/503208/)
- pienet aallot: mcmikai, [532179](https://freesound.org/people/mcmikai/sounds/532179/)
- isot aallot: Ali_6868, [384360](https://freesound.org/people/Ali_6868/sounds/384360/)
- heikko tuuli: kyles, [454360](https://freesound.org/people/kyles/sounds/454360/);
  talvella MHCerberus, [141143](https://freesound.org/people/MHCerberus/sounds/141143/)
- kova tuuli: teadrinker, [403051](https://freesound.org/people/teadrinker/sounds/403051/);
  talvella jpnien, [97397](https://freesound.org/people/jpnien/sounds/97397/)
- varis: straget, [404687](https://freesound.org/people/straget/sounds/404687/)
- korppi ja merikotka: inspire153, [849152](https://freesound.org/people/inspire153/sounds/849152/),
  [833715](https://freesound.org/people/inspire153/sounds/833715/)
- sorsa: WavJunction.com, [456770](https://freesound.org/people/WavJunction.com/sounds/456770/)
- hanhet: EpicWizard, [425488](https://freesound.org/people/EpicWizard/sounds/425488/)
- lokki: Canardo55, [538016](https://freesound.org/people/Canardo55/sounds/538016/)

Lähteet ovat kansiossa `data/sounds/`, ja pelin äänet tehdään niistä komennolla
`uv run --no-project --with miniaudio --with numpy python tools/make_recorded_sounds.py`.
Muut äänet on syntetisoitu itse (`tools/make_sounds.py`).

Kalastajan puhe on tehty Piper-puhesynteesillä suomenkielisellä
fi_FI-harri-äänellä (opetusaineisto CC0). Repliikit voi tehdä uudelleen
komennolla `python3 tools/make_voice.py` (vaatii uv:n) tai korvata omilla
äänityksillä kansiossa `assets/sounds/voice/`.
