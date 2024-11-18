#!/bin/bash
config_file="<%= @config_file %>"
snapshot_dir="<%= @snapshot_dir %>"
project="<%= @project %>"
mirror="<%= @mirror %>"
bucket="<%= @bucket %>"
repository_name="<%= @repository_name %>"
remote_path="<%= @remote_path %>"


# Start at the same time everyday, 
# but with a predictable delay so
# that multiple instances of this
# script can run in parallel without
# too much overlap.
# The delay is calculated by taking
# the first 4 hex digits of the md5sum
# of the repository name and converting
# it to a decimal number, and multiplying
# it by 4. This results in a predicatable
# delay between 0 and 1020 minutes (17 hours).
sleep $((16#$(echo "${repository_name}" | md5sum | awk '{print"0x"$1}' | cut -c1-4 | xargs printf "%d" )*4))m

mkdir -p "${snapshot_dir}/${bucket}"
rclone mount "${project}:${bucket}" "${snapshot_dir}/${bucket}" --daemon --allow-other --dir-cache-time 24h
rclone mkdir "${mirror}:${bucket}-kopia"
kopia repository connect rclone --remote-path="${remote_path}" --config-file="${config_file}"
kopia snapshot create --config-file="${config_file}" "${snapshot_dir}/${bucket}"
kopia repository disconnect --config-file="${config_file}"
rclone umount "${snapshot_dir}/${bucket}"
rm -rf "${snapshot_dir:?}/${bucket}"
