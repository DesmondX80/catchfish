# CATCHFISH-88: Äänimaailma

## Tavoite
Pelistä poistetaan "kummitusääni" eli kuikan huuto, joka kuului illalla ja
yöllä satunnaisesti kaukaa järveltä. Metsänreunan pikkulinnut eivät enää
laula lähes taukoamatta: laulujen väli on 8–15 sekuntia koko valoisan ajan.

## Toiminta pelaajan kannalta
- **Kuikka:** ei kuulu koskaan, ei illalla, yöllä eikä millään muullakaan
  hetkellä. Muita yöääniä ei tule tilalle.
- **Pikkulinnut (peippo, talitiainen):**
  - Laulavat metsänreunassa 40–250 m päässä veneestä kuten ennenkin
    (peippo 60 %, talitiainen 40 %, äänenvoimakkuus ja kuuluvuus ennallaan).
  - Seuraava laulu tulee satunnaisesti 8–15 s edellisen jälkeen. Nykyään väli
    on päivällä 6–18 s ja aamulla klo 3–8 tiheämpi 3–8 s; aamun oma väli
    poistuu, ja 8–15 s koskee koko valoisaa aikaa.
  - Laulavat vain, kun valoisuus on yli 0,45 (`sky.daylight() > 0.45`), kuten nyt.
    Yöllä ja hämärässä pikkulintuja ei kuulu.
  - Kuten nyt, jos valitusta suunnasta ei löydy rantaa 250 metrin sisältä, sillä
    kierroksella ei kuulu laulua. Selällä kauempana rannasta kahden laulun väli
    voi siksi olla pidempi kuin 15 s. Tämä on nykyinen toiminta, eikä sitä muuteta.
- **Taivaan linnut (Birds):** varis, korppi, sorsa, hanhi, lokki ja kotka
  kuuluvat täsmälleen kuten nyt. Niihin ei tehdä muutoksia.

## Ulkoasu ja äänet
- Ruudulla ei muutu mitään (ei HUD-tekstiä, ilmoitusta eikä valikkoa).
- Äänissä vain kaksi muutosta: kuikan huuto puuttuu ja pikkulintujen laulua
  kuuluu harvemmin, erityisesti aamulla. Muut taustaäänet (tuuli, sade, laineet)
  ja Taustaäänet-väylän voimakkuussäätö toimivat ennallaan.

## Toteutus pääpiirteissään
Kuikan kaikki esiintymät (haettu koko työkopiosta, `grep -i "loon\|kuikka"`):

1. `scripts/audio/game_audio.gd`
   - `ONE_SHOTS`-taulukosta rivi `"bird_loon": [-2.0, 160.0, 0.04]`.
   - Muuttuja `_loon_timer` (rivi 67).
   - `_birds()`: koko kuikkahaara (`_loon_timer`-laskuri, klo 20.5–4 ehto,
     järvipisteen haku ja `play_at("bird_loon", ...)`). Tämän jälkeen
     `_birds()` ei tarvitse `lake`-viitettä kuikkaa varten; `_shore_spot()`
     käyttää sitä edelleen, joten `lake` jää.
   - Pikkulintujen väli: `dawn`-muuttuja ja aamun 3–8 s pois, tilalle aina
     `randf_range(8.0, 15.0)`. Daylight-ehto `> 0.45` säilyy. Jos `hour`-muuttujaa
     ei enää tarvita, sekin pois.
   - Funktion kommentti (rivit 242–243) ajan tasalle: kuikkarivi pois, ja
     "aamulla tiheämmin" muutetaan kertomaan 8–15 s väli valoisaan aikaan.
   - Alkuarvo `_bird_timer := 4.0` (ensimmäinen laulu 4 s käynnistyksestä):
     ks. avoin kysymys 1.
2. `assets/sounds/bird_loon.wav` ja `assets/sounds/bird_loon.wav.import` poistetaan
   (`git rm`). `.godot/imported/`-välimuistin tiedosto ei ole versionhallinnassa;
   se siivoutuu uudelleenimportissa.
3. `tools/make_sounds.py`: funktio `loon_call()` (rivit 189–198) ja
   `sounds`-sanakirjan rivi `'bird_loon': loon_call` pois. `loon_call()` ei käytä
   satunnaislukugeneraattoria (`rng`), joten sen poisto ei muuta muiden äänten
   tuloksia, jos kaikki äänet generoidaan uudelleen.
4. `tests/audio_preview.gd` (`--audio-preview`): rivi `main.audio._loon_timer = 30.0`
   pois (muuten skripti kaatuu ajossa, koska muuttujaa ei enää ole) ja rivin 20
   kommentti "ilta: linnut ja kuikka" muotoon, joka ei mainitse kuikkaa.
   Kellonaika 21:00 jää ennalleen, koska kohtauksen tarkoitus on moottori,
   soutu ja heitto.
5. README, F1-ohje ja `docs/plan.md`: kuikkaa ei mainita missään (tarkistettu
   `README.md`, `scripts/ui/`, `scripts/game_input.gd`, `docs/plan.md`). Niihin ei
   tarvita kuikan poistoa. `docs/plan.md`:hen lisätään tavalliseen tapaan
   edistymiskirjaus (`- **#88 Äänimaailma – tehty (versio).** ...`) ja uusi testi
   osion *Testaus* listaan.
