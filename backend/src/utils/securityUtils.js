const crypto = require('crypto');

// ------------------------------------------------------------------
// 1. Calculate Haversine Distance (in Meters) between two GPS points
// ------------------------------------------------------------------
exports.calculateDistanceMeters = (lat1, lon1, lat2, lon2) => {
  const R = 6371000; // Earth's mean radius in meters
  const toRad = (deg) => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in meters
};

// ------------------------------------------------------------------
// 2. Cosine Similarity for Face Embeddings (128D / 192D Float Vectors)
// ------------------------------------------------------------------
exports.calculateCosineSimilarity = (vectorA, vectorB) => {
  if (!Array.isArray(vectorA) || !Array.isArray(vectorB) || vectorA.length !== vectorB.length) {
    return 0.0;
  }

  let dotProduct = 0.0;
  let normA = 0.0;
  let normB = 0.0;

  for (let i = 0; i < vectorA.length; i++) {
    dotProduct += vectorA[i] * vectorB[i];
    normA += vectorA[i] * vectorA[i];
    normB += vectorB[i] * vectorB[i];
  }

  if (normA === 0 || normB === 0) return 0.0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
};

// ------------------------------------------------------------------
// 3. Generate Rolling 15-Second Dynamic Token (TOTP-style)
// ------------------------------------------------------------------
exports.generateTimeToken = (secret, timeStepOffset = 0) => {
  const timeStep = Math.floor(Date.now() / 15000) + timeStepOffset; // 15s window
  return crypto
    .createHmac('sha256', secret)
    .update(timeStep.toString())
    .digest('hex')
    .substring(0, 8)
    .toUpperCase();
};

// ------------------------------------------------------------------
// 4. Validate Token with ±1 Step Grace Window (for network delay)
// ------------------------------------------------------------------
exports.verifyTimeToken = (incomingToken, secret) => {
  const currentToken = exports.generateTimeToken(secret, 0);
  const previousToken = exports.generateTimeToken(secret, -1); // 15s grace window

  return incomingToken === currentToken || incomingToken === previousToken;
};


// UUID Format Validator
exports.isValidUUID = (uuid) => {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return typeof uuid === 'string' && uuidRegex.test(uuid.trim());
};