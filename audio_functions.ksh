#=============================================================================
#
# Functions for FLAC and MP3 related stuff
#
#
# GLOBAL VARIABLES 
#
# TRACK(
#   T_TITLE   : track title (free string)
#   A_TITLE   : album title (free string)
#   F_TITLE   : filename song title (lower case/underscore string)
#   T_ARTIST  : track artist (free string)
#   F_ARTIST  : filename artist (lower case/underscore string, no "the_"
#   A_YEAR    : album release date (YYYY)
#   T_NO		: track number (int)
#   GENRE     : genre of music (free string)
# )
#

#=============================================================================

qualify_path()
{
    # Make a path fully qualified, if it isn't already. 
    # $1 is the path to qualify

    if [[ $1 == /* ]]
    then
        print $1
    else
        print $(pwd)/$1
    fi

}

function die
{
    # Print an error message and exit

    print -u2 "ERROR: $1"
    exit ${2:-1}
}

function is_int
{
	# Is arg an integer?

	[[ -z $1 ]] || print $1 | egrep -s "[^0-9]" \
		&& return 1 \
		|| return 0 

}

function mk_fname
{
	# Takes a string and spits out a "filename safe" version of it.

	# Args are the string

	typeset -l outname="$*"

	print $outname | sed 's/ \{1,\}/_/g;s/[^0-9a-z._-]//g'
}

function mk_title
{
	# Inverse of mk_fname(). Capitalises and add spaces. Doesn't do a GREAT
	# job, but near enough.
	# $* is the string to work on

	NOCAPSLIST=" and of in the for on it its is a "
	typeset -i i=0
	typeset -u initial

	for word in $(print $* | tr "_" " ")
	do
		if [[ $i -gt 0 && $NOCAPSLIST == *" $word "* ]]
		then
			print -n -- "$word "
		else
			initial=${word:0:1}
			print -n -- "${initial}${word:1} "
		fi

		((i++))
	done

	print
}

function is_flac
{
	# Is file a flac?
	# $1 is the file

	metaflac --list "$1" >/dev/null 2>&1
}

function get_val_flac
{

	# $1 is the key
	# $2 is the file
	
	typeset val
	
	val=$(metaflac --show-tag=$1 "$2" 2>/dev/null)

	print -- ${val#*=}
}

function get_bitrate_mp3
{
	# $1 is the file

	id3info "$1" | sed -n '/^Bitrate/s/^.*: //p'
}

function set_val
{
	# $1 is the filetype
	# $2 is the key
	# $3 is the value
	# $4 is the file

	typeset cmdkey
	
	if [[ $# != 4 ]]
	then
		print "set_val requires four args."
		return 1
	fi
		
	if [[ ! -f "$4" ]]
	then
		print "file does not exist. [$4]"
		return 1
	fi

	if [[ ! -w "$4" ]]
	then
		print "file is not writeable. [$4]"
		return 1
	fi

	if [[ $1 == "flac" ]]
	then

		case $2 in
			
			title|artist|album|genre)
				cmdkey=$2
				;;

			track)
				cmdkey="tracknumber"
				;;

			year)
				cmdkey="date"
				;;

			*)	print "unknown key [$2]"
				return 1

		esac

		metaflac --remove-tag=$cmdkey "$4"
		metaflac --set-tag=${cmdkey}="$3" "$4"

	elif [[ $1 == "mp3" ]]
	then

		case $2 in
			
			artist|album|track|total|year|genre)
				cmdkey=$2
				;;

			title)
				cmdkey="song"
				;;

			*)	print "unknown key [$2]"
				return 1

		esac

		id3tag --${cmdkey}="$3" "$4" >/dev/null 2>&1
	else
		print "unknown filetype [$1]"
		return 1
	fi

}

function get_track_info_flac
{
	# Populates global variable TRACK with an associative array of the track
	# information in a FLAC

	# $1 is the file

	# Sometimes the keys are uppercase, so force them lower for the benefit
	# of the switch. Q needs to be an associative array

	typeset -l key
	typeset -A Q

	metaflac --list "$1" | egrep "bits-per-sample|sample_rate|comment\[" \
	| sed 's/^.*comment\[[0-9]*\]: //;/^ /s/^ *\([a-z_\-]*\): /\1=/' | \
	while read l
	do
		key=${l%%=*}
		val=${l#*=}

		case $key in
			
			"sample_rate")

				# Remove the space before the 'Hz'

				Q[RATE]=${val// /}
				;;

			"bits-per-sample")
				Q[BITS]=$val
				;;

			"title")
				TRACK[T_TITLE]=$val
				;;

			"artist")
				TRACK[T_ARTIST]=$val
				;;

			"album")
				TRACK[A_TITLE]=$val
				;;

			"tracknumber")
				TRACK[T_NO]=$val
				;;

			"genre")
				TRACK[GENRE]=$val
				;;

			"date")
				TRACK[A_YEAR]=$val
				;;

		esac

		# Make the bitrate element

		TRACK[BITRATE]="${Q[BITS]}-bit/${Q[RATE]}"

	done
}

function get_val_mp3
{
	# $1 is the key
	# $2 is the file
	
	typeset val
	
	val=$(id3info "$2" | grep $1)

	print -- ${val#*: }
}

function get_track_info_mp3
{
	# Populates global variable TRACK with an associative array of the track
	# information in an MP3

	typeset T_ARTIST GENRE F_ARTIST T_NO

	file=$1

	T_ARTIST=$(get_val_mp3 "TPE1" "$file")
	GENRE=$(get_val_mp3 "TRCON" "$file")
	F_ARTIST=$(mk_fname "$T_ARTIST")
	T_NO=$(get_val_mp3 "TRCK" "$file")

	# The following works for most files I've found
	
	TRACK=(
		[BITRATE]=$(get_bitrate_mp3 "$file")
		[T_TITLE]=$(get_val_mp3 "TIT2" "$file")
		[A_TITLE]=$(get_val_mp3 "TALB" "$file")
		[T_ARTIST]=$T_ARTIST
		[A_YEAR]=$(get_val_mp3 "TYER" "$file")
		[GENRE]=${GENRE:-Alternative}
		[T_NO]=${T_NO%/*}
		[F_ARTIST]=${F_ARTIST#the_}
	)

	# But some files (encoded by iTunes?) use different field names. I hate
	# hacks like this, but that's what you get when people don't stick to
	# standards

	[[ -z ${TRACK[T_ARTIST]} ]] \
		&& TRACK[T_ARTIST]=$(get_val_mp3 "TP1" "$file")

	[[ -z ${TRACK[A_TITLE]} ]] \
		&& TRACK[A_TITLE]=$(get_val_mp3 "TAL" "$file")

	[[ -z ${TRACK[T_TITLE]} ]] \
		&& TRACK[T_TITLE]=$(get_val_mp3 "TT2" "$file")

	[[ -z ${TRACK[A_YEAR]} ]] \
		&& TRACK[A_YEAR]=$(get_val_mp3 "TYE" "$file")

	[[ -z ${TRACK[T_NO]} ]] \
		&& TRACK[T_NO]=$(get_val_mp3 "TPA" "$file")

	# Track numbers are sometimes given as x/y

	[[ ${TRACK[T_NO]} == *"/"* ]] \
		&& TRACK[T_NO]=${TRACK[T_NO]%%/*}
}

transcode_flac()
{
	# Re-encode a FLAC to MP3. All the tag stuff has just been set in the
	# main(), so it's visible here. Kind of messy I know.  $1 is the file to
	# re-encode

	# $1 is the source file
	# Requires the TRACK variable is set

	if ! is_flac "$1" 
	then
		print "ERROR: $1 is not a FLAC"
		return 1
	fi

	OUT="$(qualify_path ${1%.*}).mp3"

	print -n "\n->$1\n<-${OUT##*/}\nencoding : "
	
	flac -dsc $1 | lame \
		-h \
		--vbr-new \
		--preset 128 \
		--silent \
		--tt "${TRACK[T_TITLE]}" \
		--ta "${TRACK[T_ARTIST]}" \
		--tl "${TRACK[A_TITLE]}" \
		--ty "${TRACK[A_YEAR]}" \
		--tn "${TRACK[T_NO]}" \
	- $OUT 2>/dev/null \
		&& print "ok" \
		|| print "FAILED"
	
}

function show_track_info
{
	# Display basic information on the given file

	# $1 is the file

	typeset fullpath

	get_track_info_$FILETYPE "$1"

	cat<<-EOINFO
	 Filename : $1
	     Type : $FILETYPE
	  Bitrate : ${TRACK[BITRATE]}
	   Artist : ${TRACK[T_ARTIST]}
	    Album : ${TRACK[A_TITLE]}
	    Title : ${TRACK[T_TITLE]}
	    Genre : ${TRACK[GENRE]}
	 Track no : ${TRACK[T_NO]}
	     Year : ${TRACK[A_YEAR]}

	EOINFO
}

function bump_track_no
{
	# Increment the track number by a specified amount

	# $1 is the file to work on
	# $2 is the number to add
	
	# We know $2 is valid, make sure the existing track number is

	typeset now=${TRACK[T_NO]}

	if is_int $now 
	then
		newval=$(( $now + $2 )) 
		print "${1##*/}\n  track number [${now}] -> $newval\n"
		set_val $FILETYPE "track" $newval $1
	else
		print "$now not valid"
	fi

}

function sort_files
{
	# Put loose files in a directory of the form artist.album

	typeset adir 

	if [[ ! -f "$1" ]]
	then
		print "skipping ${1##*/} (not a file)"
	else
		adir="$(mk_fname ${TRACK[T_ARTIST]}.${TRACK[A_TITLE]})"
		adir=${adir#the_}

		# If we didn't have properly tagged files, we'll not have a
		# directory name. (Well, it'll be ".".)

		if [[ $adir == '.' ]]
		then
			print "cannot get album name for '${1##*/}'"
			return
		fi

		adir="$(get_dir $1)/$adir"

		# Make the directory if it doesn't exist

		[[ -d $adir ]] \
			|| mkdir -p $adir

		# if we couldn't do that, issue a warning and continue

		if [[ ! -d $adir ]]
		then
			print "cannot create directory [${adir}]"
			return
		fi

		# Now move the file

		print -- "  $adir <-- $1"
		mv -i "$1" $adir
	fi

}

function verify_files
{
	# Verify FLACs. Can't verify MP3s, they suck.
	# $1 is the file to examine

	if [[ $FILETYPE == "flac" ]]
	then
		flac --test --totally-silent "$1" \
			&& output="ok" \
			|| output="FAILED"

		print "${1##*/}: $output"

	else
		print "can't verify files of type '${FILETYPE}'"
	fi

}

function get_dir
{
	# Some functions need to know what directory the files it's looking at
	# are in. This helps, by giving a directory if one hasn't been supplied.
	# $1 is the file 

	if [[ $1 == *"/"* ]]
	then
		qualify_path ${1%/*}
	else
		pwd
	fi

}

function name2tag
{
	# Work out artist, album and title information as best we can from a
	# filename.
	# $1 is the file

	typeset DIR file

	DIR=$(get_dir "$1")

	# Work out the album name from the directory name

	file=${1##*/}
	album=${DIR##*/}
	title=${file#*.}
	artist="$(mk_title ${file%%.*})"
	album="$(mk_title ${album#*.})"
	title="$(mk_title ${title%.*})"
	
	cat<<-EOINFO
	$file
	   album : $album
	  artist : $artist
	   title : $title

	EOINFO

	# We only have three things to change, so we'll call the set_val()
	# function three times. Inefficient, but it'll do for now.

	set_val $FILETYPE "artist" "$artist" "$1"
	set_val $FILETYPE "album" "$album" "$1"
	set_val $FILETYPE "title" "$title" "$1"
}

function tag2name
{
	# Rename a file according to its tag information. Pretty much the
	# opposite of name2tag (which you might expect)
	# $1 is the file

	typeset -l info artist title fname
	typeset DIR

	DIR=$(get_dir "$1")
	file=${1##*/}

	# This sets the TRACK variable

	get_track_info_$FILETYPE "$1"

	artist=${TRACK[T_ARTIST]}
	title=$(mk_fname ${TRACK[T_TITLE]})
	artist=$(mk_fname ${artist#the_})

	if [[ -n $artist && -n $title ]]
	then
		fname="${artist}.${title}.$FILETYPE"
		print "$1\n  -> ${fname}\n"
		mv -i "$1" "${DIR}/$fname"
	else
		print "ERROR: can't get information for ${1##*/}"
	fi

}

function set_value
{
	# Let the user set a single field in the metaflac/id3tag
	# $1 is the file
	# $2 is key=value string

	typeset -l key 
	typeset val

	val=${2#*=}
	key=${2%%=*}

	print "$1\n  $key -> ${val}\n"

	set_val $FILETYPE $key "$val" "$1"
}

function number
{
	# Set the track number from the number at the beginning of the filename
	# $1 is the file

	typeset -i t_num

	num=$(print $1 | sed 's/^\([0-9]\{1,\}\).*$/\1/')

	if [[ -n $num ]]
	then
		t_num=${num#0} 
		set_value "$1" "track=$t_num"
	fi
}

function notag_files
{
	# We already have track info in $TRACK, so study it

	if [[ $2 == "track" ]]
	then
		tag="tracknumber"
	elif [[ $2 == "year" ]]
	then
		tag="date"
	else
		tag=$2
	fi

	get_


	if [[ -z ${TRACK[$key]}  ]]
	then
		EXIT=1
		print "${1}:no $2 information"
	elif [[ ${#a} -gt 100 ]]
	then
		EXIT=1
		print "${1}:unusually long $2"
	fi

}

function inumber_files
{
	# $1 is the filename

	read num?"track number for '$1'> "

	[[ -n $num ]] && set_value "$1" "track=$num"
}
