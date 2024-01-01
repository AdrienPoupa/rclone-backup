#!/bin/bash

. /app/includes.sh

function clear_dir() {
    rm -rf "${BACKUP_DIR}"
}

function backup_init() {
    NOW="$(date +"${BACKUP_FILE_DATE_FORMAT}")"
    # backup database file (sqlite)
    BACKUP_FILE_DB_SQLITE="${BACKUP_DIR}/db.${NOW}.sqlite3"
    # backup database file (postgresql)
    BACKUP_FILE_DB_POSTGRESQL="${BACKUP_DIR}/db.${NOW}.dump"
    # backup database file (mysql)
    BACKUP_FILE_DB_MYSQL="${BACKUP_DIR}/db.${NOW}.sql"
    # backup zip file
    BACKUP_FILE_ZIP="${BACKUP_DIR}/backup.${NOW}.${ZIP_TYPE}"
}

function backup_folders() {
    color blue "Backup folders"

    for BACKUP_FOLDER_X in "${BACKUP_FOLDER_LIST[@]}"
    do
        local BACKUP_FOLDER_NAME=$(echo ${BACKUP_FOLDER_X} | cut -d: -f1)
        local BACKUP_FOLDER_PATH=$(echo ${BACKUP_FOLDER_X} | cut -d: -f2)
        local BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FOLDER_NAME}.${NOW}.tar"

        color blue "Backing up $(color yellow "[${BACKUP_FOLDER_NAME}]")"

        if [[ -d "${BACKUP_FOLDER_PATH}" ]]; then
            tar -C "${BACKUP_FOLDER_PATH}" -cf "${BACKUP_FILE}" .

            color blue "Backed up files:"

            tar -tf "${BACKUP_FILE}"
        else
            color yellow "${BACKUP_FOLDER_PATH} does not exist, skipping"
        fi
    done
}

function backup_db_sqlite() {
    color blue "Backup SQLite database"

    if [[ -f "${SQLITE_DATABASE}" ]]; then
        sqlite3 "${SQLITE_DATABASE}" ".backup '${BACKUP_FILE_DB_SQLITE}'"
    else
        color yellow "SQLite database not found, skipping"
    fi
}

function backup_db_postgresql() {
    color blue "Backup PostgreSQL database"

    pg_dump -Fc -h "${PG_HOST}" -p "${PG_PORT}" -d "${PG_DBNAME}" -U "${PG_USERNAME}" -f "${BACKUP_FILE_DB_POSTGRESQL}"
    if [[ $? != 0 ]]; then
        color red "Backup PostgreSQL database failed"

        send_mail_content "FALSE" "Backup failed at $(date +"%Y-%m-%d %H:%M:%S %Z"). Reason: Backup postgresql database failed."

        exit 1
    fi
}

function backup_db_mysql() {
    color blue "Backup MySQL database"

    mariadb-dump -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" "${MYSQL_DATABASE}" > "${BACKUP_FILE_DB_MYSQL}"
    if [[ $? != 0 ]]; then
        color red "Backup MySQL database failed"

        send_mail_content "FALSE" "Backup failed at $(date +"%Y-%m-%d %H:%M:%S %Z"). Reason: Backup mysql database failed."

        exit 1
    fi
}

function backup() {
    mkdir -p "${BACKUP_DIR}"

    backup_folders

    case "${DB_TYPE}" in
        SQLITE)     backup_db_sqlite ;;
        POSTGRESQL) backup_db_postgresql ;;
        MYSQL)      backup_db_mysql ;;
    esac

    ls -lah "${BACKUP_DIR}"
}

function backup_package() {
    if [[ "${ZIP_ENABLE}" == "TRUE" ]]; then
        color blue "Package backup file"

        UPLOAD_FILE="${BACKUP_FILE_ZIP}"

        if [[ "${ZIP_TYPE}" == "zip" ]]; then
            7z a -tzip -mx=9 -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}" "${BACKUP_DIR}"/*
        else
            7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}" "${BACKUP_DIR}"/*
        fi

        ls -lah "${BACKUP_DIR}"

        color blue "Display backup ${ZIP_TYPE} file list"

        7z l -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}"
    else
        color yellow "Skipped package backup files"

        UPLOAD_FILE="${BACKUP_DIR}"
    fi
}

function upload() {
    # upload file not exist
    if [[ ! -e "${UPLOAD_FILE}" ]]; then
        color red "Upload file not found"

        send_mail_content "FALSE" "File upload failed at $(date +"%Y-%m-%d %H:%M:%S %Z"). Reason: Upload file not found."

        exit 1
    fi

    # upload
    local HAS_ERROR="FALSE"

    for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
    do
        color blue "Upload backup file to storage system $(color yellow "[${RCLONE_REMOTE_X}]")"

        rclone ${RCLONE_GLOBAL_FLAG} copy "${UPLOAD_FILE}" "${RCLONE_REMOTE_X}"
        if [[ $? != 0 ]]; then
            color red "upload failed"

            HAS_ERROR="TRUE"
        fi
    done

    if [[ "${HAS_ERROR}" == "TRUE" ]]; then
        send_mail_content "FALSE" "File upload failed at $(date +"%Y-%m-%d %H:%M:%S %Z")."

        exit 1
    fi
}

function clear_history() {
    if [[ "${BACKUP_KEEP_DAYS}" -gt 0 ]]; then
        for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
        do
            color blue "Delete backup files from ${BACKUP_KEEP_DAYS} days ago $(color yellow "[${RCLONE_REMOTE_X}]")"

            mapfile -t RCLONE_DELETE_LIST < <(rclone ${RCLONE_GLOBAL_FLAG} lsf "${RCLONE_REMOTE_X}" --min-age "${BACKUP_KEEP_DAYS}d")

            for RCLONE_DELETE_FILE in "${RCLONE_DELETE_LIST[@]}"
            do
                color yellow "Deleting \"${RCLONE_DELETE_FILE}\""

                rclone ${RCLONE_GLOBAL_FLAG} delete "${RCLONE_REMOTE_X}/${RCLONE_DELETE_FILE}"
                if [[ $? != 0 ]]; then
                    color red "Deleting \"${RCLONE_DELETE_FILE}\" failed"
                fi
            done
        done
    fi
}

color blue "Running the backup program at $(date +"%Y-%m-%d %H:%M:%S %Z")"

init_env
check_rclone_connection

clear_dir
backup_init
backup
backup_package
upload
clear_dir
clear_history

send_mail_content "TRUE" "The file was successfully uploaded at $(date +"%Y-%m-%d %H:%M:%S %Z")."
send_ping

color none ""
