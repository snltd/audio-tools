#!/bin/ksh

# Ensure the filename prefix is the real track number

find $(pwd) -type d | grep '\...' | while read dir
do
    cd $dir
    files=$(ls | grep -c '\.flac$')
    want=$(seq -s\  1 $files)
    got=$(aud.sh info *.flac | sed -n '/Track no :/s/^.* : 0*//p' | \
        sed 's|/[0-9]*$||' | sort -n | tr "\n" " ")

    if [[ "${want} " != "$got" ]]
    then
        print "ERROR in $dir"
        print "expected ${want}"
        print "   found ${got}"
    else
        print "OK: $dir"
    fi
done
