# CATCHFISH-68: Muita veneitä järvellä

## Tavoite
Järvi tuntuu elävältä: silloin tällöin joku muu kalastaja ajaa moottoriveneellä
ohi tai soutaa kalapaikalle. Ohi ajavan moottoriveneen peräaallot saapuvat
pelaajan veneeseen ja keinuttavat sitä. Muiden veneiden läpi ei pääse: niihin
voi törmätä kuten laituriin.

## Toiminta pelaajan kannalta

### Milloin veneitä on
- Vain avovesikaudella. Jäätalvena (`boat.on_ice`) ei veneitä.
- Vain valoisaan aikaan: `sky.daylight() > 0.45` (sama raja kuin metsän
  pikkulinnuilla `game_audio.gd`:ssä). Hämärän tullen järvellä olevat veneet
  palaavat laiturille, uusia ei tule.
- Kovalla tuulella ja sateella ei lähdetä: ks. avoin kysymys 4.
- Järvellä on kerrallaan enintään 2 vierasta venettä (avoin kysymys 3).
- Ensimmäinen vene ilmestyy 2–6 min pelin alusta, sen jälkeen uusi aikaisintaan
  4–12 min edellisen jälkeen (todellista aikaa, ei peliaikaa, jotta ajan
  nopeutus T:llä ei täytä järveä veneillä). Luvut ovat ehdotus: avoin kysymys 3.
- Kertakalastus ja uramoodi toimivat samoin. Mitään ei tallenneta.

### Veneet ja niiden liike
Kaksi tyyppiä (osuudet: avoin kysymys 3):

1. **Moottorivene, ohiajo.** Lähtee laiturilta (ks. alla) ja ajaa toiselle
   laiturille tai kalapaikalle järven toisella puolella. Matkanopeus noin
   4,4 m/s (16 km/h): sama perämoottori ja vastusmalli kuin pelaajan veneessä
   (`Boat.MOTOR_THRUST` 420 N, vastus `13 v² + 10 v`) 70 %:n kaasulla. Huippu
   pelaajan veneellä on noin 5,3 m/s, joten pelaaja pysyy perässä
   täysillä ajaen. Laiturin lähellä ja käännöksissä hiljentää noin 1,5 m/s:iin.
   Noin puolet ohiajoista valitaan reitiksi, joka kulkee 30–80 m:n päästä
   pelaajasta, jotta peräaallot oikeasti tavoittavat pelaajan (muuten ominaisuus
   jää harvoin huomatuksi). Ks. avoin kysymys 5.
2. **Soutuvene, kalastaja.** Soutaa laiturilta 100–400 m:n päähän
   kalapaikalle noin 1,5 m/s (pelaajan soutuvauhti: `ROW_FORCE` ja sama vastus),
   pysähtyy, laskee ankkurin ja "kalastaa" 5–15 min (istuu, vapa ulkona), ja
   soutaa takaisin laiturille. Soutuveneen vana on pieni eikä keinuta pelaajaa
   juuri lainkaan.

**Lähtö- ja tulopaikat.** Järven kolme laituria/luiskaa (`lake.starts`:
kota, uimalaituri, veneenlasku). Vene ilmestyy laiturin viereen vain, jos
pelaaja on yli 250 m:n päässä siitä, ja katoaa laiturilla, kun pelaaja on yli
250 m:n päässä tai laituri ei ole kameran näkökentässä. Näin pelaaja ei näe
veneen ilmestyvän tyhjästä. (Vaihtoehdot: avoin kysymys 6.)

**Reitit.** Reitti haetaan järven ruudukosta (A*):
- moottorivene vain vähintään 1,3 m:n syvyydessä (`Boat.SHALLOW_WARNING`,
  potkuri osuu pohjaan alle 1,0 m:ssä), soutuvene vähintään 0,6 m:ssä
  (2 × `Boat.DRAFT`); laiturin ja syvän veden välinen pätkä ajetaan hitaasti
