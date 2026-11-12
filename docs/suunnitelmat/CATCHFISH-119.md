# CATCHFISH-119: Koukussa oleva kala lentää ilmassa veneen vieressä

## Tavoite
Koukussa oleva kala pysyy väsytyksen ajan aina vedessä. Kun kalan kelaa veneen
viereen, se jää pintaan laidan ulkopuolelle odottamaan haavia, eikä nouse
siiman mukana ilmaan vavan kärkeen roikkumaan.

## Juurisyy

### Todennettu (headless-toisto + GPU-kuvat, origin/main v0.57.0)

**Kireä siima vetää kalaa suoraan kohti vavan kärkeä, eikä kalan korkeutta
rajata mihinkään.** `scripts/fishing/fishing.gd`, `_fight()`:

- rivi 1471: `_fish_pos = anchor + (_fish_pos - anchor).normalized() * (line_out - tip_to_anchor)`.
  Avovedessä `anchor` on vavan kärki (rivi 1436), joka on väsytyksessä
  2,1–2,4 m vedenpinnan yläpuolella (mitattu). Kala siirretään siis 3D-suoraa
  pitkin kärkeä kohti, myös ylöspäin.
- rivi 1472: siiman alaraja avovedessä on 0,5 m, eli kalan saa kelattua
  puolen metrin päähän kärjestä, noin 1,9 m korkeuteen.
- rivi 1434: ainoa korkeuteen vaikuttava sääntö on hidas hakeutuminen
  tavoitesyvyyteen (0,5 m/s) *ennen* siiman vetoa. Kun siima on jyrkkä,
  kelaus (0,85 tai 1,6 m/s) nostaa kalaa nopeammin kuin se ehtii vajota.
  Missään ei ole ehtoa "kala ei nouse pinnan yli".
- rivi 1799: kalan malli piirretään suoraan kohtaan `_fish_pos`, joten virhe
  näkyy sellaisenaan (kala vaakasuorassa uimassa ilmassa).
- rivi 1519: haavintakehote vaatii `line_out < 3.2 and _fish_pos.y > -1.2`.
  Ilmassa oleva kala täyttää ehdon, joten peli ei huomaa mitään.

Vika on ollut pelissä versiosta 0.1.0 asti (rivi 1471 on alkuperäinen,
`git log -S`). Se näkyy aina, kun pelaaja kelaa kalaa, joka ei juuri sillä
hetkellä ryntää (jarru ei luista): ei siis vain hauella vaan kaikilla lajeilla,
kuten tehtävän kuvaus sanoo.

Mittaukset (vene paikallaan, jarru 3,0 kg, kala 8 m päässä 0,5 m syvyydessä,
pelaaja pitää kelausta pohjassa 20 s, 30 fps):

| Tilanne | Kala pinnan yläpuolella | Suurin korkeus |
|---|---|---|
| Väsynyt hauki 3 kg, kelaus | alkaen 6,4 s (siimaa 5,8 m) | +1,94 m (siimaa 0,5 m) |
| Väsynyt hauki 3 kg, nopea kelaus | alkaen 3,3 s | +1,99 m |
| Pirteä ahven 0,2 kg, kelaus | alkaen 7,9 s | +1,80 m |
| Pirteä hauki 3 kg, kelaus | alkaen 5,4 s | +2,02 m |
| Hauki sivulla / keulassa / perässä, ahven vasemmalla | kaikissa | +1,8…+2,0 m |

- Kala on ilmassa jo ennen haavintakehotetta: kun kehote syttyy (siimaa
  3,1 m), kala on +0,8 m korkeudella.
- Kun kala on perän takana, vavan kärki on rungon päällä (rungon
  koordinaateissa x 0,24, z 1,52; puolileveys 0,70), joten kala roikkuu veneen
  sisäpuolella ilmassa.
- Ilman kelausta kala pysyy 0,3 m syvyydessä (ei vikaa).

