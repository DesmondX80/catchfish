# CATCHFISH-86: Siima kuin lanka (myös CATCHFISH-85 ja CATCHFISH-81)

## Tavoite
Siima näyttää ja käyttäytyy kuin oikea monofiilisiima. Löysä siima kaartuu
pehmeästi, painuu ja kulkeutuu tuulessa, kireä siima vetäytyy suoraksi, eikä
siima taitu missään yhdessä pisteessä. Väriksi tulee läpikuultava vaalea
sinertävä monofiili, joka erottuu taivasta, vettä ja lunta vasten mutta ei
hehku eikä vilku. Lisäksi siiman vetolujuus toimii fysiikan mukaan: ison
kalan äkillinen ryntäys kireällä jarrulla voi katkaista siiman, vaikka jarru
on alle siiman lujuuden.

## Linjaukset (ratkaistu)

| # | Asia | Päätös |
|---|---|---|
| 1 | Venyvyys | A: vain ulkoasu, venymä ei vaikuta väsytykseen (Teemu) |
| 2 | Katkeaminen | B: nykäyskuorma voi hetkeksi ylittää lujuuden ja katkaista siiman (Teemu); malli osiossa *Nykäyskuorma* |
| 3 | Kireys siimassa | A: ei värinää eikä ääntä; jännityspalkki, vavan taipuma ja jarrun ääni riittävät (Teemu) |
| 4 | Näkyvyys | B: vaalea sinertävä, näkyy selvästi noin 40 m päähän (Teemu) |
| 5 | Veneen runko | A: siima kiertää laidan yli, vain ulkoasu, ei hankautumista (työnjohtaja) |
| 6 | Pinnan alla | A: häipyy humusveteen 0,3–0,5 m syvyydessä (Teemu) |
| 7 | Katkeaminen näkyvästi | B: vavan kärkeen jää roikkumaan katkennut pätkä (Teemu) |
| 8 | Tuulikaari | A: vain ulkoasu (työnjohtaja) |
| 9 | Siiman arvot | Yhteen paikkaan; pelissä yksi 0,28 mm siima, ja CATCHFISH-63 voi myöhemmin tehdä siitä vaihdettavan (työnjohtaja) |

## Nykytila ja havaitut viat

Siima piirretään funktiossa `Fishing._draw_line()` (`scripts/fishing/fishing.gd`,
noin rivi 1928) yhden pikselin `PRIMITIVE_LINE_STRIP`-viivana, jossa on 33
pistettä. Väri on `Color(0.9, 0.9, 0.85, 0.8)`, ja materiaali on
varjostamaton (unshaded) ja alfaläpinäkyvä. Muoto lasketaan joka ruudulla
kaavasta, eikä siimalla ole omaa tilaa:

1. Vavan kärjestä uistimeen on paraabeli, jonka roikkuma on
   `max(paino-roikkuma, sqrt(3·jänneväli·ylimääräinen siima / 8))`. Roikkuma
   on rajattu arvoon `0,45 × jänneväli`.
2. Paraabeli painuu veden alle, ja vedessä pisteet nostetaan arvoon
   `max(y, lerp(0, uistimen y, u))`, eli siima kulkee pinnalta suoraan
   uistimelle.
3. Tuuli siirtää siimaa sivulle kertoimella `0,08 × roikkuma`.

Paraabelin leikkauskohtaan vesirajassa tulee terävä kulma, ja se on juuri
"yhden pikselin taite". Mittasin kokeiluskriptillä suurimman kulman
peräkkäisten siimasegmenttien välillä (WSL, NVIDIA):

| Tilanne | Suurin taite | Missä |
|---|---|---|
| Löysä siima heiton jälkeen (31 m) | 22–31° | 2. pisteessä, veneen kyljessä vesirajassa |
| Pitkä heitto (41 m) | 22–27° | sama |
| Koho-onki | 25–27° | 3. pisteessä |
| Kova tuuli 12 m/s, löysä | 15–20° | vesirajassa veneen vieressä |
| Kelaus, kireä | 2–10° | vesirajassa |
| Hauki 4 kg, jarru laulaa | 6–12° | vesirajassa |
| Uistelu 26 m | 3–11° | vesirajassa |
| Pilkki ja kala jään alla | 15–29° | avannon kohdalla ja pinnan alla |
| Heitto lennossa | 0,3° | (suora jana, ei kaarta) |

Kuvissa (polut lopussa) näkyy lisäksi:

- **V-taite vesirajassa** FPV-kamerassa kelatessa (`11-fpv-kirea`) ja
  uistelussa perään katsottaessa (`25-uistelu-fpv-taakse`). Pelaaja näkee
  sen koko ajan, joten tämä on pahin kohta.
- **Löysä siima putoaa vavan kärjestä lähes pystysuoraan veteen veneen
  viereen** ja jatkuu siitä suorana pintaa pitkin (`02`, `04`, `09`).
