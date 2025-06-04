# Rclone Backup

[![Docker Image Version (latest by date)](https://img.shields.io/docker/v/adrienpoupa/rclone-backup?label=Version&logo=docker)](https://hub.docker.com/r/adrienpoupa/rclone-backup/tags) [![Docker Pulls](https://img.shields.io/docker/pulls/adrienpoupa/rclone-backup?label=Docker%20Pulls&logo=docker)](https://hub.docker.com/r/adrienpoupa/rclone-backup) [![GitHub](https://img.shields.io/github/license/adrienpoupa/rclone-backup?label=License&logo=github)](https://github.com/AdrienPoupa/rclone-backup/blob/master/LICENSE)

Forked from [ttionya/vaultwarden-backup](https://github.com/ttionya/vaultwarden-backup).

This tool supports backing up the following files or directories.

- Any directory you specify
- SQLite databases
- MySQL/MariaDB databases
- PostgreSQL databases

And the following ways of notifying backup results are supported.

- Ping (only send on success)
- Mail (SMTP based, send on success and on failure)

## Usage

### Configure Rclone (⚠️ MUST READ ⚠️)

> **You need to configure Rclone first, otherwise the backup tool will not work.**

We upload the backup files to the storage system by [Rclone](https://rclone.org/).

Visit [GitHub](https://github.com/rclone/rclone) for more storage system tutorials. Different systems get tokens differently.

#### Configure and Check

You can get the token by the following command.

```shell
docker run --rm -it \
  --mount type=volume,source=rclone-backup-data,target=/config/ \
  adrienpoupa/rclone-backup:latest \
  rclone config
```

**We recommend setting the remote name to `RcloneBackup`, otherwise you need to specify the environment variable `RCLONE_REMOTE_NAME` as the remote name you set.**

After setting, check the configuration content by the following command.

```shell
docker run --rm -it \
  --mount type=volume,source=rclone-backup-data,target=/config/ \
  adrienpoupa/rclone-backup:latest \
  rclone config show

# AWS S3 Example
# [RcloneBackup]
# type = s3
# provider = AWS
# access_key_id = <key>
# secret_access_key = <key>
# region = us-east-1
# location_constraint = us-east-1
# acl = private
# server_side_encryption = AES256
# storage_class = INTELLIGENT_TIERING
# bucket_acl = private
# no_check_bucket = true
```

Download `docker-compose.yml` to you machine, edit environment variables and start it.

You need to go to the directory where the `docker-compose.yml` file is saved.

#### Options

<details>
<summary><strong>※ You have the compressed file named <code>backup</code></strong></summary>

##### --zip-file \<file>

You need to use this option to specify the `backup` compressed package.

Make sure the file name in the compressed package has not been changed.

##### -p / --password

THIS IS INSECURE!

If the `backup` compressed package has a password, you can use this option to set the password to extract it.

If not, the password will be asked for interactively.

</details>

## Environment Variables

> **Note:** All environment variables have default values, you can use the docker image without setting any environment variables.

#### RCLONE_REMOTE_NAME

The name of the Rclone remote, which needs to be consistent with the remote name in the rclone config.

You can view the current remote name with the following command.

```shell
docker run --rm -it \
  --mount type=volume,source=rclone-backup-data,target=/config/ \
  adrienpoupa/rclone-backup:latest \
  rclone config show

# [RcloneBackup] <- this
# ...
```

Default: `RcloneBackup`

#### RCLONE_REMOTE_DIR

The folder where backup files are stored in the storage system.

Default: `/RcloneBackup/`

#### RCLONE_GLOBAL_FLAG

Rclone global flags, see [flags](https://rclone.org/flags/).

**Do not add flags that will change the output, such as `-P`, which will affect the deletion of outdated backup files.**

Default: `''`

#### CRON

Schedule to run the backup script, based on [`supercronic`](https://github.com/aptible/supercronic). You can test the rules [here](https://crontab.guru/#5_*_*_*_*).

Default: `5 * * * *` (run the script at 5 minute every hour)

#### DB_TYPE

Database to back up, can be one of `sqlite`, `mysql` or `postgresql`.

Default: `none` to disable.

#### BACKUP_FOLDER_NAME

Name of the folder to back up, eg `data`.

Default: `data`

#### BACKUP_FOLDER_PATH

Path of the folder to back up, eg `/data`/

Default: `/data`

Multiple folders can be backed up by doing the following, with the same syntax as [multiple remotes](docs/multiple-remote-destinations.md):

```
BACKUP_FOLDER_NAME_1: first-folder
BACKUP_FOLDER_PATH_1: /first
BACKUP_FOLDER_NAME_2: second-folder
BACKUP_FOLDER_PATH_2: /second
```

#### ZIP_ENABLE

Pack all backup files into a compressed file. When set to `'FALSE'`, each backup file will be uploaded independently.

Default: `TRUE`

#### ZIP_PASSWORD

The password for the compressed file. Note that the password will always be used when packing the backup files.

Default: `123456`

#### ZIP_TYPE

Because the `zip` format is less secure, we offer archives in `7z` format for those who seek security.

Default: `zip` (only support `zip` and `7z` formats)

#### BACKUP_KEEP_DAYS

Only keep last a few days backup files in the storage system. Set to `0` to keep all backup files.

Default: `0`

#### BACKUP_FILE_SUFFIX

Each backup file is suffixed by default with `%Y%m%d`. If you back up your vault multiple times a day, that suffix is not unique anymore. This environment variable allows you to append a unique suffix to that date to create a unique backup name.

You can use any character except for `/` since it cannot be used in Linux file names.

This environment variable combines the functionalities of [`BACKUP_FILE_DATE`](#backup_file_date) and [`BACKUP_FILE_DATE_SUFFIX`](#backup_file_date_suffix), and has a higher priority. You can directly use this environment variable to control the suffix of the backup files.

Please use the [date man page](https://man7.org/linux/man-pages/man1/date.1.html) for the format notation.

Default: `%Y%m%d`

#### TIMEZONE

Set your timezone name.

Here is timezone list at [wikipedia](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

Default: `UTC`

#### DISPLAY_NAME

A custom name to identify your vaultwarden instance in notifications and logs.

This doesn't affect functionality, it only affects the display in the notification title and partial log output.

Default: `RcloneBackup`

<details>
<summary><strong>※ Other environment variables</strong></summary>

> **You don't need to change these environment variables unless you know what you are doing.**

#### BACKUP_FILE_DATE

You should use the [`BACKUP_FILE_SUFFIX`](#backup_file_suffix) environment variable instead.

Edit this environment variable only if you explicitly want to change the time prefix of the backup file (e.g. 20220101). **Incorrect configuration may result in the backup file being overwritten by mistake.**

Same rule as [`BACKUP_FILE_DATE_SUFFIX`](#backup_file_date_suffix).

Default: `%Y%m%d`

#### BACKUP_FILE_DATE_SUFFIX

You should use the [`BACKUP_FILE_SUFFIX`](#backup_file_suffix) environment variable instead.

Each backup file is suffixed by default with `%Y%m%d`. If you back up your vault multiple times a day, that suffix is not unique anymore.
This environment variable allows you to append a unique suffix to that date (`%Y%m%d${BACKUP_FILE_DATE_SUFFIX}`) to create a unique backup name.

Note that only numbers, upper and lower case letters, `-`, `_`, `%` are supported.

Please use the [date man page](https://man7.org/linux/man-pages/man1/date.1.html) for the format notation.

Default: `''`

#### SQLITE_DATABASE

Set the path for the SQLite database file.

Default: `${BACKUP_FOLDER_PATH}/db.sqlite3`

</details>

## Notification

### Ping

We provide functionality to send notifications when the backup is completed, started, successful, or failed.

**Using a [healthcheck.io](https://healthchecks.io/) address or other similar cron monitoring addresses is a good choice, and it is also recommended.** For more complex notification scenarios, you can use environment variables with the `_CURL_OPTIONS` suffix to set curl options. For example, you can add request headers, change the request method, etc.

For different notification scenarios, **the backup tool provides `%{subject}` and `%{content}` placeholders to replace the actual title and content**. You can use them in the following environment variables. Note that the title and content may contain spaces. For the four environment variables containing `_CURL_OPTIONS`, the placeholders will be directly replaced, retaining spaces. For other `PING_URL` environment variables, spaces will be replaced with `+` to comply with URL rules.

| Environment Variable               | Trigger Status                  | Test Identifier | Description                                                          |
| ---------------------------------- | ------------------------------- | --------------- | -------------------------------------------------------------------- |
| PING_URL                           | completion (success or failure) | `completion`    | The URL to which the request is sent after the backup is completed.  |
| PING_URL_CURL_OPTIONS              |                                 |                 | Curl options used with `PING_URL`                                    |
| PING_URL_WHEN_START                | start                           | `start`         | The URL to which the request is sent when the backup starts.         |
| PING_URL_WHEN_START_CURL_OPTIONS   |                                 |                 | Curl options used with `PING_URL_WHEN_START`                         |
| PING_URL_WHEN_SUCCESS              | success                         | `success`       | The URL to which the request is sent after the backup is successful. |
| PING_URL_WHEN_SUCCESS_CURL_OPTIONS |                                 |                 | Curl options used with `PING_URL_WHEN_SUCCESS`                       |
| PING_URL_WHEN_FAILURE              | failure                         | `failure`       | The URL to which the request is sent after the backup fails.         |
| PING_URL_WHEN_FAILURE_CURL_OPTIONS |                                 |                 | Curl options used with `PING_URL_WHEN_FAILURE`                       |

<br>

### Ping Test

You can use the following command to test the Ping sending.

The "test identifier" is the identifier in the table in the [previous section](#ping). You can use `completion`, `start`, `success`, or `failure`, which determines which set of environment variables to use.

```shell
docker run --rm -it \
  -e PING_URL='<your ping url>' \
  -e PING_URL_CURL_OPTIONS='<your curl options for PING_URL>' \
  -e PING_URL_WHEN_START='<your ping url>' \
  -e PING_URL_WHEN_START_CURL_OPTIONS='<your curl options for PING_URL_WHEN_START>' \
  -e PING_URL_WHEN_SUCCESS='<your ping url>' \
  -e PING_URL_WHEN_SUCCESS_CURL_OPTIONS='<your curl options for PING_URL_WHEN_SUCCESS>' \
  -e PING_URL_WHEN_FAILURE='<your ping url>' \
  -e PING_URL_WHEN_FAILURE_CURL_OPTIONS='<your curl options for PING_URL_WHEN_FAILURE>' \
  adrienpoupa/rclone-backup:latest ping <test identifier>
```

<br>

### Mail

| Environment Variable | Default Value | Description                                           |
| -------------------- | ------------- | ----------------------------------------------------- |
| MAIL_SMTP_ENABLE     | `FALSE`       | Enable sending mail.                                  |
| MAIL_SMTP_VARIABLES  |               | Mail sending options.                                 |
| MAIL_TO              |               | The recipient of the notification email.              |
| MAIL_WHEN_SUCCESS    | `TRUE`        | Send an email when the backup completes successfully. |
| MAIL_WHEN_FAILURE    | `TRUE`        | Send an email if the backup fails.                    |

For `MAIL_SMTP_VARIABLES`, you need to configure the mail sending options yourself. **We will set the email subject based on the usage scenario, so you should not use the `-s` flag.**

```text
# My example:

# For Zoho
-S smtp-use-starttls \
-S smtp=smtp://smtp.zoho.com:587 \
-S smtp-auth=login \
-S smtp-auth-user=<my-email-address> \
-S smtp-auth-password=<my-email-password> \
-S from=<my-email-address>
```

Console showing warnings? Check [issue #177](https://github.com/ttionya/vaultwarden-backup/issues/117#issuecomment-1691443179) for more details.

<br>

### Mail Test

You can use the following command to test mail sending. We will add the `-v` flag to display detailed information, so you do not need to set it again in `MAIL_SMTP_VARIABLES`.

```shell
docker run --rm -it -e MAIL_SMTP_VARIABLES='<your smtp variables>' ttionya/vaultwarden-backup:latest mail <mail send to>

# Or

docker run --rm -it -e MAIL_SMTP_VARIABLES='<your smtp variables>' -e MAIL_TO='<mail send to>' ttionya/vaultwarden-backup:latest mail
```

<br>

## Environment Variables Considerations

### Using `.env` file

If you prefer using an env file instead of environment variables, you can map the env file containing the environment variables to the `/.env` file in the container.

```shell
docker run -d \
  --mount type=bind,source=/path/to/env,target=/.env \
  adrienpoupa/rclone-backup:latest
```

### Docker Secrets

As an alternative to passing sensitive information via environment variables, `_FILE` may be appended to the previously listed environment variables. This causes the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in `/run/secrets/<secret_name>` files.

```shell
docker run -d \
  -e ZIP_PASSWORD_FILE=/run/secrets/zip-password \
  adrienpoupa/rclone-backup:latest
```

### About Priority

We will use the environment variables first, followed by the contents of the file ending in `_FILE` as defined by the environment variables. Next, we will use the contents of the file ending in `_FILE` as defined in the `.env` file, and finally the values from the `.env` file itself.

## Advanced

- [Run as non-root user](docs/run-as-non-root-user.md)
- [Multiple remote destinations](docs/multiple-remote-destinations.md)
- [Manually trigger a backup](docs/manually-trigger-a-backup.md)
- [Using the PostgreSQL backend](docs/using-the-postgresql-backend.md)
- [Using the MySQL(MariaDB) backend](docs/using-the-mysql-or-mariadb-backend.md)

## License

MIT
