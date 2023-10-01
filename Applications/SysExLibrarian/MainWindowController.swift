/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class MainWindowController: GeneralWindowController {

    static var shared = MainWindowController()

    init() {
        self.library = Library.shared

        super.init(window: nil)

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(libraryDidChange(_:)), name: .libraryDidChange, object: library)
        center.addObserver(self, selector: #selector(displayPreferencesDidChange(_:)), name: .displayPreferenceChanged, object: nil)
        center.addObserver(self, selector: #selector(doubleClickToSendMessagesDidChange(_:)), name: .doubleClickToSendPreferenceChanged, object: nil)
        center.addObserver(self, selector: #selector(listenForProgramChangesDidChange(_:)), name: .listenForProgramChangesPreferenceChanged, object: nil)
        center.addObserver(self, selector: #selector(programChangeBaseIndexDidChange(_:)), name: .programChangeBaseIndexPreferenceChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return "MainWindow"
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        window?.showsToolbarButton = false

        // FUTURE: Consider handling file promises, as below (higher priority than file URLs).
        // As of 10.15 the Finder doesn't create them for drags, so it isn't terribly important.
        // libraryTableView.registerForDraggedTypes(NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        // https://developer.apple.com/documentation/appkit/nstableviewdatasource/supporting_table_view_drag_and_drop_through_file_promises
        libraryTableView.registerForDraggedTypes([.fileURL])

        libraryTableView.target = self

        // Configure the table view to send messages on double-click if enabled in preferences
        doubleClickToSendMessagesDidChange(nil)

        // Fix cells so they don't draw their own background (overdrawing the alternating row colors)
        for tableColumn in libraryTableView.tableColumns {
            (tableColumn.dataCell as? NSTextFieldCell)?.drawsBackground = false
        }

        // The MIDI controller may cause us to do some things to the UI, so we create it now instead of earlier
        midiController = MIDIController(mainWindowController: self)

        updateProgramChangeTableColumnFormatter()
        listenForProgramChangesDidChange(nil)
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        loadToolbar()
        synchronizeInterface()
    }

    override var firstResponderWhenNotEditing: NSResponder? {
        libraryTableView
    }

    // MARK: Actions

    @IBAction func selectDestinationFromPopUpButton(_ sender: Any?) {
        if let popUpButton = sender as? NSPopUpButton,
           let menuItem = popUpButton.selectedItem,
           let destination = menuItem.representedObject as? OutputStreamDestination {
            midiController.selectedDestination = destination
        }
    }

    @IBAction func selectDestinationFromMenuItem(_ sender: Any?) {
        if let menuItem = sender as? NSMenuItem,
           let destination = menuItem.representedObject as? OutputStreamDestination {
            midiController.selectedDestination = destination
        }
    }

    @IBAction override func selectAll(_ sender: Any?) {
        // Forward to the library table view, even if it isn't the first responder
        libraryTableView.selectAll(sender)
    }

    @IBAction func addToLibrary(_ sender: Any?) {
        guard let window = self.window, finishEditingWithoutError() else { return }

        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        openPanel.allowedFileTypes = library.allowedFileTypes
        openPanel.beginSheetModal(for: window) { response in
            if response == .OK {
                let filenames = openPanel.urls.compactMap { $0.path }
                self.importFiles(filenames, showingProgress: false)
            }
        }
    }

    @IBAction func delete(_ sender: Any?) {
        guard finishEditingWithoutError() else { return }
        deleteController.deleteEntries(selectedEntries)
    }

    @IBAction func recordOne(_ sender: Any?) {
        guard finishEditingWithoutError() else { return }
        recordOneController.beginRecording()
    }

    @IBAction func recordMany(_ sender: Any?) {
        guard finishEditingWithoutError() else { return }
        recordManyController.beginRecording()
    }

    @IBAction func play(_ sender: Any?) {
        guard finishEditingWithoutError() else { return }
        findMissingFilesThen {
            self.alertUnreadableFilesThen {
                self.playSelectedEntries()
            }
        }
    }

    @IBAction func showFileInFinder(_ sender: Any?) {
        precondition(selectedEntries.count == 1)

        finishEditingInWindow()
        // We don't care if there is an error, go on anyway

        if let path = selectedEntries.first?.path {
            NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
        }
        else {
            NSSound.beep()    // Turns out the file isn't there after all
        }
    }

    @IBAction func rename(_ sender: Any?) {
        let columnIndex = libraryTableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name"))

        if libraryTableView.editedRow >= 0 && libraryTableView.editedColumn == columnIndex {
            // We are already editing the name column of the table view, so don't do anything
        }
        else {
            finishEditingInWindow() // In case we are editing something else

            // Make sure that the file really exists right now before we try to rename it
            if let entry = selectedEntries.first,
               entry.isFilePresentIgnoringCachedValue {
                libraryTableView.editColumn(columnIndex, row: libraryTableView.selectedRow, with: nil, select: true)
            }
            else {
                NSSound.beep()
            }
        }
    }

    @IBAction func changeProgramNumber(_ sender: Any?) {
        let columnIndex = libraryTableView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "programNumber"))

        if libraryTableView.editedRow >= 0 && libraryTableView.editedColumn == columnIndex {
            // We are already editing the program# column of the table view, so don't do anything
        }
        else {
            finishEditingInWindow() // In case we are editing something else

            libraryTableView.editColumn(columnIndex, row: libraryTableView.selectedRow, with: nil, select: true)
        }
    }

    @IBAction func showDetails(_ sender: Any?) {
        guard finishEditingWithoutError() else { return }

        findMissingFilesThen {
            self.alertUnreadableFilesThen {
                self.showDetailsOfSelectedEntries()
            }
        }
    }

    @IBAction func saveAsStandardMIDI(_ sender: Any?) {
        guard finishEditingWithoutError() else { return }

        findMissingFilesThen {
            self.alertUnreadableFilesThen {
                self.exportSelectedEntriesAsSMF()
            }
        }
    }

    @IBAction func saveAsSysex(_ sender: Any?) {
        guard finishEditingWithoutError() else { return }

        findMissingFilesThen {
            self.alertUnreadableFilesThen {
                self.exportSelectedEntriesAsSYX()
            }
        }
    }

    // MARK: Other API

    func synchronizeInterface() {
        synchronizeDestinations()
        synchronizeLibrarySortIndicator()
        synchronizeLibrary()
    }

    func synchronizeDestinations() {
        // Remove empty groups from groupedDestinations
        let groupedDestinations = midiController.groupedDestinations.filter { (group: [OutputStreamDestination]) -> Bool in
            group.count > 0
        }

        let currentDestination = midiController.selectedDestination

        synchronizeDestinationPopUp(destinationGroups: groupedDestinations, currentDestination: currentDestination)
        synchronizeDestinationToolbarMenu(destinationGroups: groupedDestinations, currentDestination: currentDestination)
    }

    func synchronizeLibrarySortIndicator() {
        if let column = libraryTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: sortColumnIdentifier)) {
            libraryTableView.setSortColumn(column, isAscending: isSortAscending)
            libraryTableView.highlightedTableColumn = column
        }
    }

    func synchronizeLibrary() {
        let selectedEntries = self.selectedEntries

        sortLibraryEntries()

        // NOTE Some entries in selectedEntries may no longer be present in sortedLibraryEntries.
        // We don't need to manually take them out of selectedEntries because selectEntries can deal with
        // entries that are missing.

        libraryTableView.reloadData()
        self.selectedEntries = selectedEntries

        // Sometimes, apparently, reloading the table view will not mark the window as needing update. Weird.
        NSApp.setWindowsNeedUpdate(true)
    }

    func importFiles(_ filePaths: [String], showingProgress: Bool) {
        importController.importFiles(filePaths, showingProgress: showingProgress)
    }

    func showNewEntries(_ newEntries: [LibraryEntry]) {
        synchronizeLibrary()
        selectedEntries = newEntries
        scrollToEntries(newEntries)
    }

    func addReadMessagesToLibrary() {
        guard let allSysexData = SystemExclusiveMessage.data(forMessages: midiController.messages) else { return }

        do {
            if let entry = try library.addNewEntry(sysexData: allSysexData) {
                showNewEntries([entry])
            }
        }
        catch {
            guard let window else { return }

            let messageText = NSLocalizedString("Error", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of error alert")
            let informativeTextPart1 = NSLocalizedString("The file could not be created.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "message of alert when recording to a new file fails")
            let informativeText = informativeTextPart1 + "\n" + error.localizedDescription

            let alert = NSAlert()
            alert.messageText = messageText
            alert.informativeText = informativeText
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }

    func playEntry(withProgramNumber desiredProgramNumber: UInt8) {
        if let entry = sortedLibraryEntries.first(where: { $0.programNumber == desiredProgramNumber }) {
            playController.playMessages(inEntryForProgramChange: entry)
        }
    }

    var selectedEntries: [LibraryEntry] {
        get {
            var selectedEntries: [LibraryEntry] = []
            for rowIndex in libraryTableView.selectedRowIndexes
            where rowIndex < sortedLibraryEntries.count {
                selectedEntries.append(sortedLibraryEntries[rowIndex])
            }
            return selectedEntries
        }
        set {
            libraryTableView.deselectAll(nil)
            for entry in newValue {
                if let row = sortedLibraryEntries.firstIndex(of: entry) {
                    libraryTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                }
            }
        }
    }

    // MARK: Private
    @IBOutlet private var destinationPopUpButton: NSPopUpButton!
    @IBOutlet private var libraryTableView: GeneralTableView!
    @IBOutlet private var programChangeTableColumn: NSTableColumn!

    // Library
    private let library: Library
    private var sortedLibraryEntries: [LibraryEntry] = []

    // Subcontrollers
    private var midiController: MIDIController!
    private lazy var playController = PlayController(mainWindowController: self, midiController: midiController)
    private lazy var recordOneController = RecordOneController(mainWindowController: self, midiController: midiController)
    private lazy var recordManyController = RecordManyController(mainWindowController: self, midiController: midiController)
    private lazy var deleteController = DeleteController(windowController: self)
    private lazy var importController = ImportController(windowController: self, library: library)
    private lazy var exportController = ExportController(windowController: self)
    private lazy var findMissingController = FindMissingController(windowController: self, library: library)
    private lazy var reportFileReadErrorController = ReportFileReadErrorController(windowController: self, library: library)

    // Transient data
    private var sortColumnIdentifier = "name"
    private var isSortAscending = true
    private weak var destinationToolbarItem: NSToolbarItem?

}

extension MainWindowController /* Preferences keys */ {

    static let abbreviateSizesInLibraryPreferenceKey = "SSEAbbreviateFileSizesInLibraryTableView"
    static let doubleClickToSendPreferenceKey = "SSEDoubleClickToSendMessages"

}

extension MainWindowController /* NSUserInterfaceValidations */ {

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(play(_:)),
             #selector(delete(_:)),
             #selector(showDetails(_:)),
             #selector(saveAsStandardMIDI(_:)),
             #selector(saveAsSysex(_:)):
            return libraryTableView.numberOfSelectedRows > 0
        case #selector(showFileInFinder(_:)),
             #selector(rename(_:)):
            return libraryTableView.numberOfSelectedRows == 1 && selectedEntries.first!.isFilePresent
        case #selector(changeProgramNumber(_:)):
            return libraryTableView.numberOfSelectedRows == 1 && programChangeTableColumn.tableView != nil
        default:
            return super.validateUserInterfaceItem(item)
        }
    }

}

