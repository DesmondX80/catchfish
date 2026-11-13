# CATCHFISH-170: Tehokkuus 1/7: Agenttiohjeet ja työtavat (kooste retroista)

v2 klo 10:15 (13.11.2026): päätökset 1–12 sisällytetty

## Tavoite

Kuudentoista retron (93–169) työtapaehdotukset kirjataan pysyviin ohjeisiin
niin, että tiimi ei enää menetä tunteja taustailmoitusten odotukseen,
sekaisiin työkopioihin, tyhjiin testeihin eikä uusiin palautuskierroksiin.
Ohjeet pysyvät lyhyinä, eivätkä tiedostot ole ristiriidassa keskenään.

## Käyttö ja tuloste

Dokumenttitehtävä, pelaajalle ei muutu mitään. Muuttuvat tiedostot:

| Tiedosto | Kuka lukee | Muutos |
|---|---|---|
| `CLAUDE.md` | kaikki (ladataan jokaiseen sessioon ja tiimiläiseen automaattisesti) | uusi osio *Sävy viesteissä* (siirretty agenttitiedostoista), uusi osio *Yhteiset säännöt tiimiläisille*, uusi osio *Työnjohtajan vahti*, *Työnkulku*-kohtiin 1–7 tarkennukset, *Testaus*-osioon aikaraja, kesto ja Windows-ajuri |
| `.claude/agents/designer.md` | designer | suunnitelmapohja päivitetään, esityö ja tarkistus tarkennetaan, *Sävy* ja yhteiset säännöt poistetaan (siirtyvät `CLAUDE.md`:hen) |
| `.claude/agents/koodaaja.md` | koodaaja | aloitus, testin kytkentä, testin laatu, kuvat, luovutus commit-tunnisteella, jäädytys |
| `.claude/agents/testaaja.md` | testaaja | oma irrotettu työkopio, toistoajot, mutaatiot, kutsupolut, testicommitit |
| `docs/plan.md`, *Testaus* | kaikki tarvittaessa | uudet alaosiot: pitkät ajot, toistoajot, mutaatiotarkistus käsin, kuvat (kuvasuhteet, GPU-vuoro, Windows-ajuri), grafiikkavikojen diagnostiikka, CI-lokit, tunnetusti epävakaat testit |
| `docs/plan.md`, *Työtapa* | kaikki | kohtaan 5 `mkdir -p export`, uusi alaosio *Suunnitelman tarkistuslista* |

Pelikoodi, varjostimet, testit ja `tools/` eivät muutu.

## Nykytila

Mitä tiedostoissa on jo nyt (origin/main d1ce22f):

- **Kaikissa kolmessa agenttitiedostossa** sama 47 rivin *Sävy*-osio ja sama
  *Yhteiset säännöt* -kohta (vertaa `origin/main`iin). Lisäksi sama kappale
  "Et jää odottamaan mitään tarkistamatta, että se on oikeasti käynnissä" on
  jokaisessa (designer ja koodaaja *Mitä et tee*, testaaja *Sinun vastuusi*).
- **designer.md (120 riviä):** suunnitelmapohja (Tavoite, Toiminta, Ulkoasu,
  Toteutus, Hyväksymiskriteerit, Avoimet kysymykset Teemulle), kuvatarkistus
  kuvaskripteillä näytönohjaimella, kielto arvata.
- **koodaaja.md (118 riviä):** aloitus vasta hyväksytystä suunnitelmasta,
  oma työkopio, suunnitelman tallennus `docs/suunnitelmat/`, testi + lippu
  `scripts/main.gd` + `tools/run_tests.sh`, raja-arvomuutokset *Päätöksiin*,
  WIP-commit "ajettu: ei", ei koko sarjaa, rebase ja `--ref=origin/main
  --repeat=N` ennen luovutusta, ilmoitus testaajalle/työnjohtajalle/designerille.
- **testaaja.md (101 riviä):** koko sarja `tools/run_tests.sh -q`, työkopio
  "koodaajan työkopio tai oma", `--repeat`/`--ref`-tarkistus epävakaille,
  kriteerit yksitellen, testin olemassaolo ja kytkentä, `git diff
  origin/main...`, talvi/kesä, mutaatiotarkistus tilapäisessä työkopiossa
  (kun ehtoa/rajaa/syötettä muutetaan), raporttimuoto.
- **CLAUDE.md (152 riviä):** worktree per tehtävä, työnkulku 1–8, säännöt,
  GPU-komento ja "yksi ajo kerrallaan", `--repeat`/`--ref`, autotest kohinainen.
  Työnkulun kohta 4: "Koodaaja ... tallentaa sen haaraansa".
- **plan.md, Testaus (rivit 125–200):** `run_tests.sh`-liput, testilista,
  `--audio-log`, autotest. **Työtapa (202–224):** kohdat 0–6, mm. mainin
  Actions-ajon seuranta (kohta 6).

## Lähde-ehdotusten sijoitus

Sarakkeet: **Tila** = uusi / jo ohjeissa / täydennys (osin jo) / muutettu
(ks. ristiriidat) / työkalu tulossa (käsin tehtävä tapa ohjeeseen).
**Grep-avain** = merkkijono, jonka testaaja hakee kohdetiedostosta
(`grep -n -F -e 'avain' tiedosto`; `-e` tarvitaan `--`-alkuisille avaimille). Avaimet on valittu luonnosteksteistä alla.

Lyhenteet: CL = `CLAUDE.md`, DE = `designer.md`, KO = `koodaaja.md`,
TE = `testaaja.md`, PT = `docs/plan.md` *Testaus*, PW = `docs/plan.md` *Työtapa*,
TL = PW:n alaosio *Suunnitelman tarkistuslista*.

