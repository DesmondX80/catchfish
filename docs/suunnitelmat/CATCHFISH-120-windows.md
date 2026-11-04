# CATCHFISH-120 (Windows): Pelaajaa ympäröi katkoviiva

## Tavoite
Noin 117 metrin päässä näkyvä valkoinen katkoviiva (tai yhtenäinen viiva)
häviää myös Windowsin natiivilla OpenGL-ajurilla (NVIDIA). v0.52.2 korjasi
vian WSL:n D3D12/Mesa-ajurilla, mutta Teemun koneella viiva jäi.

## Syy

### Varmistettu (Windows-ajot, NVIDIA 573.05, OpenGL 3.3 Compatibility, RTX 4050)
- **Vika toistuu Windowsissa.** `--seamshots` v0.52.2:lla: kuva 02 (8 m,
  viisto, tyyni) saumamittari 48,6 % poikkeavia, vertailuviiva 0 %. Kuvassa
  on sama valkoinen katkoviiva kuin Teemun kuvassa
  (`windows-kuvat/v0522-02-8m-viisto.png`, suurennos `v0522-02-zoom.png`).
  Pelin oma kolmannen persoonan kamera (`--watershots` 02) näyttää saman
  sauman yhtenäisenä valkoisena viivana (`v0522-watershots-02-zoom.png`).
- **Valkoinen ei ole rako eikä kaksinkertainen kerros.** Kun lähivesi
  väritettiin punaiseksi ja järviverkko siniseksi (ALPHA = 1), viivan
  pikseleissä piirtyy oikea verkko, mutta niihin tulee lisää kirkasta valoa
  (esim. sininen 0,46/0,51/1,0 → 0,87/0,89/1,0). Rako näyttäisi pohjan,
  limitys pelkän toisen värin.
- **Syy on pikselin derivaatat `discard`in jälkeen.** `water.gdshader`
  `fragment()` hylkää ensin pikselit (`water_mask`, saumatesti, `inside_boat`)
  ja laskee vasta sen jälkeen `dpdx = dFdx(p)`, `dpdy = dFdy(p)` ja
  `footprint`. GPU laskee derivaatat 2 × 2 pikselin ryhmistä. Saumalla samassa
  ryhmässä on pikseleitä, jotka verkko hylkää, ja NVIDIA:n ajuri antaa
  jäljelle jääville pikseleille derivaatoiksi **nollan**: diagnostiikka-ajossa
  `footprint < 1e-6` juuri katkoviivan pikseleissä, muualla footprint on
  metrejä. Kun footprint on 0, aaltojen ja väreiden antialiasointi ei toimi
  (`textureGrad` nollagradientilla, ei häivytystä, karheus minimissä), joten
  pinta heijastaa auringon ja taivaan kirkkaana. GLSL:n mukaan derivaatat
  ovat `discard`in jälkeen määrittelemättömiä; Mesa/D3D12 antaa oikeat arvot,
  NVIDIA ei.
- **Katkokuvio selittyy samalla:** pätkät ovat 2 px korkeita ja alkavat
  parillisilta riveiltä. Kun loiva saumaviiva kulkee 2 × 2 ryhmän keskeltä,
  ryhmässä on molempien verkkojen pikseleitä (vika). Kun viiva osuu ryhmien
  rajalle, ryhmä on yhtenäinen (ei vikaa). Siksi vino viiva näkyy
  katkoviivana ja kameran suuntainen yhtenäisenä.
- **Korjaus A toimii Windowsissa** (derivaatat ennen `discard`ia):
  saumamittari 0,0 % kaikissa Korkean kuvissa 01–07 (4 m/s ja 8 m/s ≤ 0,5 %,
  sama kuin vertailuviivalla). Kuvat `korjausA-02-8m-viisto.png`.
- **Korjauksen A jälkeen jää yksittäisiä rakopikseleitä**: Matalalla
  kuvassa 02 kaksi tummaa pikseliä (mittari 0,4 %), liikkuvissa kuvissa
  1–3 pikseliä ruutua kohden molemmilla laaduilla. Väritetyssä ajossa niissä
  ei piirry kumpikaan verkko (näkyy sumuinen pohja), eli ne ovat aitoja
  rakoja: verkot interpoloivat `rest_pos`in eri kolmioista hieman eri
  tavalla, ja saumalle juuri osuva pikseli hylätään molemmissa
  (`korjausA-matala-02-rakopikselit-zoom.png`).
- **Korjaus B poistaa rakopikselit**: kun saumatestin kohta lasketaan
  ruudun pikselin säteen ja y = 0 -tason leikkauksesta (sama laskenta
  molemmissa verkoissa, ei riipu kolmioista), Windows-ajoissa ei ole yhtään
  poikkeavaa pikseliä saumalla: Korkea ja Matala kuvat 01–07, liikkuvat
  ruudut mukaan lukien (0,0 %; tuulikuvissa 03 jää 0,5–0,7 %, sama taso kuin
  vertailuviivalla eli aaltoja). Talvi (`--day=30`) ja `--watershots` 02,
  17, 19 näyttävät oikeilta (`korjausAB-*.png`).

