/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Snoize nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class SysExWindowController: DetailsWindowController {

    private let sysExMessage: SystemExclusiveMessage

    override init(message myMessage: Message) {
        guard let mySysExMessage = myMessage as? SystemExclusiveMessage else { fatalError() }
        sysExMessage = mySysExMessage
        super.init(message: myMessage)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBOutlet private var manufacturerNameField: NSTextField!

    override var windowNibName: NSNib.Name? {
        return "SysEx"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        if let manufacturerName = sysExMessage.manufacturerName {
            manufacturerNameField.stringValue = manufacturerName
        }
    }

    override var dataForDisplay: Data {
        return sysExMessage.receivedDataWithStartByte
    }

    @IBAction func save(_ sender: AnyObject) {
        guard let window = window else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["syx"]
        savePanel.allowsOtherFileTypes = true
        savePanel.beginSheetModal(for: window) { _ in
            savePanel.orderOut(nil)

            let saveWithEOXAlways = UserDefaults.standard.bool(forKey: PreferenceKeys.saveSysExWithEOXAlways)
            let dataToWrite = saveWithEOXAlways ? self.sysExMessage.fullMessageData : self.sysExMessage.receivedDataWithStartByte
            if let url = savePanel.url {
                do {
                    try dataToWrite.write(to: url, options: .atomic)
                }
                catch {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: window, completionHandler: nil)
                }
            }
        }
    }

}
