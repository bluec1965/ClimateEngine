const byId = (id) => document.getElementById(id);

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
      icon: "↝",
    };
  }
  if (drier) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist zwar trockener, aber wärmer als die Raumluft.",
      icon: "×",
    };
  }
  if (moreHumid && cooler) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist zwar kühler, enthält aber mehr Feuchtigkeit als die Raumluft.",
      icon: "×",
    };
  }
  if (moreHumid) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist wärmer und feuchter als die Raumluft.",
      icon: "×",
    };
  }
  if (!cooler) {
    return {
      key: "close",
      title: "Fenster geschlossen halten",
      explanation: "Die Aussenluft ist wärmer als die Raumluft.",
      icon: "×",
    };
  }
  return {
    key: "neutral",
    title: "Keine Änderung nötig",
    explanation: "Innen- und Aussenluft unterscheiden sich nur gering.",
    icon: "–",
  };
};

const setText = (id, value) => { byId(id).textContent = value; };
const temperatureText = (value) => `${value.toFixed(1)} °C`;
const humidityText = (value) => `${value.toFixed(0)} %`;
const absoluteText = (value) => `${value.toFixed(1)} g/m³`;

const sensorReading = (raw, fallback) => ({
  id: raw?.id || fallback.id,
  name: raw?.name || fallback.name,
  temperature: parseTemperature(raw?.temperature ?? fallback.temperature),
  humidity: Number(raw?.humidity ?? fallback.humidity),
  isPrimary: raw?.isPrimary ?? fallback.isPrimary,
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

const renderSensorCards = (containerId, readings, icon) => {
  const cards = readings.map((reading) => {
    const absolute = absoluteHumidity(reading.temperature, reading.humidity);
    const card = document.createElement("article");
    card.className = "climate-card";
    card.innerHTML = `
      <div class="card-title">
        <span class="card-icon" aria-hidden="true">${icon}</span>
        <h3></h3>
        ${reading.isPrimary ? '<span class="reference-badge">SMS-Referenz</span>' : ""}
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

const renderRoomObservations = (rooms, referenceOutdoor) => {
  const observations = rooms.map((room) => {
    const advice = recommendation(room, referenceOutdoor);
    const item = document.createElement("article");
    item.className = `room-observation ${advice.key}`;
    item.innerHTML = `
      <span class="room-advice-icon" aria-hidden="true">${advice.icon}</span>
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
    summary.textContent = "Eve Degree ist SMS-Referenz";
    summary.className = "section-note";
    return;
  }
  const temperatures = readings.map((reading) => reading.temperature);
  const absoluteValues = readings.map((reading) =>
    absoluteHumidity(reading.temperature, reading.humidity));
  const temperatureSpread = Math.max(...temperatures) - Math.min(...temperatures);
  const humiditySpread = Math.max(...absoluteValues) - Math.min(...absoluteValues);
  const uncertain = temperatureSpread >= 1.5 || humiditySpread >= 1.0;
  summary.textContent = `Spanne ${temperatureSpread.toFixed(1)} °C · ${humiditySpread.toFixed(1)} g/m³${uncertain ? " · beobachten" : ""}`;
  summary.className = `section-note${uncertain ? " warning" : ""}`;
};

const renderHistory = (history) => {
  setText("measurement-count", `${history.length} ${history.length === 1 ? "Messung" : "Messungen"}`);
  setText("first-measurement", formatTime(history[0]?.timestamp));
  setText("last-measurement", formatTime(history.at(-1)?.timestamp));

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
    const item = document.createElement("article");
    item.className = `timeline-event ${ventilate ? "ventilate" : "close"}`;
    item.innerHTML = `
      <span class="event-icon" aria-hidden="true">${ventilate ? "↝" : "×"}</span>
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

const render = ({ snapshot, history }) => {
  const { indoorRooms, outdoorSensors } = snapshotReadings(snapshot);
  const indoor = indoorRooms.find((reading) => reading.isPrimary) || indoorRooms[0];
  const outdoor = outdoorSensors.find((reading) => reading.isPrimary) || outdoorSensors[0];
  const indoorAbsolute = absoluteHumidity(indoor.temperature, indoor.humidity);
  const outdoorAbsolute = absoluteHumidity(outdoor.temperature, outdoor.humidity);

  renderSensorCards("indoor-grid", indoorRooms, "⌂");
  renderSensorCards("outdoor-grid", outdoorSensors, "♧");
  renderRoomObservations(indoorRooms, outdoor);
  renderOutdoorSummary(outdoorSensors);

  setText("compare-temp-indoor", temperatureText(indoor.temperature));
  setText("compare-temp-outdoor", temperatureText(outdoor.temperature));
  setText("compare-temp-difference", temperatureText(outdoor.temperature - indoor.temperature));
  setText("compare-humidity-indoor", absoluteText(indoorAbsolute));
  setText("compare-humidity-outdoor", absoluteText(outdoorAbsolute));
  setText("compare-humidity-difference", absoluteText(outdoorAbsolute - indoorAbsolute));

  const advice = recommendation(indoor, outdoor);
  const panel = byId("recommendation-panel");
  panel.className = `recommendation panel ${advice.key}`;
  setText("recommendation-icon", advice.icon);
  setText("recommendation-title", advice.title);
  setText("recommendation-explanation", advice.explanation);
  setText("measurement-time", `Sensormessung: ${formatTime(snapshot.timestamp, true)}`);
  renderHistory(history);
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
    setText("recommendation-title", "Dashboard nicht verfügbar");
    setText("recommendation-explanation", error.message);
  }
};

byId("refresh-button").addEventListener("click", refresh);
refresh();
setInterval(refresh, 10_000);
