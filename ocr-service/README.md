# Eigen OCR-service

De game werkt offline zonder deze service: importeer een foto en voer de namen zelf in. Voor automatische tekstherkenning kun je deze service op je eigen server draaien. Er is geen betaalde AI-API nodig.

## Starten

Maak een willekeurig token (minimaal 32 bytes), kopieer `.env.example` naar `.env` in deze map en zet de waarde bij `TOPOROTOR_OCR_TOKEN`:

```
python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
```

Vanuit de projectroot:

```
TAG=$(git rev-parse --short HEAD)
docker build -f ocr-service/Dockerfile -t toporotor-ocr:$TAG .
docker run -d --name toporotor-ocr --restart unless-stopped --env-file ocr-service/.env --memory=512m --cpus=2 -p 127.0.0.1:8080:8080 toporotor-ocr:$TAG
```

Gebruik altijd een expliciete tag en geen `latest`. Zo blijft elke eerder gebouwde image lokaal beschikbaar (`docker image ls toporotor-ocr`). Verwijder oude tags pas als een nieuwe versie goed werkt.

Terugdraaien: stop de huidige container en start de vorige tag.

```
docker rm -f toporotor-ocr
docker run -d --name toporotor-ocr --restart unless-stopped --env-file ocr-service/.env --memory=512m --cpus=2 -p 127.0.0.1:8080:8080 toporotor-ocr:<vorige-tag>
```

De image heeft een Docker-`HEALTHCHECK`. Met `docker ps` of `docker inspect --format '{{.State.Health.Status}}' toporotor-ocr` zie je of de dienst gezond is.

### Meerdere tokens, rotatie en intrekken

In plaats van `TOPOROTOR_OCR_TOKEN` kun je `TOPOROTOR_OCR_TOKENS` zetten: een kommagescheiden lijst, bijvoorbeeld één token per apparaat. Elk token moet minimaal 32 bytes zijn. Zijn beide variabelen gezet, dan worden alle tokens geaccepteerd. Bij elke geslaagde aanvraag logt de service alleen de index van het gebruikte token (`ocr_auth token_index=N`), nooit het token zelf.

- Roteren: voeg het nieuwe token toe aan de lijst, herstart de container, zet het nieuwe token op de apparaten, verwijder daarna het oude token en herstart opnieuw.
- Intrekken (bijv. verloren tablet): verwijder alleen het token van dat apparaat uit de lijst en herstart de container. Andere apparaten blijven werken.

Er zit geen standaardtoken in de image. Een ontbrekend of kort token maakt `/extract` onbeschikbaar (503). Verkeerde credentials geven 401. De container draait als gebruiker 10001. Met twee gelijktijdige uploads/herkenningen is de dienst bezet; extra werk krijgt 429. Een upload heeft 20 seconden en de Tesseract-aanroep 30 seconden als limiet.

Plaats een HTTPS reverse proxy voor de loopback-poort en bescherm de toegang desgewenst verder via je VPN. Een Caddy-voorbeeld voor een eigen bereikbaar domein:

```
topo.example.org {
    request_body {
        max_size 12MB
    }
    reverse_proxy 127.0.0.1:8080
}
```

Vul in de app `https://topo.example.org/extract` en hetzelfde token in. Het token blijft alleen in geheugen; je voert het na herstart opnieuw in. De app volgt voor deze aanvraag geen redirects, zodat een andere host de Authorization-header niet kan ontvangen.

## Privacy en beperkingen

Een foto verlaat het apparaat pas na ‘Herken tekst uit foto’. De service decodeert in geheugen en stuurt het bewerkte beeld via stdin naar Tesseract; de tekst komt via stdout terug. Er wordt door deze code geen tijdelijk foto- of tekstbestand aangemaakt. Controleer zelf logging en buffering van je reverse proxy. Uvicorn-accesslogging is uitgeschakeld.

De app bewaart lokaal één schoolwerkfoto. Wis appgegevens om die te verwijderen. OCR kan namen missen, kopjes herkennen of extra locaties suggereren. De ouder moet altijd controleren. Onbenoemde kaarten met alleen nummers worden niet automatisch opgelost.

## API

- `GET /health`: 200 bij een reagerende applicatie; geen authenticatie. Dit is liveness, geen garantie dat OCR of een token goed is ingesteld.
- `POST /extract`: raw PNG/JPG, `Content-Type: image/png` of `image/jpeg`, header `Authorization: Bearer <token>`. Maximaal 12 MiB en 12 megapixel; afmetingen worden vóór pixeldecodering gecontroleerd.
- Antwoord: `{"api_version":1, "catalog_version":"...", "text":"...", "candidates":["Arnhem"], "review_required":true}`.
- Fouten: 400 ongeldige afbeelding; 401 onjuist token; 408 uploadtimeout; 413 te groot; 415 formaat; 429 bezet; 502 enginefout; 503 configuratie/engine ontbreekt; 504 OCR-timeout.
- Foutbody: altijd JSON `{"detail":"<melding>"}` (string). 401 bevat `WWW-Authenticate: Bearer`, 429 bevat `Retry-After`.
- Het schema (request body en velden) staat in `/openapi.json` en is bruikbaar om een client te genereren.

`requirements.txt` legt directe versies vast; `requirements.lock.txt` bevat de gecontroleerde runtime-afhankelijkheden. De Docker-build gebruikt de lockfile. Installeer `tests/requirements.txt` alleen voor ontwikkelchecks.

De API en echte OCR zijn lokaal getest. Een Docker-build, reverse-proxyconfiguratie en uitrol op jouw server zijn niet uitgevoerd.