- **Siima pinnan alla näkyy eri tavalla eri ajureilla.** WSL:ssä siima näkyy
  pinnan päällä koko matkan uistimelle asti (`05`, `07`, `19`), vaikka uistin
  on 2–5 m syvyydessä. Windowsin NVIDIA-ajurilla sama siima katoaa
  vesirajassa (`nyky-win/04`, `nyky-win/11`). Syy on todennäköisesti
  läpinäkyvien kohteiden (vesi ja siima) piirtojärjestys, joka riippuu
  kameran paikasta. Siima voi siis myös "poksahtaa" näkyviin ja pois.
- **Illalla siima hehkuu** valkoisena (`22-ilta-kirea`), koska materiaali on
  varjostamaton.
- **Lunta vasten** valkoinen siima ei juuri erotu (`nyky-talvi/w1`).
- **Kala veneen alla:** siima kulkee veneen rungon läpi
  (`20-kala-veneen-alla`).
- **Jäällä** siima piirretään suoraan vavan kärjestä kalaan, eli
  väsytyksessä jään läpi eikä avannon kautta. `_fight` käyttää avantoa
  taitekohtana pituuslaskussa, mutta piirto ei käytä.
- Siima lepää korkeudella y = 0, vaikka aallokko (`Waves.swell_height`)
  nostaa ja laskee pintaa.
- Yhden pikselin viiva portaittuu ja välkkyy liikkeessä (MSAA 2×).
  Kaukanakin se näkyy kirkkaan valkoisena (`09`).

Nykyinen pelilogiikka (säilyy, ellei alla toisin sanota):

- `line_out` (siimaa ulkona) ja `tension` (jännitys, kg)
- `LINE_STRENGTH = 6.5` kg (0,28 mm monofiili), jarru `drag_kg` 0,5–10 kg,
  oletus 3 kg, E/C 0,25 kg:n askelin
- väsytyksessä (`_fight`, noin rivi 1380–1466):
  - kalan veto `pull = (intensity·(0,3 + 0,7·stamina)·power·0,95 + 0,12)·paino`
  - kelaus lisää 0,6 kg (`effort`)
  - jos `pull + effort > jarru`, jarru luistaa ja `tension = jarru`; muuten
    `tension = pull + effort`
  - siima katkeaa, kun `tension > LINE_STRENGTH`, eli nyt vain, kun jarru on
    yli 6,5 kg
- ryntäys alkaa, kun `_run_timer` loppuu: `_run_intensity` arvotaan väliltä
  0,5–1,0 (todennäköisyys `0,45 + 0,4·stamina`), muuten lepo 0,12.
  Vastaiskun jälkeen (`_try_hook`) ensimmäinen ryntäys alkaa heti.
- `_try_land` epäonnistuu pirteällä kalalla, ja kala pakenee haavin luota
  (`_run_intensity = 1`).
- Hauen paino on 0,4–14 kg ja `power` 1,0. Muiden lajien `power` on 0,5–0,8
  ja enimmäispaino 0,18–6 kg (`species.gd`).

## Toiminta pelaajan kannalta

Ohjaus ei muutu. Suurin osa muutoksesta koskee sitä, miltä siima näyttää ja
miten se liikkuu. Ainoa uusi pelimekaniikka on nykäyskuorma (linjaus 2).

Siima käyttäytyy näin:

- **Lennossa:** siima purkautuu kelalta uistimen perässä loivana kaarena,
  jota tuuli taivuttaa. Nyt se on suora jana.
- **Heiton jälkeen (löysä):** siima laskeutuu vavan kärjestä veteen loivana
  ketjukaarena, jonka kulmaa ei näe kosketuskohdassa. Sieltä se lepää
  aaltojen pinnalla kohti uistinta, ja ylimääräinen siima jää pinnalle
  mutkalle. Sivutuuli kaartaa ilmassa olevaa osaa selvästi ja pinnalla
  lepäävää osaa hitaasti.
- **Kelatessa:** löysä siima nousee pinnalta ja oikenee vavan päästä
  alkaen. Kireä siima on ilmassa lähes suora, ja mitä kireämpi se on, sitä
  suorempi.
- **Väsytyksessä:** siima on kireä ja seuraa kalan ryntäyksiä. Kun kala
  kääntyy, siima pyyhkäisee pintaa ja kaartuu hetken eikä hyppää heti
  uuteen suuntaan. Kun jännitys katoaa, siima löystyy ja painuu kaarelle.
  Kuormassa siima venyy hieman näkyvästi, mutta venymä ei vaikuta peliin.
- **Uistelussa:** siima laskeutuu telinevavan kärjestä loivasti veteen
  veneen perässä ja keinuu veneen mukana.
- **Koho:** siima kulkee kohoon samalla tavalla, eikä kohon alla oleva siima
  näy (kuten nyt).
