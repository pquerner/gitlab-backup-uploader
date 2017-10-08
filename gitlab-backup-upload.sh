#!/bin/bash
#
# Backup Script: send GitLab backup files to Google Drive
# 
pushd `dirname $0` > /dev/null
UPLOAD_HOME=`pwd -P`
popd > /dev/null

cd $UPLOAD_HOME

usage() {
    echo "Usage: $0 [-c FILE|-d|-k]" 1>&2;
    echo ""
    echo "OPTIONAL: -c = Configuration file to use (defaults to $UPLOAD_HOME/conf/upload.cfg)"
    echo "OPTIONAL: -d = Dry-run mode. Does not actually do anything but just shows you what would be done normally."
    echo "OPTIONAL: -k = Doesnt delete any uploaded files GoogleDrive."
    exit 1;
}
CONFIGFILE=$UPLOAD_HOME/conf/upload.cfg
DRYRUN=false
DELETEOLDFILE=true

while getopts "c:dk" arg; do
    case $arg in
        c)
            CONFIGFILE=${OPTARG}
            ;;
        k)
            eval nextopt=\${$OPTIND}
            if [[ -n $nextopt && $nextopt != -* ]] ; then
                OPTIND=$((OPTIND + 1))
                level=$nextopt
            else
                level=1
            fi

            DELETEOLDFILE=false
            ;;
        d)
            eval nextopt=\${$OPTIND}
            if [[ -n $nextopt && $nextopt != -* ]] ; then
                OPTIND=$((OPTIND + 1))
                level=$nextopt
            else
                level=1
            fi


            DRYRUN=true
            ;;
        *)
            usage
            break ;;
    esac
done

if [ -z "${CONFIGFILE}" ]; then
    usage
fi

#Test is cfg file exists and is readable
if [ ! -f $CONFIGFILE  ] || [ ! -r $CONFIGFILE ]; then
    echo "$CONFIGFILE file not found or not readable! Please read instructions (README.md)."
    exit 1
fi

source $CONFIGFILE
source ./conf/version.cfg

if [ -z ${GITLAB_BACKUPS} ] || [ ! -d "$GITLAB_BACKUPS" ]; then
    echo "  => ERROR: GITLAB_BACKUPS folder variable is unset or folder is unreadable."
    echo "            Please configure GITLAB_BACKUPS in config file."
    exit 1
fi

if [ -z ${GDRIVE_DIRECTORY_ID} ]; then
    echo "  => ERROR: GDRIVE_DIRECTORY_ID is unset."
    echo "            Please configure GDRIVE_DIRECTORY_ID in config file.";
    exit 1
fi

clear

echo 
echo 
echo "Starting GitLab Backup Uploader version $VERSION"
echo "at `date`"
echo  
echo "Backup directory: $GITLAB_BACKUPS"

