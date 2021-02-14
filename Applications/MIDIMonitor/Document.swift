/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa
import SnoizeMIDI

class Document: NSDocument {

    override init() {
        guard let context = (NSApp.delegate as? AppController)?.midiContext else { fatalError() }
        stream = CombinationInputStream(midiContext: context)

        super.init()

        let center = NotificationCenter.default

        center.addObserver(self, selector: #selector(self.readingSysEx(_:)), name: .inputStreamReadingSysEx, object: stream)
        center.addObserver(self, selector: #selector(self.doneReadingSysEx(_:)), name: .inputStreamDoneReadingSysEx, object: stream)
        center.addObserver(self, selector: #selector(self.sourceListDidChange(_:)), name: .inputStreamSourceListChanged, object: stream)
        updateVirtualEndpointName()

        stream.messageDestination = messageFilter
        messageFilter.filterMask = Message.TypeMask.all
        messageFilter.channelMask = VoiceMessage.ChannelMask.all

        messageFilter.messageDestination = history
        center.addObserver(self, selector: #selector(self.historyDidChange(_:)), name: .messageHistoryChanged, object: history)

        // If the user changed the value of this old obsolete preference, bring its value forward to our new preference
        // (the default value was YES)
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: PreferenceKeys.selectFirstSourceInNewDocument) {
            defaults.setValue(false, forKey: PreferenceKeys.selectOrdinarySourcesInNewDocument)
            defaults.setValue(true, forKey: PreferenceKeys.selectFirstSourceInNewDocument)
        }

        autoselectSources()

        updateChangeCount(.changeCleared)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Private

    private let midiMonitorFileType = "com.snoize.midimonitor"
    private let midiMonitorErrorDomain = "com.snoize.midimonitor"

    private(set) var windowSettings: [String: Any]?

    // MIDI processing
    private let stream: CombinationInputStream
    private let messageFilter = MessageFilter()
    private let history = MessageHistory()

    // Transient data
    private var isSysExUpdateQueued = false

}

extension Document {

    // MARK: Document data (read and write)

    override class var autosavesInPlace: Bool {
        return true
    }

    override func data(ofType typeName: String) throws -> Data {
        guard typeName == midiMonitorFileType else { throw badFileTypeError }

        var dict: [String: Any] = [:]
        dict["version"] = 2

        if let streamSettings = stream.persistentSettings {
            dict["streamSettings"] = streamSettings
        }

        let historySize = history.historySize
        if historySize != MessageHistory.defaultHistorySize {
            dict["maxMessageCount"] = historySize
        }

        let filterMask = messageFilter.filterMask
        if filterMask != Message.TypeMask.all {
            dict["filterMask"] = filterMask.rawValue
        }

        let channelMask = messageFilter.channelMask
        if channelMask != VoiceMessage.ChannelMask.all {
            dict["channelMask"] = channelMask.rawValue
        }

        let savedMessages = history.savedMessages
        if savedMessages.count > 0 {
            // Was: dict["messageData"] = NSKeyedArchiver.archivedData(withRootObject: savedMessages)
            // Except: After the Swift migration, we now need to map from the Swift classes
            // to the ObjC class names. So we have to do this the hard way.
            let mutableData = NSMutableData()
            let archiver = NSKeyedArchiver(forWritingWith: mutableData)
            Message.prepareToEncodeWithObjCCompatibility(archiver: archiver)
            archiver.encode(savedMessages, forKey: NSKeyedArchiveRootObjectKey)
            archiver.finishEncoding()
            dict["messageData"] = mutableData
        }

        if let windowSettings = monitorWindowController?.windowSettings {
            dict.merge(windowSettings) { (_, new) in new }
        }

        return try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard typeName == midiMonitorFileType else { throw badFileTypeError }

        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard let dict = propertyList as? [String: Any] else { throw badFileContentsError }

        if let settings = try readStreamSettings(dict) {
            _ = stream.takePersistentSettings(settings)
            monitorWindowController?.updateSources()
        }
        else {
            selectedInputSources = []
        }

        maxMessageCount = (dict["maxMessageCount"] as? NSNumber)?.intValue ?? MessageHistory.defaultHistorySize

        if let number = dict["filterMask"] as? NSNumber {
            filterMask = Message.TypeMask(rawValue: number.intValue)
        }
        else {
            filterMask = Message.TypeMask.all
        }

        if let number = dict["channelMask"] as? NSNumber {
            channelMask = VoiceMessage.ChannelMask(rawValue: number.intValue)
        }
        else {
            channelMask = VoiceMessage.ChannelMask.all
        }

        if let messageData = dict["messageData"] as? Data {
            // Was: messages = NSKeyedUnarchiver.unarchiveObject(with: messageData) as? [Message]
            // Except: After the Swift migration, we now need to map from the ObjC class names
            // to the Swift classes. So we have to do this the hard way.
            let unarchiver = NSKeyedUnarchiver(forReadingWith: messageData)
            Message.prepareToDecodeWithObjCCompatibility(unarchiver: unarchiver)
            let decoded = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey)
            unarchiver.finishDecoding()
            if let messages = decoded as? [Message] {
                history.savedMessages = messages
            }
        }

        var readWindowSettings: [String: Any] = [:]
        for key in MonitorWindowController.windowSettingsKeys {
            if let obj = dict[key] {
                readWindowSettings[key] = obj
            }
        }
        windowSettings = readWindowSettings

        // Doing the above caused undo actions to be remembered, but we don't want the user to see them
        updateChangeCount(.changeCleared)
    }

    private func readStreamSettings(_ dict: [String: Any]) throws -> [String: Any]? {
        var streamSettings: [String: Any]?
        let version = dict["version"] as? Int ?? 0
        switch version {
        case 1:
            if let number = dict["sourceEndpointUniqueID"] as? NSNumber {
                var settings: [String: Any] = ["portEndpointUniqueID": number]
                if let endpointName = dict["sourceEndpointName"] {
                    settings["portEndpointName"] = endpointName
                }
                streamSettings = settings
            }
            else if let number = dict["virtualDestinationEndpointUniqueID"] as? NSNumber {
                streamSettings = ["virtualEndpointUniqueID": number]
            }

        case 2:
            streamSettings = dict["streamSettings"] as? [String: Any]

        default:
            throw badFileContentsError
        }

        return streamSettings
    }

    private var badFileTypeError: Error {
        let reason = NSLocalizedString("Unknown file type.", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "error reason for unknown file type read or write")
        return NSError(domain: midiMonitorErrorDomain, code: 1, userInfo: [NSLocalizedFailureReasonErrorKey: reason])
    }

    private var badFileContentsError: Error {
        let reason = NSLocalizedString("Can't read the contents of the file.", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "error reason for unknown file contents")
        return NSError(domain: midiMonitorErrorDomain, code: 2, userInfo: [NSLocalizedFailureReasonErrorKey: reason])
    }

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        // Clear the undo stack whenever we load or save.
        super.updateChangeCount(change)
        if change == .changeCleared {
            self.undoManager?.removeAllActions()
        }
    }

    override var fileURL: URL? {
        didSet {
            updateVirtualEndpointName()
        }
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        // It's easy for us to dirty the document, but the user may not generally care to save the documents.
        // Pay attention to the user's preference for whether or not to warn when closing a dirty document.

        var mayCloseWithoutSaving = false

        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "NSCloseAlwaysConfirmsChanges") {
            // The system preference for "Ask to keep changes when closing documents" is turned ON.
            // Therefore, our documents are not automatically saved. It makes sense to apply our
            // preference to all documents.
            mayCloseWithoutSaving = true
        }
        else {
            // The system preference for "Ask to keep changes when closing documents" is turned OFF.
            // Documents are automatically saved. However, if they are untitled (never saved anywhere),
            // then closing the window will ask to save.
            if self.fileURL == nil {
                // This is an untitled document.
                mayCloseWithoutSaving = true
            }
        }

        if mayCloseWithoutSaving && !defaults.bool(forKey: PreferenceKeys.askBeforeClosingModifiedWindow) {
            // Tell the delegate to close now, regardless of what the document's dirty flag may be.
            // Unfortunately this is not easy in Objective-C:
            // void (*objc_msgSendTyped)(id self, SEL _cmd, NSDocument *document, BOOL shouldClose, void *contextInfo) = (void*)objc_msgSend;
            // objc_msgSendTyped(delegate, shouldCloseSelector, self, YES /* close now */, contextInfo);
            // and it's not nice in Swift either. https://stackoverflow.com/a/43553386
            let delegateObject = delegate as AnyObject
            if let selector = shouldCloseSelector,
               let imp = class_getMethodImplementation(type(of: delegateObject), selector) {
                unsafeBitCast(imp, to: (@convention(c)(Any?, Selector, Any?, Bool, Any?)->Void).self)(delegateObject, selector, self, true /*close now */, contextInfo)
            }
        }
        else {
            // Do the same as normal: ask if the user wants to save.
            super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
        }
    }

}

extension Document {

