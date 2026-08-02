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
