/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class MonitorWindowController: NSWindowController {

    init() {
        super.init(window: nil)
        shouldCascadeWindows = true
        shouldCloseDocument = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.displayPreferencesDidChange(_:)), name: .displayPreferenceChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return "MIDIMonitor"
    }

    // MARK: Internal

    // Sources controls
    @IBOutlet private var sourcesDisclosureButton: DisclosureButton!
    @IBOutlet private var sourcesDisclosableView: DisclosableView!
    @IBOutlet private var sourcesOutlineView: SourcesOutlineView!

    // Filter controls
    @IBOutlet private var filterDisclosureButton: DisclosureButton!
    @IBOutlet private var filterDisclosableView: DisclosableView!
    @IBOutlet private var voiceMessagesCheckBox: NSButton!
    @IBOutlet private var voiceMessagesMatrix: NSMatrix!
    @IBOutlet private var systemCommonCheckBox: NSButton!
    @IBOutlet private var systemCommonMatrix: NSMatrix!
    @IBOutlet private var realTimeCheckBox: NSButton!
    @IBOutlet private var realTimeMatrix: NSMatrix!
    @IBOutlet private var systemExclusiveCheckBox: NSButton!
    @IBOutlet private var invalidCheckBox: NSButton!
    @IBOutlet private var channelRadioButtons: NSMatrix!
    @IBOutlet private var oneChannelField: NSTextField!
    private var filterCheckboxes: [NSButton] {
        return [voiceMessagesCheckBox, systemCommonCheckBox, realTimeCheckBox, systemExclusiveCheckBox, invalidCheckBox]
    }
    private var filterMatrixCells: [NSCell] {
        return voiceMessagesMatrix.cells + systemCommonMatrix.cells + realTimeMatrix.cells
    }

    // Event controls
    @IBOutlet private var messagesTableView: NSTableView!
    @IBOutlet private var clearButton: NSButton!
    @IBOutlet private var maxMessageCountField: NSTextField!
    @IBOutlet private var sysExProgressIndicator: NSProgressIndicator!
    @IBOutlet private var sysExProgressField: NSTextField!

    // Transient data
    private var oneChannel: Int = 1
    private var inputSourceGroups: [CombinationInputStreamSourceGroup] = []
    private var displayedMessages: [Message] = []
    private var messagesNeedScrollToBottom: Bool = false
    private var nextMessagesRefreshDate: NSDate?
    private var nextMessagesRefreshTimer: Timer?
    private var isRestoringWindowSettings = false
    private var doneSettingDocument = false

    // Constants
    private let minimumMessagesRefreshDelay: TimeInterval = 0.10

}

extension MonitorWindowController {

    // MARK: Window and document

    override func windowDidLoad() {
        super.windowDidLoad()

        sourcesOutlineView.outlineTableColumn = sourcesOutlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
        sourcesOutlineView.autoresizesOutlineColumn = false

        let checkboxCell = NonHighlightingButtonCell(textCell: "")
        checkboxCell.setButtonType(.switch)
        checkboxCell.controlSize = .small
        checkboxCell.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        checkboxCell.allowsMixedState = true
        sourcesOutlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "enabled"))?.dataCell = checkboxCell

        let textFieldCell = NonHighlightingTextFieldCell(textCell: "")
        textFieldCell.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        sourcesOutlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name"))?.dataCell = textFieldCell

        voiceMessagesCheckBox.allowsMixedState = true
        systemCommonCheckBox.allowsMixedState = true
        realTimeCheckBox.allowsMixedState = true

        (maxMessageCountField.formatter as? NumberFormatter)?.allowsFloats = false
        (oneChannelField.formatter as? NumberFormatter)?.allowsFloats = false

        messagesTableView.autosaveName = "MessagesTableView2"
        messagesTableView.autosaveTableColumns = true
        messagesTableView.target = self
        messagesTableView.doubleAction = #selector(self.showDetailsOfSelectedMessages(_:))

        hideSysExProgressIndicator()
    }

    override var document: AnyObject? {
        didSet {
            guard let document else { return }
            guard let smmDocument = document as? Document else { fatalError() }

            _ = window // Make sure the window and all views are loaded first

            if !smmDocument.isDraft && smmDocument.fileURL != nil {
                windowFrameAutosaveName = ""
            }

            updateMessages(scrollingToBottom: false)
            updateSources()
            updateMaxMessageCount()
            updateFilterControls()

            restoreWindowSettings(smmDocument.windowSettings ?? [:])

            doneSettingDocument = true
        }
    }

    private var midiDocument: Document? {
        return document as? Document
    }

    private func trivialWindowSettingsDidChange() {
        // Mark the document as dirty, so the state of the window gets saved.
        // However, use NSChangeDiscardable, so it doesn't cause a locked document to get dirtied for a trivial change.
        // Also, don't do it for untitled, unsaved documents which have no fileURL yet, because that's annoying.
        // Similarly, don't do it if "Ask to keep changes when closing documents" is turned on.

        guard let midiDocument else { return }
        if midiDocument.fileURL != nil && !UserDefaults.standard.bool(forKey: "NSCloseAlwaysConfirmsChanges") {
            let change = NSDocument.ChangeType(rawValue: (NSDocument.ChangeType.changeDone.rawValue | NSDocument.ChangeType.changeDiscardable.rawValue))!
            midiDocument.updateChangeCount(change)
        }
    }

}

