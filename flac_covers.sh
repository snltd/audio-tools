#!/bin/ksh

#=============================================================================
#
# flac_covers.sh
# --------------
#
# Find any JPEG image below the current working directory, and change its
# name to "front.jpg". This script helps me keep my FLAC directories in
# order.
#
# Run with the -m option to find directories which don't have a front.jpg
# image.
#
# R Fisher 2011
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

FNAME="front.jpg"	# the target JPEG name
typeset -i c=0		# count how many files are renamed

#-----------------------------------------------------------------------------
# FUNCTIONS

die()
{
	# Print an error and exit
	# $1 is the message
	# $2 is an optional exit code

	print -u2 "ERROR: $1"
	exit ${2:-1}
}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# There's only one option, so I'm not going to bother with getopts.

if [[ $1 == "-m" && -n $2 ]]
then
	# Check all directories directories with no front.jpg

	if [[ -d $2 ]]
	then

		find $2 -type d | while read d
		do
			[[ ! -f "${d}/front.jpg" && ! -d "${d}/disc_1" ]] && print $d
		done | sort

	else
		die "$2 is not a directory."
	fi

elif [[ -n $1 ]]
then

	# Check the directory exists, find jpegs, and rename them. Skip ones
	# already named correctly

	if [[ -d $1 ]]
	then

		find . -type f -a -name \*.jpg -o -name \*.JPG -o -name \*.jpeg | \
		while read f
		do
			dir=${f%/*}

			if [[ "${f##*/}" != "front.jpg" ]]
			then

				if [[ -f "${dir}/$FNAME" ]]
				then
					print "WARNING: $FNAME already exists in ${dir}."
				else
					print "renaming in $dir"
					mv -i "$f" "${dir}/$FNAME"
					c=$(($c + 1))
				fi

			fi

		done

		print "renamed $c files."
	else
		die "$1 is not a directory."
	fi

else
	# Otherwise, print usage

	print -u2 "usage: ${0##*/} [-m] directory"
	exit 2
fi