    // MARK: Core document properties

    // NOTE ON UNDOABLE DOCUMENT PROPERTIES:
    // After migrating to Swift, we can no longer easily use NSUndoManager's prepareWithInvocationTarget mechanism.
    // It would be nicer to use block-based undo registration, but that requires macOS 10.11. So, for now, register using selectors,
    // and use a separate @objc-exposed method to do the work.

    var selectedInputSources: Set<InputStreamSource> {
        get {
            return stream.selectedInputSources
        }
        set {
            guard selectedInputSources != newValue else { return }
            undoableSetSelectedInputSources(newValue)
        }
    }

    // TODO But this can't be ObjC
    /*@objc*/ private func undoableSetSelectedInputSources(_ newValue: Set<InputStreamSource>) {
//        if let undoManager = undoManager {
//            undoManager.registerUndo(withTarget: self, selector: #selector(self.undoableSetSelectedInputSources(_:)), object: selectedInputSources)
//            undoManager.setActionName(NSLocalizedString("Change Selected Sources", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "change source undo action"))
//        }

        stream.selectedInputSources = newValue
        monitorWindowController?.updateSources()
    }

    var maxMessageCount: Int {
        get {
            return history.historySize
        }
        set {
            guard newValue != maxMessageCount else { return }
            undoableSetMaxMessageCountNumber(NSNumber(value: newValue))
        }
    }

