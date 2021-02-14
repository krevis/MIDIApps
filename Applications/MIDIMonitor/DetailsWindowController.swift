/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa
import SnoizeMIDI

class DetailsWindowController: UtilityWindowController, NSWindowDelegate {

    let message: Message

    init(message: Message) {
        self.message = message
        super.init(window: nil)
        shouldCascadeWindows = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.displayPreferencesDidChange(_:)), name: .displayPreferenceChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .displayPreferenceChanged, object: nil)
    }

    //
    // To be overridden by subclasses
    //

    override var windowNibName: NSNib.Name? {
        "Details"
    }

    var dataForDisplay: Data {
        message.fullData
    }

    //
    // Private
    //

    @IBOutlet private var timeField: NSTextField!
    @IBOutlet private var sizeField: NSTextField!
    @IBOutlet private var textView: NSTextView!

    override func windowDidLoad() {
        super.windowDidLoad()

        updateDescriptionFields()

        textView.string = dataForDisplay.formattedAsHexDump()
    }

    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        let format = NSLocalizedString("%@ Details", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "Details window title format string")
        return String.localizedStringWithFormat(format, displayName)
    }

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        guard let midiDocument = document as? Document else { return }
        midiDocument.encodeRestorableState(state, for: self)
    }

    @objc func displayPreferencesDidChange(_ notification: Notification) {
        updateDescriptionFields()
    }

    private func updateDescriptionFields() {
        let format = NSLocalizedString("%@ bytes", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "Details size format string")
        let formattedLength = Message.formatLength(dataForDisplay.count)
        let sizeString = String.localizedStringWithFormat(format, formattedLength)

        sizeField.stringValue = sizeString
        timeField.stringValue = message.timeStampForDisplay
    }

}
