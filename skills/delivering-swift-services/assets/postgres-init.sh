#!/bin/bash
# Creates each service's database and its owner on the shared Postgres instance. Copy to
# postgres-init/10-databases.sh beside compose.yaml and repeat the create_database line per
# service. The postgres image runs it from /docker-entrypoint-initdb.d only while its data volume
# is empty; for a service added later, run the same three statements once as the administrator.
# The owner only migrates: it gets CREATEROLE so its role migrations run, and serving connects as
# those roles. Role names are cluster-wide, so every service's roles are named distinctly.
set -euo pipefail

create_database() {
  local database=$1 owner=$2 password=$3
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
    -v database="$database" -v owner="$owner" -v password="$password" <<'SQL'
CREATE ROLE :"owner" LOGIN CREATEROLE PASSWORD :'password';
CREATE DATABASE :"database" OWNER :"owner";
REVOKE ALL ON DATABASE :"database" FROM PUBLIC;
SQL
}

create_database "<project>_<service>" "${<SERVICE>_OWNER:?set the database owner}" "${<SERVICE>_OWNER_PASSWORD:?set the database owner's password}"
