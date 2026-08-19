# ClimateEngine

## Lokales Web-Dashboard

Das Dashboard liest dieselben Sensor- und Verlaufsdateien wie die macOS-App.
Sie liegen unter `~/Library/Application Support/ClimateEngine`, damit der
lokale Webdienst ohne Zugriff auf den geschützten Dokumente-Ordner auskommt.
CLI und App lösen diesen Pfad über das echte Benutzerkonto auf, sodass ein
eventueller App-Container nicht versehentlich eine zweite Datenablage erzeugt.
Für Tests oder bewusst abweichende Installationen kann ein absoluter gemeinsamer
Pfad über `CLIMATEENGINE_DATA_DIRECTORY` vorgegeben werden.

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

Die ersten vier Werte bleiben vollständig rückwärtskompatibel. Die Stube bleibt
die Innenreferenz für SMS; aussen verwendet die Empfehlung den Mittelwert aus
Eve Degree und HomePod Terrasse. Die zusätzlichen Sensoren werden gespeichert,
im Dashboard dargestellt und dort pro Raum bewertet.

## Separater Additional Sensor Connector

Der Kurzbefehl `ClimateEngine Additional Sensor Connector` sammelt weitere
HomePod-Sensoren unabhängig vom Haupt-Connector. Mac-App und Web-Dashboard
zeigen diese Beobachtungsdaten an; auf SMS oder Empfehlungen haben sie zunächst
keinen Einfluss.

Das Textfeld des Kurzbefehls übergibt genau diese sechzehn Werte über `stdin`:

1. Küche Temperatur
2. Küche Luftfeuchtigkeit
3. Bad Peter Temperatur
4. Bad Peter Luftfeuchtigkeit
5. Schlafzimmer HomePod Temperatur
6. Schlafzimmer HomePod Luftfeuchtigkeit
7. Büro Alois zweiter HomePod Temperatur
8. Büro Alois zweiter HomePod Luftfeuchtigkeit
9. Sauna zweiter HomePod Temperatur
10. Sauna zweiter HomePod Luftfeuchtigkeit
11. Büro Peter Temperatur
12. Büro Peter Luftfeuchtigkeit
13. Bad Alois Temperatur
14. Bad Alois Luftfeuchtigkeit
15. Dachzimmer Temperatur
16. Dachzimmer Luftfeuchtigkeit

In der Mac-App und im Web-Dashboard werden Zusatzsensoren raumweise gruppiert.
Dabei gelten diese
bewussten Zuordnungen für bereits vorhandene Räume:

- `HomePod Küche` ist der zweite Sensor der **Stube**.
- `HomePod Schlafzimmer` ist der zweite Sensor des **Schlafzimmers**.
- `HomePod Büro Alois Rechts` ist der zweite Sensor von **Büro Alois**.
- `HomePod Sauna Links` ist der zweite Sensor der **Sauna**.

Bad Peter, Büro Peter, Bad Alois und Dachzimmer erscheinen als eigene Räume.
Die beiden Messungen eines Raums werden vorerst separat gezeigt und noch nicht
gemittelt; SMS und Lüftungsempfehlung verwenden weiterhin nur die bisherigen
Referenzsensoren. Zur eindeutigen Orientierung wird der bisherige Hauptsensor
im Büro Alois als `HomePod Büro Alois Links` und in der Sauna als
`HomePod Sauna Rechts` angezeigt.

Direkt nach dem Textfeld folgt `Shell-Skript ausführen` mit diesem Befehl:

```bash
/Users/aloiscarnier/Developer/ClimateEngine/.build/debug/ClimateEngineCLI additional-sensors
```

Als Eingabe wird das Textfeld ausgewählt und über `stdin` übergeben. Ein
erfolgreicher manueller Lauf gibt `ADDITIONAL_SENSORS_SAVED` zurück. Der
aktuelle Snapshot liegt danach unter
`~/Library/Application Support/ClimateEngine/additional-sensors/current.json`;
die unveränderten Rohmessungen werden zusätzlich unter
`additional-sensors/history/YYYY-MM-DD.jsonl` gesammelt. Unvollständige oder
unplausible Eingaben ersetzen den letzten gültigen Snapshot nicht.

Die Hauptmessung wird zu den Minuten `00, 05, 10, …` gestartet. Der zusätzliche
Connector folgt jeweils zwei Minuten später zu `02, 07, 12, …`. Beide Dienste
verwenden dieselbe Prozesssperre. Dauert die wichtige Hauptmessung wegen eines
Wiederholungsversuchs länger, wird die betreffende Zusatzmessung übersprungen,
statt gleichzeitig auf HomeKit zuzugreifen.

Die beiden LaunchAgents werden nach einem Build so installiert:

```bash
swift build
chmod +x Scripts/run-sensor-connector.sh

cp Support/ch.climateengine.poller.plist ~/Library/LaunchAgents/
cp Support/ch.climateengine.additional-sensor-poller.plist ~/Library/LaunchAgents/

launchctl bootout gui/$(id -u)/ch.climateengine.poller 2>/dev/null || true
launchctl bootout gui/$(id -u)/ch.climateengine.additional-sensor-poller 2>/dev/null || true

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ch.climateengine.poller.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ch.climateengine.additional-sensor-poller.plist
```

Der Zusatzdienst protokolliert seine Versuche in
`/tmp/climateengine-additional-sensor-retry.log`.

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
Sensor Connector. Die Temperaturprognose verhindert ein vorschnelles Schliessen
nach dem Lüften. Regen und Wind verändern die Empfehlung nicht, ergänzen bei
`Lüften` aber einen Hinweis zum Kippen beziehungsweise Sichern der Fenster.

Für die SMS-Empfehlung werden Temperatur und absolute Luftfeuchtigkeit von
Eve Degree und HomePod Terrasse gemittelt. Die letzten drei plausiblen
Sensormessungen werden geglättet. Eine neue Tendenz wird im Normalfall erst nach
15 Minuten übernommen; eine klar wärmere oder deutlich feuchtere Gegenentwicklung
führt beim Lüften sofort zur Schliess-Empfehlung.

Der Sensor Connector gibt für die bestehende Kurzbefehls-Verzweigung weiterhin
`OPEN_WINDOWS`, `CLOSE_WINDOWS` oder `NONE` aus. Bei einer Lüftungsempfehlung
mit Wetterhinweis werden stattdessen diese eindeutigen Werte verwendet:

- `OPEN_WITH_RAIN_WARNING`
- `OPEN_WITH_WIND_WARNING`
- `OPEN_WITH_RAIN_AND_WIND_WARNING`

Im Kurzbefehl werden dafür drei zusätzliche `Wenn Text enthält ...`-Zweige mit
passendem Nachrichtentext angelegt. Die Werte enthalten absichtlich nicht
`OPEN_WINDOWS`, damit nicht gleichzeitig die normale Lüftungsnachricht gesendet
wird. Ein neuer Wetterhinweis wird während eines laufenden Lüftungsfensters nur
einmal ausgegeben.

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
