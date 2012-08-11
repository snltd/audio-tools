#!/bin/ksh

# Really simple script to find 24-bit albums and symlink them into a common
# directory. Rough hack, even has hardcoded paths! Requires aud.sh

LINKDIR=/storage/flac/24-bit

rm -fr $LINKDIR

mkdir -p $LINKDIR

find /storage/flac/albums /storage/flac/eps -type d | while read d
do
	# See if the first file in there is 24-bit. If it is, assume everything
	# else is. Crude, but it'll do

	if aud.sh info $(ls $d/*flac 2>/dev/null | sed 1q) \
	| egrep -s "Bitrate : 24" 
	then
		print "$d is 24-bit"
		ln -s $d $LINKDIR
	fi
	
done
