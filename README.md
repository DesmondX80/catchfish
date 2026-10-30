# Catchfish

Kalastussimulaattori Godot 4 -pelimoottorilla. Pelialueena on Raahen
Haapajärven tekoallas, joka on mallinnettu Maanmittauslaitoksen avoimesta
aineistosta. Lähdet soutuveneellä laiturista ja heittelet virvelillä uistinta
tai lasket verkon pyytämään.

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
| X | ankkuri alas / ylös (lasketaan keulasta pohjaan 1 m/s, köyttä syvyys + 0,5 m; köysi kiristyy jos yrität lähteä). Ankkuria laskiessa ja nostaessa kalastaja on keulassa köyden kimpussa, joten moottori on vapaalla eikä soutaa voi. |
| V | mela käteen / pois: melalla pääsee irti laiturista, kun airot eivät mahdu (W/S melonta, A/D melotaan toiselta puolelta) |
| Hiiri | kameran ja heittosuunnan kääntö, rulla = zoomaus |
| P | kamera: veneen takana / FPV kalastajan silmistä (valinta muistetaan) |
| Vasen hiiri | pidä = heittovoima (tähtäin näyttää osumapisteen), päästä = heitto; tärpätessä vastaisku; lopuksi haavinta |
| Oikea hiiri | kelaa (Shift = nopeasti) |
| Välilyönti | nykäisy |
| E / C | jarru kireämmälle / löysemmälle |
| Z | saalis haavissa tai jäällä: vapauta kala (uramoodissa maine) |
| L | kalapakki auki: kamera katsoo pakkia, ja uistin, koho-onki tai pohjaonki valitaan klikkaamalla sen lokeroa (L, Esc tai oikea hiiri sulkee). Talvella pieni pilkkirasia |
| F / G | kohon syvyys matalammalle / syvemmälle (ennen heittoa) |
| R | vetouistelu: heitetty vapa telineeseen ja toinen käteen, tai vapa telineestä käteen |
| Hiiri uistellessa | kun vapa on telineessä (uistelumoodi): vasen hiiri pohjassa laskee käsivavan uistimen veneen perään; FPV:ssä vasen/oikea hiiri nostaa ruudun vasemman/oikean telinevavan ja antaa tärpissä vastaiskun |
| B | verkon silmäkoko: 22 mm (särki, ahven, kiiski), 35 mm (lahna, isot ahvenet, made), 50 mm (hauki, iso lahna, made) |
| N | verkko: laske soutaen laidan yli perän läheltä (N uudelleen lopettaa), pyykin luona pysähtyneenä nosta |
| T | ajan nopeus (x1 / x10 / x60) |
| Tab | kalasaavi: kamera saavin yläpuolelle ja sivulle saaliin painot |
| F1 | ohje |
| Esc | tauko (myös ohjeet, kalakirja ja asetukset) |

Hiiren herkkyyden, käänteisen pystyohjauksen, veden laadun ja äänenvoimakkuudet
(kaikki äänet, taustaäänet, efektit, kalastajan puhe) voi säätää alkuvalikon tai
taukovalikon kohdasta *Asetukset*. Asetukset tallennetaan koneelle. *Veden laatu*
on Korkea (tarkat aallot ja väreet, työpöydän oletus) tai Matala (kevyempi
lähivesi, väreiden tilalla pinnan karheus, selaimen oletus); vaihto tulee voimaan heti myös kesken kalareissun, eikä se
muuta veneen keinuntaa.

Alkuvalikon taustalla on mökin pirtti, jossa takka lepattaa ja pöydän takana
vanhassa kuvaputki-TV:ssä pyörii kalastusohjelma (veneilijä iltajärvellä, koho
painuu, hauki hyppää).

## Simulaatio lyhyesti

- **Vene**: valkoinen lasikuituinen soutuvene (limisaumaa jäljittelevät kyljet,
  kermanvärinen sisäpuoli) ja perässä pieni musta nelitahtinen perämoottori,
  jonka potkuri pyörii ajettaessa. Oma vesifysiikka (työntövoima, vastus, sivuttaisvastus), tuuli
  ajelehdittaa (kylki tuuleen paljon enemmän kuin keula), ankkuri pitää
  paikallaan, matalikolla vene osuu pohjaan. Vastatuuleen pääsee kovallakin
  tuulella soutaen ja meloen: keula tuuleen kalastaja vetää kovempaa.
  Laituriin vene kolahtaa ja pysähtyy, viistossa törmäyksessä se liukuu
  laituria pitkin.
  Perämoottorin potkuri ulottuu lähes metrin syvyyteen: matalassa se osuu
  pohjaan ja vääntyy, ja liian monesta osumasta se menee rikki, jolloin
  loppureissu soudetaan. Matalasta varoitetaan, ja vapaalla potkuri ei pyöri.
