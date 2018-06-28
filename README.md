# Migrate Between Postgresql Databases using Postgresql Foreign Data Wrapper

## Migrate using Docker Container and Database Backup (SKIP to [below](#Setup-Foreign-Data-Wrapper) if you are already have db servers running)
### Setup Data Container and Restore DB

**REQUIREMENT:** Get [docker](https://docs.docker.com/engine/installation/linux/ubuntulinux/) and [docker-compose](https://docs.docker.com/compose/install/)

Follow these steps to prepare the data containers

#### Old Database
* Create a container that won't do anything other than keeping your data:
  ```shell
  docker create -v /dbdata --name old-dbstore postgres:9.6 /bin/true
  ```
* Run an ephemeral container that will be used to restore the backup to the old-dbstore volumes:
  ```shell
  docker run --rm --volumes-from old-dbstore -p 5432:5432 postgres:9.6
  ```
* With this container running (it will be killed if you press ctrl+c, so use another terminal or client app), backup whatever you need through port 5432.
  * Create your local containerized database. Start by using pgAdmin 3 (use pgAdmin 4 if you'd like, but there have been complaints about its UI) to create the database server.
    ```
    Name: old_db_server
    Host: 0.0.0.0
    Port: 5432
    Maintenance DB: postgres
    Username: postgres
    ```
  * Add a new database `old_db`. Right-click on the newly created `old_db` database and click `Restore...`. Choose the latest `.backup` file and use it to restore the db. This may take several minutes.
* Done with the DB. The docker-compose files refer to old-dbstore as the data container, so keep it around to use those. You can also manually connect to this postgres store from other containers using its access port or a postgres:9.6 image and the options `--volumes-from old-dbstore`.

#### New Database
**IMPORTANT:** The following steps will be a repeat of the above steps with `old-dbstore` replaced with `dbstore`, `old_db` replaced with `db` and `old_db_server` replaced with `db_server`.

* Create a container that won't do anything other than keeping your data:
  ```shell
  docker create -v /dbdata --name dbstore postgres:9.6 /bin/true
  ```
* Run an ephemeral container that will be used to restore the backup to the dbstore volumes:
  ```shell
  docker run --rm --volumes-from dbstore -p 5432:5432 postgres:9.6
  ```
* With this container running (it will be killed if you press ctrl+c, so use another terminal or client app), backup whatever you need through port 5432.
  * Create your local containerized database. Start by using pgAdmin 3 (use pgAdmin 4 if you'd like, but there have been complaints about its UI) to create the database server.
    ```
    Name: db_server
    Host: 0.0.0.0
    Port: 5433
    Maintenance DB: postgres
    Username: postgres
    ```
  * Add a new database `db`. Right-click on the newly created `db` database and click `Restore...`. Choose the latest `.backup` file and use it to restore the db. This may take several minutes.
* Done with the DB. The docker-compose files refer to dbstore as the data container, so keep it around to use those. You can also manually connect to this postgres store from other containers using its access port or a postgres:9.6 image and the options `--volumes-from dbstore`.

### Setup Docker-Compose File
You can find the below code in the following [docker-compose file](./docker-compose.yml). What this is doing is setting up the two database containers that you will connect with using [pgAdmin](https://www.pgadmin.org/) or any other db management tool.

```
version: '2.1'

services:
  old-db-server:
    image: postgres:9.6
    ports:
      - 5432:5432
    volumes_from:
      - container:old-dbstore:rw

  db-server:
    image: postgres:9.6
    ports:
      - 5433:5432
    volumes_from:
      - container:dbstore:rw
```

After setting up the `docker-compose file`. Run the following command from the project root directory (where you created the `docker-compose file`) to bring up the two containers.

```
docker-compose up
```

## Setup Foreign Data Wrapper
You can find the below code in the [data migration file](./data-migration.sql).

In `pgAdmin`, open the query panel for the current database (ex. `db`) under your current database server (ex. `db-server`).

Run the following command in the query panel.

```
-- Install the postgres_fdw extension
CREATE EXTENSION postgres_fdw;

-- Create a server
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
```

Now you can use `old_db_server_db` as if it was a table in your datebase.

```
SELECT * from old_db_server_db.username

-- Migrate username from old_db to current db
INSERT INTO users (id, username, created_at, updated_at)
SELECT id::BIGINT, username, created_at, updated_at 
FROM old_db_server_db.users
```

Make sure to clean up afterward

```
-- Clean up
-- Drop the server connection and schema
DROP SCHEMA old_db_server_db CASCADE;
DROP SERVER foreign_db CASCADE;
```

**Resource:**
* PostgreSQL's Foreign Data Wrapper Documentation ([Link](https://www.postgresql.org/docs/9.5/static/postgres-fdw.html))
* PostgreSQL's Foreign Data Wrapper Article ([Link](https://robots.thoughtbot.com/postgres-foreign-data-wrapper))