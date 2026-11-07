# TopoRotor

Vlieg je topografie: een Godot-game waarin je met een helikopter over Nederland en Europa vliegt om opdrachten van school te oefenen. Met 152 locaties, foto-import, eigen missielijsten, een oefen- en testmodus, hints en lokaal bewaarde scores.

**Status: gereviewd prototype, broncodeversie 0.4.0.** De eerdere Android-APK 0.1.0 bevat de onderstaande reparaties niet. Deze repository bevat broncode en graphics; er is nog geen nieuwe 0.4-APK gebouwd of op een Android-toestel getest.

![TopoRotor vliegmissie](docs/screenshots/preview-flight.png)

## Starten

Installeer **Godot 4.5.1 Standard** (geen .NET nodig), importeer `project.godot` en druk F5. Alle kaartdata, 3D-graphics, fonts en geluiden zijn meegeleverd. Er zijn geen online kaarttegels of game-accounts nodig.

- Kies Nederland of Europa, oefenen of testvlucht en start een vliegmissie.
- Sturen: joystick, WASD of pijltjes. Antwoorden: ‘Hier is het!’ of spatie. H: hints. M: overzicht.
- Je begint **laag en dichtbij**. Gebruik **Lager / Hoger**, het muiswiel of **Q / E** om tussen drie vlieghoogtes te wisselen. Lager toont meer detail; hoger geeft meer zicht op de omgeving. De overzichtskaart (M) blijft apart beschikbaar. Het spel controleert je positie; er is geen landingssimulatie.
- ‘Hangar’ beëindigt een vlucht. Naar de achtergrond schakelen pauzeert de vlucht; bij terugkeer gaat hij verder. De Android-terugknop sluit eerst de foto of vlucht.

## Nederlandse miniatuurwereld

![Amsterdam met grachtenpanden](docs/screenshots/preview-amsterdam.png)

![Rotterdam met haven en brug](docs/screenshots/preview-rotterdam.png)

De referentiestijl is vertaald naar eenvoudige hoekige 3D-modellen, warm licht en water met subtiele beweging. De detailbeelden hierboven gebruiken een vaste opnamecamera; de gewone vlucht heeft de instelbare vlieghoogtes. Modellen worden per kleur samengevoegd, zodat elk raam of elke boom geen afzonderlijke tekenaanroep nodig heeft. Alle graphics blijven lokaal en werken offline.

Alle vijftig Nederlandse steden hebben nu een eigen wijkindeling, verschillende gevels, dakvormen, hoogtes en bebouwingsdichtheid. Historische centra, rivierstadjes, havens, groene woonsteden en moderne steden gebruiken verschillende typen bebouwing. Onder meer Arnhem/Nijmegen (verschillende boogbruggen), Leeuwarden (Oldehove), Groningen (Martinitorenmotief), Maastricht (Maasbrug en kerksilhouet), Den Haag (Hofvijver en hof) en Almere/Lelystad hebben een eigen centrum. De gebouwen, wegen en herkenningspunten blijven schematisch en uitvergroot; dit is geen nauwkeurig 3D-model van de echte stad. De beschikbare globale Natural Earth-bebouwde contouren begrenzen de gegenereerde woonwijken. Voor Sneek ontbreekt dekking en wordt een schematische indeling gebruikt.

### Grenzen op landschap en minikaart

- Op het landschap: neutrale lijnen, met een dikke landsgrens, gestreepte provinciegrenzen en fijnere gestippelde gemeentegrenzen. Gemeentegrenzen verschijnen bij laag/midden vliegen; op grote afstand blijft de kaart rustig. Gebieden op het landschap krijgen **geen provincie- of gemeentekleuren**.
- Alleen de minikaart kleurt de twaalf provincies in. Landsgrenzen zijn goud, provinciegrenzen licht en gemeentegrenzen blauwgrijs. Een legenda verklaart de accenten.
- **Tik of klik op de minikaart** om te wisselen tussen Nederland en de omgeving. De lokale weergave volgt de helikopter en maakt gemeentegrenzen beter leesbaar. Onderaan staat de huidige provincie.
- De gebundelde Nederlandse grensdata omvat twaalf provincies en 342 gemeenten uit de officiële Kadaster/PDOK-laag van 2026. De lijnen zijn vereenvoudigd voor de game. Bronvermelding en licentie zijn ook bereikbaar via **Bronnen en licenties** in de hangar.

