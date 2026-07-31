const byId = (id) => document.getElementById(id);

const parseTemperature = (value) =>
  Number.parseFloat(String(value).replace("°C", "").trim());

const absoluteHumidity = (temperature, humidity) => {
  const saturation = 6.112 * Math.exp((17.67 * temperature) / (temperature + 243.5));
  return (2.1674 * saturation * humidity) / (273.15 + temperature);
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
  const indoor = {
    temperature: parseTemperature(snapshot.indoor.temperature),
    humidity: Number(snapshot.indoor.humidity),
  };
  const outdoor = {
    temperature: parseTemperature(snapshot.outdoor.temperature),
    humidity: Number(snapshot.outdoor.humidity),
  };
  const indoorAbsolute = absoluteHumidity(indoor.temperature, indoor.humidity);
  const outdoorAbsolute = absoluteHumidity(outdoor.temperature, outdoor.humidity);

  setText("indoor-temperature", temperatureText(indoor.temperature));
  setText("indoor-humidity", humidityText(indoor.humidity));
  setText("indoor-dew-point", temperatureText(dewPoint(indoor.temperature, indoor.humidity)));
  setText("indoor-absolute", absoluteText(indoorAbsolute));
  setText("outdoor-temperature", temperatureText(outdoor.temperature));
  setText("outdoor-humidity", humidityText(outdoor.humidity));
  setText("outdoor-dew-point", temperatureText(dewPoint(outdoor.temperature, outdoor.humidity)));
  setText("outdoor-absolute", absoluteText(outdoorAbsolute));

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
