#!/usr/local/bin/php

<?php
//============================================================================
// 
// get_flac_artwork.php
// --------------------
//
// A really, really, not remotely good script to get sleeve artwork from 
// Amazon via GIS. Took five minutes. It shows. Works reasonably well though.
//
// R Fisher 03/2012
//
//============================================================================

//----------------------------------------------------------------------------
// VARIABLES

$img_file = "front.jpg";

//----------------------------------------------------------------------------
// SCRIPT STARTS HERE

// Needs a directory as an argument

if (!$_SERVER["argv"][1])
	die("usage: " . $_SERVER["argv"][0] . " <dir>\n");

foreach($_SERVER["argv"] as $dir) {
	$out = array();

	if ($dir == $_SERVER["argv"][0])
		continue;

	if (!is_dir($dir)) {
		echo "ERROR: $dir is not a directory.\n\n";
		continue;
	}


	// Find the first FLAC in the directory, and get the artist and album
	// name from it

	$dh = dir($dir);

	echo "Directory: $dir\n";

	if (file_exists("${dir}/$img_file")) {
		echo "  file already exits.\n\n";
		continue;
	}

	while($file = $dh->read()) {

		if (preg_match("/\.flac$/", $file)) {
			echo "  using file $file\n";
			exec("metaflac --show-tag=artist --show-tag=album $dir/$file",
			$out, $ret);

			$out = preg_replace("/^\w+=/U", "", $out);

			// This makes an array with the artist name in [0] and album
			// name in [1]

			break;
		}

	}

	if (empty($out[0]) || empty($out[1])) {
		echo "ERROR: couldn't get FLAC metadata.\n\n";
		continue;
	}

	echo "  artist is '$out[0]'\n  album is '$out[1]'\n";

	$artist = urlencode($out[0]);
	$album = urlencode($out[1]);

	$rawfile =
	file("http://www.google.com/search?as_st=y&tbm=isch&hl=en&as_q=${artist}&as_epq=${album}&as_oq=&as_eq=&as_sitesearch=amazon.com&cr=&safe=off&btnG=Search+images&tbs=isz:m,iar:s");
	//"r");

	foreach($rawfile as $line) {

		if (preg_match("/Square/", $line)) {

			preg_match_all("/imgurl=(.+)\"/U", $line, $a);

			$src = preg_replace("/.jpg.*$/", ".jpg", $a[1][0]);

			if (!empty($src)) {
				echo "  copying file $src\n";
				
				if (copy($src, "${dir}/$img_file"))
					echo "  file copied\n";
				else
					echo "ERROR: file failed to copy.\n";
			}
			else 
				echo "  couldn't find a file\n";

			echo "\n";
		}

	}

}

?>