    @objc private func undoableSetMaxMessageCountNumber(_ number: NSNumber) {
        if let undoManager = undoManager {
            undoManager.registerUndo(withTarget: self, selector: #selector(self.undoableSetMaxMessageCountNumber(_:)), object: NSNumber(value: maxMessageCount))
            undoManager.setActionName(NSLocalizedString("Change Remembered Events", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "change history limit undo action"))
        }

        history.historySize = number.intValue
        monitorWindowController?.updateMaxMessageCount()
    }

    var filterMask: Message.TypeMask {
        get {
            return messageFilter.filterMask
        }
        set {
            guard newValue != filterMask else { return }
            undoableSetFilterMaskNumber(NSNumber(value: newValue.rawValue))
        }
    }

    @objc private func undoableSetFilterMaskNumber(_ number: NSNumber) {
        if let undoManager = undoManager {
            undoManager.registerUndo(withTarget: self, selector: #selector(self.undoableSetFilterMaskNumber(_:)), object: NSNumber(value: filterMask.rawValue))
            undoManager.setActionName(NSLocalizedString("Change Filter", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "change filter undo action"))
        }

        messageFilter.filterMask = Message.TypeMask(rawValue: number.intValue)
        monitorWindowController?.updateFilterControls()
    }

    var channelMask: VoiceMessage.ChannelMask {
        get {
            return messageFilter.channelMask
        }
        set {
            guard newValue != channelMask else { return }
            undoableSetChannelMaskNumber(NSNumber(value: newValue.rawValue))
        }
    }

    @objc private func undoableSetChannelMaskNumber(_ number: NSNumber) {
        if let undoManager = undoManager {
            undoManager.registerUndo(withTarget: self, selector: #selector(self.undoableSetChannelMaskNumber(_:)), object: NSNumber(value: channelMask.rawValue))
            undoManager.setActionName(NSLocalizedString("Change Channel", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "change channel undo action"))
        }

        messageFilter.channelMask = VoiceMessage.ChannelMask(rawValue: number.intValue)
        monitorWindowController?.updateFilterControls()
    }

    var savedMessages: [Message] {
        // Note: The remembered messages are saved with the document, and changes to the messages
        // do dirty the document, but changes are not undoable -- it wouldn't make much sense.
        return history.savedMessages
    }

}

extension Document {

    // MARK: Derived / convenience document functions

    func changeFilterMask(_ maskToChange: Message.TypeMask, turnBitsOn: Bool) {
        var newMask = messageFilter.filterMask.rawValue
        if turnBitsOn {
            newMask |= maskToChange.rawValue
        }
        else {
            newMask &= ~maskToChange.rawValue
        }

        filterMask = Message.TypeMask(rawValue: newMask)
    }

    var isShowingAllChannels: Bool {
        return messageFilter.channelMask == VoiceMessage.ChannelMask.all
    }

    var oneChannelToShow: Int {
        // It is possible that something else could have set the mask to show more than one, or zero, channels.
        // We'll just return the lowest enabled channel (1-16), or 0 if no channel is enabled.

        guard !isShowingAllChannels else { fatalError() }

        let mask = messageFilter.channelMask
        for channel in 1...16 {
            if mask.contains(VoiceMessage.ChannelMask(channel: channel)) {
                return channel
            }
        }

        return 0
    }

    func showAllChannels() {
        channelMask = VoiceMessage.ChannelMask.all
    }

    func showOnlyOneChannel(_ channel: Int) {
        guard (1...16).contains(channel) else { fatalError() }
        channelMask = VoiceMessage.ChannelMask(channel: Int(channel))
    }

    func clearSavedMessages() {
        history.clearSavedMessages()
    }

}

extension Document {

    // MARK: Window controllers

    override func makeWindowControllers() {
        addWindowController(MonitorWindowController())
    }

    var monitorWindowController: MonitorWindowController? {
        return windowControllers.first { $0 is MonitorWindowController } as? MonitorWindowController
    }

    var detailsWindowsControllers: [DetailsWindowController] {
        return windowControllers.filter { $0 is DetailsWindowController } as? [DetailsWindowController] ?? []
    }

    func detailsWindowController(for message: Message) -> DetailsWindowController {
        if let match = detailsWindowsControllers.first(where: { $0.message == message}) {
            return match
        }

        let detailsWindowController: DetailsWindowController
        if message is SystemExclusiveMessage {
            detailsWindowController = SysExWindowController(message: message)
        }
        else {
            detailsWindowController = DetailsWindowController(message: message)
        }
        addWindowController(detailsWindowController)
        return detailsWindowController
    }

    func encodeRestorableState(_ state: NSCoder, for detailsWindowController: DetailsWindowController) {
        if let messageIndex = savedMessages.firstIndex(of: detailsWindowController.message) {
            state.encode(messageIndex, forKey: "messageIndex")
        }
    }

    override func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        if identifier.rawValue == "monitor" {
            super.restoreWindow(withIdentifier: identifier, state: state, completionHandler: completionHandler)
        }
        else {
            var window: NSWindow?

            if let messageIndexNumber = state.decodeObject(forKey: "messageIndex") as? NSNumber {
                let messageIndex = messageIndexNumber.intValue
                if messageIndex < savedMessages.count {
                    window = detailsWindowController(for: savedMessages[messageIndex]).window
                }
            }

            completionHandler(window, nil)
        }
    }

}

extension Document {

    // MARK: Input sources

    var inputSourceGroups: [CombinationInputStreamSourceGroup] {
        return stream.sourceGroups
    }

    private func autoselectSources() {
        let groups = inputSourceGroups
        var sourcesSet = Set<InputStreamSource>()

        let defaults = UserDefaults.standard

        if defaults.bool(forKey: PreferenceKeys.selectOrdinarySourcesInNewDocument) {
            if groups.count > 0 {
                sourcesSet.formUnion(groups[0].sources)
            }
        }

        if defaults.bool(forKey: PreferenceKeys.selectVirtualDestinationInNewDocument) {
            if groups.count > 1 {
                sourcesSet.formUnion(groups[1].sources)
            }
        }

        if defaults.bool(forKey: PreferenceKeys.selectSpyingDestinationsInNewDocument) {
            if groups.count > 2 {
                sourcesSet.formUnion(groups[2].sources)
            }
        }

        selectedInputSources = sourcesSet
    }

    private func updateVirtualEndpointName() {
        let applicationName = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? "MIDI Monitor"
        var virtualEndpointName = applicationName
        if let documentName = displayName { // should always be non-nil, but just in case
            virtualEndpointName += " (\(documentName))"
        }
        stream.virtualEndpointName = virtualEndpointName
    }

}

extension Document {

    // MARK: Updates when changes happen

    @objc private func sourceListDidChange(_ notification: Notification?) {
        monitorWindowController?.updateSources()

        // Also, it's possible that the endpoint names went from being unique to non-unique, so we need
        // to refresh the messages displayed.
        monitorWindowController?.updateVisibleMessages()
    }

    @objc private func historyDidChange(_ notification: Notification?) {
        updateChangeCount(.changeDone)

        if let wereMessagesAdded = notification?.userInfo?[MessageHistory.wereMessagesAdded] as? Bool {
            updateMessages(scrollingToBottom: wereMessagesAdded)
        }
    }

    private func updateMessages(scrollingToBottom: Bool) {
        monitorWindowController?.updateMessages(scrollingToBottom: scrollingToBottom)
    }

    @objc private func readingSysEx(_ notification: Notification?) {
        // We want multiple updates to get coalesced, so only queue it once
        if !isSysExUpdateQueued {
            isSysExUpdateQueued = true
            self.perform(#selector(self.updateSysExReadIndicators), with: nil, afterDelay: 0)
        }
    }

    @objc private func updateSysExReadIndicators() {
        isSysExUpdateQueued = false
        monitorWindowController?.updateSysExReadIndicator()
    }

    @objc private func doneReadingSysEx(_ notification: Notification?) {
        if isSysExUpdateQueued {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.updateSysExReadIndicators), object: nil)
            isSysExUpdateQueued = false
        }

        monitorWindowController?.stopSysExReadIndicator()
    }

}