Kuvat (D3D12 / RTX 4050, 1280 × 720): hauki vaakasuorassa ilmassa vavan
kärjessä, HUD:ssa "Hauki koukussa! Siimaa 0.4 m" ja haavintakehote:
`/tmp/claude-1000/-home-teekar-projektit-catchfish/eef29393-b63a-4a69-a6ed-4ae3f79071b3/scratchpad/shots/A_sivu_takaa.png`
ja `A_sivu_sivulta.png`. Toistoskripti (ei kuulu peliin, koodaaja voi käyttää
mallina):
`/tmp/claude-1000/-home-teekar-projektit-catchfish/eef29393-b63a-4a69-a6ed-4ae3f79071b3/scratchpad/fly_repro.gd`
(kytketty kopion `main.gd`:hen lipulla `--flyrepro`, kopio samassa kansiossa
`copy/`), lokit `repro.log`, `repro2.log`.

### Todennettu: vene vetää kalaa (uistelu ja ajo kala koukussa)

Sama rivi 1471 nostaa kalaa ilman kelaustakin, kun vene liikkuu kalasta
poispäin ja kalan veto jää alle jarrun (jarru ei luista). Mitattu: kala 15 m
perässä, voimat 0,25, ei kelausta, jarru 3,0 kg, veneen paikkaa siirretty
testissä tasaisella nopeudella (ei moottorin ohjauksella):

| Tilanne | Kala pinnan yläpuolella | Suurin korkeus |
|---|---|---|
| Ahven 0,3 kg, vene 4 m/s (14 km/h) | alkaen 2,9 s | +1,19 m 15 s kohdalla, nousee yhä |
| Hauki 1,5 kg, vene 7,5 m/s (27 km/h) | alkaen 0,6 s | +1,79 m |
| Ahven 0,3 kg, soutuvauhti 1,2 m/s | ei koskaan | −0,29 m |

Kala lentää tällöin 15 m veneen perässä, ei veneen vieressä, joten otsikon
tilanne ("veneen vieressä") on todennäköisimmin kelaus veneen viereen.
Soutuvauhtisessa uistelussa veto ei nosta kalaa; uistelun tärpin jälkeen
vapa otetaan käteen ja kala kelataan sisään samaa `_fight()`-polkua, eli
vika näkyy uistelussa täsmälleen kuten heitossa. Telineessä olevaa vapaa ei
voi kelata (`_reel_speed`, rivi 999), joten telinevavan kala nousee vain
veneen vetämänä. Loki: `repro4.log` samassa scratch-kansiossa.

### Hypoteesi (ei todennettu, sama korjaus kattaa)

**Aallonpohja paljastaa kalan.** Väsyneen kalan tavoitesyvyys on kiinteä
0,3 m lepopinnasta (rivi 1433), ei aaltopinnasta. Kovalla tuulella
aallonpohja voi käydä kalan alapuolella. En mitannut.

### Poissuljettu (luettu koodista)

- Kalalla ei ole hyppyanimaatiota eikä hyppytilaa. "Rimpuilee pinnassa"
  (rivit 1494–1511) on vain ääni, viesti ja nykäys, ei liikettä.
- Jäällä siiman taitekohta on avanto korkeudella 0 (rivit 1439–1444), ja siiman
  alaraja jättää kalan 0,15 m avannon alle. Kala ei nouse jään yli.
- Haavinta (`landing_net.gd`) nostaa kalan tarkoituksella haavissa veneeseen.
  Se alkaa kalan vaakapaikasta kiinteältä syvyydeltä −0,15 m (rivi 194), joten
  ilmassa ollut kala hyppää haavinnan alussa takaisin veteen. Tämä on
  seuraus, ei syy.
- Matala vesi ei nosta kalaa: tavoitesyvyys on vähintään 0,3 m (rivi 1433).

## Toiminta pelaajan kannalta
Ei uusia näppäimiä. Väsytys toimii kuten ennen, kolmella täsmennyksellä
(avovesi; jäällä ei muutosta):

