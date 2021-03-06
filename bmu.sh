#!/usr/bin/env bash
# Back me up. Copyright (c) 2017, https://github.com/devimust/bmu

# trace what gets executed (debugging purposes)
#set -x
# exit script when command fails
set -e
# exit status of last command returning non-zero exit code
set -o pipefail

##################################
# Setup default global variables
##################################

ARCHIVE_PREFIX=""
FORCE=false
PASSWORD=""
SUBFOLDERS=false
VERBOSE=false
ARCHIVE_TYPE="zip"
DRY_RUN=false
TMP_FOLDER=
GLOBAL_START_TIME=$(date +%s)

##################################
# Local functions
##################################

show_help(){
    THIS_NAME=$(basename "$0")

    cat <<EOF
Usage: ${THIS_NAME} [-cdfhnv] [-p PASSWORD] [-s PREFIX] [-t TYPE] [SOURCE DIRECTORY] [DESTINATION DIRECTORY]...
Back Me Up (bmu) archives files and/or folders based on changes found in the target
directory.

Examples:
  ${THIS_NAME} -p p4ss1 /src /dst            # Create protected archive only if source files/folders were modified.
  ${THIS_NAME} -s my-prefix -vdf /src /dst   # Force new archives with prefix, verbosity and only include sub-dirs.

  Main operation mode:
    -c, --cache-dir             temporary cache folder to use as archiving medium
    -d, --sub-dirs              only archive sub directories inside given source directory
    -f, --force                 force process and bypass checking for changes
    -h, --help                  show this help menu
    -n, --dry-run               dry run to see what will happen
    -p, --password PASSWORD     specify password to protect archive(s)
    -s, --string-prefix PREFIX  prefix string to the destination archive file(s)
    -t, --type TYPE             archive type to use (only zip currently available)
    -v, --verbose               verbose output (debugging purposes)

EOF
}

debug_message(){
    if [ ${VERBOSE} = true ]; then
        TIME=$(date +"%H:%M:%S")
        echo "DEBUGGING (${TIME}) : $1"
    fi
}

output_message(){
    if [ ${VERBOSE} = false ]; then
        if [ "$2" = true ]; then
            echo -n "$1"
        else
            echo "$1"
        fi
    fi
}

archive_file_type(){
    case "$1" in
        zip) echo 'zip' ;;
        *) echo "Signal number $1 is not processed" ;;
    esac
}

# @link http://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
calc_nice_duration(){
    local T=$1
    local D=$((T/60/60/24))
    local H=$((T/60/60%24))
    local M=$((T/60%60))
    local S=$((T%60))

    (( D > 0 )) && printf '%d days ' $D
    (( H > 0 )) && printf '%d hours ' $H
    (( M > 0 )) && printf '%d minutes ' $M
    (( D > 0 || H > 0 || M > 0 )) && printf 'and '

    printf '%d seconds\n' $S
}

calc_hash(){
    local STR
    local shaBin
    local cmdOutput

    STR=$1
    shaBin=$(command -v sha256sum)
    cmdOutput=$(echo "${STR}" | ${shaBin})

    echo "$cmdOutput"
}

calc_dir_checksum(){
    local DIR
    local findBin
    local shaBin
    local cmdOutput

    DIR=$1
    findBin=$(command -v find)
    shaBin=$(command -v sha256sum)
    statBin=$(command -v stat)

    # check for file changes based file modification time
    cmdOutput=$(${findBin} "${DIR}" -exec "${statBin}" -c '%y %n' {} + | "${shaBin}")
    # better to check for changes (hash of file contents), but verrrry slow
    #cmdOutput=$(${findBin} "${DIR}" -type f -exec "${shaBin}" "{}" + | sort | "${shaBin}")

    echo "$cmdOutput"
}

