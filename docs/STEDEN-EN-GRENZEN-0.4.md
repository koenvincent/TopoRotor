# Steden en grenzen — 0.4

Vijftig Nederlandse steden gebruiken eigen gegenereerde wijkindelingen in plaats van hetzelfde twaalf-huizenblok. Gevels, daktypen, hoogtes en dichtheid verschillen. Historische centra, rivierstadjes, havens, groene woonsteden en moderne steden hebben verschillende profielen. Extra silhouetten zijn onder andere de Oldehove, Martinitoren, boogbruggen bij Arnhem/Nijmegen, een Maasbrug en basiliekmotief bij Maastricht, het Hofvijver-/hofmotief bij Den Haag en een waterpoort bij Sneek.

De bestaande stadsankers blijven behouden. Globale Natural Earth-bebouwde contouren begrenzen waar mogelijk de gegenereerde woonwijken. Deze contouren zijn geen actuele straat- of gebouwregistratie; wegen en gebouwen zijn schematisch, herkenningspunten zijn uitvergroot. Sneek gebruikt een expliciet gedocumenteerde fallback wegens ontbrekende dekking.

De Nederlandse grenslagen komen uit Kadaster/PDOK Bestuurlijke Gebieden 2026: twaalf provincies en 342 gemeenten. Gedeelde randen zijn ontdubbeld en vereenvoudigd. Op de grote kaart staan uitsluitend neutrale grenslijnen met verschillende diktes en patronen. Gemeentegrenzen verschijnen bij laag/midden vliegen. Het landschap wordt niet bestuurlijk ingekleurd.

De minikaart heeft provincie-invulling, goudkleurige landsgrenzen, lichte provinciegrenzen en blauwgrijze gemeentegrenzen. Klikken/tikken wisselt tussen Nederland en de omgeving. De huidige provincie staat onder de kaart. Achtergrondgeometrie wordt gecachet; de navigatiemarkers verversen los daarvan. In lokale weergave wordt de achtergrond pas na verplaatsing opnieuw gecentreerd.

Bronvermelding: Kadaster NL, CC BY 4.0. Attribution staat zichtbaar op de minikaart en onder Bronnen en licenties in de hangar. Uitgebreide bron- en bewerkingsvermelding staat in THIRD-PARTY.md en de gebundelde JSON.

## Validatie

- Godot 4.5.1: import en volledige bestaande smoke-tests geslaagd. Toegevoegd: alle vijftig steden hebben een niet-lege unieke indeling, alle drie grenslagen zijn aanwezig, twaalf provinciegebieden zijn geladen en de lokale minikaart kan weer terug naar het overzicht.
- Gerenderde beelden gecontroleerd op Apple M4 met de Compatibility-renderer: gameplay, laag/midden/hoog, lokale minikaart, elf verschillende stadscentra, hangar, credits, foto-invoer en Europa.
- Geen backendwijzigingen of extra runtime-afhankelijkheden. Shapely wordt alleen gebruikt om de gebundelde data tijdens ontwikkeling te genereren.
- git diff --check geslaagd. Mobiele aanraking, FPS en batterijverbruik moeten nog op een echt Android-toestel worden gecontroleerd.
