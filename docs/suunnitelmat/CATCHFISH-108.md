# CATCHFISH-108: Moottorilla ajaminen nopeammaksi

## Tavoite
Perämoottorilla pääsee järven päästä päähän nopeammin: täydellä kaasulla
tyynellä noin 28 km/h (nyt noin 19 km/h). Lisäksi näppäin 0 vie kaasun
heti vapaalle (0 %), ettei W/S:llä tarvitse hakea nollaa.

## Toiminta pelaajan kannalta

### Nopeus
- Kaasun käyttö ei muutu: W/S muuttaa kaasua 0,6 yksikköä sekunnissa
  (0 → 100 % noin 1,7 s), alue peruutus .. 100 %.
- Täydellä kaasulla tyynellä, ehjällä potkurilla huippunopeus 28 km/h
  (±0,5 km/h). Nykyinen huippu on laskettuna ja koodin vastusmallilla 18,95 km/h,
  ei kommentin mukainen ~20 km/h.
- Välikaasuilla nopeus nousee samassa suhteessa (vastus on neliöllinen):
  50 % kaasulla noin 19,4 km/h (nyt 13,0 km/h).
- Kiihtyvyys kasvaa: 0 → 26,6 km/h (95 %) noin 5 sekunnissa.
- Potkurivaurio heikentää työntöä kuten ennenkin (−60 % täysin vääntyneellä),
  tuuli ja vastatuuli vaikuttavat kuten ennenkin.

### Näppäin 0: kaasu vapaalle
- Fyysinen näppäin 0 (numerorivi) asettaa kaasun heti 0 %:iin. Kaasua ei
  liu'uteta, vene jatkaa liukuen ja hidastuu vastuksen mukaan.
- Toimii sekä eteen- että peruutuskaasulta.
- Toimii vain, kun moottori käy tai käynnistyy. Soudettaessa, melottaessa ja
  moottori sammuksissa 0 ei tee mitään (ei ilmoitusta).
- Toimii myös, kun kädet ovat verkolla tai ankkurin köydellä (kaasu on jo
  silloinkin pakotettu tai jäänyt; nollaus on aina turvallinen).
- Jäällä (vene talviteloilla) 0 ei tee mitään.
- 0 ei ole nyt käytössä missään (tarkistettu: `game_input.gd` ja koko
  `scripts/`, ei KEY_0- tai keycode-käsittelyä).

## Ulkoasu ja äänet
- HUD:n tilarivi näyttää jo kaasun ("Moottori %d %%", `hud.gd:430`):
  0:n jälkeen siinä lukee "Moottori 0 %". Nopeus näkyy samalla rivillä km/h.
- Ei uutta ääntä: moottorin kierrokset seuraavat kaasua (`game_audio.gd`
  `drive_motor`), joten 0 laskee äänen tyhjäkäynnille luonnostaan.
- Keulan nousu (`boat.gd:659`, `planing`) on jo rajattu 0,06 radiaaniin, joka
  saavutetaan nykyiselläkin huipulla; täydellä kaasulla ulkonäkö ei muutu,
  välikaasuilla keula nousee hieman aiemmin. Ei muutosta koodiin.
- Peräaalto (`wake.gd`) saa nopeuden parametrina; isompi nopeus levittää
  aaltoa enemmän. Designer tarkistaa kuvista, ettei 7,8 m/s:n wake näytä
  rikkinäiseltä (ks. hyväksymiskriteerit).
- F1-ohjeeseen (`hud.gd` `help_text`) ja README:n näppäintaulukkoon uusi rivi:
  `0            kaasu vapaalle (moottori)` / `| 0 | kaasu vapaalle (moottori) |`.

## Toteutus pääpiirteissään
- `scripts/boat/boat.gd`: `MOTOR_THRUST` 420 → **880 N**. Laskettu
  fysiikkasilmukan kaavoista tyynellä (tuuli 0): vastus pituussuunnassa
  13 v² + 10 v ja ilmanvastus keula edellä 0,85 · 0,3 · v² = 0,255 v²;
  13,255 v² + 10 v = 880 → v = 7,78 m/s = 28,0 km/h. Kommentti päivitetään
  (huippu ~28 km/h).
- `scripts/game_input.gd`: uusi toiminto, esim. `"motor_idle": [KEY_0]`.
- `boat.gd` `_unhandled_input`: `motor_idle` → jos `motor_running` tai
  `motor_starting > 0`, `throttle = 0.0`. Jään tarkistus on jo funktion alussa.