- **Kala veneen alla:** siima kiertää veneen laidan yli eikä kulje rungon
  läpi. Laidassa saa olla taite. Tällä ei ole pelivaikutusta (ei
  hankautumista).
- **Jäällä:** siima kulkee vavan kärjestä avantoon ja avannosta pilkille
  tai kalalle. Avannon reunassa siima taittuu; se on ainoa sallittu taite
  jään yllä.
- **Rannalla:** kun uistin on rannalla, siima lepää maan pinnalla eikä
  kulje maaston läpi.
- **Siima katkeaa** (nykäys, liian kireä jarru tai kiinni oleva uistin):
  `line_snap` kuuluu kuten nyt, ja vavan kärki ponnahtaa suoraksi. Vavan
  kärkeen jää roikkumaan katkennut pätkä, jonka pituus on **ehdotus 2,5 m**
  (Teemu voi päättää; ks. avoin kysymys B). Pätkä heilahtaa löysänä,
  roikkuu kärjestä, lepää osin vedessä ja liikkuu tuulessa. Pelitila
  katkeamisen jälkeen on sama kuin nyt (`State.READY`), joten pätkällä ei
  ole pelivaikutusta. Pätkä häviää, kun pelaaja heittää, laskee uistimen
  uistelussa, vaihtaa uistimen tai laskee vavan telineeseen tai pohjalle
  ("uusi uistin solmitaan").
- **Tuulikaari ja venymä** näkyvät siimassa, mutta ne eivät muuta
  `line_out`ia, jännitystä eikä vastaiskua (linjaukset 1 ja 8).

### Nykäyskuorma (uusi pelimekaniikka, linjaus 2)

**Mitä pelaaja kokee:** kun iso kala ryntää äkkiä, siimaan tulee hetkeksi
nykäys, joka on suurempi kuin tasainen veto. Jarru ei ehdi luistaa heti
(lähtökitka), ja vapa vaimentaa nykäystä vain osittain. Jos jarru on liian
kireällä tai pelaaja kelaa ryntäyksen alkaessa, nykäys voi katkaista
siiman, vaikka jarru on alle 6,5 kg. Pelaaja voi estää sen:

- **jarrulla:** kun jarru on enintään noin 5,2 kg, nykäys ei koskaan katkaise
  siimaa (ehdotetuilla luvuilla 5,2 × 1,25 = 6,5 kg).
- **kelauksella:** ison kalan ryntäyksen aikana ei kelata. Kelaus lisää
  vetoa (nykyinen `effort` 0,6 kg) ja jäykistää nykäystä.

Pienet kalat eivät koskaan katkaise siimaa nykäyksellä (raja alla). Malli
on deterministinen, eli siinä ei ole satunnaisuutta. Kalan ryntäysten
voimakkuus on kuitenkin jo nyt satunnainen (0,5–1,0), joten iso kala
katkaisee kireän siiman vasta täysivoimaisessa ryntäyksessä eikä
jokaisessa.

**Malli** (`_fight`, olemassa olevan logiikan päälle):

1. **Nykäyksen hetki.** Nykäys syntyy, kun kalan veto kasvaa äkkiä:
   - ryntäyksen alkaessa (`_run_timer`-haara, `_run_intensity` 0,5–1,0),
     myös vastaiskun jälkeinen ensimmäinen ryntäys
   - kun kala pakenee haavin luota (`_try_land`, `_run_intensity = 1`)
   - kun kala rimpuilee pinnassa (olemassa oleva `fish_splash`-tapahtuma
     `_fight`issa)
2. **Nykäyksen suuruus.**
   `nykäys = max(0, uusi_veto − edellinen_tension)`, jossa `uusi_veto`
   lasketaan nykyisellä `pull`-kaavalla uudella intensiteetillä.
   Pinnassa rimpuilun `uusi_veto` on **ehdotus: `pull + 0,5 · paino ·
   power`**.
3. **Huippujännitys.**
   `huippu = min(uusi_veto + effort + K · nykäys, jarru · (1 + S))`
   - `K` = vavan läpi menevä osa nykäyksestä (vapa vaimentaa loput).
     **Ehdotus: K = 0,4**, kun ei kelata, ja **K = 0,6**, kun pelaaja kelaa
     nykäyksen alkaessa (kampi lukitsee kelan, eikä vapaa voi antaa periksi).
   - `S` = jarrun lähtökitka, eli kuinka paljon yli asetuksen jarru pitää
     ennen kuin se lähtee luistamaan. **Ehdotus: S = 0,25.**
   - Jos `uusi_veto + effort + K · nykäys > jarru · (1 + S)`, jarru lähtee
     luistamaan heti (`drag_slipping`, jarru laulaa, `line_out` kasvaa).
