# FreePBX Remote Backup
The Script will copy the latest .tgz backup that FreePBX creates to a offsite server, confirm the
file was successfully copied across else it will retry the copy with a max of 4 attempts,
once the copy is successful it will verify the integrity of the archive.
