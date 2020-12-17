/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class SMMMonitorWindowController: NSWindowController, NSUserInterfaceValidations {

    @objc init() {
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
    @IBOutlet var sourcesDisclosureButton: SNDisclosureButton!
    @IBOutlet var sourcesDisclosableView: SNDisclosableView!
    @IBOutlet var sourcesOutlineView: SMMSourcesOutlineView!

    // Filter controls
    @IBOutlet var filterDisclosureButton: SNDisclosureButton!
    @IBOutlet var filterDisclosableView: SNDisclosableView!
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
    var oneChannel: UInt = 0
    var groupedInputSources: [Any]? = nil  // TODO do better
    var displayedMessages: [SMMessage] = []
    var messagesNeedScrollToBottom: Bool = false
    var nextMessagesRefreshDate: NSDate? = nil
    var nextMessagesRefreshTimer: Timer? = nil

    // Constants
    let minimumMessagesRefreshDelay: TimeInterval = 0.10

}

extension SMMMonitorWindowController {

    // MARK: Window and document

    override func windowDidLoad() {
        super.windowDidLoad()

        sourcesOutlineView.outlineTableColumn = sourcesOutlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
        sourcesOutlineView.autoresizesOutlineColumn = false

        let checkboxCell = SMMNonHighlightingButtonCell(textCell: "")
        checkboxCell.setButtonType(.switch)
        checkboxCell.controlSize = .small
        checkboxCell.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        checkboxCell.allowsMixedState = false
        sourcesOutlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "enabled"))?.dataCell = checkboxCell

        let textFieldCell = SMMNonHighlightingTextFieldCell(textCell: "")
        textFieldCell.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        sourcesOutlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name"))?.dataCell = textFieldCell

        voiceMessagesCheckBox.allowsMixedState = true
        systemCommonCheckBox.allowsMixedState = true
        realTimeCheckBox.allowsMixedState = true

        (maxMessageCountField.formatter as! NumberFormatter).allowsFloats = false
        (oneChannelField.formatter as! NumberFormatter).allowsFloats = false

        messagesTableView.autosaveName = "MessagesTableView2"
        messagesTableView.autosaveTableColumns = true
        messagesTableView.target = self
        messagesTableView.doubleAction = #selector(self.showDetailsOfSelectedMessages(_:))

        hideSysExProgressIndicator()
    }

    override var document: AnyObject? {
        didSet {
            guard let document = document else { return }
            guard let smmDocument = document as? SMMDocument else { fatalError() }

            _ = self.window // Make sure the window and all views are loaded first

            updateMessages(scrollingToBottom: false)
            updateSources()
            updateMaxMessageCount()
            updateFilterControls()

            if let windowSettings = smmDocument.windowSettings as? [String:AnyObject] {
                restoreWindowSettings(windowSettings)
            }
        }
    }

    private var midiDocument: SMMDocument {
        return document as! SMMDocument
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

extension SMMMonitorWindowController {

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

extension SMMMonitorWindowController: NSOutlineViewDataSource, NSOutlineViewDelegate {

    // MARK: Input Sources Outline View

    @objc func updateSources() {
        groupedInputSources = midiDocument.groupedInputSources()
        sourcesOutlineView.reloadData()
    }

    @objc func revealInputSources(_ sources: NSSet) {
        // Show the sources first
        sourcesDisclosableView.shown = true
        sourcesDisclosureButton.intValue = 1

        // Of all of the input sources, find the first one which is in the given set.
        // Then expand the outline view to show this source, and scroll it to be visible.
        guard groupedInputSources != nil else { return }
        for group in groupedInputSources! {
            if let itemDict = group as? [String:Any],
               let itemNotExpandableNumber = itemDict["isNotExpandable"] as? NSNumber,
               !itemNotExpandableNumber.boolValue {
                let groupSources = itemDict["sources"] as! [SMInputStreamSource]
                for source in groupSources {
                    if sources.contains(source) {
                        // Found one!
                        sourcesOutlineView.expandItem(group)
                        sourcesOutlineView.scrollRowToVisible(sourcesOutlineView.row(forItem: source))

                        // And now we're done
                        break
                    }
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
            return groupedInputSources?.count ?? 0
        }
        else if let itemDict = item as? [String:Any] {
            let itemSources = itemDict["sources"] as! [Any]
            return itemSources.count
        }
        else {
            return 0
        }
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return groupedInputSources![index]
        }
        else {
            let itemDict = item as! [String:Any]
            let itemSources = itemDict["sources"] as! [Any]
            return itemSources[index]
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let itemDict = item as? [String:Any],
           let itemNotExpandableNumber = itemDict["isNotExpandable"] as? NSNumber {
            return !itemNotExpandableNumber.boolValue
        }
        else {
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        let identifier = tableColumn?.identifier.rawValue
        let itemDict = item as? [String:Any]
        let isCategory = itemDict != nil

        switch identifier {
        case "name":
            if isCategory {
                return itemDict!["name"]
            }
            else {
                let source: SMInputStreamSource = item as! SMInputStreamSource
                let name = source.inputStreamSourceName()!
                let externalDeviceNames =  source.inputStreamSourceExternalDeviceNames() as! [String]
                if externalDeviceNames.count > 0 {
                    return "\(name)—\(externalDeviceNames.joined(separator:", "))"
                }
                else {
                    return name
                }
            }

        case "enabled":
            let sources: [SMInputStreamSource]
            if isCategory {
                sources = itemDict!["sources"] as! [SMInputStreamSource]
            }
            else {
                sources = [item] as! [SMInputStreamSource]
            }
            return buttonStateForInputSources(sources)

        default:
            return nil
        }
    }

    func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, byItem item: Any?) {
        let number = object as! NSNumber
        var newState = NSCell.StateValue(rawValue: number.intValue)
        // It doesn't make sense to switch from off to mixed, so go directly to on
        if newState == NSCell.StateValue.mixed {
            newState = NSCell.StateValue.on
        }

        let itemDict = item as? [String:Any]
        let isCategory = itemDict != nil

        let sources: [SMInputStreamSource]
        if isCategory {
            sources = itemDict!["sources"] as! [SMInputStreamSource]
        }
        else {
            sources = [item] as! [SMInputStreamSource]
        }

        var newSelectedSources = midiDocument.selectedInputSources
        // TODO this should be a set and we should do union or remove
        if newState == .on {
            for source in sources {
                newSelectedSources?.insert(source as! AnyHashable)
            }
        }
        else {
            for source in sources {
                newSelectedSources?.remove(source as! AnyHashable)
            }
        }

        midiDocument.selectedInputSources = newSelectedSources
    }

    func outlineView(_ outlineView: NSOutlineView, willDisplayOutlineCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        // cause the button cell to always use a "dark" triangle
        (cell as! NSCell).backgroundStyle = .light
    }

    private func buttonStateForInputSources(_ sources: [SMInputStreamSource]) -> NSCell.StateValue {
        guard let selectedSources = midiDocument.selectedInputSources else { return .off }

        var areAnySelected = false
        var areAnyNotSelected = false

        for source in sources {
            if selectedSources.contains(source as! AnyHashable) {
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

extension SMMMonitorWindowController {

    // MARK: Filter

    @objc func updateFilterControls() {
        // TODO this is clumsy
        let currentMask = midiDocument.filterMask().rawValue

        for checkbox in filterCheckboxes {
            let buttonMask = UInt32(checkbox.tag)

            let newState: NSControl.StateValue
            if (currentMask & buttonMask) == buttonMask {
                newState = .on
            }
            else if (currentMask & buttonMask) == 0 {
                newState = .off
            }
            else {
                newState = .mixed
            }

            checkbox.state = newState
        }

        for checkbox in filterMatrixCells {
            let buttonMask = UInt32(checkbox.tag)

            let newState: NSControl.StateValue
            if (currentMask & buttonMask) == buttonMask {
                newState = .on
            }
            else {
                newState = .off
            }

            checkbox.state = newState
        }

        if midiDocument.isShowingAllChannels() {
            channelRadioButtons.selectCell(withTag: 0)
            oneChannelField.isEnabled = false
        }
        else {
            channelRadioButtons.selectCell(withTag: 1)
            oneChannelField.isEnabled = true
            oneChannel = midiDocument.oneChannelToShow()
        }
        oneChannelField.objectValue = NSNumber(value: oneChannel)
    }

    @IBAction func toggleFilterShown(_ sender: AnyObject?) {
        filterDisclosableView.toggleDisclosure(sender)
        trivialWindowSettingsDidChange()
    }

    @IBAction func changeFilter(_ sender: AnyObject?) {
        let button = sender as! NSButton

        let turnBitsOn: Bool
        switch button.state {
        case .on, .mixed:
            turnBitsOn = true
        default:
            turnBitsOn = false
        }

        midiDocument.changeFilterMask(SMMessageType(UInt32(button.tag)), turnBitsOn: turnBitsOn)
    }

    @IBAction func changeFilterFromMatrix(_ sender: AnyObject?) {
        let matrix = sender as! NSMatrix
        self.changeFilter(matrix.selectedCell())
    }

    @IBAction func setChannelRadioButton(_ sender: AnyObject?) {
        let matrix = sender as! NSMatrix
        if matrix.selectedCell()?.tag == 0 {
            midiDocument.showAllChannels()
        }
        else {
            midiDocument.showOnlyOneChannel(oneChannel)
        }
    }

    @IBAction func setChannel(_ sender: AnyObject?) {
        let control = sender as! NSControl
        let channel = (control.objectValue as? NSNumber)?.uintValue ?? 0
        midiDocument.showOnlyOneChannel(channel)
    }

}

extension SMMMonitorWindowController: NSTableViewDataSource {

    // MARK: Messages Table View

    @objc func updateMaxMessageCount() {
        maxMessageCountField.objectValue = NSNumber(value: midiDocument.maxMessageCount)
    }

    @objc func updateSysExReadIndicator(bytesRead: Int) {
        showSysExProgressIndicator()
    }

    @objc func stopSysExReadIndicator(bytesRead: Int) {
        hideSysExProgressIndicator()
    }

    @objc func updateMessages(scrollingToBottom: Bool) {
        // Reloading the NSTableView can be excruciatingly slow, and if messages are coming in quickly,
        // we will hog a lot of CPU. So we make sure that we don't do it too often.

        if scrollingToBottom {
            messagesNeedScrollToBottom = true
        }

        if nextMessagesRefreshTimer != nil {
            // We're going to refresh soon, so don't do anything now.
            return
        }

        let ti = nextMessagesRefreshDate?.timeIntervalSinceNow ?? 0
        if ti <= 0 {
            // Refresh right away, since we haven't recently.
            refreshMessagesTableView()
        }
        else {
            // We have refreshed recently.
            // Schedule an event to make us refresh when we are next allowed to do so.
            nextMessagesRefreshTimer = Timer.scheduledTimer(timeInterval: ti, target: self, selector: #selector(self.refreshMessagesTableViewFromTimer(_:)), userInfo: nil, repeats: false)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedMessages.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let message = displayedMessages[row]

        switch tableColumn?.identifier.rawValue {
        case "timeStamp":
            return message.timeStampForDisplay()
        case "source":
            return message.originatingEndpointForDisplay()
        case "type":
            return message.typeForDisplay()
        case "channel":
            return message.channelForDisplay()
        case "data":
            if UserDefaults.standard.bool(forKey: SMExpertModePreferenceKey) {
                return message.expertDataForDisplay()
            }
            else {
                return message.dataForDisplay()
            }
        default:
            return nil
        }
    }

    @IBAction func clearMessages(_ sender: AnyObject?) {
        midiDocument.clearSavedMessages()
    }

    @IBAction func setMaximumMessageCount(_ sender: AnyObject?) {
        let control = sender as! NSControl
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
            let columnStrings = columns.map { (column) -> String in tableView(messagesTableView, objectValueFor: column, row: row) as! String
            }
            return columnStrings.joined(separator: "\t")
        }
        let totalString = rowStrings.joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(totalString, forType: .string)
    }

    @IBAction func showDetailsOfSelectedMessages(_ sender: AnyObject?) {
        for message in selectedMessages {
            midiDocument.detailsWindowController(for: message)?.showWindow(nil)
        }
    }

    @objc private func displayPreferencesDidChange(_ notification: NSNotification) {
        messagesTableView.reloadData()
    }

    private var selectedMessages: [SMMessage] {
        return messagesTableView.selectedRowIndexes.map { displayedMessages[$0] }
    }

    private func refreshMessagesTableView() {
        updateDisplayedMessages()

        // Scroll to the botton, iff the table view is already scrolled to the bottom.
        let isAtBottom = messagesTableView.bounds.maxY - messagesTableView.visibleRect.maxY < messagesTableView.rowHeight

        messagesTableView.reloadData()

        if messagesNeedScrollToBottom && isAtBottom {
            let messageCount = displayedMessages.count
            if messageCount > 0 {
                messagesTableView.scrollRowToVisible(messageCount - 1)
            }
        }

        messagesNeedScrollToBottom = false

        // Figure out when we should next be allowed to refresh.
        nextMessagesRefreshDate = NSDate(timeIntervalSinceNow: minimumMessagesRefreshDelay)
    }

    @objc private func refreshMessagesTableViewFromTimer(_ timer: Timer) {
        nextMessagesRefreshTimer = nil
        refreshMessagesTableView()
    }

    private func updateDisplayedMessages() {
        displayedMessages = midiDocument.savedMessages() as! [SMMessage]
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

extension SMMMonitorWindowController {

    // MARK: Window settings

    private static let sourcesShownKey = "areSourcesShown"
    private static let filterShownKey = "isFilterShown"
    private static let windowFrameKey = "windowFrame"
    private static let messagesScrollPointX = "messagesScrollPointX"
    private static let messagesScrollPointY = "messagesScrollPointY"

    @objc static var windowSettingsKeys: [String] {
        return [sourcesShownKey, filterShownKey, windowFrameKey, messagesScrollPointX, messagesScrollPointY]
    }

    @objc var windowSettings: [String:AnyObject] {
        var windowSettings: [String:AnyObject] = [:]

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
            windowSettings[Self.messagesScrollPointX] = NSNumber(value:Double(scrollPoint.x))
            windowSettings[Self.messagesScrollPointY] = NSNumber(value:Double(scrollPoint.y))
        }

        return windowSettings
    }

    private func restoreWindowSettings(_ windowSettings: [String:AnyObject]) {
        // Restore visibility of disclosable sections
        let sourcesShown = (windowSettings[Self.sourcesShownKey] as? NSNumber)?.boolValue ?? false
        sourcesDisclosureButton.intValue = sourcesShown ? 1 : 0
        sourcesDisclosableView.shown = sourcesShown

        let filterShown = (windowSettings[Self.filterShownKey] as? NSNumber)?.boolValue ?? false
        filterDisclosureButton.intValue = filterShown ? 1 : 0
        filterDisclosableView.shown = filterShown

        // Then, since those may have resized the window, set the frame back to what we expect.
        if let windowFrame = windowSettings[Self.windowFrameKey] as? String {
            window?.setFrame(from: windowFrame)
        }

        if let scrollX = windowSettings[Self.messagesScrollPointX] as? NSNumber,
           let scrollY = windowSettings[Self.messagesScrollPointY] as? NSNumber {
            let scrollPoint = NSPoint(x: scrollX.doubleValue, y: scrollY.doubleValue)
            messagesTableView.scroll(scrollPoint)
        }
    }

}
