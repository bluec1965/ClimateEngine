const byId = (id) => document.getElementById(id);

const additionalAcquisitionState = (snapshot, status, now = Date.now()) => {
  if (!snapshot) return { sensors: [], message: status?.message || "" };
  if (!status || new Date(status.timestamp) < new Date(snapshot.timestamp)) status = snapshot.acquisition;
  if (status?.accepted === false) return { sensors: [], message: status.message };
  const age = now - new Date(snapshot.timestamp).getTime();
  if (!Number.isFinite(age) || age < -30_000 || age > 12 * 60_000) {
    return { sensors: [], message: "Zusatzmessung veraltet · keine aktuellen Zusatzsensorwerte." };
  }
  const names = {
    "homepod-kueche": "HomePod Küche", "homepod-bad-peter": "HomePod Bad Peter",
    "homepod-schlafzimmer": "HomePod Schlafzimmer", "homepod-buero-alois-rechts": "HomePod Büro Alois Rechts",
    "homepod-sauna-links": "HomePod Sauna Links", "homepod-buero-peter": "HomePod Büro Peter",
    "homepod-bad-alois": "HomePod Bad Alois", "dachzimmer-sensor": "Dachzimmer",
  };
  const missing = (status?.sensors || []).filter((sensor) => !sensor.measurement);
  return { sensors: snapshot.sensors || [],
    message: missing.length ? `Nicht verfügbar: ${missing.map((sensor) => names[sensor.id] || sensor.id).join(", ")}` : "" };
};

const parseTemperature = (value) =>
  Number.parseFloat(String(value).replace("°C", "").trim());

const absoluteHumidity = (temperature, humidity) => {
  const saturation = 6.112 * Math.exp((17.62 * temperature) / (temperature + 243.12));
  return (2.167 * saturation * humidity) / (273.15 + temperature);
};

const dewPoint = (temperature, humidity) => {
  const alpha = Math.log(humidity / 100) + (17.62 * temperature) / (243.12 + temperature);
  return (243.12 * alpha) / (17.62 - alpha);
};

const formatTime = (value, includeDate = false) => {
  if (!value) return "–";
  return new Intl.DateTimeFormat("de-CH", {
    ...(includeDate ? { dateStyle: "medium" } : {}),
    timeStyle: "short",
  }).format(new Date(value));
};

const recommendation = (indoor, outdoor) => {
  const indoorAbsolute = absoluteHumidity(indoor.temperature, indoor.humidity);
  const outdoorAbsolute = absoluteHumidity(outdoor.temperature, outdoor.humidity);
  const difference = outdoorAbsolute - indoorAbsolute;
  const drier = difference < -0.3;
  const moreHumid = difference > 0.3;
  const cooler = outdoor.temperature < indoor.temperature;

  if (drier && cooler) {
    return {
      key: "ventilate",
      title: "Jetzt lüften",
      explanation: "Die Aussenluft ist kühler und trockener als die Raumluft.",
    };
  }
  if (drier) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist zwar trockener, aber wärmer als die Raumluft.",
    };
  }
  if (moreHumid && cooler) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist zwar kühler, enthält aber mehr Feuchtigkeit als die Raumluft.",
    };
  }
  if (moreHumid) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist wärmer und feuchter als die Raumluft.",
    };
  }
  if (!cooler) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist wärmer als die Raumluft.",
    };
  }
  return {
    key: "neutral",
    title: "Keine Änderung nötig",
    explanation: "Innen- und Aussenluft unterscheiden sich nur gering.",
  };
};

const analysisAdvice = (analysis) => {
  const value = analysis?.recommendation;
  if (!value) return null;
  return {
    key: value === "ventilate" ? "ventilate" : value === "closeWindows" ? "close" : "neutral",
    title: value === "ventilate" ? "Jetzt lüften" : value === "closeWindows" ? "Fenster geschlossen halten" : "Keine Änderung nötig",
    explanation: analysis.explanation || "",
  };
};

const meanOutdoor = (readings) => {
  const temperature = readings.reduce((sum, item) => sum + item.temperature, 0) / readings.length;
  const meanAbsolute = readings.reduce(
    (sum, item) => sum + absoluteHumidity(item.temperature, item.humidity), 0) / readings.length;
  const saturation = 6.112 * Math.exp((17.62 * temperature) / (temperature + 243.12));
  const humidity = meanAbsolute * (temperature + 273.15) / (2.167 * saturation);
  return { id: "outdoor-mean", name: "Aussenmittel", temperature, humidity, isPrimary: false };
};

