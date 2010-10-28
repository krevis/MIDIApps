## What is this? ##

[MIDI Monitor](http://www.snoize.com/MIDIMonitor/) is a Mac OS X application for monitoring MIDI data as it goes in and out of the computer.

[SysEx Librarian](http://www.snoize.com/SysExLibrarian/) is a Mac OS X application for sending and receiving MIDI system exclusive (aka sysex) messages.

This is the source code for the two applications. You do *not* need any of this if you just want to use the apps. You need the source if you want to play with the code, customize the application, or use parts of the code in your own project.

The source code is Open Source under the BSD license. See LICENSE for the legal details.


## How to build ##

1. Install the Mac OS X 10.4 SDK, if you don't already have it in /Developer/SDKs.

   The 10.4 SDK is an optional part of the Xcode install. To install it, just re-run the Xcode installer and check the box for the 10.4 SDK.

2. Open Applications/MIDIMonitor/MIDIMonitor.xcodeproj or Applications/SysExLibrarian/SysExLibrarian.xcodeproj with Xcode.
3. Build and run!

The projects enclosed are for Xcode 3.2 and later. (You may be able to use the projects in earlier versions of Xcode, but no guarantees.)

For final builds: The shell scripts in Scripts/BuildMIDIMonitor and Scripts/BuildSysExLibrarian build the apps and package them in disk images. If you just run the script, you should end up with a MIDIMonitorBuild or SysExLibrarianBuild directory in your home directory, with an "InstalledProducts" directory inside containing the built application.


## What's inside ##

Your source tree should look like this:

* Applications
	* MIDIMonitor
	* SysExLibrarian
* Configurations
* Frameworks
	* SnoizeMIDI
	* SnoizeMIDISpy
	* DisclosableView
* Scripts

### Applications/MIDIMonitor Applications/SysExLibrarian ###

The source for the two apps. The project files are MIDIMonitor.xcodeproj and SysExLibrarian.xcodeproj; open them with Xcode.

Both apps are Cocoa and are written in Objective-C.

The apps rely on the other frameworks, described below.


### Frameworks/SnoizeMIDI ###

A framework containing code for dealing with CoreMIDI in a Cocoa app:

* Finding MIDI devices, sources, and destinations
* Creating "streams" of input and output data
* Hooking them up to inputs and outputs
* Parsing incoming MIDI data into separate messages

This framework is used by both apps. You can use it in your own apps as well.

The code is mainly Objective-C, with one ordinary C file.


### Frameworks/SnoizeMIDISpy ###

This project builds two things: A CoreMIDI driver, and a framework.

The CoreMIDI driver can "spy" on the MIDI sent to any destination in the system by any app.  (See the MIDIDriverEnableMonitoring() function in CoreMIDIServer/MIDIDriver.h for more details.)  The driver can then pass the MIDI data to another application.

The framework is used by apps that want to spy. It manages the communication between the app and the driver, and provides the app with an easy way to install the CoreMIDI driver when necessary.

This code is currently only used by MIDI Monitor, but it could be useful in other contexts. MIDI Monitor contains some code to channel the "spy" MIDI data into the rest of the SnoizeMIDI stream system, so it acts just like any other MIDI source.

The driver is written in C++, and the framework is plain C code.  You should be able to easily use the code from a Cocoa or Carbon application


### Frameworks/DisclosableView ###
	
A framework containing a Cocoa "disclosable" view -- one that can be shown and hidden by the user on demand.


### Configurations ###

Contains .xcconfig files used to coordinate build settings across all the Xcode projects.


### Scripts ###

Contains scripts to build the final ("install") version of the apps.


## Questions? ##

Please contact Kurt Revis <krevis@snoize.com> with any questions.