| # | Ehdotus (lyhyesti) | Tila | Kohde | Grep-avain |
|---|---|---|---|---|
| 169a | Ei vuoron päättämistä taustatyön varaan; < 10 min etualalla, pidemmät lokista | uusi (yhdistää 155a, 145c, 95) | CL yhteiset | `et päätä vuoroasi` |
| 169b | Uusi testi ei käytä satunnaista säätä, ellei testaa säätä | uusi, työkalu tulossa (`--seed`, CATCHFISH-171) | KO | `satunnaista säätä` |
| 169c | Uusi/muutettu testi `--repeat=10`, tulosrivien luvut verrataan | uusi, toistomäärä PÄÄTÖS 6; työkalu tulossa (CATCHFISH-172) | TE + PT | `--repeat=10` |
| 169d | Deterministiseksi muutetussa testissä mutaatio vakiokriteerinä | täydennys (TE:ssä osin) | DE (TL) + TE | `mutaatiotarkistus on vakiokriteeri` |
| 169e | Vanhat CI-lokit `gh api`:lla; koko sarja noin 15 min | uusi (komento tarkistettu 13.11.) | PT + CL | `actions/jobs/` ja `noin 15 min` |
| 169f | Työnjohtaja tarkistaa lokin ja prosessin 5 min sisällä | uusi (yhdistää 155c, 145c, 95, 107c) | CL vahti | `5 minuutin sisällä` |
| 162a | Kaikki godot-ajot timeout-kääreessä | uusi | CL yhteiset + CL Testaus | `timeout 590` |
| 162b | Mutaatiossa kytketään pois vain korjaus, ei koko tiedoston palautusta | uusi | PT mutaatio | `ei koko tiedoston palautusta` |
| 162c | Oma mutantti jokaiselle varmistuspolulle; elävä mutantti = testiaukko | uusi | TE | `elävä mutantti` |
| 162d | Kynnysarvomuutokset ja mutaation muoto suunnitelmaan, ei vain viestiin | täydennys (raja-arvot jo KO:ssa) | KO | `mutaation muoto` |
| 162e | Toistoskriptien aika `Engine.physics_ticks_per_second`illa (60/s) | uusi | DE + PT diagnostiikka | `physics_ticks_per_second` |
| 162f | Retron jälkeen `git worktree list`, ylimääräiset kopiot pois | uusi | CL työnkulku 7 | `git worktree list` |
| 156a | Kuva- ja UI-tehtävissä luonnos ja mockup ennen hyväksyntää | uusi, PÄÄTÖS 2 (ei odota); mockup-skripti tulossa (CATCHFISH-174) | DE + CL työnkulku 3 | `luonnoskuva ja mockup` |
| 156b | Tarkistuskuvat 16:9, 4:3 ja 21:9 näytönohjaimella | uusi, laajuus PÄÄTÖS 7 | PT kuvat + TL | `2100x900` |
| 156c | Headless-testin tehtävänannossa: pakotetaanko ikkunan koko | uusi | DE pohja | `ikkunan koko` |
| 155a | Taustalle lähtevälle ajolle valmismerkki; tarkistus ennen idleä | uusi, työkalu tulossa (CATCHFISH-172) | CL yhteiset + PT pitkät ajot | `valmismerkki` |
| 155b | Tilaviestit lyhyinä tilariveinä (valmis/kesken/ajo + PID) | uusi (koskee kaikkia) | CL yhteiset | `TILA:` |
| 155c | Työnjohtaja käynnistää oman taustavahdin, kun "sarja käy" | uusi | CL vahti | `taustavahti` |
| 152a | Testaajalle commit-tunniste, ei pelkkä haara | uusi (yhdistää 131a, 111) | KO + TE + CL työnkulku 5 | `commit-tunniste` |
| 152b | Testi ajaa pelin oikean kutsupolun | uusi | KO + TE | `oikean kutsupolun` |
| 152c | Näkyvyyskriteeri kuvakulmittain, ei pelkkä luku | uusi (yhdistää 110a) | TL | `näkyy ylhäältä` |
| 152d | Koodaajan ensimmäiset kuvat designerille ennen laajempia ajoja; suurennos | uusi (yhdistää 107b, 110b), rajaustyökalu tulossa (CATCHFISH-174) | KO + DE | `ensimmäiset kuvat` |
| 152e | Designer kuvaa nykytilan suunnitteluvaiheessa | uusi | DE | `kuvaa nykytila` |
| 152f | Julkaisun alkamisesta viesti koodaajalle ja testaajalle, ei committeja | uusi | CL työnkulku 6 + KO | `julkaisu alkaa` |
| 152g | Välitilan commit vähintään tunnin välein | täydennys (WIP jo KO:ssa; yhdistää 131f) | KO + CL yhteiset | `tunnin välein` |
| 152h | Linjausvaihtoehdot karkeasti speksattuina jo suunnitelmassa | uusi | DE pohja | `karkeasti speksattuna` |
| 145a | Kysymys = pysähdys: ei koko sarjaa eikä kuvia ennen vastausta | uusi | KO | `Kysymys = pysähdys` |
| 145b | Päätösloki suunnitelmaan, `PÄÄTÖS n:`, luetaan ennen committia ja ajoa | uusi | CL yhteiset + CL työnkulku 3 + KO | `PÄÄTÖS n:` |
| 145c | Ei until-silmukoita eikä sokeaa odotusta; inbox ennen > 2 min ajoa; työnjohtaja ListAgents + loki | muutettu (R6, R7) | CL yhteiset + CL vahti | `yli 2 minuutin ajoa` |
| 145d | Jokaiselle "X ennallaan" -kriteerille ja päätökselle oma testirivi | uusi | KO + TL | `ennallaan` |
| 145e | Testaajan testicommit vain haaran kärkeen ja heti viesti koodaajalle | uusi | TE | `haaran kärki` |
| 144a | Numeeriset kriteerit prototyypillä, tulos kriteerin viereen / "ei prototyypattu" | uusi | DE | `ei prototyypattu` |
| 144b | Ristiriitataulukko: paikka → kriteerit → täyttyvätkö yhtä aikaa | uusi | TL | `ristiriitataulukko` |
| 144c | Sivuvaikutuslista grepillä: tarkistettu / ei tarkistettu | uusi | DE | `sivuvaikutuslista` |
| 144d | Prosenttikriteereille mittaustapa: alue, kaava, komento | uusi (yhdistää 131d) | TL | `mittaustapa` |
| 131a | Haara jäädytetään testauksen ajaksi; testaaja tarkistaa `git status`; koodaaja ei muokkaa oman ajon aikana | uusi | KO + TE + CL työnkulku 5 | `jäädytetty` |
| 131b | Koodaaja aloittaa heti: suunnitelmatiedosto + runko + välicommit | uusi (R5, PÄÄTÖS 3) | KO | `ensimmäinen commit` |
| 131c | Suunnitelmaan versiorivi | uusi | DE pohja | `versiorivi` |
| 131d | Numeerisiin kriteereihin mittaustapa ja budjetin ylitys | yhdistetty 144d:hen | TL | `mittaustapa` |
| 131e | Testeihin siirtymätilanteet | uusi (yhdistää 109) | KO + TL | `siirtymätilanteet` |
| 131f | Välicommitit tiheiksi käyttörajan varalta | yhdistetty 152g:hen | KO | `tunnin välein` |
| 111 | Testaaja aina omaan irrotettuun työkopioon `<sha>`:sta; palautukset työnjohtajan kautta | työkopio uusi; palautusosa hylätty (R3, PÄÄTÖS 5) | TE | `--detach ../catchfish-testi-` |
| 110a | Jokaiselle kuvalle kameran suunta, tilanne ja mitä pitää näkyä | uusi (103:n kuvalista samaan) | DE pohja | `kuvalista` |
| 110b | Koodaaja katsoo muutoksen itse suunnitelman kuvakulmasta; GPU-komento KO:hon | uusi (GPU-komento viittauksena CL:ään) | KO | `suunnitelman kuvakulmasta` |
| 109 | Pohjaan ääriolot, tilojen päättyminen ja kappaleiden paikka 3D:ssä | uusi | DE pohja | `Ääriolot` |
| 107a | Koodaaja liittää OK/VIRHE-rivit ja kriteeri → rivi; testaaja greppaa, että tarkistusfunktiot kutsutaan | uusi | KO + TE | `kriteeri → testirivi` |
| 107b | Designer tarkistaa ensimmäiset kuvat jo toteutuksessa | yhdistetty 152d:hen | DE | `ensimmäiset kuvat` |
| 107c | Työnjohtaja tarkistaa, jos tunnin aikana ei committeja eikä ajoja | muutettu: 15 min (R1, PÄÄTÖS 4) | CL vahti | `Hiljaisuus` |
| 96a | Työkalutehtävän pohjassa *Käyttö ja tuloste* | uusi | DE pohja | `Käyttö ja tuloste` |
| 96b | Avoimiin kysymyksiin "oletus, jos ei linjata" | uusi | DE pohja | `oletus, jos ei linjata` |
| 96c | Koodaaja tarkistaa suunnitelman sisällön koodista | uusi | KO | `tarkista suunnitelman sisältö koodista` |
| 96d | Tarkka testimäärä: "kaikki listan testit" | uusi | TL | `kaikki listan testit` |
| 96e | Suunnitelma suoraan haaraan, työkopio jo suunnitteluvaiheessa | uusi (R5) | CL työnkulku 1–2, DE | `jo suunnitteluvaiheessa` |
| 96f | Designer vertaa työkalutehtävän päätetulostetta suunnitelmaan | uusi | DE tarkistus | `päätetuloste` |
| 96g | Rebase ennen luovutusta; testaaja `git log HEAD..origin/main` | rebase jo ohjeissa (KO "Kun olet valmis" 1); testaajan tarkistus uusi | TE | `HEAD..origin/main` |
| 96h | Uuden .gd:n jälkeen import ja `.uid` committiin | uusi | KO | `.uid` |
| 95 | Sarja etualalla 600000 ms; jos taustalla, lue tulos; työnjohtaja 15 min | muutettu (R2, R1) | CL yhteiset + CL vahti | `600000 ms` |
| 93a | Testaaja rikkoo vanhan toiminnan ja varmistaa, että uusi testi kaatuu | täydennys (mutaatio jo TE:ssä muutetuille testeille; nyt myös uudet) | TE | `uusi testi kaatuu` |
| 93b | Poistotehtävissä grep kaikki esiintymät, poikkeukset kriteeriin heti | uusi | TL | `poistotehtävissä` |
| 93c | Avoimet kysymykset kahteen osioon | uusi | DE pohja | `Avoimet kysymykset työnjohtajalle` |
| 93d | Uuden headless-testin kytkentä kerran KO:hon | täydennys (main.gd ja run_tests.sh jo; plan.md-lista ja testitiedoston ajokomento puuttuvat) | KO | `Testaus*-listaan` |
| 93e | Tunnetusti epävakaat testit listaksi | uusi (lista PÄÄTÖS 8) | PT + CL Testaus | `Tunnetusti epävakaat` |
| 93f | `mkdir -p export` ennen Windows-vientiä | uusi | PW kohta 5 | `mkdir -p export` |
| 125a | Varjostinparametrit kesken ajon ilman pelikoodin muutosta | uusi, `--param` tulossa (CATCHFISH-174), yleiskuvaus PÄÄTÖS 10 | PT diagnostiikka | `autoloadeihin` |
| 125b | Grafiikkabugeissa designer varmistaa syyn kokeilemalla kesken ajon | uusi | DE | `kokeilemalla kesken ajon` |
| 125c | Grafiikkabugeissa Teemun kuvakaappaus heti alussa | uusi | DE + CL työnkulku 1 | `kuvakaappaus heti` |
| 125d | WSL-kuvat eivät riitä; näkyvät muutokset myös Windowsin ajurilla | uusi, yhden komennon työkalu tulossa (CATCHFISH-174) | CL Testaus + PT kuvat | `Windowsin ajurilla` |

