/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class RecordManyController: RecordController {

    // MARK: RecordController subclass

    override var nibName: String {
        "RecordMany"
    }

    override func tellMIDIControllerToStartRecording() {
        midiController?.listenForMultipleMessages()
    }

    override func updateIndicators(status: MIDIController.MessageListenStatus) {
        if status.bytesRead == 0 {
            progressMessageField.stringValue = waitingForSysexMessage
            progressBytesField.stringValue = ""
        }
        else {
            progressMessageField.stringValue = receivingSysexMessage
            progressBytesField.stringValue = String.abbreviatedByteCount(status.bytesRead)
        }

        let hasAtLeastOneCompleteMessage = status.messageCount > 0
        if hasAtLeastOneCompleteMessage {
            let format = status.messageCount > 1 ? Self.totalProgressPluralFormatString : Self.totalProgressFormatString
            totalProgressField.stringValue = String(format: format, status.messageCount, String.abbreviatedByteCount(status.totalBytesRead))
            doneButton.isEnabled = true
        }
        else {
            totalProgressField.stringValue = ""
            doneButton.isEnabled = false
        }
    }

    // MARK: Actions

    @IBAction func doneRecording(_ sender: Any?) {
        midiController?.doneWithMultipleMessageListen()
        stopObservingMIDIController()

        progressIndicator.stopAnimation(nil)

        mainWindowController?.window?.endSheet(sheetWindow)

        mainWindowController?.addReadMessagesToLibrary()
    }

    // MARK: Private

    @IBOutlet private var totalProgressField: NSTextField!
    @IBOutlet private var doneButton: NSButton!

    static private var totalProgressFormatString = NSLocalizedString("Total: %d message, %@", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format of progress message when receiving multiple sysex messages (one message so far)")
    static private var totalProgressPluralFormatString = NSLocalizedString("Total: %d messages, %@", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format of progress message when receiving multiple sysex messages (more than one message so far)")

}
