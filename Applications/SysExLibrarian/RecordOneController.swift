/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            self.mainWindowController?.window?.endSheet(self.sheetWindow)

            // Don't actually add the entry until after we've ended the sheet,
            // in case it needs to show its own sheet
            self.mainWindowController?.addReadMessagesToLibrary()
        }
    }

}