- vähintään 15 m rannasta ja saarista paitsi laiturille tullessa
- laitureiden kannet kierretään (`lake.docks`), samoin pelaajan verkkojen
  pyykit vähintään 10 m:n päästä (`NetControl.nets`).

**Väistäminen.** Vieras vene ei aja tahallaan pelaajan päälle:
- Jos pelaaja on reitillä, vene kiertää hänet vähintään 15 m:n etäisyydeltä
  (moottorivene) tai 6 m:n (soutuvene).
- Jos pelaaja tulee alle 10 m:n päähän, vene hiljentää ja kääntyy poispäin;
  alle 4 m:ssä se pysähtyy (moottori vapaalle) ja jatkaa, kun tilaa on.
- Etäisyydet ovat ehdotuksia; testaaja ja Teemu kokeilevat.

### Peräaallot
- Moottoriveneen perään jää sama perävana kuin pelaajan veneellä
  (`Wake`: kulku-uoma ja Kelvinin aallot 19,5°:n kulmassa sivuille).
- Kun Kelvinin aaltojen "V:n" haara saavuttaa pelaajan veneen, vene keinuu
  aaltojakson ajan: noin 4–5 aallonharjaa, jakso
  `T = sqrt(2π λ / g)`, missä aallonpituus riippuu ohiajavan veneen nopeudesta
  (`λ ≈ 0,67 · 2π v² / g`, Kelvinin hajaantuvat aallot noin 35°:ssa). Matkanopeudella
  4,4 m/s tämä antaa λ ≈ 8 m ja T ≈ 2,3 s, eli keinunta kestää noin 10 s.
- Korkeus pienenee etäisyyden mukaan (`d^(-1/3)`, Kelvinin hajaantuvien aaltojen
  vaimeneminen) ja ajan mukaan samaan tapaan kuin vaahto haalenee
  (`Wake.LIFETIME` 14 s). Hitaasti ajava (alle ~1,5 m/s) tai soutava vene ei
  tee keinuttavaa aaltoa.
- Aallon korkeus 20 m:n päässä matkanopeudella: ehdotus 0,15 m, säädettävä
  vakio. Tällä vene kallistuu sivuttain noin 6° kylki aaltoon päin
  (laskettu `Boat._animate`:n kaavasta: leveys 1,4 m, λ 8 m). Luku on arvio:
  avoin kysymys 2.
- Keinunta on suurempi, kun kylki on aaltoa kohti (vene kallistuu), ja
  pienempi, kun keula osoittaa aaltoon (vene nyökkää). Tämä tulee itsestään,
  kun aaltokorkeus luetaan samoista viidestä rungon pisteestä kuin aallokko.
- Peräaalto ei työnnä venettä eikä vaikuta kalastukseen; vapa ja kalastaja
  keinuvat rungon mukana (ne seuraavat jo `hull`-solmua). FPV-kamera keinuu
  samoin.
- Vesipinta itse ei nouse peräaallon kohdalla (ks. Ulkoasu ja avoin kysymys 1);
  aallon näkee vaahtojuovista ja veneen keinunnasta.

### Törmäys ("niitä ei voi ajaa päin")
Tulkinta: pelaajan vene ei mene vieraan veneen läpi, vaan törmää siihen kuten
laituriin (`Boat._dock_collision`). Avoin kysymys 7 vahvistaa tulkinnan.
- Molempien veneiden runko on sama ääriviiva (`Boat.OUTLINE`). Jos ääriviivat
  menevät päällekkäin, pelaajan vene työnnetään irti, toisiaan kohti oleva
  suhteellinen nopeus pysähtyy hieman kimmoten (kerroin 1,2 kuten laiturissa) ja
  kosketuskohdan isku kääntää venettä, jolloin veneet liukuvat toistensa ohi.
- Liikkuvan vieraan veneen massa on sama kuin pelaajan (`Boat.MASS`), joten se
  saa vastakkaisen iskun ja liikahtaa; ankkurissa kalastava soutuvene ei liiku
  (kuin laituri).
