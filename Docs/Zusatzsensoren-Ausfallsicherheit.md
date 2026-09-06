# Zusatzsensoren: unabhängige Erfassung

Ein nicht erreichbarer Zusatzsensor darf die anderen sieben nicht blockieren.
Die acht reinen Lese-Kurzbefehle in `Support/additional-connector.example.json`
enthalten jeweils nur die bestehende Temperatur-/Feuchteabfrage eines Gerätes,
die zugehörigen Variablen und Wartezeiten sowie einen abschliessenden Text mit
genau zwei Messwertzeilen. Keine CLI, SMS oder HomeKit-Schreibaktionen.
Der ursprüngliche `ClimateEngine Additional Sensor Connector` bleibt erhalten.

Der Starter liest jeden Sensor unabhängig (höchstens 25 Sekunden je Gerät,
insgesamt 150 Sekunden). Alle IDs werden gemeldet, bei einem Fehler mit
`measurement: null` und einem Ausfallstatus. Ein Ausfall wird niemals mit
kopierten Messwerten eines anderen Sensors gefüllt. Die Abrufzeit ist nicht
gleichbedeutend mit dem Zeitpunkt der physischen HomeKit-Sensormessung.

`ClimateEngineCLI additional-readings` speichert nur echte erfolgreiche
Messpaare in `additional-sensors/current.json` und der Tageshistorie. Die
optionalen Erfassungsmetadaten dokumentieren fehlende Sensoren. Die Datei
`additional-sensors/current-status.json` hält auch einen vollständigen Ausfall
fest; in diesem Fall bleiben letzte Messung und Historie unverändert.
Fehlerhafte, alte oder wiederholte Eingaben erzeugen keine neuen Messungen.

Mac-App und WebUI nennen fehlende Sensoren und nehmen sie nicht in Raumwerte
oder Bias-Korrekturen auf. Nach zwölf Minuten gelten Zusatzdaten als veraltet.
Beim ausgefallenen Schlafzimmer-HomePod bleibt damit die Hauptmessung sichtbar,
aber es wird kein Zwei-Sensor-Mittelwert vorgetäuscht. Sobald das Gerät wieder
gültige Werte liefert, wird es automatisch aufgenommen. Die Hauptempfehlung
und ihre SMS-Verarbeitung werden vom Zusatz-Connector nicht verändert.

## Prüfung und Aktivierung

Zuerst alle acht Hilfskurzbefehle prüfen, dann rein lesend:

```sh
cd /Users/aloiscarnier/Developer/ClimateEngine
/usr/bin/python3 -B Scripts/run-additional-connector.py --config Support/additional-connector.example.json --collect-only
```

Vor der Aktivierung die CLI und Mac-App neu bauen sowie den bestehenden
Webserver neu starten. Erst nach erfolgreicher Prüfung die Beispieldatei nach
`~/Library/Application Support/ClimateEngine/additional-sensors/connector.json`
kopieren. Diese Konfiguration gilt nur für den Zusatz-Connector. Die separate
Terrassenkonfiguration gilt nur für den Haupt-Connector. Beide verwenden
weiterhin die bestehende gemeinsame Laufsperre und ihre bisherigen Zeitpläne.

Zur Rückkehr zum ursprünglichen Zusatz-Connector die Aktivierungsdatei in
`connector.disabled.json` umbenennen. Alte Historiendateien bleiben lesbar.
