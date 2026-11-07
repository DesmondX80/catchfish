# CATCHFISH-84: Kalastustarvikeliikkeelle taustakuva

## Tavoite
Kun pelaaja avaa uramoodissa kalastustarvikeliikkeen, mökin pirtin tilalle
taustalle tulee kalastustarvikemyymälän sisätila. Pelaaja tuntee astuneensa
kauppaan, mutta kuva on hillitty eikä kilpaile tuotelistan ja painikkeiden
kanssa.

## Nykytila (tutkittu 7.11.2026)
- Kauppa on `CareerView.show_shop()` (`scripts/ui/career_view.gd:207`).
  `CareerView` on `MarginContainer`, ankkuroitu `PRESET_LEFT_WIDE`,
  vasen marginaali 70 px; sen sisällä `CenterContainer` → `PanelContainer`
  (tausta `Color(0.04, 0.06, 0.05, 0.84)`, kulmat 14, sisämarginaali 28) →
  `VBoxContainer` (leveys vähintään 500 px). Sama paneeli näyttää kaikki
  uran näkymät (koti, myynti, liike, nukkuminen); näkymä vaihtuu
  `_clear()`-kutsulla ja rakennetaan uudelleen.
- `CareerView` on `StartMenu`-CanvasLayerin lapsi (`scripts/ui/start_menu.gd:179`).
  Taustalla on 3D-mökki `CabinScene` (`start_menu.gd:69`, kamera fov 62),
  joka näkyy nyt myös kaupan takana: lämmin oranssinruskea hirsipirtti,
  takka, TV ja raidallinen matto (kuva `u2-kauppa.png` careertestistä,
  designerin ajo RTX 4050:llä, ei repossa).
- Paneeli peittää 1600×900-ruudulla vaakasuunnassa noin x = 70–626 px
  (4–39 % leveydestä) ja pystysuunnassa lähes koko korkeuden. Oikealla
  noin 60 % ruudusta jää taustalle.
- Projektin ikkuna: perusresoluutio 1600×900, `stretch/mode="canvas_items"`,
  `stretch/aspect="expand"`: leveämmällä näytöllä näkymä levenee, 4:3:lla
  korkenee.
- Pelin UI-värit: paneeli `#0A0F0D` (alfa 0,84), painike `#294D38`
  (hover `#3D6B4D`, painettu `#1F3829`, pois käytöstä `#1F2421`), otsikko
  kulta `#F2D973`, leipäteksti `#E0E6D6`, varoitus `#FFD980`. Fontti on
  Godotin oletus; koot 13–34.
- Pelin ilme: matalapolyinen, tasavärisiä pintoja ilman ääriviivoja, lämmin
  valaistus (mökki), ei tekstuurikuvia.
- Python-apuskriptit (`tools/`) käyttävät numpyä ja standardikirjastoa
  (`struct`, `wave`, `json`, `zlib` on saatavilla). Pillow ei ole asennettu.
  Ainoa PNG:n kirjoittava skripti `build_lake.py` käyttää GDALia, jota ei
  tähän tarvita. `build_ripples.py` käyttää kiinteää siementä
  (`np.random.default_rng(77)`), samaa mallia noudatetaan.
- Kuvatiedostot tuodaan Godotiin oletuksena häviöttömästi
  (`assets/lake/map.png.import`: `compress/mode=0`, ei mipmappeja).
- Peli viedään myös selaimeen (Web-vienti, GitHub Pages), joten tiedoston
  koko vaikuttaa latausaikaan.

## Toiminta pelaajan kannalta
- Uramoodin kotinäkymässä painike *Kalastustarvikeliike* avaa liikkeen kuten
  ennenkin. Taustalla näkyy heti myymälän sisätila koko ruudun kokoisena;
  mökkiä ei näy.
- Kaikki liikkeen toiminnot (maksut, ostot, vieritys, *Takaisin*) toimivat
  täsmälleen kuten nyt. Ostaminen ei vaihda eikä välähdä kuvaa.
- *Takaisin* (kotinäkymä) tai Esc (alkuvalikko) poistaa myymäläkuvan, ja
  mökki näkyy taas.
- Muut uran näkymät (koti, *Myy kaloja*, *Nuku*), alkuvalikko, kartta,
  asetukset ja kalakirja pysyvät ennallaan (PÄÄTÖS 5).
