import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import oebb from 'oebb-api';

const app = express();
const PORT = 3000;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Cache for station boards: evaId -> { journeys, lastUpdate, lastError, stationName }
const stationBoards = new Map();

async function fetchStationBoard(evaId, stationName = null) {
  try {
    const options = oebb.getStationBoardDataOptions();
    options.evaId = evaId;

    const boardData = await oebb.getStationBoardData(options);
    const journeys = boardData.journey || [];

    const mappedJourneys = journeys.map((journey) => {
      const rt = journey.rt || {};

      let status = 'on-time';
      if (rt.status === 'Ausfall') {
        status = 'cancelled';
      } else if (rt.dlm) {
        status = 'delayed';
      }

      return {
        departure: journey.ti, // planned time
        date: journey.da,
        tram: journey.pr, // line / train name
        from: journey.st, // station
        to: journey.lastStop, // final destination
        status, // 'on-time' | 'delayed' | 'cancelled'
        delayMinutes: rt.dlm || 0, // delay in minutes, if any
        realtimeTime: rt.dlt || null, // real-time departure, if provided
      };
    });

    const name = stationName || boardData.stationName || `Station ${evaId}`;
    stationBoards.set(evaId, {
      journeys: mappedJourneys,
      lastUpdate: new Date(),
      lastError: null,
      stationName: name,
    });

    console.log(`Updated board for ${name} (${evaId}) at`, new Date().toISOString());
  } catch (error) {
    console.error(`Error fetching station board data for evaId ${evaId}:`, error);

    const current = stationBoards.get(evaId) || {};
    stationBoards.set(evaId, {
      journeys: current.journeys || [],
      lastUpdate: current.lastUpdate || null,
      lastError: error.message || String(error),
      stationName: current.stationName || stationName || `Station ${evaId}`,
    });
  }
}

// Search stations via OEBB API
app.get('/api/stations/search', async (req, res) => {
  const q = (req.query.q || '').trim();
  if (!q || q.length < 2) {
    return res.json({ stations: [] });
  }
  try {
    const options = oebb.getStationSearchOptions();
    options.S = q;
    options.REQ0JourneyStopsB = 20;
    const results = await oebb.searchStations(options);
    const stations = (results || [])
      .filter((s) => s.extId && s.value)
      .map((s) => ({
        evaId: parseInt(s.extId, 10),
        name: s.value,
        type: s.typeStr || '',
      }));
    res.json({ stations });
  } catch (error) {
    console.error('Station search error:', error);
    res.status(500).json({ error: 'Suche fehlgeschlagen.', stations: [] });
  }
});

// Journeys for a specific station (?evaId=...)
app.get('/api/journeys', async (req, res) => {
  const evaId = Number(req.query.evaId);
  if (!evaId) {
    return res.status(400).json({ message: 'evaId fehlt.' });
  }

  let board = stationBoards.get(evaId);
  if (!board || (board.lastError && !board.journeys?.length)) {
    await fetchStationBoard(evaId);
    board = stationBoards.get(evaId);
  }

  if (!board) {
    return res.status(404).json({
      message: 'Noch keine Verbindungen gefunden (Station nicht geladen).',
    });
  }

  const { journeys, lastUpdate, lastError, stationName } = board;

  if (!journeys.length && lastError) {
    return res.status(500).json({
      error: 'Error fetching station board data.',
      details: lastError,
    });
  }

  if (!journeys.length) {
    return res.status(404).json({
      message: 'Aktuell keine Verbindungen gefunden.',
    });
  }

  res.json({
    updatedAt: lastUpdate,
    journeys,
    stationName: stationName || `Station ${evaId}`,
  });
});

// Background refresh for recently requested stations (every 60s)
const REFRESH_INTERVAL_MS = 60_000;
setInterval(() => {
  for (const [evaId, board] of stationBoards) {
    if (board.lastUpdate && Date.now() - board.lastUpdate.getTime() < REFRESH_INTERVAL_MS * 3) {
      fetchStationBoard(evaId, board.stationName);
    }
  }
}, REFRESH_INTERVAL_MS);

// Route for station page - serve station.html (before static so it matches first)
app.get('/station/:evaId', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'station.html'));
});

// Serve static frontend
app.use(express.static(path.join(__dirname, 'public')));

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Sill display running at http://0.0.0.0:${PORT}`);
});
