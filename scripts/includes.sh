#!/bin/bash

ENV_FILE="/.env"
CRON_CONFIG_FILE="${HOME}/crontabs"
BACKUP_DIR="/data/backup"

#################### Function ####################
########################################
# Print colorful message.
# Arguments:
#     color
#     message
# Outputs:
#     colorful message
########################################
function color() {
    case $1 in
        red)     echo -e "\033[31m$2\033[0m" ;;
        green)   echo -e "\033[32m$2\033[0m" ;;
        yellow)  echo -e "\033[33m$2\033[0m" ;;
        blue)    echo -e "\033[34m$2\033[0m" ;;
        none)    echo "$2" ;;
    esac
}

########################################
# Check storage system connection success.
# Arguments:
#     None
########################################
function check_rclone_connection() {
    # check configuration exist
    rclone ${RCLONE_GLOBAL_FLAG} config show "${RCLONE_REMOTE_NAME}" > /dev/null 2>&1
    if [[ $? != 0 ]]; then
        color red "rclone configuration information not found"
        color blue "Please configure rclone first, check https://github.com/AdrienPoupa/rclone-backup/blob/master/README.md#backup"
        exit 1
    fi

    # check connection
    local HAS_ERROR="FALSE"

    for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
    do
        rclone ${RCLONE_GLOBAL_FLAG} mkdir "${RCLONE_REMOTE_X}"
        if [[ $? != 0 ]]; then
            color red "Storage system connection failure $(color yellow "[${RCLONE_REMOTE_X}]")"

            HAS_ERROR="TRUE"
        fi
    done

    if [[ "${HAS_ERROR}" == "TRUE" ]]; then
        exit 1
    fi
}

########################################
# Check file is exist.
# Arguments:
#     file
########################################
function check_file_exist() {
    if [[ ! -f "$1" ]]; then
        color red "cannot access $1: No such file"
        exit 1
    fi
}

########################################
# Check directory is exist.
# Arguments:
#     directory
########################################
function check_dir_exist() {
    if [[ ! -d "$1" ]]; then
        color red "cannot access $1: No such directory"
        exit 1
    fi
}

########################################
# Send mail by s-nail.
# Arguments:
#     mail subject
#     mail content
# Outputs:
#     send mail result
########################################
function send_mail() {
    if [[ "${MAIL_DEBUG}" == "TRUE" ]]; then
        local MAIL_VERBOSE="-v"
    fi

    echo "$2" | mail ${MAIL_VERBOSE} -s "$1" ${MAIL_SMTP_VARIABLES} "${MAIL_TO}"
    if [[ $? != 0 ]]; then
        color red "Error when sending mail"
    else
        color blue "Mail sent successfully"
    fi
}

########################################
# Send mail.
# Arguments:
#     backup successful
#     mail content
########################################
function send_mail_content() {
    if [[ "${MAIL_SMTP_ENABLE}" == "FALSE" ]]; then
        return
    fi

    # successful
    if [[ "$1" == "TRUE" && "${MAIL_WHEN_SUCCESS}" == "TRUE" ]]; then
        send_mail "Backup Success" "$2"
    fi

    # failed
    if [[ "$1" == "FALSE" && "${MAIL_WHEN_FAILURE}" == "TRUE" ]]; then
        send_mail "Backup Failed" "$2"
    fi
}

########################################
# Send health check ping.
# Arguments:
#     None
########################################
function send_ping() {
    if [[ -z "${PING_URL}" ]]; then
        return
    fi

    wget "${PING_URL}" -T 15 -t 10 -O /dev/null -q
    if [[ $? != 0 ]]; then
        color red "Error when sending ping"
    else
        color blue "Ping sent was successfully"
    fi
}

########################################
# Configure PostgreSQL password file.
# Arguments:
#     None
########################################
function configure_postgresql() {
    if [[ "${DB_TYPE}" == "POSTGRESQL" ]]; then
        echo "${PG_HOST}:${PG_PORT}:${PG_DBNAME}:${PG_USERNAME}:${PG_PASSWORD}" > ~/.pgpass
        chmod 0600 ~/.pgpass
    fi
}

########################################
# Export variables from .env file.
# Arguments:
#     None
# Outputs:
#     variables with prefix 'DOTENV_'
# Reference:
#     https://gist.github.com/judy2k/7656bfe3b322d669ef75364a46327836#gistcomment-3632918
########################################
function export_env_file() {
    if [[ -f "${ENV_FILE}" ]]; then
        color blue "find \"${ENV_FILE}\" file and export variables"
        set -a
        source <(cat "${ENV_FILE}" | sed -e '/^#/d;/^\s*$/d' -e 's/\(\w*\)[ \t]*=[ \t]*\(.*\)/DOTENV_\1=\2/')
        set +a
    fi
}