- Ääni ja viesti samoin rajoin kuin laituriin törmätessä: kolahdus
  (`boat_bump`) yli 0,4 m/s suhteellisella nopeudella, yli 1,0 m/s:ssa viesti
  "Kolahdus! Vene törmäsi toiseen veneeseen". Sama 3 s:n viive kuin laiturissa.
- Törmäyksen jälkeen vieras vene pysähtyy 3 s:ksi ja jatkaa sitten matkaansa
  poispäin pelaajasta.
- Vieraat veneet eivät törmää toisiinsa (ne väistävät toisiaan reitillä
  samoin kuin pelaajaa; ilmestymissäännöt pitävät ne erillään).
- Vieras vene ei katkaise pelaajan siimaa eikä sotkeudu verkkoon (ks. avoin
  kysymys 8).

## Ulkoasu ja äänet

### Vene ja kuljettaja
- Sama lasikuitusoutuvene ja perämoottori kuin pelaajalla (`Boat._build_hull`,
  `_build_motor`), eri värein, jotta vieraan veneen erottaa omasta:
  ehdotus kolme värimallia (avoin kysymys 9), esim. tummanvihreä runko,
  harmaa (alumiinin näköinen) ja valkoinen punaisella reunalistalla.
- Soutuveneessä airot liikkuvat samaa vetorytmiä kuin pelaajalla
  (`STROKE_TIME` 1,6 s); kalastaessa airot ovat veneessä ja vapa on ulkona.
- Kuljettajana sama hahmomalli (`assets/characters/adventurer.glb`)
  istumassa: moottoriveneessä perätuhdolla käsi ohjausaisalla, soutaessa
  keskituhdolla airoilla, kalastaessa keskituhdolla vapa kädessä. Vaatteet
  eri väriset kuin pelaajalla (esim. oranssi kelluntaliivi). Yksinkertaistettu
  asento riittää: kaukaa katsottuna erottuu ihminen veneessä.
- Vieras vene keinuu järven aallokossa samoin kuin pelaajan vene
  (`Waves.swell_height` viidestä pisteestä) lähivedessä (alle 120 m kamerasta);
  kauempana vesi on tasaista.
- Vettä ei piirretä vieraan veneen sisälle (nyt vesivarjostin piilottaa veden
  vain pelaajan veneen sisältä, `inside_boat` / `boat_pos`).

### Vana
- Moottoriveneen perään sama vaahtovana kuin pelaajan veneellä: kulku-uoma ja
  V-muotoiset sivuaallot, jotka leviävät ja haalenevat 14 s:ssa. Vaahtojuova
  näyttää, missä peräaalto on ja milloin se saapuu.
- Soutuveneestä airojen pyörteet kuten pelaajalla.

### Äänet
- Moottoriveneellä oma `motor_loop`-silmukka 3D-äänenä veneen mukana:
  kierrokset ja voimakkuus kaasun mukaan samalla kaavalla kuin pelaajan
  moottorissa. Kuuluu kauas (tyynellä järvellä perämoottori kuuluu satojen
  metrien päähän); kantama ehdotus 600 m. Käynnistysääni `motor_start`
  laiturilta lähtiessä.
- Soutuveneestä airoveto `oar_stroke` (ja `oar_catch`) joka vedolla
  `play_at`illa: kuuluu vain lähellä.
- Peräaallon saapuessa veneen kyljessä pärskyvä aaltoääni (`water_waves_loop`,
  `GameAudio._waves`) voimistuu aallon korkeuden mukaan. Ei uutta äänitiedostoa
  (avoin kysymys 10).
- Kaikki äänet näkyvät `--audio-log`-lokissa (`play_at` kirjaa itse;
  vieraan moottorin silmukka kirjataan `loop_start`/`loop_stop` -riveinä).