const acquisitionState = (snapshot, acquisition, now = Date.now()) => {
  const status = acquisition || snapshot.acquisition;
  const age = now - new Date(snapshot.timestamp).getTime();
  const rejected = status?.accepted === false
    && new Date(status.timestamp).getTime() >= new Date(snapshot.timestamp).getTime();
  if (rejected || !Number.isFinite(age) || age < -30_000 || age > 12 * 60_000) {
    return {
      unavailable: true,
      message: rejected ? status.message : "Sensormessung veraltet · keine aktuelle Lüftungsempfehlung.",
    };
  }
  const outdoor = status?.sensors?.filter((s) => ["eve-degree", "homepod-terrasse"].includes(s.id)) || [];
  const names = { "eve-degree": "Eve Degree", "homepod-terrasse": "HomePod Terrasse" };
  const missing = outdoor.filter((s) => !s.measurement);
  return {
    unavailable: false,
    message: missing.length
      ? `Ersatzbetrieb · ${outdoor.filter((s) => s.measurement).map((s) => names[s.id]).join(", ")} aktiv · ${missing.map((s) => names[s.id]).join(", ")} nicht verfügbar`
      : "",
  };
};

const setText = (id, value) => { byId(id).textContent = value; };
const temperatureText = (value) => `${value.toFixed(1)} °C`;
const humidityText = (value) => `${value.toFixed(0)} %`;
const absoluteText = (value) => `${value.toFixed(1)} g/m³`;
const precipitationText = (value) =>
  value == null ? "–" : `${Number(value).toFixed(0)} %`;
const windText = (value) =>
  value == null ? "–" : `${Number(value).toFixed(1)} km/h`;

const modeTitle = (mode) => ({
  summer: "Sommer",
  transition: "Übergang",
  heating: "Heizen",
}[mode] || "–");

const renderOperatingMode = (
  operatingMode,
  operatingModeError,
  seasonalRecommendation,
  seasonalRecommendationError,
) => {
  const state = operatingMode || {
    heatingEnabled: false,
    selection: "automatic",
    effectiveMode: "transition",
  };
  const effectiveMode = state.effectiveMode || "transition";
  const selectedSegment = state.heatingEnabled
    ? "heating"
    : state.selection || "automatic";

  setText("effective-mode", modeTitle(effectiveMode));
  setText("heating-state", state.heatingEnabled ? "Ein" : "Aus");
  setText(
    "operating-mode-description",
    state.heatingEnabled
      ? "Heizschalter ein · Stosslüftung wird beobachtet"
      : state.selection === "automatic"
        ? `Auto folgt aktuell der Betriebsart ${modeTitle(effectiveMode)}`
        : `Manuell auf ${modeTitle(effectiveMode)} gesetzt`,
  );

  document.querySelectorAll(".mode-segments [data-mode]").forEach((segment) => {
    segment.classList.toggle("active", segment.dataset.mode === selectedSegment);
  });
  const panel = document.querySelector(".operating-mode-panel");
  panel.classList.toggle("heating", effectiveMode === "heating");

  let candidate = "Nächste Hauptmessung abwarten";
  if (seasonalRecommendation) {
    const duration = seasonalRecommendation.suggestedDurationMinutes;
    const start = seasonalRecommendation.suggestedStartAt;
    switch (seasonalRecommendation.recommendation) {
      case "extendedVentilation":
        candidate = "Dauerlüften";
        break;
      case "briefVentilation":
        candidate = duration ? `${duration} Minuten Stosslüften` : "Stosslüften";
        break;
      case "wait":
        candidate = start ? `Bis ${formatTime(start)} warten` : "Abwarten";
        break;
      case "keepClosed":
        candidate = "Fenster geschlossen halten";
        break;
    }
  }
  setText("seasonal-candidate", candidate);
  setText(
    "seasonal-explanation",
    seasonalRecommendation?.explanation
      || "Die produktive Sommerlogik bleibt unverändert aktiv.",
  );

  const error = operatingModeError || seasonalRecommendationError;
  const errorElement = byId("operating-mode-error");
  errorElement.hidden = !error;
  errorElement.textContent = error || "";
};

const renderVentilationSession = (session) => {
  const active = session?.active === true && session.remainingSeconds > 0;
  const container = byId("ventilation-session");
  const button = byId("ventilation-session-button");
  container.classList.toggle("active", active);
  setText("ventilation-session-title", active ? "Stosslüftung aktiv" : "Nicht aktiv");
  if (active) {
    const minutes = Math.max(1, Math.ceil(session.remainingSeconds / 60));
    setText(
      "ventilation-session-detail",
      `Noch ca. ${minutes} Minuten · endet automatisch um ${formatTime(session.expiresAt)}`,
    );
  } else {
    setText(
      "ventilation-session-detail",
      "Erwartbare Abkühlung wird im Normalbetrieb geprüft.",
    );
  }
  button.textContent = active ? "Vorzeitig beenden" : "10 Minuten starten";
  button.dataset.action = active ? "stop" : "start";
};

