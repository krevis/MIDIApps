/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
