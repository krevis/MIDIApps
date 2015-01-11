//
//  AppDelegate.swift
//  SwiftApp
//
//  Created by Kurt Revis on 1/11/15.
//  Copyright (c) 2015 Kurt Revis. All rights reserved.
//

import Cocoa
import SnoizeMIDI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SMMessageDestination {

    @IBOutlet weak var window: NSWindow!

    var inputStream: SMPortInputStream!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application

        // Make a CoreMIDI client via SnoizeMIDI
        var client: SMClient? = SMClient.sharedClient();
        println("SMClient is \(client)")

        // Make a SnoizeMIDI input stream
        inputStream = SMPortInputStream()
        // that calls our takeMIDIMessages() method
        inputStream.setMessageDestination(self)
        // and listens to all currently available input sources
        inputStream.setSelectedInputSources(NSSet(array: inputStream.inputSources()))
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func takeMIDIMessages(messages: [AnyObject]!) {
        // Print each message as it is received
        for message in messages {
            println("Received MIDI message \(message.typeForDisplay())");
        }
    }
}

