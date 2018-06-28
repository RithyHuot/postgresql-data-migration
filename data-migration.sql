-- Install the postgres_fdw extension
CREATE EXTENSION postgres_fdw;

CREATE SERVER foreign_db
        FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'old-db-server', port '5432', dbname 'old_db', updatable 'false');

-- Create a user mapping, which defines the credentials that a user on the local server will use to make queries against the remote server
CREATE USER MAPPING FOR CURRENT_USER
        SERVER foreign_db
        OPTIONS (user 'postgres', password '');

-- Create foreign tables for all of the tables from our old_db_server database’s public schema
CREATE SCHEMA old_db_server_db;

-- Importing the created schema into our current database
IMPORT FOREIGN SCHEMA public
    FROM SERVER foreign_db INTO old_db_server_db;

-- Migrate username from old_db to current db
INSERT INTO users (id, username, created_at, updated_at)
SELECT id::BIGINT, username::VARCHAR(256), created_at, updated_at
FROM old_db_server_db.users

-- Clean up 
-- Drop the server connection and schema
DROP SCHEMA old_db_server_db CASCADE;
DROP SERVER foreign_db CASCADE;