const sensorReading = (raw, fallback) => ({
  id: raw?.id || fallback.id,
  name: raw?.name || fallback.name,
  temperature: parseTemperature(raw?.temperature ?? fallback.temperature),
  humidity: Number(raw?.humidity ?? fallback.humidity),
  isPrimary: raw?.isPrimary ?? fallback.isPrimary,
  sourceSensorId: raw?.sourceSensorID || null,
  sourceSensorName: raw?.sourceSensorName || null,
  isFallback: raw?.isFallback === true,
});

const snapshotReadings = (snapshot) => {
  const legacyIndoor = {
    id: "stube",
    name: "Stube",
    temperature: snapshot.indoor.temperature,
    humidity: snapshot.indoor.humidity,
    isPrimary: true,
  };
  const legacyOutdoor = {
    id: "eve-degree",
    name: "Eve Degree",
    temperature: snapshot.outdoor.temperature,
    humidity: snapshot.outdoor.humidity,
    isPrimary: true,
  };
  return {
    indoorRooms: snapshot.indoorRooms?.length
      ? snapshot.indoorRooms.map((reading) => sensorReading(reading, legacyIndoor))
      : [sensorReading(legacyIndoor, legacyIndoor)],
    outdoorSensors: snapshot.outdoorSensors?.length
      ? snapshot.outdoorSensors.map((reading) => sensorReading(reading, legacyOutdoor))
      : [sensorReading(legacyOutdoor, legacyOutdoor)],
  };
};

const additionalSnapshotReadings = (snapshot) =>
  (snapshot?.sensors || []).map((sensor) => ({
    id: sensor.id,
    name: sensor.name,
    roomId: sensor.roomID,
    roomName: sensor.roomName,
    temperature: Number(sensor.measurement?.temperature),
    humidity: Number(sensor.measurement?.humidity),
    isPrimary: false,
    origin: "additional",
  }));

const canonicalAdditionalRoom = (sensor) => {
  switch (sensor.id) {
    case "homepod-kueche":
      return { id: "stube", name: "Stube" };
    case "homepod-schlafzimmer":
      return { id: "schlafzimmer", name: "Schlafzimmer" };
    case "homepod-buero-alois-rechts":
      return { id: "buero-alois", name: "Büro Alois" };
    case "homepod-sauna-links":
      return { id: "sauna", name: "Sauna" };
    default:
      return { id: sensor.roomId, name: sensor.roomName };
  }
};

const primarySensorDisplayName = (sensor) => {
  switch (sensor.id) {
    case "buero-alois":
      return "HomePod Büro Alois Links";
    case "sauna":
      return "HomePod Sauna Rechts";
    default:
      return sensor.name;
  }
};

const roomBiasCorrections = Object.freeze({
  stube: {
    additionalSensorId: "homepod-kueche",
    temperatureAdjustment: -0.403,
    humidityAdjustment: 5.0625915527344,
    sampleCount: 3142,
    analysisPeriod: "15.–28. August 2026",
  },
  schlafzimmer: {
    additionalSensorId: "homepod-schlafzimmer",
    temperatureAdjustment: -0.12,
    humidityAdjustment: 3.5944519042969,
    sampleCount: 3142,
    analysisPeriod: "15.–28. August 2026",
  },
  "buero-alois": {
    additionalSensorId: "homepod-buero-alois-rechts",
    temperatureAdjustment: 0.9,
    humidityAdjustment: -1,
    sampleCount: 3142,
    analysisPeriod: "15.–28. August 2026",
    isProvisional: true,
    caveat: "Temperaturabweichung abhängig vom Messbereich (ca. −0,3 bis −1,1 °C).",
  },
  sauna: {
    additionalSensorId: "homepod-sauna-links",
    temperatureAdjustment: -0.5,
    humidityAdjustment: 1,
    sampleCount: 3142,
    analysisPeriod: "15.–28. August 2026",
    isProvisional: true,
    caveat: "Feuchteabweichung abhängig von der Temperatur (ca. −4 bis +1 %-Pkt. rF).",
  },
});

