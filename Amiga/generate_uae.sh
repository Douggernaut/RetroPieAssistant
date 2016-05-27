#!/bin/bash

ROM_FOLDER="/home/pi/RetroPie/roms/amiga"
ZIP_FOLDER="zip_files"

SCRIPT_DIR="${0%/*}"
MULTIDISK_FILE="$SCRIPT_DIR/multidisk.cfg"
TEMPLATE_FILE="$SCRIPT_DIR/template.uae"

function print {
  if [[ ! $quiet = "true" ]]; then
    echo "$1" >&2
  fi
}

function print_help {
  print "This script creates .uae configuration files for amiga .adf disk ROMS."
  print "The output files are meant to be used to display individual games in the EmulationStation Amiga list."
  print "If you want to change how this script searches for multi-disk games, please edit this file:"
  print "  $MULTIDISK_FILE"
  print "Usage:"
  print "$0 [OPTIONS]"
  print "  -f : overwrite .uae files"
  print "  -h : this help menu"
  print "  -q : quiet output"
  print "  -v : enable verbose printing"
  print "  -z : unzip .zip files in rom directory"
}

function qprint {
  if [[ $quiet = "true" ]]; then
    if [[ $2 ]]; then
      echo -n "$1" >&2
    else
      echo "$1" >&2
    fi
  fi
}

function vprint {
  if [[ $verbose = "true" ]]; then
    print "$1"
  fi
}

function get_multidisk_strings {
  multidisk_str=""
  while IFS= read -r line; do
    if [[ ! $line = \#* ]]; then
      vprint "$line"
      if [[ ! -z $multidisk_str ]]; then multidisk_str="$multidisk_str|"; fi
      multidisk_str="$multidisk_str$line"
    fi
  done < $1
  echo "$multidisk_str"
}

function init_config {
  configfile=$1
  vprint "Initializing $configfile..."
  for i in `seq 0 3`; do
    sed -i '/floppy'"$i"'=/{s/=.*/=/}' "$ROM_FOLDER/$uae_file"
  done
  sed -i '/nr_floppies=/{s/=.*/=/}' "$ROM_FOLDER/$uae_file"
}

while getopts ":fhqvz" opt; do
  case $opt in
    f)
      force=true
      ;;
    h)
      print_help
      exit 0
      ;;
    q)
      if [[ $verbose = "true" ]]; then
        print "-qv is incompatible"
      fi
      quiet=true
      ;;
    v)
      if [[ $quiet = "true" ]]; then
        print "-qv is incompatible"
      fi
      verbose=true
      ;;
    z)
      unzip=true
      ;;
    \?)
      print "Invalid option: -$OPTARG"
      exit 0
      ;;
    :)
      print "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done

set -e

vprint "Building multidisk format string from $MULTIDISK_FILE..."
multidisk_str=$(get_multidisk_strings $MULTIDISK_FILE)
vprint "Multidisk string:"
vprint "$multidisk_str"
vprint

lastgame=""
zero="false"