extension MainWindowController: GeneralTableViewDataSource {

    // NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        sortedLibraryEntries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let tableColumn, row < sortedLibraryEntries.count else { return nil }

        let entry = sortedLibraryEntries[row]

        switch tableColumn.identifier.rawValue {
        case "name":
            return entry.name
        case "manufacturer":
            return entry.manufacturer
        case "size":
            if let size = entry.size {
                if UserDefaults.standard.bool(forKey: Self.abbreviateSizesInLibraryPreferenceKey) {
                    return String.abbreviatedByteCount(size)
                }
                else {
                    return "\(size)"
                }
            }
            else {
                return ""
            }
        case "messageCount":
            return entry.messageCount
        case "programNumber":
            if let programNumber = entry.programNumber {
                let baseIndex = UserDefaults.standard.integer(forKey: MIDIController.programChangeBaseIndexPreferenceKey)
                return baseIndex + Int(programNumber)
            }
            else {
                return nil
            }

        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let tableColumn, row < sortedLibraryEntries.count else { return }

        let entry = sortedLibraryEntries[row]

        switch tableColumn.identifier.rawValue {
        case "name":
            if let newName = object as? String {
                if entry.renameFile(newName) {
                    // Table view will be reloaded asynchronously; after that, scroll to keep the entry visible
                    DispatchQueue.main.async {
                        self.scrollToEntries([entry])
                    }
                }
                else {
                    if let window {
                        let alert = NSAlert()
                        alert.messageText = NSLocalizedString("Error", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of error alert")
                        alert.informativeText = NSLocalizedString("The file for this item could not be renamed.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "message of alert when renaming a file fails")
                        alert.beginSheetModal(for: window, completionHandler: nil)
                    }
                }
            }

        case "programNumber":
            var newProgramNumber: UInt8?
            if let newNumber = object as? NSNumber {
                var intValue = newNumber.intValue

                let baseIndex = UserDefaults.standard.integer(forKey: MIDIController.programChangeBaseIndexPreferenceKey)
                intValue -= baseIndex

                if (0...127).contains(intValue) {
                    newProgramNumber = UInt8(intValue)
                }
            }
            entry.programNumber = newProgramNumber

        default:
            break
        }

    }

    // GeneralTableViewDataSource

    func tableView(_ tableView: GeneralTableView, deleteRows rows: IndexSet) {
        delete(tableView)
    }

    private func filePaths(fromDraggingInfo draggingInfo: NSDraggingInfo) -> [String] {
        if let nsURLs = draggingInfo.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] {
            return nsURLs.compactMap(\.filePathURL?.path)
        }

        return []
    }

    func tableView(_ tableView: GeneralTableView, draggingEntered sender: NSDraggingInfo) -> NSDragOperation {
        let paths = filePaths(fromDraggingInfo: sender)
        if !paths.isEmpty && areAnyFilesAcceptableForImport(paths) {
            return .copy
        }
        else {
            return []
        }
    }

    func tableView(_ tableView: GeneralTableView, performDragOperation sender: NSDraggingInfo) -> Bool {
        let paths = filePaths(fromDraggingInfo: sender)
        if !paths.isEmpty {
            importFiles(paths, showingProgress: true)
            return true
        }
        else {
            return false
        }
    }

}

extension MainWindowController: GeneralTableViewDelegate {

