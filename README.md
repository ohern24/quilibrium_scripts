# Orlando's Quilibrium Scripts
Here you'll find scripts I made for myself that you can take for yourself as well. Ill help where I can but google is your best friend!

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

## Quilibrium Balance and Average Earnings:
With the help of Cunnaredu from the discord by providing a Python script to get balance and do the average earned for min, hour, and daily this script will allow you to easily retreive that data + have logs to see the difference as you earn. Please make sure your node has Python3 installed to run the script properly.

While using it will say no data yet if not enough time has passed. It will get the average minute every 15 minutes and average hourly + daily every hour.

### To install the script:
```
wget --no-cache -O - https://raw.githubusercontent.com/ohern24/quilibrium_scripts/main/Quilibrium_Balance/quilibrium_balance_script.sh | bash
```

### To get balance, average per minute, average per hour, and average per day:
```
cd ~/node_balance && ./get_balance.sh
```

## Looking for a dedicated/bare metal server to host on?
I have found a provider that I have been working with to make sure running a Quilibrium node is okay to run on their servers. Others and I have had a good experience with them so far:
[Vultric Hosting](https://billing.vultrichosting.com/aff.php?aff=257)

Best option is a 7950x3D for Quilibrium but they go out of stock often. Hit me up if you are interested in higher core count servers like dual Epyc 7742 (128c/256t total) for ~$650 a month.
