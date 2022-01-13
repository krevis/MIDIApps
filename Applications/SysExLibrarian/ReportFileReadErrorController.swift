/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class ReportFileReadErrorController {

    init(windowController: MainWindowController, library: Library) {
        self.mainWindowController = windowController
        self.library = library
    }

    // Main window controller sends this to begin the process
    func reportErrors(forEntries entriesAndErrors: [(LibraryEntry, Error)], completion: @escaping () -> Void) {
        // Tell the user about the problem files. If they choose to proceed, perform the completion.
        // If they cancel, don't do anything.

        self.entriesAndErrors = entriesAndErrors
        self.completion = completion

        reportNextError()
    }

    // MARK: Private

    private weak var mainWindowController: MainWindowController?
    private weak var library: Library?

    private var entriesAndErrors: [(LibraryEntry, Error)] = []
    private var completion: (() -> Void)?

}

extension ReportFileReadErrorController /* Private */ {

    private func reportNextError() {
        if let window = mainWindowController?.window, let (_, error) = entriesAndErrors.first {
            let alert = NSAlert(error: error)
            alert.addButton(withTitle: NSLocalizedString("Continue", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Continue button in alert"))
            alert.addButton(withTitle: NSLocalizedString("Cancel", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Cancel button in alert"))
            alert.beginSheetModal(for: window) { response in
                if response == .alertFirstButtonReturn /* Continue */ {
                    // Get this sheet out of the way before we open another one
                    alert.window.orderOut(nil)

                    self.entriesAndErrors.removeFirst()
                    self.reportNextError()
                }
                else /* Cancel */ {
                    self.cancel()
                }
            }
        }
        else {
            self.completion?()
        }
    }

    private func cancel() {
        // Cancel the whole process
        self.entriesAndErrors = []
    }

}
