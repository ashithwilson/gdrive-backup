#!/bin/bash

# Using gdrive binary to upload to Google drive from https://github.com/gdrive-org/gdrive

local_backup_dir=/backup/gdrive-backups
gdrive_backup_dir=REPLACE_WITH_GDRIVE_FOLDER_ID
backup_dir_list=/backup/gdrive-backups/backup-list.txt
mysql_backup_list=/backup/gdrive-backups/mysql_backup_list.txt
backup_retention=14


displaytime() {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
  (( $M > 0 )) && printf '%d minutes ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}

init_backups()
{
start_time=`date +%s`
mkdir $local_backup_dir/misc -p
rm -rf $local_backup_dir/tmp
tmp_backup_dir=$local_backup_dir/tmp/`date --iso`
mkdir -p $tmp_backup_dir

rm -rf $tmp_backup_dir/mysql
mkdir -p $tmp_backup_dir/mysql

log_file=$local_backup_dir/misc/backup.log


echo "
      =================================
      `date`: backup process started
      =================================
         " >> $log_file
date >> $log_file

}

generate_individual_tmp_local_backup()
{
cd $tmp_backup_dir
if [ -e $1 ]
        then
                filename=`echo $1 | sed  "s|/|_|g"`
                echo "`date`: Generating local backup for $1" >> $log_file
                tar -C $1 -czf $filename.tar.gz ./
                echo "`date`: Saved to $tmp_backup_dir/$filename" >> $log_file
fi

}

generate_tmp_local_backup()
{
for dir in `cat $backup_dir_list`
do
        generate_individual_tmp_local_backup $dir
done
}

generate_tmp_local_mysql_backup()
{
cd $tmp_backup_dir/mysql
for db in `cat $mysql_backup_list`
do
        mysqldump $db | gzip -c > $db.sql.gz
        echo "`date`: Dumping $db to $tmp_backup_dir/mysql/$db.sql.gz" >> $log_file
done
}

upload_to_gdrive()
{
echo "
`date`: Starting upload to GDrive..." >> $log_file
gdrive sync upload $local_backup_dir/tmp/ $gdrive_backup_dir >> $log_file
}

check_retention()
{
local gdrive_backup_list=/backup/gdrive-backups/misc/backups_in_gdrive.txt
gdrive sync content --order createdTime $gdrive_backup_dir | grep -wE "[0-9]{4}-[0-9]{2}-[0-9]{2}" | grep -v "\/" > $gdrive_backup_list
echo "`date`: Retention value is set as $backup_retention" >> $log_file
backups_in_gdrive=`cat $gdrive_backup_list | wc -l`
if [ "$backups_in_gdrive" -gt "$backup_retention" ]
then
        let backups_to_delete=$backups_in_gdrive-$backup_retention
        for backup_id in `cat $gdrive_backup_list | head -n $backups_to_delete | awk '{print $1}'`
        do
                gdrive delete -r $backup_id >> $log_file
        done

        echo "
        `date`: Deleting the below for retention
        ---

        " >> $log_file
        cat $gdrive_backup_list | head -n $backups_to_delete >> $log_file
else
        echo "`date`: Retention value not reached. Deleting nothing." >> $log_file
fi
}

cleanup_tmp_dir()
{
rm -rf $local_backup_dir/tmp/
}

conclude_logs()
{
end_time=`date +%s`
let total_time=$end_time-start_time
echo "
      =======================================
      `date`: Backup process completed in `displaytime $total_time`
      =======================================" >>  $log_file
}

init_backups
generate_tmp_local_backup
generate_tmp_local_mysql_backup
upload_to_gdrive
check_retention
cleanup_tmp_dir
conclude_logs
