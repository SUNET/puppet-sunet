#!/bin/bash

image_path="<%= @image_path%>"
registry="<%= @registry %>"
registry_url="<%= @registry_url %>"
repo_path="<%= @repo_path%>"

for image in $(curl "${registry_url}/v2/_catalog" | jq -r '.repositories[]'); do
	for tag in $(curl "${registry_url}/v2/${image}/tags/list" | jq -r '.tags[]'); do
		filedir="${image_path}/${image}"
		mkdir -p "${filedir}"
		"${repo_path}/scanner/scanner.py" --images "${registry}/${image}:${tag}" | jq . >"${filedir}/${tag}.json"
	done
done