Työnjohtajan muistitiedostoista pysyviin ohjeisiin:

| Muisti | Tila | Kohde | Grep-avain |
|---|---|---|---|
| no-idle-waiting | 169f/155c:n kanssa samaan | CL vahti | `taustavahti` |
| teammate-inbox-lag | 145b/145c:n kanssa samaan | CL yhteiset | `PÄÄTÖS n:` |
| koodaaja-ei-koko-sarjaa | jo ohjeissa (KO *Mitä et tee*) | – | `Et aja koko testisarjaa` |
| team-round-names | uusi | CL työnkulku 1 | `vanhat tiimiläiset suljetaan` |
| windows-driver-shots | 125d:n kanssa samaan | CL Testaus + PT kuvat | `Windowsin ajurilla` |
| gpu-screenshots | jo ohjeissa (CL Testaus); `render_loop_enabled`-kokeilu kuuluu työkalutehtävään (115) | – | `GALLIUM_DRIVER=d3d12` |

### Ristiriidat ja ratkaisut (uusin retro voittaa)

- **R1 Työnjohtajan tarkistusraja.** 95: tarkistus, jos tiimiläiseltä ei
  kuulu 15 minuuttiin. 107c (uudempi): jos tunnin aikana ei committeja eikä
  testiajoja. 155c ja 169f (uusimmat): heti taustavahti ja tarkistus 5 min
  sisällä *ilmoituksesta*. Ratkaisu: 169f/155c koskevat ilmoitettua ajoa ja
  menevät sellaisinaan. Hiljaisuusraja (ei ilmoitusta lainkaan) on 107c:n
  mukaan 1 h, mutta Johtajan 5.11. toive ("potkia persuuksille aina, jos joku
  ei tee mitään") puoltaa lyhyempää. Ratkaistu: 15 min (PÄÄTÖS 4).
- **R2 Koko sarja etualalla.** 95: `run_tests.sh -q` etualalla 600000 ms:n
  aikarajalla (sarja 6–10 min). 169: alle 10 min etualalla, pidemmät
  lokista; sarja nyt noin 15 min. Bash-työkalun etualan yläraja on 600000 ms,
  joten koko sarja ei mahdu etualalle. 169 voittaa: koko sarja taustalle
  valmismerkillä, ja ajaja seuraa itse.
- **R3 Palautusreitti.** 111: tiimiläiset eivät lähetä palautuksia suoraan
  koodaajalle, vaan työnjohtajan kautta. Nykyinen TE ja CL: raportti
  tekijälle ja työnjohtajalle. 145e ja 152f (uudempia): viestit suoraan
  koodaajalle. 111:n syy (yhteinen työkopio sotki ajot) poistuu omalla
  irrotetulla työkopiolla ja commit-tunnisteella. Ehdotus: raportti suoraan
  koodaajalle ja työnjohtajalle kuten nyt, 111:n palautusosa hylätään
  (PÄÄTÖS 5).
- **R4 Testaajan työkopio.** Nykyinen TE: "siirry hänen työkopioonsa (tai
  tee oma)". 111: aina oma irrotettu. 145e: testaajan testicommit haaran
  kärkeen. Ei todellista ristiriitaa: oma irrotettu kopio, ja testimuutos
  pushataan haaraan vain, jos testattu commit on yhä kärki.
- **R5 Kuka tallentaa suunnitelman.** CL työnkulku 4 ja KO: koodaaja
  tallentaa suunnitelman haaraansa. 96e (uudempi): työnjohtaja luo
  työkopion jo suunnitteluvaiheessa ja designer kirjoittaa sinne. 96e
  voittaa. Koodaaja commitoi suunnitelman ensimmäisenä committinaan (PÄÄTÖS 3).
- **R6 until-silmukat.** 145c: tiimiläisille ei until-silmukoita. Muisti
  no-idle-waiting: työnjohtaja käynnistää until-silmukan taustavahdiksi.
  Eri roolit, ei ristiriitaa: tiimiläinen seuraa itse lokista, työnjohtajan
  pääsessio saa taustatyön päättymisilmoituksen.
- **R7 "Inbox luetaan ennen yli 2 min ajoa".** Tiimiläinen ei voi lukea
  saapuneita viestejä erikseen: ne tulevat seuraavalla työkalukierroksella.
  Muutettu muotoon: ennen yli 2 minuutin ajoa luetaan suunnitelman
  *Päätökset*-osio, johon työnjohtaja kirjaa päätökset (145b).
- **R8 Mutaatiotarkistuksen laajuus.** Nykyinen TE: kun testin ehtoa,
  rajaa tai syötettä muutetaan. 93a: jokaiselle uudelle testille. 169d:
  kun testi muutetaan deterministiseksi. Ei kumoa toisiaan, joten yhdistetään:
  uusi testi, muutettu ehto/raja/syöte ja deterministiseksi muutettu testi.

### Työkalut, joita ei vielä ole

Ohjeeseen kirjataan nykyinen käsin tehtävä tapa ja maininta "työkalu
tulossa (CATCHFISH-nnn)" uuden tehtävän tunnisteella (PÄÄTÖS 12):
171 = `--seed` ja sää-apufunktio, 172 = `run_tests.sh`:n `latest.done` ja
liput, 173 = `mutate.sh`, 174 = GPU-lukko, `--param`, Windows-kuvakomento,
rajaustyökalu ja mockup-skripti. Lippuja tai tiedostoja ei kuvata olemassa
olevina.

| Tuleva työkalu (lähderetro → uusi tehtävä) | Käsin nyt (kirjataan ohjeeseen) |
|---|---|
| `tools/mutate.sh` (161, 114, 100 → 173) | PT *Mutaatiotarkistus käsin*: tilapäinen työkopio, yksi muutos, `git diff` todistaa osuman, ajo aikarajalla, poisto |
| `.test-logs/latest.done` (168 → 172) | ajo `run_in_background`-tilassa komennolla `...; echo "exit=$? $(date +%T)" > <scratchpad>/<ajo>.done`, tai `grep '^Läpi ' .test-logs/latest.log` |
| `--repeat` näyttää vaihtelleet rivit (168 → 172) | `grep -E '^(OK\|VIRHE)' .test-logs/latest.log \| sort \| uniq -c` (tarkistettu 13.11. shopbgtestillä: jokainen rivi 2 kertaa, kun `--repeat=2`) |
| `--seed` (166), testien sää-apufunktio (165) → 171 | sää pysäytetään testissä kuten `tests/boat_test.gd` ja `tests/motor_speed_test.gd`: `weather.set_process(false)`, `gust`, `_wind_target` (ja tarvittaessa `wind_base`) nollaan; säätilan vaihtoa testaavissa `_change_in = INF` (`tests/pressure_test.gd`) |
| GPU-lukko (130 → 174) | ennen ikkuna-ajoa `pgrep -af godot \| grep -v -- --headless` on tyhjä |
| `--param` varjostinuniformeille (130 → 174) | PT *Grafiikkavikojen diagnostiikka*: yleiskuvaus, käynnistysskripti + oma Node-skripti (PÄÄTÖS 10) |
| Windows-kuvat yhdellä komennolla (151 → 174) | PT *Kuvat Windowsin ajurilla*: kopio Windowsin TEMP-kansioon, import, ajo, siivous |
| Kuvien rajaus ja kontrasti (124, 130 → 174) | lähempi kamera kuvaskriptissä tai suurempi `--resolution`; oma rajausskripti scratchpadiin |
| Mockup-apuskripti (156 → 174) | luonnos ja mockup scratchpad-skriptillä kuten CATCHFISH-84:ssä |