### Päätelty (ei varmistettu)
- WSL:n kuvissa ennen v0.52.2:ta näkynyt tumma/vaalea vuorottelu oli osin
  samaa rakoilmiötä kuin korjauksen A jälkeiset rakopikselit; v0.52.2 ei
  ollut väärä, mutta se ei voinut auttaa NVIDIA:n derivaattavikaan.
- Sama derivaattavika voi näkyä NVIDIA:lla myös rannassa (`water_mask`) ja
  veneen sisäpuolen leikkauksen (`inside_boat`) reunalla; korjaus A poistaa
  sen niistäkin, koska derivaatat lasketaan ennen kaikkia hylkäyksiä.
  En kuvannut näitä erikseen.
- AMD- ja Intel-ajureita en voinut kokeilla.

### Ajotapa (toimi)
- WSL-interop: Windowsin Godot-editorin konsoliversio
  `/mnt/c/Program Files (x86)/Godot/Godot_v4.7.2-stable_win64_console.exe`.
  Projektin kopio Windowsin levylle (esim.
  `C:\Users\teeka\AppData\Local\Temp\cf120\proj`, ilman `.git`- ja
  `export`-kansioita), kerran `--headless --path <kopio> --import`, sitten
  `--path <kopio> --fixed-fps 30 -- --day=180 --seamshots=C:\...\kansio`.
  Lokiin tulee `OpenGL API 3.3.0 NVIDIA 573.05`. Yksi ajo noin minuutti.
  Varjostinkokeilut tehtiin vain tähän kopioon.
- Toimii myös vienti: `godot-4.7.2 --headless --export-release "Windows
  Desktop" export/Catchfish.exe`, kopio `/mnt/c/...`:hen ja
  `./Catchfish.exe --fixed-fps 30 -- --day=180 --seamshots=C:\\...` (sama
  tulos kuin editorilla). UNC-polkua (`\\wsl.localhost\...`) en kokeillut.
- Kuvien rajaus ja pikseliarvot: pieni `godot-4.7.2 --headless -s` -skripti
  (Pythonissa ei ole PIL:iä).

## Toiminta pelaajan kannalta
Ei uusia näppäimiä eikä sääntöjä. Vedessä ei näy viivaa, katkoviivaa eikä
yksittäisiä vaaleita tai tummia pisteitä lähiveden ja järviverkon saumassa
missään kamerassa, millään tuulella, kummallakaan veden laadulla eikä
talvella, Windowsin NVIDIA-ajurilla eikä WSL:n D3D12/Mesa-ajurilla.

## Ulkoasu ja äänet
Vesi näyttää muuten täsmälleen samalta kuin v0.52.2:ssa (korjaus A siirtää
vain laskennan järjestystä, B muuttaa vain sitä, kumpi verkko piirtää
saumapikselin). Ei ääniä.

## Toteutus pääpiirteissään
Vain `shaders/water.gdshader`, `fragment()`:

- **A (pakollinen):** `dpdx`, `dpdy` ja `footprint` lasketaan heti
  `vec2 p = rest_pos;` -rivin jälkeen, ennen ensimmäistä `discard`ia.
  Kommentti, miksi järjestys on tärkeä (derivaatat ovat `discard`in jälkeen
  määrittelemättömiä, NVIDIA antaa nollan). Varmistetaan, ettei `discard`in
  jälkeen jää muita derivaattoja tai implisiittisiä `texture()`-kutsuja
  (nyt kaikki ovat `textureLod`/`textureGrad`/`texelFetch`; pidetään niin).
- **B (suositus):** saumatestin kohta (`nd`) lasketaan `rest_pos`in sijaan
  ruudun pikselin näkösäteen ja y = 0 -tason leikkauksesta: `SCREEN_UV` →
  NDC → kaksi pistettä (z = −1 ja z = 1) `INV_VIEW_MATRIX *
  INV_PROJECTION_MATRIX`illa maailmaan → leikkaus tasolla y = 0. Kahden
  pisteen tapa toimii myös ortografisella kameralla. Tämä on oikein, koska
  v0.52.2:n jälkeen lähiveden uloin rivi ja järviverkko ovat saumalla
  tasaisia y = 0:ssa. `water_mask`- ja `inside_boat`-testit jäävät ennalleen.
  Kokeiluversio molemmista:
  `/tmp/claude-1000/-home-teekar-projektit-catchfish/5db04354-d51e-4be7-942e-4fe65e94d5d4/scratchpad/water-kokeilu-AB.gdshader`
  (koodaaja kirjoittaa oman siistin version kommentteineen).
