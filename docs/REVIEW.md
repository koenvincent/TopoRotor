# Review TopoRotor — 7 november 2026

## Oordeel

De aangeleverde 0.1-versie is een speelbaar technisch prototype, geen afgeronde kinderapp. Er waren concrete risico's in Android-bediening, beeldverwerking, de OCR-service en testisolatie. Die zijn in broncodeversie 0.2 aangepakt en met gerichte regressietests gecontroleerd. Device-validatie en een nieuwe APK ontbreken nog.

## Bevindingen en herstel

| ID | Prioriteit | Bevinding in 0.1 | Herstel in 0.2 | Validatie |
|---|---|---|---|---|
| R01 | Hoog | `emulate_mouse_from_touch=false`. Godot BaseButton verwerkt muisknoppen/acties, niet rechtstreeks ScreenTouch; menu- en antwoordknoppen konden op Android onbruikbaar zijn. | Touch-naar-muis-emulatie ingeschakeld; joystick blijft eigen touch-events gebruiken. | Configuratie en Godot-enginebron gecontroleerd. Nog geen fysieke Android-test. |
| R02 | Hoog | `/extract` accepteerde uploads zonder authenticatie; iedere bereikbare client kon OCR starten. | Fail-closed bearer-token, minimaal 32 bytes, constant-time vergelijking. App heeft een gemaskeerd tokenveld en volgt geen redirects. | Tests voor ontbrekende configuratie en ongeautoriseerde aanvragen; geen OCR gestart bij 401. |
| R03 | Hoog | Een async route deed afbeeldingsdecodering en blokkerende Tesseract-OCR op de eventloop. Tijdens OCR kon de dienst andere aanvragen niet tijdig afhandelen. | Werk naar threadpool; maximaal twee gelijktijdige uploads/herkenningen; upload- en OCR-timeouts. | Twee geblokkeerde OCR-taken laten `/health` reageren en een derde upload krijgt 429. |
| R04 | Hoog | De privacyclaim ‘geen foto op schijf’ klopte niet volledig: `pytesseract` schrijft bij een PIL-image een tijdelijk werkbladbestand. | `pytesseract` vervangen door Tesseract stdin/stdout met subprocess-timeout; PNG-pixels in een geheugenbuffer. | Aanroep met stdin gecontroleerd; echte Tesseract-test op het voorbeeldwerkblad geslaagd. |
| R05 | Hoog | De app las de volledige foto vóór de bytecontrole en decodeerde vóór een pixellimiet. De service decodeerde eveneens vóór de eigen dimensiecontrole. | Bestandsgrootte vóór lezen; PNG/JPEG-headercheck en 12 MP-limiet vóór decode. Server heeft byte-/pixelgrenzen vóór OCR. | Tests voor afmetingen, PNG/JPEG-headers, afgekapt/corrupt beeld en byte-/pixeloverschrijding. |
| R06 | Middel | Rooktests gebruikten echte appvoortgang en konden via missievoltooiing scores/mute-instellingen opslaan. | Rooktestmodus slaat niets op en laadt geen spelprofiel; runner gebruikt een tijdelijk profiel. | Enginecheck verifieert behoud van bestaande voortgangsbytes/bestandstatus. |
| R07 | Middel | Willekeurige JSON-velden uit voortgang werden samengevoegd. Verkeerde typen konden de UI of het spel breken. | Schema-/bereikvalidatie, veilige defaults, punten/landcodes gecontroleerd en atomair vervangen van het opslagbestand. JSON-getallen worden correct terug naar sterren omgezet. | Corrupte data en een echte JSON-roundtrip met geldige/ongeldige sterren getest. |
| R08 | Middel | Een laat OCR-antwoord kon de missielijst overschrijven nadat de ouder de lijst al had aangepast of een andere foto koos. | Snapshotcontrole, annuleren bij andere foto/start/sluiten en validatie van antwoordtypen/omvang. | Late OCR-antwoorden en ongeldige kandidaten overschrijven bestaande invoer niet. |
| R09 | Middel | Nederland-locaties behalve Amsterdam werden op Europa verborgen; eigen punten kregen geen label. Gemengde opdrachten konden daardoor geen volledige hints tonen. | Actieve missielocaties krijgen altijd een marker; dubbele namen worden gemeld. | Gemengde eigen-punt/Parijs-missie en markers gecontroleerd in de engine. |
| R10 | Middel | De minikaart werd iedere frame volledig opnieuw opgebouwd/getrianguleerd, ook als alleen de helikopter bewoog. | Statische kaart in een eigen drawlaag; alleen de navigatie-overlay wordt tijdens vliegen ververst. | Rendercheck en visuele controle op desktop. Nog geen Android-performanceprofiel. |
| R11 | Middel | Achtergebleven hintknoptekst kon niet overeenkomen met een nieuwe vluchtmodus. | Hinttekst wordt bij het starten van iedere vlucht opnieuw ingesteld. | Visuele controle van oefenvlucht. |
| R12 | Hoog | De oude runtimepins leverden bij audit bevindingen op voor Pillow en Starlette. | Directe dependencies bijgewerkt, `pytesseract` verwijderd, runtime-lockfile toegevoegd en dependency-audit in CI. | `pip-audit` op de nieuwe lockfile: geen bekende bevindingen op de reviewdatum. Dit is geen garantie voor alle code/dependencies. |
| R13 | Middel | Er was geen CI; bestaande tests dekten slechts drie naamherkenningsgevallen. Oude APK/buildbestanden konden als actuele bronversie in Git belanden. | 13 backend-/integratietests, uitgebreide Godot-regressies, CI met alleen leesrechten, checksum voor engine-download en gepinde action-commits. APK's, keystores, omgevingsbestanden en caches uitgesloten. | Lokaal uitgevoerd; GitHub Actions nog niet op GitHub gestart. |

