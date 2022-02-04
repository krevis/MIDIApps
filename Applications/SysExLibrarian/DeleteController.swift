/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class DeleteController {

    init(windowController: MainWindowController) {
        self.mainWindowController = windowController

        guard Bundle.main.loadNibNamed("Delete", owner: self, topLevelObjects: &topLevelObjects) else { fatalError() }
    }

    // Main window controller sends this to begin the process
    func deleteEntries(_ entries: [LibraryEntry]) {
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

    private var entriesToDelete: [LibraryEntry] = []

}

extension DeleteController /* Preferences keys */ {

    static var showWarningOnDeletePreferenceKey = "SSEShowWarningOnDelete"

}

extension DeleteController /* Private */ {

    private func checkForFilesInLibraryDirectory() {
        guard let window = mainWindowController?.window else { return }

        let areAnyFilesInLibraryDirectory = entriesToDelete.contains(where: \.isFileInLibraryFileDirectory)
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
