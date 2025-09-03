-- Create system_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS system_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    container_name TEXT,
    message TEXT,
    level TEXT,
    metadata JSONB
);

-- Create index on timestamp for faster queries
CREATE INDEX IF NOT EXISTS system_logs_timestamp_idx ON system_logs (timestamp);

-- Create index on service for filtering
CREATE INDEX IF NOT EXISTS system_logs_service_idx ON system_logs (container_name);

-- Create index on level for filtering
CREATE INDEX IF NOT EXISTS system_logs_level_idx ON system_logs (level);

-- Create databases for services if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'authelia') THEN
        CREATE DATABASE authelia;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'openwebui') THEN
        CREATE DATABASE openwebui;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'uptimekuma') THEN
        CREATE DATABASE uptimekuma;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'vaultwarden') THEN
        CREATE DATABASE vaultwarden;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'postiz') THEN
        CREATE DATABASE postiz;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'coolify') THEN
        CREATE DATABASE coolify;
    END IF;
END
$$; 