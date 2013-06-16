# audio-tools

Scripts to create, manage, and manipulate libraries of FLAC and MP3
files. I wrote these because I needed them, and it was more fun to do it
myself than to simply use someone else's things. They're pretty
full-featured, and I find them useful on a regular basis. They're
definitely geared towards the anally-retentive FLAC user.

# Requirements

To use these scripts fully you must have
[flac](http://flac.sourceforge.net/),
[LAME](http://lame.sourceforge.net/), and
[cdrecord](http://cdrecord.berlios.de/private/cdrecord.html). Any
reasonably recent version should be fine.

The scripts were written on Solaris, and some of them need ksh93.

## `aud.sh`

This is the main script. It's a bit of a "swiss-army knife" job, with
several commands. You can use it to manipulate FLAC, WAV, and MP3 files.
Unless otherwise stated, commands work for both FLAC and MP3.

### Usage
 
    aud.sh <command> <files>

The following commands are available.

 * `artist=str`: set artist/band name tag to `str`. Usually, you'll want to
   quote this. None of the `tag=str` commands work on WAV files, as
   proper WAVs don't support tagging.
 * `title=str`: set track title tag to `str`
 * `album=str`: set album title tag to `str`
 * `track=str`: set track number tag to `str`
 * `genre=str`: set genre tag to text string `str`
 * `year=str`: set year tag to text string `str`
 * `name2tag`: tag the file from the filename. Assumes the format of the
   filename is `artist.title`. Words like "the", "in" and so-forth will
   not be capitalized.
 * `tag2name`: rename a file from the ID3/FLAC tag in the format
   `artist.title.extension`.  If the artist name begins with "The", the
   leading `the_` will be removed from the filename.
 * `bump=n`: increase track number by `n`. Useful for merging
   multi-disc albums into a single directory.
 * `sort`: put loose files in album-specific directories. The format of
   the directory name will be `artist.title`. Doesn't work very well on
   compilation albums!
 * `transcode`: convert FLAC files to MP3, preserving tags. MP3s are put
   in the current working directory. The MP3s are 128kbit VBRs. Requires
   LAME.
 * `toflac`: convert WAV files to FLACs. Requires `flac`.
 * `number`: number tracks, assuming the filename begins with the track
   number.
 * `inumber`: number tracks interactively. You will be prompted for the
   track number of each file.
 * `info`: show track information.
 * `verify`: verify files -- only works for FLACs.
 * `notag=str`: Tells you if the file does not have a value for the
   `str` tag.
 * `help`: print usage info.

## `audio_functions.ksh`

A library of functions used by other scripts.

## `flac_covers.sh`

My standard is to have a file called `front.jpg` in the album directory.
This script invoked with the `-m` option, tells you which directories do
not contain that file. Run with no options, it renames any JPG or PNG
files it finds to `front.jpg` or `front.png`.

## `flac_find_24-bit.sh`

Uses `aud.sh` to find hi-rez audio files, and links them to a directory.
Can you hear the difference? I'm not sure I can.

## flac_missing_tags.sh

Supply a directory, and it will dig through that directory with
`find(1)`, look at every FLAC it finds with `aud.sh`, and report back if
any of the tags which `aud.sh info` displays are blank. Only use this if
you are a bit OCD.

## `rip_cd.sh`

A wrapper to `cdrecord`. Accepts the following options:

 * `-d`: CD-ROM device in `x,y,z` format
 * `-m`: rip to MP3
 * `-f`: rip to FLAC (both `-m` and `-f` are allowed. by default it will
   do both anyway.)
 * `-t`: tracks to rip. Comma separated list of numbers.
 * `-u`: force use of CD-TEXT for track names rather than trying to use
   CDDB. If if can't find any CD-TEXT, it will prompt for names.

## `get_flac_artwork.php`

A very rough-and-ready PHP script which tries to pull artwork down from
Amazon and Google Image Search. It does a reasonable job, but I'm sure
there are far smarter alternatives out there.

# License

All this junk is in the public domain. No license, help yourself, don't
blame me if it trashes your system.