- Kuva on staattinen: ei animaatiota, ei vaihtelua vuorokauden- tai
  vuodenajan mukaan (PÄÄTÖS 5).

## Ulkoasu ja äänet

### Kuvan sisältö
Pieni maaseudun kalastustarvikeliike, kuvattuna sisääntulon kohdalta
silmän korkeudelta kohti takaseinää (yhden pisteen perspektiivi, pakopiste
noin x = 55 %, y = 45 %). Tiskin takana on yksi ihminen, partasuu myyjä
(PÄÄTÖS 3); muita ihmisiä ei ole. Luettavaa tekstiä ei ole (kyltit ja
hintalaput vain tyhjinä), koska teksti kilpailisi UI:n kanssa.

Vasen osa (x 0–40 %, jää paneelin taakse): rauhallisin alue.
- Vasen seinä: matalat puuhyllyt, joilla rivissä pahvi- ja muovirasioita
  (siimakelat, koukkurasiat) tummina, hillityin värein. Ei kirkkaita
  yksityiskohtia, ei lamppua.

Keskiosa (x 40–75 %): kuvan pääkohde.
- Myyntitiski keskellä lattiaa takaseinän edessä (puinen, edessä
  lasivitriini, jossa himmeinä pisteinä uistimia, ja vihreä paneeli).
  Tiskin päällä vaalea kassakone (runko, viisto näppäimistö, näyttö,
  kosketusvarjo tiskilevyssä), pieni rasia ja siimakelat.
- Tiskin takana seisoo partasuu myyjä (PÄÄTÖS 3), vyötäröstä ylöspäin
  näkyvissä: iso harmaanvalkoinen parta poskista rintaan, viikset,
  näkyvät silmät ja kulmat, vihreä lippalakki kultaisella merkillä,
  punaruudullinen flanellipaita ja oliivinvihreä kalastusliivi taskuineen.
  Sama tasavärinen tyyli kuin muu kuva. Hahmo on 1,25-kertainen
  luonnolliseen kokoon nähden, jotta kasvot ja parta erottuvat. Myyjä
  seisoo tiskin vasemmalla puolella (x noin 40–45 % kuvan leveydestä)
  ja on kokonaan paneelin oikealla puolella myös 1600×900-ruudulla.
- Takaseinällä myyjän oikealla puolella reikälevy (pegboard), jossa riveittäin
  roikkuvia uistimia ja vaappuja pakkauksissaan: pieniä värillisiä
  pystysuoria muotoja (lusikat hopeisina, vaaput punavalkoisina,
  keltaisina ja vihreinä). Nämä ovat kuvan ainoat kylläiset värit, ja nekin
  pieninä pisteinä.
- Tiskin ja myyjän yläpuolella seinällä iso täytetty hauki laudalla
  (PÄÄTÖS 2): noin 2,1 m pitkä (tyylitelty), pää vasemmalla, kita auki
  hampain, keltainen silmä ja kiduskansi, tumma selkä, vihreät kyljet
  vaaleine pilkkuineen, vaalea vatsa, punaruskeat evät (selkä-, perä-,
  vatsa- ja rintaevä) ja haarainen pyrstö. Laudassa tyhjä messinkilaatta.
  Hauki on kuvan selvin yksittäinen kohde, ja sumennus saa pehmentää vain
  reunoja.

Oikea osa (x 75–100 %):
- Oikean seinän vieressä lattialla vapateline (PÄÄTÖS 4): puinen jalusta,
  kaksi takapylvästä ja niiden varassa yläkisko. 8–12 vapaa seisoo
  tyvi jalustan reiässä ja nojaa yläkiskoon (ohuita tummia viivoja,
  korkkikahvat vaaleanruskeina jalustan yläpuolella).
- Seinällä kaksi haavia ja kumisaappaat hyllyn alla tai pilkkikairat
  nojallaan (yksi näistä riittää, koodaajan valinta).
- Oikean seinän perällä pieni ikkuna, josta näkyy himmeää päivänvaloa
  (vaalea harmaansininen, ei maisemaa).

Huone:
- Lattia: tummaa lautalattiaa, laudat pakopisteeseen päin, saumat ohuina
  tummina viivoina.
- Seinät: vaaleaa mäntypaneelia varjossa (lämmin, mutta selvästi
  himmeämpi kuin mökin oranssit hirret, jotta kauppa erottuu mökistä).
