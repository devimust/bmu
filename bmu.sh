#!/usr/bin/env bash
# Back me up. Copyright (c) 2017, https://github.com/devimust

# trace what gets executed (debugging purposes)
#set -x
# exit script when command fails
#set -e
# exit when trying to use undeclared vars
#set -u
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
TRIAL_RUN=false

##################################
# Local functions
##################################

show_help(){
    cat <<EOF
Usage: bmu [OPTION...] [SOURCE DIRECTORY] [DESTINATION DIRECTORY]...
'bmu' archives files and/or folders based on changes found in the target
directory.

Examples:
  bmu -p somepassword1 /src_folder /dst_folder      # Create protected archive only if source
                                                    # files/folders were modified.
  bmu -a my-prefix -vsf /src_folder /dst_folder     # Force new archives with prefix, verbosity
                                                    # and only include sub-folders.

 Main operation mode:

  -a            attach prefix to the archived files
  -c            check what will be processed in a test run if omitted
  -f            force process and bypass checking for changes
  -h            show this help menu
  -p            specify password to protect archive(s)
  -s            only archive subfolders inside given directory
  -d            show more verbose output (debugging)
  -t            archive type to use (zip or tar)

  long options not currently supported
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
        echo "$1"
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
    cmdOutput=$(${findBin} "${DIR}" -type f -exec "${shaBin}" "{}" + | sort | "${shaBin}")

    echo "$cmdOutput"
}

archive_folder(){
    local SOURCE_DIR
    local DESTINATION_DIR
    local ARCHIVE_TYPE
    local ARCHIVE_PREFIX
    local FORCE
    local PASSWORD
    local TRIAL_RUN

    local CAN_ARCHIVE
    local SOURCE_CHECKSUM
    local SOURCE_HASH
    local START_TIME
    local OUTPUT_MESSAGE
    local ARCHIVE_FILE_TYPE
    local DESTINATION_ARCHIVE_FILE
    local DESTINATION_CHECKSUM_FILE

    SOURCE_DIR=$1
    DESTINATION_DIR=$2
    ARCHIVE_TYPE=$3
    ARCHIVE_PREFIX=$4
    FORCE=$5
    PASSWORD=$6
    TRIAL_RUN=$7

    CAN_ARCHIVE=false
    SOURCE_CHECKSUM=""
    SOURCE_HASH=""
    START_TIME=$(date +%s)
    OUTPUT_MESSAGE=""
    ARCHIVE_FILE_TYPE=$(archive_file_type "${ARCHIVE_TYPE}")
    DESTINATION_ARCHIVE_FILE="${DESTINATION_DIR}/${ARCHIVE_PREFIX}$(basename "$SOURCE_DIR").${ARCHIVE_TYPE}"
    DESTINATION_CHECKSUM_FILE="${DESTINATION_ARCHIVE_FILE}.crc"

    debug_message "trying to archive ${SOURCE_DIR} to ${DESTINATION_DIR}"

    if [ ! -e "${DESTINATION_CHECKSUM_FILE}" ]; then
        debug_message "no checksum file found (${DESTINATION_CHECKSUM_FILE})"
        OUTPUT_MESSAGE="creating new archive on ${SOURCE_DIR}"
        CAN_ARCHIVE=true
    else
        if [ "${FORCE}" = false ]; then
            DESTINATION_HASH=$(cat "${DESTINATION_CHECKSUM_FILE}")

            debug_message "calculating source folder checksum to compare with destination checksum"
            SOURCE_CHECKSUM=$(calc_dir_checksum "${SOURCE_DIR}")
            SOURCE_HASH=$(calc_hash "${SOURCE_CHECKSUM}")

            if [ "${DESTINATION_HASH}" != "${SOURCE_HASH}" ]; then
                debug_message "changes detected"
                OUTPUT_MESSAGE="changes detected on ${SOURCE_DIR}"
                CAN_ARCHIVE=true
            else
                debug_message "no changes detected"
                OUTPUT_MESSAGE="no changes detected on ${SOURCE_DIR}"
            fi
        else
            debug_message "forcing archive"
            OUTPUT_MESSAGE="forcing archive on ${SOURCE_DIR}"
            CAN_ARCHIVE=true
        fi
    fi

    # # do we need to check for changes
    # if [ "$FORCE" = false ] ; then
    #     debug_message "check for changes"
    #     FOLDER_SIZE=$(du -sb ${DESTINATION_DIR})
    #     echo $FOLDER_SIZE
    #     #check_source_dir $SOURCE_DIR
    # else
    #     debug_message "forcing archive"

    if [ -z "${SOURCE_CHECKSUM}" ]; then
        debug_message "calculating source folder checksum as this is a new archive or was forced"
        SOURCE_CHECKSUM=$(calc_dir_checksum "${SOURCE_DIR}")
        SOURCE_HASH=$(calc_hash "${SOURCE_CHECKSUM}")
    fi

    if [ "${TRIAL_RUN}" = true ]; then
        END_TIME=$(date +%s)
        TOTAL_TIME=$((END_TIME - START_TIME))
        NICE_TIME=$(calc_nice_duration "$TOTAL_TIME")

        debug_message "trial run, nothing written (finished in ${NICE_TIME}) (${DESTINATION_ARCHIVE_FILE})"
        OUTPUT_MESSAGE="${OUTPUT_MESSAGE}... trial run, nothing written (finished in ${NICE_TIME}) (${DESTINATION_ARCHIVE_FILE})"
    else
        if [ "${CAN_ARCHIVE}" = true ]; then
            case "$ARCHIVE_FILE_TYPE" in
                zip)
                    debug_message "zip archive started (${DESTINATION_ARCHIVE_FILE})"
                    zipBin=$(command -v zip)

                    cmd="${zipBin} --recurse-paths --paths -9 -b /mnt/cache/tmp/ "
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
                    OUTPUT_MESSAGE="${OUTPUT_MESSAGE}... (finished in ${NICE_TIME}) (${DESTINATION_ARCHIVE_FILE})"
                    ;;
                *) ;;
            esac
        else
            END_TIME=$(date +%s)
            TOTAL_TIME=$((END_TIME - START_TIME))
            NICE_TIME=$(calc_nice_duration "$TOTAL_TIME")

            debug_message "skipping ${SOURCE_DIR} (finished in ${NICE_TIME})"
            OUTPUT_MESSAGE="${OUTPUT_MESSAGE}... (finished in ${NICE_TIME})"
        fi
    fi

    output_message "${OUTPUT_MESSAGE}"
}