# Verify what's the most recent backup file
if [ "$DRYRUN" = true ]; then
        UPLOAD_ARCHIV="IDONTEXISTS.tar.gz"
        UPLOAD_ARCHIV_NAME=$(basename $UPLOAD_ARCHIV)
    else
        UPLOAD_ARCHIV=$(ls -dt $GITLAB_BACKUPS/* | head -1)
        UPLOAD_ARCHIV_NAME=$(basename $UPLOAD_ARCHIV)
fi

echo "File to upload: $UPLOAD_ARCHIV"
echo

# The GitLab backup files are only grouped with .tar
# So, we need to copy the file and compress it, 
# before send it to Google Drive.
# Optionally, if set by user, we will encrypt the file with GPG first.
echo "Copying file..."
if [ "$DRYRUN" = true ]; then
        echo "cp $UPLOAD_ARCHIV ."
    else
        cp $UPLOAD_ARCHIV .
fi

# Test if you want to compress the file
if test "$UPLOAD_COMPRESS_FILE" = true; then
    echo "Compressing file $UPLOAD_ARCHIV_NAME..."
    if [ "$DRYRUN" = true ]; then
        echo "bzip2 --best $UPLOAD_ARCHIV_NAME"
    else
        bzip2 --best $UPLOAD_ARCHIV_NAME
    fi

    # Update variables, to keep the correct names and paths.
    UPLOAD_ARCHIV=$UPLOAD_HOME/$UPLOAD_ARCHIV_NAME.bz2
    UPLOAD_ARCHIV_NAME=$UPLOAD_ARCHIV_NAME.bz2
else
    echo "  => Warning: the backup will not be compressed by uploader."
fi

# Test if user wants to encrypt the file first
if test "$ENCRYPT_FILE" = true; then
    # Test is password file exists and is readable
    if [ ! -f $ENCRYPT_PASSWORD_FILE  ] || [ ! -r $ENCRYPT_PASSWORD_FILE ]; then
        echo "$ENCRYPT_PASSWORD_FILE file not found or not readable! Please read instructions (README.md)."
        exit 1
    fi
    echo "Compressing file $UPLOAD_ARCHIV_NAME..."
    if [ "$DRYRUN" = true ]; then
        echo "gpg --no-tty -vv --exit-on-status-write-error --batch --passphrase-file $ENCRYPT_PASSWORD_FILE --cipher-algo AES256 --symmetric $UPLOAD_HOME/$UPLOAD_ARCHIV_NAME > ./log/error.log 2>&1"
    else
        gpg --no-tty -vv --exit-on-status-write-error --batch --passphrase-file $ENCRYPT_PASSWORD_FILE --cipher-algo AES256 --symmetric $UPLOAD_HOME/$UPLOAD_ARCHIV_NAME > ./log/error.log 2>&1
    fi

    # Update variables, to keep the correct names and paths.
    UPLOAD_ARCHIV=$UPLOAD_HOME/$UPLOAD_ARCHIV_NAME.gpg
    UPLOAD_ARCHIV_NAME=$UPLOAD_ARCHIV_NAME.gpg
else
    echo "  => Warning: the backup will not be encrypted by uploader."
fi

# Upload the file to Google Drive
echo "Uploading file $UPLOAD_ARCHIV_NAME..."
if [ "$DRYRUN" = true ]; then
        GDRIVE_ARCHIV_NAME=$UPLOAD_ARCHIV_NAME
        GDRIVE_UPLOADED_FILE_ID="ID_NOT_SET_DRY_DRUN"
    else
        GDRIVE_RETURNINFO=$(drive upload $UPLOAD_ARCHIV_NAME --parent $GDRIVE_DIRECTORY_ID)
        GDRIVE_ARCHIV_NAME=$(echo $GDRIVE_RETURNINFO |cut -d" " -f2)
        GDRIVE_UPLOADED_FILE_ID=$(echo $GDRIVE_RETURNINFO |cut -d" " -f4)
fi

echo "  => ID  : $GDRIVE_UPLOADED_FILE_ID"
echo "  => File: $GDRIVE_ARCHIV_NAME"

# Remove the previous file from Google Drive
if [ -s ./conf/gdrive-oldfileinfo ] && [ "$DELETEOLDFILE" = true ];
then
  GDRIVE_OLD_FILE_ID=$(cat ./conf/gdrive-oldfileinfo)

  echo "Removing previous file..."
  echo "  => ID: $GDRIVE_OLD_FILE_ID"

  if [ "$DRYRUN" = false ]; then
        drive delete $GDRIVE_OLD_FILE_ID
  fi

else
  if [ "$DRYRUN" = false ]; then
        echo
        echo "File with previous ID is empty."
        echo "If the next time it remains empty,"
        echo "check for any problem in backup."
        echo
  fi
fi

# Save the uploaded file ID
if [ "$DRYRUN" = false ]; then
    $(echo $GDRIVE_UPLOADED_FILE_ID > ./conf/gdrive-oldfileinfo)
fi

# Remove the compressed file.
# We don't need to remove the GitLab backup file, 
# because GitLab itself controls what file will be kept.
echo "Removing local file $UPLOAD_ARCHIV_NAME..."
  if [ "$DRYRUN" = true ]; then
        echo "rm $UPLOAD_ARCHIV_NAME"
    else
        rm $UPLOAD_ARCHIV_NAME
  fi

echo
echo "Done. End of upload script at `date`"
echo
