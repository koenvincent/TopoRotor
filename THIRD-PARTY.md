# Bronnen en licenties

- **Godot Engine 4.5.1**: MIT. Enginebinary in de Android-APK. Licentietekst in `assets/GODOT-LICENSE.txt`. https://godotengine.org/license/
- **Natural Earth**: public domain. Administratieve landcontouren, rivieren en meren uit `ne_50m_admin_0_countries`, `ne_50m_rivers_lake_centerlines` en `ne_50m_lakes`, gedownload 3 oktober 2026, uitgesneden en vereenvoudigd voor deze game. De standaardlaag volgt de feitelijke situatie; voor de landcontrole rekent `scripts/world.gd` de Krim tot Oekraïne, Noord-Cyprus tot Cyprus en Åland tot Finland (Nederlands standpunt / schooltopografie). https://www.naturalearthdata.com/about/terms-of-use/ ; https://github.com/nvkelso/natural-earth-vector
- **DejaVu Sans**: fontlicentie zie `assets/FONT-LICENSE.txt`. https://dejavu-fonts.github.io/
- **Tesseract OCR** (optionele service, direct via stdin/stdout aangeroepen): Apache 2.0. https://github.com/tesseract-ocr/tesseract
- **FastAPI**: MIT; **Uvicorn**: BSD-3-Clause; **Pillow 13**: MIT-CMU. Dit zijn optionele pip-/Docker-afhankelijkheden, niet de Android-app. Hun distributies bevatten de betreffende licenties.

Helikoptermesh, logo, stedendecoratie, landschapsdecoratie, rotor- en succesgeluid zijn voor dit project gemaakt. De catalogus bevat handmatig samengestelde WGS84-punten op stads-/gebiedsniveau; geen adresgeocoder.

Nederlandse meeruitsnede bijgewerkt op 7 november 2026 uit **Natural Earth 1:10m lakes**, feature `IJsselmeer` (`ne_id=1159126631`), [bronbestand op revisie ace5fed0eaf3c6c03c951e75b439ba8fffbc218e](https://github.com/nvkelso/natural-earth-vector/blob/ace5fed0eaf3c6c03c951e75b439ba8fffbc218e/geojson/ne_10m_lakes.geojson). Public domain. Vereenvoudigd met behoud van polders/eilanden; ontwikkelimport via `tools/import_nl_lakes.py`.

Herkenningspunten zijn zelfgemaakte symbolische modellen. Geografische referenties: [Amsterdamse grachtengordel (UNESCO)](https://whc.unesco.org/en/urban-heritage-atlas/Amsterdam/), [Domtoren (gemeente Utrecht)](https://erfgoed.utrecht.nl/verhalen/domtoren), [Erasmusbrug (gemeente Rotterdam)](https://www.rotterdam.nl/oeververbindingen), [Veluwe (Staatsbosbeheer)](https://www.staatsbosbeheer.nl/uit-in-de-natuur/locaties/veluwe) en [Zuid-Limburgs heuvellandschap (Staatsbosbeheer)](https://www.staatsbosbeheer.nl/wat-we-doen/natuurbeheer/heuvellandschap). Er zijn geen modellen, textures of pixels uit de aangeleverde stijlreferentie overgenomen.