- **Aika ja sää**: aurinko liikkuu Raahen leveysasteella kesäkuussa,
  tuuli vaihtelee ja puuskittelee. Aallokon koko riippuu tuulesta ja
  pyyhkäisymatkasta eli siitä, kuinka pitkän matkan tuuli on puhaltanut
  veden yli: ylätuulen rannan ja saarten suojassa on tyyntä, selällä
  lyhyttä, jyrkkää aallokkoa (8 m/s tuulella noin 4 m pitkät ja 0,2 m
  korkeat aallot, terävät harjat ja leveät pohjat). Aallokko kasvaa tuulen
  voimistuessa noin 10 ja laantuu noin 20 peliminuutissa, ja tuulen
  kääntyessä uusi aallokko kasvaa uuteen suuntaan minuutin kuluessa.
  Väreet syntyvät tuulesta jo muutaman metrin matkalla: ne näkyvät selvästi
  2 m/s tuulesta alkaen myös kapeissa lahdissa, ja vain ylätuulen rannan
  ensimmäisillä metreillä ne ovat heikompia. Tyynellä pinta on lähes
  peilityyni. Aallot ja väreet ovat epäsäännöllisiä, lyhytharjaisia
  muodostumia tuulen suunnassa. Puuskat näkyvät tuulen mukana kulkevina tummina
  värelaikkuina. Noin 4 m/s tuulesta alkaen aallonharjat murtuvat selällä
  ja alatuulen rannan edessä vaahtopäiksi, jotka ajelehtivat tuulen mukana
  ja hajoavat; kovalla tuulella pintaan jää myös tuulen suuntaisia
  vaahtojuovia. Vene, koho, verkon pyykit ja ankkuri keinuvat samassa
  aallokossa, ja aaltojen loiske on suojassa hiljaisempaa kuin selällä.
  Veneen varjo lankeaa vedenpintaan rungosta alkaen auringon mukaan:
  aamulla ja illalla pitkänä, keskipäivällä lähes veneen alla. Ruskeassa
  vedessä pohjan varjo sumenee syvyyden mukaan. Vene, kalastaja, vavat ja
  kamera liikkuvat ruudulla tasaisesti myös silloin, kun näytön
  virkistystaajuus ei ole pelin fysiikan 60 Hz.
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
  käteen. Samalla peli siirtyy uistelumoodiin ja kamera FPV-tilaan (P
  vaihtaa takaisin). Uistelumoodissa toisella vavalla ei heitetä: pidä
  vasenta hiirtä pohjassa ja soutele, niin uistin jää veneen perään ja
  siimaa lähtee (enintään 60 m), ja R laittaa senkin vavan telineeseen.
  Uistimet kulkevat perässä omassa uintisyvyydessään. Tärpin tullessa vavan
  kärki nykäisee. FPV-kamerassa vasen hiiri nostaa ruudun vasemmalla
  puolella näkyvän telinevavan ja oikea hiiri oikeanpuoleisen, ja tärpissä
  nosto on samalla vastaisku, joka ei aina onnistu (veneen vauhti auttaa).
  Jos toinen vapa on kädessä, se menee telineeseen nostettaessa. R ottaa
  tärppäävän vavan käteen myös kolmannen persoonan kamerassa. Ilman
  vastaiskua veneen vauhti koukuttaa kalan vain joskus itsestään.
- **Onki ja syötit**: koho-ongella mato roikkuu kohon alla syvyydessä, jonka
  säädät ennen heittoa (F/G). Koho kelluu aallokon mukana ja kallistelee
  tuulen voimakkuuden mukaan. Pohjaongella paino on pohjassa ja mato noin
  puolen metrin korkeudella pohjasta. Tärpissä kala maistelee ensin: koho
  nykii tai vavan kärki värähtelee, ja vastaisku tehdään vasta, kun koho
  painuu pinnan alle tai siima kiristyy. Särki, lahna, kiiski, ahven ja made
  syövät matoa, hauki tuskin koskaan.