const biasCorrectedMeasurement = (group) => {
  const correction = roomBiasCorrections[group.id];
  if (!correction) return null;

  const reference = group.sensors.find(
    (sensor) => sensor.origin === "main" && sensor.id === group.id,
  );
  const additional = group.sensors.find(
    (sensor) => sensor.origin === "additional"
      && sensor.id === correction.additionalSensorId,
  );
  if (!reference || !additional) return null;

  const correctedTemperature = additional.temperature
    + correction.temperatureAdjustment;
  const correctedHumidity = Math.min(
    100,
    Math.max(0, additional.humidity + correction.humidityAdjustment),
  );

  return {
    temperature: (reference.temperature + correctedTemperature) / 2,
    humidity: (reference.humidity + correctedHumidity) / 2,
    correction,
    baselineSensorName: reference.name,
    adjustedSensorName: additional.name,
  };
};

const groupedRoomReadings = (
  primaryRooms,
  additionalSnapshot,
  includeBiasCorrectedMeasurements = true,
) => {
  const groups = primaryRooms.map((sensor) => ({
    id: sensor.id,
    name: sensor.name,
    sensors: [{
      ...sensor,
      id: sensor.sourceSensorId || sensor.id,
      name: sensor.isFallback
        ? (sensor.sourceSensorName || sensor.name)
        : primarySensorDisplayName(sensor),
      origin: sensor.isFallback ? "fallback" : "main",
    }],
  }));

  for (const sensor of additionalSnapshotReadings(additionalSnapshot)) {
    const room = canonicalAdditionalRoom(sensor);
    const existing = groups.find((group) => group.id === room.id);
    if (existing) {
      if (!existing.sensors.some((item) => item.id === sensor.id)) {
        existing.sensors.push(sensor);
      }
    } else {
      groups.push({ id: room.id, name: room.name, sensors: [sensor] });
    }
  }

  if (includeBiasCorrectedMeasurements) {
    for (const group of groups) {
      group.biasCorrectedMeasurement = biasCorrectedMeasurement(group);
    }
  }

  return groups;
};

const sensorSnapshotsAreAligned = (primaryTimestamp, additionalTimestamp) => {
  const primaryTime = new Date(primaryTimestamp).getTime();
  const additionalTime = new Date(additionalTimestamp).getTime();
  return Number.isFinite(primaryTime)
    && Number.isFinite(additionalTime)
    && Math.abs(primaryTime - additionalTime) <= 3 * 60 * 1000;
};

const signedNumber = (value) => `${value >= 0 ? "+" : ""}${value.toFixed(1)}`;

const renderSensorCards = (containerId, readings, iconType) => {
  const cards = readings.map((reading) => {
    const absolute = absoluteHumidity(reading.temperature, reading.humidity);
    const card = document.createElement("article");
    card.className = "climate-card";
    card.innerHTML = `
      <div class="card-title">
        <span class="card-icon card-icon--${iconType}" aria-hidden="true"></span>
        <h3></h3>
        ${iconType === "indoor" && reading.isPrimary ? '<span class="reference-badge">SMS-Referenz</span>' : ""}
      </div>
      <dl>
        <div><dt>Temperatur</dt><dd>${temperatureText(reading.temperature)}</dd></div>
        <div><dt>Luftfeuchtigkeit</dt><dd>${humidityText(reading.humidity)}</dd></div>
        <div><dt>Taupunkt</dt><dd>${temperatureText(dewPoint(reading.temperature, reading.humidity))}</dd></div>
        <div><dt>Absolute Feuchte</dt><dd>${absoluteText(absolute)}</dd></div>
      </dl>`;
    card.querySelector("h3").textContent = reading.name;
    return card;
  });
  byId(containerId).replaceChildren(...cards);
};