## Luonnostekstit

Asiallinen kieli, suomeksi. Koodaaja saa hioa sanamuotoja, kunhan grep-avain
ja sisältö säilyvät. Kaikki avoimet kysymykset on ratkaistu (*Päätökset* 1–12).

### CLAUDE.md, *Agenttitiimi* → *Työnkulku* (muutettavat kohdat)

1. **Tehtävä** (lisäys loppuun): "Työnjohtaja luo työkopion
   (`git worktree add -b claude/<aihe> ../catchfish-<aihe> origin/main`)
   jo suunnitteluvaiheessa ja antaa polun designerille. Uudella
   tiimikierroksella vanhat tiimiläiset suljetaan ensin ja tehtävänannossa
   nimetään nykyiset tiimiläiset. Grafiikkavioissa työnjohtaja pyytää
   Teemulta kuvakaappauksen heti alussa."
2. **Suunnittelu** (lisäys): "Designer kirjoittaa suunnitelman suoraan
   työkopioon `docs/suunnitelmat/<tunniste>.md`."
3. **Hyväksyntä** (lisäys): "Jokainen päätös kirjataan heti suunnitelman
   *Päätökset*-osioon muodossa `PÄÄTÖS n: …`, ja päätösviestin ensimmäinen
   rivi on sama. Kuva- ja UI-tehtävissä designerin luonnoskuva ja mockup
   liitetään Planeen hyväksytyn suunnitelman mukana; toteutus ei odota
   niiden kuittausta."
4. **Toteutus** (korvaa "tallentaa sen haaraansa"): "Koodaaja jatkaa samassa
   työkopiossa, commitoi suunnitelmatiedoston ensimmäisenä committinaan
   ja kirjoittaa testin. Designer ei commitoi."
5. **Testaus** (lisäys ja korvaus): "Koodaaja luovuttaa commit-tunnisteen, ja
   haara on jäädytetty testaajan raporttiin asti. Testaajan ja designerin
   raportti menee suoraan koodaajalle ja työnjohtajalle."
6. **Julkaisu** (lisäys): "Työnjohtaja ilmoittaa koodaajalle ja testaajalle,
   kun julkaisu alkaa; sen jälkeen haaraan ei commitoida."
7. **Retro** (lisäys): "Lopuksi `git worktree list`, ja tiimiläisten
   ylimääräiset työkopiot poistetaan."

### CLAUDE.md, uusi alaosio *Yhteiset säännöt tiimiläisille* (Säännöt-osion jälkeen)

```
### Yhteiset säännöt tiimiläisille

Koskevat designeria, koodaajaa ja testaajaa. Roolikohtaiset ohjeet:
`.claude/agents/`.

- Vertaa aina `origin/main`iin (`git fetch` ensin), älä paikalliseen `main`iin.
- Päätökset ovat suunnitelman *Päätökset*-osiossa (`PÄÄTÖS n: …`). Viestit
  tulevat perille vasta seuraavalla työkalukierroksella, joten lue
  *Päätökset* ennen jokaista commitia ja ennen jokaista yli 2 minuutin ajoa.
- Tilaviesti alkaa tilarivillä, esim. `TILA: valmis`, `TILA: kesken`,
  `TILA: ajo käynnissä (PID 1234, loki .test-logs/latest.log)`,
  `TILA: odottaa vastausta (kysymys 2)`.
- Pitkät ajot: et päätä vuoroasi odottamaan taustatyötä. Alle 10 minuutin
  ajot etualalla (Bash-aikaraja 600000 ms). Pidempi ajo, esim. koko sarja
  (noin 15 min), taustalle valmismerkillä, ja seuraat sitä itse lokista
  (`docs/plan.md`, *Testaus* → *Pitkät ajot*). Ennen idle-tilaa tarkistat
  jokaisen käynnistämäsi ajon valmismerkin ja luet valmiin tuloksen.
- Et jää odottamaan mitään tarkistamatta, että se on oikeasti käynnissä
  (`ps`, lokin muutosaika). Jos ajo on loppunut tai sitä ei ole, lue tulos
  tai aja uudelleen ja jatka heti.
- Suora Godot-ajo aina aikarajalla: `timeout 590 godot-4.7.2 ...`.
  `tools/run_tests.sh`:ssä aikaraja on valmiina (600 s testiä kohti).
- Kesken jäävä työ commitoidaan vähintään tunnin välein (välitila/WIP), jotta
  käyttörajan katkaisema työ jatkuu suoraan haarasta.
```

### CLAUDE.md, uusi alaosio *Sävy viesteissä* (PÄÄTÖS 1)

Nykyinen *Sävy*-osio siirretään agenttitiedostoista sanasta sanaan
(neljä kohtaa, esimerkit, rajat) `CLAUDE.md`:n *Agenttitiimi*-osioon
otsikolla `### Sävy viesteissä`. Sisältöä ei lievennetä. Muutetaan vain
johdanto: "Koskee kaikkia tiimiläisiä ja työnjohtajaa." Kolmannen kohdan
loppu "Työnjohtajaakin saa piikitellä." säilyy. Rajat-kohta "Tiedostoihin
kirjoitettava teksti on asiallista ..." säilyy sellaisenaan, ja se koskee
myös `CLAUDE.md`:tä ja `.claude/agents/`-tiedostoja.

### CLAUDE.md, uusi alaosio *Työnjohtajan vahti*

```
### Työnjohtajan vahti

- Kun lähetät tiimiläiselle työtä, varmista pian, että se alkoi
  (tiedostojen muutosajat, `ps`, ListAgents).
- Kun tiimiläinen ilmoittaa ajon käyvän tai odottavansa ajoa, tarkista
  prosessi ja loki itse 5 minuutin sisällä ja käynnistä oma taustavahti
  (Bash `run_in_background`, until-silmukka lokin `Läpi n/m`-riville tai
  prosessin päättymiselle). Kun vahti laukeaa, patista tiimiläistä heti.
  Tiimiläiselle taustailmoitus ei tule luotettavasti.
- Hiljaisuus: jos tiimiläiseltä ei tule viestiä, committia, tiedostomuutosta
  eikä testiajoa 15 minuuttiin, tarkista tila ja patista.
```

### CLAUDE.md, *Testaus* (lisäykset)

- "Suora Godot-ajo aikarajalla (`timeout 590 ...`). Koko sarja kestää
  paikallisesti noin 15 min, joten se ajetaan taustalle valmismerkillä
  (`docs/plan.md`, *Testaus* → *Pitkät ajot*)."
- "Näkyvät varjostin- ja grafiikkamuutokset varmistetaan myös Windowsin
  ajurilla WSL-interopilla (`docs/plan.md`, *Testaus* → *Kuvat Windowsin
  ajurilla*). WSL:n D3D12-kuvat eivät yksin riitä: CATCHFISH-120:n korjaus
  toimi WSL:ssä mutta ei Windowsissa."
- "Tunnetusti epävakaat testit: `docs/plan.md`, *Testaus*."

### designer.md (uusi runko)

- *Sävy* poistetaan; tilalle yksi rivi: "Sävy viesteissä: `CLAUDE.md`,
  *Agenttitiimi* → *Sävy viesteissä* (koskee jokaista viestiä)."
- *Yhteiset säännöt* poistetaan; tilalle yksi rivi: "Yhteiset säännöt:
  `CLAUDE.md`, *Yhteiset säännöt tiimiläisille*."
- *Suunnitelma*:

