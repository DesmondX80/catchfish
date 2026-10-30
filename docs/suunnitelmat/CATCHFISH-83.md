# CATCHFISH-83: Bug: Ankkuri (köysi venyy nostettaessa)

Hyväksytty 2026-10-23, tarkistettu mainia 0.52.0 vasten 2026-10-30: ankkurilogiikka
on ennallaan, eikä muiden veneiden törmäys (CATCHFISH-68) muuta suunnitelmaa.
Törmäyksen tönäisemä vene käsitellään kuten muukin ajautuminen.

## Tavoite

Ankkuriköysi ei veny koskaan, ei myöskään nostettaessa. Kun kalastaja käsittelee
ankkurin köyttä keulassa, hän ei samaan aikaan aja moottorilla eikä souda. Vene ei
siis voi karata köyttä pidemmälle.

## Syy

- `Boat.toggle_anchor()` asettaa nostettaessa heti `anchored = false` (#57:n ratkaisu:
  "nostettaessa vene irtoaa heti"). Köyden kova raja (`anchor_reach`) on voimassa
  vain `anchored`-tilassa, joten nostossa veneellä ei ole enää mitään rajaa.
- Kaasu ja soutu toimivat edelleen. Kalastaja istuu ankkuriasennossa etutuhdolla,
  mutta `drive`-syöte menee yhä moottorille tai airoille. Täydellä kaasulla vene
  kulkee noin 5 m/s, soutaen noin 1,5 m/s.
- `BoatAnchor.update()` (RAISING) siirtää ankkuria kohti keulaa vain 1 m/s
  (`RAISE_SPEED`). `_draw_rope()` piirtää köyden suorana keulasta renkaaseen niin
  pitkänä kuin väli on, joten köysi venyy kuin kuminauha veneen perässä.
- #57 (0.40.1) korjasi laskun ja pohjassa olon. Noston tilanne jäi korjaamatta.

## Toiminta pelaajan kannalta

- **Köyttä käsitellessä ei voi ajaa eikä soutaa.** Kun ankkuria lasketaan tai
  nostetaan (`anchor.handling()`), toimitaan kuten verkkoa käsitellessä (`net_hands`):
  W/S ja A/D eivät liikuta venettä.
  - Moottori: kaasu menee heti vapaalle (`throttle = 0`), ja ohjausaisa palaa
    keskelle. Moottori jää käymään tyhjäkäynnille, joten ankkurin tultua veneeseen
    pelaaja voi jatkaa ajoa W:llä käynnistämättä uudelleen.
  - Airot ja mela: vedot eivät kulje.
  - Ensimmäisellä painalluksella tulee ilmoitus (kerran käsittelyä kohden):
    `Kädet ankkurin köydellä – odota, että ankkuri on veneessä`.
  - Kun X painetaan kaasun ollessa päällä, ilmoitus on
    `Kaasu vapaalle – ankkuria nostetaan...` (nosto) tai
    `Kaasu vapaalle – ankkuri lasketaan keulasta...` (lasku).
- **Köysi ei veny nostossa.** Nostossa köyttä on ulkona jäljellä (`rope_out`).
  - Alussa köyttä on ulkona `anchor_rope` eli syvyys + 0,5 m. Sitä kelataan sisään 1 m/s.
  - Ankkurin ja keulan väli ei koskaan ole pidempi kuin ulkona oleva köysi. Jos vene
    ajautuu (vauhti, tuuli) kauemmas kuin köysi riittää, ankkuri laahautuu köyden
    perässä keulaa kohti. Venettä ei pidätetä, eli #57:n "nostettaessa vene irtoaa
    heti" säilyy.
  - Kun ulkona olevaa köyttä on vähemmän kuin syvyys, ankkuri irtoaa pohjasta ja
    nousee suoraan keulan alle.
  - Löysä köysi roikkuu kaarella kuten pohjassa olevalla ankkurilla. Kireä köysi on
    suora, mutta ei koskaan ulkona olevaa köyttä pidempi.
- **Nosto vauhdissa.** Jos vene liukuu vielä nopeasti (esim. heti täydeltä kaasulta),
  veden vastus hidastaa sitä kuten nyt. Ankkuri laahautuu perässä sen aikaa, ja köysi
  on kireä mutta oikean mittainen. Kun vene on hidastunut, nosto jatkuu normaalisti.
