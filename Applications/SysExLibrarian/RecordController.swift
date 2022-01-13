/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class RecordController: NSObject {

    init(mainWindowController: MainWindowController, midiController: MIDIController) {
        self.mainWindowController = mainWindowController
        self.midiController = midiController

        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: API for main window controller

    func beginRecording() {
        guard let window = mainWindowController?.window else { return }

        if topLevelObjects == nil {
            guard Bundle.main.loadNibNamed(self.nibName, owner: self, topLevelObjects: &topLevelObjects) else { fatalError("couldn't load nib") }
        }

        progressIndicator.startAnimation(nil)

        updateIndicators(status: MIDIController.MessageListenStatus(messageCount: 0, bytesRead: 0, totalBytesRead: 0))

        window.beginSheet(sheetWindow, completionHandler: nil)

        observeMIDIController()
        tellMIDIControllerToStartRecording()
    }

    // MARK: Actions

    @IBAction func cancelRecording(_ sender: Any?) {
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

    func updateIndicators(status: MIDIController.MessageListenStatus) {
        fatalError("must override in subclass")
    }

    // MARK: May be overridden in subclasses

    func observeMIDIController() {
        NotificationCenter.default.addObserver(self, selector: #selector(readStatusChanged(_:)), name: .readStatusChanged, object: midiController)
    }

    func stopObservingMIDIController() {
        NotificationCenter.default.removeObserver(self, name: .readStatusChanged, object: midiController)
    }

    // MARK: To be used by subclasses

    weak var mainWindowController: MainWindowController?
    weak var midiController: MIDIController?

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
        guard let status = midiController?.messageListenStatus else { return }
        updateIndicators(status: status)

        scheduledProgressUpdate = false
    }

    @objc private func readStatusChanged(_ notification: Notification) {
        if !scheduledProgressUpdate {
            self.perform(#selector(self.privateUpdateIndicators), with: nil, afterDelay: 5.0 / 60.0)
            scheduledProgressUpdate = true
        }
    }

}
