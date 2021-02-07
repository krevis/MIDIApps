/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

@objc class RecordManyController: RecordController {

    // MARK: RecordController subclass

    override var nibName: String {
        "RecordMany"
    }

    override func tellMIDIControllerToStartRecording() {
        midiController?.listenForMultipleMessages()
    }

    override func updateIndicators(messageCount: Int, bytesRead: Int, totalBytesRead: Int) {
        if bytesRead == 0 {
            progressMessageField.stringValue = waitingForSysexMessage
            progressBytesField.stringValue = ""
        }
        else {
            progressMessageField.stringValue = receivingSysexMessage
            progressBytesField.stringValue = String.abbreviatedByteCount(bytesRead)
        }

        let hasAtLeastOneCompleteMessage = messageCount > 0
        if hasAtLeastOneCompleteMessage {
            let format = messageCount > 1 ? Self.totalProgressPluralFormatString : Self.totalProgressFormatString
            totalProgressField.stringValue = String(format: format, Int(messageCount), String.abbreviatedByteCount(Int(totalBytesRead)))
            doneButton.isEnabled = true
        }
        else {
            totalProgressField.stringValue = ""
            doneButton.isEnabled = false
        }
    }

    // MARK: Actions

    @IBAction func doneRecording(_ sender: AnyObject?) {
        midiController?.doneWithMultipleMessageListen()
        stopObservingMIDIController()

        progressIndicator.stopAnimation(nil)

        NSApp.endSheet(sheetWindow)

        mainWindowController?.addReadMessagesToLibrary()
    }

    // MARK: Private

    @IBOutlet private var totalProgressField: NSTextField!
    @IBOutlet private var doneButton: NSButton!

    static private var totalProgressFormatString = NSLocalizedString("Total: %d message, %@", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format of progress message when receiving multiple sysex messages (one message so far)")
    static private var totalProgressPluralFormatString = NSLocalizedString("Total: %d messages, %@", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format of progress message when receiving multiple sysex messages (more than one message so far)")

}