const renderRoomSensorCards = (containerId, groups) => {
  const cards = groups.map((group) => {
    const card = document.createElement("article");
    card.className = "climate-card room-card";

    const title = document.createElement("div");
    title.className = "card-title";
    title.innerHTML = `
      <span class="card-icon card-icon--indoor" aria-hidden="true"></span>
      <h3></h3>
      <span class="card-badges"></span>`;
    title.querySelector("h3").textContent = group.name;

    const badges = title.querySelector(".card-badges");
    if (group.sensors.length > 1) {
      const countBadge = document.createElement("span");
      countBadge.className = "sensor-count-badge";
      countBadge.textContent = `${group.sensors.length} Sensoren`;
      badges.append(countBadge);
    }
    if (group.sensors.some((sensor) => sensor.isPrimary)) {
      const referenceBadge = document.createElement("span");
      referenceBadge.className = "reference-badge";
      referenceBadge.textContent = "SMS-Referenz";
      badges.append(referenceBadge);
    }

    const sensors = document.createElement("div");
    sensors.className = "room-sensors";
    if (group.biasCorrectedMeasurement) {
      const combined = group.biasCorrectedMeasurement;
      const correction = combined.correction;
      const absolute = absoluteHumidity(combined.temperature, combined.humidity);
      const panel = document.createElement("section");
      panel.className = `room-sensor room-combined${correction.isProvisional ? " provisional" : ""}`;
      panel.innerHTML = `
        <div class="room-sensor-header">
          <strong>Kombinierter Raumwert</strong>
          <span class="bias-badge">${correction.isProvisional ? "Bias-korrigiert · vorläufig" : "Bias-korrigiert"}</span>
        </div>
        <dl>
          <div><dt>Temperatur</dt><dd>${temperatureText(combined.temperature)}</dd></div>
          <div><dt>Luftfeuchtigkeit</dt><dd>${humidityText(combined.humidity)}</dd></div>
          <div><dt>Taupunkt</dt><dd>${temperatureText(dewPoint(combined.temperature, combined.humidity))}</dd></div>
          <div><dt>Absolute Feuchte</dt><dd>${absoluteText(absolute)}</dd></div>
        </dl>
        <p class="bias-correction"></p>
        <p class="bias-caveat"></p>
        <p class="bias-basis"></p>`;
      panel.querySelector(".bias-correction").textContent =
        `Korrektur ${combined.adjustedSensorName}: `
        + `${signedNumber(correction.temperatureAdjustment)} °C · `
        + `${signedNumber(correction.humidityAdjustment)} %-Pkt. rF`;
      panel.querySelector(".bias-caveat").textContent = correction.caveat || "";
      panel.querySelector(".bias-basis").textContent =
        `Sensor 1 (${combined.baselineSensorName}) dient als Vergleichsbasis; `
        + `danach 1:1 gemittelt. Basis: Median aus `
        + `${correction.sampleCount} Messpaaren, `
        + `${correction.analysisPeriod}.`;
      sensors.append(panel);

      const rawLabel = document.createElement("p");
      rawLabel.className = "room-raw-label";
      rawLabel.textContent = "Unveränderte Rohwerte";
      sensors.append(rawLabel);
    }

    group.sensors.forEach((sensor, index) => {
      const absolute = absoluteHumidity(sensor.temperature, sensor.humidity);
      const panel = document.createElement("section");
      panel.className = "room-sensor";
      panel.innerHTML = `
        <div class="room-sensor-header">
          <strong></strong>
          <span class="sensor-origin">${sensor.origin === "main" ? "Hauptmessung" : sensor.origin === "fallback" ? "Ersatzmessung · bias-korrigiert" : "Zusatzmessung"}</span>
        </div>
        <dl>
          <div><dt>Temperatur</dt><dd>${temperatureText(sensor.temperature)}</dd></div>
          <div><dt>Luftfeuchtigkeit</dt><dd>${humidityText(sensor.humidity)}</dd></div>
          <div><dt>Taupunkt</dt><dd>${temperatureText(dewPoint(sensor.temperature, sensor.humidity))}</dd></div>
          <div><dt>Absolute Feuchte</dt><dd>${absoluteText(absolute)}</dd></div>
        </dl>`;
      panel.querySelector("strong").textContent = group.sensors.length > 1
        ? `Sensor ${index + 1} · ${sensor.name}`
        : sensor.name;
      sensors.append(panel);
    });

    card.append(title, sensors);
    return card;
  });

  byId(containerId).replaceChildren(...cards);
};

const renderRoomObservations = (rooms, referenceOutdoor) => {
  const observations = rooms.map((room) => {
    const advice = recommendation(room, referenceOutdoor);
    const item = document.createElement("article");
    item.className = `room-observation ${advice.key}`;
    item.innerHTML = `
      <span class="room-advice-icon" aria-hidden="true"></span>
      <div>
        <h3></h3>
        <p></p>
      </div>
      <strong>${advice.key === "ventilate" ? "Lüften" : advice.key === "close" ? "Geschlossen" : "Beobachten"}</strong>`;
    item.querySelector("h3").textContent = room.name;
    item.querySelector("p").textContent = advice.explanation;
    return item;
  });
  byId("room-observations").replaceChildren(...observations);
};

const renderOutdoorSummary = (readings) => {
  const summary = byId("outdoor-summary");
  if (readings.length < 2) {
    summary.textContent = "Der vorhandene Aussensensor wird für die Empfehlung verwendet";
    summary.className = "section-note";
    return;
  }
  const temperatures = readings.map((reading) => reading.temperature);
  const absoluteValues = readings.map((reading) =>
    absoluteHumidity(reading.temperature, reading.humidity));
  const temperatureSpread = Math.max(...temperatures) - Math.min(...temperatures);
  const humiditySpread = Math.max(...absoluteValues) - Math.min(...absoluteValues);
  const uncertain = temperatureSpread >= 1.5 || humiditySpread >= 1.0;
  summary.textContent = `Aussenmittel aus ${readings.length} Sensoren · Spanne ${temperatureSpread.toFixed(1)} °C · ${humiditySpread.toFixed(1)} g/m³${uncertain ? " · beobachten" : ""}`;
  summary.className = `section-note${uncertain ? " warning" : ""}`;
};

