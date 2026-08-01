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
