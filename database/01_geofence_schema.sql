-- Create the main table for storing attendance zones
CREATE TABLE attendance_zones (
    id SERIAL PRIMARY KEY,
    location_name VARCHAR(100) NOT NULL,
    
    -- We use GEOGRAPHY to accurately measure distances over the Earth's curve.
    -- SRID 4326 is the standard GPS coordinate system (WGS 84).
    center_point GEOGRAPHY(Point, 4326) NOT NULL,
    
    -- Radius in meters for circular geofences
    radius_meters INTEGER DEFAULT 100, 
    
    -- Optional: If you need custom polygonal shapes instead of just circles
    polygon_boundary GEOMETRY(Polygon, 4326), 
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- IMPORTANT: Create spatial indexes. 
-- This is what makes PostGIS incredibly fast when checking if a user is inside a fence.
CREATE INDEX idx_attendance_zones_center ON attendance_zones USING GIST (center_point);
CREATE INDEX idx_attendance_zones_boundary ON attendance_zones USING GIST (polygon_boundary);