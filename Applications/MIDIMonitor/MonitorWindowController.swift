/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

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

    deinit {
        NotificationCenter.default.removeObserver(self, name: .displayPreferenceChanged, object: nil)

        nextMessagesRefreshTimer?.invalidate()
    }

    override var windowNibName: NSNib.Name? {
        return "MIDIMonitor"
    }

    // MARK: Internal

    // Sources controls
    @IBOutlet var sourcesDisclosureButton: DisclosureButton!
    @IBOutlet var sourcesDisclosableView: DisclosableView!
    @IBOutlet var sourcesOutlineView: SourcesOutlineView!

    // Filter controls
    @IBOutlet var filterDisclosureButton: DisclosureButton!
    @IBOutlet var filterDisclosableView: DisclosableView!
    @IBOutlet var voiceMessagesCheckBox: NSButton!
    @IBOutlet var voiceMessagesMatrix: NSMatrix!
    @IBOutlet var systemCommonCheckBox: NSButton!
    @IBOutlet var systemCommonMatrix: NSMatrix!
    @IBOutlet var realTimeCheckBox: NSButton!
    @IBOutlet var realTimeMatrix: NSMatrix!
    @IBOutlet var systemExclusiveCheckBox: NSButton!
    @IBOutlet var invalidCheckBox: NSButton!
    @IBOutlet var channelRadioButtons: NSMatrix!
    @IBOutlet var oneChannelField: NSTextField!
    var filterCheckboxes: [NSButton] {
        return [voiceMessagesCheckBox, systemCommonCheckBox, realTimeCheckBox, systemExclusiveCheckBox, invalidCheckBox]
    }
    var filterMatrixCells: [NSCell] {
        return voiceMessagesMatrix.cells + systemCommonMatrix.cells + realTimeMatrix.cells
    }

    // Event controls
    @IBOutlet var messagesTableView: NSTableView!
    @IBOutlet var clearButton: NSButton!
    @IBOutlet var maxMessageCountField: NSTextField!
    @IBOutlet var sysExProgressIndicator: NSProgressIndicator!
    @IBOutlet var sysExProgressField: NSTextField!

    // Transient data
    var oneChannel: UInt = 1
    var inputSourceGroups: [CombinationInputStreamSourceGroup] = []
    var displayedMessages: [SMMessage] = []
    var messagesNeedScrollToBottom: Bool = false
    var nextMessagesRefreshDate: NSDate?
    var nextMessagesRefreshTimer: Timer?

    // Constants
    let minimumMessagesRefreshDelay: TimeInterval = 0.10

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
            guard let document = document else { return }
            guard let smmDocument = document as? Document else { fatalError() }

            _ = window // Make sure the window and all views are loaded first

            updateMessages(scrollingToBottom: false)
            updateSources()
            updateMaxMessageCount()
            updateFilterControls()

            if let windowSettings = smmDocument.windowSettings {
                restoreWindowSettings(windowSettings)
            }
        }
    }

    private var midiDocument: Document! {
        return document as? Document
    }

    private func trivialWindowSettingsDidChange() {
        // Mark the document as dirty, so the state of the window gets saved.
        // However, use NSChangeDiscardable, so it doesn't cause a locked document to get dirtied for a trivial change.
        // Also, don't do it for untitled, unsaved documents which have no fileURL yet, because that's annoying.
        // Similarly, don't do it if "Ask to keep changes when closing documents" is turned on.

        if midiDocument.fileURL != nil && UserDefaults.standard.bool(forKey: "NSCloseAlwaysConfirmsChanges") {
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
        default:
            return false
        }
    }

}

extension MonitorWindowController: NSOutlineViewDataSource, NSOutlineViewDelegate {

    // MARK: Input Sources Outline View

    func updateSources() {
        inputSourceGroups = midiDocument.inputSourceGroups
        sourcesOutlineView.reloadData()
    }

