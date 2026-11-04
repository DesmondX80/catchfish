# CATCHFISH-120: Pelaajaa ympäröi katkoviiva

## Tavoite
Vedessä noin 120 metrin päässä pelaajasta näkyvä vaalea (välillä tumma)
katkoviiva poistuu. Lähivesi ja kaukainen järviverkko jatkuvat toisiinsa
näkymättömästi kaikista kuvakulmista, tuulella ja tyynellä, kesällä ja talvella.

## Syy (varmistettu kuvista)

Viiva on **lähiveden ja kaukaisen järviverkon sauma**. Vesi piirretään kahdella
verkolla (`scripts/world/lake_world.gd`):

- lähivesi `near_water`: kameraa seuraava 240 × 240 m neliöverkko
  (`NEAR_RADIUS = 120`), jonka verteksit liikkuvat aaltojen mukana;
- kaukainen järviverkko: tasainen 4 m ruudukko, jonka varjostin jättää lähiveden
  alueen piirtämättä: `discard`, kun `max(|p - near_center|) < near_radius - 0.02`
  (`shaders/water.gdshader`, `fragment()`).

Lähiveden reuna on siis *geometrian reuna*, mutta kaukaisen verkon reuna on
*pikselikohtainen testi*, ja niiden välissä on vain 2 cm limitys. Loivassa
kuvakulmassa yksi pikseli kattaa 120 m päässä syvyyssuunnassa metrejä
(8 m korkeudelta noin 2 m), joten 2 cm on pikselin murto-osa. Rasteroinnin
alipikselitarkkuus ja interpoloidun `rest_pos`:n pyöristys eivät osu yksiin,
joten saumaviivalla vuorottelevat
- **rako** (kumpikaan ei piirrä, läpi näkyy tumma pohja) ja
- **limitys** (molemmat läpikuultavat pinnat piirtyvät päällekkäin, jolloin vesi
  on peittävämpää ja näyttää vaaleammalta eli "valkoiselta").

Kuvio riippuu viivan kulmasta pikseliruudukkoon ja kameran korkeudesta, joten
se näkyy kuvakulman mukaan katkonaisena tai yhtenäisenä. Neliön muodon vuoksi
viiva kiertää pelaajan, ja se liikkuu kameran mukana.

Varmistus (GPU-ajo, D3D12/RTX 4050, 1600 × 900, kesä, selkä):
- Kameran korkeus 25 m ja 8 m: neliön kulmat ja reuna näkyvät katkoviivana
  noin 120 m päässä.
- Kokeilu ajonaikaisella parametrilla (kaukaisen verkon `near_radius`):
  - perus (−0,02 m): tummia ja vaaleita pätkiä vuorotellen;
  - rako 0,5 m: tummat pätkät pitenevät, eli rako;
  - limitys 1 m: tummat pätkät katoavat, tilalle tulee **vaalea** katkoviiva,
    eli kaksinkertainen läpikuultava kerros näkyy valkoisena;
  - vain lähivesi: lähiveden reuna on suora ja yhtenäinen.
  Pelkkä limityksen kasvattaminen ei siis korjaa vikaa, vaan vaihtaa tumman
  viivan vaaleaksi.
- Teemun näkemä valkoinen väri vastaa limitystä. Windowsissa en ole ajanut
  kuvia, joten en ole varmistanut, miksi hänellä näkyy juuri vaalea eikä tumma
  vaihe (luultavasti ajurin rasterointi). Korjaus poistaa molemmat.

Diagnostiikkaskriptit (eivät kuulu peliin, koodaaja voi käyttää mallina):
`/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/diag/boot.gd`
ja `shots.gd`, kuvat samassa kansiossa `out/`.

## Toiminta pelaajan kannalta
Ei uusia näppäimiä eikä sääntöjä. Pelaaja ei näe vedessä viivaa, rakoa eikä
vaaleaa nauhaa missään kuvakulmassa (normaali kamera, FPV, kohokamera,
kartan/haavinnan kamerat), millään tuulella, kummallakaan veden laadulla
(Korkea/Matala) eikä talvella jäällä.

## Ulkoasu ja äänet
Vesi näyttää muuten täsmälleen samalta kuin nyt. Aallot häipyvät lähiveden
reunaa kohti jo nyt (96–120 m); korjauksen jälkeen ne häipyvät hieman
aiemmin (noin 6 m Korkealla, 11 m Matalalla), mikä ei 100 metrin päässä erotu.
Ei ääniä.

## Toteutus pääpiirteissään

Periaate: **molemmat verkot päättävät saumasta samalla pikselikohtaisella
testillä** samassa kohdassa, ja sauma siirretään lähiveden sisälle alueelle,
jossa lähivesi on täysin tasainen. Silloin kumpikin verkko katsoo samaa
tasaista pintaa ja samaa `rest_pos`-kohtaa, eikä geometrian reunan
rasteroinnilla ole merkitystä.

1. **Aaltojen häivytys loppuu ennen viimeistä verkkoriviä.** `near_fade`
   (`shaders/waves.gdshaderinc` ja sama `scripts/world/waves.gd`) menee nollaan
   jo kohdassa `near_radius - reunarivin väli` eikä vasta reunalla. Reunarivin
   väli on Korkealla noin 6,3 m ja Matalalla noin 11 m
   (`lake_world.gd`: `spacing` reunalla). Silloin lähiveden uloin solurivi on
   tasainen (y = 0, ei vaakasiirtymää), kuten kaukainen verkko.
   GDScript- ja varjostinversion pitää pysyä samoina (vene, koho ja muut
   veneet käyttävät GDScript-versiota).
