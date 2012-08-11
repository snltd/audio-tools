#!/bin/ksh93

#=============================================================================
#
# aud.sh
# ------
#
# Manipulation of FLAC and MP3 files.
#
# R Fisher 04/09
#
# Please record changes below
#
# v1.0  Initial release.
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

typeset -l FILETYPE
typeset -A TRACK


#-----------------------------------------------------------------------------
# FUNCTIONS

. audio_functions.ksh

function usage
{
	cat<<-EOUSAGE

		  usage: ${0##*/} <command> <files>

		  commands:

		    artist=str : set artist/band name tag to 'txt'
		    track=str  : set track title tag to 'txt'
		    album=str  : set album title tag to 'txt'
		    title=str  : set track title tag to 'txt'
		    genre=str  : set tag to text string txt
		     
		    name2tag   : tag the file from the filename. Assumes artist.title
		    tag2name   : rename a file from the ID3/FLAC tag
		     
		    bump=n     : increase track number by 'n'
		    sort       : put loose files in album-specific directories
		    transcode  : convert files to MP3, preserving tags
		    number     : number tracks, assuming the filename begins with
		                 the track number
		    inumber    : number tracks interactively
		     
		    info       : show track information
		    verify     : verify files -- only works for FLACs
		    notag=str  : does file have the 'str' tag.
		    	
		    help       : print this message

	EOUSAGE

	exit 2

}

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

for tool in lame metaflac id3info flac
do
    whence $tool >/dev/null 2>&1 || die "$tool binary is missing"
done


[[ $# -lt 2 ]] && \
	usage

# Get the command. Some commands can have values attached

CMD=$1

if [[ $CMD == *"="* ]]
then
	CARG=${CMD#*=}
	CMD=${CMD%%=*}
fi

# Break off the command, so all the arguments left are filenames

shift

case $CMD in 

	artist|title|album|genre|track|year)
		FUNC=set_value 
		EXTRA_ARGS="${CMD}=$CARG"
		NOTRACK=true
		;;

	"bump")
		is_int $CARG \
			|| die "'bump' requires a numerical value."

		FUNC=bump_track_no
		EXTRA_ARGS=$CARG
		;;

	"info")	
		FUNC=show_track_info 
		;;
	
	"name2tag")
		FUNC=name2tag
		NOTRACK=true
		;;

	"tag2name")
		FUNC=tag2name
		;;

	"transcode")
		FUNC=transcode_flac
		;;

	"number")
		FUNC=number
		NOTRACK=true
		;;

	"sort")
		FUNC=sort_files
		;;

	"verify")
		FUNC=verify_files
		NOTRACK=true
		;;
	
	"notag")
		FUNC=notag_files
		EXTRA_ARGS=$CARG
		NOTRACK=true
		;;

	"inumber")
		FUNC=inumber_files
		NOTRACK=true
		;;

	*)	usage
		;;

esac

for file in "$@"
do

	if [[ ! -s $file ]]
	then
		print "ERROR: $file does not exist."
		continue
	fi

	# Put the file type in a global variable. We only support MP3 and FLAC

	FILETYPE=${file##*.}

	# Check each file is valid

	if [[ $FILETYPE == "flac" ]]
	then
		
		if ! metaflac --list "$file" >/dev/null 2>&1
		then
			print "'${file}' is not a FLAC"
			continue
		fi
	
	elif [[ $FILETYPE == "mp3" ]]
	then

		if ! file "$file" | egrep -s "MPEG-1"
		then
			print "'${file}' is not an MP3"
		fi

	else
		print "'${FILETYPE}' files are not supported."
		continue
	fi

	# We generally need track information, so unless told not to, get it. It
	# goes in the TRACK variable

	[[ -z $NOTRACK ]] && get_track_info_$FILETYPE "$file"

	# Now perform the operation

	$FUNC "$file" "$EXTRA_ARGS"
done

exit $EXIT
