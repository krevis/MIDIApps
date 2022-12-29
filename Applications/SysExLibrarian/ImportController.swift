/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class ImportController {

    init(windowController: MainWindowController, library: Library) {
        self.mainWindowController = windowController
        self.library = library

        guard Bundle.main.loadNibNamed("Import", owner: self, topLevelObjects: &topLevelObjects) else { fatalError() }
    }

    // Main window controller sends this to begin the process
    func importFiles(_ paths: [String], showingProgress: Bool) {
        precondition(filePathsToImport.isEmpty)
        filePathsToImport = paths

        shouldShowProgress = showingProgress && areAnyFilesDirectories(paths)

        showImportWarning()
    }

    // MARK: Actions

    @IBAction func cancelImporting(_ sender: Any?) {
        // No need to lock just to set a boolean
        importCancelled = true
    }

    @IBAction func endSheetWithReturnCodeFromSenderTag(_ sender: Any?) {
        if let window = mainWindowController?.window,
           let sheet = window.attachedSheet,
           let senderView = sender as? NSView {
            window.endSheet(sheet, returnCode: NSApplication.ModalResponse(rawValue: senderView.tag))
        }
    }

    // MARK: Private

    private var topLevelObjects: NSArray?

    @IBOutlet private var importSheetWindow: NSPanel!
    @IBOutlet private var progressIndicator: NSProgressIndicator!
    @IBOutlet private var progressMessageField: NSTextField!
    @IBOutlet private var progressIndexField: NSTextField!

    @IBOutlet private var importWarningSheetWindow: NSPanel!
    @IBOutlet private var doNotWarnOnImportAgainCheckbox: NSButton!

    private weak var mainWindowController: MainWindowController?
    private weak var library: Library?

    private var workQueue: DispatchQueue?

    // Transient data
    private var filePathsToImport: [String] = []
    private var shouldShowProgress = false
    private var importCancelled = false

}

extension ImportController /* Preferences keys */ {

    static var showWarningOnImportPreferenceKey = "SSEShowWarningOnImport"

}

extension ImportController /* Private */ {

    private func areAnyFilesDirectories(_ paths: [String]) -> Bool {
        for path in paths {
            var isDirectory = ObjCBool(false)
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue {
                return true
            }
        }

        return false
    }

    private func showImportWarning() {
        guard let library else { return }

        let areAllFilesInLibraryDirectory = filePathsToImport.allSatisfy({ library.isPathInFileDirectory($0) })

        if areAllFilesInLibraryDirectory || UserDefaults.standard.bool(forKey: Self.showWarningOnImportPreferenceKey) == false {
            importFiles()
        }
        else {
            doNotWarnOnImportAgainCheckbox.intValue = 0
            mainWindowController?.window?.beginSheet(importWarningSheetWindow, completionHandler: { modalResponse in
                self.importWarningSheetWindow.orderOut(nil)

                if modalResponse == .OK {
                    if self.doNotWarnOnImportAgainCheckbox.integerValue == 1 {
                        UserDefaults.standard.set(false, forKey: Self.showWarningOnImportPreferenceKey)
                    }

                    self.importFiles()
                }
                else {
                    // Cancelled
                    self.finishedImport()
                }
            })
        }
    }

    private func importFiles() {
        if shouldShowProgress {
            importFilesShowingProgress()
        }
        else {
            // Add entries immediately
            let (newEntries, badFiles) = addFilesToLibrary(filePathsToImport)
            finishImport(newEntries, badFiles)
        }
    }

    //
    // Import with progress display
    // Main queue: setup, updating progress display, teardown
    //

    private func importFilesShowingProgress() {
        guard let mainWindow = mainWindowController?.window else { return }

        importCancelled = false
        updateImportStatusDisplay("", 0, 0)

        mainWindow.beginSheet(importSheetWindow) { _ in
            self.importSheetWindow.orderOut(nil)
        }

        let paths = self.filePathsToImport
        if workQueue == nil {
            workQueue = DispatchQueue(label: "Import", qos: .userInitiated)
        }
        workQueue?.async {
            self.workQueueImportFiles(paths)
        }
    }

