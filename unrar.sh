#!/bin/bash
full_path=$1

############################################
#
#   Handle extraction of .rar files
#     DEPENDENCIES:
#       - log function
#     REQUIREMENTS:
#       - Need to be able to handle extraction of .rar files partitioned into .r01 -> .r99 files
#       - Need to be able to handle extraction of part001.rar -> part999.rar files
#
####################################

found_rar_files=$(find $full_path -type f -name '*.rar')

if [ ! -z "$found_rar_files" ]
then
  # If we found any .rar files
  for file in $found_rar_files
  do
      filename=$(basename $file)

      echo "Extracting $filename..."
      unrar e -y $file
      echo "Finished extracting $filename..."

  done
else
  echo "No rar files found"
fi