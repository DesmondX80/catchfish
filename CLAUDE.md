# Catchfish – ohjeet Claudelle

Kalastussimulaattori Godot 4.7:llä (GDScript, GL Compatibility). Pelialue on
Raahen Haapajärven tekoallas. Yleiskuvaus ja ohjaus: `README.md`, suunnitelma ja
edistyminen: `docs/plan.md`.

## Tärkein sääntö: kysy, jos et tiedä

- **Kysy aina käyttäjältä, jos et tiedä jotain** tai jos pyyntö on
  tulkinnanvarainen. Älä arvaa äläkä keksi vastauksia, tiedostoja, funktioita
  tai pelimekaniikan yksityiskohtia.
- Tarkista ensin koodista ja `docs/plan.md`:stä, mitä sieltä löytyy; kysy
  se, mitä ei voi selvittää itse.
- Jos jokin jää epävarmaksi, sano se suoraan sen sijaan, että esittäisit
  arvauksen varmana tietona.

## Kieli

- Vastaa käyttäjälle aina suomeksi, myös väliraporteissa ja kysymyksissä.
- Koodin kommentit, commit-viestit, README, F1-ohje ja julkaisutiedot ovat suomeksi.

## Rakenne

- `scripts/` – pelilogiikka (`boat/`, `fishing/`, `lake/`, `world/`, `ui/`, `audio/`);
  autoloadit `game_input.gd`, `catch_log.gd`, `settings.gd`, `career.gd`, `fish_book.gd`
- `scenes/` – scenet, pääscene `scenes/main.tscn`
- `shaders/`, `assets/`, `data/` – varjostimet, mallit/äänet, järviaineisto
- `tools/` – Python-apuskriptit (järven rakennus, äänet)
- `tests/` – headless-testit (`*_test.gd`), käynnistyslipuilla esim. `--luretest`
- `export/Catchfish.exe` – viimeisin Windows-julkaisu

## Työtapa

Katso `docs/plan.md`, osio *Työtapa*. Lyhyesti:

0. **Jokainen uusi tehtävä omaan haaraan ja omaan työkopioon** (git worktree)
   ajantasaisesta mainista, koska samaan aikaan voi työskennellä useampi agentti:
   `git fetch && git worktree add -b claude/<aihe> ../catchfish-<aihe> origin/main`,
   ja kaikki työ tehdään siinä hakemistossa. Pääkansiossa `~/projektit/catchfish`
   ei vaihdeta haaraa eikä tehdä muutoksia. Älä jatka vanhan tehtävän haarassa.
   Uudessa työkopiossa aja ensin kerran `godot --headless --import`.
   Releasen jälkeen poista työkopio: `git worktree remove ../catchfish-<aihe>`.
1. Tehtävä Planesta (projekti CATCHFISH) → tila *In Progress*.
2. Toteutus ja testit (uusi ominaisuus saa oman testinsä), README ja F1-ohje ajan tasalle.
3. Versio `project.godot`:iin: uusi ominaisuus nostaa minor-, korjaus patch-versiota.
4. Ennen releasea päivitä haara mainin päälle, koska toinen agentti on voinut
   julkaista välissä: `git fetch && git rebase origin/main`, aja testit uudelleen
   ja tarkista versionumero mainista (`project.godot`, `docs/plan.md`), ettei
   samaa versiota julkaista kahdesti.
5. Release: commit → Windows-vienti → push → GitHub-release (suomeksi, exe liitteenä)
   → tehtävä Planessa *Done*.

## Agenttitiimi

Projektia tehdään Claude Coden agenttitiimillä (Agent Teams). Roolit on
määritelty kansiossa `.claude/agents/`:

| Rooli | Määritys | Tehtävä |
|---|---|---|
| Tiimin johtaja | Teemu | Antaa tehtävän, hyväksyy suunnitelman, kokeilee tuloksen, päättää julkaisusta |
| Työnjohtaja (lead) | pääsessio | Käynnistää tiimin, vie tehtävän vaiheesta toiseen, välittää viestit, julkaisee |
| Designer | `designer.md` | Suunnittelee tehtävän: miten ominaisuus toimii ja miltä se näyttää ja kuulostaa |
| Koodaaja | `koodaaja.md` | Toteuttaa hyväksytyn suunnitelman ja sen testin omassa työkopiossa |
| Testaaja | `testaaja.md` | Testaa toteutuksen suunnitelmaa vasten ja hyväksyy tai palauttaa sen |

### Työnkulku

Jokainen tehtävä kulkee nämä vaiheet tässä järjestyksessä:

1. **Tehtävä.** Teemu antaa tehtävän työnjohtajalle (Planen CATCHFISH-N tai
   vapaa kuvaus). Työnjohtaja luo tiimin (designer, koodaaja, testaaja) ja
   siirtää tehtävän Planessa tilaan *In Progress*.
2. **Suunnittelu.** Designer tutkii koodin ja `docs/plan.md`:n ja kirjoittaa
   suunnitelman (rakenne: `.claude/agents/designer.md`). Avoimet kysymykset
   kerätään suunnitelmaan; designer ei arvaa.
3. **Hyväksyntä.** Työnjohtaja näyttää suunnitelman ja avoimet kysymykset
   Teemulle. Toteutus alkaa vasta, kun Teemu on hyväksynyt suunnitelman.
4. **Toteutus.** Koodaaja toteuttaa hyväksytyn suunnitelman sellaisenaan,
   tallentaa sen haaraansa tiedostoon `docs/suunnitelmat/<tunniste>.md` ja
   kirjoittaa testin. Jos suunnitelmasta pitää poiketa, koodaaja kysyy ensin
   työnjohtajalta.
5. **Testaus.** Testaaja testaa haaran suunnitelman hyväksymiskriteereitä
   vasten. Palautus menee koodaajalle korjattavaksi; yli kaksi
   palautuskierrosta pysäyttää työn ja työnjohtaja kertoo Teemulle.
   Näkyvät muutokset designer tarkistaa kuvakaappauksista ennen hyväksyntää.
6. **Kokeilu.** Työnjohtaja raportoi Teemulle: mitä muuttui, testaajan
   raportti ja työkopio, jonka `project.godot` Teemu avaa Windowsin
   editorissa.
7. **Julkaisu.** Vasta kun Teemu sanoo "julkaise": versio, Windows-vienti,
   push, GitHub-release, Planessa *Done*, työkopion poisto ja tiimiläisten
   sulkeminen.

### Säännöt

- **Vain työnjohtaja nostaa versiota, tekee Windows-viennin, julkaisee ja
  muuttaa Planen tiloja.** Julkaisut tehdään yksi haara kerrallaan työtavan
  kohdan 4 mukaan, jolloin sama versio ei voi mennä kahdesti.
- Jokainen koodia muuttava tiimiläinen työskentelee omassa haarassaan ja
  työkopiossaan.
- Tiimiläinen, joka ei tiedä jotain, kysyy työnjohtajalta. Työnjohtaja kysyy
  Teemulta eikä arvaa.
- Teemu voi milloin tahansa puhua kenelle tahansa tiimiläiselle suoraan.

## Testaus

- Godot ei ole WSL:ssä PATHissa; lataa Godot 4.7.2 Linux-binääri scratchpadiin,
  aja kerran `--headless --import` ja sitten testit, esim.
  `--headless --fixed-fps 30 -- --day=180 --luretest` (liput testitiedostojen alussa).
- `--autotest`-tasapainoajo on hyvin kohinainen; älä tulkitse sitä pass/fail-tuloksena.
- Käyttäjä kokeilee muutokset itse Windowsin Godot-editorissa (F5); kerro hänelle,
  minkä työkopion `project.godot` hänen pitää avata.