- **Ennallaan pysyvät (#57):** lasku keulan alla 1 m/s; köyttä syvyys + 0,5 m; pohjassa
  kova raja, ja kireä köysi kääntää keulaa; ilmoitus ja "Perkele, ankkuri!"
  ajoyrityksestä ankkuri pohjassa; nostoaika noin 1 m/s; vene on ankkurissa vasta
  ankkurin osuttua pohjaan.

## Ulkoasu ja äänet

- Ei uusia malleja eikä ääniä.
- Kalastaja on ankkuriasennossa koko käsittelyn ajan kuten nyt. Moottorin ääni laskee
  tyhjäkäynnille kaasun mukana (`game_audio.gd` seuraa jo kaasua).
- Köysi näkyy pinnan yläpuolella keulasta veteen kuten nyt. Muutos näkyy siinä, että
  köysi ei enää veny vinoksi pitkäksi viivaksi veneen perään.
- HUD-teksti `ankkuria nostetaan` ennallaan. Uudet ilmoitukset näytetään samalla
  `message`-ilmoituksella kuin muut veneen ilmoitukset.
- README / F1-ohje: ankkurikohtaan lisätään yksi lause: "Ankkuria laskiessa ja
  nostaessa kalastaja on keulassa köyden kimpussa, joten moottori on vapaalla eikä
  soutaa voi."

## Toteutus pääpiirteissään

- `scripts/boat/boat.gd`:
  - `toggle_anchor()`: kaasu nollaan ja aisa keskelle sekä ilmoitusteksti kaasun mukaan.
  - `_simulate`: kun `anchor.handling()`, `drive = 0` ja `steer = 0` samaan tapaan kuin
    `net_hands`. Ilmoitus annetaan kerran, kun pelaaja yrittää ajaa tai soutaa.
- `scripts/boat/anchor.gd`:
  - Uusi `rope_out` (ulkona oleva köysi). Se asetetaan noston alkaessa pituuteen
    `boat.anchor_rope` (tai laskussa olevalle ankkurille nykyiseen väliin) ja pienenee
    `RAISE_SPEED`illä.
  - RAISING-tilassa ankkuri pysyy pohjassa paikallaan, kunnes `rope_out` < syvyys.
    Sen jälkeen se nousee keulan alle.
  - Jos keulan ja renkaan väli > `rope_out`, ankkuri vedetään köyden suuntaan välin
    verran (laahaus).
  - `_draw_rope()` käyttää nostossa pituutta `rope_out` (sama kaari kuin DOWN-tilassa).
  - Nosto päättyy kuten nyt (`stowed`).
- `tests/anchor_test.gd` (`--anchortest`), uudet vaiheet:
  - Ankkuri pohjassa, moottori käy ja kaasu on 1,0 (ajoyritys kuten vaihe 3) → X.
    Tarkistetaan: kaasu on 0 heti; nostossa keulan ja renkaan väli ≤ `rope_out` + 0,1 m
    joka ruudulla; W nostossa ei muuta kaasua, ja ilmoitus "Kädet ankkurin köydellä"
    tulee; ankkuri tulee veneeseen alle (syvyys + 3) s:ssa; sen jälkeen W nostaa
    kaasun taas.
  - Vene liukuu 5 m/s, kun X painetaan: väli pysyy ≤ `rope_out` + 0,1 m.
  - Soutu nostossa (moottori sammuksissa, W pohjassa): vene ei kiihdy airoilla.
  - Nykyiset tarkistukset pysyvät, myös "nostettaessa vene irtoaa heti".
  - Kuva `--anchortest-shots`-kansioon: `ankkuri-5-nosto-kaasulla`.
- README ja F1-ohje (`hud.gd` `help_text`, X-rivi), `docs/plan.md` (korjattu-merkintä).

## Hyväksymiskriteerit

- [ ] Ankkuri pohjassa ja täysi kaasu, sitten X: köysi ei veny. Keulan ja ankkurin väli
  on koko noston ajan enintään ulkona olevan köyden mittainen (`--anchortest`, kuva).
- [ ] X kaasun ollessa päällä vie kaasun vapaalle, ja ilmoitus kertoo sen. Moottori jää
  käymään.
- [ ] Köyttä käsitellessä (lasku ja nosto) W/S/A/D eivät liikuta venettä moottorilla,
  airoilla eivätkä melalla. Ilmoitus tulee kerran.
- [ ] Ankkurin tultua veneeseen ajo ja soutu toimivat heti taas.
- [ ] Jos vene liukuu vauhdissa noston alkaessa, ankkuri laahautuu perässä eikä köysi veny.
- [ ] Nosto kestää edelleen noin 1 m/s (syvyys + enintään 3 s), ja ankkuri päätyy keulan
  jalkatasolle.
- [ ] #57:n käytös ennallaan: lasku keulan alla; köyttä syvyys + 0,5 m; pohjassa kova
  raja; ajoyrityksen ilmoitus ja huudahdus; tuulessa keula ankkuria kohti.
- [ ] `--anchortest` ja `--boattest` sekä muut ikkunattomat testit menevät läpi.
- [ ] README ja F1-ohje kertovat, että köyttä käsitellessä moottori on vapaalla eikä
  soutaa voi.
- [ ] Designer tarkistaa kuvan `ankkuri-5-nosto-kaasulla` (köysi lyhyt, ei venynyt).

## Päätetyt

- X kaasun ollessa päällä vie kaasun vapaalle, ja moottori jää tyhjäkäynnille. Kalastaja
  on keulassa, joten kukaan ei pidä peräsimestä (työnjohtaja).
- Vene irtoaa nostettaessa heti, ja jos vene ajautuu kauemmas kuin köysi riittää,
  ankkuri laahautuu perässä. #57:n "irtoaa heti" säilyy (työnjohtaja).