const renderWeather = (weather, weatherError) => {
  const content = byId("weather-content");
  const status = byId("weather-status");

  if (!weather) {
    status.textContent = weatherError ? "Wetterdaten fehlerhaft" : "Noch keine Wetterdaten";
    status.className = `count-badge${weatherError ? " warning" : ""}`;
    const empty = document.createElement("p");
    empty.className = `empty-state${weatherError ? " error-text" : ""}`;
    empty.textContent = weatherError || "Der separate Weather Connector wurde noch nicht ausgeführt.";
    content.replaceChildren(empty);
    return;
  }

  const age = Date.now() - new Date(weather.timestamp).getTime();
  const stale = age > 90 * 60 * 1000;
  status.textContent = `${stale ? "Veraltet" : "Aktuell"} · ${formatTime(weather.timestamp)}`;
  status.className = `count-badge ${stale ? "warning" : "fresh"}`;

  const current = weather.current;
  const currentCard = document.createElement("article");
  currentCard.className = "weather-current";
  currentCard.innerHTML = `
    <div class="weather-current-title">
      <div>
        <span class="weather-location"></span>
        <h3></h3>
      </div>
    </div>
    <dl class="weather-metrics">
      <div><dt>Temperatur</dt><dd>${temperatureText(Number(current.temperature))}</dd></div>
      <div><dt>Luftfeuchte</dt><dd>${humidityText(Number(current.humidity))}</dd></div>
      <div><dt>Taupunkt</dt><dd>${temperatureText(dewPoint(Number(current.temperature), Number(current.humidity)))}</dd></div>
      <div><dt>Absolute Feuchte</dt><dd>${absoluteText(absoluteHumidity(Number(current.temperature), Number(current.humidity)))}</dd></div>
      <div><dt>Regenchance</dt><dd>${precipitationText(current.precipitationChance)}</dd></div>
      <div><dt>Wind</dt><dd>${windText(current.windSpeed)}</dd></div>
    </dl>`;
  currentCard.querySelector(".weather-location").textContent = weather.location || "Aktueller Ort";
  currentCard.querySelector("h3").textContent = current.condition || "Wetterlage unbekannt";

  const forecast = document.createElement("div");
  forecast.className = "weather-forecast";
  const readings = (weather.hourlyForecast || []).slice(0, 6);
  if (!readings.length) {
    const empty = document.createElement("p");
    empty.className = "empty-state";
    empty.textContent = "Noch keine Stundenprognose vorhanden.";
    forecast.append(empty);
  } else {
    for (const reading of readings) {
      const row = document.createElement("article");
      const rainChance = Number(reading.precipitationChance || 0);
      row.className = `weather-hour${rainChance >= 40 ? " rainy" : ""}`;
      row.innerHTML = `
        <time>${formatTime(reading.timestamp)}</time>
        <span class="weather-condition"></span>
        <strong>${temperatureText(Number(reading.temperature))}</strong>
        <span>${absoluteText(absoluteHumidity(Number(reading.temperature), Number(reading.humidity)))}</span>
        <span>${precipitationText(reading.precipitationChance)}</span>`;
      row.querySelector(".weather-condition").textContent = reading.condition || "–";
      forecast.append(row);
    }
  }

  content.replaceChildren(currentCard, forecast);
};

