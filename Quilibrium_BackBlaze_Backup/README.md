## Quilibrium Daily Backup Script
This script will use BackBlaze Cloud S3 to backup your store folder daily @ 6AM. Backup_script.sh and restore_backup.sh will be generated. Backup_script.sh will be used in a cronjob to do daily backups. Restore_backup.sh will allow you to run the script and retreive your backup. It will be placed in your user root folder.

Use this guide to create an application key & bucket in BackBlaze: [GUIDE](https://scribehow.com/shared/Create_Backblaze_Application_Key_and_Bucket_for_Quilibrium_Backup_Script__cXYURObtTnqNT_zOZWEAZA)

NOTE: If your key application key generates a "/" inside of it try creating a new one as it will cause problems with the script.

### To install the script + cronjob run:
```
wget -P ~ https://raw.githubusercontent.com/ohern24/quilibrium_scripts/main/quilibrium_daily_backups_backblaze.sh && chmod +x ~/quilibrium_daily_backups_backblaze.sh && ~/quilibrium_daily_backups_backblaze.sh
```

### To retrieve backups:
```
cd && ./restore_backup.sh
```
