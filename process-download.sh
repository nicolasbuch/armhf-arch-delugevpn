#!/bin/bash
torrent_id=$1
torrent_name=$2
torrent_dir=$3
full_path="${torrent_dir}/${torrent_name}"
tmp_output_dir="/mnt/storage/tmp/$torrent_name"
final_output_dir="/mnt/storage"
log_file="/data/process-download.log"

############################################
#
#   Function which handles notifications
#
#   Params:
#   string $message
#   string $level [default: "info"]
#
############################################

notify () {
    message=$1
    level=$2

    # If no notification level is defined, default to info
    if [ -z $level ] ; then level="info" ; fi

    echo "[$level] $message" >> $log_file
}


notify "Processing download $torrent_name"

# Create temporary directory structure
mkdir -p $tmp_output_dir


############################################
#
#   Handle extraction of .rar files
#
############################################

for file in $(find $full_path -type f -name '*.rar')
do
    filename=$(basename $file)

    notify "Extracting $filename..."
    unrar e -y $file
    notify "Finished extracting $filename..."

done


# Convert all .mkv video files which are not named "sample" to mp4 with AC3 audio
for mkv_path in $(find $full_path -type f -name '*.mkv' | grep -i -v 'sample')
do
    # Get the filename from filepath and strip it from its extension
    mkv_filename=$(basename $mkv_path)
    mkv_filename="${mkv_filename%.*}"
    mkv_dir=$(dirname $mkv_path)

    # Build a temp output path
    tmp_output_path="$tmp_output_dir/$mkv_filename.mp4"



    ############################################
    #
    #   Handle extraction of subtitles from
    #   mkv file to external srt file
    #
    ############################################

    # Get the stream output of the file in json
    mkv_stream_ouput=$(ffprobe -v error -show_entries stream=index,codec_name,codec_type:stream_tags=language -print_format json $mkv_path)

    # Loop through the stream output
    for row in $(echo $mkv_stream_ouput | jq -r '.streams[] | @base64')
    do
        # Will return the row of a given key from the stream_output
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        # If the codec type is not a subtitle, then continue
        if [ $(_jq '.codec_type') != 'subtitle' ]
            then
            continue
        fi

        # If the codec type is null, then notify and continue
        if [ $(_jq '.tags.language') == null ]
            then
            notify "Subtitle track does not have a language. Skipping..." "warn"
            continue
        fi

        # Set variables with available information about this stream
        index=$(_jq '.index')
        codec_name=$(_jq '.codec_name')
        language=$(_jq '.tags.language')
        tmp_srt_stream_output_path="$tmp_output_dir/$mkv_filename.$language.srt"

        notify "Extracting $language subtitle..."

        # Extract subtitle with ffmpeg into tmp output dir
        # TODO: Slow approach to extract subtitle due to it "transcoding"? Any copy commands?
        ffmpeg -y -i $mkv_path -map 0:$index $tmp_srt_stream_output_path 2>> $log_file

        notify "Finished extracting subtitle to $tmp_srt_stream_output_path"

    done


    ############################################
    #
    #   Handle copying of any external
    #   subtitles
    #
    ############################################

    notify "Looking for external subtitles to copy..."

    # Find all files with .srt extension
    srt_files=$(find $mkv_dir -type f -name '*.srt')

    if [[ -n $srt_files ]]
        then
            # Get the count of .srt files found
            srt_files_count=$(find $mkv_dir -type f -name '*.srt' | wc -l)

            notify "Found [$srt_files_count] .srt files"
        else
            notify "No .srt files found. Skipping..."
    fi

    # Loop through the found subtitles
    # Copy all subtitles to tmp dir
    for sub in $(find $mkv_dir -type f -name '*.srt' | grep -i -v 'sample')
    do
        sub_filename_full=$(basename $sub)
        extension="${sub_filename_full##*.}"
        filename="${sub_filename_full%.*}"
        filename_lenght=${#filename}

        # Check for subtitle naming convention DA.srt, DE.srt e.t.c. since filebot will see them as orphaned
        if [ filename_lenght == 2 ]
        then
            notify "Subtitle naming convention is not compatible with filebot"
            notify "Copying && renaming $sub_filename_full to $mkv_filename.$sub_filename_full..."
            cp $sub "$tmp_output_dir/$mkv_filename.$sub_filename_full"
            notify "Finished copying $sub_filename_full"
        else
            notify "Copying $sub_filename_full..."
            cp $sub $tmp_output_dir
            notify "Finished copying $sub_filename_full"
        fi
    done



    ############################################
    #
    #   Handle transcoding and/or container
    #   swapping to .mp4 with ac3 audio.
    #
    #   This will enable directplay
    #   on all Apple Tv's.
    #
    ############################################

    # Determine the audio codec of video file
    audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $mkv_path)

    notify "Processing $mkv_path";
    notify "Audio codec $audio_codec detected"

    if [ "$audio_codec" == "ac3" ];
        then
            notify "Initiate copy of video and audio to .mp4 container"
            notify "Copying..."

            # Remux to mp4 container
            ffmpeg -y -i $mkv_path -metadata title="" -vcodec copy -acodec copy $tmp_output_path 2>> $log_file

            notify "Finished copying to $tmp_output_path"
        else
            notify "Transcoding of audio is needed"
            notify "Initiate copy of video and transcoding of audio to mp4 container"
            notify "Copying & transcoding..."

            # Copy and transcode to .mp4 container
            ffmpeg -y -i $mkv_path -metadata title="" -vcodec copy -acodec ac3 -b:a 640k $tmp_output_path 2>> $log_file

            notify "Finished copying & transcoding $tmp_output_path"
    fi
done


############################################
#
#   Handle renaming files, moving them
#   to their destination and pinging
#   plex to reindex it's libraries
#
############################################

notify "Initiating renaming of files"
notify "Renaming..."

# Rename files/folders and move them to movies folder
filebot -script fn:amc --output "$final_output_dir" --action move --conflict skip -non-strict --log-file "$log_file" --def unsorted=y plex=192.168.1.100:mx93Mzy4MLYSMVC9TZq7 excludeList=".excludes" ut_dir="$tmp_output_dir" ut_kind="multi" ut_title="$torrent_name" ut_label=""

notify "Finished renaming"
notify "Finished processing download $torrent_name"