archive_folder(){
    local SOURCE_DIR
    local DESTINATION_DIR
    local ARCHIVE_TYPE
    local ARCHIVE_PREFIX
    local FORCE
    local PASSWORD
    local DRY_RUN
    local TMP_DIR

    local CAN_ARCHIVE
    local SOURCE_CHECKSUM
    local SOURCE_HASH
    local START_TIME
    local ARCHIVE_FILE_TYPE
    local DESTINATION_ARCHIVE_FILE
    local DESTINATION_CHECKSUM_FILE

    SOURCE_DIR=$1
    DESTINATION_DIR=$2
    ARCHIVE_TYPE=$3
    ARCHIVE_PREFIX=$4
    FORCE=$5
    PASSWORD=$6
    DRY_RUN=$7
    TMP_DIR=$8

    CAN_ARCHIVE=false
    SOURCE_CHECKSUM=""
    SOURCE_HASH=""
    START_TIME=$(date +%s)
    ARCHIVE_FILE_TYPE=$(archive_file_type "${ARCHIVE_TYPE}")
    DESTINATION_ARCHIVE_FILE="${DESTINATION_DIR}/${ARCHIVE_PREFIX}$(basename "$SOURCE_DIR").${ARCHIVE_TYPE}"
    DESTINATION_CHECKSUM_FILE="${DESTINATION_ARCHIVE_FILE}.crc"

    debug_message "trying to archive ${SOURCE_DIR} to ${DESTINATION_DIR}"

    if [ ! -e "${DESTINATION_CHECKSUM_FILE}" ]; then
        debug_message "no checksum file found (${DESTINATION_CHECKSUM_FILE})"
        output_message "creating new archive on ${SOURCE_DIR}" true
        CAN_ARCHIVE=true
    else
        if [ "${FORCE}" = false ]; then
            DESTINATION_HASH=$(cat "${DESTINATION_CHECKSUM_FILE}")

            debug_message "calculating source folder checksum to compare with destination checksum"
            SOURCE_CHECKSUM=$(calc_dir_checksum "${SOURCE_DIR}")
            SOURCE_HASH=$(calc_hash "${SOURCE_CHECKSUM}")

            if [ "${DESTINATION_HASH}" != "${SOURCE_HASH}" ]; then
                debug_message "changes detected"
                output_message "changes detected on ${SOURCE_DIR}" true
                CAN_ARCHIVE=true
            else
                debug_message "no changes detected"
                output_message "no changes detected on ${SOURCE_DIR}" true
            fi
        else
            debug_message "forcing archive"
            output_message "forcing archive on ${SOURCE_DIR}" true
            CAN_ARCHIVE=true
        fi
    fi

    if [ -z "${SOURCE_CHECKSUM}" ]; then
        debug_message "calculating source folder checksum as this is a new archive or was forced"
        SOURCE_CHECKSUM=$(calc_dir_checksum "${SOURCE_DIR}")
        SOURCE_HASH=$(calc_hash "${SOURCE_CHECKSUM}")
    fi

    if [ "${DRY_RUN}" = true ]; then
        END_TIME=$(date +%s)
        TOTAL_TIME=$((END_TIME - START_TIME))
        NICE_TIME=$(calc_nice_duration "$TOTAL_TIME")

        debug_message "trial run, nothing written (finished in ${NICE_TIME}) (${DESTINATION_ARCHIVE_FILE})"
        output_message " ... trial run, nothing written (finished in ${NICE_TIME}) (${DESTINATION_ARCHIVE_FILE})"
    else
        if [ "${CAN_ARCHIVE}" = true ]; then
            case "$ARCHIVE_FILE_TYPE" in
                zip)
                    debug_message "zip archive started (${DESTINATION_ARCHIVE_FILE})"
                    zipBin=$(command -v zip)

                    TMP_ZIP_OPTION=""
                    if [ ! -z "${TMP_DIR}" ]; then
                        TMP_ZIP_OPTION="-b ${TMP_DIR}"
                    fi

                    cmd="${zipBin} --recurse-paths --paths -9 ${TMP_ZIP_OPTION} "
                    if [ ! -z "${PASSWORD}" ]; then
                        cmd="${cmd} --password ${PASSWORD}"
                    fi
                    cmdOutput=$(${cmd} "${DESTINATION_ARCHIVE_FILE}" "${SOURCE_DIR}")

                    # store hash value in checksum file
                    echo "${SOURCE_HASH}" > "${DESTINATION_CHECKSUM_FILE}"

                    END_TIME=$(date +%s)
                    TOTAL_TIME=$((END_TIME - START_TIME))
                    NICE_TIME=$(calc_nice_duration "$TOTAL_TIME")

                    debug_message "zip archive (finished in ${NICE_TIME}) (${DESTINATION_ARCHIVE_FILE})"
                    output_message " ... (finished in ${NICE_TIME}) (${DESTINATION_ARCHIVE_FILE})"
                    ;;
                *) ;;
            esac
        else
            END_TIME=$(date +%s)
            TOTAL_TIME=$((END_TIME - START_TIME))
            NICE_TIME=$(calc_nice_duration "$TOTAL_TIME")

            debug_message "skipping ${SOURCE_DIR} (finished in ${NICE_TIME})"
            output_message " ... (finished in ${NICE_TIME})"
        fi
    fi
}

