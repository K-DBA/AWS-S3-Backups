#!/bin/bash

# ==========================================
# Configuration
# ==========================================
# Path confirmed by user
BACKUP_DIR="/u01/app/oracle/backup"

# AWS Configuration
S3_BUCKET="s3://oracle-devdb-back-up-2026"   # <--- CHANGE THIS
ZIP_PASSWORD="Password@123"     # <--- CHANGE THIS

# Environment Setup
export ORACLE_HOME=/u01/app/oracle/product/19.0.0.0/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
export ORACLE_SID=DEVDB

DATE_STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PREFIX="devdb_backup_${DATE_STAMP}"

echo "=========================================="
echo "Starting Backup: $(date)"
echo "Destination: $BACKUP_DIR"
echo "=========================================="

# Ensure directory exists
mkdir -p "$BACKUP_DIR"

# ==========================================
# Step 1: RMAN Backup
# ==========================================
echo "Running RMAN Backup..."

rman target / <<EOF
RUN {
   ALLOCATE CHANNEL ch1 DEVICE TYPE DISK FORMAT '${BACKUP_DIR}/${BACKUP_PREFIX}_%U.bak';
   BACKUP DATABASE;
   BACKUP CURRENT CONTROLFILE FORMAT '${BACKUP_DIR}/${BACKUP_PREFIX}_ctrl.bak';
   SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
   BACKUP ARCHIVELOG ALL FORMAT '${BACKUP_DIR}/${BACKUP_PREFIX}_arch_%U.bak';
   RELEASE CHANNEL ch1;
}
EXIT;
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: RMAN backup failed. Aborting script."
    exit 1
fi

echo "RMAN Backup Complete."

# ==========================================
# Step 2: Zip with Password
# ==========================================
echo "Compressing and Encrypting..."

ZIP_FILE="${BACKUP_DIR}/${BACKUP_PREFIX}.zip"

# -j: Junk paths (don't store full directory structure in zip)
# -r: Recursive
# -P: Password
zip -r -j -P "${ZIP_PASSWORD}" "${ZIP_FILE}" "${BACKUP_DIR}"/*.bak

if [ $? -ne 0 ]; then
    echo "ERROR: Zip failed. Check disk space in /u01."
    exit 1
fi

# Clean up raw .bak files to free space immediately
echo "Cleaning up temporary files..."
rm -f "${BACKUP_DIR}"/*.bak

# ==========================================
# Step 3: Upload to AWS S3
# ==========================================
echo "Uploading to S3 Bucket: ${S3_BUCKET}..."

aws s3 cp "${ZIP_FILE}" "${S3_BUCKET}/"

if [ $? -ne 0 ]; then
    echo "ERROR: S3 Upload failed. Check 'aws configure' setup."
    exit 1
fi

echo "Upload Successful."
echo "=========================================="
echo "Backup Finished: $(date)"
echo "File sent to S3: ${S3_BUCKET}/$(basename ${ZIP_FILE})"
echo "=========================================="