const renderHistory = (history, additionalSummary, additionalHistoryError) => {
  setText("measurement-count", `${history.length} ${history.length === 1 ? "Messung" : "Messungen"}`);
  setText("first-measurement", formatTime(history[0]?.timestamp));
  setText("last-measurement", formatTime(history.at(-1)?.timestamp));

  const additionalCount = Number(additionalSummary?.measurementCount || 0);
  setText(
    "additional-measurement-count",
    `${additionalCount} ${additionalCount === 1 ? "Messung" : "Messungen"}`,
  );
  setText(
    "additional-first-measurement",
    formatTime(additionalSummary?.firstMeasurement),
  );
  setText(
    "additional-last-measurement",
    formatTime(additionalSummary?.lastMeasurement),
  );

  const additionalHistoryStatus = byId("additional-history-status");
  additionalHistoryStatus.hidden = !additionalHistoryError;
  additionalHistoryStatus.textContent = additionalHistoryError || "";

  let changes = 0;
  let periods = 0;
  let previous;
  const events = [];

  for (const entry of history) {
    if (previous !== undefined && entry.recommendation !== previous) changes += 1;
    if (entry.recommendation !== previous || entry.notificationSent) {
      events.push(entry);
      if (entry.recommendation === "ventilate") periods += 1;
    }
    previous = entry.recommendation;
  }

  setText("recommendation-changes", String(changes));
  setText("ventilation-periods", String(periods));

  const timeline = byId("timeline");
  const recentEvents = events.slice(-5).reverse();
  if (!recentEvents.length) {
    timeline.innerHTML = '<p class="empty-state">Noch keine Ereignisse</p>';
    return;
  }

  timeline.replaceChildren(...recentEvents.map((entry) => {
    const ventilate = entry.recommendation === "ventilate";
    const neutral = entry.recommendation === "neutral";
    const state = ventilate ? "ventilate" : neutral ? "neutral" : "close";
    const item = document.createElement("article");
    item.className = `timeline-event ${state}`;
    item.innerHTML = `
      <span class="event-icon" aria-hidden="true"></span>
      <div>
        <div class="event-title">
          <span>${ventilate ? "Jetzt lüften" : entry.recommendation === "neutral" ? "Keine Änderung nötig" : "Fenster geschlossen halten"}</span>
          <time>${formatTime(entry.timestamp)}</time>
        </div>
        <p class="event-explanation"></p>
      </div>`;
    item.querySelector(".event-explanation").textContent = entry.explanation || "";
    return item;
  }));
};