########################################
# Get variables from
#     environment variables,
#     secret file in environment variables,
#     secret file in .env file,
#     environment variables in .env file.
# Arguments:
#     variable name
# Outputs:
#     variable value
########################################
function get_env() {
    local VAR="$1"
    local VAR_FILE="${VAR}_FILE"
    local VAR_DOTENV="DOTENV_${VAR}"
    local VAR_DOTENV_FILE="DOTENV_${VAR_FILE}"
    local VALUE=""

    if [[ -n "${!VAR:-}" ]]; then
        VALUE="${!VAR}"
    elif [[ -n "${!VAR_FILE:-}" ]]; then
        VALUE="$(cat "${!VAR_FILE}")"
    elif [[ -n "${!VAR_DOTENV_FILE:-}" ]]; then
        VALUE="$(cat "${!VAR_DOTENV_FILE}")"
    elif [[ -n "${!VAR_DOTENV:-}" ]]; then
        VALUE="${!VAR_DOTENV}"
    fi

    export "${VAR}=${VALUE}"
}

########################################
# Get RCLONE_REMOTE_LIST variables.
# Arguments:
#     None
# Outputs:
#     variable value
########################################
function get_rclone_remote_list() {
    RCLONE_REMOTE_LIST=()

    local i=0
    local RCLONE_REMOTE_NAME_X_REFER
    local RCLONE_REMOTE_DIR_X_REFER
    local RCLONE_REMOTE_X

    # for multiple
    while true; do
        RCLONE_REMOTE_NAME_X_REFER="RCLONE_REMOTE_NAME_${i}"
        RCLONE_REMOTE_DIR_X_REFER="RCLONE_REMOTE_DIR_${i}"
        get_env "${RCLONE_REMOTE_NAME_X_REFER}"
        get_env "${RCLONE_REMOTE_DIR_X_REFER}"

        if [[ -z "${!RCLONE_REMOTE_NAME_X_REFER}" || -z "${!RCLONE_REMOTE_DIR_X_REFER}" ]]; then
            break
        fi

        RCLONE_REMOTE_X=$(echo "${!RCLONE_REMOTE_NAME_X_REFER}:${!RCLONE_REMOTE_DIR_X_REFER}" | sed 's@\(/*\)$@@')
        RCLONE_REMOTE_LIST=(${RCLONE_REMOTE_LIST[@]} "${RCLONE_REMOTE_X}")

        ((i++))
    done
}

########################################
# Get BACKUP_FOLDER_LIST variables.
# Arguments:
#     None
# Outputs:
#     variable value
########################################
function get_backup_folder_list() {
    BACKUP_FOLDER_LIST=()

    local i=0
    local BACKUP_FOLDER_NAME_X_REFER
    local BACKUP_FOLDER_PATH_X_REFER
    local BACKUP_FOLDER_X

    # for multiple
    while true; do
        BACKUP_FOLDER_NAME_X_REFER="BACKUP_FOLDER_NAME_${i}"
        BACKUP_FOLDER_PATH_X_REFER="BACKUP_FOLDER_PATH_${i}"
        get_env "${BACKUP_FOLDER_NAME_X_REFER}"
        get_env "${BACKUP_FOLDER_PATH_X_REFER}"

        if [[ -z "${!BACKUP_FOLDER_NAME_X_REFER}" || -z "${!BACKUP_FOLDER_PATH_X_REFER}" ]]; then
            break
        fi

        BACKUP_FOLDER_X=$(echo "${!BACKUP_FOLDER_NAME_X_REFER}:${!BACKUP_FOLDER_PATH_X_REFER}" | sed 's@\(/*\)$@@')
        BACKUP_FOLDER_LIST=(${BACKUP_FOLDER_LIST[@]} "${BACKUP_FOLDER_X}")

        ((i++))
    done
}

