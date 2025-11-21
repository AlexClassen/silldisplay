import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import oebb from 'oebb-api';

const app = express();
const PORT = 3000;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SILLPARK_EVA_ID = 1370165; // Innsbruck Sillpark

let latestJourneys = [];
let lastUpdate = null;
let lastError = null;

async function fetchSillparkBoard() {
  try {
    const options = oebb.getStationBoardDataOptions();
    options.evaId = SILLPARK_EVA_ID;

    const boardData = await oebb.getStationBoardData(options);

    const journeys = boardData.journey || [];

    latestJourneys = journeys.map(journey => {
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
        from: journey.st,              // station (Sillpark)
        to: journey.lastStop,          // final destination
        status,                        // 'on-time' | 'delayed' | 'cancelled'
        delayMinutes: rt.dlm || 0,     // delay in minutes, if any
        realtimeTime: rt.dlt || null   // real-time departure, if provided
      };
    });

    lastUpdate = new Date();
    lastError = null;
    console.log('Updated Sillpark board at', lastUpdate.toISOString());
  } catch (error) {
    console.error('Error fetching station board data:', error);
    lastError = error.message || String(error);
  }
}

// First run immediately, then every minute
await fetchSillparkBoard();
setInterval(fetchSillparkBoard, 60_000);

// API endpoint for frontend
app.get('/api/journeys', (req, res) => {
  if (!latestJourneys.length && lastError) {
    return res.status(500).json({
      error: 'Error fetching station board data.',
      details: lastError
    });
  }

  if (!latestJourneys.length) {
    return res.status(404).json({
      message: 'Aktuell keine Verbindungen gefunden.'
    });
  }

  res.json({
    updatedAt: lastUpdate,
    journeys: latestJourneys
  });
});

// Serve static frontend
app.use(express.static(path.join(__dirname, 'public')));

app.listen(PORT, () => {
  console.log(`Sillpark display running at http://localhost:${PORT}`);
});
