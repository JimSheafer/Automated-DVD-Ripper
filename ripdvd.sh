#!/bin/bash
# Rip a DVD

#####################################################################
# Constants
# Declare variables that will not change
#####################################################################
readonly DATE=$(which date)           || die "Can't find 'date' command"
readonly LSDVD=$(which lsdvd)         || die "Can't find 'lsdvd' command"
readonly SETCD=$(which setcd)         || die "Can't find 'setcd' command"
readonly CLEAR=$(which clear)         || die "Can't find 'clear' command"
readonly RIPPER=$(which HandBrakeCLI) || die "Can't find 'HandBreakCLI' command"
readonly SENDMAIL=$(which ssmtp)      || die "Can't find 'ssmtp' command"
readonly ADDRESS="$TXT"
readonly PRESET_FILE="/home/sheaf/Documents/Plex.json"
readonly PRESET_NAME="Plex"
readonly DVD_DEV="/dev/dvd"
readonly OUTPUT_DIR="/mnt/Plex/Media/Movies/"
readonly OUTPUT_FORMAT="m4v"

#####################################################################
# Initialize
# Initialize variables
#####################################################################
TitleName="---"
StartTime="---"
EndTime="---"
TitleNumber="---"
Status="---"

#####################################################################
# Colors
# Declare colors as constants
#####################################################################
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'

#####################################################################
# die ()
# Output a message and exit with an error
#####################################################################
die () { printf '%b %s %b \n' "$RED" "$@" "$WHITE" 1>&2; exit 1; }

#####################################################################
# notify ()
# Send notice via email
#####################################################################
notify() { 
	printf "%s\n" "$@" | "$SENDMAIL" "$ADDRESS" 
}

#####################################################################
# test_prereq ()
# Make sure we can find everything
#####################################################################
test_prereq () {
  [[ -x "$LSDVD" ]]       || die "Can't run $LSDVD; exiting!"
  [[ -x "$SETCD" ]]       || die "Can't run $SETCD; exiting!"
  [[ -x "$CLEAR" ]]       || die "Can't run $CLEAR; exiting!"
  [[ -x "$RIPPER" ]]      || die "Can't run $RIPPER; exiting!"
  [[ -r "$PRESET_FILE" ]] || die "Can't read $PRESET_FILE; exiting!"
  [[ -r "$DVD_DEV" ]]     || die "Can't read $DVD_DEV; exiting!"
  [[ -w "$OUTPUT_DIR" ]]  || die "Can't write $OUTPUT_DIR; exiting!"
}

#####################################################################
# title ()
# Clear the screen and output the title, making it look like we 
#   are updating just the fields instead of printing everything
#   over and over.
#####################################################################
output_title () { 
  $CLEAR
  # These next 3 are strange.
  #   First printf just sets the color
  #   Next line prints out 81 '=' by giving 81 parameters printed with a width of 0
  #   Last line gives us the newline
  printf '%b' "$CYAN"
  printf '=%.0s' {1..81}
  printf '\n'

  printf '%b  The Automated DVD Ripper \n' "$BLUE"

  printf '%b' "$CYAN"
  printf '=%.0s' {1..81}
  printf '\n'
  printf '%b  Title Number:%b %-43s %b Started:%b  %-8s \n' \
    "$GREEN" \
    "$WHITE" \
    "$TitleNumber" \
    "$GREEN" \
    "$WHITE" \
    "$StartTime"
  printf '%b  Title Name:  %b %-43s %b Finished:%b %-8s \n' \
    "$GREEN" \
    "$WHITE" \
    "$TitleName" \
    "$GREEN" \
    "$WHITE" \
    "$EndTime"
  printf '%b  Saved As:    %b %-43s \n\n' \
    "$GREEN" \
    "$WHITE" \
    "$OUTPUT_DIR$TitleName.$OUTPUT_FORMAT"
  printf '%b  Status:      %b %-43s \n' \
    "$GREEN" \
    "$RED" \
    "$Status"
  printf '%b' "$CYAN"
  printf '=%.0s' {1..81}
  printf '\n'
  printf '%b' "$WHITE"
}

#####################################################################
# get_dvd_info ()
# Use lsdvd to get DVD title and longest title number in the hope
#   that the longest title is the one that is the movie
#####################################################################
get_dvd_info () {
  # get a lot of info from lsdvd and save it in a var
  cdinfo=$($LSDVD -s) || ""

  # extract the title name from the line that looks like
  #   "Disc Title: <title>"
  TitleName=$(echo "$cdinfo" | awk -F": " '/Disc Title/ {print $2}')

  # extract the longest track number from the line that looks like
  #   "Longest track: <number>"
  TitleNumber=$(echo "$cdinfo" | awk -F": " '/Longest track/ {print $2}')
}

#####################################################################
# rip_it
# Rip and encode the DVD using HandBrake command line tool
#####################################################################
rip_it() {
  $RIPPER \
    --preset-import-file "$PRESET_FILE" \
    -Z "$PRESET_NAME" \
    -i "$DVD_DEV" \
    -t "$TitleNumber" \
    -o "$OUTPUT_DIR$TitleName.$OUTPUT_FORMAT" \
    2> /dev/null
}

#####################################################################
# Main
# Loop until a disk is inserted
#####################################################################

output_title
test_prereq

while true; do

  cdstatus=$($SETCD -i) 2> /dev/null

  case "$cdstatus" in
    *'Disc found'*)
      StartTime=$($DATE +"%T")
      EndTime="---"
      get_dvd_info
      Status="Ripping..."
      output_title
      rip_it
      EndTime=$($DATE +"%T")
      notify  "====================" "Encode Complete" "Title: $TitleName" \
        "Start: $StartTime" "End: $EndTime" "====================" 
      eject
    ;;
    *'not ready'*)
      Status="Waiting for drive to be ready..."
      output_title
      sleep 3;
    ;;
    *'is open'*)
      Status="Drive is open..."
      output_title
      sleep 10;
    ;;
    *)
      Status="ERROR"
      output_title
      die "Confused by setcd -i, bailing out:
      
      $cdinfo"
  esac
done

# End