const render = ({
  snapshot,
  sensorAcquisition,
  history,
  weather,
  weatherError,
  recommendation: savedRecommendation,
  operatingMode,
  operatingModeError,
  seasonalRecommendation,
  seasonalRecommendationError,
  ventilationSession,
  additionalSensorSnapshot,
  additionalSensorAcquisition,
  additionalSensorError,
  additionalHistorySummary,
  additionalHistoryError,
}) => {
  const additionalState = additionalAcquisitionState(additionalSensorSnapshot, additionalSensorAcquisition);
  const activeAdditionalSnapshot = additionalSensorSnapshot
    ? { ...additionalSensorSnapshot, sensors: additionalState.sensors } : null;
  const acquisition = acquisitionState(snapshot, sensorAcquisition);
  const acquisitionElement = byId("sensor-acquisition-status");
  acquisitionElement.hidden = !acquisition.message;
  acquisitionElement.textContent = acquisition.message;
  const { indoorRooms, outdoorSensors } = snapshotReadings(snapshot);
  const indoor = indoorRooms.find((reading) => reading.isPrimary) || indoorRooms[0];
  const outdoor = meanOutdoor(outdoorSensors);
  const indoorAbsolute = absoluteHumidity(indoor.temperature, indoor.humidity);
  const outdoorAbsolute = absoluteHumidity(outdoor.temperature, outdoor.humidity);
  const alignedSensorSnapshots = sensorSnapshotsAreAligned(
    snapshot.timestamp,
    additionalSensorSnapshot?.timestamp,
  );

  renderOperatingMode(
    operatingMode,
    operatingModeError,
    acquisition.unavailable ? null : seasonalRecommendation,
    seasonalRecommendationError,
  );
  renderVentilationSession(ventilationSession);

  renderRoomSensorCards(
    "indoor-grid",
    groupedRoomReadings(
      indoorRooms,
      activeAdditionalSnapshot,
      alignedSensorSnapshots,
    ),
  );
  renderSensorCards("outdoor-grid", outdoorSensors, "outdoor");
  if (acquisition.unavailable) {
    const note = document.createElement("p");
    note.className = "section-note warning";
    note.textContent = "Raumempfehlungen warten auf aktuelle Innen- und Aussenmessungen.";
    byId("room-observations").replaceChildren(note);
  } else {
    renderRoomObservations(indoorRooms, outdoor);
  }
  renderOutdoorSummary(outdoorSensors);
  if (acquisition.unavailable) {
    setText("outdoor-summary", "Zuletzt verfügbare Messwerte");
  }
  try {
    renderWeather(weather, weatherError);
  } catch (error) {
    renderWeather(null, `Wetterdaten konnten nicht dargestellt werden: ${error.message}`);
  }

  setText("compare-temp-indoor", temperatureText(indoor.temperature));
  setText("compare-temp-outdoor", temperatureText(outdoor.temperature));
  setText("compare-temp-difference", temperatureText(outdoor.temperature - indoor.temperature));
  setText("compare-humidity-indoor", absoluteText(indoorAbsolute));
  setText("compare-humidity-outdoor", absoluteText(outdoorAbsolute));
  setText("compare-humidity-difference", absoluteText(outdoorAbsolute - indoorAbsolute));

  const advice = acquisition.unavailable
    ? { key: "neutral", title: "Warte auf aktuelle Sensordaten", explanation: acquisition.message }
    : analysisAdvice(savedRecommendation?.analysis) || recommendation(indoor, outdoor);
  const heroRecommendation = byId("hero-recommendation");
  heroRecommendation.className = `hero-recommendation ${advice.key}`;
  setText("hero-recommendation-title", advice.title);

  const panel = byId("recommendation-panel");
  panel.className = `recommendation panel ${advice.key}`;
  setText("recommendation-title", advice.title);
  setText("recommendation-explanation", advice.explanation);
  setText("measurement-time", `Sensormessung: ${formatTime(snapshot.timestamp, true)}`);

  const indoorSummary = byId("indoor-summary");
  const summaryText = additionalSensorSnapshot && !alignedSensorSnapshots
    ? "Bias-korrigierte Raumwerte warten auf zeitlich passende Haupt- und Zusatzmessungen"
    : "Bias-Korrektur nur mit zwei aktuellen Sensoren · Büro Alois und Sauna vorläufig";
  if (additionalSensorSnapshot?.timestamp) {
    indoorSummary.textContent = `${summaryText} · Zusatzmessung ${formatTime(additionalSensorSnapshot.timestamp)}`;
    indoorSummary.className = "section-note";
  } else {
    indoorSummary.textContent = additionalSensorError
      ? `${summaryText} · Zusatzdaten nicht verfügbar`
      : summaryText;
    indoorSummary.className = `section-note${additionalSensorError ? " warning" : ""}`;
  }

  const additionalMeasurementTime = byId("additional-measurement-time");
  additionalMeasurementTime.hidden = !additionalSensorSnapshot?.timestamp && !additionalSensorError;
  additionalMeasurementTime.textContent = additionalSensorSnapshot?.timestamp
    ? `Zusatzsensoren: ${formatTime(additionalSensorSnapshot.timestamp, true)}`
    : additionalSensorError || "";
  additionalMeasurementTime.className = additionalSensorError ? "warning" : "";
  if (additionalState.message) {
    indoorSummary.textContent += ` · ${additionalState.message}`;
    indoorSummary.className = "section-note warning";
    additionalMeasurementTime.hidden = false;
    additionalMeasurementTime.textContent += ` · ${additionalState.message}`;
    additionalMeasurementTime.className = "warning";
  }
  const indoorFallbacks = (sensorAcquisition || snapshot.acquisition)?.indoorFallbacks || [];
  if (indoorFallbacks.length) {
    const fallbackText = "Ersatzbetrieb Innen · " + indoorFallbacks.map((fallback) =>
      `${fallback.roomName}: ${fallback.activeSensorName} aktiv · ${fallback.unavailableSensorName} nicht verfügbar`
    ).join(" · ");
    indoorSummary.textContent += ` · ${fallbackText}`;
    indoorSummary.className = "section-note warning";
  }
  renderHistory(history, additionalHistorySummary, additionalHistoryError);
};

const refresh = async () => {
  const status = byId("connection-status");
  try {
    const response = await fetch("/api/dashboard", { cache: "no-store" });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || `HTTP ${response.status}`);
    render(payload);
    status.className = "status-pill online";
    status.lastElementChild.textContent = "Live verbunden";
  } catch (error) {
    status.className = "status-pill error";
    status.lastElementChild.textContent = "Keine Sensordaten";
    byId("hero-recommendation").className = "hero-recommendation neutral";
    setText("hero-recommendation-title", "Warte auf Sensordaten");
    setText("recommendation-title", "Dashboard nicht verfügbar");
    setText("recommendation-explanation", error.message);
  }
};

byId("refresh-button").addEventListener("click", refresh);
byId("ventilation-session-button").addEventListener("click", async (event) => {
  const button = event.currentTarget;
  const action = button.dataset.action || "start";
  button.disabled = true;
  try {
    const response = await fetch("/api/ventilation-session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error || `HTTP ${response.status}`);
    renderVentilationSession(payload);
    await refresh();
  } catch (error) {
    const status = byId("connection-status");
    status.className = "status-pill error";
    status.lastElementChild.textContent = `Stosslüftung nicht gespeichert: ${error.message}`;
  } finally {
    button.disabled = false;
  }
});
refresh();
setInterval(refresh, 10_000);
