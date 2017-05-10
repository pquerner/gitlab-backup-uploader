#!/bin/bash
#
# Backup Script: send GitLab backup files to Google Drive
# 
pushd `dirname $0` > /dev/null
UPLOAD_HOME=`pwd -P`
popd > /dev/null

cd $UPLOAD_HOME
source ./conf/upload.cfg
source ./conf/version.cfg

clear

echo 
echo 
echo "Starting GitLab Backup Uploader version $VERSION"
echo "at `date`"
echo  
echo "Backup directory: $GITLAB_BACKUPS"

# Verify what's the most recent backup file
UPLOAD_ARCHIV=$(ls -dt $GITLAB_BACKUPS/* | head -1)
UPLOAD_ARCHIV_NAME=$(basename $UPLOAD_ARCHIV)

echo "File to upload: $UPLOAD_ARCHIV"
echo

# The GitLab backup files are only grouped with .tar
# So, we need to copy the file and compress it, 
# before send it to Google Drive.
echo "Copying file..."
cp $UPLOAD_ARCHIV .

# Test if you want to compress the file
if test "$UPLOAD_COMPRESS_FILE" = true; then
    echo "Compressing file $UPLOAD_ARCHIV_NAME..."
    bzip2 --best $UPLOAD_ARCHIV_NAME

    # Update variables, to keep the correct names and paths.
    UPLOAD_ARCHIV=$UPLOAD_HOME/$UPLOAD_ARCHIV_NAME.bz2
    UPLOAD_ARCHIV_NAME=$UPLOAD_ARCHIV_NAME.bz2
else
    echo "  => Warning: the backup will not be compressed by uploader."
fi

# Upload the file to Google Drive
echo "Uploading file $UPLOAD_ARCHIV_NAME..."

GDRIVE_RETURNINFO=$(drive upload $UPLOAD_ARCHIV_NAME --parent $GDRIVE_DIRECTORY_ID)

GDRIVE_ARCHIV_NAME=$(echo $GDRIVE_RETURNINFO |cut -d" " -f2)
GDRIVE_UPLOADED_FILE_ID=$(echo $GDRIVE_RETURNINFO |cut -d" " -f4)

echo "  => ID  : $GDRIVE_UPLOADED_FILE_ID"
echo "  => File: $GDRIVE_ARCHIV_NAME"

# Remove the previous file from Google Drive
if [ -s ./conf/gdrive-oldfileinfo ]
then
  GDRIVE_OLD_FILE_ID=$(cat ./conf/gdrive-oldfileinfo)

  echo "Removing previous file..."
  echo "  => ID: $GDRIVE_OLD_FILE_ID"

  drive delete $GDRIVE_OLD_FILE_ID

else
  echo
  echo "File with previous ID is empty."
  echo "If the next time it remains empty,"
  echo "check for any problem in backup."
  echo
fi

# Save the uploaded file ID
$(echo $GDRIVE_UPLOADED_FILE_ID > ./conf/gdrive-oldfileinfo)

# Remove the compressed file.
# We don't need to remove the GitLab backup file, 
# because GitLab itself controls what file will be kept.
echo "Removing local file $UPLOAD_ARCHIV_NAME..."
rm $UPLOAD_ARCHIV_NAME

echo
echo "Done. End of upload script."
echo