- Katto: tumma, kaksi tai kolme riippuvalaisinta (lämmin keltainen
  hehku, pehmeä valokeila tiskille ja lattialle).

### Tyyli ja valaistus
- Pelin ilme: tasaväriset monikulmiot ilman ääriviivoja, kuten
  `CabinScene`. Pinnoille vain hienovarainen sävyvaihtelu (puun syy,
  laudan sävyero) ja pehmeä valon vaimeneminen valaisimista.
- Valaistus: lämmin sisävalo valaisimista, nurkat ja katto tummempia
  (pehmeä varjostus nurkkiin), lievä reunatummennus (vinjetti) koko
  kuvaan.
- Lievä pehmennys koko kuvaan (gaussinen sumennus noin 1–1,5 px
  lopullisessa koossa), jotta kuva tuntuu taustalta eikä vaadi katsomista.
- Pieni kohina (±1/255) liukuvärien porrastumisen estämiseksi.

### Väripaletti (lopullisen kuvan sävyt valaistuina, hex)
| Kohde | Väri |
|---|---|
| Varjot, nurkat | `#16120E` |
| Lattia | `#3E2C1E` – `#5A402A` |
| Seinäpaneeli | `#6E5236` – `#8E6C46` |
| Hyllyt, tiski, vapateline | `#4E3420` – `#6B4628` |
| Reikälevy | `#7A6A50` |
| Katto | `#241C16` |
| Valaisimen hehku | `#FFD98A` (vain lampun kohdalla) |
| Ikkuna | `#9AA8AE` |
| Hauki | selkä `#2E3E26`, kylki `#5C6E38`, vatsa `#D2CBA0`, pilkut `#D8CE84`, evät `#A0603A` |
| Myyjä | iho `#C8946E`, parta `#C4BEB2` (juovat `#A49C90`), paita `#8A3A30`/`#5E2620`, liivi `#4E5A3A`, lakki `#294D38` |
| Kassakone | `#8C8C82`, näppäimistö `#5A5A54`, näyttö `#3A5A40` |
| Uistinpisteet | `#B8463A`, `#D8B04A`, `#9CB44A`, `#C8CCC8`, `#C8743A`, `#4A72A0` |

Paletti on lämmin ja ruskea kuten mökki, mutta tummempi. Vihreät ja
kultaiset sävyt sopivat UI:n painikkeisiin ja otsikoihin.

### Kirkkaus
- Koko kuvan keskimääräinen luminanssi 0,18–0,32 (0–1-asteikolla,
  Rec. 709 -kertoimet). Kauppa on silmämääräisesti hillitympi kuin
  mökki (mökin luminanssia ei ole mitattu).
- Vasemman 40 %:n keskiluminanssi on pienempi kuin oikean 60 %:n
  (paneelin alue rauhallisempi).
- Kirkkaimmat kohdat (lampun hehku) enintään 0,98 (PÄÄTÖS 6); mitään suurta
  kirkasta pintaa ei ole.
- Tummennus leivotaan kuvaan, eikä pelissä ole lisäpeittoa (PÄÄTÖS 5).

### Koko, kuvasuhde ja rajaus
- Kuva 1920×1080 (16:9), RGB, ei alfakanavaa.
- Pelissä kuva peittää koko ruudun ja säilyttää kuvasuhteen
  (`TextureRect`, `STRETCH_KEEP_ASPECT_COVERED`, keskitetty). 16:9:llä koko
  kuva näkyy; leveämmällä näytöllä ylä- ja alareunasta rajautuu, 4:3:lla
  sivuilta noin 12,5 % kummaltakin puolelta.
- Turva-alue: tärkeät kohteet (tiski, reikälevy, hauki, vapateline)
  alueella x 13–87 %, y 12–88 %, jotta ne näkyvät 4:3:sta 21:9:ään.
- Tiedostokoko enintään 1,6 Mt (Web-vienti, PÄÄTÖS 6); sumennus ja tasaiset
  pinnat pitävät PNG:n pienenä.
- Godot-tuonti: häviötön (kuten `map.png`), ei mipmappeja, suodatus
  lineaarinen.

### Äänet
Ei uusia ääniä tässä tehtävässä (PÄÄTÖS 5; ovikello Backlogiin).

## Toteutus pääpiirteissään

