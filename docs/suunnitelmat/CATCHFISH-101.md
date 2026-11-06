# CATCHFISH-101: Kodan rannan väylä syvemmäksi moottoriveneille

## Tavoite
Kodan laiturilta pääsee moottorilla järvelle ilman, että potkuri osuu pohjaan:
kodan kapeaan lahteen ruopataan noin 1,5 m syvä väylä laiturilta syvään
veteen. Samalla vieraat moottoriveneet (CATCHFISH-68) voivat käyttää kodan
laituria, eli päätös 14 kumoutuu.

## Nykytila (mitattu `assets/lake/`-datasta)
- Kodan laituripaikka (`starts[0]`, id `kota`) on kohdassa x = −1314, z = 990;
  syvyys 0,78 m, rantaan 8 m.
- Laiturilta lähin vesi, jossa on ≥ 1,3 m syvää ja ≥ 15 m rantaan
  (vieraan moottoriveneen syvä vesi), on noin 540 m päässä kohdassa
  (−1040, 712). Koko matka on kapeaa lahtea ja pientä lampea: pohja
  0,75–0,82 m, rantatörmän reunasolut 0,6 m. Moottorilla ajettaessa koko
  matka on varoitusrajan (`Boat.SHALLOW_WARNING` 1,3 m) alla, ja potkuri osuu
  pohjaan alle 1,0 m:ssä (`Boat.PROP_DEPTH`).
- Lahden vesileveys keskilinjalla on 20–37 m (kapein noin 20 m laiturin
  edessä ja kohdassa (−1314, 926)), lammessa ja sen jälkeen 40–50 m.
- Väylän alueella ei ole kiviä (`rocks`), eikä se ole maatuvaa vesialuetta.
- Syvyys tulee datasta: `tools/build_lake.py` laskee `heights.bin`:n
  MML:n korkeuskäyristä (`bathymetry`). Rakennus on toistettavissa: ajoin sen
  nykyisellä MML-aineistolla, ja kaikki tiedostot (`heights.bin`, `water.bin`,
  `ground.bin`, `shore.bin`, `lake.json`, `map.png`) syntyivät tavu tavulta
  samoina kuin repossa. MML-raakadata on vain pääkansiossa
  `~/projektit/catchfish/data/mml/` (gitignore), ei työkopiossa.

## Toiminta pelaajan kannalta
- Pelaaja lähtee kodan laiturilta moottorilla (M, kaasu) ja ajaa väylää
  pitkin järvelle. Väylän keskellä syvyys on koko matkalla vähintään 1,4 m,
  joten potkuri ei osu pohjaan eikä tule varoitusta "Matalaa (… m)! Varo
  potkuria". Väylän pohja on 1,5 m.
- Väylä on noin 10 m leveä tasapohja, jonka reunat loivenevat lahden nykyiseen
  pohjaan noin 8 m matkalla. ≥ 1,3 m syvää (ei varoitusta) on 7–16 m
  leveydeltä, ≥ 1,0 m (potkuri ei osu) 11–25 m leveydeltä. Jos pelaaja ajaa
  väylän reunalle, tulee ensin nykyinen matalan varoitus ja sitten nykyinen
  pohjakosketus; säännöt eivät muutu.
- Väylä alkaa laiturin vierestä: laituripaikassa ja veneen perän kohdalla
  syvyys on vähintään 1,4 m, joten moottorin voi käynnistää ja laittaa
  vaihteen päälle laiturissa ilman varoitusta.
- Väylä päättyy noin 515 m päähän kohtaan (−1028, 708), jossa vesi on jo
  luonnostaan ≥ 1,5 m syvää ja rantaan on yli 50 m.
- Rantatörmä (ensimmäinen vesisolu rannasta) ja lahden reunojen kaislikko
  jäävät ennalleen; pystyseinää ei synny.
