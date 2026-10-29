# CATCHFISH-92: Testiapu --audio-log: soitetut äänet lokiin

## Tavoite
Uusi käynnistyslippu `--audio-log` tulostaa jokaisesta soitetusta äänestä rivin
(pelin kellonaika, äänen nimi, etäisyys veneestä). Designer ja testaaja näkevät
äänimuutoksen lokista ilman kuuntelua. Pelaajalle ei muutu mitään; ei
versionnostoa eikä releasea (Teemun linjaus), viedään mainiin.

## Toiminta pelaajan kannalta
Ei näy pelaajalle. Lippu vaikuttaa vain, kun se annetaan:

    godot-4.7.2 --headless --fixed-fps 30 -- --day=180 --audio-log --casttest

- Lippu yhdistetään mihin tahansa testiin tai kuvaskriptiin. Ilman lippua
  mitään ei tulosteta eikä peli muutu.
- Kirjataan kaikki kertaäänet:
  1. `GameAudio.play_at()` – kaikki `ONE_SHOTS`-äänet (moottorin käynnistys/
     sammutus, airot, mela, törmäys, potkuri, ankkuri, heitto, uistimen
     molskahdus, tärppi, kalan loiske, siiman katkeaminen, haavi, kaira,
     lumiaskel, metsän pikkulinnut, kuikka, taivaan linnut `Birds`-solmusta).
  2. Ennätyksen kilahdus `record_chime` (`_chime`, ei kulje `play_at`:n kautta).
  3. Kalastajan repliikit `AnglerVoice.say()` (nimenä repliikin tunniste,
     esim. `voice:bite_1`).
- Ääni, jota `play_at` ei soita (tuntematon nimi tai yli `MAX_ONE_SHOTS`),
  kirjataan merkinnällä `OHITETTU`, jotta katoava ääni näkyy lokissa.
- Silmukat (tuuli, talvituuli, sade, liplatus, aallokko, moottori, kela,
  jarru): ehdotus, että kirjataan vain käynnistys ja pysäytys
  (`loop_start`/`loop_stop`), ei voimakkuuden muutoksia. Tuuli, liplatus ja
  aallokko käynnistyvät kerran alussa (aina päällä, voimakkuus säädellään),
  joten käytännössä lokiin tulevat sade, moottori, kela, jarru ja tuulen
  talvi/kesä-vaihto. Ks. avoin kysymys 1.

### Lokirivin muoto
Yksi rivi per ääni, kiinteä etuliite, jotta rivit voi suodattaa `grep`illä:

    [ääni] 12:04:37 cast_swish 1.2 m
    [ääni] 12:04:38 lure_splash 23.8 m
    [ääni] 12:04:41 bird_chaffinch 118.0 m
    [ääni] 12:05:02 voice:bite_1 0.9 m
    [ääni] 12:05:10 record_chime -
    [ääni] 12:06:00 loop_start motor_loop
    [ääni] 12:07:15 loop_stop reel_loop
    [ääni] 12:07:20 fish_splash 14.3 m OHITETTU

- Kellonaika: pelin kello `SkyTime.minutes` muodossa HH:MM:SS (sekunnit
  mukaan, koska samalla minuutilla soi usein monta ääntä; nykyinen
  `clock_text()` antaa vain HH:MM).
- Etäisyys: 3D-etäisyys äänen pisteestä veneen `global_position`iin, yksi
  desimaali, yksikkö m. Ei-sijainnillisille (chime) `-`, silmukoille ei etäisyyttä.
- Nimi: `play_at`-kutsun nimi (ei muunnelman numeroa, esim. `oar_stroke`).

## Ulkoasu ja äänet
Ei muutoksia ruudulla eikä äänissä. Tuloste `print()`illä vakiotulosteeseen
(näkyy headless-ajossa ja editorin Output-paneelissa).

## Toteutus pääpiirteissään
- `scripts/audio/game_audio.gd`: lippu luetaan `setup()`issa
  (`OS.get_cmdline_user_args()`, sama tapa kuin `catch_log.gd`/`settings.gd`).
  Yksi kirjausfunktio (esim. `log_sound(nimi, piste)`), joka muodostaa rivin,
  tulostaa sen ja lisää sen muistiin (taulukko) testiä varten. Kutsut
  `play_at`iin (myös ohitushaaraan), chimeen sekä silmukoiden
  `play()`/`stop()`-kohtiin (`_process`, `_set_loop`, talvivaihto).
- `scripts/audio/angler_voice.gd`: `say()` kirjaa soitetun repliikin samaan
  lokiin (esim. viittaus GameAudioon tai signaali, jonka `main.gd` kytkee).
- `scripts/main.gd`:
  - **Huom.** `_ready()` aloittaa pelin suoraan ohittaen valikon, jos jokin
    käyttäjäargumentti alkaa `--`. Pelkkä `--audio-log` ohittaisi siis
    valikon. Ehdotus: `--audio-log` ei ohita valikkoa (ks. avoin kysymys 2).
  - Testin käynnistys `elif "--audiologtest" in args:` -ketjuun.