    func revealInputSources(_ sources: Set<AnyHashable>) {
        // Show the sources first
        sourcesDisclosableView.shown = true
        sourcesDisclosureButton.intValue = 1

        // Of all of the input sources, find the first one which is in the given set.
        // Then expand the outline view to show this source, and scroll it to be visible.
        for group in inputSourceGroups where group.expandable {
            for source in group.sources {
                if let hashableSource = source as? AnyHashable,
                   sources.contains(hashableSource) {
                    // Found one!
                    sourcesOutlineView.expandItem(group)
                    sourcesOutlineView.scrollRowToVisible(sourcesOutlineView.row(forItem: source))

                    // And now we're done
                    break
                }
            }
        }
    }

    @IBAction func toggleSourcesShown(_ sender: AnyObject?) {
        sourcesDisclosableView.toggleDisclosure(sender)
        trivialWindowSettingsDidChange()
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return inputSourceGroups.count
        }
        else if let group = item as? CombinationInputStreamSourceGroup {
            return group.sources.count
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
            return group.sources[index]
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
        guard let item = item else { fatalError() }

        let identifier = tableColumn?.identifier.rawValue
        switch identifier {
        case "name":
            if let group = item as? CombinationInputStreamSourceGroup {
                return group.name
            }
            else if let source = item as? SMInputStreamSource {
                let name = source.inputStreamSourceName ?? ""
                if let externalDeviceNames = source.inputStreamSourceExternalDeviceNames,
                   externalDeviceNames.count > 0 {
                    return "\(name)—\(externalDeviceNames.joined(separator: ", "))"
                }
                else {
                    return name
                }
            }
            else {
                return nil
            }

        case "enabled":
            if let group = item as? CombinationInputStreamSourceGroup {
                return buttonStateForInputSources(group.sources)
            }
            else if let source = item as? SMInputStreamSource {
                return buttonStateForInputSources([source])
            }
            else {
                return nil
            }

        default:
            return nil
        }
    }

