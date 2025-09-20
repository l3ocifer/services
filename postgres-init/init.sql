-- Vector database initialization script
-- Creates necessary tables and databases for vector log processing

-- Create vector_metrics database if it doesn't exist
SELECT 'CREATE DATABASE vector_metrics' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'vector_metrics');

-- Connect to vector_metrics database (this will be handled by the application)
-- Create metrics table for system metrics
CREATE TABLE IF NOT EXISTS metrics (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    service VARCHAR(255),
    metric_name VARCHAR(255),
    metric_value DOUBLE PRECISION,
    tags JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index on timestamp for better query performance
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_metrics_service ON metrics(service);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics(metric_name);

-- Grant permissions
GRANT ALL PRIVILEGES ON TABLE metrics TO postgres;
GRANT USAGE, SELECT ON SEQUENCE metrics_id_seq TO postgres;