##################################
# Main execution
##################################

# @link https://gist.github.com/cosimo/3760587
OPTS=$(getopt -o c:dfhnp:s:t:v --long cache-dir,sub-dirs,force,help,dry-run,password,string-prefix,type,verbose: -n 'parse-options' -- "$@")

if [ "$?" != "0" ]; then
    echo "Failed parsing options." >&2
    exit 1
fi

eval set -- "$OPTS"

while true; do
  case "$1" in
    -c | --cache-dir )     TMP_FOLDER="$2"; shift; shift ;;
    -d | --sub-dirs )      SUBFOLDERS=true; shift ;;
    -f | --force )         FORCE=true; shift ;;
    -h | --help )          show_help && exit 0; shift ;;
    -n | --dry-run )       DRY_RUN=true; shift ;;
    -p | --password )      PASSWORD="$2"; shift; shift ;;
    -s | --string-prefix ) ARCHIVE_PREFIX="$2"; shift; shift ;;
    -t | --type )          ARCHIVE_TYPE="$2"; shift; shift ;;
    -v | --verbose )       VERBOSE=true; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ "$#" -eq 0 ]; then
    show_help
    exit 0
fi

SOURCE_DIR=$1
DESTINATION_DIR=$2

if [ -z "$SOURCE_DIR" ]; then
    echo "No source directory specified" >&2
    exit 1
fi

if [ -z "$DESTINATION_DIR" ]; then
    echo "No destination directory specified" >&2
    exit 1
fi

if [ ! -d "$DESTINATION_DIR" ]; then
    echo "Destination directory does not exist" >&2
    exit 1
fi

debug_message "VAR Prefix: $ARCHIVE_PREFIX"
debug_message "VAR Force: $FORCE"
#debug_message "VAR Pass: $PASSWORD"
debug_message "VAR Sub Directories: $SUBFOLDERS"
debug_message "VAR Type: $ARCHIVE_TYPE"
debug_message "VAR Dry Run: $DRY_RUN"
debug_message "VAR Source: $SOURCE_DIR"
debug_message "VAR Destination: $DESTINATION_DIR"
debug_message "VAR Temp Directory: $TMP_FOLDER"

if [ "${SUBFOLDERS}" = true ]; then
    debug_message "checking subfolders on ${SOURCE_DIR}"

    PREFIX=$(basename "${SOURCE_DIR}")

    # save and change IFS
    OLDIFS=$IFS
    IFS=$'\n'

    # read all file name into an array
    fileArray=($(find "${SOURCE_DIR}" -maxdepth 1 -type d | sort))

    # restore it
    IFS=$OLDIFS

    # get length of an array
    tLen=${#fileArray[@]}

    # use for loop read all filenames
    for (( i=0; i<tLen; i++ ));
    do
        dir="${fileArray[$i]}"

        if [ -d "$dir" ]; then
            if [ "$dir" != "${SOURCE_DIR}" ]; then
                TMP_SOURCE_DIR="${dir}"
                archive_folder "${TMP_SOURCE_DIR}" "${DESTINATION_DIR}" "${ARCHIVE_TYPE}" "${PREFIX}-${ARCHIVE_PREFIX}" "${FORCE}" "${PASSWORD}" "${DRY_RUN}" "${TMP_FOLDER}"
            fi
        fi
    done
else
    archive_folder "${SOURCE_DIR}" "${DESTINATION_DIR}" "${ARCHIVE_TYPE}" "${ARCHIVE_PREFIX}" "${FORCE}" "${PASSWORD}" "${DRY_RUN}" "${TMP_FOLDER}"
fi

GLOBAL_END_TIME=$(date +%s)
GLOBAL_TOTAL_TIME=$((GLOBAL_END_TIME - GLOBAL_START_TIME))
GLOBAL_NICE_TIME=$(calc_nice_duration "$GLOBAL_TOTAL_TIME")

output_message "total execution time ${GLOBAL_NICE_TIME}"