### HUD
- Ei uutta HUD-elementtiä. Ainoa viesti on törmäysviesti.
- Kartta (K) ja kaikuluotain: ei muutoksia (avoin kysymys 11).
- F1-ohjeeseen ei ohjausmuutoksia. README:n *Simulaatio lyhyesti* -osioon
  kappale muista veneistä (milloin liikkuvat, peräaallot, törmäys).

## Toteutus pääpiirteissään
- **Uusi `scripts/boat/other_boats.gd`** (hallinta, kuten `Birds`): ilmestymis-
  ja katoamissäännöt, reittihaku, enintään 2 venettä, `auto_spawn`-lippu
  testejä varten (kuten `Birds.auto_spawn`) ja `spawn(tyyppi, reitti)`-funktio
  testeille. Reittihakuun sopii Godotin `AStarGrid2D` karkeassa ruudukossa
  (esim. 8 m) järven syvyyksistä; rakennetaan kerran alussa. Mittaa
  latausajan muutos (`load_ms`, `--perftest`).
- **Uusi `scripts/boat/other_boat.gd`** (yksi vene): yksinkertaistettu fysiikka
  samoilla vakioilla kuin `Boat` (työntö, vastus, kääntö), ohjaus reittipisteeseen
  (ei `Input`-lukua), väistäminen, keinunta, oma `Wake`-solmu, moottori-/
  airoäänet. Rungon ja moottorin malli `Boat`:n rakennusfunktioista: ne
  kannattaa erottaa niin, että sama runko voidaan rakentaa eri värein ilman
  pelaajan veneen logiikkaa (esim. staattiset funktiot tai pieni
  `boat_model.gd`). Pelaajan veneen ulkonäkö ei saa muuttua.
- **Peräaaltojen korkeus:** yksi funktio, esim. `OtherBoats.wake_height(p)`,
  joka laskee kohdassa p kaikkien moottoriveneiden vanojen yhteisen korkeuden
  vananäytteiden historiasta (sama näytteistys kuin `Wake.track`).
  `Boat._animate` lisää sen viiteen pisteeseen `Waves.swell_height`in päälle.
  `Waves.swell_height`iin ei lisätä peräaaltoja (koho, pyykit ja ankkuri
  pysyvät nykyisellään, vesipinta ei näytä peräaaltoa).
- **Törmäys:** `boat.gd`:n laiturikosketuksen rinnalle kosketus vieraisiin
  veneisiin (ääriviiva vastaan ääriviiva: kummankin kulmat toisen sisällä,
  kuten `_dock_push` laiturin kulmille). Suhteellinen nopeus ja vastaisku
  vieraalle veneelle.
- **`shaders/waves.gdshaderinc`:** `inside_boat` tarkistaa myös vieraat
  veneet (pieni taulukko sijainteja ja suuntia, enintään 2). Koskee vesi- ja
  vanavarjostimia. Huomio selaimen (WebGL) uniform-rajoihin: pieni taulukko riittää.
- **`scripts/main.gd`:** `OtherBoats` luodaan avovesikaudella `Birds`in
  tapaan, äänet kytketään `audio.play_at`iin, vieraiden vanojen materiaaleille
  `Waves.apply` ja veneiden sijainnit varjostimiin `_process`issa. Testin
  käynnistys `--otherboatstest` ja kuvaskripti `--otherboatshots=`.
- **`scripts/audio/game_audio.gd`:** aaltoäänen voimistus peräaallon
  korkeuden mukaan; vieraiden moottorien silmukoiden lokirivit.
- **Dokumentit:** README (*Simulaatio lyhyesti*, *Testit*), `docs/plan.md`
  (*Testaus*-lista, arkkitehtuuritaulukkoon rivi), `tools/run_tests.sh`-lista.

