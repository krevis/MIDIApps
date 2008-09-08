*
* WHAT IS THIS?
*

SysEx Librarian is a Mac OS X application for sending and receiving MIDI system exclusive (aka sysex) messages.

This is the source code for the entire application.  You do NOT need any of this if you just want to use the application.  You only need the source if you want to play with the code, customize the application, or use parts of the code in your own project.

The source code is released as Open Source code, under the BSD license.  See the LICENSE file for the legal details.

The latest version of the code should be available here:
http://www.snoize.com/SysExLibrarian/Source/


*
* WHAT'S INCLUDED
*

Everything you need to build SysEx Librarian is here.  You should have a source tree that looks like this:

SysEx Librarian Source
	Applications
		SysExLibrarian
	Configurations
	Frameworks
		SnoizeMIDI
	Scripts


In decreasing order of importance:

* Applications/SysExLibrarian

	The source to the application.  The project file is SysExLibrarian.xcodeproj; open this using Xcode.

	SysEx Librarian is a Cocoa application, written in Objective-C.

	The application relies on the other frameworks, described below.


* Frameworks/SnoizeMIDI

	A framework containing code for dealing with CoreMIDI in a Cocoa app:
		Creating a CoreMIDI client
		Finding MIDI devices, sources, and destinations
		Creating "streams" of input and output data, and hooking them up to inputs and outputs
		Parsing MIDI streams into separate MIDI messages
		Dealing with older versions of CoreMIDI (from 10.1 onwards)

	This framework is used by both SysEx Librarian and my other application, MIDI Monitor.  You should be able to use it in your own applications as well.

	The code is mainly Objective-C, with one ordinary C file.


* Configurations

	Contains .xcconfig files used to coordinate build settings across all the Xcode projects.


* Scripts

	Contains a script to build the final ("install") version of SysEx Librarian.


*
* HOW TO BUILD
*

The projects enclosed are for Xcode 3.1.  You may be able to use the projects in earlier versions of Xcode, but no guarantees.  (They are supposedly compatible back to Xcode 2.4.)

Everything is set up to build Universal.  Intel uses the 10.4 SDK and gcc 4.0.  PowerPC uses the 10.3.9 SDK and gcc 3.3.  (Note that 10.3.9 support is optional in Xcode 3; make sure you install it.)

IMPORTANT NOTE:  You *must* set a global build location in Xcode's preferences. If you don't, the app's project will not be able to find the frameworks after they are built.
In the Xcode preferences window, choose the "Building" section, change "Place Build Products in" to "Customized location", and pick a folder.

Once you do that, when you open the SysEx Librarian project and build it, it will automatically build everything you need.

For install builds: There is a shell script in Scripts/BuildSysExLibrarian which builds the whole app and takes care of some miscellaneous details.  If you just run the script, you should end up with a SysExLibrarianBuild directory in your home directory, with an "InstalledProducts" directory inside containing the built application.  If you want the built results to go elsewhere, feel free to change the script.


*
* QUESTIONS?
*

Kurt Revis <krevis@snoize.com> is the original author of this code.  Please contact him with any questions.

