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

Projektia voi tehdä Claude Coden agenttitiimillä (Agent Teams). Roolit on
määritelty kansiossa `.claude/agents/`:

| Rooli | Määritys | Tehtävä |
|---|---|---|
| Tiiminvetäjä (lead) | pääsessio | Ottaa tehtävät Planesta, jakaa ne, sovittaa tiedostoreviirit, julkaisee |
| Koodaaja (2-3 kpl) | `koodaaja.md` | Toteuttaa pelilogiikan ja sen testin omassa työkopiossa |
| Designer | `designer.md` | Käyttöliittymä, varjostimet, äänimaailma; arvioi kuvakaappauksista |
| Testaaja | `testaaja.md` | Ajaa testisarjan ja hyväksyy tai palauttaa haaran |

Teemu on tiimin omistaja: hän päättää prioriteetit ja vastaa kysymyksiin, joita
koodista tai suunnitelmasta ei löydy.

Säännöt:

- **Vain tiiminvetäjä nostaa versiota, tekee Windows-viennin, julkaisee ja
  muuttaa Planen tiloja.** Julkaisut tehdään yksi haara kerrallaan työtavan
  kohdan 4 mukaan, jolloin sama versio ei voi mennä kahdesti.
- Jokainen tiimiläinen työskentelee omassa haarassaan ja työkopiossaan.
- Tiiminvetäjä jakaa tehtävät niin, ettei kaksi tiimiläistä muokkaa samaa
  tiedostoa yhtä aikaa. Jaetut tiedostot (`scripts/main.gd`, `scenes/main.tscn`,
  `tools/run_tests.sh`, `README.md`) sovitaan viestillä ennen muokkausta.
- Haara julkaistaan vasta, kun testaaja on hyväksynyt sen. Näkyvät muutokset
  käyvät lisäksi designerin arviossa.
- Tiimiläinen, joka ei tiedä jotain, kysyy tiiminvetäjältä. Tiiminvetäjä kysyy
  Teemulta eikä arvaa.
- Kun tehtävä on valmis, tiiminvetäjä kertoo Teemulle, minkä työkopion
  `project.godot` hänen pitää avata kokeillakseen.

## Testaus

- Godot ei ole WSL:ssä PATHissa; lataa Godot 4.7.2 Linux-binääri scratchpadiin,
  aja kerran `--headless --import` ja sitten testit, esim.
  `--headless --fixed-fps 30 -- --day=180 --luretest` (liput testitiedostojen alussa).
- `--autotest`-tasapainoajo on hyvin kohinainen; älä tulkitse sitä pass/fail-tuloksena.
- Käyttäjä kokeilee muutokset itse Windowsin Godot-editorissa (F5); kerro hänelle,
  minkä työkopion `project.godot` hänen pitää avata.