- Kalastus: väylässä on syvempää vettä, joten kalojen syvyysmieltymykset ja
  kaikuluotaimen pohjan laatu (`bottom_at`) määräytyvät uuden syvyyden mukaan
  nykyisillä säännöillä (väylän keskellä muta tai kasvillisuus, reunojen
  rinteissä kova pohja). Uutta kalastussääntöä ei tule.
- Vieraat moottoriveneet: kota lisätään moottoriveneiden laitureihin. Vene
  voi lähteä kodalta toiselle laiturille tai kalapaikalle ja palata kodalle,
  ja järvellä oleva vene voi palata kodalle, jos se on lähin. Muut säännöt
  (ilmestyminen vain, kun pelaaja on yli 250 m:n päässä tai ei katso
  laituria, laituri vapaa, väistö, törmäys) ovat ennallaan. Kapealla
  väylällä ei ole tilaa kiertää pelaajaa, joten vene hiljentää alle 10 m:ssä
  ja pysähtyy alle 4 m:ssä (nykyinen `NEAR_SLOW`/`NEAR_STOP`), kunnes pelaaja
  väistää; jumiin jäänyt vene katoaa nykyisellä `STUCK_TIME`-säännöllä, kun
  pelaaja ei näe sitä.
- Soutuveneet kulkevat kodalta kuten nyt (kapea vesi, paino 4); syvempi väylä
  vain helpottaa niiden reittiä.

## Ulkoasu ja äänet
- Ei uutta HUD-tekstiä, valikkoa eikä ääntä (paitsi jos Teemu valitsee
  kysymyksessä 2 kartan väyläviivan tai merkit).
- Vedenalainen pohja tummuu väylän kohdalla nykyisen syvyysvärin mukaan
  (`LakeWorld._summer_ground_color`: väri syvyyden mukaan 3 m:iin asti), eli
  väylä näkyy läheltä hieman tummempana kaistana. Reunan pitää olla
  liukuva: ei terävää rajaa, ei portaita eikä suorakulmaista "kaukaloa".
  Väylän keskilinja seuraa lahden mutkia (ei suoria pitkiä sivuja).
- Kartta (`map.png`) rakennetaan uudelleen samalla skriptillä, joten väylä
  näkyy kartalla nykyisellä syvyysvärityksellä hennosti tummempana viivana
  (0,8 m → 1,5 m on noin 10 värisävyn ero).
- Laiturin tolpat ulottuvat uuteen pohjaan automaattisesti (`height_at`).

