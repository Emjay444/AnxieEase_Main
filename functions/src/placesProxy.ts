import * as functions from "firebase-functions/v1";

// Server-side proxy for Google Maps Platform REST APIs (Places Nearby Search,
// Places Text Search, Directions). The Maps key never ships in the app -
// it lives only here as an environment variable, set via functions/.env
// (MAPS_SERVER_KEY). This closes the "API key embedded in the APK" hole:
// anyone could previously decompile the app and lift the key to run up
// billing on our project indefinitely.
const MAPS_SERVER_KEY = process.env.MAPS_SERVER_KEY;

async function proxyGoogleMaps(
  targetUrl: string,
  query: Record<string, unknown>,
  res: functions.Response
) {
  if (!MAPS_SERVER_KEY) {
    res.status(500).json({
      status: "REQUEST_DENIED",
      error_message: "MAPS_SERVER_KEY is not configured on the server",
    });
    return;
  }

  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === "") continue;
    params.set(key, String(value));
  }
  params.set("key", MAPS_SERVER_KEY);

  try {
    const response = await fetch(`${targetUrl}?${params.toString()}`);
    const data = await response.json();
    res.status(response.status).json(data);
  } catch (error) {
    console.error("placesProxy: upstream request failed", error);
    res.status(502).json({
      status: "UNKNOWN_ERROR",
      error_message: "Failed to reach Google Maps Platform",
    });
  }
}

export const placesNearbySearch = functions.https.onRequest(
  async (req, res) => {
    await proxyGoogleMaps(
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
      req.query as Record<string, unknown>,
      res
    );
  }
);

export const placesTextSearch = functions.https.onRequest(async (req, res) => {
  await proxyGoogleMaps(
    "https://maps.googleapis.com/maps/api/place/textsearch/json",
    req.query as Record<string, unknown>,
    res
  );
});

export const mapsDirections = functions.https.onRequest(async (req, res) => {
  await proxyGoogleMaps(
    "https://maps.googleapis.com/maps/api/directions/json",
    req.query as Record<string, unknown>,
    res
  );
});
