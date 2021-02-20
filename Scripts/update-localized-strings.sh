#!/bin/sh -x
#
# Run this from the MIDIApps directory as "./Scripts/update-localized-strings.sh"

pushd Applications/MIDIMonitor	
genstrings *.swift -o en.lproj
popd

pushd Applications/SysExLibrarian
genstrings *.swift -o en.lproj
popd

pushd Frameworks/SnoizeMIDI
genstrings *.swift *.m -o en.lproj
popd
