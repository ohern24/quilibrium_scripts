#!/bin/bash

# Define the home directory
USER_HOME=$(eval echo ~$USER)
CONFIG_FILE="$USER_HOME/backup_restore_config.conf"

# Check if configuration file already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Configuration file found. Using existing configuration."
    source "$CONFIG_FILE"
else
    echo "Configuration file not found. Creating a new one."

    # Install required packages
    sudo apt install -y duplicity
    sudo apt-get install -y python3-b2sdk gnupg

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

    # Prompt the user for B2 variables
    read -p "Enter B2 App keyID: " B2_ACCOUNT
    read -s -p "Enter B2 App Key (Hidden for Security): " B2_KEY
    echo
    read -p "Enter B2 Bucket: " B2_BUCKET

    echo "Note: Please keep a secure backup of the following passphrases. Losing them will result in the inability to access your encrypted backup data."

    # Prompt the user for GPG passphrase and reconfirm
    while true; do
        read -s -p "Enter GPG Passphrase (Hidden for Security): " GPG_PASSPHRASE
        echo
        read -s -p "Re-enter GPG Passphrase for confirmation: " GPG_PASSPHRASE_CONFIRM
        echo

        if [ "$GPG_PASSPHRASE" == "$GPG_PASSPHRASE_CONFIRM" ]; then
            break
        else
            echo "Passphrases do not match. Please try again."
        fi
    done

    # Prompt the user for GPG signing passphrase and reconfirm if provided
    read -s -p "Enter GPG Signing Passphrase (press Enter if same as GPG Passphrase): " SIGN_PASSPHRASE
    echo

    if [ -z "$SIGN_PASSPHRASE" ]; then
        SIGN_PASSPHRASE=$GPG_PASSPHRASE
    else
        while true; do
            read -s -p "Re-enter GPG Signing Passphrase for confirmation (press Enter if same as GPG Passphrase): " SIGN_PASSPHRASE_CONFIRM
            echo

            if [ -z "$SIGN_PASSPHRASE_CONFIRM" ]; then
                # User chose to use the same passphrase for signing
                echo "Using the same passphrase as GPG passphrase for signing."
                break
            elif [ "$SIGN_PASSPHRASE" == "$SIGN_PASSPHRASE_CONFIRM" ]; then
                break
            else
                echo "Passphrases do not match. Please try again."
            fi
        done
    fi

    # Retrieve the peer_id
    peer_id=$(cd $USER_HOME/ceremonyclient/node && ./node-1.4.19.1-linux-amd64 -peer-id | awk -F ': ' '/Peer/ {print $2}')

    if [ -z "$peer_id" ]; then
        echo "Error retrieving peer_id" >&2
        exit 1
    fi

    # Create a configuration file
    cat <<EOF >"$CONFIG_FILE"
USER_HOME=$USER_HOME
B2_ACCOUNT=$B2_ACCOUNT
B2_KEY=$B2_KEY
B2_BUCKET=$B2_BUCKET
SGN_KEY=$SGN_KEY
ENC_KEY=$ENC_KEY
GPG_PASSPHRASE=$GPG_PASSPHRASE
SIGN_PASSPHRASE=$SIGN_PASSPHRASE
PEER_ID=$peer_id
EOF
fi

# Create the backup script
cat <<EOF >"$USER_HOME/backup_script.sh"
#!/bin/bash

source $CONFIG_FILE

# Get the current date in YYYYMMDD format
current_date=\$(date +%Y%m%d)

# Define the tar file name using current date and peer_id
TAR_FILE="\${current_date}_\${PEER_ID}_store_backup.tar.gz"

# Define the directory to be tarred
DIR_TO_TAR="\$USER_HOME/ceremonyclient/node/.config"

# Create a tar.gz file of the specified directory
echo "Creating tar file of \$DIR_TO_TAR..."
tar -czf "\$TAR_FILE" -C "\$(dirname "\$DIR_TO_TAR")" "\$(basename "\$DIR_TO_TAR")"

if [ \$? -eq 0 ]; then
    echo "Tar file created successfully: \$TAR_FILE"
else
    echo "Error creating tar file" >&2
    exit 1
fi

# Set B2_DIR to peer_id
B2_DIR="\$PEER_ID"

# Construct the B2 URL with the user inputs
B2_URL="b2://\${B2_ACCOUNT}:\${B2_KEY}@\${B2_BUCKET}/\${B2_DIR}"

# Print the constructed B2 URL
echo "Constructed B2 URL: \$B2_URL"

# Export passphrase environment variables for GPG
export PASSPHRASE="\$GPG_PASSPHRASE"
export SIGN_PASSPHRASE="\$SIGN_PASSPHRASE"

# Remove the previous day's backup from backups using duplicity
echo "Removing previous day's backup: \$OLD_TAR_FILE"
duplicity remove-older-than 1m --force --sign-key "\$SGN_KEY" --encrypt-key "\$ENC_KEY" "\$B2_URL"

# Perform the backup using duplicity
echo "Backing up \$TAR_FILE to B2 storage..."
duplicity full --sign-key "\$SGN_KEY" --encrypt-key "\$ENC_KEY" "\$TAR_FILE" "\$B2_URL"

if [ \$? -eq 0 ]; then
    echo "Backup completed successfully."
    
    # Remove the tar file after backup is completed
    rm -f "\$TAR_FILE"
else
    echo "Error during backup" >&2
    exit 1
fi

echo "Script execution completed."

# Unset passphrase environment variables for security
unset PASSPHRASE
unset SIGN_PASSPHRASE
EOF

# Make the backup script executable
chmod +x $USER_HOME/backup_script.sh

# Create the restore script
cat <<EOF >"$USER_HOME/restore_backup.sh"
#!/bin/bash

source $CONFIG_FILE

# Define the restore directory
RESTORE_DIR="\$USER_HOME/restore"

# Create the restore directory
mkdir -p "\$RESTORE_DIR"

# Set B2_DIR to peer_id
B2_DIR="\$PEER_ID"

# Construct the B2 URL with the user inputs
B2_URL="b2://\${B2_ACCOUNT}:\${B2_KEY}@\${B2_BUCKET}/\${B2_DIR}"

# Restore the files using duplicity
echo "Restoring files from B2 storage..."
duplicity --file-to-restore / "\$B2_URL" "\$RESTORE_DIR"

if [ \$? -eq 0 ]; then
    echo "Restore completed successfully."
    
    # Decompress the restored files
    echo "Decompressing the restored files..."
    tar -xvzf "\$RESTORE_DIR"
    rm "\$RESTORE_DIR"

    if [ \$? -eq 0 ]; then
        echo "Decompression completed successfully."
    else
        echo "Error during decompression" >&2
        exit 1
    fi
else
    echo "Error during restore" >&2
    exit 1
fi
EOF

# Make the restore script executable
chmod +x $USER_HOME/restore_backup.sh

# Run the backup script once
$USER_HOME/backup_script.sh

# Check if cron job exists
existing_cron=$(crontab -l | grep "$USER_HOME/backup_script.sh")

# Schedule the backup script if it's not already scheduled
if [ -z "$existing_cron" ]; then
    (crontab -l 2>/dev/null; echo "0 6 * * * $USER_HOME/backup_script.sh") | crontab -
    echo "Backup script scheduled to run daily at 6:00 AM."
else
    echo "Backup script already scheduled."
fi

# Inform the user about the restore script
echo "The restore script has been created at $USER_HOME/restore_backup.sh."
echo "To restore the backup, run: cd && ./restore_backup.sh"

# Clean up
rm "$USER_HOME/quilibrium_daily_backups_backblaze.sh"