6. Uusi testi `tests/bird_sound_test.gd`, lippu ehdotuksena `--birdsoundtest`:
   kytkentä `scripts/main.gd`:n testivalintaan (`elif "--birdsoundtest" in args`),
   rivi `tools/run_tests.sh`:n `tests`-taulukkoon
   (`"birdsoundtest|--fixed-fps 30 -- --day=180 --birdsoundtest"`) ja
   `docs/plan.md`:n *Testaus*-listaan. Mallina `tests/wave_sound_test.gd`
   (`_check`, `_log`, lopetus koodilla 1 VIRHE-rivistä). Testin sisältö:
   - **Kuikka on poissa:** `GameAudio.ONE_SHOTS` ei sisällä avainta `bird_loon`,
     `audio._streams` ei sisällä sitä, `"_loon_timer" in audio` on epätosi ja
     `FileAccess.file_exists("res://assets/sounds/bird_loon.wav")` on epätosi.
   - **Kuikkaa ei soiteta koskaan:** `main.birds.auto_spawn = false` (taivaan linnut
     eivät sotke tulosta). Kuunnellaan `audio.child_entered_tree`-signaalia ja
     kirjataan jokaisen uuden `AudioStreamPlayer3D`:n striimin `resource_path`;
     soittimet vapautetaan heti kirjauksen jälkeen, koska headlessina `finished`
     ei välttämättä laukea ja `MAX_ONE_SHOTS`-raja estäisi muuten uudet äänet.
     Käydään läpi koko vuorokausi (esim. puolen tunnin askelin klo 0–24:
     `sky.minutes` asetetaan ja kutsutaan `audio._birds()` kiinteällä askeleella
     vähintään 120 simuloitua sekuntia kunkin kellonajan kohdalla). Yhdenkään
     soittimen polussa ei saa olla `loon`.
   - **Väli 8–15 s:** samassa ajossa kirjataan `_bird_timer`-arvo aina, kun laskuri
     nollautuu (arvo hyppää ylöspäin). Kaikkien arvojen on oltava välillä
     8,0–15,0, ja niitä on kerätty sekä aamulta (klo 3–8) että päivältä.
     Lisäksi kahden peräkkäisen pikkulinnun soiton väli simuloidussa ajassa on
     aina vähintään 8 s (yläraja ei ole tarkistettavissa soitoista, koska
     rannaton suunta jättää kierroksen väliin).
   - **Daylight-ehto:** pikkulintuja (`bird_chaffinch`, `bird_great_tit`) soi vain
     kellonaikoina, joina `sky.daylight() > 0.45`, ja päivällä (esim. klo 12) niitä
     soi ainakin kerran.
   - Testin alkuun kommentti tavalliseen tapaan: ajokomento ja mitä testi tarkistaa.

## Hyväksymiskriteerit
- [ ] `grep -rni "loon\|kuikka"` työkopiossa (pois lukien `.godot/`, `export/`, `docs/suunnitelmat/` ja `docs/plan.md`:n uusi #88-edistymiskirjaus) ei
      löydä kuikkaan viittaavia osumia; sanat kuten "piiloon" ja "kloonatulta"
      eivät kuulu tähän.
- [ ] `assets/sounds/bird_loon.wav` ja `.import` on poistettu versionhallinnasta.
- [ ] `tools/make_sounds.py` ei sisällä `loon_call`-funktiota eikä `bird_loon`-riviä,
      ja `python3 tools/make_sounds.py bird_chaffinch` toimii edelleen (ei
      välttämätöntä ajaa, mutta skriptin on oltava syntaksiltaan ehjä:
      `python3 -m py_compile tools/make_sounds.py`).
- [ ] `game_audio.gd`: pikkulintujen väli arvotaan aina 8–15 s, aamulla ei ole
      omaa väliä, ja daylight-ehto `> 0.45` on ennallaan.
- [ ] Taivaan lintujen (`VARIANTS`, `ONE_SHOTS`-rivit `bird_varis` ... `bird_kotka`,
      `scripts/world/birds.gd`) koodi on muuttumaton
      (`git diff origin/main` ei näytä niihin muutoksia).
- [ ] `godot --headless --fixed-fps 30 -- --day=180 --birdsoundtest` päättyy
      koodilla 0, ja tulosteessa on OK-rivit: kuikka poissa, kuikkaa ei soiteta
      vuorokauden aikana, välit 8–15 s (aamu ja päivä), pikkulinnut vain valoisalla.
- [ ] Uusi testi on `tools/run_tests.sh`:ssa ja `docs/plan.md`:n *Testaus*-listassa.
- [ ] Muut testit menevät läpi (`tools/run_tests.sh`), erityisesti `birdtest` ja
      `wavesoundtest`.
- [ ] `godot -- --audio-preview=/polku/naute.wav` ei kaadu (`_loon_timer`-rivi poistettu).
- [ ] Peli käynnistyy ilman virheitä tai varoituksia puuttuvasta `bird_loon.wav`:sta.
- [ ] Käsin (Teemu): illalla ja yöllä ei kuulu kuikkaa; aamulla ja päivällä
      pikkulintuja kuuluu selvästi harvemmin kuin ennen.

## Ratkaistut kysymykset
1. **Ensimmäinen laulu käynnistyksen jälkeen (työnjohtaja):** jätetään 4 s
   (`_bird_timer := 4.0`). Teemun 8–15 s koskee laulujen väliä.
2. **Versio (työnjohtaja):** patch, 0.51.1 (tarkistetaan mainista ennen julkaisua).
3. **Aamun väli (työnjohtaja):** 8–15 s koskee koko valoisaa aikaa, eikä aamulla
   ole omaa tiheämpää väliä.
