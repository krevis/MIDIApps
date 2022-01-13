/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class RecordOneController: RecordController {

    // MARK: RecordController subclass

    override var nibName: String {
        "RecordOne"
    }

    override func tellMIDIControllerToStartRecording() {
        midiController?.listenForOneMessage()
    }

    override func updateIndicators(status: MIDIController.MessageListenStatus) {
        if status.bytesRead == 0 && status.messageCount == 0 {
            progressMessageField.stringValue = waitingForSysexMessage
            progressBytesField.stringValue = ""
        }
        else {
            progressMessageField.stringValue = receivingSysexMessage
            progressBytesField.stringValue = String.abbreviatedByteCount(status.bytesRead + status.totalBytesRead)
        }
    }

    override func observeMIDIController() {
        super.observeMIDIController()

        NotificationCenter.default.addObserver(self, selector: #selector(self.readFinished(_:)), name: .readFinished, object: midiController)
    }

    override func stopObservingMIDIController() {
        super.stopObservingMIDIController()

        NotificationCenter.default.removeObserver(self, name: .readFinished, object: midiController)
    }

    // MARK: Private

    @objc private func readFinished(_ notification: Notification) {
        // If there is an update pending, cancel it and do it now.
        updateIndicatorsImmediatelyIfScheduled()

        progressIndicator.stopAnimation(nil)

        stopObservingMIDIController()

        // Close the sheet, after a little bit of a delay (makes it look nicer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.mainWindowController?.window?.endSheet(self.sheetWindow)

            // Don't actually add the entry until after we've ended the sheet,
            // in case it needs to show its own sheet
            self.mainWindowController?.addReadMessagesToLibrary()
        }
    }

}
