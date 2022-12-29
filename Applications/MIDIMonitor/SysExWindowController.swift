/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class SysExWindowController: DetailsWindowController {

    private let sysExMessage: SystemExclusiveMessage

    override init(message: Message) {
        self.sysExMessage = message as! SystemExclusiveMessage // swiftlint:disable:this force_cast
        super.init(message: message)
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
        guard let window else { return }

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