    static private var scanningString = NSLocalizedString("Scanning...", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Scanning...")
    static private var xOfYFormatString = NSLocalizedString("%u of %u", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "importing sysex: x of y")

    private func updateImportStatusDisplay(_ filePath: String, _ fileIndex: Int, _ fileCount: Int) {
        if fileCount == 0 {
            progressIndicator.isIndeterminate = true
            progressIndicator.usesThreadedAnimation = true
            progressIndicator.startAnimation(nil)
            progressMessageField.stringValue = Self.scanningString
            progressIndexField.stringValue = ""
        }
        else {
            progressIndicator.isIndeterminate = false
            progressIndicator.maxValue = Double(fileCount)
            progressIndicator.doubleValue = Double(fileIndex + 1)
            progressMessageField.stringValue = FileManager.default.displayName(atPath: filePath)
            progressIndexField.stringValue = String.localizedStringWithFormat(Self.xOfYFormatString, fileIndex + 1, fileCount)
        }
    }

    //
    // Import with progress display
    // Work queue: recurse through directories, filter out inappropriate files, and import
    //

    private func workQueueImportFiles(_ paths: [String]) {
        autoreleasepool {
            let expandedAndFilteredFilePaths = workQueueExpandAndFilterFiles(paths)

            var newEntries = [LibraryEntry]()
            var badFiles = [String]()
            if expandedAndFilteredFilePaths.count > 0 {
                (newEntries, badFiles) = addFilesToLibrary(expandedAndFilteredFilePaths)
            }

            DispatchQueue.main.async {
                self.doneImportingInWorkQueue(newEntries, badFiles)
            }
        }
    }

    private func workQueueExpandAndFilterFiles(_ paths: [String]) -> [String] {
        guard let library else { return [] }
        let fileManager = FileManager.default

        var acceptableFilePaths = [String]()

        for path in paths {
            if importCancelled {
                acceptableFilePaths.removeAll()
                break
            }

            var isDirectory = ObjCBool(false)
            if !fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
                continue
            }

            autoreleasepool {
                if isDirectory.boolValue {
                    // Handle this directory's contents recursively
                    do {
                        let childPaths = try fileManager.contentsOfDirectory(atPath: path)

                        var fullChildPaths = [String]()
                        for childPath in childPaths {
                            let fullChildPath = NSString(string: path).appendingPathComponent(childPath) as String
                            fullChildPaths.append(fullChildPath)
                        }

                        let acceptableChildren = workQueueExpandAndFilterFiles(fullChildPaths)
                        acceptableFilePaths.append(contentsOf: acceptableChildren)
                    }
                    catch {
                        // ignore
                    }
                }
                else {
                    if fileManager.isReadableFile(atPath: path) && library.typeOfFile(atPath: path) != .unknown {
                        acceptableFilePaths.append(path)
                    }
                }
            }
        }

        return acceptableFilePaths
    }

    private func doneImportingInWorkQueue(_ newEntries: [LibraryEntry], _ badFiles: [String]) {
        if let window = mainWindowController?.window,
           let sheet = window.attachedSheet {
            window.endSheet(sheet)
        }

        finishImport(newEntries, badFiles)
    }

    //
    // Check if each file is already in the library, and then try to add each new one
    //

    private func addFilesToLibrary(_ paths: [String]) -> ([LibraryEntry], [String]) {
        // Returns successfully created library entries, and paths for files that could not
        // be successfully imported.
        // NOTE: This may be happening in the main queue or workQueue.

        guard let library else { return ([], []) }

        var addedEntries = [LibraryEntry]()
        var badFilePaths = [String]()

        // Find the files which are already in the library, and pull them out.
        let (existingEntries, filePaths) = library.findEntries(forFilePaths: paths)

        // Try to add each file to the library, keeping track of the successful ones.
        let fileCount = filePaths.count
        for (fileIndex, filePath) in filePaths.enumerated() {
            // If we're not in the main thread, update progress information and tell the main thread to update its UI.
            if !Thread.isMainThread {
                if importCancelled {
                    break
                }

                DispatchQueue.main.async {
                    self.updateImportStatusDisplay(filePath, fileIndex, fileCount)
                }
            }

            autoreleasepool {
                if let addedEntry = library.addEntry(forFile: filePath) {
                    addedEntries.append(addedEntry)
                }
                else {
                    badFilePaths.append(filePath)
                }
            }
        }

        addedEntries.append(contentsOf: existingEntries)

        return (addedEntries, badFilePaths)
    }

    //
    // Finishing up
    //

    private func finishImport(_ newEntries: [LibraryEntry], _ badFiles: [String]) {
        mainWindowController?.showNewEntries(newEntries)
        showErrorMessageForFilesWithNoSysEx(badFiles)
        finishedImport()
    }

    private func finishedImport() {
        filePathsToImport = []
        importCancelled = false
    }

    private func showErrorMessageForFilesWithNoSysEx(_ badFiles: [String]) {
        let badFileCount = badFiles.count
        guard badFileCount > 0 else { return }

        guard let window = mainWindowController?.window,
              window.attachedSheet == nil
        else { return }

        var informativeText: String = ""

        if badFileCount == 1 {
            informativeText = NSLocalizedString("No SysEx data could be found in this file. It has not been added to the library.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "message when no sysex data found in file")
        }
        else {
            let format = NSLocalizedString("No SysEx data could be found in %u of the files. They have not been added to the library.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format of message when no sysex data found in files")
            informativeText = String.localizedStringWithFormat(format, badFileCount)
        }

        let messageText = NSLocalizedString("Could not read SysEx", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of alert when can't read a sysex file")

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = messageText
        alert.informativeText = informativeText
        alert.beginSheetModal(for: window, completionHandler: nil)
    }

}