1. **Pintaraja.** Koukussa oleva kala on aina vähintään 0,15 m pinnan alla.
   Kireä siima nostaa kalan edelleen syvältä pintaan, mutta ei sen yli.
   0,15 m on sama syvyys, josta haavinta-animaatio alkaa
   (`landing_net.gd:194`), joten haavinnan alkuun ei tule hyppäystä.
2. **Kala jää laidan viereen.** Veneen vieressä kala pysyy rungon ulkopuolella
   vähintään 0,3 m päässä laidasta, sillä puolella, jolta se tuli. Se ei päädy
   veneen sisään eikä alle.
3. **Siiman voi kelata vain kalaan asti.** Kun kala on pinnassa laidan
   vieressä, kelaus ei enää lyhennä siimaa. HUD:n "Siimaa x m" pysähtyy
   silloin noin 2,3–2,8 metriin (vavan kärjen korkeus + kalan syvyys) eikä
   mene 0,5 metriin. Haavintakehote (siimaa alle 3,2 m) syttyy kuten ennen,
   ja haavinta ja "kala on vielä pirteä" toimivat ennallaan.

Kalan voimat, jarru, jännitys, nykäykset, irtoamiset ja lajin tunnistus eivät
muutu.

## Ulkoasu ja äänet
- Kala näkyy väsytyksessä aina veden alla tai pinnassa, humusveden
  haalistamana kuten nyt (`shaders/fish.gdshader`). Veneen vieressä se ui
  pinnan tuntumassa laidan ulkopuolella.
- Siima kulkee vavan kärjestä alas kalaan (jyrkästi, kun kala on vieressä).
- Ei uusia HUD-tekstejä, ilmoituksia eikä ääniä. HUD:n siimalukema ei mene
  veneen vieressä alle noin 2,3 metrin.

## Toteutus pääpiirteissään
Muutos on `scripts/fishing/fishing.gd`:n `_fight()`-funktiossa. Ei muutoksia
varjostimiin, malleihin eikä haavinta-animaatioon.

1. **Sallittu alue kalalle** (avovesi): korkeus enintään
   `min(0, Waves.swell_height(kalan xz)) − 0,15` (sama aaltofunktio kuin
   koholla, `_bobber_pos`, rivi 1907), ja vaakatasossa rungon ääriviivan
   ulkopuolella vähintään 0,3 m (`Boat._hull_at`, rungon koordinaatit kuten
   `FishingLine._inside_hull`, `fishing_line.gd:705`). Vakiot nimettyinä
   tiedoston alkuun muiden viereen.
2. **Kireän siiman veto (rivi 1471):** kala siirretään kuten nyt kohti
   kärkeä. Jos tulos ylittäisi pintarajan, korkeus jää rajalle ja
   vaakaetäisyys kärjestä lasketaan siiman pituudesta niin, että siiman pituus
   täsmää (sama ajatus kuin uistimella `_constrain_lure`, rivit 1290–1300).
   Vaakasuunta kärjestä kalaan säilyy. Jos tulos osuu rungon sallitun alueen
   sisään, kala siirretään lähimpään sallittuun kohtaan samalle puolelle.
3. **Siiman alaraja (rivi 1472):** avoveden kiinteä 0,5 m korvataan
   etäisyydellä kärjestä lähimpään sallittuun kohtaan (kala kärjen alla
   pintarajalla tai laidan vieressä). Kärki liikkuu (vavan taipuma, veneen
   keinunta), joten raja lasketaan joka askeleella; jos `line_out` jää rajan
   alle, se nostetaan rajalle (siimaa annetaan, ei jännityspiikkiä). Jään
   raja (`tip_to_anchor + 0.15`) säilyy.
4. **Varmistus askeleen lopussa:** ennen riviä `lure_pos = _fish_pos` (1515)
   kalan korkeus rajataan pintarajaan kaikissa haaroissa (jarru luistaa, löysä
   siima, vene liikkuu). Tämä kattaa veneen vetämän kalan ja aallonpohjan.
