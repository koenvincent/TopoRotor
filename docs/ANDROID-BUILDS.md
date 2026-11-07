# APK bouwen en installeren

De workflow **Android APK** bouwt met Godot 4.5.1, Java 17 en Android SDK 35.
Elke geslaagde build op main (na een merge, of via Actions → Android APK →
Run workflow op main) publiceert de ondertekende APK en SHA-256 als download
bij GitHub Releases als de bovenste (Latest) versie, onder de tag
`build-<versienaam>` (bijvoorbeeld `build-0.4.57`). Die naam botst niet met
handmatige `v*`-tags. Een eigen tag `v*` publiceert onder die tagnaam. De
workflow maakt de release eerst als concept met beide bestanden en publiceert
pas daarna; een bestaande release die de workflow niet zelf als concept heeft
gemaakt wordt nooit overschreven, de run stopt dan met een fout. De APK blijft daarnaast 90 dagen als artifact bij de run staan.
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
De sleutelgegevens zijn alleen zichtbaar in de stap *Export signed APK*; de
keystore bestaat alleen tijdens die stap. Alle externe actions staan vast op een
volledige commit-SHA (met de tag als commentaar). Alleen de releasejob heeft
schrijfrechten, en alleen op main en versietags; die job wordt niet halverwege
afgebroken door een nieuwere push.
Wil je de sleutel ook afschermen voor handmatige runs op andere branches, zet de
drie secrets dan in Settings → Environments → `android-release` en beperk die
omgeving tot main en `v*`-tags. De workflow gebruikt die omgeving al.

## Versies en Godot

- Versienaam: `major.minor` uit `config/version` in `project.godot` plus het
  runnummer (`0.4.57`). Bij een `v*`-tag is de naam de tag zonder `v`. Verhoog
  `config/version` bij een nieuwe release; er staat nergens anders een versie.
- Versiecode: `VERSION_CODE_BASE + runnummer × 100 + poging`
  (`tools/android_version.py`). Telt het runnummer van de workflow ooit opnieuw
  (workflow hernoemd of opnieuw aangemaakt), verhoog dan `VERSION_CODE_BASE`
  boven de laatst uitgebrachte code, anders weigert Android de update.
  Het script stopt met een fout als het geen versieregel kan aanpassen.
- Godot: `tools/godot-version.env` bevat de versie en de SHA-512 van editor en
  exporttemplates voor zowel `ci.yml` als `android.yml`. Bij een upgrade pas je
  alleen dat bestand aan, met de hashes uit `SHA512-SUMS.txt` van die release.

## Download op tablet

Open GitHub Releases en download `TopoRotor.apk` bij de bovenste (Latest) versie.
Terug naar een eerdere versie: zet bij die release *Set as the latest release*
aan (of `gh release edit <tag> --latest`).
Bij een private repository moet je op de tablet inloggen met toegang tot de repo.
Een build van een andere branch staat alleen als artifact bij de run:
Actions → geslaagde Android APK-run → artifact, ZIP downloaden en uitpakken.
Open de APK en geef de browser of bestandsapp
zo nodig toestemming om deze app te installeren. Installeer updates over de
bestaande app. Een andere signing key vereist verwijderen, waarbij opgeslagen
missies, foto's en sterren verloren gaan.

## Publiceren vanuit deze checkout

Controleer wijzigingen, commit de gewenste bestanden en merge naar main; de
release volgt vanzelf. Een eigen versietag (bijvoorbeeld `v0.5.0`) mag ook,
mits er voor die tag nog geen release bestaat.
Een geslaagde lokale enginecheck is geen geslaagde APK-build: controleer de
workflowrun en test de APK op de echte tablet.

Godot-documentatie: https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html
