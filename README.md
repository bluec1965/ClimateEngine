# ClimateEngine

## Lokales Web-Dashboard

Das Dashboard liest dieselben Sensor- und Verlaufsdateien wie die macOS-App.
Sie liegen unter `~/Library/Application Support/ClimateEngine`, damit der
lokale Webdienst ohne Zugriff auf den geschützten Dokumente-Ordner auskommt.

```bash
python3 WebApp/server.py
```

Danach zeigt der Server zwei Adressen an: eine für den Mac und eine für Geräte
im gleichen WLAN. Die zweite Adresse auf dem iPhone in Safari öffnen. Der
Server läuft nur, solange dieses Terminalfenster geöffnet bleibt.

## Mehrere Räume und Aussensensoren

ClimateEngine kann in der Beobachtungsphase zwölf Werte über die
Standardeingabe entgegennehmen. Die Reihenfolge ist:

1. Stube Temperatur
2. Stube Luftfeuchtigkeit
3. Eve Degree Temperatur
4. Eve Degree Luftfeuchtigkeit
5. Schlafzimmer Temperatur
6. Schlafzimmer Luftfeuchtigkeit
7. Büro Alois Temperatur
8. Büro Alois Luftfeuchtigkeit
9. Sauna Temperatur
10. Sauna Luftfeuchtigkeit
11. HomePod Terrasse Temperatur
12. HomePod Terrasse Luftfeuchtigkeit

Die ersten vier Werte bleiben vollständig rückwärtskompatibel. SMS werden
weiterhin ausschliesslich anhand von Stube und Eve Degree ausgelöst. Die
zusätzlichen Sensoren werden gespeichert, im Dashboard dargestellt und dort
pro Raum bewertet.

## Qualität der Sensoreingänge

Der Sensor Connector soll nur über den LaunchAgent `ch.climateengine.poller`
im Fünf-Minuten-Takt gestartet werden. Ältere parallele Zeitpläne müssen
deaktiviert bleiben, damit derselbe Kurzbefehl nicht doppelt ausgeführt wird.

Der LaunchAgent startet `Scripts/run-sensor-connector.sh`. Falls Kurzbefehle
mit `Schreib-/Lesevorgang fehlgeschlagen` endet, wartet der Starthelfer 20
Sekunden und versucht den Lauf höchstens zweimal erneut. Andere Fehler werden
nicht wiederholt, damit die Prüfung auffälliger Sensorwerte nicht umgangen
wird. Eine Prozesssperre verhindert parallele Läufe. Das Ergebnis jedes
Versuchs steht in `/tmp/climateengine-sensor-retry.log`.

Die mitgelieferte LaunchAgent-Vorlage wird so installiert:

```bash
chmod +x Scripts/run-sensor-connector.sh
cp Support/ch.climateengine.poller.plist ~/Library/LaunchAgents/
launchctl bootout gui/$(id -u)/ch.climateengine.poller 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ch.climateengine.poller.plist
launchctl kickstart -k gui/$(id -u)/ch.climateengine.poller
```

ClimateEngine prüft die Stube als primären Innensensor vor dem Überschreiben
des aktuellen Snapshots. Ein Sprung von mehr als 1 °C oder 8 Prozentpunkten
Luftfeuchtigkeit innerhalb des Prüfzeitfensters gilt zunächst als auffällig.
Der Wert wird erst nach drei aufeinanderfolgenden, konsistenten Messungen
übernommen. Bis dahin bleibt der letzte gültige Snapshot erhalten und der
CLI-Lauf endet mit einer genauen Fehlermeldung und Exit-Code 1.

Alle angenommenen und verworfenen Eingänge werden unabhängig von Snapshot und
Empfehlung unter
`~/Library/Application Support/ClimateEngine/sensor-input/history/YYYY-MM-DD.jsonl`
protokolliert. Damit bleiben fehlerhafte HomeKit-Werte für die Diagnose sichtbar,
ohne die Empfehlung zu beeinflussen.

## Separater Weather Connector

Der Weather Connector sammelt Apple-Weather-Daten unabhängig vom bestehenden
Sensor Connector. Wetterdaten beeinflussen während der Beobachtungsphase weder
SMS noch Lüftungsempfehlungen.

Der Kurzbefehl übergibt seinen Text an diesen Aufruf:

```bash
/Users/aloiscarnier/Developer/ClimateEngine/.build/debug/ClimateEngineCLI weather
```

Die Eingabe wird im Kurzbefehl als Text erzeugt und über `stdin` übergeben. Das
Format ist zeilenorientiert:

```text
CLIMATEENGINE_WEATHER_V1
LOCATION|Platz 3
CURRENT|NOW|21.4 °C|73 %|Leicht bewölkt||8.5 km/h|
FORECAST|+1|20.8 °C|75 %|Bewölkt|20 %|7 km/h|0 mm
FORECAST|+2|20.1 °C|78 %|Leichter Regen|55 %|9 km/h|0.4 mm
```

Die Felder einer Wetterzeile sind:

1. `CURRENT` oder `FORECAST`
2. Zeitpunkt: `NOW`, `+1` bis `+6` oder ein ISO-8601-Zeitpunkt
3. Temperatur
4. relative Luftfeuchtigkeit
5. Wetterlage
6. Niederschlagswahrscheinlichkeit; darf leer sein
7. Windgeschwindigkeit; darf leer sein
8. Niederschlagsmenge; optional und darf leer sein

`+1` bezeichnet die nächste volle Stunde. Für die Stundenprognose sollen daher
die ersten sechs zukünftigen Einträge aus „Wettervorhersage abrufen“ verwendet
werden. Zahlen dürfen Dezimalkomma und Einheiten enthalten. Ein erfolgreicher
Lauf gibt `WEATHER_SAVED` zurück.

Die aktuelle Wetterbeobachtung liegt unter
`~/Library/Application Support/ClimateEngine/weather/current.json`. Jeder Lauf
wird zusätzlich unter
`~/Library/Application Support/ClimateEngine/weather/history/YYYY-MM-DD.jsonl`
gespeichert. Mac-App und Web-Dashboard laden die Wetterdatei unabhängig von den
Sensordaten und kennzeichnen einen Abruf nach 90 Minuten als veraltet.
