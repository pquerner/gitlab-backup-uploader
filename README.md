## Gitlab Backup Uploader
#### Script to upload Gitlab backups to Google Drive for Linux systems

--------

### Install:

Make a repository copy to the GitLab `home` directory.

```
cd /home/git
git clone https://github.com/pquerner/gitlab-backup-uploader.git
```

I recommend using this uploader via `git clone` instead of downloading, so you can benefit from automatic update scripts.

Download and install the [Google Drive CLI](https://github.com/prasmussen/gdrive) for your system.
This has been tested with version 2.1.0 Linux x64 (Ubuntu).

```
wget https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA -O drive
chmod a+x drive
sudo mv /home/git/drive /usr/bin/
```

Run Google Drive CLI and configure it with your Google Account Drive that will receive the files. When running, follow the instructions that appear on the terminal.

```
drive
```

After configuring the Google Drive CLI, create a directory in Google Drive, and get his ID. Example: if the URL of the directory on Google Drive is this:

```
https://drive.google.com/drive/u/0/#folders/0B43Qn3ksX-mMRzl1S05mbDNIdGc
```

the directory ID is the part that is left after `/#folders/`. In other words:

```
0B43Qn3ksX-mMRzl1S05mbDNIdGc
```

With ID in hand, register it in the configuration file. How to do that?

Make a copy of the example configuration file:

```
cd /home/git/gitlab-backup-uploader/conf
cp upload.cfg.example upload.cfg
```

Edit `upload.cfg`, and change the following items:

* The parameter `GITLAB_BACKUPS` with the full path of the GitLab backup directory.
* The parameter `GDRIVE_DIRECTORY_ID` with the Google Drive directory ID that will receive the backup files. 
* The parameter `UPLOAD_COMPRESS_FILE` to decide whether the backup will be compressed prior to upload.

Then just put the upload script in crontab (com `crontab -e`):

```
# Upload the latest GitLab backup to Google Drive at 10pm.
0 22 * * * /home/git/gitlab-backup-uploader/gitlab-backup-upload.sh 1> /home/git/gitlab-backup-uploader/log/cron.log 2>&1
```

### Parameters

The shell script "gitlab-backup-upload" accepts the following optional parameters:

```
-c = Configuration file to use. Defaults to /conf/upload.cfg
Reason:
    If you save your /etc/gitlab directory from a cronjob for instance, you can save it with this script also.
    (Example cronjob : tar cfz /var/opt/gitlab/backups/opt/$(date "+opt-gitlab-%s.tgz") -C / opt/gitlab)
-d = Dry-run mode. Does not actually do anything but shows what would be done. Good for testing.
-k = Keep old uploaded file. Normally this script deletes the last uploaded file uploaded to your GDrive account. This parameters prevents that action.
```

_____

### License

```
Copyright 2014 Syonet CRM

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```