4. **Kesto.** Huipun ylitys (`huippu − tasainen tension`) vaimenee
   eksponentiaalisesti aikavakiolla **ehdotus: 0,2 s**, joten nykäys on
   ohi noin puolessa sekunnissa. Tasainen jännitys lasketaan kuten nyt.
5. **Katkeaminen.** Jos `tension + nykäyksen jäljellä oleva osa >
   LINE_STRENGTH`, siima katkeaa (`_lose_fish(…, true)` kuten nyt), ja
   viesti on **ehdotus: "Siima katkesi nykäisyyn! Löysää jarrua isolle
   kalalle"**. Nykyinen sääntö (tasainen jännitys yli 6,5 kg) ja sen viesti
   säilyvät.
6. **Näkyvyys pelaajalle.** HUD:n jännityspalkki näyttää huipun (palkki
   hyppää ja palaa). Vavan taipuma ja `_bend_vel`-nykäys toimivat kuten
   nyt, ja jarru laulaa, jos se lähtee luistamaan. Siimassa itsessään ei ole
   värinää (linjaus 3).
7. **Ennallaan pysyvät:** kalan väsyminen (`_stamina`) lasketaan tasaisesta
   jännityksestä ilman huippua, joten tasapaino ei muutu. Lisäksi
   ennallaan pysyvät kiinni olevan uistimen satunnainen katkeaminen,
   telinevapa (sama malli, pelaaja ei kelaa) ja pilkki (sama malli).

**Esimerkit** (hauki, `power` 1, täysivoimainen ryntäys levosta,
pirteä kala):

| Kala | Jarru | Ei kelausta | Kelaa |
|---|---|---|---|
| 8 kg | 4,0 kg | huippu 5,0, ei katkea (jarru laulaa) | 5,0, ei katkea |
| 8 kg | 5,0 kg | 6,25, ei katkea | 6,25, ei katkea |
| 8 kg | 6,0 kg | 7,5, **katkeaa** | 7,5, **katkeaa** |
| 4,5 kg | 6,0 kg | 6,3, ei katkea | 7,5, **katkeaa** |
| 3 kg | mikä tahansa | enintään 4,2 | enintään 5,3, ei katkea |
| 2 kg | mikä tahansa | enintään 2,8 | enintään 3,7, ei katkea |

Pienen kalan raja: huippu on enintään noin `1,57 · paino · power + 0,6`
kg, joten hauki alle 3,7 kg ei voi katkaista siimaa nykäyksellä millään
jarrulla. Muilla lajeilla raja on suurempi, koska `power` on pienempi
(esim. `power` 0,8 → noin 4,7 kg). Käytännössä ahven, särki ja muut pienet
eivät katkaise siimaa koskaan.

**Perustelut luvuille (kaikki ovat ehdotuksia, joista Teemu voi päättää):**

- **S = 0,25:** kelan jarrun lähtökitka on oikeasti suurempi kuin
  luistokitka. Arvolla 0,25 turvallinen jarru on 5,2 kg, eli noin 80 %
  siiman lujuudesta. Se on tuttu kalastajan nyrkkisääntö: jarru noin
  1/4–1/3 lujuudesta on varma, ja yli 80 % on riskialtis. Oletusjarru 3 kg on
  aina turvallinen.
- **K = 0,4 / 0,6:** äkillinen kuorma joustavassa järjestelmässä voi olla
  jopa kaksinkertainen tasaiseen verrattuna (K = 1). Vapa vaimentaa siitä
  suurimman osan. Kelatessa vapa ei jousta yhtä vapaasti, mikä antaa
  pelaajalle toisen keinon estää katkeaminen.
- **0,2 s:** nykäys on lyhyt mutta näkyy jännityspalkissa. Katkeaminen
  ratkeaa huipussa, joten kesto ei muuta tulosta, vain sen, miltä palkki
  näyttää.
- **Venymä ei vaimenna** (linjaus 1 = A), joten siiman pituus ei vaikuta
  nykäykseen. Jos Teemu haluaa myöhemmin, että pitkä siima pehmentää
  nykäystä, K:sta voi tehdä pituuden funktion (ks. avoin kysymys C).

## Ulkoasu ja äänet

**Väri ja materiaali.** Läpikuultava, vaalea sinertävä monofiili, joka näkyy
selvästi noin 40 m päähän (linjaus 4). Lähtökohta on noin
`Color(0.65, 0.82, 0.95)` ja peittävyys noin 0,6. Designer säätää arvot
kuvista. Materiaali ei ole varjostamaton: siima saa valon taivaalta ja
auringolta kuten muutkin kohteet, joten illalla ja yöllä se tummuu eikä
hehku. Auringon puolella siimaan tulee heikko kiilto, joka vaihtelee
pehmeästi kulman mukaan eikä vilku.