## Toteutus pääpiirteissään
1. **Ruoppaus järviaineistoon** (`tools/build_lake.py`, suositus; vaihtoehto
   avoimessa kysymyksessä 4):
   - Uusi vakio väylistä MML_STARTSin tapaan, esim. `MML_CHANNELS`: id, laituri
     (`kota`), tavoitesyvyys 1,5 m ja keskilinja ETRS-TM35FIN-koordinaatteina.
     Ensimmäinen piste on kodan laituripaikka (lasketaan `start_near`ista,
     ei kovakoodata), loput lahden keskilinjaa pitkin. Prototyyppini
     keskilinja (maailman x, z; sileäksi suodatettu reitti, joka pysyy
     mahdollisimman kaukana rannoista):
     (−1314, 990) (−1323, 983) (−1327, 976) (−1327, 952) (−1302, 900)
     (−1270, 808) (−1232, 748) (−1220, 741) (−1204, 741) (−1160, 776)
     (−1144, 780) (−1120, 779) (−1080, 759) (−1028, 708),
     TM35FIN: (380130, 7167938) (380121, 7167945) (380117, 7167952)
     (380117, 7167976) (380142, 7168028) (380174, 7168120) (380212, 7168180)
     (380224, 7168187) (380240, 7168187) (380284, 7168152) (380300, 7168148)
     (380324, 7168149) (380364, 7168169) (380416, 7168220). Pituus noin 515 m.
   - Ruoppausprofiili jokaiselle vesisolulle: `off` = etäisyys keskilinjaan,
     paino `w` = 1, kun `off` ≤ 5 m, ja smoothstep 0:aan, kun `off` = 13 m.
     Rantaraja `cap` = nykyinen syvyys, jos rantaan ≤ 4 m (törmä
     ennallaan), muuten min(1,5; 0,8 + 0,175 × (rantaetäisyys − 4)).
     Uusi syvyys = max(nykyinen, min(nykyinen + (1,5 − nykyinen) × w, cap)).
     Väylä vain syventää; matalammaksi mikään ei muutu.
   - Ruoppaus tehdään `mml_lake`issa aloituspaikkojen laskun jälkeen ja ennen
     `map_image`a, jotta laituripaikat (`starts`: x, z, yaw, dock_length)
     pysyvät tarkalleen ennallaan ja kartta näyttää väylän.
   - Prototyyppi näillä luvuilla: 678 solua (noin 1,1 ha) muuttuu, syvennys
     enintään 0,73 m, pohjan suurin kaltevuus väylän alueella 0,16 (noin 9°;
     nyt lahdessa 0,11), kaislikkokelpoisia vesisoluja (alle 0,7 m,
     rantaan alle 14 m) lahdella 537 entisen 575:n sijaan. Keskilinjan
     syvyys pelin interpoloinnilla keskimäärin 1,49 m, mutta kahdessa
     kapeassa kohdassa, (−1297, 887) ja (−1281, 839), vain 1,32 m. Koodaaja
     hioo keskilinjan pisteitä tai rantarajan kerrointa, kunnes
     hyväksymiskriteerit täyttyvät; luvut ovat lähtöarvoja.
   - `lake.json`iin uusi avain, esim. `channels`: [{id, dock: "kota", depth,
     points: [[x, z], …]}] maailman koordinaatteina, jotta peli ja testi
     tietävät väylän. `LakeData.load_from` lukee sen (`channels`-taulukko).
   - Rakennus ajetaan työkopiossa raakadatalla pääkansiosta:
     `python3 tools/build_lake.py --mml ~/projektit/catchfish/data/mml`.
     Vain `heights.bin`, `map.png` ja `lake.json` (uusi avain) saavat
     muuttua. `water.bin`, `ground.bin`, `shore.bin` ja `fetch.bin` eivät
     muutu, joten `build_fetch.py`:tä ei tarvitse ajaa.
2. **Vieraat moottoriveneet** (`scripts/boat/other_boats.gd`):
   - `MOTOR_DOCKS`-rajaus pois tai kota mukaan: moottorivene saa käyttää
     laituria, jolla on väylä tai jonka lähtöpisteestä pääsee syvään veteen.
   - Kodan väylä on kapea (keskilinja 9–16 m rannasta), joten nykyinen
     ruudukko (`SHORE_CLEARANCE` 15 m, 8 m ruudut, ruudun matalin kohta
     ≥ 1,3 m) ei päästä moottorivenettä sen läpi. Suositus: kodan laiturin
     moottorivenereitti kulkee väylän keskilinjaa pitkin. Lähtöpiste
     (`_exits[MOTOR][kota]`) on väylän pää, ja `dock_route` ja `send_home`
     lisäävät väylän pisteet laiturin ja lähtöpisteen väliin (samaan tapaan
     kuin `_berth_path`). Vaihtoehto koodaajan harkintaan: väylän ruudut
     omana luokkanaan ruudukossa (kulkukelpoinen, paino kuten lähivedellä),
     jos se on yksinkertaisempi ja täyttää samat syvyyskriteerit.
   - Nopeus väylällä: Teemun päätös (kysymys 3). Hidas ajo hoituu
     `OtherBoat`issa samalla tavalla kuin nykyinen `in_approach`.
   - Soutuveneiden säännöt ennallaan.