    // NSTableViewDelegate

    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        guard let cell = cell as? NSTextFieldCell,
              row < sortedLibraryEntries.count else { return }
        let entry = sortedLibraryEntries[row]

        let color: NSColor
        if entry.isFilePresent {
            if #available(macOS 10.14, *) {
                color = NSColor.labelColor
            }
            else {
                color = NSColor.black
            }
        }
        else {
            if #available(macOS 10.14, *) {
                color = NSColor.systemRed
            }
            else {
                color = NSColor.red
            }
        }

        cell.textColor = color
    }

    func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
        let columnIdentifier = tableColumn.identifier.rawValue
        if columnIdentifier == sortColumnIdentifier {
            isSortAscending = !isSortAscending
        }
        else {
            sortColumnIdentifier = columnIdentifier
            isSortAscending = true
        }

        synchronizeLibrarySortIndicator()
        synchronizeLibrary()
        scrollToEntries(selectedEntries)
    }

    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        guard let tableColumn, row < sortedLibraryEntries.count else { return false }

        switch tableColumn.identifier.rawValue {
        case "name":
            return sortedLibraryEntries[row].isFilePresent
        case "programNumber":
            return true
        default:
            return false
        }
    }

    // GeneralTableViewDelegate

    func tableViewKeyDownReceivedSpace(_ tableView: GeneralTableView) -> Bool {
        // Space key is used as a shortcut for -play:
        play(nil)
        return true
    }

}

