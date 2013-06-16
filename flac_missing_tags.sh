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


find $DIR -name \*flac | while read file
do
	aud.sh info $file | grep " : " | while read key sep value
	do
		[[ $key == "filename" ]] && continue

		if [[ -z $value ]]
		then
			print "missing '$key'"
			print "  ${file#$DIR/}"
		fi

	done

done