extension MonitorWindowController: NSUserInterfaceValidations {

    // MARK: General UI

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(copy(_:)):
            return window?.firstResponder == messagesTableView && messagesTableView.numberOfSelectedRows > 0
        case #selector(self.showDetailsOfSelectedMessages(_:)):
            return selectedMessages.count > 0
        case #selector(self.clearMessages(_:)):
            return messagesTableView.numberOfRows > 0
        default:
            return false
        }
    }

}

extension MonitorWindowController: NSOutlineViewDataSource, NSOutlineViewDelegate {

    // MARK: Input Sources Outline View

    // Note: On macOS 10.15 (and possibly before), we can provide items which are Swift structs.
    // However, in macOS 10.9-10.11 (and maybe later) this causes a crash in swift_unknownObjectRetain.
    // Work around it by boxing the structs (InputStreamSource) in Box.

    func updateSources() {
        guard let midiDocument else { return }

        inputSourceGroups = midiDocument.inputSourceGroups
        sourcesOutlineView.reloadData()
    }

    func revealInputSources(_ sources: Set<InputStreamSource>) {
        // Show the sources first
        sourcesDisclosableView.shown = true
        sourcesDisclosureButton.intValue = 1

        // Of all of the input sources, find the first one which is in the given set.
        // Then expand the outline view to show this source, and scroll it to be visible.
        // Subsequent sources will expand their groups (if necessary) but won't scroll.
        var foundFirstSource = false
        for group in inputSourceGroups where group.expandable {
            for source in group.boxedSources where sources.contains(source.unbox) {
                // Found one!
                sourcesOutlineView.expandItem(group)

                if !foundFirstSource {
                    sourcesOutlineView.scrollRowToVisible(sourcesOutlineView.row(forItem: source))
                    foundFirstSource = true
                }
            }
        }
    }

    @IBAction func toggleSourcesShown(_ sender: Any?) {
        sourcesDisclosableView.toggleDisclosure(sender)
        trivialWindowSettingsDidChange()
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return inputSourceGroups.count
        }
        else if let group = item as? CombinationInputStreamSourceGroup {
            return group.boxedSources.count
        }
        else {
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return inputSourceGroups[index]
        }
        else if let group = item as? CombinationInputStreamSourceGroup {
            return group.boxedSources[index]
        }
        else {
            fatalError()
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let group = item as? CombinationInputStreamSourceGroup {
            return group.expandable
        }
        else {
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let item else { fatalError() }

        let identifier = tableColumn?.identifier.rawValue
        switch identifier {
        case "name":
            if let group = item as? CombinationInputStreamSourceGroup {
                return group.name
            }
            else if let source = item as? Box<InputStreamSource> {
                return source.unbox.name ?? ""
            }
            else {
                return nil
            }

        case "enabled":
            if let group = item as? CombinationInputStreamSourceGroup {
                return buttonStateForInputSources(group.sources)
            }
            else if let source = item as? Box<InputStreamSource> {
                return buttonStateForInputSources([source.unbox])
            }
            else {
                return nil
            }

        default:
            return nil
        }
    }

    func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, byItem item: Any?) {
        guard let midiDocument else { return }
        guard let item,
              let number = object as? NSNumber else { fatalError() }

        var newState = NSControl.StateValue(rawValue: number.intValue)
        // It doesn't make sense to switch from off to mixed, so go directly to on
        if newState == .mixed {
            newState = .on
        }

        let sources: [InputStreamSource]
        if let group = item as? CombinationInputStreamSourceGroup {
            sources = group.sources
        }
        else if let source = item as? Box<InputStreamSource> {
            sources = [source.unbox]
        }
        else {
            sources = []
        }

        var newSelectedSources = midiDocument.selectedInputSources
        for source in sources {
            if newState == .on {
                newSelectedSources.insert(source)
            }
            else {
                newSelectedSources.remove(source)
            }
        }

        midiDocument.selectedInputSources = newSelectedSources
    }