5. Haavintakehotteen ehto (rivi 1519) ei muutu. Koodaaja varmistaa testillä,
   että uusi alaraja jää kaikissa suunnissa alle 3,0 m. Jos ei jää (vapa
   pystyssä kovalla jännityksellä), koodaaja kysyy työnjohtajalta ennen kuin
   muuttaa kehotteen ehtoa.

Todennäköisesti muuttuvat: `scripts/fishing/fishing.gd`, uusi
`tests/fight_depth_test.gd`, `scripts/main.gd` (lippu `--fightdepthtest`),
`tools/run_tests.sh` (testilista), `docs/plan.md` (testilista). README ja
F1-ohje eivät muutu. Versio: korjaus, patch (työnjohtaja).

Huomio nykyisestä testistä: `tests/input_test.gd:65` asettaa `line_out = 2.0`
väsytetylle hauelle. Uusi alaraja nostaa sen noin 2,5 metriin; kehote syttyy
silti (alle 3,2 m), eikä testin pitäisi muuttua.

## Hyväksymiskriteerit
Uusi regressiotesti `--fightdepthtest`
(`godot-4.7.2 --headless --fixed-fps 30 -- --day=180 --fightdepthtest`):

- [ ] Tilanteet: väsynyt hauki 3 kg (voimat 0,2) ja pirteä ahven 0,2 kg,
      kumpikin neljästä suunnasta (oikea, vasen, keula, perä) 8 m päästä,
      jarru 3,0 kg, kelaus pohjassa 20 s; lisäksi hauki nopealla kelauksella.
- [ ] Joka ruudussa kalan `_fish_pos.y` ja mallin `_fish_node.global_position.y`
      ovat enintään −0,15 m (toleranssi 0,01). **Nykyisellä mainilla tämä
      epäonnistuu** (suurin korkeus +1,8…+2,0 m).
- [ ] Joka ruudussa kala on rungon ääriviivan ulkopuolella vähintään 0,3 m
      (toleranssi 0,02), myös perän ja keulan suunnasta.
- [ ] Siiman pää on kalassa (`lure_pos == _fish_pos`), eikä kireän siiman
      pituus poikkea kärjen ja kalan etäisyydestä yli 0,05 m.
- [ ] Jokaisessa tilanteessa haavintakehote syttyy 20 s kuluessa, ja siiman
      alaraja on alle 3,0 m.
- [ ] Väsyneellä hauella vasen hiiri kehotteen aikana aloittaa haavinnan ja
      päättyy tilaan LANDED; haavinnan ensimmäisessä ruudussa kalan paikka ei
      hyppää yli 0,3 m.
- [ ] Vene vetää kalaa: kala 15 m perässä (voimat 0,25, ei kelausta, jarru
      3,0 kg), venettä siirretään 4 m/s (ahven 0,3 kg) ja 7,5 m/s (hauki
      1,5 kg) 15 s ajan, sekä kädessä olevalla että telineessä olevalla
      vavalla. Kala pysyy joka ruudussa enintään −0,15 m korkeudella.
      **Nykyisellä mainilla epäonnistuu** (+1,19 m ja +1,79 m).
- [ ] Kova tuuli (12 m/s, selkä): kala on joka ruudussa vähintään 0,15 m
      aaltopinnan (`Waves.swell_height`) alla (toleranssi 0,03).
- [ ] Syvällä oleva pirteä kala (esim. kuha 4 m syvyydessä, siima kireällä,
      ei kelausta) ei siirry pintarajalle itsestään: korjaus ei muuta
      vedenalaista käytöstä.
- [ ] Mutaatiotarkistus: koodaaja näyttää, että testi epäonnistuu, kun
      korjaus poistetaan (rivit 1471–1472 alkuperäisinä), ja menee läpi
      korjauksella.
