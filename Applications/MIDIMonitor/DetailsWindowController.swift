/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class DetailsWindowController: UtilityWindowController {

    let message: Message

    init(message: Message) {
        self.message = message
        super.init(window: nil)
        if let windowNibName {
            windowFrameAutosaveName = windowNibName
        }
        shouldCascadeWindows = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.displayPreferencesDidChange(_:)), name: .displayPreferenceChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .displayPreferenceChanged, object: nil)
    }

    //
    // To be overridden by subclasses
    //

    override var windowNibName: NSNib.Name? {
        "Details"
    }

    var dataForDisplay: Data {
        message.fullData
    }

    //
    // Private
    //

    @IBOutlet private var timeField: NSTextField!
    @IBOutlet private var sizeField: NSTextField!
    @IBOutlet private var dataContainerView: NSView!

    private let dataController = HFController()
    private let dataLayoutRep = HFLayoutRepresenter()

    override func windowDidLoad() {
        super.windowDidLoad()

        updateDescriptionFields()

        dataController.editable = false
        dataController.savable = false

        let byteSlice = HFFullMemoryByteSlice(data: dataForDisplay)
        let byteArray = HFBTreeByteArray()
        byteArray.insertByteSlice(byteSlice, in: HFRange(location: 0, length: 0))
        dataController.byteArray = byteArray

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
    }

    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        let format = NSLocalizedString("%@ Details", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "Details window title format string")
        return String.localizedStringWithFormat(format, displayName)
    }

    @objc func displayPreferencesDidChange(_ notification: Notification) {
        updateDescriptionFields()
    }

    private func updateDescriptionFields() {
        let format = NSLocalizedString("%@ bytes", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "Details size format string")
        let formattedLength = MessageFormatter.formatLength(dataForDisplay.count)
        let sizeString = String.localizedStringWithFormat(format, formattedLength)

        sizeField.stringValue = sizeString
        timeField.stringValue = message.timeStampForDisplay
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

    private func autosaveCurrentWindowFrame() {
        // Work around an AppKit bug: the frame that gets saved in NSUserDefaults is the window's old position, not the new one.
        // We get notified after the window has been moved/resized and the defaults changed.
        if let window {
            window.saveFrame(usingName: window.frameAutosaveName)
        }
    }

}

extension DetailsWindowController: NSWindowDelegate {

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        guard let midiDocument = document as? Document else { return }
        midiDocument.encodeRestorableState(state, for: self)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        minimumWindowSize(frameSize)
    }

    func windowDidResize(_ notification: Notification) {
        autosaveCurrentWindowFrame()
    }

    func windowDidMove(_ notification: Notification) {
        autosaveCurrentWindowFrame()
    }

}
