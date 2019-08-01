#!/bin/bash

errchk() {
    if [ ! $1 == 0 ] ; then
	echo '*** ERROR ***' 1>&2
	echo $2 1>&2
	echo 'Exiting.' 1>&2
	exit 1
    fi
}

del_lowest_dir() {
    # Deletes all directories with the greatest depth (incl. their files)
    # found in the directory structure under the root directory path
    # passed as the first parameter.

    # Check subdirectories.
    local cnt
    find "$1" -type d -print0 | while IFS= read -r -d '' dir
    do
	if [ "$dir" != "$1/icons" ] ; then
	    # Check the current directory for more subdirectories.
	    cnt=$( find "$dir" -maxdepth 1 -type d | wc -l )
	    if [ "$cnt" == "1" ] ; then
		# No subdirectores found -> remove directory.
		rm --force "${dir}"/*
		rmdir "${dir}"
	    fi
	fi
    done
}

print_usage() {
    echo 'usage: render_map.sh <map_id>';
    echo 'Renders current map and updates public storage for map files.'
}

map_id=$1
if [ -z "${map_id}" ] ; then
    print_usage
    exit 0
fi
if [ "${map_id}" == "-h" ] ; then
    print_usage
    exit 0
fi

path=$(dirname $0)

# Log environment and run parameters
echo "Running: $0 $@"
echo "Printing environment:"
echo $( env | sort | sed "s/google_api_key=.*/google_api_key=XXXXXXXXXXXX/" )

# Variable render_output must be set or root file system will be deleted.
if [ -z "$render_output" ] ; then
    echo "Variable render_output is not set"
    exit 1
fi
if [ -z "$region" ] ; then
    echo "Variable region (aws region) is not set"
    exit 1
fi
if [ -z "$pub_bucket" ] ; then
    echo "Variable pub_bucket is not set"
    exit 1
fi
if [ -z "$pub_bucket_maps_dir" ] ; then
    echo "Variable pub_bucket_maps_dir is not set"
    exit 1
fi
if [ -z "$map_data_dir" ] ; then
    echo "Variable map_data_dir is not set"
    exit 1
fi
if [ -z "$tmp_dir" ] ; then
    echo "Variable tmp_dir is not set"
    exit 1
fi
if [ -z "$bucket" ] ; then
    echo "Variable bucket is not set"
    exit 1
fi
if [ -z "$bucket_render_cache" ] ; then
    echo "Variable bucket_render_cache_dir is not set"
    exit 1
fi
if [ -z "$bucket_render_cache_dir" ] ; then
    echo "Variable bucket_render_cache_dir is not set"
    exit 1
fi
if [ -z "$google_api_key" ] ; then
    echo "Variable google_api_key is not set"
    exit 1
fi


# Retrieve map files.
echo "Copying map file s3://${bucket}/${bucket_map_dir}/${map_id}.tgz to ${tmp_dir}."
aws s3 --region "$region" cp "s3://${bucket}/${bucket_map_dir}/${map_id}.tgz" "${tmp_dir}"
errchk $? "aws s3 cp call failed for s3://${bucket}/${bucket_map_dir}/${map_id}.tgz."

# Untar world files.
echo "Unpacking map file to $map_data_dir."
tar xzf "${tmp_dir}/${map_id}.tgz" -C "$map_data_dir"
errchk $? "untar failed for ${tmp_dir}/${map_id}.tgz."

echo 'Clearing render output directory.'
rm -fr "${render_output}/*"

# Download cached files from last render, if a bucket for the cached render files is defined.
if [ -n "$bucket_render_cache" -a -n "$bucket_render_cache_dir" ] ; then
  echo "Looking for cached rendered files at $bucket_render_cache."
  output=$(aws s3api --region "$region" list-objects-v2 --bucket "$bucket_render_cache" --prefix "${bucket_render_cache_dir}/${map_id}_render.tgz" --query 'Contents[*].[Key]' --output text)
  errchk $? 'aws s3api list-objects-v2 call failed.'

  if [ "${output}" == "None" ] ; then
      echo "No cached rendered files found."
  else
      echo "Downloading cached rendered files."
      aws s3 --region "$region" cp "s3://${bucket_render_cache}/${bucket_render_cache_dir}/${map_id}_render.tgz" "${tmp_dir}"
      tar xzf "${tmp_dir}/${map_id}_render.tgz" -C "$render_output"
      errchk $? "untar failed for ${tmp_dir}/${map_id}_render.tgz."
      rm "${tmp_dir}/${map_id}_render.tgz"
  fi
fi

# Check if there is a config file in the expected location.
if [ -e "${map_data_dir}/overviewer_config/overviewer.config" ] ; then
    map_id="$map_id" overviewer.py --config="${map_data_dir}/overviewer_config/overviewer.config"
    ret="$?"
else
    echo 'No config file found. Running basic render.'
    overviewer.py "${map_data_dir}/world" "$render_output"
    ret="$?"
fi
errchk "$ret" "overviewer.py call failed."

echo "Adding google API key."
# Add Google API key to use Google Maps API.
sed -i 's/maps.google.com\/maps\/api\/js">/maps.google.com\/maps\/api\/js\?key='"$google_api_key"'">/' "${render_output}/index.html"
# Test if insert of google api key succeeded.
grep "key=${google_api_key}" "${render_output}/index.html" > /dev/null
if [ ! "$?" == "0" ]; then
    echo "Adding Google API Key to Google Maps API failed."
fi

echo 'Caching rendered files in s3.'
tar czf "${tmp_dir}/${map_id}_render.tgz" -C "$render_output" .

# Upload archive with cached files to s3.
echo "Copying ${tmp_dir}/${map_id}_render.tgz to s3://${bucket_render_cache}/${bucket_render_cache_dir}/${map_id}_render.tgz"
aws s3 --region "$region" cp "${tmp_dir}/${map_id}_render.tgz" "s3://${bucket_render_cache}/${bucket_render_cache_dir}/${map_id}_render.tgz"
errchk $? "awsc cp call failed"
rm "${tmp_dir}/${map_id}_render.tgz"

# Delete lowest layer of map tiles.
del_lowest_dir "$render_output"

# Delete lowest layer of map tiles, again.
del_lowest_dir "$render_output"

# Upload new files.
echo "Uploading changed tiles with aws sync to s3://${pub_bucket}/${pub_bucket_maps_dir}/${map_id}/"
aws --region "${region}" s3 sync --only-show-errors "${render_output}/" "s3://${pub_bucket}/${pub_bucket_maps_dir}/${map_id}/"
errchk $? ""
echo "Clearing map data"
rm -fr ${map_data_dir}/*

mkdir -p "${map_data_dir}/world" "${map_data_dir}/world_nether" "${map_data_dir}/world_the_end"

echo 'Clearing render output directory.'
rm -fr ${render_output}/*