########################################
# Initialization environment variables.
# Arguments:
#     None
# Outputs:
#     environment variables
########################################
function init_env() {
    # export
    export_env_file

    init_env_db
    init_env_mail

    # CRON
    get_env CRON
    CRON="${CRON:-"5 * * * *"}"

    # RCLONE_REMOTE_NAME
    get_env RCLONE_REMOTE_NAME
    RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-"RcloneBackup"}"
    RCLONE_REMOTE_NAME_0="${RCLONE_REMOTE_NAME}"

    # RCLONE_REMOTE_DIR
    get_env RCLONE_REMOTE_DIR
    RCLONE_REMOTE_DIR="${RCLONE_REMOTE_DIR:-"/RcloneBackup/"}"
    RCLONE_REMOTE_DIR_0="${RCLONE_REMOTE_DIR}"

    # get RCLONE_REMOTE_LIST
    get_rclone_remote_list

    # RCLONE_GLOBAL_FLAG
    get_env RCLONE_GLOBAL_FLAG
    RCLONE_GLOBAL_FLAG="${RCLONE_GLOBAL_FLAG:-""}"

    # ZIP_ENABLE
    get_env ZIP_ENABLE
    ZIP_ENABLE=$(echo "${ZIP_ENABLE}" | tr '[a-z]' '[A-Z]')
    if [[ "${ZIP_ENABLE}" == "FALSE" ]]; then
        ZIP_ENABLE="FALSE"
    else
        ZIP_ENABLE="TRUE"
    fi

    # ZIP_PASSWORD
    get_env ZIP_PASSWORD
    ZIP_PASSWORD="${ZIP_PASSWORD:-"123456"}"

    # ZIP_TYPE
    get_env ZIP_TYPE
    ZIP_TYPE=$(echo "${ZIP_TYPE}" | tr '[A-Z]' '[a-z]')
    if [[ "${ZIP_TYPE}" == "7z" ]]; then
        ZIP_TYPE="7z"
    else
        ZIP_TYPE="zip"
    fi

    # BACKUP_KEEP_DAYS
    get_env BACKUP_KEEP_DAYS
    BACKUP_KEEP_DAYS="${BACKUP_KEEP_DAYS:-"0"}"

    # BACKUP_FILE_DATE_FORMAT
    get_env BACKUP_FILE_SUFFIX
    get_env BACKUP_FILE_DATE
    get_env BACKUP_FILE_DATE_SUFFIX
    BACKUP_FILE_DATE="$(echo "${BACKUP_FILE_DATE:-"%Y%m%d"}${BACKUP_FILE_DATE_SUFFIX}" | sed 's/[^0-9a-zA-Z%_-]//g')"
    BACKUP_FILE_DATE_FORMAT="$(echo "${BACKUP_FILE_SUFFIX:-"${BACKUP_FILE_DATE}"}" | sed 's/\///g')"

    # PING_URL
    get_env PING_URL
    PING_URL="${PING_URL:-""}"

    # TIMEZONE
    get_env TIMEZONE
    local TIMEZONE_MATCHED_COUNT=$(ls "/usr/share/zoneinfo/${TIMEZONE}" 2> /dev/null | wc -l)
    if [[ "${TIMEZONE_MATCHED_COUNT}" -ne 1 ]]; then
        TIMEZONE="UTC"
    fi

    color yellow "========================================"

    # BACKUP_FOLDER_NAME
    get_env BACKUP_FOLDER_NAME
    BACKUP_FOLDER_NAME="${BACKUP_FOLDER_NAME:-"data"}"
    BACKUP_FOLDER_NAME_0="${BACKUP_FOLDER_NAME}"

    # BACKUP_FOLDER_PATH
    get_env BACKUP_FOLDER_PATH
    BACKUP_FOLDER_PATH="${BACKUP_FOLDER_PATH:-"/data/"}"
    BACKUP_FOLDER_PATH_0="${BACKUP_FOLDER_PATH}"

    # get BACKUP_FOLDER_LIST
    get_backup_folder_list

    # DB_TYPE
    DB_TYPE="${DB_TYPE:-"none"}"

    color yellow "DB_TYPE: ${DB_TYPE}"

    if [[ "${DB_TYPE}" == "POSTGRESQL" ]]; then
        color yellow "DB_URL: postgresql://${PG_USERNAME}:***(${#PG_PASSWORD} Chars)@${PG_HOST}:${PG_PORT}/${PG_DBNAME}"
    elif [[ "${DB_TYPE}" == "MYSQL" ]]; then
        color yellow "DB_URL: mysql://${MYSQL_USERNAME}:***(${#MYSQL_PASSWORD} Chars)@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}"
    elif [[ "${DB_TYPE}" == "SQLITE" ]]; then
        color yellow "SQLITE_DATABASE: ${SQLITE_DATABASE}"
    fi

    color yellow "CRON: ${CRON}"

    for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
    do
        color yellow "RCLONE_REMOTE: ${RCLONE_REMOTE_X}"
    done

    color yellow "RCLONE_GLOBAL_FLAG: ${RCLONE_GLOBAL_FLAG}"

    for BACKUP_FOLDER_X in "${BACKUP_FOLDER_LIST[@]}"
    do
        local BACKUP_FOLDER_NAME=$(echo ${BACKUP_FOLDER_X} | cut -d: -f1)
        local BACKUP_FOLDER_PATH=$(echo ${BACKUP_FOLDER_X} | cut -d: -f2)
        color yellow "BACKUP_FOLDER_NAME: ${BACKUP_FOLDER_NAME}"
        color yellow "BACKUP_FOLDER_PATH: ${BACKUP_FOLDER_PATH}"
    done

    color yellow "ZIP_ENABLE: ${ZIP_ENABLE}"
    color yellow "ZIP_PASSWORD: ${#ZIP_PASSWORD} Chars"
    color yellow "ZIP_TYPE: ${ZIP_TYPE}"
    color yellow "BACKUP_FILE_DATE_FORMAT: ${BACKUP_FILE_DATE_FORMAT} (example \"[filename].$(date +"${BACKUP_FILE_DATE_FORMAT}").[ext]\")"
    color yellow "BACKUP_KEEP_DAYS: ${BACKUP_KEEP_DAYS}"
    if [[ -n "${PING_URL}" ]]; then
        color yellow "PING_URL: ${PING_URL}"
    fi
    color yellow "MAIL_SMTP_ENABLE: ${MAIL_SMTP_ENABLE}"
    if [[ "${MAIL_SMTP_ENABLE}" == "TRUE" ]]; then
        color yellow "MAIL_TO: ${MAIL_TO}"
        color yellow "MAIL_WHEN_SUCCESS: ${MAIL_WHEN_SUCCESS}"
        color yellow "MAIL_WHEN_FAILURE: ${MAIL_WHEN_FAILURE}"
    fi
    color yellow "TIMEZONE: ${TIMEZONE}"
    color yellow "========================================"
}