### Testi `--otherboatstest` (headless)
`OtherBoats.auto_spawn = false`, sää tyyni (tuuli 0, ei aallokkoa), vene
syvässä vedessä paikallaan, linnut pois (kuten `voice_test.gd`).
1. **Reitti:** moottorivene laiturilta toiselle laiturille: joka fysiikka-
   askeleella syvyys rungon kohdalla ≥ 1,0 m syvässä osuudessa (potkuri ei osu
   pohjaan), ei maalla eikä laiturin kannen alla, perillä aikarajassa.
   Soutuvene vastaavasti ≥ 0,3 m.
2. **Peräaalto:** moottorivene ajaa matkanopeudella pelaajan ohi 20 m:n
   päästä kylki vanaan päin. Ennen vanan saapumista `hull.rotation.z` < 0,2°;
   keinunta alkaa vasta, kun Kelvinin haara on ehtinyt pelaajan kohdalle
   (ei ennen kuin vieras vene on ohittanut pelaajan sivusuunnassa);
   suurin kallistus yli 2°; 30 s:n kuluttua alle 0,2°.
3. **Etäisyys ja nopeus:** sama ohiajo 60 m:n päästä keinuttaa vähemmän kuin
   20 m:n; soutuveneen ohitus 10 m:n päästä alle 0,5°.
4. **Törmäys:** pelaaja ajaa täydellä kaasulla pysähtyneen vieraan veneen
   kylkeen, keulaan ja viistosti: ääriviivat eivät mene päällekkäin yli 0,1 m,
   `boat_bump` kuuluu, viesti tulee, pelaajan nopeus kohti vierasta venettä
   pysähtyy, ja viistossa veneet liukuvat ohi. Ankkurissa oleva soutuvene ei
   liiku törmäyksestä.
5. **Väistö:** pelaaja paikallaan moottoriveneen reitillä: vieras vene ohittaa
   vähintään 15 m:n päästä eikä törmää.
6. **Ehdot:** `--day=40` (jää) ja yö (klo 1, `daylight() ≤ 0,45`):
   `auto_spawn = true` ja nopeutettu ajastin → ei yhtään venettä.
   Päivällä enintään 2 venettä kerrallaan.
7. **Ääni:** liikkuvan moottoriveneen moottorisilmukka soi; `--audio-log`
   kirjaa sen.

### Kuvaskripti `--otherboatshots=KANSIO` (ikkuna)
Designerin tarkistukseen: 1) vieras moottorivene sivulta lähietäisyydeltä,
2) soutuvene airoineen, 3) moottoriveneen ohiajo pelaajan veneestä katsottuna
vanan V:n kanssa, 4) pelaajan vene peräaallossa kallistuneena (normaali kamera
ja FPV), 5) vieraan veneen sisäpuoli ylhäältä: ei vettä sisällä, 6) vene
laiturilla.

## Hyväksymiskriteerit
- [ ] Kesäpäivänä järvelle ilmestyy vieraita veneitä: ensimmäinen
      2–6 min alusta, enintään 2 kerrallaan, moottori- ja soutuveneitä.
- [ ] Talvella (jää) ja yöllä ei vieraita veneitä; hämärtyessä veneet palaavat.
- [ ] Veneet ilmestyvät ja katoavat laitureilla vain, kun pelaaja on yli 250 m
      päässä tai ei katso laituria kohti.
- [ ] Moottorivene ei aja alle 1,3 m:n veteen (laiturin lähiosuutta lukuun
      ottamatta), maalle, rantaan eikä laiturin läpi; soutuvene ei matalikolle.
- [ ] Vieras vene väistää pelaajaa (≥ 15 m moottorilla, ≥ 6 m soutaen) ja
      pelaajan verkkojen pyykkejä (≥ 10 m).
- [ ] Moottoriveneen perään jää vaahtovana kuten pelaajan veneellä.
- [ ] Peräaalto keinuttaa pelaajan venettä vasta, kun vanan V-haara saapuu,
      noin 4–5 aallon ajan; kylki aaltoon keinuu enemmän kuin keula aaltoon;
      kauempana ja hitaammasta veneestä vähemmän; soutuvene ei keinuta.
