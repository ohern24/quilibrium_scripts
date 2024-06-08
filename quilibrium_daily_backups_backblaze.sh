#!/bin/bash

# Install required packages
sudo apt install -y duplicity
sudo apt-get install -y python3-b2sdk gnupg

# Define the home directory
USER_HOME=$(eval echo ~$USER)

# Generate GPG key
echo "Generating GPG key..."
gpg --batch --gen-key <<EOF
    Key-Type: RSA
    Key-Length: 2048
    Subkey-Type: RSA
    Subkey-Length: 2048
    Name-Real: Backup User
    Name-Email: backup@example.com
    Expire-Date: 0
    %no-protection
    %commit
EOF

# Extract GPG key fingerprints
SGN_KEY=$(gpg --list-keys --with-colons | grep "^fpr" | head -n 1 | cut -d':' -f10)
ENC_KEY=$SGN_KEY

if [ -z "$SGN_KEY" ] || [ -z "$ENC_KEY" ]; then
    echo "Error generating GPG keys" >&2
    exit 1
fi

# Create the backup script
cat <<EOF >$USER_HOME/backup_script.sh
#!/bin/bash

# Retrieve the peer_id
peer_id=$($USER_HOME/ceremonyclient/node/node-1.4.19-linux-amd64 -peer-id | grep 'Peer' | cut -d':' -f 2 | tr -d ' ')

if [ -z "$peer_id" ]; then
    echo "Error retrieving peer_id" >&2
    exit 1
fi

# Get the current date in YYYYMMDD format
current_date=$(date +%Y%m%d)

# Define the tar file name using current date and peer_id
TAR_FILE="${current_date}_${peer_id}_store_backup.tar.gz"

# Define the directory to be tarred
DIR_TO_TAR="/root/ceremonyclient/node/.config/store"

# Create a tar.gz file of the specified directory
echo "Creating tar file of $DIR_TO_TAR..."
tar -czf $TAR_FILE -C $(dirname $DIR_TO_TAR) $(basename $DIR_TO_TAR)

if [ $? -eq 0 ]; then
    echo "Tar file created successfully: $TAR_FILE"
else
    echo "Error creating tar file" >&2
    exit 1
fi

# B2 credentials and bucket information
B2_ACCOUNT="<B2_ACCOUNT_PLACEHOLDER>"
B2_KEY="<B2_KEY_PLACEHOLDER>"
B2_BUCKET="<B2_BUCKET_PLACEHOLDER>"

# Set B2_DIR to peer_id
B2_DIR=$peer_id

# Construct the B2 URL with the user inputs
B2_URL="b2://${B2_ACCOUNT}:${B2_KEY}@${B2_BUCKET}/${B2_DIR}"

# Print the constructed B2 URL
echo "Constructed B2 URL: $B2_URL"

# GPG keys
SGN_KEY="<SGN_KEY_PLACEHOLDER>"
ENC_KEY="<ENC_KEY_PLACEHOLDER>"

# Export passphrase environment variables for GPG
export PASSPHRASE="<GPG_PASSPHRASE>"
export SIGN_PASSPHRASE="<SIGN_PASSPHRASE>"

# Perform the backup using duplicity
echo "Backing up $TAR_FILE to B2 storage..."
duplicity --sign-key $SGN_KEY --encrypt-key $ENC_KEY $TAR_FILE $B2_URL

if [ $? -eq 0 ]; then
    echo "Backup completed successfully."
else
    echo "Error during backup" >&2
    exit 1
fi

# Delete the tar backup file
echo "Deleting tar backup file: $TAR_FILE"
rm $TAR_FILE

# Unset passphrase environment variables for security
unset PASSPHRASE
unset SIGN_PASSPHRASE

echo "Script execution completed."
EOF

# Make the backup script executable
chmod +x $USER_HOME/backup_script.sh

# Check if cron job exists
existing_cron=$(crontab -l | grep "$USER_HOME/backup_script.sh")

# Prompt the user for B2 variables
read -p "Enter B2 Account: " B2_ACCOUNT
read -s -p "Enter B2 Key: " B2_KEY
echo
read -p "Enter B2 Bucket: " B2_BUCKET

# Prompt the user for GPG passphrases
read -s -p "Enter GPG Passphrase: " GPG_PASSPHRASE
echo
read -s -p "Enter GPG Signing Passphrase (press Enter if same as GPG Passphrase): " SIGN_PASSPHRASE
echo

# Use the same passphrase if signing passphrase is not provided
if [ -z "$SIGN_PASSPHRASE" ]; then
    SIGN_PASSPHRASE=$GPG_PASSPHRASE
fi

# Replace placeholders in the backup script with the actual values
sed -i "s|<B2_ACCOUNT_PLACEHOLDER>|$B2_ACCOUNT|g" $USER_HOME/backup_script.sh
sed -i "s|<B2_KEY_PLACEHOLDER>|$B2_KEY|g" $USER_HOME/backup_script.sh
sed -i "s|<B2_BUCKET_PLACEHOLDER>|$B2_BUCKET|g" $USER_HOME/backup_script.sh
sed -i "s|<SGN_KEY_PLACEHOLDER>|$SGN_KEY|g" $USER_HOME/backup_script.sh
sed -i "s|<ENC_KEY_PLACEHOLDER>|$ENC_KEY|g" $USER_HOME/backup_script.sh
sed -i "s|<GPG_PASSPHRASE>|$GPG_PASSPHRASE|g" $USER_HOME/backup_script.sh
sed -i "s|<SIGN_PASSPHRASE>|$SIGN_PASSPHRASE|g" $USER_HOME/backup_script.sh

# Run the backup script once
$USER_HOME/backup_script.sh

# Schedule the backup script if it's not already scheduled
if [ -z "$existing_cron" ]; then
    (crontab -l 2>/dev/null; echo "0 6 * * * $USER_HOME/backup_script.sh") | crontab -
    echo "Backup script scheduled to run daily at 6:00 AM."
else
    echo "Backup script already scheduled."
fi
