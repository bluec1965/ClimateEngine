# Terrasse: Einrichtung des Ersatzbetriebs

Der neue Ablauf liest Innenräume, HomePod Terrasse und Eve Degree unabhängig.
Nur der abschliessende Verarbeitungskurzbefehl wertet die Messung aus und führt
die vorhandenen SMS-Verzweigungen aus. Ein ausgefallener Eve wird nie durch
HomePod-Werte unter falschem Sensornamen ersetzt.

## Vorbereiten in Kurzbefehle

Den bestehenden `ClimateEngine Sensor Connector` zunächst unverändert behalten.
Für die neue Verarbeitung ein Duplikat namens `ClimateEngine Process Sensors`
anlegen. Die darin enthaltene SMS-Verzweigung samt Empfängern beibehalten.

Drei neue **reine Lese-Kurzbefehle** erstellen. Sie dürfen keine CLI-Aufrufe,
SMS-Aktionen oder HomeKit-Schreibaktionen enthalten. Jeder gibt am Ende einen
Text zurück, mit genau einem Messwert je Zeile (ohne Beschriftungen):

| Kurzbefehl | Ausgabe in dieser Reihenfolge |
| --- | --- |
| `ClimateEngine Read Indoor` | Stube Temperatur, Stube Feuchtigkeit, Schlafzimmer Temperatur, Schlafzimmer Feuchtigkeit, Büro Alois Temperatur, Büro Alois Feuchtigkeit, Sauna Temperatur, Sauna Feuchtigkeit |
| `ClimateEngine Read HomePod Terrasse` | HomePod Terrasse Temperatur, HomePod Terrasse Feuchtigkeit |
| `ClimateEngine Read Eve Degree` | Eve Degree Temperatur, Eve Degree Feuchtigkeit |

Dafür die vorhandenen HomeKit-Abfragen und ihre Gerätezuordnung übernehmen.
Mit den Ergebnissen ein Textfeld als letzte Aktion erstellen (oder danach
„Stoppen und Ausgabe“ mit diesem Text verwenden). Keine „Wenn“-Prüfung hinter dem Eve-Lesen
ist erforderlich: Der Mac fängt Fehler und Zeitüberschreitungen ausserhalb
dieses Kurzbefehls ab. Temperatur und Feuchtigkeit gelten immer gemeinsam.

Im Duplikat `ClimateEngine Process Sensors` die Sensor-Leseaktionen und das alte
Textfeld entfernen. Die Aktion „Shell-Skript ausführen“ bekommt die
**Kurzbefehleingabe als stdin** (Dateiinhalt) und ruft die gebaute CLI auf:

```sh
/Users/aloiscarnier/Developer/ClimateEngine/.build/debug/ClimateEngineCLI sensor-readings
```

Die nachfolgenden bisherigen Verzweigungen für `OPEN_WINDOWS`,
`CLOSE_WINDOWS` und die Wettervarianten müssen weiterhin die Textausgabe dieser
CLI-Aktion auswerten. Bei `NONE` wird keine SMS gesendet. Der Verarbeitungskurzbefehl
wird nur mit dem erzeugten JSON gestartet; direktes „Run“ ohne Eingabe liefert
absichtlich keine neue Messung.

## Vor der Aktivierung testen

Zunächst die drei reinen Lese-Kurzbefehle einzeln prüfen. Beim derzeit leeren
Eve ist ein Lesefehler dort erwartbar; die beiden anderen müssen Werte liefern.
Dann lässt sich das Zusammenspiel **ohne Auswertung, Datenänderung oder SMS** prüfen:

```sh
cd /Users/aloiscarnier/Developer/ClimateEngine
/usr/bin/python3 Scripts/run-terrace-connector.py --config Support/terrace-connector.example.json --collect-only
```

Das Ergebnis enthält alle sechs Sensor-IDs. Beim Eve steht bei einem Fehler
`measurement: null`; HomePod Terrasse hat ein vollständiges Messpaar.
Die Abrufzeit wird gespeichert. HomeKit stellt dabei keinen verlässlich
auswertbaren Zeitpunkt der physischen Sensormessung bereit; von HomeKit
erfolgreich zurückgelieferte Cachewerte lassen sich damit nicht sicher erkennen.

Vor dem ersten Verarbeitungstest die neue CLI bauen (`swift build`), Mac-App
neu bauen/starten und den bestehenden Webserver neu starten. Die Python-API
liefert jetzt zusätzlich den Status des letzten Sensorlaufs.

## Aktivierung

Erst wenn die vier Kurzbefehle fertig geprüft sind, die Beispieldatei nach
`~/Library/Application Support/ClimateEngine/sensor-input/terrace-connector.json`
kopieren. Diese Datei schaltet den vorhandenen Fünf-Minuten-Starter auf die
neue Verarbeitung um. Der LaunchAgent benötigt keine Änderung.

Der Starter behält seine Sperre gegen überlappende Läufe. Er liest die drei
Quellen einzeln mit höchstens 60 Sekunden für die vier Innenräume und je
25 Sekunden für die Aussensensoren und ruft die Verarbeitung
genau einmal auf. Eine fehlgeschlagene Verarbeitung wird nicht automatisch
wiederholt, da eine SMS bereits versendet worden sein könnte.

Bei erfolgreicher Eve-Messung werden wieder beide Aussensensoren verwendet.
Beim Quellenwechsel beginnt die zeitliche Mittelung neu, damit keine Werte des
ausgefallenen Sensors weiter im Aussenmittel stecken. Die bestehende Stabilisierung
von Empfehlungswechseln bleibt wirksam.

Wenn beide Aussensensoren oder eine notwendige Innenmessung ausfallen, bleibt
die letzte erfolgreiche Messung erhalten, aber die Oberflächen kennzeichnen
sie und zeigen keine aktuelle Empfehlung. Es entstehen weder neue
Messhistorieneinträge noch SMS. Auch ohne ausdrückliche Fehlermeldung gilt eine
Hauptmessung nach zwölf Minuten als veraltet. Die Aktivierung gilt ausschliesslich
für den Haupt-Connector; der Zusatz-Connector behält seinen eigenen Ablauf.

Zur Rückkehr zum ursprünglichen Ablauf die Aktivierungsdatei in
`terrace-connector.disabled.json` umbenennen. Der ursprüngliche Hauptkurzbefehl
bleibt für diesen Zweck erhalten.
