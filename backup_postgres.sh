#!/bin/bash

# --- Configuration ---
DB_NAME="dvdrental"
S3_BUCKET="db-backups-2026"
S3_PATH="Postgres"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# SET YOUR PASSWORD HERE
PASSPHRASE="Password@123"

# Filenames
TMP_DUMP_FILE="${DB_NAME}_${TIMESTAMP}.tar"
ZIP_FILENAME="${DB_NAME}_${TIMESTAMP}.zip"

# --- Run Backup ---
echo "Starting backup for database: $DB_NAME"

# 1. Dump database to a temporary file
# We pipe the output to the file as 'root' so we have permission to write in /scripts/
sudo -u postgres pg_dump -F t "$DB_NAME" > "$TMP_DUMP_FILE"

if [ $? -eq 0 ]; then
    echo "Database dumped. Compressing and encrypting with password..."

    # 2. Zip with Password
    # -P uses the password variable
    # -m moves/deletes the original file after zipping (cleanup)
    zip -P "$PASSPHRASE" "$ZIP_FILENAME" "$TMP_DUMP_FILE"

    if [ -f "$ZIP_FILENAME" ]; then
        echo "Zip created successfully: $ZIP_FILENAME"

        # 3. Upload to S3
        echo "Uploading to S3..."
        aws s3 cp "$ZIP_FILENAME" "s3://${S3_BUCKET}/${S3_PATH}/${ZIP_FILENAME}"

        if [ $? -eq 0 ]; then
            echo "Upload successful."
            # 4. Clean up zip file
            rm "$ZIP_FILENAME"
        else
            echo "ERROR: Upload failed. File kept locally: $ZIP_FILENAME"
        fi
    else
        echo "ERROR: Zip creation failed."
    fi
else
    echo "ERROR: Database dump failed."
fi
