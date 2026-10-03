#!/bin/bash
# Bildschirmfotos von der Apple Watch -- echte, aus dem Simulator.
#
#     ios/uhrbilder.sh
#
# ## Warum das hier ein Shellskript ist und keine fastlane-Spur
#
# **watchOS kennt XCUITest nicht.** Es gibt kein `XCUIApplication` für
# die Uhr; `snapshot` und das Ziel `RoutetreeBilder` sind Wege, die es
# auf der Uhr nicht gibt. Was es gibt, ist `simctl`: booten,
# installieren, starten, fotografieren.
#
# Tippen kann `simctl` nicht. Deshalb wird die Ansicht beim START
# gesetzt statt ertippt -- `-uhrprobe-ziel` sagt der App, was sie
# zeigen soll (siehe `Uhr/Probe/Uhrprobe.swift`). Je Ansicht ein
# Start, je Start ein Bild.
#
# ## Woher die Plays kommen
#
# Aus `bibliothek.py`, über `scripts/uhrprobe_bauen.py` in
# `Uhrprobedaten.swift`. Gezeichnet werden sie von `Uhrfeld` -- der
# Ansicht, die auch am Handgelenk läuft. Das Bild ist kein Nachbau
# eines Uhrschirms, es IST der Uhrschirm.
#
# ## Die Sprache
#
# `-AppleLanguages "(en)"` als Startargument. NSUserDefaults liest den
# Argumentbereich VOR allem anderen, und `String(localized:)` folgt
# ihm -- so läuft dieselbe App auf demselben Simulator einmal deutsch
# und einmal englisch, ohne den Simulator umzustellen.
#
# Umgebung:
#   UHR_SPRACHEN   Komma, z. B. "de,en"       (Vorgabe: de)
#   UHR_ZIELE      Leerzeichen, s. u.          (Vorgabe: hefte kategorien plays)
#   UHR_GERAET     Name im Simulator          (Vorgabe: neuestes Apple Watch)

set -euo pipefail
cd "$(dirname "$0")"

# Welcher Ort zu welcher Sprache gehoert.
#
# Eine Tabelle und keine Ableitung -- dieselbe wie in
# `Bildschirmfotos.ort(zu:)`: `en` heisst `en_US` und nicht `en_EN`.
# Wer das rechnet, rechnet bei der ersten Sprache falsch, die nicht so
# heisst wie ihr Land, und Englisch ist die erste.
ort() {
  case "$1" in
    de) echo "de_DE" ;; en) echo "en_US" ;; es) echo "es_ES" ;;
    fr) echo "fr_FR" ;; it) echo "it_IT" ;; *) echo "en_US" ;;
  esac
}

SPRACHEN="${UHR_SPRACHEN:-de}"
ZIELE="${UHR_ZIELE:-hefte kategorien plays}"
BUENDEL="de.routetree.app.watchkitapp"
AUSGABE="$PWD/bilder/uhr"

# --- Welche Uhr -----------------------------------------------------------
#
# NICHT AUF EINEN NAMEN FESTGENAGELT. Die Läufer bekommen neue
# Xcode-Fassungen, und mit ihnen neue Gerätenamen; ein fest
# eingetragenes „Apple Watch Series 10 (46mm)" wäre der Fehlschlag, der
# ein halbes Jahr später kommt und nach etwas anderem aussieht.
geraet_finden() {
  if [ -n "${UHR_GERAET:-}" ]; then
    xcrun simctl list devices available | grep -m1 -F "$UHR_GERAET ("
    return
  fi
  # DIE GROESSTE UHR, NICHT DIE LETZTE ZEILE.
  #
  # Hier stand `tail -1` mit der Begruendung „simctl sortiert
  # aufsteigend". Es sortiert nach Reihe, nicht nach Groesse: Der Lauf
  # vom 30.09.2026 nahm eine 40-mm-Uhr und lieferte 324x394. Apple
  # nimmt das zwar an, aber es ist das KLEINSTE Fach -- und auf dem
  # Store-Bild wie auf der Startseite steht der Schirm neben einem
  # 1290 Punkte breiten Telefon.
  #
  # Sortiert wird nach der Millimeterzahl im Namen. „Ultra" traegt
  # keine: Sie ist mit 49 mm die groesste und bekommt die Zahl hier.
  xcrun simctl list devices available \
    | grep -E "^[[:space:]]+Apple Watch" \
    | while IFS= read -r zeile; do
        mm="$(printf '%s' "$zeile" | grep -oE '[0-9]+mm' | head -1 \
              | tr -d 'm')"
        case "$zeile" in *Ultra*) mm=49 ;; esac
        printf '%s\t%s\n' "${mm:-0}" "$zeile"
      done \
    | sort -n -k1,1 | tail -1 | cut -f2-
}

zeile="$(geraet_finden || true)"
if [ -z "$zeile" ]; then
  echo "Kein Apple-Watch-Simulator verfügbar. Vorhanden:"
  xcrun simctl list devices available
  exit 1