### Kuvan tuottava skripti
- Uusi `tools/build_shop_image.py`, rakenne ja docstring samaan tapaan kuin
  `tools/build_ripples.py`: alussa suomenkielinen kuvaus, käyttö ja tuotettava
  tiedosto.
- Ajo: `python3 tools/build_shop_image.py` (tai
  `uv run --no-project --with numpy python tools/build_shop_image.py`).
  Kirjoittaa `assets/shop/shop_interior.png`.
- Vain numpy ja standardikirjasto. PNG kirjoitetaan itse (`zlib` +
  `struct`: PNG-otsake, IHDR, IDAT, IEND, CRC `zlib.crc32`), ei Pillowia
  eikä GDALia.
- Kiinteä siemen `np.random.default_rng(84)`; kaikki satunnaisuus (syyt,
  uistinten värit ja paikat, vapojen kulmat, kohina) tästä yhdestä
  generaattorista. Sama komento tuottaa tavulleen saman tiedoston.
- Pohja: designerin luonnosskripti
  `/tmp/claude-1000/-home-teekar-projektit-catchfish/34b11e31-0386-430e-bad6-df94f9b04d38/scratchpad/kauppakuva/build_shop_image.py`
  (Teemun näkemä kuva). Koodaaja kopioi sen tiedostoksi
  `tools/build_shop_image.py` ja muuttaa vain tulostuspolun oletukseksi
  `assets/shop/shop_interior.png`, ilman muutoksia piirtoon, jolloin kuva
  pysyy samana kuin Teemun hyväksymä (sama sha256 kuin luonnoksessa).
  Mockup-apuskripti `make_mockup.py` ei tule repoon. Scratchpad on
  väliaikainen, joten skripti kannattaa kopioida työkopioon heti
  hyväksynnän jälkeen.
- Piirtotapa (luonnoksessa käytetty): huone yhden pisteen perspektiivillä monikulmioina
  (takaseinä, lattia, katto, sivuseinät) maalarin algoritmilla takaa
  eteen; monikulmion täyttö numpy-maskeilla; piirto 2× ylinäytteistettynä
  ja pienennys keskiarvolla (reunojen pehmennys); valaistus kertoimina
  (valaisimien säteittäinen vaimeneminen, nurkkatummennus, vinjetti);
  lopuksi erotuva gaussinen sumennus ja kohina.
- Kuvan valmis PNG ja sen `.import` commitoidaan repoon (kuten
  `assets/lake/map.png`), joten peli ei tarvitse Pythonia.

### Pelin muutokset
- `scripts/ui/start_menu.gd`: uusi koko ruudun `TextureRect`
  (`PRESET_FULL_RECT`, `expand_mode` ignore size, `STRETCH_KEEP_ASPECT_COVERED`,
  `mouse_filter` ignore), lisätään CanvasLayeriin ennen `_career`-näkymää,
  jotta se piirtyy mökin päälle ja paneelin alle. Oletuksena piilossa.
- `scripts/ui/career_view.gd`: näkymän vaihtuessa kerrotaan, onko liike auki
  (esim. signaali `shop_shown(bool)` tai vastaava; koodaajan valinta).
  `show_shop()` näyttää kuvan; `show_home()`, `show_market()`,
  `show_sleep()` piilottavat sen. Osto (`_buy`, `_pay_fee`,
  `_pay_rod_permit` kutsuvat `show_shop()`) ei saa välähdyttää kuvaa.
- `start_menu.gd`: `_show_main()`, `_show_map()` ja `open_career()`
  piilottavat kuvan (Esc kaupasta ja kalareissulle lähtö).
- Paneelin tyyliä, kokoa ja tekstejä ei muuteta.
- `README.md`: lyhyt maininta skriptistä apuskriptien kohdalle (miten kuva
  tehdään uudelleen). `docs/plan.md`: rivi edistymiseen ja uusi testi
  testilistaan. F1-ohjetta ei tarvitse muuttaa (ei uutta ohjausta).