for fullpath in $ROM_FOLDER/*.{adf,adz,zip}; do
  filename="${fullpath##*/}"  # filename with extension
  basename="${filename%.*}"   # no extension
  extension="${filename##*.}" # just extension

  if [[ $filename =~ \*.* ]]; then
    continue
  fi

  print "Processing $filename"

  # ASSUMPTION - zip file contains an .adf or .adz file of the same name as the zip at its top level
  if [[ $extension = "zip" ]] && [[ $unzip = "true" ]]; then
    vprint "Unzipping $filename..."
    set +e
    ext="adf"
    unzip -n "$fullpath" "$basename.$ext" -d $ROM_FOLDER 2>/dev/null
    if [[ ! $? = 0 ]]; then
      ext="adz"
      unzip -n "$fullpath" "$basename.$ext" -d $ROM_FOLDER 2>/dev/null
    fi
    if [[ ! $? = 0 ]]; then
      print "WARNING: unzip of $filename failed. Check that the file has $basename.{adf,adz} at its top level."
      print "  Skipping $filename..."
      print
      set -e
      continue
    fi
    set -e
    mkdir -p $ROM_FOLDER/$ZIP_FOLDER
    vprint "Moving $filename to $ROM_FOLDER/$ZIPFOLDER"
    mv -n "$fullpath" "$ROM_FOLDER/$ZIP_FOLDER"
    filename="$basename.$ext"
    fullpath="$ROM_FOLDER/$filename"
    extension=$ext
  elif [[ $extension = "zip" ]]; then
    vprint "Skipping $filename because -z option not specified."
    vprint
    continue
  fi

  # use the multidisk config strings to pull out the game name and the disk identifier
  disk_identifier=""
  vprint "Running name detection on $filename"
  if [[ $basename =~ (.*)($multidisk_str) ]]; then
    game="${BASH_REMATCH[1]}"
    index=3
    while [[ -z $disk_identifier ]]; do
      disk_identifier="${BASH_REMATCH[$index]}"
      index=$((index+1))
    done
    vprint "  Detected [$game] disk $disk_identifier."
  else
    game=$basename
    vprint "  No matching disk numbers detected on the below file - it is single-disk or $MULTIDISK_FILE needs to be updated."
    vprint "    $filename"
  fi

  uae_file=$game.uae

  # make sure you don't want to lose all that hard work configuring things
  if [[ -f $ROM_FOLDER/$uae_file ]] && [[ ! $force = "true" ]] && [[ ! $game == $lastgame ]]; then
    print "$uae_file already exists. Use -f flag to force overwrites. Skipping $game."
    continue
  fi

  # create .uae file if it doesn't exist
  if [[ ! -f $ROM_FOLDER/$uae_file ]]; then
    vprint "Creating $uae_file..."
    cp "$TEMPLATE_FILE" "$ROM_FOLDER/$uae_file"
  else
    vprint "Updating $uae_file..."
  fi

  # game files are sorted lexicographically and not in ascending numerical order
  # i.e. 1 10 11 2 3 4 5 6 7 8 9
  # i.e. A AA B C D ... Z
  # also disks may start numbered 0 or 1.
  # so we have to deal with the cases in which our disks are out of order.
  if [[ ! $game == $lastgame ]]; then
    zero="false"
    alpha="false"
    count=1
    qprint ""
    qprint "$game ..." n
  fi

  case $disk_identifier in
    "A")
      init_config "$ROM_FOLDER/$uae_file"
      alpha="true"
      ;;
    "0")
      init_config "$ROM_FOLDER/$uae_file"
      zero="true"
      ;;
    "1")
      if [[ ! $game == $lastgame ]]; then
        init_config "$ROM_FOLDER/$uae_file"
      else
        count=$((count+1))
      fi
      ;;
    "")
      disk_identifier="1"
      init_config "$ROM_FOLDER/$uae_file"
      ;;
    *)
      count=$((count+1))
      ;;
  esac

  # put the filename into its disk number
  escaped_fullpath=${fullpath//\//\\\/}
  if [[ $alpha = "false" ]] && [[ $zero = "true" ]]; then
    vprint "Updating drive floppy$disk_identifier to point to $fullpath."
    sed -i '/floppy'"$disk_identifier"'=/{s/=.*/='"$escaped_fullpath"'/}' "$ROM_FOLDER/$uae_file"
  elif [[ $alpha = "false" ]]; then
    vprint "Updating drive floppy$((disk_identifier-1)) to point to $fullpath.."
    sed -i '/floppy'"$((disk_identifier-1))"'=/{s/=.*/='"$escaped_fullpath"'/}' "$ROM_FOLDER/$uae_file"
  else
    case $disk_identifier in
      "A") drive_number=0 ;;
      "B") drive_number=1 ;;
      "C") drive_number=2 ;;
      "D") drive_number=3 ;;
      *) drive_number=5 ;;
    esac
    vprint "Updating drive floppy$drive_number to point to $fullpath..."
    sed -i '/floppy'"$drive_number"'=/{s/=.*/='"$escaped_fullpath"'/}' "$ROM_FOLDER/$uae_file"
  fi

  # replace nr_floppies with the disk number
  # ASSUMPTION - files will be processed in ascending order
  vprint "Updating nr_floppies to $count..."
  sed -i '/nr_floppies=/{s/=.*/='"$count"'/}' "$ROM_FOLDER/$uae_file"
  vprint

  # update last game for counting purposes
  lastgame=$game
  qprint " $disk_identifier" n
done

if [[ $unzip = "true" ]] && [[ -d $ROM_FOLDER/$ZIP_FOLDER ]]; then
  print "NOTE: Successfully processed zip files are stored in $ROM_FOLDER/$ZIP_FOLDER because -z option was set."
fi

print "Done!"
qprint ""