- Uusi testi `tests/audio_log_test.gd` ja rivi `tools/run_tests.sh`-listaan:
  `"audiologtest|--fixed-fps 30 -- --day=180 --audio-log --audiologtest"`.
- `docs/plan.md`, osio *Testaus*: lippu ja testi listaan. README:n
  testausosioon maininta. F1-ohjeeseen ei muutosta (ei pelaajalle).

### Testi `--audiologtest`
Vene paikallaan, `main.birds.auto_spawn = false`, metsälintujen ajastimet
siirretään kauas (kuten `voice_test.gd`), jotta satunnaiset äänet eivät sotke:
1. `play_at("lure_splash", veneen paikka + 10 m)` → uusin lokirivi vastaa
   muotoa `^\[ääni\] \d\d:\d\d:\d\d lure_splash 10\.0 m$` ja kellonaika on
   pelin kello.
2. Muunnelmaääni `oar_stroke` → nimi ilman numeroa.
3. Tuntematon nimi → rivi päättyy `OHITETTU`.
4. `voice.say("lost", true)` → rivi `voice:lost`.
5. `fishing.caught` ennätyksellä → rivi `record_chime -`.
6. Moottori päälle ja pois → `loop_start motor_loop` ja `loop_stop motor_loop`
   (jos silmukat kirjataan).
7. Kirjaus pois päältä (lippu false) → `play_at` ei lisää riviä.
Lopuksi `OK`/`VIRHE`-rivit ja `quit(1)` virheestä, kuten muut testit.

## Hyväksymiskriteerit
- [ ] `godot-4.7.2 --headless --fixed-fps 30 -- --day=180 --audio-log --casttest`
      tulostaa `[ääni]`-rivit heitolle (`cast_swish`) ja molskahdukselle
      (`lure_splash`) yllä olevassa muodossa; casttest menee yhä läpi.
- [ ] Sama ajo ilman `--audio-log`ia ei tulosta yhtään `[ääni]`-riviä.
- [ ] Rivien kellonaika on pelin kello (HH:MM:SS) ja etäisyys veneestä metreinä
      yhdellä desimaalilla.
- [ ] Kaikki kertaäänilähteet kirjautuvat: vene, kalastus, haavi, linnut
      (`Birds` ja metsälinnut/kuikka), ennätyskilahdus ja repliikit.
- [ ] Soittamatta jäänyt ääni näkyy merkinnällä `OHITETTU`.
- [ ] Silmukoiden käynnistys/pysäytys kirjautuu (loop_start/loop_stop).
- [ ] `tools/run_tests.sh godot-4.7.2 audiologtest` menee läpi, ja koko
      `tools/run_tests.sh` menee läpi kuten ennen.
- [ ] Pelaajalle ei muutosta: `project.godot`in versio ennallaan, ääni ja
      valikko toimivat kuten ennen.
- [ ] `docs/plan.md` (Testaus) ja README mainitsevat lipun.

## Ratkaistut kysymykset (työnjohtaja, 2026-10-29)

Testityökalun yksityiskohtia, joten työnjohtaja ratkaisi ehdotusten mukaan:
1. Silmukoista kirjataan vain käynnistys ja pysäytys (a).
2. Pelkkä `--audio-log` ei ohita valikkoa.
3. Vain `print()`, ei tiedostoa.
4. Ei lisätietoja: aika, nimi, etäisyys (+ OHITETTU).

## Alkuperäiset avoimet kysymykset
1. **Kirjataanko silmukat?** Ehdotus: kyllä, vain käynnistys/pysäytys
   (`loop_start`/`loop_stop`), ei voimakkuuksia. Vaihtoehdot: (a) ehdotus,
   (b) vain kertaäänet, (c) myös silmukoiden voimakkuus esim. kerran
   sekunnissa (paljon rivejä). Kela ja jarru voivat käynnistyä ja pysähtyä
   tiheään kelatessa.
2. **Ohittaako pelkkä `--audio-log` valikon?** Nyt mikä tahansa `--`-lippu
   aloittaa pelin heti ja ottaa saaliskirjan kirjoituksen pois. Ehdotus: ei
   ohita, jolloin lipulla voi pelata käsin normaalisti (valikko, saaliskirja
   tallentuu). Vaihtoehto: käyttäytyy kuin muut testiliput.
3. **Pelkkä tulostus vai myös tiedosto?** Ehdotus: vain `print()`
   (headless-ajossa riittää, Windowsin editorissa näkyy Outputissa).
   Vaihtoehto: `--audio-log=TIEDOSTO` kirjoittaa myös tiedostoon, jos Teemu
   haluaa kerätä lokin exe-ajosta.
4. **Lisätiedot riville?** Ehdotus: vain aika, nimi, etäisyys (+ OHITETTU).
   Vaihtoehto: myös äänenvoimakkuus dB ja väylä (Efektit/Taustaäänet/Puhe),
   mikä auttaisi tarkistamaan voimakkuusmuutokset.
