#!/bin/sh
# remove-dup-files.sh
# This script requires two paths as inputs: $1 is the base folder and $2 is the folder $1 will be compared against
# $1 and $2 can be relative or absolute paths
# For each file under $1, the script will try to find a matching one with same name and size in $2
# The relative path of each file with respect to $1 and $2 does not matter
# If a match is found, the file under $1 will be moved under a new folder $1/TOBEDELETED, keeping the same relative path it had under $1. No files are removed but left under $1/TOBEDELETED to be removed by the user after the script is executed.

	current_pwd=`pwd`
	cd "$1"
	source_pwd=`pwd` # absolute path of $1
	mkdir -p TOBEDELETED # a path for deletable files is created under $1 if it does not exist yet
	cd - >/dev/null
	
	cd "$2"
	destination_pwd=`pwd` # absolute path of $2
	cd - >/dev/null

	# echo source_pwd is $source_pwd
	# echo destination_pwd is $destination_pwd

	# Links are not controlled! It is assumed that the directories are located in external units and mounted in temporary paths in the filesystem of the machine where this script is executed.

	case "$source_pwd" in
		"$destination_pwd") echo "SAME DIRECTORY AS SOURCE AND DESTINATION, EXITING"; exit 1;; # If source and destination directories are the same, an error is generated
		"$destination_pwd/*") echo "SOURCE UNDER DESTINATION, EXISTING"; exit 1;; # If source directory is under destination directory an error is generated 
		*) echo OK;; # If destination directory is under source directory, no error is generated... yet
	esac

	case "$destination_pwd" in
		"$source_pwd/*") echo "DESTINATION UNDER SOURCE, EXITING"; exit 1;; # If destination directory is under source directory an error is generated 
		*) echo OK;; # Here only after checking the directories are not the same and no one contains the other one
	esac
	
	cd "$source_pwd"
	# All files under $1 are found, except those already under a directory called TOBEDELETED. This allows executing this script more than once using the same directory as source and a set of different directories as destinations.
	# For each file, a record is generated in a temporary file under /tmp. That record contains the following fields:
	# 	- 0 appended by the file size in bytes (it is expected that command stat outputs file size as the 4th field with the options below, but this may not be true. Only tested with CentOS 7
	#	- basename of the file (just the filename)
	#	- dirname of the file (relative path from $1)
	# Example: file "sample_pic" located at $1 and with size 62185 bytes
	#	062185#sample_pic.jpg#./sample_pic.jpg
	# Example: same file located in subfolder "sample_folder"
	#	062185#sample_pic.jpg#./sample_folder/sample_pic.jpg
	find . -type f -not -path "./TOBEDELETED/*" | while read line; do echo "0"`stat -c "%y %s %n" "$line" | awk '{print $4}'`"#"`basename "$line"`"#$line"; done > /tmp/source_list.txt
	
	cd "$destination_pwd"
	# All files under $2 are found, except those already under a directory called TOBEDELETED. Those files are then discarded when deciding if a file under $1 is duplicated under $2 or not.
	# Record format and examples shown above for source are also valid for destination
	find . -type f -not -path "./TOBEDELETED/*" | while read line; do echo "0"`stat -c "%y %s %n" "$line" | awk '{print $4}'`"#"`basename "$line"`"#$line"; done > /tmp/destination_list.txt
	
	cd "$source_pwd"
	# An entry with the date of execution is added to the control file of deletable files. If that file does not exist, it is created, otherwise that entry is appended to the file
	date >> $source_pwd/TOBEDELETED/source_list_TOBEDELETED.txt
	
	# Also entries with absolute paths for source and destination directories is added to that control file	
	echo "source_pwd=$source_pwd" >> $source_pwd/TOBEDELETED/source_list_TOBEDELETED.txt
	echo "destination_pwd=$destination_pwd" >> $source_pwd/TOBEDELETED/source_list_TOBEDELETED.txt
	
	echo "starting the loop over source files"
	cat /tmp/source_list.txt | while read line; do
		# The record for the source file is split and save into several variables
		size_and_base_name=`echo "$line" | awk -F"#" '{print $1"#"$2"#"}'`
		rel_name=`echo "$line" | awk -F"#" '{print $3}'`
		dir_name=`dirname "$rel_name"`
		# echo size_and_base_name is $size_and_base_name
		# echo rel_name is $rel_name
		# echo dir_name is $dir_name
		# Size and filename are used to find a match in destination file. This search is case-insensitive
		grep -i "$size_and_base_name" /tmp/destination_list.txt > /tmp/auxgrep
		salida=$?
		# echo grep output is $salida
		if [ $salida -eq 0 ]; then
			# If the search yields results, the file is added for deletion to the control file
			echo "$line#"`head -1 /tmp/auxgrep` >> $source_pwd/TOBEDELETED/source_list_TOBEDELETED.txt
			# echo "$line#"`head -1 /tmp/auxgrep`
			# The following variables are used to create the destination folder under TOBEDELETED and to move the file to that folder
			new_dir_name=`echo "$dir_name" | sed -e "s/\./\.\/TOBEDELETED/"` 
			new_rel_name=`echo "$rel_name" | sed -e "s/\./\.\/TOBEDELETED/"` 
			# echo $new_dir_name
			# echo $new_rel_name
			mkdir -p "$new_dir_name"
			mv "$rel_name" "$new_rel_name"
			# moved $rel_name to $new_rel_name
		else
			# If the search does not yield results, the file is not added for deletion to the control file, but to another control file where files to be kept are listed
			echo "$line" >> $source_pwd/TOBEDELETED/source_list_SAVED.txt
		fi
	done
cd "$current_pwd"