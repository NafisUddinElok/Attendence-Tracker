const crypto = require('crypto');

// -------------------------------------------------------------
// 1. Generate Cryptographically Secure Secret for TOTP
// -------------------------------------------------------------
exports.generateTotpSecret = () => {
  return crypto.randomBytes(20).toString('hex');
};

// -------------------------------------------------------------
// 2. Generate 15-Second Rolling Dynamic Token
// -------------------------------------------------------------
exports.generateTimeToken = (secret, offsetStep = 0) => {
  const timeStep = Math.floor(Date.now() / 15000) + offsetStep;
  const hmac = crypto.createHmac('sha256', secret);
  hmac.update(timeStep.toString());
  return hmac.digest('hex').substring(0, 8).toUpperCase();
};

// -------------------------------------------------------------
// 3. Verify Dynamic TOTP Token (With +/- 1 step clock drift tolerance)
// -------------------------------------------------------------
exports.verifyTimeToken = (secret, token, toleranceSteps = 1) => {
  if (!secret || !token) return false;

  for (let offset = -toleranceSteps; offset <= toleranceSteps; offset++) {
    const expectedToken = exports.generateTimeToken(secret, offset);
    if (expectedToken === token.toUpperCase().trim()) {
      return true;
    }
  }
  return false;
};

// -------------------------------------------------------------
// 4. Calculate Distance in Meters (Haversine Formula)
// -------------------------------------------------------------
exports.calculateHaversineDistance = (lat1, lon1, lat2, lon2) => {
  const toRad = (value) => (value * Math.PI) / 180;
  const R = 6371000; // Earth radius in meters

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

// -------------------------------------------------------------
// 5. Cosine Similarity for 192D MobileFaceNet Vector Comparison
// -------------------------------------------------------------
exports.calculateCosineSimilarity = (vecA, vecB) => {
  if (!Array.isArray(vecA) || !Array.isArray(vecB) || vecA.length !== vecB.length || vecA.length === 0) {
    return 0;
  }

  let dotProduct = 0.0;
  let normA = 0.0;
  let normB = 0.0;

  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }

  if (normA === 0 || normB === 0) return 0;
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
};

// -------------------------------------------------------------
// 6. UUID v4 Format Guard
// -------------------------------------------------------------
exports.isValidUUID = (uuid) => {
  const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return typeof uuid === 'string' && regex.test(uuid);
};