**Paksuus ja näkyvyys kaukana.** Siima piirretään kameraan päin kääntyvänä
ohuena nauhana eikä yhden pikselin GL-viivana. Nauha on aina vähintään
noin 1,5 pikselin levyinen. Kun siima on kaukana ja ohuempi kuin pikseli,
peittävyyttä vähennetään samassa suhteessa, kunnes saavutetaan alaraja.
Silloin siima ei portaitu, ei välky liikkeessä eikä katoa kaukana. Alaraja
valitaan niin, että 40 m päässä oleva siima näkyy pelikamerassa selvästi
veden, taivaan ja lumen edessä.

**Pinnan alla.** Siima näkyy pinnan alla vain hetken ja häipyy humusveteen
0,3–0,5 m syvyydessä (linjaus 6). Häivytys lasketaan siiman omassa
varjostimessa siiman syvyydestä aaltopinnan suhteen (samaan tapaan kuin
`fish.gdshader` haalistaa kalan). Tulos ei siis riipu veden ja siiman
piirtojärjestyksestä, ja se on sama WSL:ssä ja Windowsissa. Siima
piirretään aina veden jälkeen (render priority), ettei se poksahda.

**Katkennut pätkä** näyttää samalta kuin siima ja käyttäytyy samoin
(simulaatio, jonka toinen pää on vapaa).

**Äänet.** Ei uusia ääniä. `line_snap` kuuluu kaikissa katkeamisissa,
myös nykäyksessä, ja jarrun laulu kuuluu, kun jarru lähtee luistamaan.

**HUD.** Ennallaan: jännityspalkki (näyttää nykäyksen huipun) ja "Jarru X kg
(siima kestää 6,5 kg)". Nykäyksestä katkeamisen viesti on oma (ks. malli,
kohta 5).

**README ja F1-ohje:**

- README, kohta **Väsytys** (noin rivi 187), täydennetään esimerkiksi näin:
  "liian kireä jarru katkaisee siiman, ja ison kalan äkillinen ryntäys voi
  katkaista sen jo alle siiman lujuuden, jos jarru on kireällä tai kelaat
  ryntäyksen aikana".
- README:n ominaisuustaulukkoon (Kalastus) ja `docs/plan.md`:hen
  "fysiikkaan perustuva siima" täsmennetään: siima taipuu kuin lanka,
  tuuli kaartaa sitä, se lepää aalloilla, kiertää veneen laidan yli ja
  kulkee jäällä avannon kautta, ja se on läpikuultava sininen monofiili.
