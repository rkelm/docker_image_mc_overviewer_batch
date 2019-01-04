#!/bin/bash

if [ -z $1 ] ; then
    echo "usage: $(basename $0) <mc_version>"
    exit 1
fi

errchk() {
    if [ "$1" != "0" ] ; then
	echo "$2"
	echo "Exiting."
	exit 1
    fi
}

# ***** Configuration *****
# Assign configuration values here or set environment variables.
local_repo_path="$BAKERY_LOCAL_REPO_PATH"
remote_repo_path="$BAKERY_REMOTE_REPO_PATH"
repo_name="overviewer_minecraft"

# Default server properties may be changed below.
# Some options may be set directly in the Dockerfile.
if [ -z "$local_repo_path" ] || [ -z "$remote_repo_path" ] ; then
    errchk 1 'Configuration variables in script not set. Assign values in script or set corresponding environment variables.'
fi

# The project directory is the folder containing this script.
project_dir=$( dirname "$0" )
project_dir=$( ( cd "$project_dir" && pwd ) )
if [ -z "$project_dir" ] ; then
    errck 1 "Error: Could not determine project_dir."
fi
echo "Project directory is ${project_dir}."

mc_version="$1"
image_tag="$mc_version"

if [ -n "$image_tag" ] ; then
    local_repo_tag="${local_repo_path}/${repo_name}:${image_tag}"
    remote_repo_tag="${remote_repo_path}/${repo_name}:${image_tag}"    
else
    local_repo_tag="${local_repo_path}:${repo_name}"
    remote_repo_tag="${remote_repo_path}:${repo_name}"
fi

# Prepare rootfs
mkdir -p ${project_dir}/rootfs/bin
mkdir -p ${project_dir}/rootfs/map_data
mkdir -p ${project_dir}/rootfs/render_output

# Build.
echo "Building $local_repo_tag"
docker build --no-cache --build-arg "APP_VERSION=${mc_version}" -t "${local_repo_tag}" "${project_dir}" 
errchk $? 'Docker build failed.'

# Get image id.
image_id=$(docker images -q "${local_repo_tag}")

test -n $image_id
errchk $? 'Could not retrieve docker image id.'
echo "Image id is ${image_id}."

# Tag for Upload to aws repo.
docker tag "${image_id}" "${remote_repo_tag}"
errchk $? "Failed re-tagging image ${image_id}".

# Upload.
echo "Execute the following commands to upload the image to remote aws repository."
echo '   $(aws ecr get-login --no-include-email --region eu-central-1)'
echo "   docker push ${remote_repo_tag}"