3. **Dokumentit**: `docs/plan.md` (#68:n teksti "Kodan laiturilta on noin
   600 m matalaa vettä …" ja CATCHFISH-68-suunnitelman päätös 14 päivitetään
   viittaamaan väylään, uusi #101-kohta), `README.md` (Muut veneet: lause
   "kodan matalalta laiturilta lähtee vain soutuveneitä" pois; Vene:
   maininta kodan ruopatusta väylästä). F1-ohje ei muutu, ellei kysymyksen 2
   vastaus tuo karttaan uutta merkintää.
4. **Testit**:
   - Uusi headless-testi `tests/channel_test.gd`, lippu esim. `--channeltest`
     (`--day=180`):
     a) `lake.channels` sisältää kodan väylän; ensimmäinen piste ≤ 10 m
        kodan laituripaikasta, viimeinen syvässä vedessä (≥ 1,5 m, rantaan
        ≥ 15 m);
     b) `depth_at` keskilinjalla 1 m välein ≥ 1,4 m, ±3 m sivuilla ≥ 1,3 m ja
        ±5 m sivuilla ≥ 1,0 m;
     c) pohjassa ei pystyseinää: väylän ±15 m alueella vierekkäisten
        vesisolujen korkeusero enintään 0,8 m (kaltevuus ≤ 0,2);
     d) pelaajan vene kodan laiturista väylän läpi moottorilla täydellä
        kaasulla (paikka ja suunta asetetaan keskilinjaa pitkin joka
        fysiikka-askeleella, kuten `prop_test` ohjaa venettä): ei
        `prop_strike`-ääntä, ei "Potkuri osui"- eikä "Matalaa"-viestiä,
        `prop_damage` = 0;
     e) laituripaikka ennallaan: `starts[0]` x = −1314, z = 990,
        yaw_deg = 41,2, dock_length = 14.
   - `tests/other_boats_test.gd`: rivin 171 tarkistus "uimalaituri ja
     veneenlasku, ei kotaa" muutetaan muotoon "kaikki kolme laituria"; uusi
     osio: moottorivene kodalta toiselle laiturille ja toiselta kodalle
     `_follow`-apufunktiolla, rungon matalin kohta ≥ `Boat.PROP_DEPTH`
     (1,0 m) koko matkalla ja perillä annetussa ajassa.
   - Kaikki nykyiset testit läpi (`tools/run_tests.sh -q`). Monet testit
     alkavat kodan laiturilta (`lure_test`, `bait_test`, `cast_test`,
     `line_test`, `troll_test`, `pike_follow_test` …); jos jokin niistä
     riippuu vanhasta syvyydestä, koodaaja kysyy työnjohtajalta ennen kuin
     muuttaa testin odotuksia.
   - Kuvat designerille (ikkuna, näytönohjain): uusi `--channelshots=KANSIO`
     tai vastaava: veneen kamerasta laiturilta väylää kohti, väylän kahdesta
     kapeasta kohdasta (−1297, 887) ja (−1281, 839) eteen ja taakse, lammen
     kohdalta ja väylän päästä, sekä karttanäkymä. Lisäksi
     `--screenshots=KANSIO` (kodan laituri).

## Hyväksymiskriteerit
- [ ] `heights.bin` muuttuu vain kodan väylän alueella: tarkistetaan
      vertaamalla `origin/main`iin, kaikki muuttuneet solut ovat alle 15 m
      keskilinjasta ja vain syvenevät (ei yhtään matalammaksi muuttunutta
      solua).
- [ ] `water.bin`, `ground.bin`, `shore.bin`, `fetch.bin` ja `ripples.bin`
      ovat tavu tavulta ennallaan; `lake.json`:n `starts`, `rocks`,
      `places`, `buildings` ja `towers` ennallaan.
- [ ] `build_lake.py --mml` tuottaa tämän haaran `assets/lake/`-tiedostot
      tavu tavulta samoina (toistettavuus säilyy).