    func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, byItem item: Any?) {
        guard let item = item,
              let number = object as? NSNumber else { fatalError() }

        var newState = NSControl.StateValue(rawValue: number.intValue)
        // It doesn't make sense to switch from off to mixed, so go directly to on
        if newState == .mixed {
            newState = .on
        }

        let sources: [SMInputStreamSource]
        if let group = item as? CombinationInputStreamSourceGroup {
            sources = group.sources
        }
        else if let source = item as? SMInputStreamSource {
            sources = [source]
        }
        else {
            sources = []
        }

        var newSelectedSources = midiDocument.selectedInputSources
        for source in sources {
            if let hashableSource = source as? AnyHashable {
                if newState == .on {
                    newSelectedSources.insert(hashableSource)
                }
                else {
                    newSelectedSources.remove(hashableSource)
                }
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

    private func buttonStateForInputSources(_ sources: [SMInputStreamSource]) -> NSControl.StateValue {
        let selectedSources = midiDocument.selectedInputSources

        var areAnySelected = false
        var areAnyNotSelected = false

        for source in sources {
            if let hashableSource = source as? AnyHashable,
               selectedSources.contains(hashableSource) {
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
        let currentMask = midiDocument.filterMask.rawValue

        // Each filter checkbox has a tag with the mask of filters that it is based on.
        // Top-level filter checkboxes are standalone NSButtons. They include the state of second-level checkboxes, so their tags may have multiple bits set, and they may be mixed state.
        // Second-level filter checkboxes are NSCells in an NSMatrix. Their tags have only a single bit set, and they are either on or off, never mixed state.
        for checkbox in filterCheckboxes {
            let buttonMask = UInt32(checkbox.tag)   // multiple bits
            checkbox.state = {
                switch currentMask & buttonMask {
                case buttonMask: return .on     // all on
                case 0:          return .off    // all off
                default:         return .mixed  // some but not all on
                }
            }()
        }

        for checkbox in filterMatrixCells {
            let buttonMask = UInt32(checkbox.tag)   // only a single bit
            checkbox.state = {
                switch currentMask & buttonMask {
                case buttonMask: return .on     // on
                case 0:          return .off    // off
                default:         fatalError()   // shouldn't happen, something is wrong with the tag
                }
            }()
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

    @IBAction func toggleFilterShown(_ sender: AnyObject?) {
        filterDisclosableView.toggleDisclosure(sender)
        trivialWindowSettingsDidChange()
    }

    private func changeFilter(tag: Int, state: NSControl.StateValue) {
        let turnBitsOn: Bool
        switch state {
        case .on, .mixed:
            turnBitsOn = true
        default:
            turnBitsOn = false
        }

        midiDocument.changeFilterMask(SMMessageType(UInt32(tag)), turnBitsOn: turnBitsOn)
    }

    @IBAction func changeFilter(_ sender: AnyObject?) {
        if let button = sender as? NSButton {
            changeFilter(tag: button.tag, state: button.state)
        }
    }

    @IBAction func changeFilterFromMatrix(_ sender: AnyObject?) {
        if let matrix = sender as? NSMatrix,
           let buttonCell = matrix.selectedCell() as? NSButtonCell {
            changeFilter(tag: buttonCell.tag, state: buttonCell.state)
        }
    }

    @IBAction func setChannelRadioButton(_ sender: AnyObject?) {
        if let matrix = sender as? NSMatrix {
            if matrix.selectedCell()?.tag == 0 {
                midiDocument.showAllChannels()
            }
            else {
                midiDocument.showOnlyOneChannel(oneChannel)
            }
        }
    }

    @IBAction func setChannel(_ sender: AnyObject?) {
        if let control = sender as? NSControl {
            let channel = (control.objectValue as? NSNumber)?.uintValue ?? 0
            midiDocument.showOnlyOneChannel(channel)
        }
    }

}

extension MonitorWindowController: NSTableViewDataSource {

    // MARK: Messages Table View

    func updateMaxMessageCount() {
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
            if UserDefaults.standard.bool(forKey: SMExpertModePreferenceKey) {
                return message.expertDataForDisplay
            }
            else {
                return message.dataForDisplay
            }
        default:
            return nil
        }
    }

    @IBAction func clearMessages(_ sender: AnyObject?) {
        midiDocument.clearSavedMessages()
    }

    @IBAction func setMaximumMessageCount(_ sender: AnyObject?) {
        guard let control = sender as? NSControl else { fatalError() }
        if let number = control.objectValue as? NSNumber {
            midiDocument.maxMessageCount = number.uintValue
        }
        else {
            updateMaxMessageCount()
        }
    }

    @IBAction func copy(_ sender: AnyObject?) {
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

    @IBAction func showDetailsOfSelectedMessages(_ sender: AnyObject?) {
        for message in selectedMessages {
            midiDocument.detailsWindowController(for: message).showWindow(nil)
        }
    }

    @objc private func displayPreferencesDidChange(_ notification: Notification) {
        updateVisibleMessages()
    }

    private var selectedMessages: [SMMessage] {
        return messagesTableView.selectedRowIndexes.map { displayedMessages[$0] }
    }

    private func refreshMessagesTableView() {
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
        // Restore visibility of disclosable sections
        let sourcesShown = (windowSettings[Self.sourcesShownKey] as? NSNumber)?.boolValue ?? false
        sourcesDisclosureButton.intValue = sourcesShown ? 1 : 0
        sourcesDisclosableView.shown = sourcesShown

        let filterShown = (windowSettings[Self.filterShownKey] as? NSNumber)?.boolValue ?? false
        filterDisclosureButton.intValue = filterShown ? 1 : 0
        filterDisclosableView.shown = filterShown

        // Then, since those may have resized the window, set the frame back to what we expect.
        if let windowFrame = windowSettings[Self.windowFrameKey] as? NSWindow.PersistableFrameDescriptor {
            window?.setFrame(from: windowFrame)
        }

        if let scrollX = windowSettings[Self.messagesScrollPointX] as? NSNumber,
           let scrollY = windowSettings[Self.messagesScrollPointY] as? NSNumber {
            let scrollPoint = NSPoint(x: scrollX.doubleValue, y: scrollY.doubleValue)
            messagesTableView.scroll(scrollPoint)
        }
    }

}