- [ ] Peräaalto ei siirrä pelaajan venettä eikä vaikuta kohoon tai verkkoon.
- [ ] Vieraan veneen läpi ei pääse: törmäyksessä kolahdus ja viesti
      "Kolahdus! Vene törmäsi toiseen veneeseen", veneet liukuvat ohi, eivät
      jää kiinni toisiinsa.
- [ ] Vieraan veneen sisällä ei näy vettä; vieras vene keinuu aallokossa.
- [ ] Vieras vene erottuu väreiltään pelaajan veneestä; kuljettaja näkyy.
- [ ] Moottoriveneen ääni kuuluu ja voimistuu lähestyessä; soutuveneen
      airovedot kuuluvat lähellä; peräaallossa aaltoääni voimistuu.
- [ ] Pelaajan veneen ulkonäkö, ohjaus ja laiturikosketus ennallaan
      (`--docktest`, `--boattest`, `--synctest` ym. läpi).
- [ ] `--otherboatstest` läpi, `--perftest` ei heikkene merkittävästi, uusi
      testi `tools/run_tests.sh`-listassa.
- [ ] README ja `docs/plan.md` päivitetty.
- [ ] Designer on tarkistanut `--otherboatshots`-kuvat.

## Päätökset (hyväksytty 2026-10-29)

Teemu valitsi kohdat 1, 3, 7 ja 9; muut työnjohtaja ratkaisi suosituksen mukaan.

1. Peräaalto näkyy vain vaahtovanana ja oman veneen keinuntana; varjostimen
   pinnan aaltomuoto on oma tehtävänsä (Teemu).
2. Peräaallon korkeus 0,15 m 20 m:n päässä matkanopeudella; säädetään
   kokeilun jälkeen (työnjohtaja).
3. Enintään 2 venettä kerrallaan, väli 4–12 min, moottori/soutu 60/40;
   ei vuodenaika- tai viikonloppuvaihtelua (Teemu).
4. Ei uusia veneitä yli 8 m/s tuulella tai rankkasateella (`rain` > 0,5) (työnjohtaja).
5. Noin puolet moottoriveneiden reiteistä kulkee 30–80 m:n päästä pelaajasta (työnjohtaja).
6. Ilmestyminen laitureille kaukana tai näkymättömissä, ja yksi vene voi
   olla järvellä jo pelin alussa (työnjohtaja).
7. Törmäys kuten laituriin (kolahdus, ei läpi), ja tekoäly väistää pelaajaa (Teemu).
8. Vieras vene ei katkaise siimaa eikä aja verkon yli; pyykit kierretään (työnjohtaja).
9. Sama runkomalli eri värein, kuljettajalla oranssi kelluntaliivi (Teemu).
10. Peräaallon ääneksi voimistuu nykyinen aaltoääni (työnjohtaja).
11. Vieraat veneet eivät näy kartalla (työnjohtaja).
12. Ei uutta kalastajan repliikkiä (työnjohtaja).
13. Moottorivene ei säikytä kaloja (työnjohtaja).
14. Kodan laiturilta on noin 600 m matalaa vettä, joten moottoriveneet
    käyttävät vain uimalaituria ja veneenlaskupaikkaa; kodalta kulkevat vain
    soutuveneet (työnjohtaja).
15. Soutuveneille kapea vesi (syvyys ≥ 0,6 m, rantaan ≥ 6 m) on kulkukelpoinen,
    mutta reittihaku välttää sitä painolla 4, jotta soutuvene pääsee kodan
    lahdesta järvelle. Kalapaikat pysyvät ≥ 15 m rannasta, moottoriveneisiin
    ei muutosta. Kodan väylä syvennetään erikseen (CATCHFISH-101) (työnjohtaja).