    func outlineView(_ outlineView: NSOutlineView, willDisplayOutlineCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        // cause the button cell to always use a "dark" triangle
        if let cell = cell as? NSCell {
            cell.backgroundStyle = .light
        }
    }

    func outlineView(_ outlineView: NSOutlineView, shouldTrackCell cell: NSCell, for tableColumn: NSTableColumn?, item: Any) -> Bool {
        // Allow clicks in the checkbox column to apply to the checkbox, not to attempt to change selection
        return tableColumn?.identifier.rawValue == "enabled"
    }

    func outlineView(_ outlineView: NSOutlineView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        // Don't allow any selection
        return IndexSet()
    }

    private func buttonStateForInputSources(_ sources: [InputStreamSource]) -> NSControl.StateValue {
        guard let midiDocument else { return .off }
        let selectedSources = midiDocument.selectedInputSources

        var areAnySelected = false
        var areAnyNotSelected = false

        for source in sources {
            if selectedSources.contains(source) {
                areAnySelected = true
            }
            else {
                areAnyNotSelected = true
            }

            if areAnySelected && areAnyNotSelected {
                return .mixed
            }
        }

        return areAnySelected ? .on : .off
    }

}

extension MonitorWindowController {

    // MARK: Filter

    func updateFilterControls() {
        guard let midiDocument else { return }

        let currentMask = midiDocument.filterMask.rawValue

        // Each filter checkbox has a tag with the mask of filters that it is based on.
        // Top-level filter checkboxes are standalone NSButtons. They include the state of second-level checkboxes, so their tags may have multiple bits set, and they may be mixed state.
        // Second-level filter checkboxes are NSCells in an NSMatrix. Their tags have only a single bit set, and they are either on or off, never mixed state.
        for checkbox in filterCheckboxes {
            let buttonMask = checkbox.tag   // multiple bits
            checkbox.state = switch currentMask & buttonMask {
            case buttonMask: .on     // all on
            case 0:          .off    // all off
            default:         .mixed  // some but not all on
            }
        }

        for checkbox in filterMatrixCells {
            let buttonMask = checkbox.tag   // only a single bit
            checkbox.state = switch currentMask & buttonMask {
            case buttonMask: .on            // on
            case 0:          .off           // off
            default:         fatalError()   // shouldn't happen, something is wrong with the tag
            }
        }

        if midiDocument.isShowingAllChannels {
            channelRadioButtons.selectCell(withTag: 0)
            oneChannelField.isEnabled = false
        }
        else {
            channelRadioButtons.selectCell(withTag: 1)
            oneChannelField.isEnabled = true
            oneChannel = midiDocument.oneChannelToShow
        }
        oneChannelField.objectValue = NSNumber(value: oneChannel)
    }

    @IBAction func toggleFilterShown(_ sender: Any?) {
        filterDisclosableView.toggleDisclosure(sender)
        trivialWindowSettingsDidChange()
    }

    private func changeFilter(tag: Int, state: NSControl.StateValue) {
        guard let midiDocument else { return }

        let turnBitsOn = switch state {
        case .on, .mixed: true
        default: false
        }

        midiDocument.changeFilterMask(Message.TypeMask(rawValue: tag), turnBitsOn: turnBitsOn)
    }

