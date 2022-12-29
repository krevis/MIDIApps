/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class PlayController: NSObject {

    init(mainWindowController: MainWindowController, midiController: MIDIController) {
        self.mainWindowController = mainWindowController
        self.midiController = midiController

        super.init()

        guard Bundle.main.loadNibNamed("Play", owner: self, topLevelObjects: &topLevelObjects) else { fatalError("Couldn't load nib") }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: API for main window controller

    func playMessages(_ messages: [SystemExclusiveMessage]) {
        guard let midiController else { return }

        observeMIDIController()

        midiController.messages = messages
        midiController.sendMessages()
        // This may send the messages immediately; if it does, it will post a notification and our sendFinishedImmediately() will be called.
        // Otherwise, we expect a different notification so that sendWillStart() will be called.
    }

    func playMessages(inEntryForProgramChange entry: LibraryEntry) {
        if !transmitting {
            // Normal case. Nothing is being transmitted, so just remember the current
            // entry and play the messages in it.
            currentEntry = entry
            playMessages(entry.messages)
        }
        else {
            // something is being transmitted already...
            if currentEntry != entry {
                // and the program change is asking to send a different entry than the one currently sending.
                // Queue up this entry to be sent later.
                queuedEntry = entry

                // and maybe cancel the current send.
                if UserDefaults.standard.bool(forKey: MIDIController.interruptOnProgramChangePreferenceKey) {
                    midiController?.cancelSendingMessages()
                }
            }
        }
    }

    // MARK: Actions

    @IBAction func cancelPlaying(_ sender: Any?) {
        midiController?.cancelSendingMessages()
        // The notification MIDIController.sendFinished will get posted soon;
        // it will call our sendFinished() and thus end the sheet
    }

    // MARK: Private

    private weak var mainWindowController: MainWindowController?
    private weak var midiController: MIDIController?

    private var topLevelObjects: NSArray?
    @IBOutlet private var sheetWindow: NSPanel!
    @IBOutlet private var progressIndicator: NSProgressIndicator!
    @IBOutlet private var progressMessageField: NSTextField!
    @IBOutlet private var progressBytesField: NSTextField!

    private var currentEntry: LibraryEntry? {
        didSet {
            if let newCurrentEntry = currentEntry {
                mainWindowController?.selectedEntries = [newCurrentEntry]
            }
        }
    }

    private var queuedEntry: LibraryEntry?

    private var transmitting = false
    private var scheduledProgressUpdate = false

}

extension PlayController /* Private */ {

    private func observeMIDIController() {
        guard let midiController else { return }
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.sendWillStart(_:)), name: .sendWillStart, object: midiController)
        center.addObserver(self, selector: #selector(self.sendFinished(_:)), name: .sendFinished, object: midiController)
        center.addObserver(self, selector: #selector(self.sendFinishedImmediately(_:)), name: .sendFinishedImmediately, object: midiController)
    }

    private func stopObservingMIDIController() {
        guard let midiController else { return }
        let center = NotificationCenter.default
        center.removeObserver(self, name: .sendWillStart, object: midiController)
        center.removeObserver(self, name: .sendFinished, object: midiController)
        center.removeObserver(self, name: .sendFinishedImmediately, object: midiController)
    }

    @objc private func sendWillStart(_ notification: Notification?) {
        transmitting = true

        progressIndicator.minValue = 0.0
        progressIndicator.doubleValue = 0.0

        if let status = midiController?.messageSendStatus {
            progressIndicator.maxValue = Double(status.bytesToSend)
        }

        updateProgressAndRepeat()

        if let window = mainWindowController?.window,
           window.attachedSheet == nil {
            window.beginSheet(sheetWindow, completionHandler: nil)
        }
    }

    @objc private func sendFinished(_ notification: Notification?) {
        let success = (notification?.userInfo?["success"] as? NSNumber)?.boolValue ?? true

        // If there is a delayed update pending, cancel it and do the update now.
        if scheduledProgressUpdate {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.updateProgressAndRepeat), object: nil)
            scheduledProgressUpdate = false
            updateProgress()
        }

        if !success {
            progressMessageField.stringValue = NSLocalizedString("Cancelled.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Cancelled.")
        }

        stopObservingMIDIController()

        transmitting = false

        // Maybe there's a queued entry that needs sending...
        if let queuedEntry, currentEntry != queuedEntry {
            let messages = queuedEntry.messages

            // yes, move the queued entry to be current
            self.currentEntry = queuedEntry
            self.queuedEntry = nil

            // then send it
            DispatchQueue.main.async {
                self.playMessages(messages)
            }
        }
        else {
            self.currentEntry = nil
            self.queuedEntry = nil

            // Even if we have set the progress indicator to its maximum value, it won't get drawn on the screen that way immediately,
            // probably because it tries to smoothly animate to that state. The only way I have found to show the maximum value is to just
            // wait a little while for the animation to finish. This looks nice, too.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.mainWindowController?.window?.endSheet(self.sheetWindow)
            }
        }
    }

    @objc private func sendFinishedImmediately(_ notification: Notification) {
        // Pop up the sheet and immediately dismiss it, so the user knows that something happehed.
        sendWillStart(nil)
        sendFinished(nil)
    }

    @objc private func updateProgressAndRepeat() {
        updateProgress()

        self.perform(#selector(self.updateProgressAndRepeat), with: nil, afterDelay: 5.0/60.0)
        scheduledProgressUpdate = true
    }

    static private var sendingFormatString = NSLocalizedString("Sending message %u of %u…", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format for progress message when sending multiple sysex messages")
    static private var sendingString = NSLocalizedString("Sending message…", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format for progress message when sending multiple sysex messages")
    static private var doneString = NSLocalizedString("Done.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Done.")

    private func updateProgress() {
        guard let sendStatus = midiController?.messageSendStatus else { return }

        progressIndicator.doubleValue = Double(sendStatus.bytesSent)
        progressBytesField.stringValue = String.abbreviatedByteCount(sendStatus.bytesSent)

        let message: String
        if sendStatus.bytesSent < sendStatus.bytesToSend {
            if sendStatus.messageCount > 1 {
                message = String(format: Self.sendingFormatString, sendStatus.messageIndex + 1, sendStatus.messageCount)
            }
            else {
                message = Self.sendingString
            }
        }
        else {
            message = Self.doneString
        }
        progressMessageField.stringValue = message
    }

}