function init_env_db() {
    # DB_TYPE
    get_env DB_TYPE

    if [[ "${DB_TYPE^^}" == "POSTGRESQL" ]]; then # postgresql
        DB_TYPE="POSTGRESQL"

        # PG_HOST
        get_env PG_HOST

        # PG_PORT
        get_env PG_PORT
        PG_PORT="${PG_PORT:-"5432"}"

        # PG_DBNAME
        get_env PG_DBNAME
        PG_DBNAME="${PG_DBNAME:-"database"}"

        # PG_USERNAME
        get_env PG_USERNAME
        PG_USERNAME="${PG_USERNAME:-"root"}"

        # PG_PASSWORD
        get_env PG_PASSWORD
    elif [[ "${DB_TYPE^^}" == "MYSQL" ]]; then # mysql
        DB_TYPE="MYSQL"

        # MYSQL_HOST
        get_env MYSQL_HOST

        # MYSQL_PORT
        get_env MYSQL_PORT
        MYSQL_PORT="${MYSQL_PORT:-"3306"}"

        # MYSQL_DATABASE
        get_env MYSQL_DATABASE
        MYSQL_DATABASE="${MYSQL_DATABASE:-"database"}"

        # MYSQL_USERNAME
        get_env MYSQL_USERNAME
        MYSQL_USERNAME="${MYSQL_USERNAME:-"root"}"

        # MYSQL_PASSWORD
        get_env MYSQL_PASSWORD
    elif [[ "${DB_TYPE^^}" == "SQLITE" ]]; then # sqlite
        DB_TYPE="SQLITE"
        get_env SQLITE_DATABASE
        SQLITE_DATABASE="${SQLITE_DATABASE:-"${BACKUP_FOLDER_PATH}/db.sqlite3"}"
    fi
}

function init_env_mail() {
    # MAIL_SMTP_ENABLE
    # MAIL_TO
    get_env MAIL_SMTP_ENABLE
    get_env MAIL_TO
    MAIL_SMTP_ENABLE=$(echo "${MAIL_SMTP_ENABLE}" | tr '[a-z]' '[A-Z]')
    if [[ "${MAIL_SMTP_ENABLE}" == "TRUE" && "${MAIL_TO}" ]]; then
        MAIL_SMTP_ENABLE="TRUE"
    else
        MAIL_SMTP_ENABLE="FALSE"
    fi

    # MAIL_SMTP_VARIABLES
    get_env MAIL_SMTP_VARIABLES
    MAIL_SMTP_VARIABLES="${MAIL_SMTP_VARIABLES:-""}"

    # MAIL_WHEN_SUCCESS
    get_env MAIL_WHEN_SUCCESS
    MAIL_WHEN_SUCCESS=$(echo "${MAIL_WHEN_SUCCESS}" | tr '[a-z]' '[A-Z]')
    if [[ "${MAIL_WHEN_SUCCESS}" == "FALSE" ]]; then
        MAIL_WHEN_SUCCESS="FALSE"
    else
        MAIL_WHEN_SUCCESS="TRUE"
    fi

    # MAIL_WHEN_FAILURE
    get_env MAIL_WHEN_FAILURE
    MAIL_WHEN_FAILURE=$(echo "${MAIL_WHEN_FAILURE}" | tr '[a-z]' '[A-Z]')
    if [[ "${MAIL_WHEN_FAILURE}" == "FALSE" ]]; then
        MAIL_WHEN_FAILURE="FALSE"
    else
        MAIL_WHEN_FAILURE="TRUE"
    fi
}