## Avoimet kysymykset Teemulle (ratkaistu, ks. Päätökset)
1. **Näkyykö peräaalto vesipinnassa?** a) Vain vaahtojuovat ja veneen
   keinunta (kevyt, tämä suunnitelma); b) lisäksi lähiveden pinta nousee
   peräaallon kohdalla varjostimessa (näyttävämpi, raskaampi, voi rasittaa
   selainversiota #75). *Suositus: a nyt, b tarvittaessa omana tehtävänään.*
2. **Peräaallon voimakkuus:** ehdotus 0,15 m 20 m:n päässä matkanopeudella
   (kallistus noin 6°). a) 0,10 m (hillitty), b) 0,15 m, c) 0,25 m (selvästi
   tuntuva). *Suositus: b, säädetään kokeilun jälkeen.*
3. **Kuinka paljon veneitä:** enintään a) 1, b) 2, c) 3 kerrallaan; väli
   4–12 min; moottori-/soutuveneiden osuus esim. 60/40. *Suositus: 2, 4–12 min,
   60/40.* Lisäksi: onko järvellä viikonloppuisin tai kesä-heinäkuussa
   enemmän veneitä kuin keväällä ja syksyllä? *Suositus: ei tässä tehtävässä.*
4. **Sää:** a) ei uusia veneitä yli 8 m/s tuulella tai rankkasateella
   (`rain` > 0,5), b) sää ei vaikuta. *Suositus: a.*
5. **Ohiajot pelaajan läheltä:** noin puolet moottoriveneiden reiteistä
   kulkee 30–80 m:n päästä pelaajasta, jotta peräaallot tuntuvat. a) näin,
   b) reitit satunnaisia (peräaalto harvinainen), c) lähes kaikki ohittavat
   pelaajan. *Suositus: a.*
6. **Ilmestyminen:** a) laitureilla, kun pelaaja on kaukana tai ei katso
   (tämä suunnitelma); b) lisäksi yksi vene voi olla jo järvellä pelin
   alussa; c) veneet ilmestyvät suoraan järvelle kauas näkyvistä.
   *Suositus: a + b.*
7. **"Niitä ei voi ajaa päin" -tulkinta:** a) törmäys kuten laituriin:
   kolahdus, veneet eivät mene läpi (tämä suunnitelma); b) peli estää
   pääsyn lähelle näkymättömällä puskurilla ilman kolahdusta; c) jokin muu
   (esim. törmäyksestä seuraus: potkurivaurio, uramoodissa sakko?).
   *Suositus: a ja tekoäly väistää.*
8. **Siimat ja verkot:** voiko ohi ajava vene katkaista pelaajan siiman
   (uistelu) tai ajaa verkon yli? *Suositus: ei tässä tehtävässä; veneet
   kiertävät pyykit.*
9. **Veneiden ulkonäkö:** a) sama runkomalli kuin pelaajalla eri värein
   (tämä suunnitelma; ehdotus tummanvihreä, harmaa, valkoinen/punainen lista);
   b) erilainen malli, esim. alumiinivene tai puuvene (enemmän työtä).
   Kuljettajalle kelluntaliivi? *Suositus: a ja oranssi kelluntaliivi.*
10. **Peräaallon ääni:** a) olemassa oleva aaltoääni voimistuu (tämä
    suunnitelma); b) uusi kertaääni "läiskähdys" laitaan jokaisesta harjasta
    (`tools/make_sounds.py`). *Suositus: a, b myöhemmin, jos jää laimeaksi.*
11. **Kartta (K):** näytetäänkö vieraat veneet kartalla? *Suositus: ei
    (kartta näyttää vain oman paikan).*
12. **Kalastajan repliikki:** huudahtaako pelaajan kalastaja kovassa
    peräaallossa tai törmäyksessä (uusi puherepliikki `angler_voice.gd`:hen,
    vaatii puheen generoinnin)? *Suositus: ei tässä tehtävässä.*
13. **Vieraiden veneiden vaikutus kaloihin:** säikyttääkö ohi ajava
    moottorivene kaloja (tärppien väheneminen hetkeksi)? *Suositus: ei tässä
    tehtävässä.*
