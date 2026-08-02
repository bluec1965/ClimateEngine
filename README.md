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
