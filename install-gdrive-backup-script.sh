#!/bin/bash

install_gdrive_binary()
{
if [ -f "/sbin/gdrive" ]; then
echo "Looks like /sbin/gdrive already exists. Aborting installation!"
exit 1
else
    wget -O /sbin/gdrive https://github.com/gdrive-org/gdrive/releases/download/2.1.0/gdrive-linux-x64
	chmod +x /sbin/gdrive
fi
}

dry_run_gdrive()
{
/sbin/gdrive list
}

configure_sync_folder()
{
folder_id=`/sbin/gdrive mkdir `hostname`-backups | awk "{print $2}"`
echo "Created Gdrive folder `hostname`-backups with ID $folder_id. The same would be used in backup script - /gdrive-backups/backup.sh"
}

install_backup_script()
{
mkdir /gdrive-backups/
wget -O /gdrive-backups/backup.sh http://raw.githubusercontent.com/ashithwilson/server-side/master/gdrive-backup.sh
sed -i "s|REPLACE_WITH_GDRIVE_FOLDER_ID|$folder_id|g" /gdrive-backups/backup.sh
chmod +x /gdrive-backups/backup.sh
}

print_summary()
{
touch /gdrive-backups/mysql_backup_list.txt
touch /gdrive-backups/backup-list.txt
echo "
============
Backup script is installed at /gdrive-backups/backup.sh
Check gdrive details using command "gdrive help"
Website files - backup list : /gdrive-backups/backup-list.txt
Db - backup list: /gdrive-backups/backup-list.txt
============

** Do not forget to set up daily/weekly cron for backups **

"
}


read -p "Are you sure to install gdrive backups?" opt
if [ $opt -eq "Y" ] || [ $opt -eq "y" ]; then
{
install_gdrive_binary
dry_run_gdrive
configure_sync_folder
install_backup_script
print_summary
}

