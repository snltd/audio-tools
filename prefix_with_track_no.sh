#!/bin/ksh

# Stick the track number at the start of the filename

typeset -Z2 ot_no

find . -name \*.flac -o -name \*.mp3 | while read f
do
    t_no=$(aud.sh info "$f" | sed -n '/Track no : /s/^.* : 0*//p')

    if [[ -z $t_no ]]
    then
        print -u2 "WARNING: no track no for '$f'"

        if [[ ${f##*.} == "mp3" ]]
        then
            eyeD3 --to-v1.1 $f >/dev/null
            t_no=$(aud.sh info "$f" | sed -n '/Track no : /s/^.* : 0*//p')
        else
            continue
        fi
    fi

    [[ -z $t_no ]] && continue

    t_no=${t_no%/*}

    if ! print "$t_no" | grep -q "^[0-9]*$"
    then
        print -u2 "WARNING: invalid track no for '$f'"
        continue
    fi

    ot_no=$t_no

    if [[ ${f##*/} != ${ot_no}* ]]
    then
        basename=${f##*/}
        basename=${basename#[0-9][0-9].}
        mv "$f" "${f%/*}/${ot_no}.${basename}"
    fi
done