    @IBAction func changeFilter(_ sender: Any?) {
        if let button = sender as? NSButton {
            changeFilter(tag: button.tag, state: button.state)
        }
    }

    @IBAction func changeFilterFromMatrix(_ sender: Any?) {
        if let matrix = sender as? NSMatrix,
           let buttonCell = matrix.selectedCell() as? NSButtonCell {
            changeFilter(tag: buttonCell.tag, state: buttonCell.state)
        }
    }

    @IBAction func setChannelRadioButton(_ sender: Any?) {
        guard let midiDocument else { return }

        if let matrix = sender as? NSMatrix {
            if matrix.selectedCell()?.tag == 0 {
                midiDocument.showAllChannels()
            }
            else {
                midiDocument.showOnlyOneChannel(oneChannel)
            }
        }
    }

    @IBAction func setChannel(_ sender: Any?) {
        guard let midiDocument else { return }

        if let control = sender as? NSControl {
            let channel = (control.objectValue as? NSNumber)?.intValue ?? 0
            midiDocument.showOnlyOneChannel(channel)
        }
    }

}

extension MonitorWindowController: NSTableViewDataSource {

    // MARK: Messages Table View

    func updateMaxMessageCount() {
        guard let midiDocument else { return }

        maxMessageCountField.objectValue = NSNumber(value: midiDocument.maxMessageCount)
    }