- **Verkkokalastus** (avovesikaudella): valitse silmäkoko (B) ja paina N, niin
  merkkipyykki ja kivi putoavat veteen. Souda hitaasti: 30 metrin pohjaverkko
  valuu löysänä laidan yli perän läheltä veneen reitille, ja toinen pyykki putoaa, kun verkko on
  vedessä (N lopettaa aiemmin, matalassa lasku päättyy itsestään). Liian
  kovassa vauhdissa verkko jarruttaa. Anna verkon pyytää tunteja, esimerkiksi
  illasta aamuun (T nopeuttaa aikaa), ja nosta se pysähtymällä pyykin luo
  moottori sammuksissa ja painamalla N: kalastaja vetää löysää verkkoa laidan
  yli kasaan veneen pohjalle, vene liukuu verkkoa pitkin, ja verkkoon
  tarttuneet kalat nousevat pinnasta näkyviin verkossa roikkuen. Saalis riippuu
  verkkopaikasta, kellonajoista, vuodenajasta ja silmäkoosta: pieni silmä pyytää
  pieniä kaloja, iso isoja. Iso hauki voi repiä verkkoon reiän. Järvessä voi
  olla kolme verkkoa, ja ne näkyvät kartalla (K). Verkkokalat menevät saaviin,
  ennätyksiin ja kalakirjaan kuten vapakalat. Uramoodissa verkot ostetaan
  kalastustarvikeliikkeestä, ne jäävät järveen reissujen yli, ja jäiden tullessa
  järveen jääneet verkot menetetään.
- **Kalan vapautus**: kun saalis on haavissa tai jäällä (saalisikkuna auki),
  Z päästää kalan takaisin järveen ja vasen hiiri laittaa sen saaviin.
  Vapautettu kala ei mene saaviin eikä kotiin säilöön, mutta se on
  kalakirjassa ja ennätyslistassa. Kalastaja sanoo "Mene kasvamaan.".
  Verkon kaloja ei voi vapauttaa.
- **Uramoodin kalastonhoitomaksu**: virvelikalastus ja verkot vaativat
  kalastonhoitomaksun, jonka maksat itse kalastustarvikeliikkeessä:
  vuosimaksu 47 € (31.12. asti), viikkomaksu 16 € (7 vrk) tai
  vuorokausimaksu 6 € (ostopäivä). Ilman maksua saa onkia ja pilkkiä, ja
  järvessä olevan verkon saa nostaa. Uusi ura alkaa 50 eurolla ilman maksua.
  Maksu tarkistetaan reissun alussa.
- **Toisen vavan lupa** (uramoodi): toisen siiman lasku veneen perään
  uistellessa vaatii tekoaltaan luvan (10 €, 31.12. asti) ja voimassa olevan
  kalastonhoitomaksun.
- **Maine** (uramoodi): vapautettu kala antaa mainetta 1 pisteen alkavaa
  kiloa kohden ja 5 lisäpistettä, jos kala on lajinsa iso kala (hauki 5 kg,
  lahna 2,5 kg, made 1,7 kg, ahven 400 g, särki 300 g, kiiski 60 g). Alle 50 g
  kalasta ei saa mainetta. Maine nostaa kalojen myyntihintaa 1 % jokaista
  10 mainetta kohden, enintään 25 %.
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
  saaliit. Versiossa 0.46.0 ennätyslista ja kalakirja tyhjennettiin kerran,
  koska kalalajit ovat muuttuneet pelin alkuajoista.
- **Linnut**: taivaalla lentää variksia, korppeja, sorsia, hanhiparvia
  (V-muodostelmassa), lokkeja ja harvinaisempana merikotka. Ne lentävät
  järven yli tai kaartelevat hetken veneen lähistöllä ja ääntelevät
  lähellä. Talvella sorsat, hanhet ja lokit ovat muuttaneet pois, ja
  hanhia näkee eniten muuttoaikaan keväällä ja syksyllä. Kun kalastaja
  näkee merikotkan, hän huudahtaa "Oho! Merikotka!".
