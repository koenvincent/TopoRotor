# TopoRotor 0.3 — Nederland, vlieghoogtes en kwaliteitsfixes

Nederland heeft een kleurrijke miniatuurwereld met symbolische Nederlandse herkenningspunten, gemengd bos, windmolens, duinen en laag reliëf in Zuid-Limburg. De camera begint dichtbij; Lager/Hoger, Q/E en het muiswiel schakelen tussen drie vlieghoogtes. Hoogtewijzigingen veranderen de missie of locatie niet. M toont nog steeds de overzichtskaart. De Nederlandse kruissnelheid is verlaagd voor rustig zoeken.

Het IJsselmeer en Markermeer gebruiken Natural Earth 10m-geometrie, vereenvoudigd met behoud van Flevoland. Almere en Lelystad liggen op land. De stadscentra blijven de cataloguscoördinaten gebruiken. Decoratieve straten, gebouwen en terrein zijn symbolisch en uitvergroot; dit is geen actuele topografische kaart of hoogtebestand.

De aangeleverde quality-review-general.patch is verwerkt: onder meer versievaste voortgang, echte opslagtests met een apart profiel, behoud van missies bij pauzeren, terugknop, EXIF-rotatie, OCR-lijst samenvoegen, retries en specifieke foutmeldingen, readiness/healthcheck, meerdere tokens, API-/catalogusversie en de aangepaste landcontrole. De nieuwe response-schema's zijn ook verwerkt in de bestaande concurrencytests. Namen langer dan 120 tekens worden bij invoer afgewezen, zodat ze na herstart niet verdwijnen.

## Gecontroleerd

- Godot 4.5.1: projectimport en smoke-tests geslaagd, inclusief nieuwe controles op Flevoland, zichtbaarheid van namen en wisselen van vlieghoogte zonder teleportatie of missiereset.
- Werkelijk gerenderde beelden op Apple M4 / OpenGL Compatibility gecontroleerd: laag/midden/hoog, Amsterdam, Utrecht, Rotterdam, hangar, foto-invoer en Europa. De vastgezette detailcamera's zijn alleen voor de screenshots.
- Lokale Python 3.12-testomgeving met FastAPI, Pillow en HTTPX: 14 tests geslaagd, 1 echte OCR-test overgeslagen omdat Tesseract met Nederlands/Engels lokaal ontbreekt. De volledige lockfile kon lokaal niet worden opgelost door de beschikbare package-index; GitHub CI voert de gepinde omgeving en echte OCR uit.
- git diff --check geslaagd.

Er is geen nieuwe Android-APK gebouwd: Android SDK/build-tools ontbreken hier. Aanraakbediening, fotopicker, pauzeren, prestaties en energieverbruik moeten nog op een echt toestel worden getest. Voor veilig updaten blijft dezelfde ondertekeningssleutel nodig; zie README.