2. **Yhteinen saumaraja** `seam` = `near_radius - reunarivin väli / 2`
   (tasaisen rivin keskellä), uusi uniform tai johdettu arvo:
   - kaukainen verkko: `discard`, kun `max(|p - near_center|) < seam`
     (nykyinen `near_radius - 0.02` pois);
   - lähivesi: uusi `discard`, kun `max(|p - near_center|) >= seam`.
   Molemmat käyttävät siirtymätöntä `rest_pos`:ia. Koska alue on tasainen,
   `rest_pos` vastaa pikselissä näkyvää kohtaa molemmissa verkoissa.
3. Arvot asetetaan samasta paikasta kuin nyt `near_center`/`near_radius`
   (`Waves`-luokan materiaaliparametrit `waves.gd` noin rivi 386, ja
   `LakeWorld._build_near_water` laskee reunarivin välin). Veden laadun vaihto
   (`Settings.water_quality_changed`) rakentaa verkon uudelleen, joten myös
   väli päivittyy.
4. Ei muutoksia `sorting_offset`iin, syvyyskirjoitukseen eikä vanaan.

Vaihtoehto, jota en suosittele: limityskaista ja syvyystesti (lähivesi
kirjoittaa syvyyden, kaukainen verkko hieman alempana). Se toimisi, mutta
muuttaa läpikuultavan veden syvyyskirjoitusta, mikä voi piilottaa veden alla
piirrettäviä läpikuultavia kohteita (siima, koho, kalat). Kohtien 1–2
korjaus on pelkkä varjostinmuutos ilman tätä riskiä.

Todennäköisesti muuttuvat:
`shaders/waves.gdshaderinc` (`near_fade`, uusi uniform),
`shaders/water.gdshader` (kaksi `discard`-ehtoa),
`scripts/world/waves.gd` (`near_fade`, parametrin asetus),
`scripts/world/lake_world.gd` (reunarivin väli talteen),
uusi testi `tests/`.

## Hyväksymiskriteerit

- [ ] Kuvat (GPU, 1600 × 900, kesä, selkä, tyyni 0,5 m/s): kamera 25 m
      korkeudella katsoo 100 m eteen ja 8 m korkeudella 40 m eteen 45°
      kulmassa. 120 m kohdalla tai neliön kulmissa ei näy katko- eikä
      yhtenäistä viivaa (vertaa diagnostiikkakuviin `c-25m-100.png`,
      `x0-perus.png`).
- [ ] Samat kuvat 4 m/s ja 8 m/s tuulella: ei viivaa eikä tasoeroa saumassa.
- [ ] Samat kuvat Matalalla laadulla (`--waterquality=matala`).
- [ ] Talvi (`--day=30` tai vastaava jäänäkymä): lumen pinnassa ei viivaa.
- [ ] Pelin oma kolmannen persoonan kamera laiturilla ja selällä
      (`--watershots`-kuvat 17–21 ja 02): ei viivaa, vesi muuten ennallaan.
- [ ] Kun kamera liikkuu (vene ajaa), saumaan ei välähdä viivaa
      ruutu ruudulta (esim. `--otherboatshots` tai uusi liikkuva kuva).
- [ ] Headless-testi: `Waves.near_fade` on 0 koko uloimmalla rivillä
      (`|d| >= near_radius - reunarivin väli`) ja 1 lähellä keskustaa;
      saumaraja on tasaisen rivin sisällä kummallakin laadulla; GDScript-
      ja varjostinkaavan luvut samat (testi tarkistaa GDScript-puolen ja
      asetetut uniformit).
- [ ] Olemassa olevat testit menevät läpi (`tools/run_tests.sh`), erityisesti
      `--wavetest`, `--settingstest`, `--overlaptest`.

## Testi
- Headless: uusi `--seamtest` (tai laajennus `--wavetest`iin) tarkistaa
  häivytyksen ja saumarajan kummallakin veden laadulla, ks. yllä.
- Ikkunassa: kuvaskripti (uusi `--seamshots=KANSIO` tai `--watershots`iin
  lisäkuvat), joka ottaa yllä luetellut saumakuvat. Ehdotan kuvaan
  automaattista mittaria: lasketaan `camera.unproject_position`illa saumaviivan
  pikselit ja verrataan niiden kirkkautta viivan ylä- ja alapuolen pikseleihin;
  poikkeavien pikseleiden osuus raportoidaan (ennen korjausta selvästi suurempi
  kuin vertailuviivalla esim. 100 m kohdalla, korjauksen jälkeen sama).
  Mittari on vain tulostus, ei pass/fail, ellei se osoittaudu vakaaksi.

## Avoimet kysymykset Teemulle
1. **Kuvakaappaus Windowsista?** Kuvissani sauma on enimmäkseen tumma ja
   vaalea vuorotellen, Teemu näkee valkoisen. Syy on sama, mutta jos Teemulla
   on kuva, sen avulla voi varmistaa, että kyse on tästä 120 m saumasta eikä
   jostain veneen vieressä. Ehdotus: työnjohtaja pyytää yhden kuvan, mutta
   toteutus voi alkaa ilman sitä, koska sauma on varmistettu.
2. Jos koodaaja huomaa, että Windowsissa jää yksittäisiä pikseleitä, saako
   lisätä pienen kaistan (esim. 0,5 m), jossa kaukainen verkko häivyttää
   alfaansa? Ehdotus: ei nyt; vain jos kuvat sitä vaativat.

## Työnjohtajan päätökset
1. Toteutus alkaa heti. Teemulta kysytään raportissa, näkyykö viiva noin
   120 m päässä vai aivan veneen vieressä; jos vastaus poikkeaa, palataan asiaan.
2. Alfahäivytyskaistaa ei lisätä nyt. Jos kuvissa jää pikseleitä, koodaaja
   kysyy ensin työnjohtajalta.