Bron voor R01: [Godot 4.5.1 BaseButton](https://github.com/godotengine/godot/blob/4.5.1-stable/scene/gui/base_button.cpp). Dit is broncodeanalyse, geen gereproduceerde fysieke telefoontest.

## Uitgevoerde controles

- Godot 4.5.1: projectimport en engine-regressies geslaagd. Inclusief catalogus, onbekende namen, coördinaten, landdetectie, missievoltooiing, eigen punten, opslagvalidatie/-isolatie, beeldheaders en late OCR.
- Backend: **13 tests geslaagd**, inclusief auth, formaat-/beeldlimieten, enginefouten, concurrency, kandidaatnamen en echte OCR met Nederlands/Engels op het voorbeeldwerkblad.
- OpenGL-rendering onder Xvfb/Mesa: hangar, vliegscherm en foto-/tokenformulier gerenderd en bekeken. Paneelhoogte en startknop gecontroleerd.
- Runtime-lockfile: dependency-audit zonder bekende kwetsbaarheden op 7 november 2026.
- Git-workflow en exportpreset voorbereid. Nieuwe Android-APK niet gebouwd; CI nog niet op GitHub uitgevoerd; Docker-image niet gebouwd.

## Nog open

1. **Android-toesteltest:** menu/touch met meerdere vingers, foto-picker, toetsenbord, focus/backknop, EXIF-orientatie, notch/safe areas, geheugen en framerate. Aanpassing R01 moet op een fysiek toestel worden bevestigd.
2. **Volwaardige topografieopdrachten:** provinciegrenzen en gebiedsdetectie, riviertrajecten, routes, nummerkaarten en antwoordbladen ontbreken. Provincies/wateren/eilanden zijn nu referentiepunten.
3. **Leerwaarde en spelbalans:** toleranties van 6/25 km zijn ruim; geen langdurige voortgang per plaats, adaptief herhalen of analyse van foutpatronen. Laat een kind met echte opdrachten proefspelen.
4. **Visuele afwerking:** huidige kaart is een eenvoudige maquette; labels kunnen overlappen. Geen cockpit, echt terrein of uitgebreide vluchtfysica.
5. **Distributie:** eigen release-signing, nieuwe APK/AAB, device-matrix en gecontroleerde releaseprocedure. De oude 0.1-APK bevat deze reparaties niet.
6. **Eigen OCR-uitrol:** HTTPS/reverse proxy, secrets en toegang op je eigen omgeving instellen. De meegeleverde service wordt niet automatisch gehost.
7. **GitHub:** repository moet privé op het persoonlijke, geverifieerde account worden gemaakt. Zolang GitHub niet gekoppeld is, is er geen remote repository of push bevestigd.

## Herkomst

Reviewbasis: `TopoRotor-v0.1.zip` van 3 oktober 2026. SHA256 van de oorspronkelijke APK: `bfd032dda8e57429d15edb16eec6f99e05e84b9de91d36cb3503437c93fd91cc`. Dit is uitsluitend herkomstinformatie; geen actuele 0.2-build of attestatie.
