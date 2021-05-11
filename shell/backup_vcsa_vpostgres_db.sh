#!/bin/bash
# William Lam
# www.williamlam.com
# Script to backup VCSA's vPostgres DB to Amazon S3 

# Path to vPostgres backup script (download from http://kb.vmware.com/kb/2091961)
VPOSTGRES_BACKUP_SCRIPT=/root/backup_lin.py
# Path to AWS CLI
AWS_CLI=/usr/local/bin/aws
# Name of S3 Bucket
AWS_S3_BUCKET='s3://vcsa-backup'

# Directory to store backup before uploading
BACKUP_DIRECTORY=/storage/core
# Name of the Backup file
BACKUP_FILE=${BACKUP_DIRECTORY}/backup-$(date +%F_%H-%M-%S)

log() {
	MESSAGE=$1
	echo "${MESSAGE}"
	logger -t 'VCSA-BACKUP' "${MESSAGE}"
}

# Ensure backup script exists before moving forward
if [ ! -f ${VPOSTGRES_BACKUP_SCRIPT} ]; then
	log "Unable to locate vPostgres DB backup script: ${VPOSTGRES_BACKUP_SCRIPT} ... exiting"
	exit 1
fi

# Ensure AWS CLI is installed before moving forward
if [ ! -f ${AWS_CLI} ]; then
	log "Unable to locate AWS CLI: ${AWS_CLI} ... exiting"
	exit 1
fi

# Start vPostgres DB backup
log "Starting vPostgres DB backup ..."
python ${VPOSTGRES_BACKUP_SCRIPT} -f ${BACKUP_FILE} > /dev/null 2>&1
if [ $? -eq 0 ]; then
	log "vPostgres DB backup completed successfully"
fi

# Upload vPostgres DB Backup to S3 or to any other destination
log "Uploading vPostgres DB backup ${BACKUP_FILE} to ${AWS_S3_BUCKET}"
${AWS_CLI} s3 cp ${BACKUP_FILE} "${AWS_S3_BUCKET}" > /dev/null 2>&1
if [ $? -eq 0 ]; then
	log "vPostgres DB backup file uploaded successfully"
fi

# Clean up
log "Cleaning up backup file ..."
rm -f ${BACKUP_FILE}
