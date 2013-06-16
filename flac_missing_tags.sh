#!/bin/ksh

#=============================================================================
#
# flac_missing_tags.sh
# --------------------
#
# Find files with missing tags. Requires my 'aud.sh' script.
#
# Usage: first argument is an optional directory.
#
# R Fisher 06/2013
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

BASE="/storage/flac"
	# Where your FLACs are stored

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# If we don't have an argument, default to the BASE

[[ -n $1 ]] && DIR=$1 || DIR=$BASE


find $DIR -type d | sort | while read dir
do

	[[ $(ls -l $dir | grep -c "^-.*flac$") == 0 ]] && continue

	# Look at the files in this directory and see if they're missing any
	# tags. We report a directory has missing tags if ANY of the files
	# are.

	find $dir -name \*.flac | while read file
	do
		MISSING=""

		aud.sh info $file | grep " : " | while read key sep value
		do
			[[ $key == "filename" ]] && continue
			[[ -z $value ]] && MISSING="$MISSING $key"
		done

	done
	
	if [[ -n $MISSING ]]
	then
		print "\n${dir##*/}"
		
		for tag in $MISSING
		do
			print "  $tag"
		done

	fi

done
