# APK bouwen en installeren

De workflow **Android APK** bouwt met Godot 4.5.1, Java 17 en Android SDK 35.
Elke geslaagde build op main (na een merge, of via Actions → Android APK →
Run workflow op main) publiceert de ondertekende APK en SHA-256 als download
bij GitHub Releases, onder `v0.4.<run>`. Een eigen tag `v*` publiceert onder
die tagnaam. De APK blijft daarnaast 90 dagen als artifact bij de run staan.
De huidige preset ondersteunt ARM64-tablets.

## Eenmalig: vaste ondertekening

Gebruik de bestaande keystore als er al installaties zijn die je wilt bijwerken.
Maak anders lokaal een nieuwe keystore en bewaar die met het wachtwoord buiten
Git, op een plek met een back-up:

```sh
keytool -genkeypair -keystore toporotor.keystore -alias toporotor \
  -keyalg RSA -keysize 2048 -validity 10000
```

Gebruik hetzelfde wachtwoord voor de sleutel en de keystore.
Voeg in GitHub → Settings → Secrets and variables → Actions toe:

- `ANDROID_KEYSTORE_BASE64`: base64 van de keystore (macOS: `base64 -i toporotor.keystore | pbcopy`).
- `ANDROID_KEY_ALIAS`: de alias, bijvoorbeeld `toporotor`.
- `ANDROID_KEY_PASSWORD`: het keystore-/sleutelwachtwoord.

De workflow stopt met een duidelijke fout als deze ontbreken. Hij genereert
geen wisselende sleutel: daardoor blijven updates over eerdere builds mogelijk.
Alleen de releasejob heeft schrijfrechten, en alleen op main en versietags.
Versiecodes stijgen per workflowrun en herstart; versienamen zijn `0.4.<run>`.

## Download op tablet

Open GitHub Releases en download `TopoRotor.apk` bij de bovenste (Latest) versie.
Bij een private repository moet je op de tablet inloggen met toegang tot de repo.
Een build van een andere branch staat alleen als artifact bij de run:
Actions → geslaagde Android APK-run → artifact, ZIP downloaden en uitpakken.
Open de APK en geef de browser of bestandsapp
zo nodig toestemming om deze app te installeren. Installeer updates over de
bestaande app. Een andere signing key vereist verwijderen, waarbij opgeslagen
missies, foto's en sterren verloren gaan.

## Publiceren vanuit deze checkout

Controleer wijzigingen, commit de gewenste bestanden en merge naar main; de
release volgt vanzelf. Een eigen versietag (bijvoorbeeld `v0.5.0`) mag ook.
Een geslaagde lokale enginecheck is geen geslaagde APK-build: controleer de
workflowrun en test de APK op de echte tablet.

Godot-documentatie: https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html
