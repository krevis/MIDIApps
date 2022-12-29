/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class DetailsWindowController: GeneralWindowController {

    static func showWindow(forEntry entry: LibraryEntry) {
        var controller = controllers.first(where: { $0.entry == entry })
        if controller == nil {
            let newController = DetailsWindowController(entry: entry)
            controllers.append(newController)
            controller = newController
        }

        controller?.showWindow(nil)
    }

    init(entry: LibraryEntry) {
        self.entry = entry
        self.cachedMessages = entry.messages

        super.init(window: nil)
        shouldCascadeWindows = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.entryWillBeRemoved(_:)), name: .libraryEntryWillBeRemoved, object: entry)
        NotificationCenter.default.addObserver(self, selector: #selector(self.entryNameDidChange(_:)), name: .libraryEntryNameDidChange, object: entry)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return "Details"
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Setting the autosave name in the nib causes it to not restore to the exact original position.
        // Doing it here works more consistently. Suggested by: https://stackoverflow.com/a/30101966/1218876
        splitView.autosaveName = "Details"

        synchronizeTitle()

        messagesTableView.reloadData()
        if cachedMessages.count > 0 {
            messagesTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        dataController.editable = false
        dataController.savable = false

        dataController.addRepresenter(dataLayoutRep)
        let innerReps: [HFRepresenter] = [ HFLineCountingRepresenter(), HFHexTextRepresenter(), HFStringEncodingTextRepresenter(), HFVerticalScrollerRepresenter() ]
        innerReps.forEach { dataController.addRepresenter($0) }
        innerReps.forEach { dataLayoutRep.addRepresenter($0) }

        let layoutView = dataLayoutRep.view()
        layoutView.frame = dataContainerView.bounds
        layoutView.autoresizingMask = [.width, .height]
        dataContainerView.addSubview(layoutView)

        if let window {
            // Tweak the window's minSize to match the data layout.
            let bytesPerLine = dataLayoutRep.maximumBytesPerLineForLayout(inProposedWidth: window.minSize.width)
            let minWidth = dataLayoutRep.minimumViewWidth(forBytesPerLine: bytesPerLine)
            window.minSize = NSSize(width: minWidth, height: window.minSize.height)

            // Then ensure the window is sized to fit the layout and that minSize
            var windowFrame = window.frame
            windowFrame.size = minimumWindowSize(windowFrame.size)
            window.setFrame(windowFrame, display: true)
        }

        synchronizeMessageDataDisplay()
    }

    // MARK: Private

    static private var controllers: [DetailsWindowController] = []
    private let entry: LibraryEntry
    private let cachedMessages: [SystemExclusiveMessage]

    @IBOutlet private var splitView: NSSplitView!
    @IBOutlet private var messagesTableView: NSTableView!
    @IBOutlet private var dataContainerView: NSView!
    @IBOutlet private var md5ChecksumField: NSTextField!
    @IBOutlet private var sha1ChecksumField: NSTextField!

    private let dataController = HFController()
    private let dataLayoutRep = HFLayoutRepresenter()

    private func synchronizeMessageDataDisplay() {
        let selectedRow = messagesTableView.selectedRow
        let data: Data
        if selectedRow >= 0 {
            data = cachedMessages[selectedRow].receivedDataWithStartByte
        }
        else {
            data = Data()
        }

        let byteSlice = HFFullMemoryByteSlice(data: data)
        let byteArray = HFBTreeByteArray()
        byteArray.insertByteSlice(byteSlice, in: HFRange(location: 0, length: 0))
        dataController.byteArray = byteArray

        md5ChecksumField.stringValue = data.count > 0 ? data.md5HexHash : ""
        sha1ChecksumField.stringValue = data.count > 0 ? data.sha1HexHash : ""
    }

    private func minimumWindowSize(_ proposedWindowFrameSize: NSSize) -> NSSize {
        // Resize to a size that will exactly fit the layout, with no extra space on the trailing side.
        let layoutView = dataLayoutRep.view()
        let proposedSizeInLayoutCoordinates = layoutView.convert(proposedWindowFrameSize, from: nil)
        let resultingWidthInLayoutCoordinates = dataLayoutRep.minimumViewWidthForLayout(inProposedWidth: proposedSizeInLayoutCoordinates.width)
        var resultingSize = layoutView.convert(NSSize(width: resultingWidthInLayoutCoordinates, height: proposedSizeInLayoutCoordinates.height), to: nil)

        // But ensure we don't get smaller than the window's minSize.
        if let window {
            resultingSize.width = Swift.max(resultingSize.width, window.minSize.width)
            resultingSize.height = Swift.max(resultingSize.height, window.minSize.height)
        }

        return resultingSize
    }

    private func synchronizeTitle() {
        window?.title = entry.name ?? ""
        window?.representedFilename = entry.path ?? ""
    }

    @objc private func entryWillBeRemoved(_ notification: Notification) {
        close()
    }

    @objc private func entryNameDidChange(_ notification: Notification) {
        synchronizeTitle()
    }

}

