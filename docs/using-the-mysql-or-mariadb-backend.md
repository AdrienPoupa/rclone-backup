# Using the MySQL(MariaDB) backend

Now supports MySQL(MariaDB) backend.

<br>



## Environment Variables

#### DB_TYPE

Set to `mysql` switch to MySQL(MariaDB) database.

Default: `none`

#### MYSQL_HOST

MySQL(MariaDB) host, **required**.

#### MYSQL_PORT

MySQL(MariaDB) port.

Default: `3306`

#### MYSQL_DATABASE

MySQL(MariaDB) database name.

Default: `database`

#### MYSQL_USERNAME

MySQL(MariaDB) username.

Default: `root`

#### MYSQL_PASSWORD

MySQL(MariaDB) password, **required**.

<br>



## Backup

Specify the above environment variables to switch to the MySQL(MariaDB) database.

<br>



## Restore

When restoring, also specify the above environment variables to switch to the MySQL(MariaDB) database.

1. Ensure that the database is accessible.

Perhaps you will use the `docker-compose up -d [services name]` command to start the database separately.

2. Verify that the `MYSQL_HOST` you are using is accessible to.

If your database is running in docker-compose, you need to find the corresponding network name via `docker network ls`  and add `--network=[name]` to the restore command to specify the network name.

3. Restore and restart the container.