![Verschillende stadsopbouw bij Arnhem en Nijmegen](docs/screenshots/preview-arnhem.png)

![Moderne bebouwing in Almere](docs/screenshots/preview-almere.png)

![Lokale minikaart met gekleurde provincies](docs/screenshots/preview-boundaries-local.png)

De decoratieve akkers kunnen worden herbouwd met `uv run --with shapely python tools/build_nl_fields.py`. Shapely is alleen nodig voor dit ontwikkelhulpmiddel, niet voor het spel.

## Schoolwerk

Open **Foto / eigen topo-opdrachten**. Kies een JPG of PNG van maximaal 25 MB en 12 megapixel. Een foto blijft lokaal als referentie; voer de gewenste namen in of gebruik de optionele OCR-service. Voor een eigen locatie:

```
Arnhem
IJsselmeer
Mijn dorp | 52.123 | 5.456
```

Namen mogen ook met komma's worden gescheiden. De app meldt onbekende namen en dubbelzinnige dubbele namen. Europese en Nederlandse plaatsen mogen worden gemengd. Gebruik `Utrecht provincie` / `Groningen provincie` voor provincies, en `Luxemburg land` voor het land.

![Opdrachten en foto](docs/screenshots/preview-photo.png)

OCR is **optioneel en niet standaard gehost**. De eigen service en Dockerfile staan in `ocr-service/`. Deze gebruikt HTTPS en een gedeeld toegangstoken. Het token blijft alleen in appgeheugen. Alleen een druk op ‘Herken tekst uit foto’ verstuurt de afbeelding. De service gebruikt Tesseract via stdin/stdout, zonder tijdelijk werkbladbestand. Zie [OCR-installatie](ocr-service/README.md).

De ouder controleert altijd de herkende locaties. Een kopje zoals ‘Nederland’ kan ten onrechte als opdracht worden toegevoegd. OCR leest tekst; onbenoemde kaarten met alleen nummers of kruisjes worden niet automatisch opgelost.

## Geografie en leren

- Landvragen controleren het landpolygoon op de kaart. Volgens de Nederlandse schooltopografie telt de Krim als Oekraïne, Noord-Cyprus als Cyprus en Åland als Finland.
- Andere vragen controleren een referentiepunt met 6 km tolerantie in Nederland en 25 km in Europa. Provincies, rivieren, eilanden en meren hebben **geen volledige gebieds-/rivierdetectie**. De getekende provinciegrens verandert deze antwoordcontrole niet.
- Natural Earth-contouren zijn grof, vooral rond delta's en kleine eilanden. Europa loopt circa 25°W–45°O en 34°–72°N.
- Velden, bomen, gebouwen en bergen zijn gestileerde decoratie; geen echte hoogte- of landgebruiksdatabase.
- Drie sterren: een foutloze testvlucht zonder hints; twee bij maximaal twee fouten; anders één. Er is nog geen adaptief herhalen of langdurige voortgang per locatie.
- Nederland heeft een kleurrijke miniatuurwereld met grachtenpanden in Amsterdam, de Domtoren, een Rotterdamse haven met vereenvoudigde Erasmusbrug, duinen en gemengd bos. Steden staan op hun cataloguscoördinaten; gebouwen en landschapselementen zijn uitvergroot en symbolisch. Dit is geen nauwkeurige stratenkaart. Europa behoudt de eenvoudigere decoratie.
- Het IJsselmeer/Markermeer is opnieuw uitgesneden met gedetailleerdere meergeometrie; Flevoland, Almere en Lelystad blijven op land.
- Vliegen in Nederland is rustiger gemaakt zodat je tijd hebt om te zoeken. Kindertests en prestaties op echte Android-toestellen blijven nodig.

De meest recente foto, eigen missielijst en beste sterren per regio/modus blijven op het apparaat. Wis appgegevens om die te verwijderen. Ook het verwijderen van de app wist deze gegevens; zie ‘Android bouwen’ voor veilig updaten. Het OCR-token wordt niet opgeslagen.

## Review en controles

De [review van 7 november 2026](docs/REVIEW.md) beschrijft de gevonden fouten, correcties, testresultaten en openstaande punten. In versie 0.2 zijn onder andere touch-emulatie, OCR-toegang, concurrency, beeldlimieten, opslagvalidatie, testisolatie, kaartmarkers en minikaartverversing aangepast.