- **Muut veneet**: avovesikaudella valoisaan aikaan järvellä liikkuu silloin
  tällöin muita kalastajia, enintään kaksi venettä kerrallaan: moottorivene
  ajaa laiturilta toiselle laiturille tai kalapaikalle, ja soutuvene soutaa
  kalapaikalle, kalastaa ankkurissa 5–15 minuuttia ja palaa (kodan matalalta
  laiturilta lähtee vain soutuveneitä). Ensimmäinen vene
  lähtee 2–6 minuutin kuluttua pelin alusta ja seuraava 4–12 minuutin välein
  (todellista aikaa); yksi vene voi olla järvellä jo alussa. Kovalla tuulella
  (yli 8 m/s) ja rankkasateella ei lähdetä, ja hämärän tullen veneet palaavat
  laiturille. Veneet ilmestyvät ja katoavat laitureilla vain, kun olet kaukana
  tai et katso laituria kohti. Ne kulkevat syvää vettä pitkin ja kiertävät
  sinut ja verkkojesi pyykit. Ohi ajavan moottoriveneen peräaallot saapuvat
  vanan V-haaran mukana ja keinuttavat venettäsi noin 4–5 aallon ajan:
  kylki aaltoon enemmän kuin keula, lähellä enemmän kuin kaukana. Muiden
  veneiden läpi ei pääse: niihin voi törmätä kuten laituriin.
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
   python3 tools/build_fetch.py
   ```

   `build_fetch.py` laskee aallokkoa varten pyyhkäisymatkat
   (`assets/lake/fetch.bin`): kuinka pitkän matkan tuuli on puhaltanut veden
   yli kuhunkin kohtaan 16 tuulensuunnasta. Se tarvitsee vain `water.bin`:n,
   joten se on ajettava uudelleen aina, kun järvi tehdään uudelleen.

Rantaviiva tulee maastotietokannan järvikuviosta ja maasto korkeusmallista.
Tekoaltaasta ei ole syvyyskarttaa, mutta altaan pohja on vanhaa maastoa, ja
maastotietokannan korkeuskäyrät jatkuvat veden alla. **Syvyydet tulevat
käyristä**: 15 m:n käyrä on 3,3 m:n ja 12,5 m:n käyrä 5,8 m:n syvyydessä
(vedenpinta 18,3 m), ja niiden välillä syvyys interpoloidaan. Vanhan jokiuoman
syvänteet (12,5 m:n käyrien sisällä) syvenevät enintään 7 metriin, joka on
paikallistiedon mukaan altaan syvin kohta. Rannoilla vesi syvenee heti noin
0,8 metriin, ja maatuvat vesialueet ovat matalia.

Raakadataa ei ole versionhallinnassa (`.gitignore`).

## Testit

Ikkunattomat testit ajetaan GitHub Actionsissa Godot 4.7.2:lla jokaisesta
pushista ja PR:stä (`.github/workflows/tests.yml`). Samat testit voi ajaa
itse:

```bash
tools/run_tests.sh                            # kaikki (Godot: $GODOT, godot-4.7.2 tai godot)
tools/run_tests.sh /polku/godotiin luretest   # vain nimetyt, Godot annettuna
tools/run_tests.sh -q                         # vain tulosrivit ja yhteenveto päätteeseen
tools/run_tests.sh --repeat=10 luretest       # epävakaan testin toistoajo
tools/run_tests.sh --ref=origin/main --repeat=3 luretest  # sama mainissa (väliaikainen työkopio)
```

Lopuksi tulostuu yhteenvetotaulukko (testi, tulos, kesto ja epäonnistuneen
testin `VIRHE`-rivit). Tulosrivit alkavat `>>`, joten ne erottuvat testien
omista riveistä. Koko ajo tallentuu lokiin `.test-logs/` (20 viimeisintä,
`latest.log` uusimpaan; `--log=TIEDOSTO` muuttaa polun). Aikaraja on
`TEST_TIMEOUT` sekuntia testiä kohti (oletus 600). Paluukoodi on 0, kun kaikki
menivät läpi, 1, jos jokin epäonnistui, ja 2 väärällä käytöllä.
`tools/run_tests_selftest.sh` testaa itse ajurin valekomennolla.

Jokaisen testin käynnistysohje on testitiedoston (`tests/*_test.gd`) alussa.
Ikkunaa vaativat testit (esim. `--inputtest`, `--pausetest`, `--menutest`)
ajetaan käsin. Välkkymisen ja nykimisen voi mitata kuvista:
`godot --fixed-fps 60 --resolution 480x270 -- --day=180 --jittershots=KANSIO`
merkitsee punaisella pikselit, jotka vaihtavat väriä edestakaisin.

Äänimuutokset näkee lokista ilman kuuntelua: `--audio-log` tulostaa jokaisesta
soitetusta äänestä rivin (pelin kello, äänen nimi, etäisyys veneestä), esim.
`godot --headless --fixed-fps 30 -- --day=180 --audio-log --casttest`.
Lipun voi antaa myös editorin ajoon; rivit näkyvät Output-paneelissa.

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
