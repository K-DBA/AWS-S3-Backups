# --- CONFIGURATION ---
 $ServerInstance = "localhost\SQLEXPRESS"
 $DatabaseName = "PRACTICE"
 $LocalBackupPath = "E:\SQLBackups"      # Ensure this folder exists
 $S3BucketName = "mssql-db-bk-2019"
 $Region = "ap-south-1"

# --- ZIP CONFIGURATION ---
# If you installed 7-Zip normally, this path is correct. If not, update it.
 $SevenZipPath = "C:\Program Files\7-Zip\7z.exe" 
 $ZipPassword = "Password@123"  # <--- SET YOUR PASSWORD HERE

# --- SCRIPT LOGIC ---
 $DateStamp = Get-Date -Format "yyyyMMdd_HHmmss"
 $FileName = "$DatabaseName`_$DateStamp.bak"
 $FullPath = "$LocalBackupPath\$FileName"
 $ZipFileName = "$DatabaseName`_$DateStamp.zip"
 $ZipFullPath = "$LocalBackupPath\$ZipFileName"

Write-Host "Starting backup for $DatabaseName..."

# 1. Run SQL Backup
 $Query = "BACKUP DATABASE [$DatabaseName] TO DISK = '$FullPath' WITH FORMAT, NAME = 'Express Backup';"
sqlcmd -S $ServerInstance -Q $Query -b

# Check if backup failed
if ($LASTEXITCODE -ne 0) {
    Write-Error "SQL Backup failed! Check permissions or path."
    exit
}

Write-Host "Backup successful. Creating Password Protected Zip..."

# 2. Create Password Protected Zip using 7-Zip
# a = add, -tzip = zip format, -p = password, -mx5 = normal compression
 $Arguments = "a -tzip -p$ZipPassword -mx5 `"$ZipFullPath`" `"$FullPath`""
Start-Process -FilePath $SevenZipPath -ArgumentList $Arguments -Wait -NoNewWindow

# Check if zip was created
if (-not (Test-Path $ZipFullPath)) {
    Write-Error "Zipping failed! Check if 7-Zip is installed correctly."
    exit
}

Write-Host "Zip created. Uploading to S3..."

# 3. Upload ZIP to S3
aws s3 cp $ZipFullPath "s3://$S3BucketName/$ZipFileName" --region $Region

# 4. Cleanup
if ($?) {
    Write-Host "Upload successful. Cleaning up local files..."
    Remove-Item $FullPath   # Delete .bak
    Remove-Item $ZipFullPath # Delete .zip
    Write-Host "Done."
} else {
    Write-Error "S3 Upload failed! Files retained at $LocalBackupPath"
}