### Testi
- Uusi headless-testi, esim. `--shopbgtest` (`tests/shop_bg_test.gd`),
  rekisteröidään `tools/run_tests.sh`:ään ja `docs/plan.md`:n listaan. Testi
  - lataa `res://assets/shop/shop_interior.png`: olemassa, 1920×1080, ei
    alfaa;
  - laskee kuvasta keskiluminanssin (0,18–0,32), suurimman arvon
    lamppualueen ulkopuolella järkevänä ja tarkistaa, että vasen 40 % on
    tummempi kuin oikea 60 %;
  - rakentaa `StartMenu`n tai `CareerView`n (headless) ja tarkistaa, että
    kuva näkyy vain liikkeessä: koti → liike (näkyy) → osto (näkyy yhä) →
    *Takaisin* (piilossa) → myynti ja nukkuminen (piilossa) → liike → Esc
    alkuvalikkoon (piilossa).
- Ikkunassa ajettava `--careertest` ottaa jo kuvan `u2-kauppa.png`;
  siihen ei tarvita muutosta, mutta se on designerin tarkistuskuva.

### Kuvakaappaustarkistus (designer)
Koodaajan työkopiossa näytönohjaimella:
```
GALLIUM_DRIVER=d3d12 MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA godot-4.7.2 --fixed-fps 30 --disable-vsync -- --careertest=KANSIO
```
sekä sama `--resolution 1200x900` (4:3) ja `--resolution 2100x900` (21:9),
jos ikkunan koko muuttaa näkymää. Lisäksi katsotaan itse PNG
`assets/shop/shop_interior.png`. Verrataan tähän suunnitelmaan: sisältö,
paletti, kirkkaus, paneelin luettavuus ja turva-alue.

## Hyväksymiskriteerit
- [ ] `python3 tools/build_shop_image.py` tuottaa `assets/shop/shop_interior.png`;
      kaksi peräkkäistä ajoa tuottavat saman sha256-tiivisteen.
- [ ] Skripti käyttää vain numpyä ja Pythonin standardikirjastoa, ja siemen on
      kiinteä (84).
- [ ] Kuva on 1920×1080 RGB, tiedosto enintään 1,6 Mt (PÄÄTÖS 6).
- [ ] Kuvassa on tunnistettavasti kalastustarvikeliike: tiski, reikälevy
      uistimineen, vapateline, hyllyt; ei luettavaa tekstiä.
- [ ] Seinällä on iso, tunnistettava täytetty hauki (pää, kita, evät,
      pilkut), joka erottuu sumennuksen jälkeenkin.
- [ ] Tiskin takana on partasuu myyjä, jonka parta, silmät ja lakki
      erottuvat, ja hän on kokonaan paneelin oikealla puolella
      1600×900-ruudulla (paneelin oikea reuna x = 626).
- [ ] Kassakone on tiskin päällä, vavat seisovat jalustassa ja nojaavat
      yläkiskoon, eikä yläkisko leiju.
- [ ] Tyyli sopii peliin: tasaväriset pinnat, lämmin hillitty valaistus,
      pehmeä kuva; paletti suunnitelman mukainen.
- [ ] Keskiluminanssi 0,18–0,32; vasen 40 % tummempi kuin oikea 60 %.
- [ ] Kuva näkyy koko ruudun taustana vain kalastustarvikeliikkeessä;
      kotinäkymässä, myynnissä, nukkumisessa, alkuvalikossa, kartalla,
      asetuksissa ja kalakirjassa näkyy kuten ennen.
- [ ] Osto tai maksu liikkeessä ei välähdä kuvaa eikä hyppää vieritystä.
- [ ] Esc liikkeestä vie alkuvalikkoon ja kuva poistuu.
- [ ] Liikkeen tekstit ja painikkeet ovat yhtä luettavia kuin ennen
      (designerin kuva `u2-kauppa.png`).
- [ ] Tiski, reikälevy ja vapateline näkyvät 16:9-, 4:3- ja 21:9-ikkunassa
      paneelin vieressä.
- [ ] Uusi headless-testi menee läpi, ja muut testit (`tools/run_tests.sh -q`)
      menevät läpi.
- [ ] README kertoo, miten kuva tehdään uudelleen; `docs/plan.md` on päivitetty.

## Päätökset

