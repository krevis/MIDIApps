/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

@objc class DeleteController: NSObject {

    @objc init(windowController: MainWindowController) {
        self.mainWindowController = windowController

        super.init()

        guard Bundle.main.loadNibNamed("Delete", owner: self, topLevelObjects: &topLevelObjects) else { fatalError() }
    }

    // Main window controller sends this to begin the process
    @objc func deleteEntries(_ entries: [SSELibraryEntry]) {
        guard entries.count > 0, let window = mainWindowController?.window else { return }

        entriesToDelete = entries
        if UserDefaults.standard.bool(forKey: Self.showWarningOnDeletePreferenceKey) {
            window.beginSheet(deleteWarningSheetWindow) { response in
                if response == .OK {
                    if self.doNotWarnOnDeleteAgainCheckbox.integerValue == 1 {
                        UserDefaults.standard.setValue(false, forKey: Self.showWarningOnDeletePreferenceKey)
                    }
                    self.checkForFilesInLibraryDirectory()
                }
                else {  // Cancelled
                    self.entriesToDelete = []
                }
            }
        }
        else {
            checkForFilesInLibraryDirectory()
        }
    }

    // MARK: Actions

    @IBAction func endSheetWithReturnCodeFromSenderTag(_ sender: Any?) {
        if let window = mainWindowController?.window,
           let sheet = window.attachedSheet,
           let senderView = sender as? NSView {
            window.endSheet(sheet, returnCode: NSApplication.ModalResponse(rawValue: senderView.tag))
        }
    }

    // MARK: Private

    private var topLevelObjects: NSArray?

    @IBOutlet private var deleteWarningSheetWindow: NSPanel!
    @IBOutlet private var doNotWarnOnDeleteAgainCheckbox: NSButton!
    @IBOutlet private var deleteLibraryFilesWarningSheetWindow: NSPanel!

    private weak var mainWindowController: MainWindowController?

    private var entriesToDelete: [SSELibraryEntry] = []

}

@objc extension DeleteController /* Preferences keys */ {

    static var showWarningOnDeletePreferenceKey = "SSEShowWarningOnDelete"

}

extension DeleteController /* Private */ {

    private func checkForFilesInLibraryDirectory() {
        guard let window = mainWindowController?.window else { return }

        let areAnyFilesInLibraryDirectory = entriesToDelete.contains(where: { $0.isFileInLibraryFileDirectory() })
        if areAnyFilesInLibraryDirectory {
            window.beginSheet(deleteLibraryFilesWarningSheetWindow) { response in
                if response == .OK {
                    // "Yes" button
                    self.deleteEntries(movingLibraryFilesToTrash: true)
                }
                else if response == .cancel {
                    // "No" button
                    self.deleteEntries(movingLibraryFilesToTrash: false)
                }
                else {
                    // "Cancel" button
                    self.entriesToDelete = []
                }
            }
        }
        else {
            deleteEntries(movingLibraryFilesToTrash: false)
        }
    }

    private func deleteEntries(movingLibraryFilesToTrash: Bool) {
        guard let library = entriesToDelete.first?.library else { return }

        if movingLibraryFilesToTrash {
            library.moveFilesInLibraryDirectoryToTrash(forEntries: entriesToDelete)
        }
        library.removeEntries(entriesToDelete)

        entriesToDelete = []

        mainWindowController?.synchronizeInterface()
    }

}
