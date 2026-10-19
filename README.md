# Catchfish

Kalastussimulaattori Godot 4 -pelimoottorilla. Pelialueena on Raahen
Haapajärven tekoallas, joka on mallinnettu Maanmittauslaitoksen avoimesta
aineistosta. Lähdet soutuveneellä laiturista ja heittelet virvelillä uistinta.

## Käynnistys

1. Asenna [Godot 4.7](https://godotengine.org/download) (tavallinen versio, ei .NET).
2. Avaa Godotissa *Import* → valitse tämän kansion `project.godot`.
3. Paina F5.

Ensimmäinen käynnistys kestää muutaman sekunnin, kun järvi, metsä ja kalat luodaan.

## Ohjaus

| Näppäin | Toiminto |
|---|---|
| W / S | kaasu (moottori) tai soutu eteen/taakse |
| A / D | ohjaus |
| Q | perämoottori käyntiin / sammuksiin (sammuksissa soudetaan) |
| X | ankkuri alas / ylös |
| Hiiri | kameran ja heittosuunnan kääntö, rulla = zoomaus |
| Vasen hiiri | pidä = heittovoima, päästä = heitto; tärpätessä vastaisku; lopuksi haavinta |
| Oikea hiiri | kelaa (Shift = nopeasti) |
| Välilyönti | nykäisy |
| E / C | jarru kireämmälle / löysemmälle |
| L | vaihda uistin |
| R | vetouistelu: heitetty vapa telineeseen ja toinen käteen, tai vapa telineestä käteen |
| T | ajan nopeus (x1 / x10 / x60) |
| Tab | saaliskirja |
| F1 | ohje |
| Esc | tauko |

## Simulaatio lyhyesti

- **Vene**: oma vesifysiikka (työntövoima, vastus, sivuttaisvastus), tuuli
  ajelehdittaa, ankkuri pitää paikallaan, matalikolla vene osuu pohjaan.
- **Aika ja sää**: aurinko liikkuu Raahen leveysasteella kesäkuussa,
  tuuli vaihtelee ja puuskittelee.
- **Uistimet**: uppoavat (lusikka, lippa, jigi) vajoavat levossa nopeasti
  pohjaan ja nousevat vedettäessä hiljalleen, mutta pysyvät pinnan alla.
  Vaaput kelluvat levossa pinnalla ja uivat kelatessa ja uistellessa
  tavoitesyvyydessään. Pohjaa laahaava uistin voi tarttua kiinni.
- **Kalat**: tekoaltaan kalakanta eli ahven, särki, hauki, kiiski, lahna
  ja made. Jokaisella lajilla on oma elinpaikka (syvyys, rannan ja
  kaislikon läheisyys), vuorokausirytmi, vuodenaikarytmi, mieluisat
  uistimet ja uistinnopeus. Hauki ja ahven iskevät uistimiin; särki,
  kiiski, lahna ja made syövät mieluiten syöttiä, eli niitä saa parhaiten
  talvella pilkillä ja toukalla. Made on talven kala ja syö pimeällä. Kalat ovat dataa: niitä ei näe,
  mutta kaikuluotain näyttää ne.
- **Vetouistelu**: veneessä on kaksi vapaa. Heitä uistin veneen perään ja
  paina R, niin vapa menee perälaudan vapatelineeseen ja toinen vapa tulee
  käteen. Kun molemmat vavat ovat telineissä, soutele tai aja moottorilla:
  uistimet kulkevat perässä omassa uintisyvyydessään. Tärpin tullessa vavan
  kärki nykäisee, ja veneen vauhti voi koukuttaa kalan itsestään. R ottaa
  tärppäävän vavan käteen väsytettäväksi.
- **Väsytys**: kala ryntäilee ja lepää, jarru antaa siimaa, liian kireä
  jarru katkaisee siiman ja löysä siima päästää kalan irti. Kalan lajin
  näkee vasta, kun kala tulee tummassa humusvedessä näkyviin veneen
  lähelle tai rimpuilee pinnassa.
- Lajien arvot ovat tiedostossa `scripts/fishing/species.gd` ja uistinten
  `scripts/fishing/lures.gd`.

## Järven data

Valmiiksi käsitelty järvi on kansiossa `assets/lake/`. Sen voi tehdä
uudelleen MML:n aineistosta:

1. Lataa [Karttapaikan](https://asiointi.maanmittauslaitos.fi/karttapaikka/)
   tiedostopalvelusta alueelta *Maastotietokanta, kaikki kohteet* (GeoPackage)
   ja *Korkeusmalli 2 m* (GeoTIFF), koordinaatisto ETRS-TM35FIN.
2. Tallenna ne nimillä `data/mml/maastotietokanta_kaikki.gpkg` ja
   `data/mml/korkeusmalli_2m.tif`.
3. Aja (vaatii Pythonin, NumPyn ja GDALin):

   ```bash
   python3 tools/build_lake.py --mml data/mml
   ```

Rantaviiva tulee maastotietokannan järvikuviosta ja maasto korkeusmallista.
Tekoaltaasta ei ole avointa syvyysaineistoa, joten **syvyys on arvioitu**
etäisyydestä rantaan (enintään 4 m, maatuvilla vesialueilla matalampaa).

Raakadataa ei ole versionhallinnassa (`.gitignore`).

## Lisenssit

Sisältää Maanmittauslaitoksen Maastotietokannan ja Korkeusmalli 2 m
-aineistoa (CC BY 4.0).
