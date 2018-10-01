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

function qualify_path
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
    # Inverse of mk_fname(). Capitalises and add spaces. Doesn't do a
    # GREAT job, but near enough.
	# $* is the string to work on

    # The following words aren't capitalized unless they're the first or
    # last word in the title.

	NOCAPSLIST=" a aboard about above absent across after against along
    alongside amid amidst among amongst an and around as as aslant
    astride at athwart atop barring before behind below beneath beside
    besides between beyond but by despite down during except failing
    following for for from in is inside into like mid minus near next
    nor notwithstanding of off on onto opposite or out outside over past
    per plus regarding round save since so than the through throughout
    till times to toward towards under underneath unlike until up upon
    via vs when with within without worth yet "

    # The following word pairs get expanded from the former to the
    # latter. I think it's more likely that the title contains "can't"
    # or "won't" than "cant" or "wont". It's/its is more
    # difficult...

    EXPANDLIST=" dont=Don't youre=You're wont=Won't im=I'm cant=Can't
    thats=That's shes=She's &=and couldnt=Couldn't etc=Etc.
    theres=there's
    wouldnt=Wouldn't hes=He's youve=You've youll=You'll its=It's
    weve=We've"

	typeset -i i=1
	typeset -u initial

    words=$(print $* | tr _ "\n" | grep -c .)

	for word in $(print $* | tr _ ' ')
	do

		if [[ $i -gt 1 && $NOCAPSLIST == *" $word "* && $i != $words ]]
		then
			pr_word=$word
        else
			initial=${word:0:1}
			pr_word=${initial}${word:1}
		fi

        if [[ $EXPANDLIST == *" ${word}="* ]]
        then
            expand_to=${EXPANDLIST##* $word=}
            pr_word=${expand_to%% *}
        fi

        # In my filenames I replace an opening bracket with a dash. I
        # think the first parenthesised word should always be
        # capitalized

        if [[ $pr_word == *-* ]]
        then
            first_word=${pr_word%%-*}
            word="${pr_word#*-}"
			initial=${word:0:1}

            if [[ $EXPANDLIST == *" ${word}="* ]]
            then
                expand_to=${EXPANDLIST##* $word=}
                pr_word="${first_word} (${expand_to%% *}"
            else
			    pr_word="${first_word} (${initial}${word:1}"
            fi

            close_bracket=true
        fi

        print -n -- $pr_word

        [[ $i == $words ]] || print -n " "

		((i++))
	done

    [[ -n $close_bracket ]] && print ")" || print
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

function get_val_mp3
{
    # $1 is the key
    # $2 is the file

    typeset val

    val=$(id3info "$2" | grep $1)

    print -- ${val#*: }
}

function get_bitrate_mp3
{
    # $1 is the file

    mp3info "$1" | sed -n '/^Audio: /s/^Audio: *\([^,]*\).*/\1/p'
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

function get_track_info_wav
{
	return
}

function get_track_info_mp3
{
	# Populates global variable TRACK with an associative array of the track
	# information in an MP3

	typeset T_ARTIST GENRE F_ARTIST T_NO

	file=$1

    T_ARTIST=$(mp3info -p "%a" "$file")
    GENRE=$(mp3info -p "%g" "$file")
	F_ARTIST=$(mk_fname "$T_ARTIST")
	T_NO=$(mp3info -p "%n" "$file")

	# The following works for most files I've found

    mp3info -p "%r %y %t" "$file" | read bitrate year title

	TRACK=(
        [BITRATE]=$bitrate
        [T_TITLE]=$title
		[A_TITLE]=$(mp3info -p "%l" "$file")
		[T_ARTIST]=$T_ARTIST
		[A_YEAR]=$year
		[GENRE]=${GENRE:-Alternative}
		[T_NO]=${T_NO%/*}
		[F_ARTIST]=${F_ARTIST#the_}
	)

	# Track numbers are sometimes given as x/y

	[[ ${TRACK[T_NO]} == *"/"* ]] \
		&& TRACK[T_NO]=${TRACK[T_NO]%%/*}

    [[ -z $TRACK[T_ARTIST] ]] && get_track_info_mp3_retry $file
}

function get_track_info_mp3_retry
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

encode_mp3()
{
	# Encode a wav to mp3. All the tag stuff has just been set in the
	# main(), so it's visible here. Kind of messy I know.
	# $1 is the file to encode

	DEST_DIR="${MP3_DIR}/$TARGET_DIR"

	[[ -d $DEST_DIR ]] || mkdir -p "$DEST_DIR"

	OUTFILE="${DEST_DIR}/${F_ARTIST#the_}.$(mk_fname $T_TITLE).mp3"

	# Some albums have duplicate song names. Get around this by appending
	# t_$TRACK_NO

	[[ -f $OUTFILE ]] && OUTFILE="${OUTFILE%.*}_t_${T_NO}.mp3"

	print "  MP3 encoding ${T_ARTIST}/$T_TITLE"

	lame \
		--vbr-new \
		--preset standard \
		--silent \
		--tt "$T_TITLE" \
		--ta "$T_ARTIST" \
		--tl "$A_TITLE" \
		--ty "$A_YEAR" \
		--tn "$T_NO" \
	$1 $OUTFILE 2>/dev/null

}

encode_flac()
{
	# Encode a wav to FLAC. All the tag stuff has just been set in the
	# main(), so it's visible here. Kind of messy I know.
	# $1 is the file to encode

    typeset -Z2 t_no

	if [[ -n $FLAC_DIR ]]
	then
		DEST_DIR="${FLAC_DIR}/$TARGET_DIR"
	else
		DEST_DIR=${1%/*}

		[[ "$DEST_DIR" == "$1" ]] && DEST_DIR=$(pwd)
	fi

	[[ -d $DEST_DIR ]] || mkdir -p "$DEST_DIR"

    t_no=$T_NO

	if [[ -n $F_ARTIST ]]
	then
		OUTFILE="${DEST_DIR}/${t_no}.${F_ARTIST#the_}.$(mk_fname \
            $T_TITLE).flac"
	else
		OUTFILE="${1%.*}.flac"
	fi

	print "  encoding '$1'"

	flac \
		-s \
		--best \
		--force \
        --keep-foreign-metadata \
		-T "title=$T_TITLE" \
		-T "artist=$T_ARTIST" \
		-T "album=$A_TITLE" \
		-T "date=$A_YEAR" \
		-T "tracknumber=$T_NO" \
		-o "$OUTFILE" \
	"$1" 2>/dev/null

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
		set_val $FILETYPE "track" $newval "$1"
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

		[[ -d "$adir" ]] || mkdir -p "$adir"

		# if we couldn't do that, issue a warning and continue

		if [[ ! -d "$adir" ]]
		then
			print "cannot create directory [${adir}]"
			return
		fi

		# Now move the file

		print -- "  $adir <-- $1"
		mv -i "$1" "$adir"
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
    typeset -i t_no

	DIR=$(get_dir "$1")

	# Work out the album name from the directory name

	file=${1##*/}
    print $file | sed 's/\./ /g' | read t_no artist title suffix
    print $file | sed 's/\./ /g' | read t_no artist title suffix
	album=${DIR##*/}
	artist="$(mk_title $artist)"
	album="$(mk_title ${album#*.})"
	title="$(mk_title $title)"

	cat<<-EOINFO
	$file
	   album : $album
	  artist : $artist
	   title : $title
	   track : $t_no

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
    typeset -Z2 t_no

	DIR=$(get_dir "$1")
	file=${1##*/}

	# This sets the TRACK variable

	get_track_info_$FILETYPE "$1"

	artist=${TRACK[T_ARTIST]}
	title=$(mk_fname ${TRACK[T_TITLE]})
	artist=$(mk_fname ${artist#the_})
    t_no=${TRACK[T_NO]}

	if [[ -n $artist && -n $title ]]
	then
		fname="${artist}.${title}.$FILETYPE"
		print "$1\n  -> ${fname}\n"
        mv -i "$1" "${DIR}/${t_no}.$(print $fname | sed 's/^the_//')"
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

function strip_flac
{
    # Remove embedded images and tags which conflict with our standards.
    # Also remove padding to save a tiny amount of space. I also want
    # the modification time of the file to be unaffected.

    # $1 is the filename

    TFILE=$(mktemp)
    touch -r "$1" $TFILE

    print "stripping $1"

    if metaflac --list "$1" | egrep -s "ALBUM ARTIST|ALBUMARTIST|ENSEMBLE"
    then
        print "  moving extraneous tags"
        metaflac --remove-tag=ALBUMARTIST \
                --remove-tag="ALBUM ARTIST" \
                --remove-tag=ENSEMBLE "$1"
    fi

    if metaflac --list "$1" | egrep -s PICTURE
    then
        print "  removing PICTURE"
        metaflac --remove --block-type=PICTURE,PADDING --dont-use-padding "$1"
    fi

    touch -r $TFILE "$1"
    rm $TFILE
}

function numname
{
	# Prefix the filename with the track number

	typeset -Z2 t_no

	get_track_info_$FILETYPE "$1"
	t_no=${TRACK[T_NO]}

	if [[ -n $t_no ]]
	then
		print "$1 -> $t_no"
		mv "$1" "${t_no}.$1"
	fi
}

function split_flac
{
	cue=$(echo $1 | sed 's/flac$/cue/')
	shnsplit -f "$cue" -o flac -t "%n.%p.%t" "$1"

}