fi
UDID="$(printf '%s' "$zeile" | grep -oE '[0-9A-Fa-f-]{36}')"
NAME="$(printf '%s' "$zeile" | sed -E 's/^ *//; s/ \(.*//')"
echo "== Uhr: $NAME  ($UDID)"

# --- Bauen ----------------------------------------------------------------
#
# `CODE_SIGNING_ALLOWED=NO`: Der Simulator braucht keine Signatur, und
# das Profil mit der HealthKit-Berechtigung gibt es auf dem Läufer
# nicht. Ohne diese Zeile bricht der Bau beim Signieren ab -- mit einer
# Meldung über Profile, die nach einem ganz anderen Problem klingt.
echo "== Bauen"
xcodebuild build \
  -project Routetree.xcodeproj \
  -scheme RoutetreeUhr \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath build/uhr \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  | grep -E "error:|warning:|BUILD" || true

APP="$(find build/uhr/Build/Products -maxdepth 2 -name 'RoutetreeUhr.app' \
       -print -quit)"
[ -n "$APP" ] || { echo "Die gebaute App ist nicht auffindbar."; exit 1; }
echo "== Gebaut: $APP"

# --- Spricht die Uhr ueberhaupt mehr als eine Sprache? --------------------
#
# **Der Befund vom 30.09.2026.** Die deutschen und die englischen
# Uhrbilder waren bis auf die Uhrzeit IDENTISCH. `project.yml` zaehlt
# die `.lproj`-Ordner fuer `RoutetreeUhr` einzeln auf, mit genau dem
# richtigen Kommentar daneben („Ohne sie faellt `String(localized:)`
# auf den Schluessel zurueck -- der ist deutsch"). Im gebauten Buendel
# lagen sie trotzdem nicht als Lokalisierungen.
#
# Das ist kein Problem der Bilderstrecke, sondern der App: Jeder
# nicht-deutsche Traeger sah eine deutsche Uhr.
#
# Geprueft wird deshalb das BUENDEL und nicht die Absicht.
fehlend=""
for sprache in de en es fr it; do
  [ -d "$APP/$sprache.lproj" ] || fehlend="$fehlend $sprache"
done
if [ -n "$fehlend" ]; then
  echo
  echo "!! Der Uhr-App fehlen die Lokalisierungen fuer:$fehlend"
  echo "   Im Buendel liegt:"
  ls -1 "$APP" | sed 's/^/     /'
  echo
  # EINFACHE ANFUEHRUNGSZEICHEN. In doppelten fuehrt bash alles
  # zwischen Backticks AUS -- „project.yml" waere ein Befehl.
  echo '   Die Uhr zeigt damit fuer JEDEN Traeger Deutsch. In'
  echo '   project.yml stehen die Ordner bei RoutetreeUhr; XcodeGen'
  echo '   muss sie als Lokalisierung eintragen, nicht als Ordner.'
  echo '   Die Bilder entstehen trotzdem, sie sind nur alle deutsch.'

  echo
fi

# --- Starten und fotografieren -------------------------------------------
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"

IFS=',' read -r -a sprachliste <<< "$SPRACHEN"
for sprache in "${sprachliste[@]}"; do
  fach="$AUSGABE/$sprache"
  mkdir -p "$fach"
  for ziel in $ZIELE; do
    # NEU STARTEN JE BILD. Die Ansicht wird beim Start gesetzt; eine
    # laufende App wechselt sie nicht, und `simctl launch` auf eine
    # laufende App holt sie nur nach vorn.
    xcrun simctl terminate "$UDID" "$BUENDEL" 2>/dev/null || true
    # DER ORT IST NICHT DIE SPRACHE. Mit `-AppleLocale en` stand auf
    # der englischen Uhr „Stand: 30. Sept. 2026, 8:07 AM" -- deutscher
    # Monat, englische Uhrzeit. Dieselbe Tabelle wie in
    # `Bildschirmfotos.ort(zu:)`: `en` heisst `en_US`, nicht `en_EN`.
    xcrun simctl launch "$UDID" "$BUENDEL" \
      -AppleLanguages "($sprache)" -AppleLocale "$(ort "$sprache")" \
      -uhrprobe -uhrprobe-ziel "$ziel" >/dev/null
    # Sechs Sekunden: Die Uhr baut beim ersten Start ihr Fenster auf,
    # und ein Bild davor zeigt einen schwarzen Schirm. Gemessen ist das
    # nicht -- wer es kuerzt, prueft die Bilder.
    sleep 6
    xcrun simctl io "$UDID" screenshot "$fach/uhr-$ziel.png" >/dev/null
    echo "   $sprache/$ziel  $(sips -g pixelWidth -g pixelHeight \
      "$fach/uhr-$ziel.png" | tail -2 | tr -d ' \n')"
  done
done

xcrun simctl terminate "$UDID" "$BUENDEL" 2>/dev/null || true
echo "== Fertig: $AUSGABE"