extension MainWindowController /* Private */ {

    @objc private func displayPreferencesDidChange(_ notification: Notification) {
        libraryTableView.reloadData()
    }

    @objc private func doubleClickToSendMessagesDidChange(_ notification: Notification?) {
        if UserDefaults.standard.bool(forKey: Self.doubleClickToSendPreferenceKey) {
            libraryTableView.doubleAction = #selector(play(_:))
        }
        else {
            libraryTableView.doubleAction = nil
        }
    }

    @objc private func listenForProgramChangesDidChange(_ notification: Notification?) {
        finishEditingInWindow()

        if UserDefaults.standard.bool(forKey: MIDIController.listenForProgramChangesPreferenceKey) {
            if programChangeTableColumn.tableView == nil {
                libraryTableView.addTableColumn(programChangeTableColumn)

                if let nameColumn = libraryTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name")) {
                    nameColumn.width -= (programChangeTableColumn.width + 3)
                }
            }
        }
        else {
            if programChangeTableColumn.tableView != nil {
                libraryTableView.removeTableColumn(programChangeTableColumn)

                if let nameColumn = libraryTableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name")) {
                    nameColumn.width += (programChangeTableColumn.width + 3)
                }
            }
        }
    }

    @objc private func programChangeBaseIndexDidChange(_ notification: Notification) {
        updateProgramChangeTableColumnFormatter()
        libraryTableView.reloadData()
    }

    private func updateProgramChangeTableColumnFormatter() {
        if let cell = programChangeTableColumn.dataCell as? NSCell,
           let formatter = cell.formatter as? NumberFormatter {
            let baseIndex = UserDefaults.standard.integer(forKey: MIDIController.programChangeBaseIndexPreferenceKey)
            formatter.minimum = NSNumber(value: baseIndex + 0)
            formatter.maximum = NSNumber(value: baseIndex + 127)
        }
    }

    private func finishEditingWithoutError() -> Bool {
        finishEditingInWindow()
        return window?.attachedSheet == nil
    }

    // MARK: Destination selections (popup and toolbar menu)

    private func synchronizeDestinationPopUp(destinationGroups: [[OutputStreamDestination]], currentDestination: OutputStreamDestination?) {
        // The pop up button redraws whenever it's changed, so use an animation group to stop the blinkiness
        NSAnimationContext.runAnimationGroup { _ in
            destinationPopUpButton.removeAllItems()

            var found = false
            for (index, destinations) in destinationGroups.enumerated() {
                if index > 0 {
                    destinationPopUpButton.addSeparatorItem()
                }

                for destination in destinations {
                    destinationPopUpButton.addItem(title: titleForDestination(destination) ?? "", representedObject: destination)

                    if !found && destination === currentDestination {
                        destinationPopUpButton.selectItem(at: destinationPopUpButton.numberOfItems - 1)
                        found = true
                    }
                }
            }

            if !found {
                destinationPopUpButton.select(nil)
            }
        }
    }

    private func synchronizeDestinationToolbarMenu(destinationGroups: [[OutputStreamDestination]], currentDestination: OutputStreamDestination?) {
        guard let toolbarItem = destinationToolbarItem else { return }
        // Set the title to "Destination: <Whatever>"
        // Then set up the submenu items

        let topMenuItem = toolbarItem.menuFormRepresentation

        let selectedDestinationTitle = titleForDestination(currentDestination) ?? NSLocalizedString("None", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "none")

        let topTitle = NSLocalizedString("Destination", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of destination toolbar item") + ": " + selectedDestinationTitle
        topMenuItem?.title = topTitle

        if let submenu = topMenuItem?.submenu {
            submenu.removeAllItems()

            var found = false
            for (index, destinations) in destinationGroups.enumerated() {
                if index > 0 {
                    submenu.addItem(NSMenuItem.separator())
                }

                for destination in destinations {
                    let title = titleForDestination(destination) ?? ""
                    let menuItem = submenu.addItem(withTitle: title, action: #selector(selectDestinationFromMenuItem(_:)), keyEquivalent: "")
                    menuItem.representedObject = destination
                    menuItem.target = self

                    if !found && destination === currentDestination {
                        menuItem.state = .on
                        found = true
                    }
                }
            }
        }

        // Workaround to get the toolbar item to refresh after we change the title of the menu item
        toolbarItem.menuFormRepresentation = nil
        toolbarItem.menuFormRepresentation = topMenuItem
    }

    private func titleForDestination(_ destination: OutputStreamDestination?) -> String? {
        var title = destination?.outputStreamDestinationName

        // https://github.com/krevis/MIDIApps/issues/79
        // If we somehow have a \0 character in this string, NSPopUpButton strips everything
        // after the \0 when drawing the non-popped-up button. That broke sometime between macOS 10.11
        // and 10.15.7. Work around it.
        title = title?.replacingOccurrences(of: "\0", with: "")

        return title
    }

    // MARK: Library interaction

    @objc private func libraryDidChange(_ notification: Notification) {
        // Reloading the table view will wipe out the edit session, so don't do that if we're editing
        if libraryTableView.editedRow == -1 {
            synchronizeLibrary()
        }
    }

    private func sortLibraryEntries() {
        let sortedEntries = library.entries.sorted(by: { (entry1, entry2) -> Bool in
            switch sortColumnIdentifier {
            case "name":
                return (entry1.name ?? "") < (entry2.name ?? "")
            case "manufacturer":
                return (entry1.manufacturer ?? "") < (entry2.manufacturer ?? "")
            case "size":
                return (entry1.size ?? -1) < (entry2.size ?? -1)
            case "messageCount":
                return (entry1.messageCount ?? 0) < (entry2.messageCount ?? 0)
            case "programNumber":
                func massagedProgramNumber(entry: LibraryEntry) -> Int {
                    if let value = entry.programNumber {
                        return Int(value)
                    }
                    else {
                        return -1
                    }
                }
                return massagedProgramNumber(entry: entry1) < massagedProgramNumber(entry: entry2)
            default:
                fatalError()
            }
        })

        self.sortedLibraryEntries = isSortAscending ? sortedEntries : sortedEntries.reversed()
    }

    private func scrollToEntries(_ entries: [LibraryEntry]) {
        guard entries.count > 0 else { return }

        var lowestRow = Int.max
        for entry in entries {
            if let row = sortedLibraryEntries.firstIndex(of: entry) {
                lowestRow = min(lowestRow, row)
            }
        }

        libraryTableView.scrollRowToVisible(lowestRow)
    }

    // MARK: Doing things with selected entries

    private var selectedMessages: [SystemExclusiveMessage] {
        Array(selectedEntries.compactMap({ $0.messages }).joined())
    }

    private func playSelectedEntries() {
        let messages = selectedMessages
        if !messages.isEmpty {
            playController.playMessages(messages)
        }
    }

    private func showDetailsOfSelectedEntries() {
        for entry in selectedEntries {
            DetailsWindowController.showWindow(forEntry: entry)
        }
    }

    private func exportSelectedEntriesAsSMF() {
        exportSelectedEntries(true)
    }

    private func exportSelectedEntriesAsSYX() {
        exportSelectedEntries(false)
    }

    private func exportSelectedEntries(_ asSMF: Bool) {
        guard let fileName = selectedEntries.first?.name else { return }

        let messages = selectedMessages
        guard !messages.isEmpty else { return }

        exportController.exportMessages(messages, fromFileName: fileName, asSMF: asSMF)
    }

    // MARK: Add files / importing

    private func areAnyFilesAcceptableForImport(_ filePaths: [String]) -> Bool {
        let fileManager = FileManager.default

        for filePath in filePaths {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return true
                }

                if fileManager.isReadableFile(atPath: filePath) && library.typeOfFile(atPath: filePath) != .unknown {
                    return true
                }
            }
        }

        return false
    }

    // MARK: Finding missing or unreadable files

    private func findMissingFilesThen(successfulCompletion: @escaping (() -> Void)) {
        let entriesWithMissingFiles = selectedEntries.filter { !$0.isFilePresentIgnoringCachedValue }
        if entriesWithMissingFiles.count == 0 {
            successfulCompletion()
        }
        else {
            findMissingController.findMissingFiles(forEntries: entriesWithMissingFiles, completion: successfulCompletion)
        }
    }

    private func alertUnreadableFilesThen(successfulCompletion: @escaping (() -> Void)) {
        let entriesAndFileReadErrors = selectedEntries.compactMap { (entry: LibraryEntry) -> (LibraryEntry, Error)? in
            if let error = entry.fileReadError {
                return (entry, error)
            }
            else {
                return nil
            }
        }

        if entriesAndFileReadErrors.count == 0 {
            successfulCompletion()
        }
        else {
            reportFileReadErrorController.reportErrors(forEntries: entriesAndFileReadErrors, completion: successfulCompletion)
        }
    }

}

