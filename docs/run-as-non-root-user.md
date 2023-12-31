# Run as non-root user

By default, the container runs the backup script as the root user. If you wish to run the container as a non-root user, there are a few things you need to set.

You can use the built-in non-root user and group, named `backuptool`, with the UID and GID of `1100`.

<br>



## Backup

1. Make sure that the rclone config file in the mounted `rclone-backup-data` volume is writable by `backuptool` user.

```shell
# enter the container
docker run --rm -it \
  --mount type=volume,source=rclone-backup-data,target=/config/ \
  --entrypoint=bash \
  adrienpoupa/rclone-backup:latest

# modify the rclone config file owner in the container
chown -R 1100:1100 /config/

# exit the container
exit
```

2. If you want a full backup of the `rsa_key*`, you need to allow the `backuptool` user to read the `rsa_key*`.

**With Docker Compose**

```shell
# enter the container
docker run --rm -it \
  --mount type=volume,source=rclone-backup-data,target=/data/ \
  --entrypoint=bash \
  adrienpoupa/rclone-backup:latest

# make files readable for all users in the container
chmod -R +r /data/

# exit the container
exit
```

**With Automatic Backups**

```shell
# enter the container
docker run --rm -it \
  --volumes-from=your-container \
  --entrypoint=bash \
  adrienpoupa/rclone-backup:latest

# make files readable for all users in the container
chmod -R +r /data/

# exit the container
exit
```

3. Start the container with proper parameters.

**With Docker Compose**

```shell
# docker-compose.yml
services:
  backup:
    image: adrienpoupa/rclone-backup:latest
    user: 'backuptool:backuptool'
    ...
```

**With Automatic Backups**

```shell
docker run -d \
  ...
  --user backuptool:backuptool \
  ...
  adrienpoupa/rclone-backup:latest
```

<br>



## Restore

Perform the restore normally, nothing special.
