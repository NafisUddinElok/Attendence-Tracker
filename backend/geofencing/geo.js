// server.js
const express = require('express');
const cors = require('cors');

const app = express();
app.use(express.json());
app.use(cors());

// Define your classroom's exact coordinates and allowed radius
const CLASSROOM_CONFIG = {
  latitude: 23.8103,   // Replace with your actual classroom latitude
  longitude: 90.4125,  // Replace with your actual classroom longitude
  radiusMeters: 50     // 50 meters is a good balance for GPS accuracy
};

// The Haversine Formula: Calculates distance between two points on Earth
function calculateDistanceInMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth's radius in meters
  const toRadians = (deg) => deg * (Math.PI / 180);

  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
            
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

app.post('/mark-attendance', (req, res) => {
  const { studentId, latitude, longitude, isMocked } = req.body;

  // 1. Anti-Spoofing Check
  if (isMocked) {
    return res.status(403).json({ 
      success: false, 
      message: "Fake GPS detected. Please turn off location spoofing." 
    });
  }

  // 2. Calculate Distance
  const distance = calculateDistanceInMeters(
    CLASSROOM_CONFIG.latitude, 
    CLASSROOM_CONFIG.longitude, 
    latitude, 
    longitude
  );

  // 3. Verify Geofence
  if (distance <= CLASSROOM_CONFIG.radiusMeters) {
    // TODO: Save to your database here (e.g., MongoDB, PostgreSQL, Firebase)
    console.log(`Success! Student ${studentId} marked present. Distance: ${Math.round(distance)}m`);
    
    return res.json({ 
      success: true, 
      message: "Attendance marked successfully!" 
    });
  } else {
    console.log(`Failed! Student ${studentId} is ${Math.round(distance)}m away.`);
    
    return res.status(400).json({ 
      success: false, 
      message: `You are too far from the classroom (${Math.round(distance)} meters away).` 
    });
  }
});

app.listen(3000, () => console.log('Attendance server running on port 3000'));