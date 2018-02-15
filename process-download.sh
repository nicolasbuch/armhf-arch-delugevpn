#!/bin/bash
torrent_id=$1
torrent_name=$2
torrent_dir=$3
full_path="${torrent_dir}/${torrent_name}"
tmp_output_dir="/mnt/storage/tmp/$torrent_name"
tmp_output_ffmpeg_path="$tmp_output_dir/$torrent_name.mp4"
final_output_dir="/mnt/storage"
log_file="/data/process-download.log"

echo "[info] Processing download $torrent_name" >> $log_file

rar_files=$(find $full_path -type f -name '*.rar')
rar_file_count=$rar_files | wc -l

echo "[info] Looking for .rar files to extract..." >> $log_file

if [[ -n $(find $full_path -type f -name '*.rar') ]]
then
    echo "[info] Found X .rar files"
else
    echo "[info] No .rar files found" >> $log_file
    echo "[info] Skipping..." >> $log_file
fi

# Loop through all rar files and extract them
for file in $(find $full_path -type f -name '*.rar')
do
    filename=$(basename $file)
    echo "[info] Extracting $filename..." >> $log_file
    unrar e -y $file
    echo "[info] Finished extracting $filename..." >> $log_file

done

# Create temporary directory structure
mkdir -p $tmp_output_dir

# Convert all .mkv video files which are not named "sample" to mp4 with AC3 audio
for mkv_path in $(find $full_path -type f -name '*.mkv' | grep -v 'sample')
do
    echo "[info] Processing $mkv_path" >> $log_file
    # Determine the audio codec of video file
    audio_codec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $mkv_path)
    echo "[info] Audio codec $audio_codec detected" >> $log_file

    if [ "$audio_codec" == "ac3" ];
        then
            echo "Initiate copy to .mp4 container" >> $log_file
            echo "Copying..." >> $log_file
            # echo "Copy both video and audio stream"
            ffmpeg -i $mkv_path -metadata title="" -vcodec copy -acodec copy $tmp_output_ffmpeg_path 2>> $log_file
            echo "Finished copying to $tmp_output_ffmpeg_path" >> $log_file
        else
            echo "Initiate remux to .mp4 container" >> $log_file
            echo "Remuxing..." >> $log_file
            # echo "Copy both video and audio stream"
            ffmpeg -i $mkv_path -metadata title="" -vcodec copy -acodec ac3 -b:a 640k $tmp_output_ffmpeg_path 2>> $log_file
            echo "Finished remuxing to $tmp_output_ffmpeg_path" >> $log_file
        fi
done

echo "[info] Looking for subtitles to copy..." >> $log_file

if [[ -n $(find $full_path -type f -name '*.srt') ]]
    then
        echo "[info] Found X .srt files"
    else
        echo "[info] No .srt files found" >> $log_file
        echo "[info] Skipping..." >> $log_file
fi

# Copy all subtitles to tmp dir
for sub in $(find $full_path -type f -name '*.srt' | grep -v 'sample')
do
    filename=$(basename $sub)
    echo "[info] Copying $filename..." >> $log_file
    cp $sub $tmp_output_dir
    echo "[info] Finished copying $filename" >> $log_file
done

echo "[info] Initiating renaming of files" >> $log_file
echo "[info] Renaming..." >> $log_file
# Rename files/folders and move them to movies folder
filebot -script fn:amc --output "$final_output_dir" --action move --conflict skip -non-strict --log-file "$log_file" --def unsorted=y excludeList=".excludes" ut_dir="$tmp_output_dir" ut_kind="multi" ut_title="$torrent_name" ut_label=""
echo "[info] Finished renaming" >> $log_file
echo "[info] Finished processing download $torrent_name" >> $log_file