#!/bin/bash

mountpoint=/opt/mastodon_web/syncmount
bucket="<%= @s3_bucket>"
mkdir -p "${mountpoint}"

rclone mount old: ${mountpoint}/ --daemon --allow-other

rclone sync "${mountpoint}/${bucket}" "new:${bucket}"
rclone sync "${mountpoint}/shared" new:shared

umount "${mountpoint}"
rmdir "${mountpoint}"
