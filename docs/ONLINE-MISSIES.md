# Online lesinhoud

Open **Online missies** in de hangar. Plak een HTTPS-link naar een JSON-bestand,
kies **Missies ophalen**, selecteer een pakket en start. De gekozen modus Leren, Oefenen of Records geldt ook voor online missies.
Elke online route bewaart in Records zijn eigen beste tijd.

Voorbeeld: `content/missions.json`. Zet dit bestand op een publiek bereikbare
HTTPS-server, bijvoorbeeld GitHub Pages. Een private GitHub raw-link is zonder
authenticatie niet beschikbaar voor het spel. Er worden geen GitHub-tokens in
de game opgeslagen. De URL wordt momenteel per sessie ingevoerd.

```json
{
  "version": 1,
  "missions": [
    {"title": "Randstad", "places": ["Amsterdam", "Utrecht", "Rotterdam"]}
  ]
}
```

Pas online de titels en plaatsnamen aan om nieuwe opdrachten aan te bieden;
hiervoor is geen nieuwe APK nodig. Namen moeten in de huidige locatiecatalogus
staan. Nieuwe coördinaten, kaarten en graphics zijn nog onderdeel van de app.
Een beheerwebsite en upload van foto's op afstand zijn nog niet aanwezig.

De game bewaart het laatst volledig geldige bestand lokaal voor offline gebruik.
Een mislukte download of ongeldig pakket vervangt de vorige missies niet.
HTTPS, geen redirects, maximaal 256 KiB, 100 missies en 100 locaties per missie.
De app downloadt alleen JSON-gegevens en voert geen online scripts uit.
Een pakket met onbekende locaties wordt met een melding geweigerd.