- v0.52.2:n `near_fade`/`near_seam`/`near_edge` jäävät ennalleen; B tarvitsee
  tasaisen uloimman rivin.
- `tests/seam_test.gd` (`--seamtest`) laajennetaan lähdetarkistuksella, ks.
  Testi. `tests/seam_shots.gd` voi pysyä ennallaan; tarvittaessa lisätään
  tulostus yksittäisistä rakopikseleistä.

## Hyväksymiskriteerit
- [ ] **Windows-ajo** (NVIDIA, natiivi OpenGL, ajotapa yllä):
      `--seamshots` Korkea ja `--waterquality=matala`: saumamittari 0,0 %
      tyynissä kuvissa 01, 02, 07-1…4; tuulikuvissa 03–06 enintään
      vertailuviivan taso + 1 prosenttiyksikkö. Lokissa näkyy NVIDIA-ajuri.
- [ ] Windows-kuvissa 02 ja 07 ei näy saumalla valkoisia pätkiä eikä
      yksittäisiä tummia pikseleitä (rajaa ja suurenna saumaviivan kohta,
      vertaa `windows-kuvat/v0522-02-zoom.png`).
- [ ] Windows `--watershots` 02, 17, 19: ei viivaa horisontin edessä; vesi
      muuten samannäköinen kuin v0.52.2:ssa (vertaa `korjausAB-watershots-02.png`).
- [ ] Windows talvi `--day=30 --seamshots`: ei viivaa lumessa.
- [ ] WSL:n GPU-ajo (D3D12) `--seamshots`: tulokset vähintään yhtä hyvät
      kuin v0.52.2:lla (ei regressiota Mesassa).
- [ ] Headless `--seamtest` ja muut testit (`tools/run_tests.sh`) menevät läpi.
- [ ] Teemu kokeilee releasea Windowsissa: FPV ja normaalikamera, kesä,
      tyyni, Korkea (sama tilanne kuin kuvassa `teemu-windows-v0522.png`).

## Testi
- Headless (`--seamtest`-laajennus): lukee `res://shaders/water.gdshader`
  -lähteen ja tarkistaa, että `fragment()`-funktiossa ensimmäinen `dFdx`
  ja `dFdy` tulevat ennen ensimmäistä `discard`ia, eikä `discard`in jälkeen
  ole `dFdx`/`dFdy`/`fwidth`/`texture(`-kutsuja. GPU-käytöstä ei voi testata
  headlessina, joten tämä estää virheen palaamisen.
- Ikkunassa: nykyinen `--seamshots` ajetaan Windowsissa (ajotapa yllä);
  sen tulos on varsinainen todiste. Ehdotan, että ajotapa kirjataan
  `docs/plan.md`:n *Testaus*-osioon (Windows-ajurin kuvat WSL-interopilla).

## Avoimet kysymykset Teemulle
1. **Otetaanko korjaus B mukaan?** A yksin poistaa näkyvän valkoisen
   katkoviivan; B poistaa lisäksi 0–3 yksittäistä tummaa pikseliä ruutua
   kohden (näkyvät lähinnä Matalalla ja kameran liikkuessa välähtävinä
   pisteinä). B on 6 riviä varjostimeen, kaksi matriisikertolaskua
   pikselille. Ehdotus: A + B.
2. **Windows-ajot tiimin vakiokäytännöksi?** Tiimi voi nyt ajaa kuvaskriptit
   Windowsin NVIDIA-ajurilla WSL-interopin kautta (Godot-editori
   `C:\Program Files (x86)\Godot`). Ehdotus: näkyvät varjostinmuutokset
   tarkistetaan jatkossa sekä WSL:ssä että Windowsissa, ja tämä kirjataan
   `CLAUDE.md`:hen ja `docs/plan.md`:hen.
3. Saako tiimi käyttää Windowsin väliaikaiskansiota
   (`C:\Users\teeka\AppData\Local\Temp\cf120`) projektikopiolle ja kuville?
   Ehdotus: kyllä, ja kansio poistetaan tehtävän jälkeen.

## Työnjohtajan päätökset
1. Korjaus A + B toteutetaan (molemmat Windowsissa testattuja; B poistaa
   jäljelle jäävät yksittäiset rakopikselit).
2. Tässä tehtävässä Windows-ajo on pakollinen hyväksymiskriteeri koodaajalle
   ja testaajalle. Pysyvä käytäntö (CLAUDE.md, plan.md) on kirjattu Planeen
   tehtäväksi CATCHFISH-125 (Backlog), jonka Teemu priorisoi; sitä ei tehdä
   tässä haarassa.
3. Windowsin väliaikaiskansiota C:\Users\teeka\AppData\Local\Temp\cf120 saa
   käyttää; työnjohtaja poistaa sen julkaisun jälkeen.