##################################
# Main execution
##################################

# @link http://stackoverflow.com/questions/402377/using-getopts-in-bash-shell-script-to-get-long-and-short-command-line-options/7680682
while getopts a:cdfhp:st:-: arg; do
  case $arg in
    a ) ARCHIVE_PREFIX="$OPTARG" ;;
    c ) TRIAL_RUN=true ;;
    d ) VERBOSE=true ;;
    f ) FORCE=true ;;
    h ) show_help && exit 0 ;;
    p ) PASSWORD="$OPTARG" ;;
    s ) SUBFOLDERS=true ;;
    t ) ARCHIVE_TYPE="$OPTARG" ;;
    \? ) exit 2 ;;  # getopts already reported the illegal option
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

if [ "$#" -eq 0 ]; then
    show_help
    exit 0
fi

SOURCE_DIR=$1
DESTINATION_DIR=$2

if [ -z "$SOURCE_DIR" ]; then
    echo "No source directory specified" >&2
    exit 2
fi

if [ -z "$DESTINATION_DIR" ]; then
    echo "No destination directory specified" >&2
    exit 2
fi

if [ ! -d "$DESTINATION_DIR" ]; then
    echo "Destination directory does not exist" >&2
    exit 2
fi

debug_message "VAR Prefix: $ARCHIVE_PREFIX"
debug_message "VAR Force: $FORCE"
#debug_message "VAR Pass: $PASSWORD"
debug_message "VAR Subfolders: $SUBFOLDERS"
debug_message "VAR Type: $ARCHIVE_TYPE"
debug_message "VAR Trial Run: $TRIAL_RUN"
debug_message "VAR Source: $SOURCE_DIR"
debug_message "VAR Destination: $DESTINATION_DIR"

if [ "${SUBFOLDERS}" = true ]; then
    debug_message "checking subfolders on ${SOURCE_DIR}"

    PREFIX=$(basename "${SOURCE_DIR}")

    # save and change IFS
    OLDIFS=$IFS
    IFS=$'\n'

    # read all file name into an array
    fileArray=($(find "${SOURCE_DIR}" -maxdepth 1 -type d))

    # restore it
    IFS=$OLDIFS

    # get length of an array
    tLen=${#fileArray[@]}

    # use for loop read all filenames
    for (( i=0; i<${tLen}; i++ ));
    do
        dir="${fileArray[$i]}"

        if [[ "$dir" == "${SOURCE_DIR}" ]]; then
            continue
        fi

        if [[ ! -d "$dir" ]]; then
            continue
        fi

        TMP_SOURCE_DIR="${dir}"
        archive_folder "${TMP_SOURCE_DIR}" "${DESTINATION_DIR}" "${ARCHIVE_TYPE}" "${PREFIX}-${ARCHIVE_PREFIX}" "${FORCE}" "${PASSWORD}" "${TRIAL_RUN}"
    done
else
    archive_folder "${SOURCE_DIR}" "${DESTINATION_DIR}" "${ARCHIVE_TYPE}" "${ARCHIVE_PREFIX}" "${FORCE}" "${PASSWORD}" "${TRIAL_RUN}"
fi
