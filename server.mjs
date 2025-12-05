import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import oebb from 'oebb-api';

const app = express();
const PORT = 3000;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Define the stations you want to rotate through.
 * Replace evaIds with the real ones you need.
 */
const STATIONS = [
  { evaId: 1370165, label: 'Innsbruck Sillpark' },
  { evaId: 8100108, label: 'Innsbruck Hauptbahnhof' }
];

// Cache for station boards: evaId -> { journeys, lastUpdate, lastError }
const stationBoards = new Map();

async function fetchStationBoard(station) {
  try {
    const options = oebb.getStationBoardDataOptions();
    options.evaId = station.evaId;

    const boardData = await oebb.getStationBoardData(options);
    const journeys = boardData.journey || [];

    const mappedJourneys = journeys.map(journey => {
      const rt = journey.rt || {};

      let status = 'on-time';
      if (rt.status === 'Ausfall') {
        status = 'cancelled';
      } else if (rt.dlm) {
        status = 'delayed';
      }

      return {
        departure: journey.ti,         // planned time
        date: journey.da,
        tram: journey.pr,              // line / train name
        from: journey.st,              // station
        to: journey.lastStop,          // final destination
        status,                        // 'on-time' | 'delayed' | 'cancelled'
        delayMinutes: rt.dlm || 0,     // delay in minutes, if any
        realtimeTime: rt.dlt || null   // real-time departure, if provided
      };
    });

    stationBoards.set(station.evaId, {
      journeys: mappedJourneys,
      lastUpdate: new Date(),
      lastError: null
    });

    console.log(
      `Updated board for ${station.label} (${station.evaId}) at`,
      new Date().toISOString()
    );
  } catch (error) {
    console.error(
      `Error fetching station board data for ${station.label} (${station.evaId}):`,
      error
    );

    const current = stationBoards.get(station.evaId) || {};
    stationBoards.set(station.evaId, {
      journeys: current.journeys || [],
      lastUpdate: current.lastUpdate || null,
      lastError: error.message || String(error)
    });
  }
}

// Initial fetch for all stations, then refresh every minute
for (const station of STATIONS) {
  await fetchStationBoard(station);
  setInterval(() => fetchStationBoard(station), 60_000);
}

// List stations for the frontend
app.get('/api/stations', (req, res) => {
  res.json({ stations: STATIONS });
});

// Journeys for a specific station (?evaId=...)
app.get('/api/journeys', (req, res) => {
  const evaId = Number(req.query.evaId) || STATIONS[0].evaId;
  const board = stationBoards.get(evaId);

  if (!board) {
    return res.status(404).json({
      message: 'Noch keine Verbindungen gefunden (Station nicht geladen).'
    });
  }

  const { journeys, lastUpdate, lastError } = board;

  if (!journeys.length && lastError) {
    return res.status(500).json({
      error: 'Error fetching station board data.',
      details: lastError
    });
  }

  if (!journeys.length) {
    return res.status(404).json({
      message: 'Aktuell keine Verbindungen gefunden.'
    });
  }

  res.json({
    updatedAt: lastUpdate,
    journeys
  });
});

// Serve static frontend
app.use(express.static(path.join(__dirname, 'public')));

app.listen(PORT, () => {
  console.log(`Sill display running at http://localhost:${PORT}`);
});