- F1-ohjeeseen (`hud.gd`, noin rivi 246, "E / C jarru kireämmälle /
  löysemmälle") lisätään vihje, esimerkiksi rivi: "Iso kala: löysää
  jarrua, äläkä kelaa ryntäyksen aikana, ettei siima katkea nykäisyyn".

## Toteutus pääpiirteissään

Pelilogiikka (`line_out`, `tension`, `_constrain_lure`, `_fight`, jarru)
määrää edelleen, missä uistin ja kala ovat ja kuinka paljon siimaa on
ulkona. Uusi siimasimulaatio on näkyvä malli tämän päällä. Se ei siirrä
uistinta eikä muuta jännitystä. Ainoa pelilogiikan muutos on nykäyskuorma
`_fight`issa.

1. **Siiman arvot yhteen paikkaan** (linjaus 9). Uusi luokka, esim.
   `scripts/fishing/fishing_line.gd`, sisältää vakiot: paksuus 0,28 mm,
   lujuus 6,5 kg (`LINE_STRENGTH` siirtyy tai viittaa tänne), paino, väri,
   venymä sekä nykäysmallin S, K ja aikavakio. `hud.gd` ja `fishing.gd`
   lukevat arvot sieltä.
2. **Siimasimulaatio: pistemassaketju (Verlet)** vavan kärjestä siiman
   päähän (uistin, koho tai kala; jäällä avanto on välipiste).
   - Pisteitä on kiinteä määrä, esim. 32–48 vapaa kohti. Ne ovat tiheämmässä
     vavan kärjen ja vesirajan lähellä. Ketjun pituus on `line_out` ja
     venymä (vain ulkoasu, esim. 15 % · jännitys / lujuus).
   - Ensimmäinen piste on kiinni vavan kärjessä ja viimeinen siiman päässä
     (katkenneessa pätkässä vapaa). Paikat tulevat pelilogiikasta joka
     fysiikka-askeleella.
   - Voimat: paino, ilmanvastus ja tuuli (`weather.vector()`), vedessä veden
     vastus. Pinnalla piste pysyy aaltopinnalla (`Waves.swell_height`) ja
     liikkuu pinnan kitkan hidastamana. Maalla piste pysyy maan pinnalla
     (`lake.height_at`), eikä se mene pohjan alle.
   - Pituusrajoitteet iteroidaan muutaman kerran askelta kohti. Kireä
     siima on suora eikä värise.
   - Ruudun tahdissa (`follow_boat`) ensimmäinen piste siirretään ruudulla
     näkyvään vavan kärkeen, kuten vapakin nyt, ettei siima nyi.
   - Kun siimaa kelataan sisään tai jarru antaa siimaa, pituus muuttuu
     vavan päästä, eikä ketju hyppää.
   - Tilan vaihtuessa (heitto, uistimen vaihto, sisäänkelaus, katkeaminen,
     vapa telineeseen tai pohjalle, haavinta) ketju alustetaan järkevään
     muotoon.
   - Ketjun tila on vapakohtainen ja kuuluu `ROD_VARS`-listaan
     (`fishing.gd`, noin rivi 60). **Huom:** pakatut taulukot jaetaan
     viittauksena, joten jokaiselle vavalle pitää luoda oma taulukko (sama
     sudenkuoppa kuin `_rod_points`, kommentti noin rivillä 1252).
   - Varavaihtoehto, jos simulaatio osoittautuu levottomaksi:
     analyyttinen ketjukäyrä, joka koskettaa vettä tangentin suuntaisesti.
     Ennen varavaihtoehtoon siirtymistä kysytään työnjohtajalta.
3. **Veneen runko:** ketjun pisteet työnnetään ulos veneen rungon
   yksinkertaisesta muodosta (laatikko tai kapseli veneen koordinaateissa),
   jolloin siima kulkee laidan yli. Ankkuriköysi tekee samantapaisen kierron
   keulavannassa (`anchor.gd`, `_draw_rope`).
4. **Jäällä** avanto on ketjun kiinteä välipiste (sama taitekohta kuin
   `_fight`issa).
5. **Piirto:** `_draw_line` piirtää ketjun pehmeänä käyränä (esim.
   Catmull-Rom, 3–4 välipistettä segmenttiä kohti) kameraan päin
   kääntyvänä kolmionauhana (`ImmediateMesh`, `PRIMITIVE_TRIANGLE_STRIP`).
   Leveys noudattaa pikselirajaa (ks. *Ulkoasu*).
6. **Uusi varjostin** `shaders/fishing_line.gdshader`: väri, läpikuultavuus,
   valaistus, kiilto, kaukaisen siiman peittävyys ja häivytys pinnan alla.
   Piirretään veden jälkeen, ei varjoja.
7. **Lento:** heiton aikana näkyvä ketju saa hieman lisäpituutta, jotta
   siima kaartuu. Pelilogiikan `line_out`, heiton pituus ja tähtäin eivät
   muutu.
8. **Nykäyskuorma:** `_fight`issa nykäyksen hetket (kohta 1), huippu ja
   vaimeneminen (kohdat 2–4), katkeaminen ja viesti (kohta 5). Tarvitaan
   uusi vapakohtainen muuttuja nykäyksen jäljellä olevalle osalle
   (`ROD_VARS`), ja muuttuja nollataan, kun kala irtoaa, haavitaan tai
   siima katkeaa.
9. **Katkennut pätkä:** `_lose_lure` käynnistää pätkän (ketju, jonka
   toinen pää on vapaa). Pätkä poistuu kohdan *Toiminta* mukaan.
10. Todennäköisesti muuttuvat: `scripts/fishing/fishing.gd`, uusi
    `scripts/fishing/fishing_line.gd`, uusi `shaders/fishing_line.gdshader`,
    `scripts/ui/hud.gd` (F1-ohje, `LINE_STRENGTH`-viittaus), `README.md`,
    `docs/plan.md` (arkkitehtuuri ja testilista).
11. **Testit:** uusi headless-testi `tests/line_test.gd` (`--linetest`) ja
    kuva-ajo `--lineshots=KANSIO` (`main.gd`). Pohjaksi kelpaa
    kokeiluskriptini
    `/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/kopio/tests/line_shots.gd`,
    joka asettaa tilanteet ja mittaa suurimman taitekulman (`_report`).
12. **Suorituskyky:** 2 vapaa × 32–48 pistettä × noin 10 iteraatiota on
    GDScriptillä alle millisekunnin työ, ja nauhassa on muutama sata kärkeä
    vapaa kohti. Mitataan `--perftest`illä ennen ja jälkeen.

## Hyväksymiskriteerit

### Siiman muoto ja käytös (`--linetest`, headless)

Tilanteet: heitto lennossa, löysä siima heiton jälkeen (20 m ja 45 m),
kelaus kireälle, koho, väsytys (hauki 4 kg, jarru laulaa), kala veneen
alla, uistelu 60 m siimalla soutaen, kova sivutuuli 12 m/s, heitto rannalle
ja talvi (`--day=40`: pilkki avannossa ja kala jään alla 4 m avannosta).

- [ ] Taitekulma: piirretyn käyrän peräkkäisten osien välinen kulma on
      kaikissa tilanteissa enintään 5°. Poikkeuksia ovat vain fyysiset
      kiinnekohdat: vavan kärki, uistin tai koho, avannon reuna ja veneen
      laita.
- [ ] Pituus: ketjun pituus on `line_out` ± 2 % (ja venymä, enintään 15 %
      · jännitys / lujuus).
- [ ] Kireä siima (jännitys ≥ 0,5 kg ja `line_out` ≈ jänneväli): ilmassa
      olevan osan suurin poikkeama suorasta on enintään 5 cm.
- [ ] Löysä siima heiton jälkeen koskettaa vettä ja lepää pinnalla.
      Pinnalla lepäävät pisteet ovat ±3 cm aaltopinnasta myös kovassa
      tuulessa. Mikään piste ei ole pohjan tai maan alla.
- [ ] Tuuli: 12 m/s sivutuulessa löysän siiman ilmassa oleva osa kaartuu
      myötätuuleen, ja tyynellä se ei kaarru.
- [ ] Vakaus: kun vene, uistin ja tuuli ovat paikallaan 3 s, mikään
      ketjun piste ei liiku yli 1 mm ruudussa.
- [ ] Kala veneen alla: mikään ketjun piste ei ole rungon sisällä.
- [ ] Jäällä siima kulkee avannon kautta: avannon ulkopuolella ei ole
      pisteitä, jotka kulkevat jään läpi.
- [ ] Tilan vaihdot (heitto, sisäänkelaus, vapa telineeseen ja takaisin,
      vavan vaihto, katkeaminen, haavinta) eivät jätä ketjua vanhaan
      paikkaan eivätkä tuota yli 1 m hyppäystä ruudussa.
- [ ] Katkennut pätkä: katkeamisen jälkeen vavan kärjessä roikkuu pätkä
      (pituus ehdotuksen mukaan, 2,5 m ± 2 %). Se poistuu heitossa,
      uistimen vaihdossa ja kun vapa lasketaan telineeseen tai pohjalle.
      Tila on `READY` kuten nyt.

### Nykäyskuorma (`--linetest` tai oma `--shocktest`, headless)

Kala koukkuun testissä kuten `tests/screenshots.gd` (`_hook`), ryntäys
pakotetaan täysivoimaiseksi (`_run_intensity = 1`, `_stamina = 1`), ja
lasketaan katkeamiset. Testi ajaa jokaisen tapauksen useita kertoja eri
siemenillä.

- [ ] Hauki 8 kg, jarru 6 kg, ei kelausta: siima katkeaa ensimmäisessä
      täysivoimaisessa ryntäyksessä, ja viesti on nykäysviesti.
- [ ] Hauki 8 kg, jarru 4 kg (sama ryntäys), kelaten ja ilman: siima ei
      katkea 30 s väsytyksessä, ja jarru luistaa (`drag_slipping`).
- [ ] Hauki 4,5 kg, jarru 6 kg: kelatessa ryntäyksen alussa katkeaa, ilman
      kelausta ei katkea (kelaus estää katkeamisen).
- [ ] Pieni kala ei koskaan katkaise siimaa: ahven 0,3 kg, särki, lahna ja
      hauki 3 kg, jarru 10 kg, kelaten koko ajan 60 s. Nykäyksestä ei tule
      yhtään katkeamista (tasainen sääntö ennallaan).
- [ ] Jarrulla 5,0 kg tai vähemmän (raja 5,2 kg, liukuluvun takia testi 5,0) nykäys ei katkaise siimaa millään
      kalalla (hauki 14 kg, kelaten).
- [ ] Vastaisku isoon kalaan (hauki 8 kg) jarrulla 6 kg katkaisee
      siiman, ja jarrulla 3 kg ei katkaise.
- [ ] Jännityspalkin arvo (`tension`) nousee nykäyksessä huippuun ja palaa
      tasaiseen arvoon noin 0,5 s:ssa.
- [ ] Kalan väsyminen ei muutu: sama kala ja sama jarru väsyy yhtä
      nopeasti kuin mainissa (± 5 %).

### Yleiset

- [ ] Kaikki nykyiset testit menevät läpi (`tools/run_tests.sh -q`),
      erityisesti `--trolltest`, `--casttest`, `--icetest`, `--synctest`
      ja `--baittest`.
- [ ] Suorituskyky: `--perftest`in ms/ruutu kasvaa enintään 0,3 ms mainiin
      verrattuna (kaksi siimaa vedessä).
- [ ] README (Väsytys, ominaisuustaulukko), F1-ohje (jarruvihje) ja
      `docs/plan.md` ovat ajan tasalla.

### Kuvat (designer tarkistaa)

GPU:lla WSL:ssä (lokissa `RTX 4050`) **ja Windowsin NVIDIA-ajurilla**
(WSL-interop, projektin kopio `C:\Users\teeka\AppData\Local\Temp\siima\`,
lokissa `NVIDIA`). Tilanteet ovat samat kuin nykytilan kuvissa.

- [ ] Siima on läpikuultava vaalea sinertävä, ei valkoinen.
- [ ] Vesirajassa ei ole V-taitetta (FPV kelaus, FPV uistelu taakse,
      sivukuva, vesirajan lähikuva).
- [ ] Löysä siima laskeutuu veteen loivasti.
- [ ] Siima näkyy pelikamerassa selvästi 40 m heiton päähän veden ja
      taivaan edessä ja talvella lunta vasten.
- [ ] Illalla (klo 21.45) siima ei hehku.
- [ ] Pinnan alla siima häipyy 0,3–0,5 m:ssä samalla tavalla WSL:ssä ja
      Windowsissa.
- [ ] Kala veneen alla: siima kulkee laidan yli.
- [ ] Katkennut pätkä roikkuu vavan kärjessä luontevasti.
- [ ] Välke: `--jittershots`-tyylinen ajo kääntyvällä kameralla siiman
      ollessa kireällä. Siiman pikseleissä ei ole edestakaista välkettä
      kummallakaan ajurilla.

## Avoimet kysymykset Teemulle

Pääkohdat on ratkaistu (taulukko alussa). Jäljellä ovat ehdotetut luvut,
joista Teemu voi päättää. Ilman muuta päätöstä toteutetaan ehdotus.

A. **Nykäysmallin luvut.**
   - Jarrun lähtökitka S = 0,25, eli turvallinen jarru on 5,2 kg.
     Vaihtoehdot: 0,15 (turvallinen 5,65 kg, anteeksiantavampi) tai 0,35
     (turvallinen 4,8 kg, tiukempi).
   - Vavan vaimennus K = 0,4 ilman kelausta ja 0,6 kelaten. Vaihtoehto:
     sama K = 0,5 molemmille, jolloin kelaus vaikuttaa vain 0,6 kg:n
     lisävedon kautta.
   - Nykäyksen kesto: aikavakio 0,2 s.
   - Pinnassa rimpuilun nykäys: `0,5 · paino · power`. Vaihtoehto: ei
     nykäystä rimpuilusta, vain ryntäyksistä.
B. **Katkenneen pätkän pituus:** 2,5 m (ehdotus). Vaihtoehdot: satunnainen
   1,5–4 m, tai koko siima jää löysäksi veteen ja kelataan sisään ennen
   uutta heittoa. Jälkimmäinen olisi uusi pelivaihe, joten en suosittele
   sitä tähän tehtävään.
C. **Siiman pituus ja nykäys:** linjauksen 1 (venymä vain ulkoasua)
   mukaan pitkä siima ei pehmennä nykäystä. Jätetäänkö näin (ehdotus) vai
   tehdäänkö myöhemmin oma tehtävä, jossa venymä vaimentaa?
D. **Viestit:** "Siima katkesi nykäisyyn! Löysää jarrua isolle kalalle"
   ja F1-vihje "Iso kala: löysää jarrua, äläkä kelaa ryntäyksen aikana,
   ettei siima katkea nykäisyyn" (ehdotukset).

## Kuvat nykytilasta

- WSL, NVIDIA (D3D12, RTX 4050), kesä:
  `/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/nyky/`
  (01–25; taitemittaukset `>>`-riveillä tiedostossa
  `/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/nyky.log`)
- WSL, talvi:
  `/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/nyky-talvi/`
- Windows, NVIDIA 573.05:
  `/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/nyky-win/`
  (myös `C:\Users\teeka\AppData\Local\Temp\siima-nyky-win\`)
- Kokeiluskripti:
  `/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/kopio/tests/line_shots.gd`
  (kytketty vain kopion `main.gd`:hen lipulla `--lineshots=`)

Tärkeimmät: `11-fpv-kirea` ja `25-uistelu-fpv-taakse` (V-taite),
`02`/`04`/`09` (löysä siima putoaa pystyyn veneen viereen), `05`/`19` ja
`nyky-win/04` (siima pinnan alla eri ajureilla), `22-ilta-kirea`
(hehkuu), `20-kala-veneen-alla` (rungon läpi) ja `15-kova-tuuli-loysa`
(tuulikaari ja kulma veneen kohdalla).

## Työnjohtajan päätökset (hyväksytty 5.11.2026)
- Teemu: nykäysmalli ehdotuksen mukaan (S 0,25, K 0,4/0,6, aikavakio 0,2 s,
  rimpuilun nykäys 0,5·paino·power); katkennut pätkä 2,5 m.
- C: siiman pituus ei vaikuta nykäykseen (seuraa linjauksesta 1).
- D: viestit ja F1-vihje suunnitelman ehdotuksen mukaan; koodaaja saa hioa
  sanamuotoa, kunhan merkitys pysyy.
- Näkyvät muutokset kuvataan sekä WSL:ssä että Windowsin NVIDIA-ajurilla
  (WSL-interop, kansio C:\Users\teeka\AppData\Local\Temp\siima\…).
