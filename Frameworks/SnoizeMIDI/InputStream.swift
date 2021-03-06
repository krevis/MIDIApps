/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

open class InputStream {

    public init(midiContext: MIDIContext) {
        self.midiContext = midiContext

        // Default to main queue for taking pending read packets
        readQueue = DispatchQueue.main
    }

    public let midiContext: MIDIContext
    public var readQueue: DispatchQueue
    public weak var delegate: InputStreamDelegate?
    public weak var messageDestination: MessageDestination?
    public var sysExTimeOut: TimeInterval = 1.0 {
        didSet {
            parsers.forEach { $0.sysExTimeOut = sysExTimeOut }
        }
    }

    public func cancelReceivingSysExMessage() {
        parsers.forEach { _ = $0.cancelReceivingSysExMessage() }
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

    // MIDIReadProc to be passed to functions like MIDIInputPortCreate() on macOS before 10.11
    public let midiReadProc: MIDIReadProc = { (packetListPtr, readProcRefCon, srcConnRefCon) in
        // NOTE: This function is called in a high-priority, time-constraint thread,
        // created for us by CoreMIDI.

        // NOTE: There's a race. The inputStream could get deallocated while this code is running on the MIDI thread,
        // including in this window of time before we fetch and retain it.
        // In macOS 10.11 and later, CoreMIDI's newer block-based callbacks, which allow the inputStream to be captured as a weak
        // reference in a block, is a better way.

        guard let readProcRefCon = readProcRefCon else { return }
        let inputStream = Unmanaged<InputStream>.fromOpaque(readProcRefCon).takeUnretainedValue()
        inputStream.midiRead(packetListPtr, srcConnRefCon)
    }

    // MIDIReadBlock to be passed to functions like MIDIInputPortCreateWithBlock() on macOS post 10.11
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
        if let uniqueID = uniqueID,
           let match = inputSources.first(where: { $0.uniqueID == uniqueID }) {
            return match
        }
        else if let name = name,
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
        self.readQueue.async {
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