- [ ] Testi tukee kuvia: `--fightdepthtest-shots=KANSIO` tallentaa kuvat
      takaa ja sivulta, kun hauki on kelattu veneen viereen (oikea laita ja
      perä). Designer tarkistaa kuvista: kala vedessä laidan vieressä, siima
      kärjestä kalaan, ei kalaa ilmassa eikä veneen sisällä.
- [ ] Nykyiset testit läpi: `tools/run_tests.sh -q` kokonaan; erityisesti
      `linetest`, `linetest-talvi`, `trolltest`, `trollstriketest`,
      `inputtest`, `baittest`, `icetest`, `piketest`, `releasetest`,
      `synctest`, `careertest`.
- [ ] Jäällä ei muutosta: `icetest` läpi, kala nousee avannosta kuten ennen.

Käsin kokeiltavaksi Johtajalle: heitä, väsytä hauki ja ahven, kelaa veneen
viereen eri puolilta ja pidä kelausta pohjassa; kala pysyy vedessä ja haavinta
toimii.

## Avoimet kysymykset Teemulle
Ei avoimia. Kaikki kolme kysymystä on ratkaistu, ks. Päätökset.

## Päätökset

### Lisätieto 1 (Johtaja, 11.11.2026): bugi nähtiin heitossa tai uistelussa
Avovesi veneestä. Pilkki on rajattu pois. Molemmat polut tutkittu: kelaus
veneen viereen (heitto ja uistelu, sama `_fight()`) ja veneen vetämä kala (ajo
kala koukussa). Kumpikin on todennettu ja kumpikin on regressiotestissä.

### PÄÄTÖS 1 (Johtaja, 11.11.2026): toisto vastaa nähtyä bugia
Johtaja vahvisti kuvasta: kala roikkui ilmassa vavan kärjessä, kun sen kelasi
veneen viereen ("Kyllä, juuri tuo").

### PÄÄTÖS 2 (Johtaja, 11.11.2026): kalaa ei nosteta vavalla ilmaan koskaan
Koukussa oleva kala pysyy aina vedessä vähintään 0,15 m pinnan alla, kunnes se
haavitaan. Pienen kalan nostoa siimassa ei tehdä.

### PÄÄTÖS 3 (Johtaja, 11.11.2026): väli laitaan 0,3 m
Kala pysyy rungon ääriviivan ulkopuolella vähintään 0,3 m.

### PÄÄTÖS 4 (työnjohtaja, 11.11.2026): suunnitelma hyväksytty
Toteutus alkaa. Jos siiman uusi alaraja ylittää jossain vavan asennossa 3,0 m
(haavintakehote ei syttyisi), koodaaja kysyy työnjohtajalta ennen kuin muuttaa
kehotteen ehtoa (rivi 1519).

### PÄÄTÖS 5 (työnjohtaja, 11.11.2026): syvän kalan testissä made
Pelin kalakannassa ei ole kuhaa (`Species.DATA`), ja kriteerissä kuha oli vain
esimerkki. Testin "syvällä oleva pirteä kala" on made 1,5 kg 4 m syvyydessä.
Ei poikkeama suunnitelmasta.

### PÄÄTÖS 6 (työnjohtaja, 11.11.2026): runkoväli koskee vain pinnassa olevaa kalaa
Koko sarjassa `linetest` epäonnistui (48/49): tilanne "kala veneen alla" ei
enää toteudu, koska runkorajaus siirsi myös syvällä olevan kalan rungon
ulkopuolelle. Kala saa edelleen uida veneen ali syvällä, ja siima kiertää
silloin laidan yli kuten ennen (olemassa oleva ominaisuus, `linetest`, ei
kuulu tähän bugiin). Runkoväli 0,3 m koskee vain kalaa, joka on rungon pohjan
syvyydellä tai sen yläpuolella; raja-arvo johdetaan rungon mitoista koodissa
(ei uutta keksittyä lukua) ja kirjataan nimettynä vakiona. `linetest`iä ei
muuteta. Uuteen testiin lisätään tarkistus: syvällä veneen alla oleva kala ei
siirry rungon takia, ja pintaan nostettu kala ei päädy rungon alle.

