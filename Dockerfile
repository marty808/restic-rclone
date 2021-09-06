FROM alpine:latest as rclone

# add coreutils
RUN apk add coreutils

# Get rclone executable
ADD https://downloads.rclone.org/rclone-current-linux-amd64.zip /
RUN unzip rclone-current-linux-amd64.zip && mv rclone-*-linux-amd64/rclone /bin/rclone && chmod +x /bin/rclone

FROM restic/restic:0.12.1

COPY --from=rclone /usr/bin/tail /usr/bin/gnu_tail
COPY --from=rclone /bin/rclone /bin/rclone

RUN mkdir -p /mnt/restic /var/spool/cron/crontabs /var/log && touch /var/log/cron.log

ENV RESTIC_REPOSITORY=/mnt/restic
ENV RESTIC_PASSWORD=""
ENV RESTIC_TAG=""
ENV NFS_TARGET=""
ENV RESTIC_MODE="CRON"
ENV BACKUP_CRON="0 */6 * * *"
ENV RESTIC_FORGET_ARGS=""
ENV RESTIC_JOB_ARGS=""
ENV MAILX_ARGS=""
ENV RESTIC_REPOSITORY=""
ENV RESTIC_PASSWORD=""

# Webdav env
ENV WEBDAV_ENABLE=0
ENV WEBDAV_HOST=""
ENV WEBDAV_PATH=""
ENV WEBDAV_USER=""
ENV WEBDAV_PASSWORD=""

# /data is the dir where you have to put the data to be backed up
RUN mkdir /data

COPY backup.sh /bin/backup
COPY entry.sh /entry.sh

WORKDIR "/"

ENTRYPOINT ["/entry.sh"]
CMD ["tail","-fn0","/var/log/cron.log"]