```
python3 -m venv .venv
.venv/bin/pip install -r ocr-service/requirements.lock.txt -r tests/requirements.txt
.venv/bin/python -m unittest discover -s tests -v
GODOT_BIN=/pad/naar/godot python3 tools/check_godot.py
.venv/bin/pip-audit -r ocr-service/requirements.lock.txt
```

Met Tesseract (`nld` en `eng`) geïnstalleerd draait ook de echte OCR-test:

```
TOPOROTOR_TEST_REAL_OCR=1 .venv/bin/python -m unittest discover -s tests -v
```

GitHub Actions bevat dezelfde backend- en enginechecks, met alleen leesrechten. De nieuwste uitslagen staan onder Actions in GitHub. Een lokale testuitslag is geen uitgevoerde GitHub Actions-run.

## Android bouwen

Het project bevat een Android-exportpreset voor ARM64 met de Compatibility-renderer. Installeer Godot 4.5.1 exporttemplates, OpenJDK 17 en de Android SDK volgens de [Godot-handleiding](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html). Stel de SDK-paden en een eigen debugkeystore in via **Editor Settings → Export → Android**. Exporteer preset **Android** met ‘Export With Debug’ naar `build/TopoRotor-debug.apk`.

De repository bevat geen signing key, tokens of APK's. Android installeert een update alleen over de bestaande app als beide met dezelfde sleutel zijn ondertekend. Gebruik daarom voor alle builds die je verspreidt één vaste keystore. Bewaar die buiten de repository, maak er een back-up van en deel hem niet via git. Alleen dan blijven missielijsten en sterren bij updates en rollbacks behouden.

**Let op:** een build met een andere handtekening (bijvoorbeeld een debugbuild van een andere computer) kan niet over de oude app heen worden geïnstalleerd. De oude app verwijderen wist alle lokaal bewaarde foto's, eigen missielijsten en sterren. Er is nog geen export of synchronisatie. Kopieer vóór het verwijderen de tekst van je eigen missielijst, zodat je die daarna opnieuw kunt invoeren. Behaalde sterren gaan in dat geval verloren. Voor native foto-selectie is Android 10+ bedoeld. Touch, Android-fotopicker, lifecycle, geheugen en prestaties moeten nog op echte telefoons/tablets worden getest.

## Indeling

| Map / bestand | Doel |
|---|---|
| `scripts/main.gd` | Menu, missies, foto-import en OCR-client |
| `scripts/world.gd` | Kaartmeshes, decoratie, markers en landcontrole |
| `scripts/helicopter.gd` | Helikopter en rotoranimatie |
| `scripts/dutch_scenery.gd` | Gebundelde miniatuurgebouwen, Nederlandse herkenningspunten, bomen en reliëf |
| `scripts/worksheet_image.gd` | Beeldheader- en dimensiecontrole vóór pixelallocatie |
| `scripts/progress_store.gd` | Validatie van opgeslagen voortgang |
| `assets/` | Modellen, graphics, fonts en geluiden |
| `data/` | Kaartgeometrie en locatiecatalogus |
| `ocr-service/` | Optionele service, lockfile en Dockerfile |
| `tests/`, `tools/` | API-tests, integratietest en geïsoleerde enginechecks |
| `.github/workflows/ci.yml` | CI voor tests en dependency-audit |

Eigen code en graphics: MIT. Zie [LICENSE](LICENSE), [THIRD-PARTY.md](THIRD-PARTY.md) en de font- en enginelicenties in `assets/`.

## Nieuw: sneller vliegen, tijdrit en online missies

Nederland vliegt nu met 10 in plaats van 4,5 wereldeenheden per seconde;
Europa met 42 in plaats van 24. Besturing en bochten reageren vloeiend,
en loslaten remt sneller af. Kies in de hangar **Vrij vliegen** of **Tijdrit**.
Een tijdrit geeft 90 seconden per locatie voor de hele missie. Tijd pauzeert
wanneer de app naar de achtergrond gaat. Bij nul eindigt de vlucht met het
aantal gevonden locaties; een onvoltooide missie levert geen sterren op.

Met **Online missies** kun je lespakketten laden en offline bewaren zonder een
nieuwe APK. Zie [online missies](docs/ONLINE-MISSIES.md) voor het JSON-formaat.
Zie [APK-builds](docs/ANDROID-BUILDS.md) voor de automatische Android-build,
vaste signing key en downloaden via GitHub Releases.