- [ ] Väylän keskilinjalla syvyys ≥ 1,4 m koko matkalla laituripaikasta
      asti; 10 m:stä laiturista alkaen ±3 m ≥ 1,3 m ja ±5 m ≥ 1,0 m (päätös 7);
      väylän pohja 1,5 m (keskilinjan keskisyvyys 1,45–1,55 m).
- [ ] Laituripaikassa syvyys ≥ 1,4 m; veneen perän (potkurin) kohdalla
      ≥ 1,0 m marginaalilla (testissä ≥ 1,02 m) laiturissa ja koko matkan
      (päätökset 6 ja 7).
- [ ] Pelaaja ajaa kodan laiturilta väylän päähän täydellä kaasulla ilman
      potkurin pohjakosketusta; laiturin lähtöhetkellä kerran tuleva matalan
      varoitus sallitaan, väylällä (10 m:stä laiturista) ei (`--channeltest`).
- [ ] Ei pystyseinää: väylän alueella pohjan kaltevuus ≤ 0,2 (vierekkäisten
      vesisolujen syvyysero ≤ 0,8 m, päätös 8).
- [ ] Rantatörmä ennallaan: vesisolut, joista on rantaan ≤ 4 m, eivät muutu.
      Kaislikkokelpoisia vesisoluja kodan lahdella vähintään 90 % entisestä.
- [ ] Vieraiden moottoriveneiden laitureissa on kota; moottorivene ajaa
      kodalta toiselle laiturille ja takaisin, rungon alla ≥ 1,0 m koko
      matkan (toisen laiturin matalaa lähivettä lukuun ottamatta), ei
      laiturin kannen alle, ja kodalla kiinnitys kannen länsipuolelle
      (päätös 9) (`--otherboatstest`).
- [ ] Soutuveneet lähtevät kodalta ja palaavat kuten ennen
      (`--otherboatstest`).
- [ ] Kaikki testit läpi (`tools/run_tests.sh -q`).
- [ ] Designerin kuvatarkistus: väylä on liukuvareunainen tummempi kaista,
      ei terävää rajaa, portaita eikä suoraa kaukaloa; laiturin tolpat ja
      kaislikko näyttävät luonnollisilta; kartalla väylä näkyy.
- [ ] `docs/plan.md`, CATCHFISH-68-suunnitelman päätös 14 ja `README.md`
      päivitetty.

## Avoimet kysymykset Teemulle
1. **Väylän leveys.**
   a) Noin 10 m tasapohja 1,5 m:ssä ja 8 m:n loivat reunat (tämä
      suunnitelma; ≥ 1,3 m syvää 7–16 m, ≥ 1,0 m 11–25 m).
   b) Kapeampi, noin 6 m pohja: vähemmän muutosta maastoon, mutta pelaajan
      pitää ajaa tarkasti, ja ≥ 1,3 m:n kaista on paikoin vain noin 5 m.
   c) Koko lahti ruopataan rannasta rantaan 1,5 m:iin (vain törmä jää):
      helppo ajaa, mutta lahden pohja muuttuu kauttaaltaan ja reunan
      kaislikkoa voi hävitä enemmän.
   *Suositus: a.*
2. **Merkitäänkö väylä?**
   a) Ei merkintää: väylä näkyy kartalla hennosti syvyysvärinä, ja
      kaikuluotain ja matalan varoitus ohjaavat.
   b) Kartalle väylän keskilinja ohuena katkoviivana (kuten verkkojen
      linjat kartalla, `lake_map.gd`).
   c) Lisäksi vedessä väylämerkit (esim. ohuet viittakepit 50–80 m välein
      väylän reunoilla): eniten apua, mutta uusi malli ja enemmän työtä.
   *Suositus: b tässä tehtävässä, c tarvittaessa omaksi tehtäväkseen
   backlogiin.*