### PÄÄTÖS 7 (työnjohtaja, 11.11.2026): veneen alta nouseva kala liukuu laidan ulkopuolelle
Päätöksen 6 toteutuksessa veneen alta pintaan kelattu kala hyppäsi yhdessä
ruudussa 0,70 m sivulle (pahimmillaan noin 1,06 m). Hyppyä ei hyväksytä.
Rungon alta nouseva kala ei nouse rungon pohjan tason yläpuolelle niin kauan
kuin se on vaakatasossa runkovälin sisällä: se liukuu pohjan tasolla lähimmän
laidan suuntaan ja nousee pintaan vasta laidan ulkopuolella. Liukunopeus on
sama 0,5 m/s, jolla kala jo hakeutuu tavoitesyvyyteen (ei uutta lukua).
Testi: kalan paikka ei muutu yhdessäkään ruudussa enempää kuin kelaus- ja
liukunopeus sallivat (ei hyppyä), kala ei käy rungon sisällä, ja
haavintakehote syttyy vasta, kun kala on laidan ulkopuolella pinnassa.
Hyväksymiskriteerien toleransseja ei löysätä.

### PÄÄTÖS 8 (Johtaja, 11.11.2026): koodaaja ei aja koko testisarjaa
Koodaaja ajaa vain uuden testin ja muutokseen liittyvät testit
(`fightdepthtest`, `linetest`, `linetest-talvi`, `inputtest`, `trolltest`,
`trollstriketest`, `icetest`). Koko sarjan ajaa testaaja ja työnjohtaja ennen
julkaisua.

### PÄÄTÖS 9 (työnjohtaja, 11.11.2026): päätöksen 7 toteutuksen tarkennukset hyväksytty
- Haavintakehotteen ehtoon (ennen rivi 1519) on lisätty "kala ei ole rungon
  alla" (`_under_hull`). Päätös 7 vaatii tämän; rajat 3,2 m ja −1,2 m ovat
  ennallaan.
- Liukuva kala kulkee 0,05 m rungon pohjan alla (olemassa oleva
  `FishingLine.HULL_MARGIN`), jotta sen keskipiste ei ole kölin pinnassa.
- Pintarajalla kalan vaakasiirtymä askeleessa rajataan siihen matkaan, jonka
  siima sitä veti. Ilman tätä jyrkkä siima siirsi pinnassa olevan kalan
  0,245 m yhdessä askeleessa (hyppy toisessa paikassa).
- Huomio Juurisyy-osion mittauksiin: fysiikka pyörii 60 askelta sekunnissa,
  ja toistoskripti laski ajan 1/30 s askelilla. Taulukoiden ajat ("alkaen
  6,4 s" jne.) ovat todellisuudessa noin puolet; korkeudet pitävät paikkansa.
  Regressiotesti käyttää `Engine.physics_ticks_per_second`ia.

### PÄÄTÖS 10 (työnjohtaja, 12.11.2026): testaajan löydökset
- Testaaja hyväksyi haaran (fightdepthtest 112/112, koko sarja 48/49:
  `pressuretest` epävakaa myös `origin/main`issa, 7/10).
- Askeleen lopun varmistukselle (kohta 4) ei ollut testiä: mutantti, josta
  varmistus on poistettu, meni läpi. Lisätty testaajan tilanne 3d (pirteä
  hauki ryntää pinnassa laitaa kohti jarru löysällä), joka kaataa mutantin;
  fightdepthtest 117/117. Lisätty myös puuttunut `fight_depth_test.gd.uid`.
- Veneen alta nouseva kala: haavintakehote syttyy, kun kala ylittää rungon
  ääriviivan (päätös 9, `_under_hull`), jolloin kala on vielä noin 0,30 m
  syvyydessä eikä 0,3 m päässä laidasta. Haavinta ei ala rungon sisältä.
  Hyväksytään sellaisenaan; Johtaja kokeilee käsin.