extension MainWindowController: NSToolbarDelegate {

    private func loadToolbar() {
        guard let toolbarName = windowNibName else { return }

        // The new Unified toolbar style doesn't leave much room for items, so use the old Expanded version
        // with the toolbar items under the title
        if #available(macOS 11.0, *) {
            window?.toolbarStyle = .expanded
        }

        let toolbar = NSToolbar(identifier: toolbarName)
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = true
        toolbar.delegate = self
        window?.toolbar = toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            NSToolbarItem.Identifier("Play"),
            .space,
            NSToolbarItem.Identifier("DestinationPopup"),
            .flexibleSpace,
            NSToolbarItem.Identifier("RecordOne"),
            NSToolbarItem.Identifier("RecordMany")
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)
        toolbarItem.isEnabled = true

        switch itemIdentifier.rawValue {
        case "Play":
            toolbarItem.label = "Play"
            toolbarItem.action = #selector(play(_:))
            toolbarItem.image = NSImage(named: "ToolbarPlay")
            toolbarItem.toolTip = "Play back the selected file(s)"

        case "DestinationPopup":
            toolbarItem.label = "Destination"
            toolbarItem.action = #selector(play(_:))
            toolbarItem.image = NSImage(named: "ToolbarPlay")
            toolbarItem.toolTip = "Where to send SysEx data"

            destinationToolbarItem = toolbarItem

            toolbarItem.view = destinationPopUpButton
            let height = destinationPopUpButton.frame.size.height
            toolbarItem.minSize = NSSize(width: 150, height: height)
            toolbarItem.maxSize = NSSize(width: 1000, height: height)

            let menuTitle = NSLocalizedString("Destination", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of destination toolbar item")
            let menuItem = NSMenuItem(title: menuTitle, action: nil, keyEquivalent: "")
            menuItem.submenu = NSMenu(title: "")
            toolbarItem.menuFormRepresentation = menuItem

        case "RecordOne":
            toolbarItem.label = "Record One"
            toolbarItem.action = #selector(recordOne(_:))
            toolbarItem.image = NSImage(named: "ToolbarRecordOne")
            toolbarItem.toolTip = "Record one SysEx message"

        case "RecordMany":
            toolbarItem.label = "Record Many"
            toolbarItem.action = #selector(recordMany(_:))
            toolbarItem.image = NSImage(named: "ToolbarRecordMultiple")
            toolbarItem.toolTip = "Record one or more SysEx messages"

        default:
            break
        }

        return toolbarItem
    }

}
