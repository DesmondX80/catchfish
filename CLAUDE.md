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
4. Release: commit → Windows-vienti → push → GitHub-release (suomeksi, exe liitteenä)
   → tehtävä Planessa *Done*.

## Testaus

- Godot ei ole WSL:ssä PATHissa; lataa Godot 4.7.2 Linux-binääri scratchpadiin,
  aja kerran `--headless --import` ja sitten testit, esim.
  `--headless --fixed-fps 30 -- --day=180 --luretest` (liput testitiedostojen alussa).
- `--autotest`-tasapainoajo on hyvin kohinainen; älä tulkitse sitä pass/fail-tuloksena.
- Käyttäjä kokeilee muutokset itse Windowsin Godot-editorissa (F5); kerro hänelle,
  minkä työkopion `project.godot` hänen pitää avata.