    func updateVisibleMessages() {
        // Traditionally this was just messagesTableView.reloadData(), but as of macOS 10.15 (and perhaps earlier)
        // that sometimes, the first time after the window is shown, has a side-effect of changing the scroll position
        // (inappropriately adjusting for the header height). It's better to do a more targeted update, anyway.
        let visibleRowRange = messagesTableView.rows(in: messagesTableView.visibleRect)
        let rowIndexes = IndexSet(integersIn: visibleRowRange.lowerBound ..< visibleRowRange.upperBound)
        messagesTableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: IndexSet(integersIn: 0 ..< messagesTableView.numberOfColumns))
    }

    func updateMessages(scrollingToBottom: Bool) {
        // Reloading the NSTableView can be excruciatingly slow, and if messages are coming in quickly,
        // we will hog a lot of CPU. So we make sure that we don't do it too often.

        if scrollingToBottom {
            messagesNeedScrollToBottom = true
        }

        if nextMessagesRefreshTimer != nil {
            // We're going to refresh soon, so don't do anything now.
            return
        }

        let timeUntilNextRefresh = nextMessagesRefreshDate?.timeIntervalSinceNow ?? 0
        if timeUntilNextRefresh <= 0 {
            // Refresh right away, since we haven't recently.
            refreshMessagesTableView()
        }
        else {
            // We have refreshed recently.
            // Schedule an event to make us refresh when we are next allowed to do so.
            nextMessagesRefreshTimer = Timer.scheduledTimer(timeInterval: timeUntilNextRefresh, target: self, selector: #selector(self.refreshMessagesTableViewFromTimer(_:)), userInfo: nil, repeats: false)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedMessages.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let message = displayedMessages[row]

        switch tableColumn?.identifier.rawValue {
        case "timeStamp":
            return message.timeStampForDisplay
        case "source":
            return message.originatingEndpointForDisplay
        case "type":
            return message.typeForDisplay
        case "channel":
            return message.channelForDisplay
        case "data":
            if UserDefaults.standard.bool(forKey: MessageFormatter.expertModePreferenceKey) {
                return message.expertDataForDisplay
            }
            else {
                return message.dataForDisplay
            }
        default:
            return nil
        }
    }

    @IBAction func clearMessages(_ sender: Any?) {
        guard let midiDocument else { return }

        midiDocument.clearSavedMessages()
    }

    @IBAction func setMaximumMessageCount(_ sender: Any?) {
        guard let midiDocument else { return }
        guard let control = sender as? NSControl else { fatalError() }

        if let number = control.objectValue as? NSNumber {
            midiDocument.maxMessageCount = number.intValue
        }
        else {
            updateMaxMessageCount()
        }
    }

    @IBAction func copy(_ sender: Any?) {
        guard window?.firstResponder == messagesTableView else { return }

        let columns = messagesTableView.tableColumns
        let rowStrings = messagesTableView.selectedRowIndexes.map { (row) -> String in
            let columnStrings = columns.map { (column) -> String in
                tableView(messagesTableView, objectValueFor: column, row: row) as? String ?? ""
            }
            let rowString = columnStrings.joined(separator: "\t")
            return rowString
        }
        let totalString = rowStrings.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(totalString, forType: .string)
    }

    @IBAction func showDetailsOfSelectedMessages(_ sender: Any?) {
        guard let midiDocument else { return }

        for message in selectedMessages {
            midiDocument.detailsWindowController(for: message).showWindow(nil)
        }
    }

    @objc private func displayPreferencesDidChange(_ notification: Notification) {
        updateVisibleMessages()
    }

    private var selectedMessages: [Message] {
        return messagesTableView.selectedRowIndexes.map { displayedMessages[$0] }
    }

    private func refreshMessagesTableView() {
        guard let midiDocument else { return }

        let oldMessages = displayedMessages
        let newMessages = midiDocument.savedMessages
        displayedMessages = newMessages

        // Keep the same messages selected, if possible
        let newRowIndexes = IndexSet(messagesTableView.selectedRowIndexes.compactMap { newMessages.firstIndex(of: oldMessages[$0]) })

        // If the table view was already scrolled to the bottom, remain scrolled to the bottom when new messages come in
        let wasAtBottom = messagesTableView.bounds.maxY - messagesTableView.visibleRect.maxY < messagesTableView.rowHeight

        // NSTableView won't detect a change in displayedMessages.count unless we tell it
        if oldMessages.count != newMessages.count {
            messagesTableView.noteNumberOfRowsChanged()
        }

        // Without doing a more complex diff of the message objects in the array, all we know is that the data for
        // any row and column may have changed, so reload them all.
        messagesTableView.reloadData(forRowIndexes: IndexSet(integersIn: 0 ..< displayedMessages.count), columnIndexes: IndexSet(integersIn: 0 ..< messagesTableView.numberOfColumns))

        if messagesNeedScrollToBottom && wasAtBottom {
            let messageCount = displayedMessages.count
            if messageCount > 0 {
                messagesTableView.scrollRowToVisible(messageCount - 1)
            }
        }
        messagesNeedScrollToBottom = false

        messagesTableView.selectRowIndexes(newRowIndexes, byExtendingSelection: false)

        // Figure out when we should next be allowed to refresh.
        nextMessagesRefreshDate = NSDate(timeIntervalSinceNow: minimumMessagesRefreshDelay)
    }

    @objc private func refreshMessagesTableViewFromTimer(_ timer: Timer) {
        nextMessagesRefreshTimer = nil
        refreshMessagesTableView()
    }

    func updateSysExReadIndicator() {
        showSysExProgressIndicator()
    }

    func stopSysExReadIndicator() {
        hideSysExProgressIndicator()
    }

    private func showSysExProgressIndicator() {
        sysExProgressField.isHidden = false
        sysExProgressIndicator.startAnimation(nil)
    }

    private func hideSysExProgressIndicator() {
        sysExProgressField.isHidden = true
        sysExProgressIndicator.stopAnimation(nil)
    }

}

extension MonitorWindowController {

    // MARK: Window settings

    private static let sourcesShownKey = "areSourcesShown"
    private static let filterShownKey = "isFilterShown"
    private static let windowFrameKey = "windowFrame"
    private static let messagesScrollPointX = "messagesScrollPointX"
    private static let messagesScrollPointY = "messagesScrollPointY"

    private static let untitledSourcesShownKey = "SMMUntitledAreSourcesShown"
    private static let untitledFilterShownKey = "SMMUntitledIsFilterShown"

    static var windowSettingsKeys: [String] {
        return [sourcesShownKey, filterShownKey, windowFrameKey, messagesScrollPointX, messagesScrollPointY]
    }

    var windowSettings: [String: Any] {
        var windowSettings: [String: Any] = [:]

        // Remember whether our sections are shown or hidden
        if sourcesDisclosableView.shown {
            windowSettings[Self.sourcesShownKey] = NSNumber(value: true)
        }
        if filterDisclosableView.shown {
            windowSettings[Self.filterShownKey] = NSNumber(value: true)
        }

        // And remember the window frame, so we can restore it after restoring those
        if let windowFrameDescriptor = window?.frameDescriptor {
            windowSettings[Self.windowFrameKey] = windowFrameDescriptor as AnyObject
        }

        // And the scroll position of the messages
        if let clipView = messagesTableView.enclosingScrollView?.contentView {
            let clipBounds = clipView.bounds
            let scrollPoint = messagesTableView.convert(clipBounds.origin, from: clipView)
            windowSettings[Self.messagesScrollPointX] = NSNumber(value: Double(scrollPoint.x))
            windowSettings[Self.messagesScrollPointY] = NSNumber(value: Double(scrollPoint.y))
        }

        return windowSettings
    }

    private func restoreWindowSettings(_ windowSettings: [String: Any]) {
        guard let window else { return }

        isRestoringWindowSettings = true
        defer { isRestoringWindowSettings = false }

        // Remember the original window frame in case we need it later. This is
        // - its size and position in the xib
        // - or the previously autosaved frame, if present
        // - plus any AppKit adjustments like cascading
        let originalFrameDescriptor = window.frameDescriptor

        // Restore visibility of disclosable sections
        let sourcesShown = (windowSettings[Self.sourcesShownKey] as? NSNumber)?.boolValue ?? UserDefaults.standard.bool(forKey: Self.untitledSourcesShownKey)
        sourcesDisclosureButton.intValue = sourcesShown ? 1 : 0
        sourcesDisclosableView.shown = sourcesShown

        let filterShown = (windowSettings[Self.filterShownKey] as? NSNumber)?.boolValue ?? UserDefaults.standard.bool(forKey: Self.untitledFilterShownKey)
        filterDisclosureButton.intValue = filterShown ? 1 : 0
        filterDisclosableView.shown = filterShown

        // Then, since those may have resized the window, set the frame back to what we expect.
        // (If we don't have a frame in the document, use the original frame.)
        let windowFrame = windowSettings[Self.windowFrameKey] as? NSWindow.PersistableFrameDescriptor ?? originalFrameDescriptor
        window.setFrame(from: windowFrame)

        if let scrollX = windowSettings[Self.messagesScrollPointX] as? NSNumber,
           let scrollY = windowSettings[Self.messagesScrollPointY] as? NSNumber {
            let scrollPoint = NSPoint(x: scrollX.doubleValue, y: scrollY.doubleValue)
            messagesTableView.scroll(scrollPoint)
        }
    }

}

extension MonitorWindowController: NSWindowDelegate {

    // Lifecycle

    func windowWillClose(_ notification: Notification) {
        // Clean up when the window is closed. This window controller will go away soon.
        NotificationCenter.default.removeObserver(self, name: .displayPreferenceChanged, object: nil)
        nextMessagesRefreshTimer?.invalidate()
        nextMessagesRefreshTimer = nil
    }

    // NSWindowRestoration-related:
    //
    // In some cases, the document's saved window settings will not match
    // the window size that was automatically encoded in restorable state.
    // (For instance, if we don't dirty the document when the window settings
    // were changed, and the user didn't save before quitting, and autosave
    // is turned off.)
    // Therefore, we must also put the window settings into the restorable
    // state, and restore that after the regular document settings are done.

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        state.encode(windowSettings, forKey: "windowSettings")
    }

    func window(_ window: NSWindow, didDecodeRestorableState state: NSCoder) {
        if let decodedWindowSettings = state.decodeObject(of: [NSDictionary.self, NSNumber.self, NSString.self], forKey: "windowSettings") as? [String: Any] {
            restoreWindowSettings(decodedWindowSettings)
        }
    }

}

extension MonitorWindowController: FastAnimatingWindowDelegate {

    func windowDidSaveFrame(window: FastAnimatingWindow, usingName name: NSWindow.FrameAutosaveName) {
        if !isRestoringWindowSettings && doneSettingDocument {
            // Also save whether each disclosable section is shown, since we want to
            // restore them all together in a new document in order to be coherent
            let defaults = UserDefaults.standard
            defaults.setValue(sourcesDisclosableView.shown, forKey: Self.untitledSourcesShownKey)
            defaults.setValue(filterDisclosableView.shown, forKey: Self.untitledFilterShownKey)
        }
    }

}