```
Ennen kirjoittamista:
- Tutki koodi (`scripts/`, `docs/plan.md` *Arkkitehtuuri lyhyesti*) ja tee
  sivuvaikutuslista: muutetun asian käyttäjät grepillä, kukin merkittynä
  tarkistettu / ei tarkistettu.
- Näkyvissä tehtävissä kuvaa nykytila jo suunnitteluvaiheessa; luvut otetaan
  kuvista. Kuva- ja UI-tehtävissä tee luonnoskuva ja mockup; työnjohtaja
  liittää ne Planeen hyväksytyn suunnitelman mukana, eikä toteutus odota.
- Grafiikkavioissa pyydä työnjohtajalta Teemun kuvakaappaus heti ja
  varmista syy kokeilemalla kesken ajon ennen suunnitelmaa (`docs/plan.md`,
  *Testaus* → *Grafiikkavikojen diagnostiikka*).
- Prototyyppaa jokainen numeerinen kriteeri pelin omalla laskennalla ja
  interpoloinnilla; aika `Engine.physics_ticks_per_second`illa (60
  askelta/s). Kirjaa tulos kriteerin viereen tai merkintä "ei prototyypattu".

Kirjoita suunnitelma suoraan työnjohtajan antamaan työkopioon
`docs/suunnitelmat/<tunniste>.md`. Käy ennen lähettämistä läpi
`docs/plan.md`, *Työtapa* → *Suunnitelman tarkistuslista*.
```

Suunnitelmapohja (korvaa nykyisen):

```
# <tunniste>: <otsikko>
v1 klo HH:MM   (versiorivi, päivittyy joka muutoksessa)

## Tavoite
## Toiminta pelaajan kannalta
Näppäimet, säännöt, luvut. Ääriolot: miten pelaaja päätyy tilanteeseen
(ajoitus, vauhti, tuuli, syvyys), mikä päättää jokaisen tilan ja
odotusehdon ja mitä ulkoiset voimat tekevät sille, missä liikkuvat
kappaleet ovat veneeseen nähden joka vaiheessa.
(Työkalutehtävissä tilalle ## Käyttö ja tuloste: komento, esimerkkituloste,
paluukoodit.)
## Ulkoasu ja äänet
Kuvalista: jokaiselle kuvalle kamera (suunta, korkeus, etäisyys), tilanne
ja mitä kuvassa pitää näkyä.
## Toteutus pääpiirteissään
Myös: pakotetaanko headless-testissä ikkunan koko, ja muutokseen liittyvät
nykyiset testit nimeltä.
## Hyväksymiskriteerit
## Avoimet kysymykset Teemulle
## Avoimet kysymykset työnjohtajalle
Jokaisessa kysymyksessä vaihtoehdot karkeasti speksattuna (luvut, ulkoasu)
ja kenttä "oletus, jos ei linjata".
## Päätökset
(työnjohtaja täyttää: PÄÄTÖS n: …)
```

- *Tarkistus toteutuksen aikana ja jälkeen* (korvaa nykyisen):

```
- Tarkista koodaajan ensimmäiset kuvat heti, kun ominaisuus näkyy, älä vasta
  julkaisun kynnyksellä.
- Kuvat koodaajan työkopiossa valmiilla kuvaskripteillä näytönohjaimella
  (lista ja kuvasuhdekomennot: `docs/plan.md`, *Testaus*). Grafiikkamuutokset
  myös Windowsin ajurilla.
- Katso PNG:t Read-työkalulla ja vertaa kuvalistaan kuva kuvalta.
- Äänimuutokset: aja testi `--audio-log`-lipulla ja vertaa `[ääni]`-rivejä
  suunnitelmaan.
- Työkalutehtävät: vertaa päätetulostetta *Käyttö ja tuloste* -osioon.
- Palaute koodaajalle ja työnjohtajalle: mikä kuva, mikä poikkeaa, mitä
  ehdotat.
```

(99:n äänitarkistus ei ole tämän tehtävän lähdelistalla; rivi pidetään,
PÄÄTÖS 9.)

- *Mitä et tee*: nykyiset kolme kohtaa; "Et jää odottamaan" poistetaan
  (siirtyy yhteisiin sääntöihin).

### koodaaja.md (muutettavat osiot)

- *Sävy* ja *Yhteiset säännöt* → yhden rivin viittaukset `CLAUDE.md`:hen kuten
  designerilla.
- *Milloin aloitat* (lisäys): "Jatkat työnjohtajan luomassa työkopiossa.
  Tarkista ensin suunnitelman sisältö koodista (esim. ominaisuus, joka on jo
  poistettu pelistä) ja kysy ristiriidoista. Ensimmäinen commit heti:
  designerin kirjoittama suunnitelmatiedosto ja toteutuksen runko, ei pitkää
  lukemista ilman muutoksia."
- *Sinun vastuusi* (lisäykset ja korvaukset):

```
- Uuden headless-testin kytkentä: `tests/<nimi>_test.gd` (ajokomento
  tiedoston alkuun), lippu `scripts/main.gd`, `tools/run_tests.sh`
  (jos ei vaadi ikkunaa) ja `docs/plan.md`:n *Testaus*-listaan. Uuden
  .gd-tiedoston jälkeen aja `godot-4.7.2 --headless --import` ja lisää
  syntynyt `.uid` committiin.
- Testi ajaa pelin oikean kutsupolun (esim. `boat.gd` kutsuu, ei irrallinen
  olio), kattaa siirtymätilanteet eikä vain tasaisia tiloja, ja jokaisella
  "ennallaan"-kriteerillä ja päätöksellä on oma testirivi.
- Uusi testi ei käytä satunnaista säätä, ellei se testaa nimenomaan säätä:
  pysäytä sää kuten `tests/boat_test.gd` (`weather.set_process(false)`,
  puuskat ja tuulikohde nollaan). Siemenlippu ja yhteinen sääapu tulossa (CATCHFISH-171).
- Kynnysarvojen ja syötteiden muutokset sekä mutaation muoto kirjataan
  suunnitelman *Päätöksiin*, ei vain viestiin.
- Näkyvissä muutoksissa katso muutos itse suunnitelman kuvakulmasta
  näytönohjaimella (komento: `CLAUDE.md`, *Testaus*), suurenna pieniä
  yksityiskohtia (lähempi kamera tai suurempi `--resolution`) ja lähetä
  ensimmäiset kuvat designerille ennen laajempia testiajoja.
- Kysymys = pysähdys: kun kysyt dataa tai kriteereitä muuttavaa asiaa, et aja
  laajoja testejä etkä kuvia ennen vastausta, vain kohdennettuja kokeiluja.
- Et muokkaa tiedostoja oman testiajosi aikana.
```

- *Kun olet valmis* (muutokset):
  - kohta 3: "Ilmoita testaajalle ja työnjohtajalle commit-tunniste
    (`git rev-parse --short HEAD`), haara, työkopion polku, testin OK/VIRHE-
    rivit ja kartta kriteeri → testirivi, ajetut testit ja käsin
    kokeiltavat."
  - uusi kohta: "Haara on jäädytetty testaajan raporttiin asti: ei
    committeja eikä työkopion muutoksia. Kun työnjohtaja ilmoittaa, että
    julkaisu alkaa, et commitoi haaraan."
  - "Kesken jäävä työ" -kohta täydennetään: "vähintään tunnin välein".
  - Poistetaan nykyinen kohta "Tallennat hyväksytyn suunnitelman haaraasi
    tiedostoon `docs/suunnitelmat/<tunniste>.md`" (R5, PÄÄTÖS 3).

### testaaja.md (muutettavat osiot)

- *Sävy* ja *Yhteiset säännöt* → viittaukset `CLAUDE.md`:hen. "Et jää odottamaan"
  -kohta poistetaan (yhteinen).
- *Sinun vastuusi* (korvaa ensimmäisen kohdan):

```
- Testaat aina omassa irrotetussa työkopiossa koodaajan ilmoittamasta
  commitista: `git fetch && git worktree add --detach
  ../catchfish-testi-<aihe> <sha>` ja kerran `godot-4.7.2 --headless
  --import`. Raportti koskee tätä commit-tunnistetta.
- Ennen jokaista ajoa `git status` on puhdas ja `git log --oneline
  HEAD..origin/main` tyhjä; jos ei, palauta rebasettavaksi.
- Koko sarja `tools/run_tests.sh -q` (noin 15 min) taustalle valmismerkillä
  (`docs/plan.md`, *Testaus* → *Pitkät ajot*).
```

- Lisäykset:

```
- Uusi tai muutettu testi ajetaan ennen hyväksyntää `--repeat=10`:llä, jos
  se kestää alle 60 s, muuten `--repeat=3`:lla, ja tulosrivien luvut
  verrataan, ei pelkkää läpi-lukua (komento: `docs/plan.md`, *Testaus* →
  *Toistoajot*). Pitkä toistoajo taustalle valmismerkillä muun työn rinnalla.
- Mutaatiotarkistus (`docs/plan.md`, *Testaus* → *Mutaatiotarkistus käsin*)
  jokaiselle uudelle testille, muutetulle ehdolle, rajalle tai syötteelle ja
  deterministiseksi muutetulle testille: varmista, että uusi testi kaatuu
  oikealla viallisella käytöksellä. Oma mutantti jokaiselle
  varmistuskoodipolulle (esim. askeleen lopun clamp); elävä mutantti on
  testiaukko ja palautuksen syy.
- Tarkista, että testi ajaa pelin oikean kutsupolun ja että jokaista
  testitiedoston tarkistusfunktiota myös kutsutaan (grep funktion nimellä),
  ja vertaa koodaajan karttaa kriteeri → testirivi.
- Jos muutat testejä, commitoi testatun commitin päälle ja pushaa vain, jos
  se on yhä haaran kärki (`git push origin HEAD:claude/<aihe>`), ja ilmoita
  heti koodaajalle.
```

- Nykyinen mutaatiokohta korvautuu yllä olevalla (ei kahta mutaatio-ohjetta).
- *Raportti*: ensimmäinen rivi "**Hyväksytty** tai **Palautettu**, commit
  `<sha>`". Raportti suoraan koodaajalle ja työnjohtajalle (kuten nyt, PÄÄTÖS 5).

### docs/plan.md, *Testaus* (uudet alaosiot testilistan ja `--audio-log`-kappaleen jälkeen)

```
### Pitkät ajot

Koko sarja kestää paikallisesti noin 15 min (otherboatstest yksinään noin
4–6 min). Alle 10 minuutin ajot etualalla (Bash-aikaraja 600000 ms).
Pidempi ajo Bashin `run_in_background`-tilassa valmismerkillä:

  tools/run_tests.sh -q; echo "exit=$? $(date +%T)" > <scratchpad>/sarja.done

Tila: `cat <scratchpad>/sarja.done` tai `grep '^Läpi ' .test-logs/latest.log`
(`latest.log` osoittaa työkopion uusimpaan ajoon). Taustailmoitukseen ei
luoteta. Valmismerkki `.test-logs/latest.done` tulossa (CATCHFISH-172).

### Toistoajot

Uusi tai muutettu testi: `--repeat=10`, jos testi kestää alle 60 s, muuten
`--repeat=3`. Pitkä toistoajo taustalle valmismerkillä (*Pitkät ajot*).

  tools/run_tests.sh -q --repeat=10 NIMI
  grep -E '^(OK|VIRHE)' .test-logs/latest.log | sort | uniq -c

Deterministisessä testissä jokainen rivi esiintyy N kertaa (N = toistot).
Jos rivin luvut vaihtelevat, sama tarkistus näkyy useana eri rivinä.
Vaihtelevien rivien yhteenveto `--repeat`iin tulossa (CATCHFISH-172).

### Mutaatiotarkistus käsin

  mut=$(mktemp -d) && git worktree add --detach "$mut" HEAD
  cd "$mut" && timeout 590 godot-4.7.2 --headless --import >/dev/null
  # kytke pois vain korjaus tai varmistus (yksi muutos), ei koko tiedoston palautusta
  git diff        # todistaa, että mutaatio osui oikeaan riviin
  tools/run_tests.sh -q NIMI     # testin pitää kaatua
  cd - && git worktree remove --force "$mut"

Mutaatio on oikea viallinen käytös, jota testin pitäisi vahtia, ei lievä
heikennys. Muoto kirjataan suunnitelman *Päätöksiin*. Työkalu
`tools/mutate.sh` tulossa (CATCHFISH-173).

### Kuvat

- Näytönohjainkomento: `CLAUDE.md`, *Testaus*. Yksi ikkuna-ajo kerrallaan
  koko koneella: ennen aloitusta `pgrep -af godot | grep -v -- --headless`
  on tyhjä. GPU-lukko tulossa (CATCHFISH-174).
- Kuvasuhteet: UI-, HUD- ja valikkomuutokset kaikilla kolmella, pelkät
  3D-muutokset 16:9:llä. Godotin `--resolution` ennen `--`-erotinta:
  `--resolution 1600x900` (16:9), `--resolution 1200x900` (4:3),
  `--resolution 2100x900` (21:9).

### Kuvat Windowsin ajurilla

WSL-interop, Windowsin oma NVIDIA-ajuri:

  win="$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")/catchfish-win"
  gw="/mnt/c/Program Files (x86)/Godot/Godot_v4.7.2-stable_win64_console.exe"
  rsync -a --delete --exclude .git --exclude .godot --exclude .test-logs ./ "$win/"
  "$gw" --headless --path "$(wslpath -w "$win")" --import
  "$gw" --path "$(wslpath -w "$win")" --fixed-fps 30 --disable-vsync -- --day=180 --watershots="$(wslpath -w "$win/kuvat")"
  rm -rf "$win"   # kun kuvat on katsottu

Lokin `OpenGL API` -rivillä pitää lukea NVIDIA. Ennen grafiikkakorjauksen
julkaisua sama kuvaskripti ajetaan myös viedyllä exellä. Yhden komennon
työkalu tulossa (CATCHFISH-174).

### Grafiikkavikojen diagnostiikka

- Teemun kuvakaappaus heti alussa.
- Syy varmistetaan kokeilemalla kesken ajon ennen suunnitelmaa:
  varjostinparametrit vaihdetaan käynnistysskriptillä, joka lisää puuhun
  oman Node-skriptin (SceneTree-skriptistä ei voi viitata autoloadeihin).
  `--param`-lippu tulossa (CATCHFISH-174).
- Toisto- ja mittausskripteissä aika lasketaan
  `Engine.physics_ticks_per_second`illa (60 askelta/s), ei ruutujen
  määrästä.

### CI-lokit

  gh run list --workflow Testit -L 5
  gh run view <run> --json jobs -q '.jobs[].databaseId'
  gh api "repos/{owner}/{repo}/actions/jobs/<job>/logs"

`gh run view --log-failed` antaa vanhoista ajoista tyhjää.

### Tunnetusti epävakaat testit

Korjataan tehtävässä CATCHFISH-171; testi poistetaan listalta, kun se on
korjattu. Työnjohtaja pitää listan ajan tasalla.

- pressuretest
- sonartest
- motorspeedtest (peruutusnopeus)
- boattest ("jalat veneen sisällä kalastaessa")
- anchortest (tuulinosto)
- settingstest (jumi ikkunassa)

Listattujen kaatuminen tarkistetaan `--repeat`illa, mutta niitä ei verrata
mainiin joka kerta erikseen.
```

### docs/plan.md, *Työtapa*

- Kohta 5: "Uudesta työkopiosta puuttuu `export/` (`.gitignore`), joten
  `mkdir -p export` ennen Windows-vientiä."
- Uusi alaosio:

```
### Suunnitelman tarkistuslista

Designer käy tämän läpi ennen lähettämistä; testaaja voi käyttää sitä
kriteerien arviointiin.

- Jokaisella numeerisella kriteerillä on mittaustapa: mistä mitataan,
  alue, kaava, poissuljetut kohdat, komento, ja mitä tehdään, jos
  suorituskykybudjetti ei riitä. Tulos prototyypistä tai "ei prototyypattu".
- Näkyvyys kuvakulmittain ("näkyy ylhäältä ja sivulta"), ei pelkkä luku.
- Ristiriitataulukko, kun samaan paikkaan kohdistuu useita kriteereitä:
  paikka → kriteerit → täyttyvätkö yhtä aikaa.
- Siirtymätilanteet (esim. löysä → kireä siima), ei vain tasaiset tilat.
- Jokainen "X ennallaan" on nimetty ja testattavissa.
- Testimäärä: "kaikki listan testit", ei arvioitua lukua; muutokseen
  liittyvät nykyiset testit nimeltä.
- Poistotehtävissä grep-kriteeri kaikille esiintymille ja poikkeukset heti
  listaan (uusi testi, `docs/suunnitelmat/`, edistymiskirjaus).
- Testimuutoksissa (uusi testi, muutettu raja/syöte, deterministiseksi
  muutettu) mutaatiotarkistus on vakiokriteeri.
- UI-, HUD- ja valikkotehtävissä tarkistuskuvat 16:9, 4:3 ja 21:9; pelkät
  3D-muutokset 16:9.
```

