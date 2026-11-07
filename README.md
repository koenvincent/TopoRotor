# TopoRotor

Vlieg je topografie: een Godot-game waarin je met een helikopter over Nederland en Europa vliegt om opdrachten van school te oefenen. Met 152 locaties, foto-import, eigen missielijsten, een oefen- en testmodus, hints en lokaal bewaarde scores.

**Status: gereviewd prototype, broncodeversie 0.2.0.** De eerdere Android-APK 0.1.0 bevat de onderstaande reparaties niet. Deze repository bevat broncode en graphics; er is nog geen nieuwe 0.2-APK gebouwd of op een Android-toestel getest.

![TopoRotor vliegmissie](docs/screenshots/preview-flight.png)

## Starten

Installeer **Godot 4.5.1 Standard** (geen .NET nodig), importeer `project.godot` en druk F5. Alle kaartdata, 3D-graphics, fonts en geluiden zijn meegeleverd. Er zijn geen online kaarttegels of game-accounts nodig.

- Kies Nederland of Europa, oefenen of testvlucht en start een vliegmissie.
- Sturen: joystick, WASD of pijltjes. Antwoorden: ‘Hier is het!’ of spatie. H: hints. M: overzicht.
- De hoogte blijft automatisch gelijk. Het spel controleert je positie; er is geen landingssimulatie.
- ‘Hangar’ beëindigt een vlucht. Een app die naar de achtergrond gaat keert terug naar de hangar.

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

- Landvragen controleren het landpolygoon op de kaart.
- Andere vragen controleren een referentiepunt met 6 km tolerantie in Nederland en 25 km in Europa. Provincies, rivieren, eilanden en meren hebben **geen volledige gebieds-/rivierdetectie**. Provinciegrenzen ontbreken.
- Natural Earth-contouren zijn grof, vooral rond delta's en kleine eilanden. Europa loopt circa 25°W–45°O en 34°–72°N.
- Velden, bomen, gebouwen en bergen zijn gestileerde decoratie; geen echte hoogte- of landgebruiksdatabase.
- Drie sterren: een foutloze testvlucht zonder hints; twee bij maximaal twee fouten; anders één. Er is nog geen adaptief herhalen of langdurige voortgang per locatie.
- De huidige vormgeving is een eenvoudige kaartmaquette. Verdere visuele afwerking, balans en kindertests zijn volgende stappen.

De meest recente foto, eigen missielijst en beste sterren per regio/modus blijven op het apparaat. Wis appgegevens om die te verwijderen. Het OCR-token wordt niet opgeslagen.

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

GitHub Actions bevat dezelfde backend- en enginechecks, met alleen leesrechten. De workflow is voorbereid; een lokale testuitslag is geen uitgevoerde GitHub Actions-run.

## Android bouwen

Het project bevat een Android-exportpreset voor ARM64 met de Compatibility-renderer. Installeer Godot 4.5.1 exporttemplates, OpenJDK 17 en de Android SDK volgens de [Godot-handleiding](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html). Stel de SDK-paden en een eigen debugkeystore in via **Editor Settings → Export → Android**. Exporteer preset **Android** met ‘Export With Debug’ naar `build/TopoRotor-debug.apk`.

De repository bevat geen signing key, tokens of APK's. Een eigen build kan een andere handtekening hebben dan de oude testapp; verwijder die dan eerst. Voor native foto-selectie is Android 10+ bedoeld. Touch, Android-fotopicker, lifecycle, geheugen en prestaties moeten nog op echte telefoons/tablets worden getest.

## Indeling

| Map / bestand | Doel |
|---|---|
| `scripts/main.gd` | Menu, missies, foto-import en OCR-client |
| `scripts/world.gd` | Kaartmeshes, decoratie, markers en landcontrole |
| `scripts/helicopter.gd` | Helikopter en rotoranimatie |
| `scripts/worksheet_image.gd` | Beeldheader- en dimensiecontrole vóór pixelallocatie |
| `scripts/progress_store.gd` | Validatie van opgeslagen voortgang |
| `assets/` | Modellen, graphics, fonts en geluiden |
| `data/` | Kaartgeometrie en locatiecatalogus |
| `ocr-service/` | Optionele service, lockfile en Dockerfile |
| `tests/`, `tools/` | API-tests, integratietest en geïsoleerde enginechecks |
| `.github/workflows/ci.yml` | CI voor tests en dependency-audit |

Eigen code en graphics: MIT. Zie [LICENSE](LICENSE), [THIRD-PARTY.md](THIRD-PARTY.md) en de font- en enginelicenties in `assets/`.
