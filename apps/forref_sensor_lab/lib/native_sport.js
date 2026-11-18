// Public-API capability probe. It does not call Zepp, start GPS, or write a session.

export const AVAILABILITY = Object.freeze([
  "NATIVE_DIRECT",
  "EXTENSION_ONLY",
  "AGGREGATE_ONLY",
  "UNAVAILABLE",
  "HARDWARE_PENDING",
]);

export const WORKOUT_EXTENSION_DEVICES = Object.freeze([
  "Amazfit T-Rex 3",
  "Amazfit Cheetah Pro",
  "Amazfit Cheetah (Round)",
  "Amazfit Cheetah Square",
  "Amazfit T-Rex Ultra",
  "Amazfit Falcon",
]);

export const SPORT_READ_TYPES = Object.freeze(["distance", "speed", "duration"]);

export const SPORT_ABSENT_TYPES = Object.freeze(["max_speed", "track", "latitude", "longitude"]);

const SOURCES = Object.freeze({
  sport: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/app-access/getSportData/",
  extension: "https://docs.zepp.com/docs/guides/workout-extension/intro/",
  extensionQuick: "https://docs.zepp.com/docs/guides/workout-extension/quick-start/",
  distance: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Distance/",
  sportWidget: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/ui/widget/SPORT_DATA/",
  workout: "https://docs.zepp.com/docs/reference/device-app-api/newAPI/sensor/Workout/",
  devices: "https://docs.zepp.com/docs/reference/related-resources/device-list/",
});

export function extensionListed(deviceName) {
  return WORKOUT_EXTENSION_DEVICES.indexOf(deviceName) >= 0;
}

export function parseSportCallback(type, callbackResult) {
  if (SPORT_ABSENT_TYPES.indexOf(type) >= 0 || SPORT_READ_TYPES.indexOf(type) < 0) {
    return { ok: false, availability: "UNAVAILABLE", reason: "TYPE_NOT_DOCUMENTED", valueText: "", unit: "UNRESOLVED" };
  }
  if (!callbackResult || callbackResult.code !== 0 || typeof callbackResult.data !== "string") {
    return { ok: false, availability: "EXTENSION_ONLY", reason: "NO_SAMPLE", valueText: "", unit: "UNRESOLVED" };
  }
  let parsed = null;
  try {
    parsed = JSON.parse(callbackResult.data);
  } catch (err) {
    parsed = null;
  }
  const row = Array.isArray(parsed) ? parsed[0] : null;
  if (!row || row[type] == null || row[type] === "") {
    return { ok: false, availability: "EXTENSION_ONLY", reason: "MISSING_FIELD", valueText: "", unit: "UNRESOLVED" };
  }
  return {
    ok: true,
    availability: "EXTENSION_ONLY",
    reason: "",
    valueText: String(row[type]),
    unit: "UNRESOLVED",
    certified: false,
  };
}

export function characterizeDistanceReading(value) {
  const numeric = typeof value === "number" && isFinite(value) ? value : null;
  return {
    availability: "AGGREGATE_ONLY",
    value: numeric,
    unit: "UNRESOLVED",
    sessionAttribution: "UNRESOLVED",
    nativeWorkoutDistance: false,
    usedInGnss: false,
  };
}

export function compareKnownRoute() {
  return {
    availability: "HARDWARE_PENDING",
    compared: false,
    nativeMeters: null,
    experimentalMeters: null,
  };
}

export function capabilityMatrix() {
  const bip6Listed = extensionListed("Amazfit Bip 6");
  return [
    {
      metric: "workout_distance_speed_duration",
      availability: "EXTENSION_ONLY",
      source: SOURCES.extensionQuick,
      note: "getSportData is documented with the Workout Extension flow. distance, speed, and duration come back as display strings.",
    },
    {
      metric: "independent_device_app_on_bip6",
      availability: "HARDWARE_PENDING",
      source: SOURCES.sport,
      note: "The reference page does not document a standalone Device App session. This build does not call getSportData.",
    },
    {
      metric: "workout_extension_on_bip6",
      availability: bip6Listed ? "NATIVE_DIRECT" : "UNAVAILABLE",
      source: SOURCES.extension,
      note: "The intro lists six devices. Bip 6 is absent. Device-list API_LEVEL 4.2 does not add it.",
    },
    {
      metric: "distance_get_current",
      availability: "AGGREGATE_ONLY",
      source: SOURCES.distance,
      note: "getCurrent returns a number. The unit and the session it belongs to are not documented, so it is not native workout distance.",
    },
    {
      metric: "native_maximum_speed_readable",
      availability: "UNAVAILABLE",
      source: SOURCES.sport,
      note: "SportType has speed and avg_speed. It has no maximum-speed field.",
    },
    {
      metric: "sport_data_speed_max_display",
      availability: "EXTENSION_ONLY",
      source: SOURCES.sportWidget,
      note: "SPEED_MAX is a Workout Extension widget type. The widget draws text. It does not return a number to JavaScript.",
    },
    {
      metric: "full_gps_track",
      availability: "UNAVAILABLE",
      source: SOURCES.workout,
      note: "No public call returns the workout polyline. getWorkoutTrackNavInfo is yaw, remaining distance, and the next turn. Geolocation is the current fix.",
    },
    {
      metric: "outdoor_walking_versus_experimental",
      availability: "HARDWARE_PENDING",
      source: SOURCES.devices,
      note: "A known-route comparison has not been run. No native or experimental total is invented here.",
    },
  ];
}
