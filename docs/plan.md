# Catchfish – suunnitelma ja tilanne

Päivitetty 21.10.2026. Nykyinen versio **0.25.0**
([release](https://github.com/DesmondX80/catchfish/releases/tag/v0.25.0)).

Catchfish on Godot 4.7 -kalastussimulaattori Raahen Haapajärven tekoaltaalla.
Järvi on mallinnettu Maanmittauslaitoksen avoimesta aineistosta. Pelaaja soutaa
tai ajaa moottorilla, heittelee virvelillä, uistelee, onkii ja pilkkii talvella.
Käyttöohje ja ohjaus ovat [README.md](../README.md):ssä.

## Tähänastinen tilanne

### Valmiina (versiot 0.1–0.25.0)

| Alue | Ominaisuudet |
|---|---|
| Vene | Oma vesifysiikka, soutu ja perämoottori, ankkuri, tuuli ajelehdittaa, pohjakosketus, törmäys laitureihin (kolahdus, liukuu laituria pitkin) |
| Maailma | MML-aineistosta tehty järvi ja maasto, vuodenajat todellisen päivämäärän mukaan, sää (tuuli, pilvet, sade, lumi), todellinen sää ja kellonaika valinnaisina |
| Kalastus | Virveli ja uistimet (lusikka, vaaput, lippa, jigi), taipuva vapa ja fysiikkaan perustuva siima, jarru ja väsytys, haavinta omana animaationaan omalla kameralla |
| Uistimet | Lusikka ui kelatessa ja uistellessa 1,5 m:ssä (nopeasti kelatessa 1 m) ja vajoaa pohjaan vedon pysähtyessä; vaaput kelluvat ja uivat tavoitesyvyydessään |
| Vetouistelu | Kaksi vapaa ja vapatelineet perälaudassa (R), tärppi telineeseen, veneen vauhti koukuttaa |
| Onki | Koho-onki (syvyys F/G ennen heittoa) ja pohjaonki (mato 0,5 m pohjasta), tärpissä koho nykii ja uppoaa, kamera zoomaa kohoon |
| Heitto | Tähtäin näyttää osumapisteen (sama lentofysiikka kuin heitossa) ja varoittaa rantaan menevästä heitosta |
| Talvi | Pilkkiminen avannosta: kairaus, pilkki ja tasapainopilkki, kävely jäällä |
| Kalat | Altaan kalakanta: ahven, särki, hauki, kiiski, lahna, made. Lajeilla elinpaikka, vuorokausi- ja vuodenaikarytmi, uistin- ja syöttimieltymykset, 3D-mallit. Laji tunnistetaan vasta, kun kala näkyy veneen lähellä |
| Saalis | Kalasaavi veneen pohjalla (Tab: kuva ylhäältä ja painot), ennätyslista, kalan kuva saalisikkunassa |
| Uramoodi | Päivät ja kello, rahat, uistinvarasto, kalastustarvikeliike, kalojen säilö ja myynti (Luken sisävesien tuottajahinnat 2024) |
| Äänet | Moottori, aallot (pienet / isot) ja tuuli (heikko / kova, talvella omat) oikeista Freesoundin CC0-nauhoituksista (tools/make_recorded_sounds.py); muut syntetisoitu (tools/make_sounds.py): kela, jarru, linnut, sade |
| Kalastaja | Quaterniuksen riggattu malli (CC0): kesällä maastoasu ja lippalakki, talvella pilkkihaalari ja pipo; kädet IK:lla vapaan, airoihin, ohjausaisaan ja kairaan, istuessa jalat lattialla, jäällä kävelyanimaatio |
| Puhe | Kalastajan repliikit tapahtumiin ja lajin huudahdus tunnistettaessa (Piper-puhesynteesi, tools/make_voice.py) |

### Tehtävänhallinta

Tehtävät ovat Plane Cloudissa, projekti **CATCHFISH**. Tila 20.10.2026:
14 tehtävää valmiina, 1 peruttu, 26 avoinna.

## Suunnitelma: seuraavat tehtävät

Prioriteetti Planen mukaan, sitten oma suositusjärjestys. Numerot ovat Planen
tunnisteita (CATCHFISH-N).

### Kiireelliset ja korkeat (Todo)

| # | Tehtävä | Prioriteetti | Huomio |
|---|---|---|---|
| 29 | Kalat eivät saa näkyä vedessä | korkea | FishVisuals näyttää kalat veden alla; humusvedessä niitä ei pitäisi nähdä (koukussa oleva kala näkyy jo vasta tunnistettaessa) |
| 17 | Hauki seuraa uistinta | korkea | Näkyvä seuranta veneelle asti, isku viime hetkellä. Huom. ristiriita #29:n kanssa: seuraava kala näkyy vain lähellä pintaa/venettä |

### Pelattavuus ja realismi (Todo)

| # | Tehtävä | Huomio |
|---|---|---|
| 31 | Alle metrin syvyydessä potkuri osuu pohjaan | Moottorin pohjakosketus |
| 34 | Haavinta aivan omaksi animaatiokseen | Tarkennettava: mitä puuttuu nykyisestä (CATCHFISH-5 tehty) |
| 38 | Ankkurianimaatio | |
| 19 | Kalojen vuodenaikakäytös | Kutu keväällä matalassa, kesähelteellä syvemmälle |
| 20 | Ilmanpaineen ja sään vaikutus syöntiin | |
| 18 | Kaikuluotaimen kalakaaret ja pohjan laatu | Liittyy #10:een |
| 10 | Järven syvyydet | Syvyys on nyt arvioitu etäisyydestä rantaan |
| 36 | Verkkokalastus | Uusi pyyntitapa |
| 8 | Lisää välineitä | Onki tehty (#15); syöttikala virvelillä puuttuu |

### Grafiikka ja äänet (Todo/Backlog)

| # | Tehtävä |
|---|---|
| 37 | Veneen malli |
| 39 | Kodan ulkoasu kodannäköiseksi |
| 40 | Lintutornin ulkoasu |
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

Seuraavaksi suunnitelman mukaan: #29 ja #17 yhdessä (kalojen näkyvyys ja hauen
seuranta), sitten #31 (potkuri osuu pohjaan alle metrin syvyydessä).

## Huomioita ja avoimia kysymyksiä

- **Järven syvyys on arvioitu** (enintään 4 m), koska tekoaltaasta ei ole avointa syvyysaineistoa (#10).
- **Puhesynteesiääni** `fi_FI-harri`: opetusaineisto CC0, mutta malli on jatkokoulutettu lessac-äänestä, jonka ehdot ovat rajoitetummat. Jos peliä joskus jaetaan kaupallisesti, omat äänitykset ovat varmempi valinta.
- **Kalojen näkyvyys (#29) ja hauen seuranta (#17)** pitää suunnitella yhdessä: kalat eivät saa näkyä humusvedessä, mutta seuraava hauki kannattaa näyttää, kun se on lähellä pintaa ja venettä.
- **Vanhat uratallennukset** voivat sisältää kuhia ja taimenia (poistettu 0.18.0); ne voi yhä myydä.