## Tiiviys ja pituustavoitteet

Agenttitiedostot luetaan joka käynnistyksessä, `CLAUDE.md` joka sessiossa.
Pitkät menettelyt (komentoreseptit, tarkistuslista) siirretään `docs/plan.md`:hen,
ja agenttitiedosto viittaa niihin osion nimellä.

*Sävy* siirtyy `CLAUDE.md`:hen (PÄÄTÖS 1).

| Tiedosto | Nyt | Tavoite |
|---|---|---|
| `designer.md` | 120 | ≤ 80 |
| `koodaaja.md` | 118 | ≤ 80 |
| `testaaja.md` | 101 | ≤ 70 |
| `CLAUDE.md` | 152 | ≤ 245 |
| `plan.md` *Testaus* (otsikosta seuraavaan `## `-otsikkoon) | 76 | ≤ 170 |
| `plan.md` *Työtapa* (sama) | 23 | ≤ 50 |
Yhteiset säännöt ovat vain `CLAUDE.md`:ssä, eivät kolmena kopiona.

## Hyväksymiskriteerit

1. Jokaisen *Lähde-ehdotusten sijoitus* -taulukon rivin grep-avain löytyy
   kohdetiedostosta (`grep -n -F -e 'avain' tiedosto`; `-e` tarvitaan `--`-alkuisille avaimille), tai rivi on merkitty
   "jo ohjeissa" ja avain löytyy nykyisestä tekstistä, tai rivillä on
   *Päätöksissä* kirjattu hylkäys ja syy. Testaaja ajaa kaikki rivit ja
   kirjaa raporttiin poikkeamat.
2. Rivimäärät (`wc -l`; plan.md:n osiot `sed -n '/^## Testaus/,/^## /p'`
   ja vastaavasti *Työtapa*) ovat *Tiiviys*-taulukon tavoitteissa.
3. Yhteiset säännöt yhdessä paikassa: `grep -c 'Vertaa aina' .claude/agents/*.md`
   antaa 0 jokaiselle, ja `CLAUDE.md`:ssä on osio *Yhteiset säännöt
   tiimiläisille*. "Et jää odottamaan" esiintyy vain `CLAUDE.md`:ssä.
   *Sävy*: `grep -c 'Kunnon kiroilu' .claude/agents/*.md` antaa 0
   jokaiselle, `CLAUDE.md`:ssä on otsikko *Sävy viesteissä*, ja sen
   sisältö vastaa vanhaa osiota (`git show origin/main:.claude/agents/designer.md`
   vertailuna: neljä kohtaa, neljä esimerkkiä ja rajat ovat mukana,
   ainoa muutos johdannossa). Jokaisessa agenttitiedostossa on viittaus
   *Sävy viesteissä* -osioon.
4. Ei ristiriitoja: `testaaja.md`:ssä ei lue "siirry hänen työkopioonsa";
   `koodaaja.md` ja `CLAUDE.md` eivät käske koodaajaa tallentamaan
   suunnitelmaa (R5); koko sarjan kesto on kaikkialla "noin 15 min"
   (`grep -rn '25 min\|6–10 min' CLAUDE.md .claude docs/plan.md` ei osu
   ohjeteksteihin); aikarajat ovat 600000 ms / `timeout 590` / 600 s
   kaikkialla samoin; mutaatio-ohje on testaajalla vain yhdessä kohdassa.
5. Tulevat työkalut: jokainen maininta `latest.done`, `mutate.sh`, `--seed`,
   `--param`, GPU-lukko on samalla rivillä tai virkkeessä merkitty "tulossa"
   oikealla tunnisteella (PÄÄTÖS 12: 171 `--seed`/sääapu, 172 `latest.done`,
   173 `mutate.sh`, 174 GPU-lukko/`--param`/Windows-komento/rajaus/mockup)
   (`grep -n -e 'latest.done' -e 'mutate.sh' -e '--seed' -e '--param' -e 'GPU-lukko'`
   ja katselmointi). Vanhoja lähderetrotunnisteita (CATCHFISH-161, -166,
   -168, -130, -151, -124) ei käytetä työkaluviittauksina.
   `tools/run_tests.sh`:lle ohjeissa mainitaan vain olemassa olevat liput
   (`-q`, `--repeat=N`, `--ref=REF`, `--log=`).
6. Viittaukset pitävät: jokainen ohjeissa mainittu tiedosto on olemassa
   (`tests/boat_test.gd`, `tests/motor_speed_test.gd`, `tests/pressure_test.gd`,
   `scripts/main.gd`, `tools/run_tests.sh`), ja jokainen viitattu osion nimi
   (*Pitkät ajot*, *Toistoajot*, *Mutaatiotarkistus käsin*, *Kuvat*,
   *Kuvat Windowsin ajurilla*, *Sävy viesteissä*,
   *Grafiikkavikojen diagnostiikka*, *CI-lokit*, *Tunnetusti epävakaat
   testit*, *Suunnitelman tarkistuslista*, *Yhteiset säännöt
   tiimiläisille*, *Työnjohtajan vahti*) löytyy otsikkona.
7. Käsikomennot toimivat: testaaja ajaa (a) *Toistoajot*-reseptin
   lyhyellä testillä (esim. `shopbgtest`, `--repeat=2`), (b)
   *Mutaatiotarkistus käsin* -reseptin yhdellä mutaatiolla, joka kaataa
   testin (työkopio poistuu lopuksi, `git worktree list` siisti), (c)
   *CI-lokit*-komennot yhdelle ajolle. Designer ajaa yhden kuvaskriptin
   `--resolution 1200x900`-lipulla näytönohjaimella ja tarkistaa, että PNG
   on 1200×900. Designer ajaa *Kuvat Windowsin ajurilla* -reseptin kerran
   (yksi `--watershots-only`-kuva, lokissa NVIDIA, väliaikaiskansio
   poistettu); poikkeava polku tai import korjataan reseptiin ennen
   hyväksyntää (PÄÄTÖS 11).
7b. Tunnetusti epävakaiden lista `docs/plan.md`:ssä on täsmälleen PÄÄTÖS 8:n
   kuusi testiä ja viittaa CATCHFISH-171:een.
8. Agenttitiedostojen frontmatter (`name`, `description`, `tools`) on
   ennallaan (`head -5 .claude/agents/*.md`).
9. Pelikoodi ei muutu: `git diff --stat origin/main...` listaa vain
   `CLAUDE.md`, `.claude/agents/*.md`, `docs/plan.md` ja
   `docs/suunnitelmat/CATCHFISH-170.md`. Testisarjaa ei tarvitse ajaa.
10. Tiedostoihin kirjoitettu uusi teksti on asiallista (ei kiroilua *Sävy*-osion
    ulkopuolella) ja suomeksi.

## Avoimet kysymykset Johtajalle

Ratkaistu: J1 → PÄÄTÖS 1, J2 → PÄÄTÖS 2.

**J1. Sävy-osion paikka ja pituus.** Sama 47 rivin osio on kolmena kopiona,
ja se on noin 40 % jokaisesta agenttitiedostosta.
- A: ennallaan jokaisessa tiedostossa.
- B: yksi kopio `CLAUDE.md`:hen (*Agenttitiimi* → *Sävy viesteissä*), joka
  ladataan jokaiselle tiimiläiselle automaattisesti; agenttitiedostoissa
  yhden rivin viittaus. Koskee silloin myös työnjohtajaa.
- C: jokaisessa tiedostossa, mutta lyhennettynä: neljä sääntöä, rajat ja
  kaksi esimerkkiä (noin 22 riviä).

Oletus, jos ei linjata: A (sävyyn ei kosketa).

**J2. Kuva- ja UI-tehtävien luonnos ja mockup (156a).** `CLAUDE.md` sanoo,
ettei suunnitelma odota Teemun erillistä hyväksyntää. 156 ehdottaa, että
Teemu näkee luonnoksen ja mockupin ennen hyväksyntää.
- A: kuva- ja UI-tehtävissä (uudet kuvat, paneelit, valikot, HUD) suunnitelma
  odottaa, että Teemu on nähnyt luonnoksen ja mockupin ja kuitannut ne.
- B: luonnos ja mockup liitetään Planen kommenttiin hyväksytyn suunnitelman
  mukana, mutta toteutus ei odota.
