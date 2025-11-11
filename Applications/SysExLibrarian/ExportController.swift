/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI
import UniformTypeIdentifiers

class ExportController {

    init(windowController: MainWindowController) {
        self.mainWindowController = windowController
    }

    // Main window controller sends this to export messages
    // asSMF == YES for standard MIDI file, NO for sysex (.syx)
    func exportMessages(_ messages: [SystemExclusiveMessage], fromFileName: String?, asSMF: Bool) {
        guard let window = mainWindowController?.window else { return }

        // Pick a file name to export to.
        let ext = asSMF ? "mid" : "syx"
        let savePanel = NSSavePanel()
        if let type = UTType(filenameExtension: ext) {
            savePanel.allowedContentTypes = [type]
        }
        savePanel.allowsOtherFileTypes = true
        savePanel.canSelectHiddenExtension = true

        let defaultFileName: String
        if let fileName = fromFileName {
            defaultFileName = NSString(string: fileName).deletingPathExtension
        }
        else {
            defaultFileName = String(localized: "SysEx", comment: "default file name for exported standard MIDI file (w/o extension)")
        }

        savePanel.nameFieldStringValue = NSString(string: defaultFileName).appendingPathExtension(ext) ?? defaultFileName

        savePanel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }

            if let fileData = asSMF ? SystemExclusiveMessage.standardMIDIFileData(forMessages: messages) : SystemExclusiveMessage.data(forMessages: messages),
               let url = savePanel.url {
                do {
                    try fileData.write(to: url)
                }
                catch {
                    let alert = NSAlert(error: error)
                    _ = alert.runModal()
                }
            }
            else {
                let alert = NSAlert()
                alert.messageText = String(localized: "Error", comment: "title of error alert")
                alert.informativeText = String(localized: "The file could not be saved.", comment: "message if sysex can't be exported")
                _ = alert.runModal()
            }
        }
    }

    // MARK: Private

    private weak var mainWindowController: MainWindowController?

}
