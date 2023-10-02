## What is this? ##

[MIDI Monitor](http://www.snoize.com/MIDIMonitor/) is a Mac OS X application for monitoring MIDI data as it goes in and out of the computer.

[SysEx Librarian](http://www.snoize.com/SysExLibrarian/) is a Mac OS X application for sending and receiving MIDI system exclusive (aka sysex) messages.

This is the source code for the two applications. You do *not* need any of this if you just want to use the apps. You need the source if you want to play with the code, customize the application, or use parts of the code in your own project.

The source code is Open Source under the BSD license. See LICENSE for the legal details.

The project is currently intended to be used with an up-to-date Xcode version, like Xcode 15.0 (with the MacOS 14.0 SDK).  If you need to run it on an earlier Xcode, try checking out older revisions.

## How to build ##

1. `git submodule update --init --recursive` 
2. Open `MIDIApps.xcworkspace` with Xcode.
3. Open `Configurations/Snoize-Signing.xcconfig` and change `DEVELOPMENT_TEAM` to the Team ID of your Apple Developer account. See the file for more details.
4. In the "Scheme" popup menu in the toolbar, select either MIDI Monitor or SysEx Librarian.
5. Build and run!


## What's inside ##

Your source tree should look like this:

* Applications
	* MIDIMonitor
	* SysExLibrarian
* Configurations
* Frameworks
	* SnoizeMIDI
	* SnoizeMIDISpy
* Third Party
    * HexFiend
* Updates

### Applications/MIDIMonitor Applications/SysExLibrarian ###

The source for the two apps. The project files are MIDIMonitor.xcodeproj and SysExLibrarian.xcodeproj; open them with Xcode.

Both apps are Cocoa, and are written in Swift.

The apps rely on the other frameworks, described below.


### Frameworks/SnoizeMIDI ###

A framework containing code for dealing with CoreMIDI in a Cocoa app:

* Finding MIDI devices, sources, and destinations
* Creating "streams" of input and output data
* Hooking them up to inputs and outputs
* Parsing incoming MIDI data into separate messages

This framework is used by both apps. You can use it in your own apps as well.


### Frameworks/SnoizeMIDISpy ###

This project builds two things: A CoreMIDI driver, and a framework.

The CoreMIDI driver can "spy" on the MIDI sent to any destination in the system by any app.  (See the MIDIDriverEnableMonitoring() function in CoreMIDIServer/MIDIDriver.h for more details.)  The driver can then pass the MIDI data to another application.

The framework is used by apps that want to spy. It manages the communication between the app and the driver, and provides the app with an easy way to install the CoreMIDI driver when necessary.

This code is currently only used by MIDI Monitor, but it could be useful in other contexts. MIDI Monitor contains some code to channel the "spy" MIDI data into the rest of the SnoizeMIDI stream system, so it acts just like any other MIDI source.

The driver is written in C++, and the framework is C and Objective-C. You should be able to easily use the code from an application.

### Configurations ###

Contains .xcconfig files used to coordinate build settings across all the Xcode projects.

### Third Party ###

Contains the git submodule for HexFiend, which we use to display hex dumps in various views.

If you don't see the HexFiend submodule, do `git submodule update --init --recursive`.

### Updates ###

Contains the server-side files used to make app updates work (via Sparkle). You don't need to touch these. 

Note that the app targets use Sparkle as a package dependency via Swift Package Manager. Xcode should automatically get the package for you.

## Questions? ##

Please contact Kurt Revis <krevis@snoize.com> with any questions.