- C: luonnos ja mockup vain, kun suunnitelmassa on ulkoasua koskeva avoin
  kysymys Teemulle (ne ovat silloin vaihtoehtojen kuvitus).

Oletus, jos ei linjata: B (nykyinen "ei odota" -sääntö pysyy).

## Avoimet kysymykset työnjohtajalle

Ratkaistu: T1–T10 → PÄÄTÖKSET 3–12.

**T1. Kuka commitoi suunnitelmatiedoston?** Designer kirjoittaa sen
työkopioon (96e). Vaihtoehdot: koodaaja ensimmäisenä committinaan (131b)
tai designer heti valmistuttuaan.
Oletus: koodaaja; designer ei commitoi.

**T2. Hiljaisuusraja (R1).** 15 min (95) vai 1 h (107c) ilman viestiä,
committia, tiedostomuutosta ja testiajoa.
Oletus: 15 min (sopii Johtajan 5.11. toiveeseen).

**T3. Palautusreitti (R3).** Testaajan ja designerin raportti suoraan
koodaajalle ja työnjohtajalle (nyt) vai vain työnjohtajalle (111).
Oletus: suoraan molemmille; 111:n palautusosa hylätään, syy kirjataan
*Päätöksiin*.

**T4. `--repeat=10` pitkille testeille.** otherboatstest 10 kertaa vie
40–60 min. Vaihtoehdot: aina 10; tai 10, kun testi kestää alle 60 s, muuten 3.
Oletus: aina 10 uudelle tai muutetulle testille, mutta testaaja saa ajaa sen
rinnakkain muiden tarkistusten kanssa (taustalla valmismerkillä).

**T5. Kuvasuhteiden laajuus (156b).** Kaikki näkyvät tehtävät vai vain
UI/HUD. Oletus: UI-, HUD- ja valikkomuutokset kolmella kuvasuhteella,
pelkät 3D-muutokset 16:9:llä.

**T6. Tunnetusti epävakaiden testien lista.** Oletus: anchortest ja
sonartest (CATCHFISH-165:n mukaan), poistetaan listalta, kun 165 on tehty.

**T7. Lähdelistan ulkopuolinen äänirivi (99).** Pidetäänkö designerin
tarkistuksessa rivi `--audio-log`-vertailusta? Oletus: pidetään (yksi
rivi), ja 99:n muut osat jäävät omaan tehtäväänsä.

**T8. Varjostinparametrien resepti (125a).** Tarkkaa toimivaa reseptiä ei
ole repossa (CATCHFISH-120:n suunnitelmissa ei ole). Vaihtoehdot: työnjohtaja
tai Johtaja antaa sen; tai ohjeeseen yleiskuvaus ja `--param`-viittaus.
Oletus: yleiskuvaus.

**T9. Windows-reseptin tarkistus.** Resepti ajaa Godotin Windowsin
puolella ja kirjoittaa Windowsin TEMP-kansioon. Ajetaanko se tässä
tehtävässä kerran oikeasti (designer, yksi `--watershots-only`-kuva)?
Oletus: ajetaan kerran; jos polku tai import poikkeaa, resepti korjataan
ennen hyväksyntää.

**T10. Tulevien työkalujen tunnisteet.** Ohjeissa viitataan lähderetron
numeroon (esim. CATCHFISH-168). Jos tehokkuustehtävillä 2–7 on omat
tunnisteet, viitataanko niihin? Oletus: lähderetron numero.

## Päätökset

- **PÄÄTÖS 1 (J1, Johtaja 13.11.):** B. *Sävy*-osio siirretään yhtenä kopiona
  `CLAUDE.md`:hen (*Agenttitiimi* → *Sävy viesteissä*), ja se koskee myös
  työnjohtajaa. Agenttitiedostoihin jää yhden rivin viittaus. Pituustavoitteet
  ovat *Tiiviys*-taulukon J1 = B -sarakkeen mukaiset. Sävyn sisältöä ei
  lievennetä siirrossa.
- **PÄÄTÖS 2 (J2, Johtaja 13.11.):** B. Kuva- ja UI-tehtävissä luonnos ja
  mockup liitetään Planeen hyväksytyn suunnitelman mukana, eikä toteutus
  odota.
- **PÄÄTÖS 3 (T1, työnjohtaja):** oletus. Koodaaja commitoi suunnitelman
  ensimmäisenä committinaan, eikä designer commitoi.
- **PÄÄTÖS 4 (T2, työnjohtaja):** 15 min.
- **PÄÄTÖS 5 (T3, työnjohtaja):** raportit suoraan koodaajalle ja
  työnjohtajalle. 111:n palautusosa hylätään, koska sen syy (yhteinen
  työkopio) poistuu testaajan omalla irrotetulla kopiolla.
- **PÄÄTÖS 6 (T4, työnjohtaja):** poikkeaa oletuksesta tehokkuuden vuoksi.
  Uusi tai muutettu testi ajetaan `--repeat=10`:llä, jos se kestää alle
  60 s, ja muuten `--repeat=3`:lla. Molemmissa tulosrivien luvut verrataan.
  Pitkä toistoajo ajetaan taustalla valmismerkillä muun työn rinnalla.
- **PÄÄTÖS 7 (T5, työnjohtaja):** oletus. UI-, HUD- ja valikkomuutokset
  tarkistetaan kuvasuhteilla 16:9, 4:3 ja 21:9, pelkät 3D-muutokset 16:9:llä.
- **PÄÄTÖS 8 (T6, työnjohtaja):** lista on CATCHFISH-171:n alitehtävien
  mukainen: pressuretest, sonartest, motorspeedtest (peruutusnopeus),
  boattest ("jalat veneen sisällä kalastaessa"), anchortest (tuulinosto) ja
  settingstest (jumi ikkunassa). Testi poistetaan listalta, kun CATCHFISH-171
  on korjannut sen.
- **PÄÄTÖS 9 (T7, työnjohtaja):** oletus. Äänirivi pidetään.
- **PÄÄTÖS 10 (T8, työnjohtaja):** oletus. Ohjeeseen yleiskuvaus ja viittaus
  tulevaan `--param`-lippuun.
- **PÄÄTÖS 11 (T9, työnjohtaja):** oletus. Designer ajaa Windows-reseptin
  kerran oikeasti testausvaiheessa.
- **PÄÄTÖS 12 (T10, työnjohtaja):** poikkeaa oletuksesta. Lähderetrot on
  suljettu (*Cancelled*, yhdistetty), joten viitataan uusiin tehtäviin:
  `--seed` ja sää-apufunktio → CATCHFISH-171; `latest.done` ja run_tests.sh:n
  liput → CATCHFISH-172; `mutate.sh` → CATCHFISH-173; GPU-lukko, `--param`,
  Windows-kuvakomento, rajaustyökalu ja mockup-skripti → CATCHFISH-174.
- **PÄÄTÖS 13 (työnjohtaja, designerin tarkistus):** korjataan kaksi huomiota
  ennen hyväksyntää: (a) `designer.md`:n viittaukseen polku "*Testaus* →
  *Grafiikkavikojen diagnostiikka*", (b) *Sävy viesteissä* -osion rajoihin
  `CLAUDE.md` ja `.claude/agents/` asiallisina tiedostoina. Rivimäärät eivät
  nouse. Korjaukset tehdään samassa erässä testaajan löydösten kanssa.
- **PÄÄTÖS 14 (työnjohtaja, testaajan suositukset):** samaan korjauserään
  (S1) *Mutaatiotarkistus käsin*: resepti ajetaan yhtenä Bash-kutsuna, koska
  cwd ja muuttujat eivät säily kutsujen välillä; (S2) `koodaaja.md`: pushatun
  haaran rebasen jälkeen `git push --force-with-lease`, eikä rebase-palautus
  laske kahden palautuskierroksen rajaan. Rivirajat pysyvät; tarvittaessa
  karsitaan samasta tiedostosta.
- **PÄÄTÖS 15 (työnjohtaja, julkaisu):** PÄÄTÖS 8:n listalta poistetaan
  pressuretest ja motorspeedtest, koska CATCHFISH-160 teki niistä
  deterministiset (`docs/plan.md`, #160: luvut joka ajolla samat). Listalle jäävät
  sonartest, boattest, anchortest ja settingstest.
