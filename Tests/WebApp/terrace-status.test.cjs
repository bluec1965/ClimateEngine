const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");

// Exercise the dashboard logic without running a browser or starting refresh.
const source = fs.readFileSync(path.join(__dirname, "../../WebApp/app.js"), "utf8");
const context = vm.createContext({});
vm.runInContext(source.split('\nbyId("refresh-button")')[0] + "\nthis.check = acquisitionState; this.additionalCheck = additionalAcquisitionState; this.group = groupedRoomReadings;", context);
const check = context.check;
const now = Date.parse("2026-09-06T12:00:00Z");
const snapshot = { timestamp: "2026-09-06T11:59:30Z" };
const status = {
  timestamp: "2026-09-06T11:59:31Z", accepted: true,
  sensors: [
    { id: "eve-degree", measurement: null, failure: "unavailable" },
    { id: "homepod-terrasse", measurement: { temperature: 20, humidity: 55 } },
  ],
};

test("one available terrace sensor produces a labelled replacement", () => {
  const result = check(snapshot, status, now);
  assert.equal(result.unavailable, false);
  assert.match(result.message, /Ersatzbetrieb.*HomePod Terrasse aktiv.*Eve Degree nicht verfügbar/);
});

test("failure of both sensors suppresses advice while last measurement is still young", () => {
  const result = check(snapshot, { ...status, accepted: false, message: "Beide Aussensensoren nicht verfügbar" }, now);
  assert.equal(result.unavailable, true);
  assert.match(result.message, /Beide Aussensensoren/);
});

test("stale measurements never keep showing live advice", () => {
  const result = check(snapshot, status, now + 15 * 60_000);
  assert.equal(result.unavailable, true);
  assert.match(result.message, /veraltet/);
});

test("recovery with both sources removes replacement label", () => {
  const result = check(snapshot, { ...status, sensors: status.sensors.map((s) => ({ ...s, measurement: { temperature: 20, humidity: 55 } })) }, now);
  assert.equal(result.unavailable, false);
  assert.equal(result.message, "");
});

test("snapshot embeds source status even if older web server omits its new field", () => {
  assert.match(check({ ...snapshot, acquisition: status }, undefined, now).message, /Ersatzbetrieb/);
});

test("missing bedroom leaves only the real primary reading and no bias mean", () => {
  const additionalSnapshot = { timestamp: snapshot.timestamp, sensors: [], acquisition: {
    accepted: true, sensors: [{ id: "homepod-schlafzimmer", measurement: null, failure: "unavailable" }],
  }};
  const result = context.additionalCheck(additionalSnapshot, null, now);
  assert.match(result.message, /HomePod Schlafzimmer/);
  const rooms = context.group([{ id: "schlafzimmer", name: "Schlafzimmer", temperature: 24, humidity: 50 }],
    { ...additionalSnapshot, sensors: result.sensors }, true);
  assert.equal(rooms[0].sensors.length, 1);
  assert.ok(!rooms[0].biasCorrectedMeasurement);
});

test("stale additional readings are not presented as current", () => {
  const result = context.additionalCheck({ timestamp: snapshot.timestamp, sensors: [{id: "old"}] }, null, now + 900000);
  assert.equal(result.sensors.length, 0);
  assert.match(result.message, /veraltet/);
});

test("complete additional failure hides previous data and recovery restores it", () => {
  const value = { timestamp: snapshot.timestamp, sensors: [{id: "real"}] };
  assert.equal(context.additionalCheck(value, {timestamp: snapshot.timestamp, accepted: false, message: "Ausfall"}, now).sensors.length, 0);
  assert.equal(context.additionalCheck(value, null, now).sensors.length, 1);
});
