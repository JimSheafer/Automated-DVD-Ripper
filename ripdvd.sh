#!/bin/bash
# Rip a DVD

#####################################################################
# Die
#####################################################################
die () { printf '%b %s %b \n' "$RED" "$*" "$WHITE" 1>&2; exit 1; }

#####################################################################
# Vars/Consts
#####################################################################
DATE=$(which date)           || die "Can't find 'date' command"
LSDVD=$(which lsdvd)         || die "Can't find 'lsdvd' command"
SETCD=$(which setcd)         || die "Can't find 'setcd' command"
CLEAR=$(which clear)         || die "Can't find 'clear' command"
RIPPER=$(which HandBrakeCLI) || die "Can't find HandBreakCLI command"
PRESET_FILE="/home/sheaf/Documents/Plex.json"
PRESET_NAME="Plex"
DVD_DEV="/dev/dvd"
OUTPUT_DIR="/mnt/Plex/Media/Movies/"

#####################################################################
# Initialize
#####################################################################
TitleName="---"
StartTime="---"
EndTime="---"
TitleNumber="---"
Status="---"

#####################################################################
# Colors
#####################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'

#####################################################################
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
# Title
#####################################################################
output_title () { 
  $CLEAR
  printf '%b-----------------------------------------------------------------------------------------\n' "$CYAN"
  printf '%b  The Automated DVD Ripper \n' "$BLUE"
  printf '%b-----------------------------------------------------------------------------------------\n' "$CYAN"
  printf '     %b Title Number:%b %-43s %b Started:%b  %-8s \n' "$GREEN" "$WHITE" "$TitleNumber" "$GREEN" "$WHITE" "$StartTime"
  printf '     %b Title Name:  %b %-43s %b Finished:%b %-8s \n' "$GREEN" "$WHITE" "$TitleName" "$GREEN" "$WHITE" "$EndTime"
  printf '     %b Saved As:    %b %-43s \n\n' "$GREEN" "$WHITE" "$OUTPUT_DIR$TitleName.m4v"
  printf '     %b Status:      %b %-43s \n' "$GREEN" "$RED" "$Status"
  printf '%b-----------------------------------------------------------------------------------------\n' "$CYAN"
  printf '%b' "$WHITE"
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
      cdinfo=$($LSDVD -s) || ""
      TitleName=$(echo "$cdinfo" | awk -F": " '/Disc Title/ {print $2}')
      TitleNumber=$(echo "$cdinfo" | awk -F": " '/Longest track/ {print $2}')
      StartTime=$($DATE +"%T")
			EndTime="---"
      Status="Ripping..."
    	output_title
      $RIPPER --preset-import-file "$PRESET_FILE" -Z "$PRESET_NAME" -i "$DVD_DEV" -t "$TitleNumber" -o "$OUTPUT_DIR$TitleName.m4v" 2> /dev/null
			EndTime=$($DATE +"%T")
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
      printf "Confused by setcd -i, bailing out:\n%s\n" "$cdinfo" >&2
      exit 1
  esac
done
echo 

# End