- Peruutus: ks. avoin kysymys 2; jos peruutusnopeus pidetään ennallaan,
  muutetaan kaasun alaraja (−0,4) koodissa vakioksi ja siihen arvo, joka antaa
  saman voiman kuin nyt (168 N → noin −0,19). HUD näyttää peruutuksen tekstinä,
  joten prosenttia ei näy.
- `scripts/boat/other_boat.gd` käyttää `Boat.MOTOR_THRUST`ia: kaasu lasketaan
  vastuksesta jaettuna työntövoimalla, joten vieraiden veneiden **matkanopeus
  pysyy 4,4 m/s**, mutta niiden kaasu putoaa noin 0,7:stä noin 0,33:een →
  moottoriääni matalampi ja keula alempana. Lisäksi `CRUISE_THROTTLE` (0,7,
  kommentti "noin 4,4 m/s") ei enää vastaa nopeutta. Ks. avoin kysymys 1.
- Testit, joihin muutos voi vaikuttaa (täysi kaasu, törmäykset):
  `dock_test.gd` (täysi kaasu laituriin: runko ei saa mennä kannen alle),
  `other_boats_test.gd` (täysi kaasu toiseen veneeseen, ääriviivat eivät
  päällekkäin ≤ 0,1 m), `prop_test.gd` (matalikolle ajo), `anchor_test.gd`.
  Koodaaja ajaa koko sarjan; jos törmäystestit pettävät suuremmalla
  työntövoimalla, se kerrotaan työnjohtajalle ennen raja-arvojen muuttamista.
- Uusi testi `tests/motor_speed_test.gd`, lippu `--motorspeedtest`
  (`main.gd` ja `tools/run_tests.sh`): tuuli 0 (`wind_base = 0`, kuten
  `prop_test.gd`), syvä avovesi, moottori käyntiin, kaasu 1,0, ajetaan 20 s
  ja mitataan huippunopeus; sitten simuloitu 0-näppäin (InputEventAction
  `motor_idle`), tarkistetaan kaasu ja nopeuden lasku; peruutus ja
  moottori sammuksissa -tapaus.
- README: näppäintaulukkoon 0-rivi. `docs/plan.md`: lyhyt merkintä
  moottorin nopeudesta ja 0-näppäimestä.

## Hyväksymiskriteerit
- [ ] Tyynellä, ehjällä potkurilla täydellä kaasulla huippunopeus
      27,5–28,5 km/h (HUD ja `speed_kmh()`).
- [ ] 50 % kaasulla nopeus noin 19–20 km/h.
- [ ] Kun moottori käy ja kaasu on 100 %, 0 asettaa kaasun heti 0 %:iin ja
      HUD näyttää "Moottori 0 %"; vene hidastuu (nopeus 5 s myöhemmin
      selvästi pienempi), moottori jatkaa käyntiä.
- [ ] 0 peruutuskaasulta → kaasu 0 %.
- [ ] Moottori sammuksissa (soutu) 0 ei muuta mitään eikä anna ilmoitusta.
- [ ] Jäällä 0 ei tee mitään.
- [ ] W toimii 0:n jälkeen normaalisti (kaasu nousee taas).
- [ ] Peruutusnopeus avoimen kysymyksen 2 päätöksen mukainen.
- [ ] Vieraiden veneiden matkanopeus ennallaan (~4,4 m/s) ja niiden
      moottorien kaasu/ääni avoimen kysymyksen 1 päätöksen mukainen.
- [ ] Potkuri osuu pohjaan, matalikkovaroitus ja potkurin rikkoutuminen
      toimivat kuten ennen (`--proptest` läpi).
- [ ] Laituri- ja venetörmäykset täydellä kaasulla: runko ei mene laiturin
      tai toisen veneen läpi (`--docktest`, `--otherboatstest` läpi).
- [ ] Uusi `--motorspeedtest` ja koko testisarja läpi.
- [ ] README:n näppäintaulukossa ja F1-ohjeessa 0-rivi.
- [ ] Kuvat (designer): täydellä kaasulla ajavan veneen wake ja keula
      `--screenshots`-ajosta näyttävät luontevilta.

## Päätökset (hyväksytty 5.11.2026)
1. **Vieraat veneet:** oma vakio 420 N, kaikki täsmälleen ennallaan (Teemu, a).
2. **Peruutus:** nopeus ennallaan noin 11,5 km/h, kaasuraja noin −19 % (Teemu, a).
3. **Numeronäppäimistön 0 (KP_0):** toimii samoin kuin numerorivin 0 (työnjohtaja).
4. **Ilmoitus 0:sta:** ei ilmoitusta, HUD näyttää "Moottori 0 %" (työnjohtaja).
5. **Matalikkovaroitus:** ennallaan 1,3 m (Teemu).
