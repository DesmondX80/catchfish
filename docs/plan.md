# Catchfish – suunnitelma ja tilanne

Päivitetty 22.10.2026. Nykyinen versio **0.36.0**
([release](https://github.com/DesmondX80/catchfish/releases/tag/v0.36.0)).

Catchfish on Godot 4.7 -kalastussimulaattori Raahen Haapajärven tekoaltaalla.
Järvi on mallinnettu Maanmittauslaitoksen avoimesta aineistosta. Pelaaja soutaa
tai ajaa moottorilla, heittelee virvelillä, uistelee, onkii ja pilkkii talvella.
Käyttöohje ja ohjaus ovat [README.md](../README.md):ssä.

## Tähänastinen tilanne

### Valmiina (versiot 0.1–0.36.0)

| Alue | Ominaisuudet |
|---|---|
| Vene | Oma vesifysiikka, soutu, mela ja perämoottori, ankkuri, tuuli ajelehdittaa, pohjakosketus, törmäys laitureihin (kolahdus, liukuu laituria pitkin) |
| Maailma | MML-aineistosta tehty järvi ja maasto, metsässä mäntyjä, kuusia ja koivuja, vuodenajat todellisen päivämäärän mukaan, sää (tuuli, pilvet, sade, lumi), todellinen sää ja kellonaika valinnaisina |
| Kalastus | Virveli ja uistimet (lusikka, vaaput, lippa, jigi), taipuva vapa ja fysiikkaan perustuva siima, jarru ja väsytys, haavinta omana animaationaan omalla kameralla |
| Uistimet | Lusikka ui kelatessa ja uistellessa 1,5 m:ssä (nopeasti kelatessa 1 m) ja vajoaa pohjaan vedon pysähtyessä; vaaput kelluvat ja uivat tavoitesyvyydessään |
| Vetouistelu | Kaksi vapaa ja vapatelineet perälaudassa (R), tärppi telineeseen, veneen vauhti koukuttaa |
| Onki | Koho-onki (syvyys F/G ennen heittoa) ja pohjaonki (mato 0,5 m pohjasta), tärpissä koho nykii ja uppoaa, kamera zoomaa kohoon |
| Heitto | Tähtäin näyttää osumapisteen (sama lentofysiikka kuin heitossa) ja varoittaa rantaan menevästä heitosta |
| Talvi | Pilkkiminen avannosta: kairaus, pilkki ja tasapainopilkki, kävely jäällä |
| Kalat | Altaan kalakanta: ahven, särki, hauki, kiiski, lahna, made. Lajeilla elinpaikka, vuorokausi- ja vuodenaikarytmi, uistin- ja syöttimieltymykset, 3D-mallit. Kalat eivät näy humusvedessä (vain kaikuluotaimessa); laji tunnistetaan vasta, kun kala näkyy veneen lähellä. Hauki voi seurata uistinta veneelle ja iskeä viime hetkellä |
| Saalis | Kalasaavi veneen pohjalla (Tab: kuva ylhäältä ja painot), ennätyslista, kalan kuva saalisikkunassa |
| Uramoodi | Päivät ja kello, rahat, uistinvarasto, kalastustarvikeliike, kalojen säilö ja myynti (Luken sisävesien tuottajahinnat 2024) |
| Äänet | Moottori, airo- ja melavedot, aallot (pienet / isot) ja tuuli (heikko / kova, talvella omat) oikeista Freesoundin CC0-nauhoituksista (tools/make_recorded_sounds.py); muut syntetisoitu (tools/make_sounds.py): kela, jarru, linnut, sade |
| Kalastaja | Quaterniuksen riggattu malli (CC0): kesällä maastoasu ja lippalakki, talvella pilkkihaalari ja pipo; kädet IK:lla vapaan, airoihin, ohjausaisaan ja kairaan, istuessa jalat lattialla, jäällä kävelyanimaatio |
| Puhe | Kalastajan repliikit tapahtumiin ja lajin huudahdus tunnistettaessa (Piper-puhesynteesi, tools/make_voice.py) |

### Tehtävänhallinta

Tehtävät ovat Plane Cloudissa, projekti **CATCHFISH**. Tila 20.10.2026:
14 tehtävää valmiina, 1 peruttu, 26 avoinna.

## Suunnitelma: seuraavat tehtävät

Prioriteetti Planen mukaan, sitten oma suositusjärjestys. Numerot ovat Planen
tunnisteita (CATCHFISH-N).

### Kiireelliset ja korkeat (Todo)

Ei avoimia (#29 ja #17 tehty 0.26.0:ssa).

### Pelattavuus ja realismi (Todo)

| # | Tehtävä | Huomio |
|---|---|---|
| 34 | Haavinta aivan omaksi animaatiokseen | Tarkennettava: mitä puuttuu nykyisestä (CATCHFISH-5 tehty) |
| 36 | Verkkokalastus | Uusi pyyntitapa |
| 8 | Lisää välineitä | Onki tehty (#15); syöttikala virvelillä puuttuu |

### Grafiikka ja äänet (Todo/Backlog)

| # | Tehtävä |
|---|---|
| 37 | Veneen malli |
| 35 | Tuulisella säällä vaahtopäiset aallot |
| 41 | Koho kelluu aaltojen mukana (backlog) |

### Palkitsevuus ja uramoodi (Todo)

| # | Tehtävä |
|---|---|
| 23 | Kalakirja (keskitaso) |
| 22 | Trofeekuva saaliista |
| 24 | Uramoodi: kalastonhoitomaksu ja kalan vapautus |
| 25 | Uramoodi: tilauskalat |
| 7 | Uramoodin laajennus: kauppa, välineiden päivitykset ja tehtävät |

### Käytettävyys (Todo/Backlog)

| # | Tehtävä |
|---|---|
| 26 | Asetukset: hiiren herkkyys, käänteinen ohjaus, äänenvoimakkuudet |
| 27 | Peliohjaimen tuki |
| 28 | Ensimmäisen kerran vinkit |
| 6 | Ohjeen päivitys (backlog) – README:n "Kalat ovat dataa: niitä ei näe" -kohta ja ohjaustaulukko kannattaa tarkistaa |

Peruttu: #21 Tuulikellunta ja uistinankkuri.

## Arkkitehtuuri lyhyesti

| Tiedosto | Tehtävä |
|---|---|
| `scripts/main.gd` | Pelin käynnistys, järjestelmien kytkentä, testien valinta komentoriviltä |
| `scripts/fishing/fishing.gd` | Kalastuksen tilakone (heitto, uinti, tärppi, väsytys), kaksi vapaa (`ROD_VARS` vaihdetaan käsiteltävän vavan mukaan), tähtäin, koho ja mato |
| `scripts/fishing/landing_net.gd` | Haavinta-animaatio ja sen kamerakuva |
| `scripts/fishing/lures.gd` | Uistimet ja syöttivälineet (kind: sink, dive, bobber, bottom) |
| `scripts/fishing/species.gd` | Lajien ominaisuudet |
| `scripts/fishing/fish_population.gd` | Kalat datana, elinpaikat, tärpin todennäköisyys (`check_lure`) |
| `scripts/fishing/fish_models.gd` | Kalojen 3D-mallit |
| `scripts/lake/lake_data.gd` | Järven ruudukot ja laiturien törmäyssuorakulmiot (`docks`, `dock_push`) |
| `scripts/boat/` | Vene (laiturikosketus rungon ääriviivalla), kalastaja (malli `assets/characters/`, luut ohjataan `AnglerPoser`-muokkaimella animaation jälkeen), kamera (näkymät: normaali, koho, saavi, haavinta), saavi |
| `scripts/audio/` | Äänet (`game_audio.gd`) ja kalastajan puhe (`angler_voice.gd`) |
| `scripts/ui/` | HUD, valikot, uramoodin näkymät, kaikuluotain, kartta |
| `tools/` | Järven rakennus MML-aineistosta, äänten ja puheen generointi |

## Testaus

Automaattitestit ajetaan Godot 4.7.2:lla (headless, ellei toisin mainita):

```bash
godot --headless --fixed-fps 30 -- --day=180 --luretest     # uistinten syvyydet
godot --headless --fixed-fps 30 -- --day=180 --trolltest    # vetouistelu, tunnistus, haavinta
godot --headless --fixed-fps 30 -- --day=180 --baittest     # onki ja syötit
godot --headless --fixed-fps 30 -- --day=180 --casttest     # heiton tähtäin
godot --headless --fixed-fps 30 -- --day=180 --docktest     # törmäys laitureihin
godot --headless --fixed-fps 30 -- --day=180 --piketest     # kalat eivät näy, hauki seuraa uistinta
godot --headless --fixed-fps 30 -- --day=180 --sonartest    # syvyydet, pohjan laatu, kalakaaret
godot --headless --fixed-fps 30 -- --day=180 --proptest     # potkuri osuu pohjaan matalassa
godot --headless -- --day=180 --seasonfishtest              # kalojen kutu, helle ja syysyönti
godot --headless -- --day=180 --pressuretest                # ilmanpaine ja syönti
godot --headless --fixed-fps 30 -- --day=180 --anchortest   # ankkurin lasku, köysi ja nosto
godot --headless --fixed-fps 30 -- --day=180 --paddletest    # airot laiturin vieressä, melonta
godot --headless --fixed-fps 30 -- --day=180 --anglertest   # kalastajahahmo (--day=40 talvella)
godot --headless --fixed-fps 30 -- --day=180 --tubtest      # kalasaavi (--day=40 talvella)
godot --headless --fixed-fps 30 -- --day=180 --voicetest    # kalastajan puhe
godot --headless --fixed-fps 30 -- --day=180 --wavesoundtest # aaltojen ja tuulen äänet (talvi: --day=40)
godot --headless --fixed-fps 30 -- --day=40 --icetest       # pilkintä
godot --headless -- --day=180 --speciestest                 # kalakanta ja saalisjakauma
godot --headless --fixed-fps 30 -- --perftest               # suorituskyky
godot -- --inputtest / --careertest=KANSIO / --pausetest     # vaativat ikkunan
godot --fixed-fps 30 -- --day=180 --anglershots=KANSIO      # kalastajan lähikuvat (ikkuna)
```

`--autotest` (puoli tuntia kalastusta) on hyvin satunnainen eikä sovi
läpi/hylätty-testiksi. Useimmissa testeissä on `--*-shots=KANSIO` kuvakaappauksia
varten (vaatii ikkunan).

Kokeilu käsin: Godot-editori ja F5, tai `export/Catchfish.exe`.

## Työtapa

1. Tehtävä Planesta → tila *In Progress*.
2. Toteutus, testit (uusi ominaisuus saa oman testinsä), README ja F1-ohje.
3. Versio `project.godot`:iin: uusi ominaisuus nostaa minor-versiota, korjaus patch-versiota.
4. Release: commit → Windows-vienti (`export/Catchfish.exe`) → push →
   GitHub-release suomenkielisin julkaisutiedoin ja exe liitteenä →
   **tehtävä Planessa *Done***.

## Edistyminen tämän suunnitelman jälkeen

- **#30 Vene menee laitureiden läpi – korjattu (0.23.1).** Laiturien kannet ovat
  törmäyssuorakulmioita (`LakeData.docks`, sama mitoitus kuin laiturimallissa).
  Veneen rungon ääriviivaa verrataan niihin joka fysiikka-askeleella: runko
  työnnetään irti kannesta, laituria kohti oleva nopeus pysähtyy ja vene liukuu
  laituria pitkin; kovasta törmäyksestä kolahdus ja viesti. Samalla korjattiin
  aloituspaikat, joissa vene oli asetettu osittain laiturin kannen alle (vene
  siirtyy alussa noin 0,4 m irti laiturista). Testi `--docktest`.
  Julkaistu [v0.23.1](https://github.com/DesmondX80/catchfish/releases/tag/v0.23.1).
- **#32 Hahmon parannus – tehty (0.24.0).** Palikkahahmon tilalle Quaterniuksen
  riggattu "Adventurer"-malli (CC0, Poly Pizza). Asennot ja IK-kohteet ennallaan,
  mutta raajat ohjataan luurangon luilla (`SkeletonModifier3D`) mallin oman
  lepo-/kävelyanimaation päälle. Kesällä maastoasu ja lippalakki, talvella
  pilkkihaalari (punamusta), hihat ja pipo; päähineen alta tukka leikataan
  varjostimella (`shaders/hair_cut.gdshader`), parta jää. Mallin käsivarret ovat
  lyhyet, joten kaukaiseen kohteeseen nivelet venyvät enintään 15 cm.
  Samalla korjattiin vanha bugi: vavat jakoivat saman `_rod_points`-taulukon,
  jolloin kädet hakeutuivat veneen pohjalla olevan varavavan kohdalle.
  Testi `--anglertest`, kuvat `--anglershots`.
  Julkaistu [v0.24.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.24.0).
- **#33 Moottorin ääni – tehty (0.24.1).** Syntetisoidun surinan tilalle oikea
  perämoottorin nauhoitus veneestä täydellä vauhdilla (kyles, Freesound 637744,
  CC0; lähde `data/sounds/`). `tools/make_recorded_sounds.py` leikkaa siitä 8 s
  saumattoman silmukan (sytytystaajuus noin 49 Hz, matala ja bassoinen) ja
  tekee käynnistys- ja sammutusäänen. Pelissä täysi kaasu soi nauhoituksen
  korkeudella, tyhjäkäynti 0,6-kertaisena (noin 30 Hz).
  Kokeiltiin myös freesfx.co.uk:n ääntä, mutta sen ehdot kieltävät tiedoston
  jakamisen julkisessa repossa; ehdokkaiksi kelpuutetaan vain CC0-äänet.
  Julkaistu [v0.24.1](https://github.com/DesmondX80/catchfish/releases/tag/v0.24.1).
- **#43 Luonnolliset aalto- ja tuuliäänet – tehty (0.25.0).** Syntetisoitujen
  tuuli- ja aaltoäänten tilalle Freesoundin CC0-nauhoitukset (käyttäjä valitsi
  ehdokkaista): pienet aallot (kesäjärven aallot), isot aallot (aallonmurtaja),
  heikko tuuli ja kova tuuli sekä talveksi omat tuuliäänet. Tyynellä tuulta ei
  kuulu, heikko tuuli voimistuu 0,3–1,5 m/s ja vaihtuu 4–8 m/s kovaksi tuuleksi.
  Silmukat tehdään työkalulla `tools/make_recorded_sounds.py` (ent.
  make_motor_sound.py) 20 s pätkistä ristihäivytyksellä, ja niiden voimakkuus
  on entisten syntetisoitujen tasolla. Testi `--wavesoundtest` tarkistaa myös tuulen.
  Korjauksia kokeilun jälkeen: puuskassa kuului "löylyn kihinää", koska puuska
  hyppäsi kerralla ~1 m/s ja toi kovan tuulen metsäkahinan esiin. Nyt puuska
  voimistuu 0,8 m/s sekunnissa, heikon ja kovan tuulen vaihto seuraa tuulen
  perusvoimakkuutta (puuska vain voimistaa ääntä), kovan tuulen silmukasta on
  vaimennettu yli 3,5 kHz kahina ja pienistä aalloista mp3-sihinä (yli 2,5 kHz).
  Pelin alussa kuulunut kohina poistettiin: tuuliäänet alkoivat täydellä
  voimakkuudella ennen ensimmäistä ruutua, nyt hiljaa ja tasot asetetaan heti.
  Julkaistu [v0.25.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.25.0).
- **#29 Kalat eivät näy vedessä ja #17 Hauki seuraa uistinta – tehty (0.26.0).**
  FishVisuals ei enää piirrä kalakantaa: vapaasti uivat kalat näkyvät vain
  kaikuluotaimessa. Vedessä näkyy vain uistinta seuraava hauki (ja koukussa
  oleva kala tunnistettaessa, kuten ennenkin). Kun hauki iskisi heitettyyn
  uistimeen yli 7 m päässä vavan kärjestä, se lähtee 60 %:n todennäköisyydellä
  seuraamaan: ui uistimen perässä puolelta toiselle kaarrellen ja nousee veneen
  lähellä noin 0,6 m syvyyteen,
  jolloin humusvesi ei enää kätke sitä ("Hauki seuraa uistinta!" ja kalastajan
  huudahdus). Tasaisesti kelattuun uistimeen se iskee 65 %:n todennäköisyydellä
  viime hetkellä 1,6–3,5 m päässä vavan kärjestä; nykäisy veneen lähellä
  houkuttelee iskuun. Jos uistin pysähtyy (ei kelata, uistin alle 0,25 m/s) 0,8 s tai sitä kelataan
  liian lujaa (yli 1,3 m/s), hauki kääntyy pois, painuu syvälle ja on hetken
  varovainen. Muut kalat eivät iske seurannan aikana. Testi `--piketest`.
  Julkaistu [v0.26.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.26.0).
- **#10 Järven syvyydet ja #18 Kaikuluotaimen kalakaaret ja pohjan laatu – tehty (0.27.0).**
  Tekoaltaan pohja on vanhaa maastoa, ja maastotietokannan korkeuskäyrät
  jatkuvat veden alla: 15 m:n käyrä (3,3 m syvyys, 22,6 km käyrää) ja 12,5 m:n
  käyrä (5,8 m, vanhan jokiuoman reunat). `tools/build_lake.py` jakaa altaan
  käyrillä alueisiin ja interpoloi syvyyden rajaavista käyristä ja rannasta;
  yhden käyrän rajaamat alueet ovat syvänteitä, ja suurin jokiuoman syvänne
  (pohjoisosa) syvenee 7 metriin, lounaispään syvänne padon lähellä lähes yhtä
  syväksi. Rannoilla vesi syvenee heti ~0,8 m:iin (laiturit ja aloituspaikat
  pysyvät ennallaan). Keskisyvyys 2,7 m. Pelin kartan värit skaalattu 7 m:iin.
  Kaikuluotain piirtää kuvan sarakkeittain (7 näytettä/s): kalan kaiku
  vinoetäisyydelle, jolloin keilan läpi kulkevasta kalasta piirtyy kaari, väri
  voimakkuuden mukaan. Kalakannan sijainnit muuttuvat harvakseltaan, joten
  luotaimessa kalat uiskentelevat edestakaisin (±3 m, oma suunta ja tahti):
  paikallaankin kalat piirtyvät kaarina eivätkä vaakaviivoina. Pohjan laatu
  (`LakeData.bottom_at`): kasvillisuus matalassa kaislikon lähellä ja laikkuina,
  kova pohja matalassa, jyrkissä rinteissä ja kivien lähellä, muuten muta.
  Kova pohja: kirkas kaiku ja toinen heijastus; muta: himmeä ja pehmeä;
  kasvillisuus: tupsuja pohjasta. Testi `--sonartest`. Uistin- ja onkitestien
  paikat rajattu enintään 4 m syvyisiin (syvänteessä uistin vajoaa liian syvälle).
  Julkaistu [v0.27.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.27.0).
- **#31 Alle metrin syvyydessä potkuri osuu pohjaan – tehty (0.28.0).**
  Kun moottori käy ja potkuri pyörii (kaasu ei vapaalla), alle metrin
  syvyydessä veneen perässä potkuri osuu pohjaan: metallinen kolahdus ja
  raapiminen (`prop_strike`), vene hidastuu ja potkuri vaurioituu kaasun ja
  matalikon mukaan (täysi kaasu syvällä matalikossa ~3 s, kevyt hipaisu
  10–20 s). Vääntynyt potkuri heikentää työntöä (HUD: "potkuri vääntynyt"),
  rikki mennyt sammuttaa moottorin eikä se käynnisty enää – reissun loppu
  soudetaan. Alle 1,3 metrin syvyydestä varoitetaan kerran. Uusi reissu alkaa
  ehjällä potkurilla. Testi `--proptest`.
  Julkaistu [v0.28.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.28.0).
- **#19 Kalojen vuodenaikakäytös – tehty (0.29.0).** Lajeille avovesikauden
  jaksot (`Species.DATA[...]["periods"]`, `Species.traits(laji, päivä, talvi)`),
  jotka korvaavat elinpaikan syvyyden, rantaetäisyyden ja kaislikon merkityksen
  ja kertovat aktiivisuuden: hauen kutu heti jäiden lähdön jälkeen (päivät
  115–140) matalissa kaislikkolahdissa, syönti vähäistä, kudun jälkeen kiihkeä
  syönti (140–165); ahvenen, särjen ja lahnan kudut touko–kesäkuussa matalassa;
  kesähelle (heinä–elokuu) siirtää kalat syvempään; syysyönti (syys–lokakuu)
  vilkastuttaa syöntiä. Kalakanta luodaan reissun päivän mukaan
  (`FishPopulation.day`), ja kutuaikaan liian syvä vesi on huono elinpaikka.
  Reissun alussa vuodenajan vihje (esim. "Hauet kutevat matalissa
  kaislikkolahdissa"). Testi `--seasonfishtest`.
  Julkaistu [v0.29.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.29.0).
- **#20 Ilmanpaineen ja sään vaikutus syöntiin – tehty (0.30.0).** Säässä on
  ilmanpaine ja sen muutos kolmessa tunnissa. Simuloidussa säässä paine seuraa
  säätilaa (selkeä ~1025 hPa … rankkasade ~993 hPa) 1,2 hPa/h, joten sään
  huonontuessa paine laskee ennen sadetta. Todellisessa säässä paine (p_sea) ja
  sen muutos tulevat Ilmatieteen laitoksen kolmen tunnin havainnoista, varalla
  Open-Meteosta (pressure_msl, tuntiarvot). `Weather.feeding_factor()`:
  laskeva paine (sää muuttuu, rintama/ukkonen tulossa) kiihdyttää syöntiä enintään
  1,5-kertaiseksi, rintaman jälkeen nouseva paine heikentää (0,85) ja tasainen
  korkeapaine (yli 1020 hPa) laiskistaa (enintään 0,75). Kerroin vaikuttaa kaikkiin
  iskuihin (FishPopulation.check_lure). HUD näyttää paineen ("1012 hPa, laskee"),
  ja nopeasta laskusta tulee vihje. Testi `--pressuretest`. FMI-haku on nyt
  kolmen tunnin jakso puolen tunnin välein. Lajien vuodenaikatiedot lasketaan
  kerran (`FishPopulation.update_traits`), ettei kalakannan luonti hidastu.
  Huom. ikkunassa ajettavassa `--settingstest`issä pelin säähaku voi
  aikakatkaista hitaalla ohjelmistorenderöinnillä (sama mainissa).
  Julkaistu [v0.30.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.30.0).
- **#38 Ankkurianimaatio – tehty (0.31.0).** Ankkurilla on malli (pieni
  naaraankoukku) ja köysi (`scripts/boat/anchor.gd`). X laskee ankkurin keulasta:
  kalastaja siirtyy etutuhdolle ja köysi luistaa käsien läpi, ankkuri vajoaa
  1 m/s, ja vene on ankkurissa vasta ankkurin osuttua pohjaan (köyttä ~2 × syvyys).
  Köysi vetää keulasta, joten tuulessa vene kääntyy keula ankkuria kohti.
  Pohjassa olevan ankkurin köysi roikkuu löysänä kaarella (lepää pohjalla) ja
  kiristyy suoraksi veneen loitotessa; ajettaessa tai soudettaessa ankkuri
  pohjassa tulee ilmoitus "Ankkuriköysi kiristyy – nosta ensin ankkuri" ja
  kalastaja huutaa "Perkele, ankkuri!". Köysi kulkee keulapiikin yli, ja
  humusvedessä ankkuri ja köysi eivät näy pinnan alla.
  Nostettaessa vene irtoaa heti, kalastaja kelaa köyttä vuorokäsin (0,8 m/s), ja
  ankkuri päätyy veneen pohjalle keulaan. Uistimen ollessa vedessä ankkuria ei
  käsitellä. HUD näyttää ankkurin tilan. Testi `--anchortest`.
  Julkaistu [v0.31.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.31.0).
- **#45 Mela peliin ja #44 Airojen äänet luonnolliseksi – tehty (0.32.0).**
  Airot eivät mene laiturin läpi: airon pyyhkäisemää aluetta (otosta vedon
  loppuun, hankaimesta lavan kärkeen) verrataan laiturien kansiin 0,25 m:n
  marginaalilla, ja laituria kohti oleva airo nostetaan hankaimessa veneen
  kylkeä pitkin (lapa perään). Sillä ei voi soutaa, ja ilmoitus kehottaa
  ottamaan melan. V ottaa melan käteen (airot veneeseen): kalastaja istuu
  keskituhdolla kasvot keulaan ja meloo kyljeltä. W/S melotaan eteen/taakse ja
  kylki vaihtuu joka vedolla, A/D melotaan vain toiselta kyljeltä, jolloin vene
  kääntyy. Mela on heikompi kuin airot (90 N vedossa). Mela on puinen
  kanoottimela (1,5 m, levenevä kämmenkahva, lapa levenee kärkeä kohti, mänty
  syykuviolla). Vedossa varsi kulkee laidan ulkopuolella, ja kylkeä vaihdettaessa
  mela nostetaan kalastajan edestä veneen yli. Kun mela ei ole käytössä, se on
  veneen pohjalla vasemmalla kyljellä. Airovedon ääni on
  leikattu oikeasta nauhoituksesta (SkibkaMusic, Freesound 478973, CC0; 5
  muunnelmaa) ja melanvedon ääni kajakin melonnasta tyynellä järvellä
  (Danjocross, Freesound 503208, CC0; 4 muunnelmaa). Peli soittaa
  satunnaisen muunnelman (`GameAudio.VARIANTS`). Testi `--paddletest`.
  Julkaistu [v0.32.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.32.0).
- **#49 Julkaisu GitHub Pagesiin – tehty.** Selainversio:
  <https://desmondx80.github.io/catchfish/>. Web-vienti on yksisäikeinen
  (`variant/thread_support=false`), joten se toimii GitHub Pagesissa ilman
  COOP/COEP-otsakkeita. `.github/workflows/pages.yml` lataa Godot 4.7.2:n ja
  web-vientipohjan (välimuistiin), vie pelin ja julkaisee sen jokaisesta
  GitHub-julkaisusta, tai käsin Actions-välilehdeltä. Selaimessa "Lopeta peli"
  piilotetaan, ja säähaku kulkee selaimen kautta (FMI ja Open-Meteo sallivat
  CORSin). Tallennukset (ura, saaliskirja, asetukset) ovat selaimen
  IndexedDB:ssä. wasm 40 Mt, pck 11 Mt.
- **#39 Kodan ulkoasu ja #40 Lintutornin ulkoasu – tehty (0.33.0).** Kodan ja
  lintutornin aloituspaikan rakennukset on mallinnettu käyttäjän valokuvista
  (`LakeWorld._kota`, `_woodshed`, `_build_towers`). Tornia lähin
  maastotietokannan rakennus on kota, muut alle 25 m:n päässä olevat puuvajoja.
  Kota on kahdeksankulmainen grillikota: harmaansininen lautaseinä valkoisin
  pielin, ikkunat, ovi laiturin puolella, jyrkkä tumma paanukatto harjoineen
  ja peltipiippu. Puuvaja on harmaantuneista hirsistä ylittyvin nurkin
  hirsijalasten päällä: harjakatto, harmaansininen ovi päädyssä ja
  ilmoitustaulu kyljessä. Lintutorni on katoton näköalatasanne neljän tolpan
  varassa: välitasanne, kaksi porrassyöksyä käsijohteineen, vinotuet ja
  pystyrimakaiteet. Torni käännetään niin, että portaat laskeutuvat
  korkeimmalle maalle. Katoille tulee talvella lunta.
  Julkaistu [v0.33.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.33.0).
- **#52 Puut luonnollisen näköisiksi – tehty (0.34.0).** Metsässä on kolme
  puulajia (`LakeWorld._pine`, `_spruce`, `_birch`): mänty (pitkä suora runko,
  tyvellä harmaanruskea ja ylempänä oranssi kaarna, laakeat neulastupsut vain
  latvassa), kuusi (kapea tuuhea kartio maahan asti, riippuvat sahalaitaiset
  oksakerrokset) ja koivu (valkoinen runko mustin laikuin ja tummin tyvin,
  soikea latvus; talvella paljaat oksat ja punaruskeat varvut). Kangasmetsässä
  mäntyä 45 %, kuusta 30 % ja koivua 25 %, rämeillä ja kallioilla enimmäkseen
  mäntyä. Lajista on kolme muunnelmaa. Puut ovat 128 m:n lohkoina
  (MultiMesh): alle 260 m:n päässä tarkat mallit, kauempana kevyet siluetit
  ilman varjoja, ja näkökartion ulkopuoliset lohkot jäävät piirtämättä.
- **Melonta vastatuuleen ja laiturin kulma – korjattu (0.34.0).** Melan veto
  on paikallaan voimakkaampi ja heikkenee vauhdin kasvaessa (`PADDLE_BLADE_SPEED`):
  tyynellä vauhti on ennallaan noin 4 km/h, 4 m/s vastatuuleen pääsee noin
  2 km/h ja 6 m/s tuuleen hitaasti. Laituritörmäys kääntää venettä
  kosketuskohdan mukaan, joten keula ei enää jää kiinni laiturin kulmaan.
  Laiturin puoleinen airo nostetaan veneeseen kääntämättä sitä laiturin läpi.
  Julkaistu [v0.34.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.34.0).
- **#51 Airojen ulkoasu – tehty (0.35.0).** Airot on mallinnettu käyttäjän
  mallikuvista (`Boat.OAR_PROFILE`, sama `_lathe_mesh` kuin melassa): 2,55 m
  vaaleaa mäntyä, kahvan päässä nuppi ja ohuempi kädensija, pyöreä varsi ja
  pitkä vähitellen levenevä lapa pyöristetyin kärjin. Hankaimen kohdalla on
  musta kumiholkki. Lavan kääntö kiertää koko airoa varren ympäri.
  Julkaistu [v0.35.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.35.0).
- **#47 Kalasaavinäkymä tärisee – korjattu (0.36.0).** Kamera luki saavin
  paikan ennen kuin saavi oli siirtynyt veneen mukana, joten Tab-näkymä jäi
  vaihtelevasti fysiikka-askeleen jälkeen ja nyki veneen liikkuessa (tuuli,
  moottori). `CatchTub.view_point()` lasketaan nyt rungon tämänhetkisestä
  asennosta; `--tubtest` tarkistaa joka kuvassa kameran paikan ajelehtivassa veneessä.


## Huomioita ja avoimia kysymyksiä

- **Järven syvyydet** tulevat veden alle jääneistä maastotietokannan korkeuskäyristä (15 m ja 12,5 m, #10). Syvin kohta (7 m) on paikallistieto; sen tarkkaa paikkaa ei tiedetä, joten se on vanhan jokiuoman syvänteen keskellä pohjoisosassa.
- **Puhesynteesiääni** `fi_FI-harri`: opetusaineisto CC0, mutta malli on jatkokoulutettu lessac-äänestä, jonka ehdot ovat rajoitetummat. Jos peliä joskus jaetaan kaupallisesti, omat äänitykset ovat varmempi valinta.
- **Vanhat uratallennukset** voivat sisältää kuhia ja taimenia (poistettu 0.18.0); ne voi yhä myydä.
