/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

open class InputStream {

    public init(midiContext: MIDIContext) {
        self.midiContext = midiContext
    }

    public let midiContext: MIDIContext
    public weak var delegate: InputStreamDelegate?
    public weak var messageDestination: MessageDestination?
    public var sysExTimeOut: TimeInterval = 1.0 {
        didSet {
            parsers.forEach { $0.sysExTimeOut = sysExTimeOut }
        }
    }

    public func cancelReceivingSysExMessage() {
        parsers.forEach { $0.cancelReceivingSysExMessage() }
    }

    open var persistentSettings: Any? {
        var persistentSettings: [[String: Any]] = []
        for inputSource in selectedInputSources {
            var dict: [String: Any] = [:]
            if let uniqueID = inputSource.uniqueID {
                dict["uniqueID"] = uniqueID
            }
            if let name = inputSource.name {
                dict["name"] = name
            }
            if !dict.isEmpty {
                persistentSettings.append(dict)
            }
        }
        return persistentSettings
    }

    open func takePersistentSettings(_ settings: Any) -> [String] {
        // If any endpoints couldn't be found, their names are returned

        guard let dicts = settings as? [[String: Any]] else { return [] }

        var newInputSources: Set<InputStreamSource> = []
        var missingNames: [String] = []
        for dict in dicts {
            let name = dict["name"] as? String
            let uniqueID = dict["uniqueID"] as? MIDIUniqueID
            if let source = findInputSource(name: name, uniqueID: uniqueID) {
                newInputSources.insert(source)
            }
            else {
                let resolvedName = name ?? NSLocalizedString("Unknown", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "name of missing endpoint if not specified in document")
                missingNames.append(resolvedName)
            }
        }

        selectedInputSources = newInputSources

        return missingNames
    }

    // MARK: For subclass use only

    // FUTURE: It would be nice to implement the functionality of our subclasses via composition instead
    // of inheritance. When doing so, these subclass-related methods will perhaps get put in a protocol.

    // MIDIReadBlock to be passed to functions like MIDIInputPortCreateWithBlock()
    public lazy var midiReadBlock: MIDIReadBlock = { [weak self] (packetListPtr, srcConnRefCon) in
        // NOTE: This function is called in a high-priority, time-constraint thread,
        // created for us by CoreMIDI.

        // NOTE: Needs to be lazy in order to capture self as a weak reference.

        self?.midiRead(packetListPtr, srcConnRefCon)
    }

    public func createParser(originatingEndpoint: Endpoint?) -> MessageParser {
        let parser = MessageParser()
        parser.delegate = self
        parser.sysExTimeOut = sysExTimeOut
        parser.originatingEndpoint = originatingEndpoint
        return parser
    }

    public func sourceListChanged() {
        delegate?.inputStreamSourceListChanged(self)
    }

    // MARK: For subclasses to implement

    open var parsers: [MessageParser] {
        fatalError("Must implement in subclass")
    }

    open func parser(sourceConnectionRefCon: UnsafeMutableRawPointer?) -> MessageParser? {
        fatalError("Must implement in subclass")
    }

    open func streamSource(parser: MessageParser) -> InputStreamSource? {
        fatalError("Must implement in subclass")
    }

    open var inputSources: [InputStreamSource] {
        fatalError("Must implement in subclass")
    }

    // For convenience when working with `selectedInputSources`
    public var inputSourcesSet: Set<InputStreamSource> {
        return Set(inputSources)
    }

    open var selectedInputSources: Set<InputStreamSource> {
        get {
            fatalError("Must implement in subclass")
        }
        set {   // swiftlint:disable:this unused_setter_value
            fatalError("Must implement in subclass")
        }
    }

}

extension InputStream: MessageParserDelegate {

    public func parserDidReadMessages(_ parser: MessageParser, messages: [Message]) {
        messageDestination?.takeMIDIMessages(messages)
    }

    public func parserIsReadingSysEx(_ parser: MessageParser, length: Int) {
        if let streamSource = streamSource(parser: parser) {
            delegate?.inputStreamReadingSysEx(self, byteCountSoFar: length, streamSource: streamSource)
        }
    }

    public func parserFinishedReadingSysEx(_ parser: MessageParser, message: SystemExclusiveMessage) {
        if let streamSource = streamSource(parser: parser) {
            delegate?.inputStreamFinishedReadingSysEx(self, byteCount: 1 + message.receivedData.count, streamSource: streamSource, isValid: message.wasReceivedWithEOX)
        }
    }

}

extension InputStream /* Private */ {

    private func findInputSource(name: String?, uniqueID: MIDIUniqueID?) -> InputStreamSource? {
        // Find the input source with the desired unique ID. If there are no matches by uniqueID, return the first source whose name matches.
        // Otherwise, return nil.
        if let uniqueID,
           let match = inputSources.first(where: { $0.uniqueID == uniqueID }) {
            return match
        }
        else if let name,
                let match = inputSources.first(where: { $0.name == name }) {
            return match
        }
        else {
            return nil
        }
    }

    fileprivate func midiRead(_ packetListPtr: UnsafePointer<MIDIPacketList>, _ srcConnRefCon: UnsafeMutableRawPointer?) {
        // NOTE: This function is called in a high-priority, time-constraint thread,
        // created for us by CoreMIDI.
        //
        // Because we're in a time-constraint thread, we should avoid allocating memory,
        // since the allocator uses a single app-wide lock. (If another low-priority thread holds
        // that lock, we'll have to wait for that thread to release it, which is priority inversion.)
        // We're not even attempting to do that yet, because neither MIDI Monitor nor SysEx Librarian
        // need that level of performance. (Probably the best solution is to stuff the packet list
        // into a ring buffer, then consume it in the other queue, but the devil is in the details.)

        let numPackets = packetListPtr.pointee.numPackets
        guard numPackets > 0 else { return }

        let packetListSize: Int
        if #available(macOS 10.15, iOS 13.0, *) {
            packetListSize = MIDIPacketList.sizeInBytes(pktList: packetListPtr)
        }
        else {
            packetListSize = SMPacketListSize(packetListPtr)
        }

        // Copy the packet data for later
        let data = Data(bytes: packetListPtr, count: packetListSize)

        // And process it on the queue
        DispatchQueue.main.async {
            autoreleasepool {
                data.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
                    let packetListPtr = rawPtr.bindMemory(to: MIDIPacketList.self).baseAddress!

                    // Find the parser that is associated with this particular connection
                    // (which may be nil, if the input stream was disconnected from this source)
                    // and give it the packet list.
                    self.parser(sourceConnectionRefCon: srcConnRefCon)?.takePacketList(packetListPtr)
                }
            }
        }
    }

}

public protocol InputStreamDelegate: NSObjectProtocol {

    // Sent when the stream begins or continues receiving a SystemExclusive message
    func inputStreamReadingSysEx(_ stream: InputStream, byteCountSoFar: Int, streamSource: InputStreamSource)

    // Sent when the stream finishes receiving a SystemExclusive message
    func inputStreamFinishedReadingSysEx(_ stream: InputStream, byteCount: Int, streamSource: InputStreamSource, isValid: Bool)

    func inputStreamSourceListChanged(_ stream: InputStream)

}
