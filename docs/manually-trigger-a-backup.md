# Manually trigger a backup

Sometimes, it's necessary to manually trigger backup actions.

This can be useful when other programs are used to consistently schedule tasks or to verify that environment variables are properly configured.

<br>



## Usage

Previously, performing an immediate backup required overwriting the entrypoint of the image. However, with the new setup, you can perform a backup directly with a parameterless command.

```shell
docker run \
  --rm \
  --name rclone_backup \
  --volumes-from=your-container \
  --mount type=volume,source=rclone-backup-data,target=/config/ \
  -e ... \
  adrienpoupa/rclone-backup:latest backup
```

You also need to mount the rclone config file and set the environment variables.

The only difference is that the environment variable `CRON` does not work because it does not start the CRON program, but exits the container after the backup is done.

<br>



## IMPORTANT

**Manually triggering a backup only verifies that the environment variables are configured correctly, not that CRON is working properly. This is the [issue](https://github.com/AdrienPoupa/rclone-backup/issues/53) that CRON may not work properly on ARM devices.**

