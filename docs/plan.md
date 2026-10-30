# Catchfish – suunnitelma ja tilanne

Päivitetty 30.10.2026. Nykyinen versio **0.52.0**
([release](https://github.com/DesmondX80/catchfish/releases/tag/v0.52.0)).

Catchfish on Godot 4.7 -kalastussimulaattori Raahen Haapajärven tekoaltaalla.
Järvi on mallinnettu Maanmittauslaitoksen avoimesta aineistosta. Pelaaja soutaa
tai ajaa moottorilla, heittelee virvelillä, uistelee, onkii ja pilkkii talvella.
Käyttöohje ja ohjaus ovat [README.md](../README.md):ssä.

## Tähänastinen tilanne

### Valmiina (versiot 0.1–0.41.0)

| Alue | Ominaisuudet |
|---|---|
| Vene | Oma vesifysiikka, soutu, mela ja perämoottori, ankkuri, tuuli ajelehdittaa, pohjakosketus, törmäys laitureihin (kolahdus, liukuu laituria pitkin) |
| Maailma | MML-aineistosta tehty järvi ja maasto, aallokko tuulen ja pyyhkäisymatkan mukaan (terävät harjat, suoja rannoilla, puuskalaikut, vaahtopäät), Veden laatu -asetus (Korkea / Matala), metsässä mäntyjä, kuusia ja koivuja, taivaalla lintuja (varis, korppi, sorsa, hanhi, lokki, merikotka), vuodenajat todellisen päivämäärän mukaan, sää (tuuli, pilvet, sade, lumi), todellinen sää ja kellonaika valinnaisina |
| Kalastus | Virveli ja uistimet (lusikka, vaaput, lippa, jigi) omina 3D-malleinaan, valinta kalapakista (L; talvella pilkkirasia), taipuva vapa ja fysiikkaan perustuva siima, jarru ja väsytys, haavinta omana animaationaan omalla kameralla |
| Uistimet | Lusikka ui kelatessa ja uistellessa 1,5 m:ssä (nopeasti kelatessa 1 m) ja vajoaa pohjaan vedon pysähtyessä; vaaput kelluvat ja uivat tavoitesyvyydessään |
| Vetouistelu | Kaksi vapaa ja vapatelineet perälaudassa (R), tärppi telineeseen, veneen vauhti koukuttaa |
| Onki | Koho-onki (syvyys F/G ennen heittoa) ja pohjaonki (mato 0,5 m pohjasta), tärpissä koho nykii ja uppoaa, kamera zoomaa kohoon |
| Heitto | Tähtäin näyttää osumapisteen (sama lentofysiikka kuin heitossa) ja varoittaa rantaan menevästä heitosta |
| Talvi | Pilkkiminen avannosta: kairaus, pilkki ja tasapainopilkki, kävely jäällä |
| Kalat | Altaan kalakanta: ahven, särki, hauki, kiiski, lahna, made. Lajeilla elinpaikka, vuorokausi- ja vuodenaikarytmi, uistin- ja syöttimieltymykset, 3D-mallit. Kalat eivät näy humusvedessä (vain kaikuluotaimessa); laji tunnistetaan vasta, kun kala näkyy veneen lähellä. Hauki voi seurata uistinta veneelle ja iskeä viime hetkellä |
| Saalis | Kalasaavi veneen pohjalla (Tab: kuva ylhäältä ja painot), ennätyslista, kalan kuva saalisikkunassa, kalakirja (lajin sivu avautuu ensimmäisestä saaliista) |
| Verkko | Pohjaverkko 30 m kolmella silmäkoolla (22, 35, 50 mm): lasku laidan yli soutaen (N, silmäkoko B), pyytää tunteja, nosto pyykin luota laidan yli (kalat näkyvät verkossa), saalis lajin elinpaikan, rytmien ja silmäkoon mukaan; uramoodissa ostetaan ja jää järveen reissujen yli |
| Uramoodi | Päivät ja kello, rahat, uistinvarasto, kalastustarvikeliike, kalojen säilö ja myynti (Luken sisävesien tuottajahinnat 2024), kalastonhoitomaksu ja toisen vavan lupa, kalan vapautus (Z) ja maine, joka nostaa myyntihintoja |
| Äänet | Moottori, airo- ja melavedot, aallot (pienet / isot), tuuli (heikko / kova, talvella omat) ja taivaan lintujen huudot oikeista Freesoundin CC0-nauhoituksista (tools/make_recorded_sounds.py); muut syntetisoitu (tools/make_sounds.py): kela, jarru, linnut, sade |
| Kalastaja | Quaterniuksen riggattu malli (CC0): kesällä maastoasu ja lippalakki, talvella pilkkihaalari ja pipo; kädet IK:lla vapaan, airoihin, ohjausaisaan ja kairaan, istuessa jalat lattialla, jäällä kävelyanimaatio |
| Asetukset | Hiiren herkkyys, käänteinen pystyohjaus ja äänenvoimakkuudet (kaikki, taustaäänet, efektit, puhe) alku- ja taukovalikossa, tallennetaan koneelle |
| Puhe | Kalastajan repliikit tapahtumiin ja lajin huudahdus tunnistettaessa (Piper-puhesynteesi, tools/make_voice.py) |
| Muut veneet | Avovesikaudella päivällä enintään kaksi vierasta venettä: moottorivene laiturilta toiselle tai kalapaikalle, soutuvene kalastaa ankkurissa ja palaa; reitit syvää vettä pitkin, väistö, peräaallot keinuttavat omaa venettä, törmäys kuten laituriin |

### Tehtävänhallinta

Tehtävät ovat Plane Cloudissa, projekti **CATCHFISH**. Tila 23.10.2026:
43 tehtävää valmiina, 32 avoinna (8 Todo, 24 Backlog).

## Suunnitelma: seuraavat tehtävät

Prioriteetti Planen mukaan, sitten oma suositusjärjestys. Numerot ovat Planen
tunnisteita (CATCHFISH-N).

### Työn alla

Ei mitään (#78 Välkkyminen tehty 0.47.1:ssä).

### Kiireelliset ja korkeat

Ei avoimia (#29 ja #17 tehty 0.26.0:ssa).

### Pelattavuus ja realismi

| # | Tehtävä | Tila | Huomio |
|---|---|---|---|
| 34 | Haavinta aivan omaksi animaatiokseen | Backlog | Tarkennettava: mitä puuttuu nykyisestä (CATCHFISH-5 tehty) |
| 8 | Lisää välineitä | Backlog | Onki tehty (#15); syöttikala virvelillä puuttuu |
| 56 | Onkimiseen madon laittaminen | Backlog | |
| 62 | Hämärä- ja yökalastus: otsalamppu ja veneen valo | Backlog | |
| 63 | Siiman vahvuus ja vaihto | Backlog | Pohjana `line_strength` (fishing.gd) |
| 64 | Kiinni tarttuneen uistimen irrotus | Backlog | |
| 65 | Rantakalastus | Backlog | Pohjana jäällä kävely |
| 66 | Kevään ja syksyn heikot jäät | Backlog | |

### Maailma, grafiikka, kamera ja äänet

| # | Tehtävä | Tila |
|---|---|---|
| 53 | Uisteluun vavan kärjen näkymä | Backlog |
| 61 | Uistimet samannäköisiksi siiman päässä kuin pakissa | Backlog |
| 59 | Tuolit oikeinpäin pöydän ympärille | Backlog |
| 60 | Musiikki alkuvalikkoon | Backlog |
| 67 | Aamusumu ja usva | Backlog |
| 68 | Muita veneitä järvellä | Backlog |
| 69 | Rannan äänimaailma ja pintapolskeet | Backlog |

### Palkitsevuus ja uramoodi

| # | Tehtävä | Tila |
|---|---|---|
| 22 | Trofeekuva saaliista | Todo |
| 24 | Uramoodi: kalastonhoitomaksu ja kalan vapautus | Todo |
| 25 | Uramoodi: tilauskalat | Todo |
| 7 | Uramoodin laajennus: kauppa, välineiden päivitykset ja tehtävät | Todo |
| 70 | Saavutukset | Backlog |
| 71 | Päivän saalisyhteenveto | Backlog |

### Käytettävyys ja tekniikka

| # | Tehtävä | Tila |
|---|---|---|
| 27 | Peliohjaimen tuki | Backlog |
| 28 | Ensimmäisen kerran vinkit | Backlog |
| 6 | Ohjeen päivitys – README:n "Kalat ovat dataa: niitä ei näe" -kohta ja ohjaustaulukko kannattaa tarkistaa | Backlog |
| 58 | FPS-laskuri | Backlog |
| 72 | Kaikuluotaimen asetukset | Backlog |
| 73 | Englanninkielinen versio | Backlog |
| 75 | Selainversion suorituskyky | Backlog |

## Arkkitehtuuri lyhyesti

| Tiedosto | Tehtävä |
|---|---|
| `scripts/main.gd` | Pelin käynnistys, järjestelmien kytkentä, testien valinta komentoriviltä |
| `scripts/fishing/fishing.gd` | Kalastuksen tilakone (heitto, uinti, tärppi, väsytys), kaksi vapaa (`ROD_VARS` vaihdetaan käsiteltävän vavan mukaan), tähtäin, koho ja mato |
| `scripts/fishing/landing_net.gd` | Haavinta-animaatio ja sen kamerakuva |
| `scripts/fishing/lures.gd` | Uistimet ja syöttivälineet (kind: sink, dive, bobber, bottom) |
| `scripts/fishing/lure_models.gd`, `scripts/boat/tackle_box.gd` | Uistinten 3D-mallit ja kalapakki (L) / pilkkirasia |
| `scripts/fishing/species.gd` | Lajien ominaisuudet |
| `scripts/fishing/nets.gd`, `gill_net.gd`, `net_control.gd` | Verkot: silmäkoot ja saalismalli (`catch_between`), verkon 3D-malli (pyykit, nouseva verkko), lasku ja nosto (N/B), tallennus `Career.nets` |
| `scripts/fishing/fish_population.gd` | Kalat datana, elinpaikat, tärpin todennäköisyys (`check_lure`) |
| `scripts/fishing/fish_models.gd` | Kalojen 3D-mallit |
| `scripts/lake/lake_data.gd` | Järven ruudukot, pyyhkäisymatkat (`fetch_at`, `assets/lake/fetch.bin` tekee `tools/build_fetch.py`) ja laiturien törmäyssuorakulmiot (`docks`, `dock_push`) |
| `scripts/world/waves.gd`, `shaders/waves.gdshaderinc` | Yhteinen aaltomalli (Gerstner-aallot tuulen ja pyyhkäisymatkan mukaan): vene, koho, pyykit, ankkuri ja vesivarjostin |
| `scripts/boat/` | Vene (laiturikosketus rungon ääriviivalla), kalastaja (malli `assets/characters/`, luut ohjataan `AnglerPoser`-muokkaimella animaation jälkeen), kamera (näkymät: normaali, koho, saavi, haavinta), saavi |
| `scripts/audio/` | Äänet (`game_audio.gd`) ja kalastajan puhe (`angler_voice.gd`) |
| `scripts/world/birds.gd` | Taivaan linnut: mallit koodissa, lentotavat, ääntely, kotkan huudahdus |
| `scripts/boat/other_boats.gd`, `other_boat.gd`, `other_boat_crew.gd` | Muut veneet: ilmestyminen laitureilla, reittihaku (`AStarGrid2D` 8 m ruudukossa, rakennetaan pelin alussa muutaman ruudun aikana), ohjaus ja väistö, peräaallot (`wakes_at`, keinuttavat pelaajan venettä `Boat._animate`), törmäys (`Boat._boat_collision`); rungon ja moottorin malli `Boat.build_hull`/`build_motor`/`build_oars` |
| `scripts/ui/` | HUD, valikot, uramoodin näkymät, kaikuluotain, kartta, kalakirja (`fish_book_view.gd`) |
| `scripts/catch_log.gd`, `scripts/fish_book.gd` | Ennätyslista (kertakalastus) ja kalakirja (kaikki saaliit lajeittain) |
| `tools/` | Järven rakennus MML-aineistosta, äänten ja puheen generointi |

## Testaus

Automaattitestit ajetaan Godot 4.7.2:lla (headless, ellei toisin mainita).
WSL:ssä se on komentona `godot-4.7.2` (`~/.local/bin/godot-4.7.2`).
GitHub Actions ajaa kaikki ikkunattomat testit jokaisesta pushista ja PR:stä
(`.github/workflows/tests.yml`); samat testit paikallisesti:
`tools/run_tests.sh [godot] [-q] [--repeat=N] [--ref=REF] [--log=TIEDOSTO] [testin_nimi...]`.
Lopussa on yhteenvetotaulukko (tulos, kesto ja `VIRHE`-rivit), ajon tulosrivit
alkavat `>>`, ja koko ajo tallentuu lokiin `.test-logs/` (20 viimeisintä,
`latest.log`). `-q` jättää Godotin tulosteen vain lokiin. `--repeat=N` ajaa
testit N kertaa ja `--ref=origin/main` väliaikaisessa työkopiossa, jolla
tarkistetaan, epäonnistuuko testi myös mainissa. Ajurin itsetesti
`tools/run_tests_selftest.sh` ajetaan CI:ssä ennen testejä.

```bash
godot --headless --fixed-fps 30 -- --day=180 --luretest     # uistinten syvyydet
godot --headless --fixed-fps 30 -- --day=180 --trolltest    # vetouistelu, tunnistus, haavinta
godot --headless --fixed-fps 30 -- --day=180 --trollstriketest # uistelumoodi, FPV-vastaisku hiirellä
godot --headless --fixed-fps 30 -- --day=180 --baittest     # onki ja syötit
godot --headless --fixed-fps 30 -- --day=180 --casttest     # heiton tähtäin
godot --headless --fixed-fps 30 -- --day=180 --docktest     # törmäys laitureihin
godot --headless --fixed-fps 30 -- --day=180 --piketest     # kalat eivät näy, hauki seuraa uistinta
godot --headless --fixed-fps 30 -- --day=180 --sonartest    # syvyydet, pohjan laatu, kalakaaret
godot --headless --fixed-fps 30 -- --day=180 --proptest     # potkuri osuu pohjaan matalassa
godot --headless -- --day=180 --seasonfishtest              # kalojen kutu, helle ja syysyönti
godot --headless -- --day=180 --pressuretest                # ilmanpaine ja syönti
godot --headless --fixed-fps 30 -- --day=180 --booktest     # kalakirja
godot --headless --fixed-fps 30 -- --day=180 --fpvtest      # FPV-kamera
godot --headless --fixed-fps 30 -- --day=180 --synctest     # vene, kamera ja vavat ruudun tahdissa
godot --headless --fixed-fps 30 -- --day=180 --overlaptest  # päällekkäiset pinnat (talvi: --day=40)
godot --headless --fixed-fps 30 -- --day=180 --birdtest     # linnut
godot --headless --fixed-fps 30 -- --day=180 --birdsoundtest # pikkulintujen laulu 8–15 s välein, vain valoisalla
godot --headless --fixed-fps 30 -- --day=180 --tackletest   # kalapakki (talvi: --day=40)
godot --headless --fixed-fps 30 -- --day=180 --anchortest   # ankkurin lasku, köysi ja nosto
godot --headless --fixed-fps 30 -- --day=180 --nettest      # verkon lasku, saalismalli ja nosto (talvi: --day=40)
godot --headless --fixed-fps 30 -- --day=180 --paddletest    # airot laiturin vieressä, melonta
godot --headless --fixed-fps 30 -- --day=180 --headwindtest  # soutu ja melonta vastatuuleen
godot --headless --fixed-fps 30 -- --day=180 --anglertest   # kalastajahahmo (--day=40 talvella)
godot --headless --fixed-fps 30 -- --day=180 --tubtest      # kalasaavi (--day=40 talvella)
godot --headless --fixed-fps 30 -- --day=180 --voicetest    # kalastajan puhe
godot --headless --fixed-fps 30 -- --day=180 --audio-log --audiologtest # ääniloki
godot --headless --fixed-fps 30 -- --day=180 --wavesoundtest # aaltojen ja tuulen äänet (talvi: --day=40)
godot --headless --fixed-fps 30 -- --day=180 --wavetest     # aallokko: koko, suoja, harjat, kääntyminen, kasvu
godot --headless --fixed-fps 30 -- --day=180 --otherboatstest # muut veneet: reitit, peräaalto, törmäys, väistö, ehdot (talvi: --day=40)
godot --headless --fixed-fps 30 -- --day=40 --icetest       # pilkintä
godot --headless -- --day=180 --speciestest                 # kalakanta ja saalisjakauma
godot --headless --fixed-fps 30 -- --perftest               # suorituskyky
godot -- --inputtest / --careertest=KANSIO / --pausetest     # vaativat ikkunan
godot --fixed-fps 30 -- --day=180 --anglershots=KANSIO      # kalastajan lähikuvat (ikkuna)
godot --fixed-fps 30 -- --day=180 --fpvshots=KANSIO         # FPV-kameran kuvat (ikkuna)
godot --fixed-fps 30 -- --day=180 --foamshots=KANSIO        # vaahtopäät eri tuulilla (ikkuna)
godot --fixed-fps 30 -- --day=180 --watershots=KANSIO [--waterquality=matala] [--watershots-only=01,19] # vesi eri tuulilla, laituri ja ruudun aika (ikkuna)
godot --fixed-fps 30 -- --day=180 --shadowshots=KANSIO      # veneen varjo eri kellonaikoina (ikkuna)
godot --fixed-fps 30 -- --day=180 --otherboatshots=KANSIO   # muut veneet, vana ja peräaallon kallistus (ikkuna)
godot --fixed-fps 60 --resolution 480x270 -- --day=180 --jittershots=KANSIO  # välke ja nykiminen (ikkuna)
```

`--audio-log` yhdistetään mihin tahansa testiin tai ajoon: se tulostaa jokaisesta
soitetusta äänestä rivin `[ääni] HH:MM:SS nimi etäisyys` (pelin kello, etäisyys
veneestä; soittamatta jäänyt merkinnällä `OHITETTU`, silmukoista `loop_start`/
`loop_stop`), esim. `godot --headless --fixed-fps 30 -- --day=180 --audio-log --casttest`.
Pelkkä `--audio-log` ei ohita valikkoa.

`--autotest` (puoli tuntia kalastusta) on hyvin satunnainen eikä sovi
läpi/hylätty-testiksi. Useimmissa testeissä on `--*-shots=KANSIO` kuvakaappauksia
varten (vaatii ikkunan).

Kokeilu käsin: Godot-editori ja F5, tai `export/Catchfish.exe`.

## Työtapa

0. Jokainen tehtävä omaan haaraan ja omaan työkopioon ajantasaisesta mainista,
   jotta rinnakkaiset agentit eivät sotke toistensa tiedostoja:
   `git fetch && git worktree add -b claude/<aihe> ../catchfish-<aihe> origin/main`.
   Pääkansiossa ei vaihdeta haaroja. Uudessa työkopiossa `godot --headless --import`
   kerran ennen testejä; Windowsin editorissa työkopio avataan omana projektinaan.
   Releasen jälkeen `git worktree remove ../catchfish-<aihe>`.
1. Tehtävä Planesta → tila *In Progress*.
2. Toteutus, testit (uusi ominaisuus saa oman testinsä), README ja F1-ohje.
3. Versio `project.godot`:iin: uusi ominaisuus nostaa minor-versiota, korjaus patch-versiota.
4. Ennen releasea haara päivitetään mainin päälle, koska rinnakkainen agentti on
   voinut julkaista välissä: `git fetch && git rebase origin/main`, testit
   uudelleen ja versionumero tarkistetaan mainista (`project.godot` ja tämän
   tiedoston alku), ettei samaa versiota julkaista kahdesti. Jos versio on jo
   käytetty, nostetaan seuraavaan.
5. Release: commit → Windows-vienti (`export/Catchfish.exe`) → push →
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
  1 m/s, ja vene on ankkurissa vasta ankkurin osuttua pohjaan (köyttä ~2 × syvyys;
  0.40.1:stä alkaen syvyys + 0,5 m, ks. #57).
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
  Julkaistu [v0.36.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.36.0).
- **#41 Koho kelluu aaltojen mukana – tehty (0.37.0).** Koho seuraa samaa
  aaltomallia (`Waves.swell_height`) kuin vesipinta ja vene: se nousee ja laskee
  aallokon mukana ja kallistuu aallon rinteen suuntaisesti. Lisäksi se keinuu
  pienissä laineissa tuulen voimakkuuden mukaan (noin 2°–15°). Nykiminen,
  uppoaminen ja väsytys lasketaan aaltopinnasta. `--baittest` tarkistaa korkeuden
  aaltopinnasta, nousun ja laskun sekä kallistelun.
  Julkaistu [v0.37.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.37.0).
- **#23 Kalakirja – tehty (0.38.0).** Alkuvalikossa ja Esc-valikossa on
  Kalakirja: lajit vasemmalla, valitun lajin sivulla tieteellinen nimi, 3D-kuva,
  kuvaus, saaliiden määrä, oma ennätys (paino, pituus, viehe, paikka, päiväys),
  ensimmäinen saalis ja vinkki (viihtymissyvyys ja kolme mieluisinta viehettä
  `species.gd`:stä). Saamaton laji näkyy listassa "? ? ?" ja sivulla
  varjokuvana. Kirjaan tulevat kaikki saaliit, myös uramoodin (`FishBook`,
  `user://kalakirja.json`); ensimmäisellä kerralla kirja täytetään saaliskirjan
  vanhoista saaliista. Uudesta lajista saalisikkunassa "UUSI LAJI KALAKIRJAAN!".
  Testi `--booktest` (kuvat `--bookshots=KANSIO`).
  Julkaistu [v0.38.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.38.0).
- **#55 Lintuja taivaalle – tehty (0.39.0).** `Birds` lennättää parvia: varis,
  korppi, sorsa (jonossa), hanhi (V-muodostelma), lokki ja harvinainen
  merikotka. Mallit tehdään koodissa (ruumis putkena, litteät siivet, joita
  `bird.gdshader` taivuttaa tyvestä ja kyynärtaipeesta); lajeilla oma koko,
  väritys, räpyttelytaajuus ja liito (kotka ja lokki liitävät, sorsa räpyttelee
  koko ajan). Parvi lentää järven yli tai kaartelee veneen lähellä ja katoaa
  kauas. Yöllä ei lennetä, sateella ja kovalla tuulella harvemmin; talvella
  muuttolinnut ovat poissa, ja hanhia on eniten muuttoaikaan. Huudot ovat
  Freesoundin CC0-nauhoituksia (`make_recorded_sounds.py --birds`). Kun
  merikotka näkyy kamerassa alle 260 m päässä, kalastaja huudahtaa "Oho!
  Merikotka!".
  Testi `--birdtest` (lähikuvat `--birdshots=KANSIO`).
  Julkaistu [v0.39.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.39.0).
- **#50 Uistimen valinta kalapakista – tehty (0.40.0).** L avaa muovisen
  kääntölokeropakin veneen pohjalla kalastajan edessä: kansi nousee,
  lokerotasot kääntyvät sivuille ja kamera katsoo pakkia ylhäältä. Vasemmalla
  tasolla lusikka, lippa ja jigi, oikealla pitkä kelluva vaappu ja lyhyt
  syvävaappu, pohjalla koho- ja pohjaonki. Lokero korostuu hiiren alla, ja
  klikkaus valitsee uistimen ja sulkee pakin (L, Esc tai oikea hiiri sulkee
  muuten). Uramoodissa näkyy kappalemäärä, eikä puuttuvaa uistinta voi valita.
  Talvella jäällä on pieni pilkkirasia (pilkki + toukka, tasapainopilkki).
  Uistimet ovat koodissa tehtyjä 3D-malleja (`LureModels`), jotka näkyvät myös
  vavan päässä ja vedessä siimaan päin (ennen pallo). Testi `--tackletest`
  (kuva `--tackleshots=KANSIO`).
  Julkaistu [v0.40.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.40.0).
- **#57 Bug: ankkuri – korjattu (0.40.1).** Köyttä tuli lisää, kun vene
  liikkui: laskiessa ankkuri jäi paikalleen ja köysi juoksi veneen perässä, ja
  pohjassa köysi oli jousi, jota moottori venytti. Nyt ankkuri vajoaa keulan
  alla veneen mukana 1 m/s, köyttä on pohjaan osuttaessa syvyys + 0,5 m, ja
  köysi pitää keulan kovana rajana (`Boat.anchor_reach`, vähintään 1 m);
  ankkurista poispäin suuntautuva nopeus pysähtyy. Kireä köysi kääntää keulaa
  ankkuria kohti. Nosto etenee myös 1 m/s. `--anchortest` tarkistaa köyden
  pituuden, laskun ja noston nopeuden, ajoyrityksen ja liikkuvasta veneestä
  laskun.
  Julkaistu [v0.40.1](https://github.com/DesmondX80/catchfish/releases/tag/v0.40.1).
- **#26 Asetukset – tehty (0.41.0).** Alkuvalikon Asetukset on kaksipalstainen
  (ohjaus ja äänet | aika ja sää), ja taukovalikossa on oma Asetukset-näkymä
  (`SettingsControls`, `scripts/ui/settings_controls.gd`). Hiiren herkkyys
  0,25–3,0× ja käänteinen pystyohjaus vaikuttavat kameran kääntöön
  (`Settings.mouse_look_scale`). Äänet soivat omilla mikseriväylillä
  (Taustaäänet: tuuli, sade, laineet, linnut; Efektit: muut pelin äänet; Puhe:
  kalastaja), jotka `Settings` luo käynnistyessä; nollaan säädetty väylä
  mykistyy, M mykistää edelleen kaiken. Asetukset tallentuvat
  `user://asetukset.cfg`:hen, testiajot käyttävät oletuksia. `--pausetest`
  tarkistaa voimakkuudet, mykistyksen, herkkyyden ja käänteisen ohjauksen (ja
  sen painikeindeksit korjattiin Kalakirja-painikkeen jäljiltä).
  Julkaistu [v0.41.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.41.0).
- **#54 TV valikon taustaan – tehty (0.42.0).** Pirtin takaseinällä pöydän
  takana on lipaston päällä vanha puukuorinen kuvaputki-TV sisäantenneineen
  (`CabinScene._tv`). Ruudulla pyörii varjostimella piirretty kalastusohjelma
  (`shaders/tv_fishing.gdshader`, 24 s kierto): veneilijä iltajärvellä ja tärppi,
  lähikuva painuvasta kohosta sekä hauen hypyt roiskeineen. Kuvaputken
  kaarevuus, kohina, kanavan logo ja leikkausten lumisade; juovat häivytetään
  kaukaa katsottaessa (ei moiréta). Ruudun hohde valaisee pöytää ja välähtää
  leikkauksissa. `--tvtest=<kansio>` tarkistaa TV:n näkyvyyden ja tallentaa
  kuvat ohjelmasta.
  Julkaistu [v0.42.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.42.0).
- **#37 Veneen malli – tehty (0.43.0).** Runko on Ideal 470 -tyyppinen
  lasikuituinen soutuvene (`Boat.HULL_STATIONS`): korkea viisto keula, kyljissä
  limisaumaa jäljittelevät askelmat, tummansininen reunalista, kermanvärinen
  valettu pohja, tuhdot ja keulan jalkataso, kromiset hankaimet. Perämoottori on
  pieni musta nelitahtinen ohjausaisamalli ilman merkkinimiä: pyöristetty kopa
  punaisella raidalla, kiinnike peräpeilissä (ei käänny), varsi, kavitaatiolevy,
  vaihteistokotelo ja kolmilapainen potkuri, joka pyörii kaasulla. Samalla
  korjattiin vanhat läpimenot: saavi siirtyi keskemmälle, ankkuri makaa keulan
  jalkatasolla, etutuhdolla kalastaja istuu polvet koholla ja perätuhdolla
  keskempänä. `--boattest` tarkistaa esineiden ja jalkojen paikat rungon
  sisällä ja potkurin pyörimisen; `--boatshots=<kansio>` ottaa kuvat veneestä.
  Julkaistu [v0.43.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.43.0).
- **#35 Vaahtopäät tuulisella säällä – tehty (0.44.0).** Vesivarjostin
  (`whitecaps` `water.gdshader`:ssa) piirtää vaahtopäät, kun aallokko ylittää
  0,45 (n. 3,6 m/s tuulta), ja niitä on sitä enemmän, mitä kovempi tuuli.
  Rannan lähellä aallot eivät murru: vaahtopäät alkavat n. 200 m rannasta
  (etäisyys rantaan kulkee vesiverkon verteksiväreissä `shore.bin`:stä).
  Tuulen mukana ajelehtivissa 6 m ruuduissa syntyy satunnaisesti harjan
  suuntainen, keskeltä edellä kaartuva murtuma: kirkas harja leimahtaa,
  taakse jää läpikuultava, pitsimäiseksi harveneva vaahto, ja 5–9 s kierron
  jälkeen vaahtopää syntyy uuteen paikkaan. Yli 0,85:n aallokossa (n. 7 m/s)
  pintaan tulee tuulen suuntaisia vaahtojuovia. Kaukana vaahto sulautuu
  tasaiseksi vaalennukseksi (ei välkettä). `--foamshots=<kansio>` ottaa
  kuvat eri tuulilla selällä ja rannassa ja tarkistaa vaalean vaahdon osuuden.
  Julkaistu [v0.44.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.44.0).
- **Vastatuuleen soutu ja melonta – korjattu (0.44.1, ei Planessa).** Tuuli
  painoi venettä samalla voimalla suunnasta riippumatta, joten yli 8 m/s
  vastatuuleen ei päässyt soutaen eikä meloen (12 m/s:ssa vene ajautui 2 m/s
  taaksepäin). Nyt keula tai perä tuuleen vene ottaa 30 % kylkituulen
  voimasta (`WINDAGE_BOW`), ja vastatuuleen kalastaja vetää airoilla ja
  melalla kovempaa: 3 m/s vastatuulesta alkaen, enimmillään 2,2-kertaisesti
  (`effort`). Tyynen sään nopeudet eivät muuttuneet. `--headwindtest`
  soutaa ja meloo 12 m/s tuuleen, jonka puuskat nousevat 18 m/s:iin, ja
  tarkistaa myös tyynen sään huippunopeudet.
  Julkaistu [v0.44.1](https://github.com/DesmondX80/catchfish/releases/tag/v0.44.1).
- **#48 Veneen varjo – tehty (0.45.0).** Läpikuultava vesi ei näyttänyt
  varjoa pinnassa, joten auringon varjo piirtyi pohjaan ja näkyi syvältä
  irrallisena läiskänä metrien päässä veneen vierestä. Vesivarjostimessa on
  nyt oma `light()`: auringonvalo siroaa humusvedessä (`scatter_color`,
  `sun_scatter`), joten aurinkoinen vesi hehkuu ruskeana ja veneen varjo
  erottuu pinnassa rungosta alkaen; varjossa myös kimallus sammuu (GGX kuten
  Godotissa). Sironta lisätään omana valonaan eikä ALBEDOn kautta, koska
  lineaarisena ALBEDO on enimmäkseen taivaan heijastusta: muuten pinta
  vaaleni ja `--foamshots` näki rannassa valkoista. Heijastuksen ja vaahdon
  osuus ei siroa (`scatter_weight`). Maasto ja
  pohja saivat oman varjostimen (`terrain.gdshader`), jossa auringon varjo
  sumenee veden alla syvyyden mukaan (`shadow_fade`), joten 1–2 m syvyydessä
  pohjavarjo näkyy vielä haaleana. `--shadowshots=<kansio>` ottaa kuvat
  ylhäältä aamulla, keskipäivällä ja illalla syvässä ja matalassa vedessä ja
  tarkistaa, että vesi rungon varjopuolella on yli 12 % tummempaa kuin
  aurinkoisella puolella.
  Julkaistu [v0.45.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.45.0).
- **#74 Automaattitestit GitHub Actionsiin – tehty (0.45.1).** Workflow
  `tests.yml` ajaa 27 ikkunatonta testiä (`tools/run_tests.sh`, aikaraja 10 min
  testiä kohti) jokaisesta pushista ja PR:stä noin 5 minuutissa; ikkunaa
  vaativat testit (input, pause, menu, settings, career, timepick, tv) ajetaan
  käsin. Samalla korjattiin kaksi epävakaata testiä: `--speciestest` ajoi
  talvikokeet kesän lajitiedoilla (0.30.0:sta lähtien välimuistiin laskettu
  `update_traits()` jäi kutsumatta talven vaihtuessa) ja koho-ongen
  särkikalaraja laskettiin 25 %:iin, koska osuus vaihtelee kalakannan
  arvonnan mukaan 29–34 %; `--voicetest` kaatui noin joka 17. ajolla, kun
  oikea kala tai merikotka huusi väliin (kalat ovat nyt testissä varovaisia
  eikä lintuja tule).
  Julkaistu [v0.45.1](https://github.com/DesmondX80/catchfish/releases/tag/v0.45.1).
- **#46 Ennätyslistan tyhjennys – tehty (0.46.0).** Kalalajit ovat muuttuneet
  projektin alusta (kuha ja taimen poistuivat 0.18.0), joten vanhat ennätykset
  tyhjennetään kerran. Saaliskirja (`user://saaliskirja.json`) ja kalakirja
  (`user://kalakirja.json`) tallennetaan nyt muodossa `{"version": 2, ...}`;
  vanhan muodon tallennus luetaan tyhjänä ja kirjoitetaan uudessa muodossa.
  Testiajot eivät enää kirjoita saaliskirjaan edes käynnistyessään.
  Tarkistukset `--booktest`issa.
  Julkaistu [v0.46.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.46.0).
- **#21 Tuulikellunta – tehty.** Vene ajelehtii vapaasti tuulen mukana
  (veneen tuulifysiikka); uistinankkuria ei toteuteta.
- **#42 FPV-kamera – tehty (0.47.0).** P vaihtaa kameran veneen takaa
  kalastajan silmiin ja takaisin; valinta tallennetaan asetuksiin. Kamera on
  pään luun kohdalla, hiiri kääntää katsetta (ylös 57°, alas 75°), ja
  katsesuunta on heittosuunta. Pää kutistetaan luurangon muokkaimessa
  kameran sisään ja päähine piilotetaan, joten kädet, vapa ja vene näkyvät.
  Rulla ei zoomaa FPV:ssä. Kohon lähikuva, saavi, kalapakki ja haavinta
  toimivat ennallaan, ja niissä pää näkyy. Testi `--fpvtest`, kuvat `--fpvshots`.
  Julkaistu [v0.47.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.47.0).
- **#78 Välkkyminen – tehty (0.47.1).** Välke ja edestakainen heiluminen
  mitattiin kuvista (`--jittershots`): kamera kääntyy hitaasti tai pysyy
  paikallaan, ja pikselit, jotka vaihtavat väriä edestakaisin, merkitään.
  Syyt ja korjaukset:
  - *Tahtiero*: vene liikkui fysiikan tahdissa (60 Hz), mutta kamera,
    kalastaja ja vavat ruudun tahdissa, joten kun ruutuja ja fysiikka-askelia
    ei ollut yhtä monta (esim. 144 Hz:n näyttö), vene ja vapa nykivät
    edestakaisin, FPV:ssä jopa 17 cm. Nyt `Boat` piirtää rungon kahden
    viimeisen fysiikka-askeleen väliin (`Engine.get_physics_interpolation_fraction`)
    ja ajetaan ennen muita; vavat, siimat, ankkuri ja haavi siirretään joka
    ruudulla rungon ja kalastajan vartalon mukaan (`Fishing.follow_boat`), ja
    FPV-kamera lukee pään paikan luurangon koordinaateista saman ruudun
    asennossa. Testi `--synctest` (fysiikka 45 Hz, ruutu 30 Hz).
  - *Päällekkäiset pinnat* (z-fighting): moottorilevy peräpeilin tasossa
    (perälauta), saavin pohja lattian ja talvella jään tasossa, moottorin
    kiinnikkeen ja varren osat. Osia siirrettiin 1–3 mm. Testi
    `--overlaptest` etsii veneen ja sen ympäristön verkoista samassa tasossa
    päällekkäin olevat kolmiot, jotka näkyvät samalta puolelta.
  - *Varjot*: aurinko kääntyi joka ruudulla, jolloin varjokartta siirtyi alle
    tekselin verran ja varjojen reunat välkkyivät. Aurinko kääntyy nyt
    0,1°:n askelin (`SkyTime.SUN_STEP`).
  - Kaukaisen metsän välke kameraa käännettäessä on reunojen aliasointia
    (peli käyttää jo 4× MSAA:ta), eikä sitä muutettu.
  Julkaistu [v0.47.1](https://github.com/DesmondX80/catchfish/releases/tag/v0.47.1).

- **#79 Vetouistelun vastaisku / vavan nosto, #53 vavan kärjen näkymä – tehty (0.48.0).**
  Kun vapa lasketaan telineeseen, peli on uistelumoodissa (`Fishing.trolling`)
  ja kamera vaihtuu FPV:hen (asetusta ei tallenneta), joten vapojen kärjet
  näkyvät. Uistelumoodissa käsivavalla ei heitetä: vasen hiiri laskee
  uistimen veneen perään ja pohjassa pidettynä siimaa lähtee veneen
  liikkuessa (enintään 60 m). FPV:ssä hiiren nappi valitsee vavan sen
  mukaan, kummalla puolella ruutua vavan kärki näkyy (`_rod_at_side`):
  telinevapa nousee käteen, ja tärpissä nosto on vastaisku (60–90 %
  veneen vauhdin mukaan). Kun toinen vapa on kädessä, nappi nostaa vain
  telinevavan, jossa on tärppi tai kala, ja käsivapa menee telineeseen
  (siima vedessä) tai veneen pohjalle. Telinevavan tärppi kestää 0,6 s
  pidempään, ja itsekoukutus harvinaistui (10–40 %). Testi `--trollstriketest`.
  Julkaistu [v0.48.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.48.0).
- **#36 Verkkokalastus – tehty (0.49.0).** Uusi pyyntitapa: 30 m:n pohjaverkko
  (korkeus 1,8 m) kolmella silmäkoolla, 22 mm (särki, ahven, kiiski), 35 mm
  (lahna, isot ahvenet, made) ja 50 mm (hauki, iso lahna, made). Silmäkoko
  valitaan B:llä, ja N laskee verkon: ensimmäinen pyykki ja kivi putoavat
  veteen, ja verkko valuu löysänä nippuna oikean laidan yli perän läheltä
  veneen reitille (piste metrin välein), kun soudetaan tai ajetaan. Yli
  1,5 m/s vauhdissa verkko jarruttaa. Lasku
  päättyy 30 metriin, N:ään tai matalaan (alle 0,8 m), ja se alkaa vain
  vähintään 1,2 m:n syvyydestä, kauempana laiturista, ankkuri ylhäällä ja
  siimat sisällä. Järvessä voi olla kolme verkkoa. Pyykin luona pysähtyneenä
  (moottori sammuksissa) N nostaa verkon: kalastaja istuu perätuhdolla kasvot
  oikealle laidalle ja vetää löysää verkkoa laidan yli 0,5 m/s kasaan veneen
  pohjalle, vene liukuu verkkoa pitkin, ja tarttuneet kalat nousevat pinnasta
  verkossa roikkuen (kidukset silmässä, pyrstö laidan ulkopuolella) ennen kuin
  ne tulevat saaviin. Lopuksi tulee yhteenveto.
  Saalismalli (`Nets.catch_between`) lasketaan nostettaessa koko pyyntiajalta
  15 minuutin askelin, joten se toimii myös reissujen yli. Kohtaamiset tulevat
  lajin tiheydestä, verkkopaikan elinpaikkasopivuudesta (`FishPopulation.habitat`
  on nyt staattinen ja ottaa vuodenpäivän tiedot), vuorokausi- ja
  vuodenaika-aktiivisuudesta ja siitä, kattaako 1,8 m:n verkko lajin
  uintisyvyydet. Tarttuminen tulee silmäkoon valinnasta (`Species` "net": paras
  pituus k × silmäkoko; pienet kalat uivat läpi). Täyttyvä verkko pyytää
  huonommin, ja iso hauki voi repiä itsensä irti. Kalibrointi: kesäyönä (12 h)
  2–2,5 m:n syvyydessä 35 mm:n verkko tuo noin 9–10 kalaa (1,4–1,7 kg), 50 mm
  noin 5 kalaa (2,5–3,5 kg) ja 22 mm noin 8–10 pientä kalaa, enimmäkseen
  kiiskiä. Elävää populaatiota verkko ei vähennä. Verkkokalat kirjataan kuten
  vapakalat (`Fishing.record_catch`): saaliskirja ja ennätykset
  kertakalastuksessa, kalakirja aina ja saavi; merkinnän välineenä on verkon
  nimi. Uramoodissa verkot ostetaan kaupasta (25–35 €), ne jäävät järveen
  reissujen ja yöunien yli (`ura.json`: `nets`), ja kolmen repeämän jälkeen
  verkko on pilalla. Jäiden tullessa järveen jääneet verkot menetetään.
  Kertakalastuksessa verkkoja on kolme kutakin silmäkokoa. Verkot näkyvät
  kartalla (K) oransseina viivoina. Testi `--nettest` (kesä ja talvi).
  Julkaistu [v0.49.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.49.0).
- **#24 Uramoodi: kalastonhoitomaksu ja kalan vapautus – tehty (0.50.0).** Suunnitelma
  `docs/suunnitelmat/CATCHFISH-24.md`. Uramoodissa virvelikalastus ja verkon
  lasku vaativat kalastonhoitomaksun, jonka pelaaja maksaa liikkeessä:
  vuosimaksu 47 € (31.12. asti), viikkomaksu 16 € (7 vrk) tai vuorokausimaksu
  6 € (ostopäivä) (`Career.fee_until`). Päällekkäisessä maksussa voimassa jää
  myöhempi päättymispäivä. Ilman maksua avovedessä käyvät vain onget ja jäällä
  pilkit (`Fishing.license`), ja verkon nosto on sallittu. Toisen siiman lasku
  uistellessa vaatii tekoaltaan luvan (10 €, 31.12. asti,
  `Career.rod_permit_until`) ja maksun (`Fishing.rod_permit`). Oikeudet
  tarkistetaan reissun alussa. Aloitusrahat ovat 50 € (ennen 20 €), eikä uusi
  ura ala maksettuna. Z vapauttaa haavissa tai jäällä olevan kalan
  (`Fishing.released`): kala lähtee saavista, kalakirja pysyy ennallaan ja
  kalastaja sanoo "Mene kasvamaan.". Uramoodissa vapautus antaa mainetta
  (`Career.release_fame`: 1 piste alkavaa kiloa kohden, iso kala +5, alle 50 g
  ei mitään), ja maine nostaa myyntihintoja 1 % jokaista 10 mainetta kohden
  (enintään 25 %). Kotinäkymä näyttää maineen, maksun ja luvan sekä neuvon,
  jos kalastaa ei voi. Testi `--releasetest` (kesä ja talvi).
  Julkaistu [v0.50.0](https://github.com/DesmondX80/catchfish/releases/tag/v0.50.0).
- **#77 Vesi aidomman näköiseksi – tehty.** Suunnitelma
  `docs/suunnitelmat/CATCHFISH-77.md`. Aallokko lasketaan joka kohdassa
  tuulesta ja pyyhkäisymatkasta (JONSWAP: Hs ja huippuaallonpituus).
  Pyyhkäisymatka 16 tuulensuuntaan 16 m ruudukossa tulee tiedostosta
  `assets/lake/fetch.bin` (`tools/build_fetch.py`), joten ylätuulen rannat ja
  saarten suojapuolet ovat tyynempiä. Pinta on 12 Gerstner-aallon summa
  (0,3–12 m): aallon korkeus riippuu paikallisesta huippuaallonpituudesta,
  harjat terävöityvät jyrkkyyden mukaan, aaltoryhmät tekevät suurimmista
  aalloista n. 1,5–2 × Hs, aaltorintamat mutkittelevat ja harjat katkeilevat
  pätkiksi, joten ruutukuviota ei synny. Kapeassa lahdessa (huippuaallonpituus
  alle 0,4 m) todellinen aallonkorkeus jaetaan lyhimmille aalloille. Aallokon tuuli seuraa tuulta pelin ajassa (90 % 10 peliminuutissa,
  laantuminen 20), ja tuulen kääntyessä yli 20° uusi suuntasarja häivytetään
  ristiin minuutissa (`Waves.step`). Kameraa seuraava tiheä lähivesi (120 m)
  liikkuu aaltojen mukana, kaukainen järviverkko on tasainen. Varjostimessa
  väreet tuulen mukaan saumattomasta kuviosta (`tools/build_ripples.py` →
  `assets/lake/ripples.bin`: satoja aaltoja ±60° tuulesta, kolme mittakaavaa,
  laikuittainen voimakkuus; suoja heikentää niitä vain ylätuulen rannan
  ensimmäisillä metreillä, `Waves.ripple_amount`; lyhyet aallot ja väreet
  vaihtelevat tuulen mukana ajelehtivina tyynempinä ja karheampina laikkuina), puuskien tummat pehmeät
  laikut (`weather.gust`) ja vaahtopäät paikallisen aallokon mukaan harjalla
  ja sen etupuolella (pehmeät reunat, läpikuultava jälkivaahto, mutkittelevat
  katkonaiset juovat). Vene, koho, pyykit,
  ankkuri ja vana seuraavat samaa mallia (`Waves.swell_height`), aaltoäänet ja
  kohon keinunta paikallista aallokkoa (`Waves.local_strength`). Uusi asetus
  *Veden laatu*: Korkea (työpöytä) tai Matala (selain; harvempi lähivesi, kaksi
  pääaaltoa pinnan muodossa, ei väreitä vaan tuulen mukana ajelehtiva
  karheuden vaihtelu). Testit `--wavetest` ja
  `--watershots`; `--foamshots`, `--wavesoundtest`, `--baittest`,
  `--settingstest` ja `--overlaptest` päivitettiin.
- **#88 Äänimaailma – tehty (0.51.1).** Suunnitelma `docs/suunnitelmat/CATCHFISH-88.md`.
  Kuikan huuto illalla ja yöllä poistettiin (ääni, `make_sounds.py`:n
  generointi ja `GameAudio`:n laskuri). Pikkulintujen (peippo, talitiainen)
  laulujen väli on aina 8–15 s, eikä aamulla ole enää omaa tiheämpää väliä;
  ne laulavat edelleen vain valoisalla. Testi `--birdsoundtest`.
- **#68 Muita veneitä järvellä – tehty (0.52.0).** Suunnitelma
  `docs/suunnitelmat/CATCHFISH-68.md`. Avovesikaudella valoisaan aikaan
  (`sky.daylight() > 0,45`) järvellä on enintään kaksi vierasta venettä:
  ensimmäinen 2–6 min pelin alusta, seuraava 4–12 min edellisestä (todellista
  aikaa), moottori-/soutuveneitä 60/40, ja pelin alussa yksi vene voi olla jo
  kalapaikalla. Yli 8 m/s tuulella tai sateella (`rain` > 0,5) ei lähdetä, ja
  hämärtyessä veneet palaavat laiturille. Vene ilmestyy ja katoaa laiturilla,
  kun pelaaja on yli 250 m:n päässä tai ei katso laituria kohti (eikä alle
  40 m:n päässä). Reitit `AStarGrid2D`-haulla 8 m:n ruudukossa (moottorivene
  ≥ 1,3 m, soutuvene ≥ 0,6 m, 15 m rannasta, laiturin kansi kierretään,
  laiturin matala lähivesi 120 m:n säteellä hitaasti, verkkojen pyykit 10 m
  ja verkon linja kierretään); ruudukko rakennetaan pelin alussa noin 2 ms
  ruutua kohti. Kodan laiturilta on noin 600 m matalaa vettä, joten
  moottoriveneet käyttävät vain uimalaituria ja veneenlaskupaikkaa ja kodalla
  käyvät vain soutuveneet. Soutuvene pääsee kodan lahdesta kapeaa vettä
  pitkin (≥ 0,6 m, rantaan ≥ 6 m, reittihaku välttää painolla 4); soudettava
  matka kalapaikalle on enintään 600 m. Vieras vene on laiturissa kannen
  suuntaisena ja lähtee ensin 5 m suoraan eteenpäin kannen pään ohi. Moottorivene ajaa 4,4 m/s (pelaajan
  moottori ja vastus 70 %:n kaasulla), noin puolet ohiajoista kulkee
  30–80 m:n päästä pelaajasta. Väistö: pelaaja ja toiset veneet kierretään
  15 m:n (soutaen 6 m) etäisyydeltä, alle 10 m:ssä hiljennetään ja alle 4 m:ssä
  pysähdytään. Peräaalto (`OtherBoats.wakes_at`): Kelvinin hajaantuvat aallot
  35°:n kulmassa, saapuvat vanan V-haaran mukana, 4,5 harjaa, 0,15 m 20 m:n
  päässä matkanopeudella, vaimenevat `d^-1/3` ja ajan mukaan; keinuttavat
  pelaajan runkoa (`Boat._animate`) ja voimistavat aaltoääntä, mutta eivät
  siirrä venettä eikä näy vesipinnassa. Törmäys (`Boat._boat_collision`,
  `Boat.hull_push`) kuten laituriin, viesti "Kolahdus! Vene törmäsi toiseen
  veneeseen". Vieraat veneet: sama runko (`Boat.build_hull`) kolmella
  värillä, kuljettajalla oranssi kelluntaliivi (`other_boat_crew.gd`), oma
  vaahtovana, moottorin ääni 600 m:iin, airovedot lähellä; vettä ei piirretä
  niiden sisälle (`other_boats`-uniform). Testit ja kokeiluajot eivät saa
  satunnaisia veneitä (paitsi `--perftest` ja `--autotest`). Testi
  `--otherboatstest` (kesä ja talvi), kuvat `--otherboatshots=KANSIO`.
- **#83 Bug: ankkuriköysi venyy nostettaessa – korjattu.** Suunnitelma
  `docs/suunnitelmat/CATCHFISH-83.md`. Köysi venyi, koska nostossa vene irtoaa
  heti (#57), mutta ankkuri nousi vain 1 m/s ja köysi piirrettiin suorana niin
  pitkänä kuin väli oli. Nyt köyttä käsitellessä (`BoatAnchor.handling()`) W/S
  ja A/D eivät liikuta venettä kuten verkkoa nostaessa: X vie kaasun vapaalle ja
  aisan keskelle (ilmoitus "Kaasu vapaalle – ..."), moottori jää tyhjäkäynnille,
  ja ajoyrityksestä tulee kerran tilan mukainen ilmoitus "Kädet ankkurin köydellä". Painallus
  lasketaan vain uudesta painalluksesta, joten X:ää painaessa pohjassa ollut W ei
  peitä kaasun ilmoitusta. Nostossa `BoatAnchor.rope_out` on ulkona oleva köysi
  (alussa `anchor_rope`, sitten −1 m/s): keulan ja renkaan väli on enintään sen
  mittainen, eli ankkuri laahautuu veneen perässä ja irtoaa pohjasta, kun köysi
  ei enää riitä pohjaan (keulapiikin korkeuden takia jo noston alussa). Irti
  pohjasta se heilahtaa keulan alle. Löysä köysi roikkuu kaarella. Vene irtoaa
  edelleen heti. Köyttä kelataan aina 1 m/s, joten nosto päättyy
  aina (syvyys + 0,5 s), myös liu'ussa ja tuulessa. Keulan takana ankkuri pysyy
  rungon pohjan alla (`KEEL_CLEAR`), ja kun köysi ei enää riitä sinne, ankkuri
  siirtyy veden alla keulan eteen (`BOW_CLEAR`) ja nousee siitä. Köysi, joka
  kulkisi suorana rungon läpi, kiertää keulavantaa pitkin vesirajaan
  (`_through_hull`). `--anchortest` tarkistaa rajan joka ruudulla (kaasulla,
  5 m/s liu'ussa, vauhdissa perutussa laskussa ja 10 m/s:n tuulessa), rungon
  läpileikkauksen, ajoesteen moottorilla, airoilla ja melalla sekä ajon jatkumisen; kuvat
  `ankkuri-5-nosto-kaasulla` ja `ankkuri-6-nosto-liussa`.

## Huomioita ja avoimia kysymyksiä

- **Järven syvyydet** tulevat veden alle jääneistä maastotietokannan korkeuskäyristä (15 m ja 12,5 m, #10). Syvin kohta (7 m) on paikallistieto; sen tarkkaa paikkaa ei tiedetä, joten se on vanhan jokiuoman syvänteen keskellä pohjoisosassa.
- **Puhesynteesiääni** `fi_FI-harri`: opetusaineisto CC0, mutta malli on jatkokoulutettu lessac-äänestä, jonka ehdot ovat rajoitetummat. Jos peliä joskus jaetaan kaupallisesti, omat äänitykset ovat varmempi valinta.
- **Vanhat uratallennukset** voivat sisältää kuhia ja taimenia (poistettu 0.18.0); ne voi yhä myydä.