3. **Vieraan moottoriveneen nopeus väylällä.**
   a) Hitaasti (1,5 m/s, kuten laiturin lähivedessä) koko väylä, noin
      6 min: ei peräaaltoa kapeassa lahdessa, uskottava luontokohteen
      lähellä, helppo kohdata.
   b) Hitaasti 120 m laiturista (kuten muilla laitureilla), sen jälkeen
      matkanopeus 4,4 m/s: väylä noin 2,5 min, peräaalto keinuttaa
      pelaajaa kapeassa lahdessa.
   c) Välinopeus noin 3 m/s.
   *Suositus: a.*
4. **Ruopataanko data vai pelin käynnistyksessä?** (työnjohtaja voi
   ratkaista)
   a) `build_lake.py` tekee väylän `heights.bin`:iin ja karttaan (tämä
      suunnitelma): yksi totuus kaikille järjestelmille, kartta näyttää
      väylän, rakennus on todetusti toistettava.
   b) Pelin käynnistyksessä `LakeData`ssa väylän pisteistä, kuten
      veneenlaskuluiska muotoillaan nyt (`LakeWorld._carve_ramps`): ei
      binäärimuutosta, mutta kartta ei näytä väylää ja kaikki `LakeData`a
      käyttävät testit saavat väylän vain, jos muotoilu tehdään
      `load_from`issa.
   *Suositus: a.*

## Päätökset
1. Leveys: a) noin 10 m tasapohja 1,5 m:ssä ja 8 m:n loivat reunat (Teemu).
2. Merkintä: a) ei merkintää. Väylä näkyy vain kartan syvyysvärissä; ei
   katkoviivaa eikä viittakeppejä, F1-ohje ei muutu (Teemu).
3. Vieraan moottoriveneen nopeus: a) 1,5 m/s koko väylän matkan (Teemu).
4. Ruoppaus tehdään datassa: a) `build_lake.py` → `heights.bin`, `map.png`,
   `lake.json` (`channels`) (työnjohtaja: yksi totuus kaikille
   järjestelmille, rakennus todetusti toistettava).
5. Vieraiden veneiden reitti kodalle väylän keskilinjaa pitkin (suositus)
   tai väyläruudut ruudukkoon: koodaaja valitsee yksinkertaisemman, kunhan
   hyväksymiskriteerit täyttyvät (työnjohtaja).
6. Rantatörmä pysyy kokonaan ennallaan myös laiturin kohdalla (vaihtoehto B).
   Laituripaikka on 8 m rannasta, joten perän alla laiturissa on noin
   1,07 m: kaasua antaessa tulee kerran "Matalaa"-varoitus, mutta potkuri ei
   osu. Kriteeri: perän kohdalla ≥ 1,0 m, laituripaikassa ≥ 1,4 m (Teemu).
7. Päätöksestä 6 seuraa: ±3/±5 m -kriteerit mitataan vasta 10 m
   laiturista, keskilinjalla ≥ 1,4 m koko matkan laituripaikasta asti, perän
   ja potkurin kohdalla ≥ 1,0 m marginaalilla (ei pyöristettynä), laiturissa
   kerran tuleva matalan varoitus sallitaan, väylällä ei (työnjohtaja).
8. Rantarajan kaava (0,8 + 0,175 × (rantaetäisyys − 4)) korvataan ehdolla
   "vierekkäisten vesisolujen syvyysero ≤ 0,8 m" (kaltevuus ≤ 0,2), koska
   kaava teki törmän viereen 0,9 m:n portaan. Keskilinja hiotaan 37
   pisteeseen noin 15 m välein. Kaislikkokelpoisia lahdella noin 91 %
   entisestä riittää (työnjohtaja).
9. Kodalla kaikki vieraat veneet (moottori- ja soutuveneet) kiinnittyvät
   kannen länsipuolelle, pelaajan aloituspaikan vastapuolelle: itäpuolen
   paikka on kapeassa taskussa, johon moottorivene ei käänny väylältä ja
   jossa soutuvene hipaisi kannen kulmaa (Teemu).
