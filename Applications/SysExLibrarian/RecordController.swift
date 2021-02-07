/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

@objc class RecordController: NSObject {

    @objc init(mainWindowController: SSEMainWindowController, midiController: SSEMIDIController) {
        self.mainWindowController = mainWindowController
        self.midiController = midiController

        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: API for main window controller

    @objc func beginRecording() {
        guard let window = mainWindowController?.window else { return }

        if topLevelObjects == nil {
            guard Bundle.main.loadNibNamed(self.nibName, owner: self, topLevelObjects: &topLevelObjects) else { fatalError("couldn't load nib") }
        }

        progressIndicator.startAnimation(nil)

        updateIndicators(messageCount: 0, bytesRead: 0, totalBytesRead: 0)

        window.beginSheet(sheetWindow) { _ in
            self.sheetWindow.orderOut(nil)
        }

        observeMIDIController()
        tellMIDIControllerToStartRecording()
    }

    // MARK: Actions

    @IBAction func cancelRecording(_ sender: AnyObject?) {
        midiController?.cancelMessageListen()
        stopObservingMIDIController()

        progressIndicator.stopAnimation(nil)

        mainWindowController?.window?.endSheet(sheetWindow)
    }

    // MARK: To be implemented in subclasses

    var nibName: String {
        fatalError("must override in subclass")
    }

    func tellMIDIControllerToStartRecording() {
        fatalError("must override in subclass")
    }

    func updateIndicators(messageCount: Int, bytesRead: Int, totalBytesRead: Int) {
        fatalError("must override in subclass")
    }

    // MARK: May be overridden in subclasses

    func observeMIDIController() {
        NotificationCenter.default.addObserver(self, selector: #selector(readStatusChanged(_:)), name: .SSEMIDIControllerReadStatusChanged, object: midiController)
    }

    func stopObservingMIDIController() {
        NotificationCenter.default.removeObserver(self, name: .SSEMIDIControllerReadStatusChanged, object: midiController)
    }

    // MARK: To be used by subclasses

    weak var mainWindowController: SSEMainWindowController?
    weak var midiController: SSEMIDIController?

    @IBOutlet var sheetWindow: NSPanel!
    @IBOutlet var progressIndicator: NSProgressIndicator!
    @IBOutlet var progressMessageField: NSTextField!
    @IBOutlet var progressBytesField: NSTextField!

    lazy var waitingForSysexMessage = NSLocalizedString("Waiting for SysEx message…", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "message when waiting for sysex")
    lazy var receivingSysexMessage = NSLocalizedString("Receiving SysEx message…", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "message when receiving sysex")

    func updateIndicatorsImmediatelyIfScheduled() {
        if scheduledProgressUpdate {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.privateUpdateIndicators), object: nil)
            scheduledProgressUpdate = false
            privateUpdateIndicators()
        }
    }

    // MARK: Private

    private var topLevelObjects: NSArray?
    private var scheduledProgressUpdate = false

    @objc private func privateUpdateIndicators() {
        var messageCount: UInt = 0
        var bytesRead: UInt = 0
        var totalBytesRead: UInt = 0

        midiController?.getMessageCount(&messageCount, bytesRead: &bytesRead, totalBytesRead: &totalBytesRead)

        updateIndicators(messageCount: Int(messageCount), bytesRead: Int(bytesRead), totalBytesRead: Int(totalBytesRead))

        scheduledProgressUpdate = false
    }

    @objc private func readStatusChanged(_ notification: Notification) {
        if !scheduledProgressUpdate {
            self.perform(#selector(self.privateUpdateIndicators), with: nil, afterDelay: 5.0 / 60.0)
            scheduledProgressUpdate = true
        }
    }

}