- **PÄÄTÖS 1 (Teemu 7.11.2026):** Teemu katsoo kuvan ennen kuin suunnittelusta edetään. Designer tekee suunnitelman mukaisen luonnosskriptin ja PNG:n scratchpadiin (`/tmp/claude-1000/-home-teekar-projektit-catchfish/34b11e31-0386-430e-bad6-df94f9b04d38/scratchpad/kauppakuva/`). Mukaan sekä pelkkä kuva että versio paneelin kanssa sellaisena kuin se pelissä näkyisi. Työkopion koodiin ei kosketa eikä commitoida ennen Teemun hyväksyntää.
  - Luonnos tehty 7.11.2026: skripti `scratchpad/kauppakuva/build_shop_image.py`
    (numpy ja standardikirjasto, siemen 84, ajo noin 5 s), kuvat
    `shop_interior.png` ja `shop_mockup.png` (1600x900: careertestin
    `u2-kauppa.png`:n oikea kauppapaneeli kuvan päällä, `make_mockup.py`)
    samassa kansiossa. Mockupissa paneeli peittää tiskin vasemman reunan noin
    45 px. Mitattu: keskiluminanssi 0,204,
    vasen 40 % 0,144, oikea 60 % 0,244, suurin 0,978 (lampun hehku), tiedosto
    1,53 Mt (PNG Sub- tai Up-suotimella), kaksi ajoa tuottivat saman sha256:n.
  - Luonnos 2 (PÄÄTÖKSET 2–4) tehty 7.11.2026: iso hauki, partasuu myyjä,
    kassakone tiskillä, vapateline korjattu. Mitattu: keskiluminanssi 0,203,
    vasen 40 % 0,145, oikea 60 % 0,242, suurin 0,978, tiedosto 1,55 Mt,
    sha256 sama kahdella ajolla. Myyjän vasen olka on 1600×900-ruudulla
    x = 699 px (paneelin reuna 626 px), kasvot x = 781 px.

- **PÄÄTÖS 2 (Teemu 7.11.2026):** Täytetty hauki ei erotu luonnoksessa ("missä vitussa se hauki on"). Hauki tehdään selvästi isommaksi ja tunnistettavaksi (pää, kita, evät, täplät, laudalla seinällä hyvin näkyvällä paikalla), eikä sumennus saa hävittää sitä.
- **PÄÄTÖS 3 (Teemu 7.11.2026):** Tiskin taakse tulee partasuu myyjä. Kielto ihmisistä kuvassa poistuu tämän osalta. Myyjä on sama tasavärinen matalapolyinen tyyli, ja hänellä on näkyvä parta.
- **PÄÄTÖS 4 (työnjohtaja):** Luonnoksen geometriaviat korjataan samalla: vapatelineen vavat ja kiskot istuvat telineessä (kahvat eivät roiku alalaudan alla, yläkisko ei leiju), ja kassakone istuu tiskin päällä eikä kellu reikälevyn edessä. Muuten sommittelu ja kirkkaus on hyväksytty ("muuten hyvä").

- **PÄÄTÖS 5 (Teemu 7.11.2026):** Avoimet kysymykset ratkaistu suositusten mukaan: kuva näkyy vain kalastustarvikeliikkeessä (ei Myy kaloja -näkymässä); tummennus leivotaan kuvaan; yksi kuva ympäri vuoden; koko 1920x1080; ovikello ei kuulu tähän tehtävään (Backlogiin).

- **PÄÄTÖS 6 (Teemu 7.11.2026, hyväksyntä):** Teemu hyväksyi luonnoksen 2 ("päästetään koodari irti"). Teemun näkemä kuva on mittapuu: skripti otetaan sellaisenaan (varmuuskopio työkopiossa `docs/suunnitelmat/CATCHFISH-84-luonnos/build_shop_image.py`), ja vain tulostuspolku vaihdetaan. Luonnoksen mittaukset ylittävät kaksi suunnitelman ylärajaa, joten ne tarkennetaan näin: lampun hehkun suurin luminanssi saa olla 0,98 (luonnos 0,978), ja tiedostokoko enintään 1,6 Mt (luonnos 1,55 Mt). Luonnosskriptin varmuuskopiokansio poistetaan haarasta ennen commitia, ja skripti jää vain `tools/`-kansioon.

## Avoimet kysymykset Teemulle
Ei avoimia kysymyksiä. Alkuperäiset kysymykset 1–5 ratkaistiin suositusten
mukaan (PÄÄTÖS 5): kuva näkyy vain kalastustarvikeliikkeessä, tummennus
leivotaan kuvaan, yksi kuva ympäri vuoden, koko 1920×1080 ja ovikello
kirjataan Backlogiin. Ihmiskielto ja hauen koko muuttuivat (PÄÄTÖKSET 2–3).
Teemu hyväksyi luonnoksen 2 (PÄÄTÖS 6).
