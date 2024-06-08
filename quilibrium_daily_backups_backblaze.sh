apt install duplicity
apt-get install python3-b2sdk

HOME=$(eval echo ~$USER)
peer_id=$(~/ceremonyclient/node/node-1.4.19-linux-amd64 -peer-id| grep 'Peer' | cut -d':' -f 2);

# Backblaze B2 configuration variables
read -p "B2 KeyID: " B2_ACCOUNT
read -p "B2 Key: " B2_KEY
read -p "B2 Bucket Name: " B2_BUCKET
B2_DIR=${peer_id//[[:blank:]]/}

cat <<"EOF" >$HOME/backup_script.sh
#!/bin/bash

# Local directory to backup
STORE_DIR="$HOME/ceremonyclient/node/.config/store"

duplicity ${STORE_DIR} b2://${B2_ACCOUNT}:${B2_KEY}@${B2_BUCKET}/${B2_DIR}

EOF

(crontab -l 2>/dev/null; echo "*/* 6 * * * $HOME/backup_script.sh") | crontab -
