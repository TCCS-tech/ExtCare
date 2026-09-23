-- Run connected to the target database (e.g. myapp_development), not to 'postgres',
-- so default privileges attach to the right DB.

BEGIN;

-- Login role for the Rails app
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'extcare') THEN
    CREATE ROLE extcare LOGIN PASSWORD 'password';
  ELSE
    ALTER ROLE extcare WITH LOGIN PASSWORD 'password';
  END IF;
END
$$;

-- Schema
CREATE SCHEMA IF NOT EXISTS extcare AUTHORIZATION extcare;

-- Database-level
GRANT CONNECT ON DATABASE current_database() TO extcare;
GRANT TEMP ON DATABASE current_database() TO extcare;

-- Schema usage + create objects
GRANT USAGE, CREATE ON SCHEMA extcare TO extcare;

-- Existing objects
GRANT ALL PRIVILEGES ON ALL TABLES    IN SCHEMA extcare TO extcare;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA extcare TO extcare;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA extcare TO extcare;

-- Future objects created by this session / by a superuser running migrations
ALTER DEFAULT PRIVILEGES IN SCHEMA extcare
  GRANT ALL PRIVILEGES ON TABLES    TO extcare;
ALTER DEFAULT PRIVILEGES IN SCHEMA extcare
  GRANT ALL PRIVILEGES ON SEQUENCES TO extcare;
ALTER DEFAULT PRIVILEGES IN SCHEMA extcare
  GRANT ALL PRIVILEGES ON FUNCTIONS TO extcare;

-- If you still create objects as postgres, also pin defaults for that role:
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA extcare
  GRANT ALL PRIVILEGES ON TABLES    TO extcare;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA extcare
  GRANT ALL PRIVILEGES ON SEQUENCES TO extcare;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA extcare
  GRANT ALL PRIVILEGES ON FUNCTIONS TO extcare;

-- App should resolve unqualified names in extcare first
ALTER ROLE extcare SET search_path TO extcare, public;

-- Optional: keep public usable for extensions (pgcrypto, plpgsql, etc.)
GRANT USAGE ON SCHEMA public TO extcare;

COMMIT;