extension DetailsWindowController /* NSWindowDelegate */ {

    func windowWillClose(_ notification: Notification) {
        Self.controllers.removeAll { $0 == self }
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        minimumWindowSize(frameSize)
    }

}

extension DetailsWindowController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        cachedMessages.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < cachedMessages.count else { return nil }
        let message = cachedMessages[row]

        switch tableColumn?.identifier.rawValue {
        case "index":
            return row + 1
        case "manufacturer":
            return message.manufacturerName
        case "sizeDecimal":
            return MessageFormatter.formatLength(message.receivedDataWithStartByteLength, usingOption: .decimal)
        case "sizeHex":
            return MessageFormatter.formatLength(message.receivedDataWithStartByteLength, usingOption: .hexadecimal)
        case "sizeAbbreviated":
            return String.abbreviatedByteCount(message.receivedDataWithStartByteLength)
        default:
            return nil
        }
    }

}

extension DetailsWindowController: NSTableViewDelegate {

    func tableViewSelectionDidChange(_ notification: Notification) {
        synchronizeMessageDataDisplay()
    }

    func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        // Don't allow an empty selection
        if proposedSelectionIndexes.count == 0 {
            return tableView.selectedRowIndexes
        }
        else {
            return proposedSelectionIndexes
        }
    }

}

private let minMessagesViewHeight = CGFloat(40.0)
private let minDataViewHeight = CGFloat(80.0)

extension DetailsWindowController: NSSplitViewDelegate {

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMinimumPosition + minMessagesViewHeight
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        proposedMaximumPosition - minDataViewHeight
    }

    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        splitView.adjustSubviews()

        guard splitView.subviews.count >= 2 else { return }
        let view1 = splitView.subviews[0]
        let view2 = splitView.subviews[1]
        let v1Frame = view1.frame
        let v2Frame = view2.frame
        let dividerThickness = splitView.dividerThickness
        let boundsHeight = splitView.bounds.size.height

        if v1Frame.size.height < minMessagesViewHeight {
            view1.frame = CGRect(x: v1Frame.origin.x,
                                 y: 0,
                                 width: v1Frame.size.width,
                                 height: minMessagesViewHeight
            )
            view2.frame = CGRect(x: v2Frame.origin.x,
                                 y: minMessagesViewHeight + dividerThickness,
                                 width: v2Frame.size.width,
                                 height: boundsHeight - (dividerThickness + minMessagesViewHeight)
            )
        }
        else if v2Frame.size.height < minDataViewHeight {
            view1.frame = CGRect(x: v1Frame.origin.x,
                                 y: 0,
                                 width: v1Frame.size.width,
                                 height: boundsHeight - (dividerThickness + minDataViewHeight)
            )
            view2.frame = CGRect(x: v2Frame.origin.x,
                                 y: boundsHeight - minDataViewHeight,
                                 width: v2Frame.size.width,
                                 height: minDataViewHeight
            )
        }
    }

}
