// Vercel Serverless Function: /api/health-sync
// Handles POST (upsert metrics for today) and GET (retrieve metrics by userId and range: day, week, month)

// Persistent memory store for serverless execution instances
const healthMetricsStore = global._healthMetricsStore || new Map();
global._healthMetricsStore = healthMetricsStore;

const userLatestStore = global._userLatestStore || new Map();
global._userLatestStore = userLatestStore;

export default async function handler(req, res) {
  // ── CORS Headers ──────────────────────────────────────────────────────────
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // ── GET: Retrieve stored metrics for userId (range: day, week, month) ──────
  if (req.method === 'GET') {
    const userId = req.query.userId || req.query.user_id;

    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required query parameter: userId',
      });
    }

    const rawRange = (req.query.range || req.query.timeRange || 'day').toLowerCase();
    const range = rawRange.startsWith('week') ? 'week' : (rawRange.startsWith('month') ? 'month' : 'day');

    const userIdStr = String(userId).trim();
    const allRecords = Array.from(healthMetricsStore.values()).filter(r => r.userId === userIdStr);

    const now = new Date();
    const days = range === 'week' ? 7 : (range === 'month' ? 30 : 1);
    const cutoff = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);

    const rangeRecords = allRecords.filter(r => {
      const recDate = new Date(r.updatedAt || r.date);
      return recDate >= cutoff;
    });

    if (range === 'day') {
      const latest = userLatestStore.get(userIdStr) || rangeRecords[rangeRecords.length - 1];
      if (latest) {
        return res.status(200).json({
          success: true,
          range: 'day',
          data: latest,
        });
      }
      return res.status(200).json({
        success: true,
        range: 'day',
        data: {
          userId: userIdStr,
          range: 'day',
          heartRate: 0,
          steps: 0,
          spo2: 0,
          sleepHours: 0,
          date: new Date().toISOString().split('T')[0],
          updatedAt: null,
        },
      });
    }

    // Weekly or Monthly aggregation: Total steps/calories, Average HR/SpO2, Nightly average Sleep
    let sumSteps = 0;
    let sumHr = 0;
    let countHr = 0;
    let sumSpo2 = 0;
    let countSpo2 = 0;
    let sumSleep = 0;
    let latestUpdatedAt = null;

    for (const r of rangeRecords) {
      sumSteps += (Number(r.steps) || 0);
      if (r.heartRate && Number(r.heartRate) > 0) {
        sumHr += Number(r.heartRate);
        countHr++;
      }
      if (r.spo2 && Number(r.spo2) > 0) {
        sumSpo2 += Number(r.spo2);
        countSpo2++;
      }
      sumSleep += (Number(r.sleepHours) || 0);
      if (r.updatedAt && (!latestUpdatedAt || new Date(r.updatedAt) > new Date(latestUpdatedAt))) {
        latestUpdatedAt = r.updatedAt;
      }
    }

    const fallbackLatest = userLatestStore.get(userIdStr);
    if (rangeRecords.length === 0 && fallbackLatest) {
      sumSteps = fallbackLatest.steps || 0;
      sumHr = fallbackLatest.heartRate || 0;
      countHr = sumHr > 0 ? 1 : 0;
      sumSpo2 = fallbackLatest.spo2 || 0;
      countSpo2 = sumSpo2 > 0 ? 1 : 0;
      sumSleep = fallbackLatest.sleepHours || 0;
      latestUpdatedAt = fallbackLatest.updatedAt;
    }

    const aggregated = {
      userId: userIdStr,
      range,
      steps: sumSteps,                                                       // Total steps
      heartRate: countHr > 0 ? Math.round(sumHr / countHr) : 0,            // Average heart rate
      spo2: countSpo2 > 0 ? Math.round((sumSpo2 / countSpo2) * 10) / 10 : 0,   // Average SpO2
      sleepHours: days > 0 ? Math.round((sumSleep / days) * 10) / 10 : 0,    // Nightly average sleep hours
      updatedAt: latestUpdatedAt || fallbackLatest?.updatedAt || null,
    };

    return res.status(200).json({
      success: true,
      range,
      data: aggregated,
    });
  }

  // ── POST: Upsert metrics keyed by (userId, date=today) ────────────────────
  if (req.method === 'POST') {
    try {
      const body = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});

      // Support camelCase AND snake_case property keys
      const rawUserId = body.userId ?? body.user_id;
      const rawHeartRate = body.heartRate ?? body.heart_rate;
      const rawSteps = body.steps;
      const rawSpo2 = body.spo2 ?? body.blood_oxygen;
      const rawSleepHours = body.sleepHours ?? body.sleep_hours;

      if (rawUserId === undefined || rawUserId === null || rawUserId === '') {
        return res.status(400).json({
          success: false,
          error: 'Missing required field: userId',
        });
      }

      const userId = String(rawUserId).trim();
      const todayDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
      const key = `${userId}_${todayDate}`;

      const updatedRecord = {
        userId,
        date: todayDate,
        heartRate: Number(rawHeartRate) || 0,
        steps: Number(rawSteps) || 0,
        spo2: Number(rawSpo2) || 0,
        sleepHours: Number(rawSleepHours) || 0,
        updatedAt: new Date().toISOString(),
      };

      // Upsert into memory store
      healthMetricsStore.set(key, updatedRecord);
      userLatestStore.set(userId, updatedRecord);

      console.log(`[health-sync] Upserted metrics for user ${userId} on ${todayDate}:`, updatedRecord);

      return res.status(200).json({
        success: true,
        message: 'Health metrics synced successfully',
        data: updatedRecord,
      });
    } catch (err) {
      console.error('[health-sync] Error processing POST payload:', err);
      return res.status(500).json({
        success: false,
        error: 'Failed to parse JSON body or process request',
        details: err.message,
      });
    }
  }

  return res.status(405).json({
    success: false,
    error: `Method ${req.method} Not Allowed`,
  });
}
