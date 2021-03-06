#!bin/sh

echo "Starting container ..."

if [ -n "${NFS_TARGET}" ]; then
    echo "Mounting NFS based on NFS_TARGET: ${NFS_TARGET}"
    mount -o nolock -v ${NFS_TARGET} /mnt/restic
fi

# get RESTIC target if sftp
RESTIC_PROTOCOL=$(echo $RESTIC_REPOSITORY | cut -d':' -f1)

if [ $RESTIC_PROTOCOL == "sftp" ]; then
    SFTP_TARGET=$(echo $RESTIC_REPOSITORY | cut -d':' -f2 | cut -d'@' -f2)
fi

# add remote SSH key
if [ -n "${SFTP_TARGET}" ]; then
    # Authorize SSH Host
    mkdir -p /root/.ssh
    chmod 0700 /root/.ssh
    ssh-keyscan ${SFTP_TARGET} >> /root/.ssh/known_hosts
fi

# check for SSH key
if [ -e  /root/.ssh/id_rsa ]; then
    chmod 600 /root/.ssh/id_rsa
else
    echo "SSH Key not mounted... exiting"
    exit 2
fi

if [ ${WEBDAV_ENABLE} ]; then
    if [ -n "${WEBDAV_HOST}" ]; then
       echo "WEBDAV enabled: ${WEBDAV_HOST}/${WEBDAV_PATH}"
    else 
       echo "Webdav enabled BUT no HOST provided. Please use Environment Variables... exiting"
       exit 2
    fi
    if [ -n "${WEBDAV_USER}" ] && [ -n "${WEBDAV_PASSWORD}" ]; then
       echo "Webdav enabled with Credentials provided."
    else 
       echo "Webdav enabled BUT no Credentials provided. Please use Environment Variables... exiting"
       exit 2
    fi
    echo "creating rclone remote config"
    rclone config create WEBDAV webdav vendor nextcloud url ${WEBDAV_HOST}/${WEBDAV_PATH} user ${WEBDAV_USER} pass ${WEBDAV_PASSWORD}
    echo "Mounting Webdav ${WEBDAV_HOST}/${WEBDAV_PATH} to /data"
    rclone mount WEBDAV:/ /data &

    if [ $? -eq 0 ]; then
       echo "WEBDAV successfully mounted"
    else
       echo "Could not mount WEBDAV"
       exit 3
    fi
fi

restic snapshots &>/dev/null
status=$?
echo "Check Repo status $status"

if [ $status != 0 ]; then
    echo "Restic repository '${RESTIC_REPOSITORY}' does not exists. Running restic init."
    restic init

    init_status=$?
    echo "Repo init status $init_status"

    if [ $init_status != 0 ]; then
        echo "Failed to init the repository: '${RESTIC_REPOSITORY}'"
        exit 1
    fi
fi


if [ $RESTIC_MODE == "CRON" ]; then
    echo "Setup backup cron job with cron expression BACKUP_CRON: ${BACKUP_CRON}"
    echo "${BACKUP_CRON} /usr/bin/flock -n /var/run/backup.lock /bin/backup >> /var/log/cron.log 2>&1" > /var/spool/cron/crontabs/root

    # Make sure the file exists before we start tail
    touch /var/log/cron.log

    # start the cron deamon
    crond
    echo "Cron started."
    
    echo "Container started."

    exec "$@"

elif [ $RESTIC_MODE == "RUN" ]; then
    echo "Run backup:"
    touch /var/log/backup-last.log
    /bin/backup &
    tail -f --pid $! /var/log/backup-last.log
    exit 0   
else
    echo "RESTIC_MODE have to be 'RUN' or 'CRON'"
    exit 1
fi
