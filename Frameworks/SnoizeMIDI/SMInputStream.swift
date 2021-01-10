/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc open class SMInputStream: NSObject {

    @objc override public init() {
        // Default to main queue for taking pending read packets
        readQueue = DispatchQueue.main

        super.init()
    }

    @objc public var readQueue: DispatchQueue
    @objc public weak var messageDestination: SMMessageDestination?
    @objc public var sysExTimeOut: TimeInterval = 1.0 {
        didSet {
            parsers.forEach { $0.setSysExTimeOut(sysExTimeOut) }
        }
    }

    @objc public func cancelReceivingSysExMessage() {
        parsers.forEach { $0.cancelReceivingSysExMessage() }
    }

    @objc open var persistentSettings: Any? {
        var persistentSettings: [[String: Any]] = []
        for source in selectedInputSources {
            if let inputSource = source as? SMInputStreamSource {
                var dict: [String: Any] = [:]
                if let number = inputSource.inputStreamSourceUniqueID {
                    dict["uniqueID"] = number
                }
                if let name = inputSource.inputStreamSourceName {
                    dict["name"] = name
                }
                if !dict.isEmpty {
                    persistentSettings.append(dict)
                }
            }
        }
        return persistentSettings
    }

    @objc open func takePersistentSettings(_ settings: Any!) -> [String]! {
        // If any endpoints couldn't be found, their names are returned
        // TODO Fix type to be nicer
        guard let dicts = settings as? [[String: Any]] else { return nil }

        var newInputSources: Set<AnyHashable> = []
        var missingNames: [String] = []
        for dict in dicts {
            let name = dict["name"] as? String
            let uniqueID = dict["uniqueID"] as? MIDIUniqueID
            if let source = findInputSource(name: name, uniqueID: uniqueID) {
                newInputSources.insert(source as! AnyHashable)
            }
            else {
                let resolvedName = name ?? NSLocalizedString("Unknown", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "name of missing endpoint if not specified in document")
                missingNames.append(resolvedName)
            }
        }

        selectedInputSources = newInputSources

        return missingNames
    }

    // MARK: For subclass use only
    //       TODO Move to a separate file, or at least extension

    public let midiReadProc: MIDIReadProc = inputStreamMIDIReadProc

    public func createParser(originatingEndpoint: SMEndpoint?) -> SMMessageParser {
        let parser = SMMessageParser()
        parser.setDelegate(self)
        parser.setSysExTimeOut(sysExTimeOut)
        parser.setOriginatingEndpoint(originatingEndpoint)
        return parser
    }

    public func postSelectedInputStreamSourceDisappearedNotification(source: SMInputStreamSource) {
        NotificationCenter.default.post(name: .inputStreamSelectedInputSourceDisappeared, object: self, userInfo: ["source": source])
    }

    public func postSourceListChangedNotification() {
        NotificationCenter.default.post(name: .inputStreamSourceListChanged, object: self)
    }

    // MARK: For subclasses to implement
    //       TODO Move to a separate file, or at least extension

    open func retainForIncomingMIDI(sourceConnectionRefCon: UnsafeMutableRawPointer?) {
        // NOTE: This is called on the CoreMIDI thread!
        //
        // The input stream (self) is already retained appropriately.
        // Subclasses may override if they have other data, dependent on the given refCon,
        // which needs to be retained until the incoming MIDI is processed on the main thread.
    }

    open func releaseForIncomingMIDI(sourceConnectionRefCon: UnsafeMutableRawPointer?) {
        // Normally called on the main thread, but could be called on other queues if set
        //
        // The input stream (self) is already released appropriately.
        // Subclasses may override if they have other data, dependent on the given refCon,
        // which needs to be retained until the incoming MIDI is processed on the main thread.
    }

    open var parsers: [SMMessageParser] {
        // TODO Should this be a collection or something?
        fatalError("Must implement in subclass")
    }

    open func parser(sourceConnectionRefCon: UnsafeMutableRawPointer?) -> SMMessageParser? {
        fatalError("Must implement in subclass")
    }

    open func streamSource(parser: SMMessageParser) -> SMInputStreamSource? {
        fatalError("Must implement in subclass")
    }

    @objc open var inputSources: [SMInputStreamSource] {
        fatalError("Must implement in subclass")
    }

    @objc public var inputSourcesSet: Set<AnyHashable> /* TODO Should become Set<SMInputStreamSource> */ {
        // for convenience going to Swift and dealing with selectedInputSources... may change
        return Set(inputSources as? [AnyHashable] ?? [])
    }

    @objc open var selectedInputSources: Set<AnyHashable> /* TODO Should become Set<SMInputStreamSource> */ {
        get {
            fatalError("Must implement in subclass")
        }
        set {
            fatalError("Must implement in subclass")
        }
    }

    // MARK: <SMMessageParserDelegate>

    @objc public override func parser(_ parser: SMMessageParser!, didRead messages: [SMMessage]!) {
        messageDestination?.takeMIDIMessages(messages)
    }

    @objc public override func parser(_ parser: SMMessageParser!, isReadingSysExWithLength length: UInt) {
        if let streamSource = streamSource(parser: parser) {
            let userInfo = ["length": length,
                            "source": streamSource] as [String: Any]
            NotificationCenter.default.post(name: .inputStreamReadingSysEx, object: self, userInfo: userInfo)
        }
    }

    @objc public override func parser(_ parser: SMMessageParser!, finishedReadingSysExMessage message: SMSystemExclusiveMessage!) {
        if let streamSource = streamSource(parser: parser) {
            let userInfo = ["length": 1 + message.receivedData.count,
                            "valid": message.wasReceivedWithEOX,
                            "source": streamSource] as [String: Any]
            NotificationCenter.default.post(name: .inputStreamDoneReadingSysEx, object: self, userInfo: userInfo)
        }
    }

    // MARK: Private

    private func findInputSource(name: String?, uniqueID: MIDIUniqueID?) -> SMInputStreamSource? {
        // Find the input source with the desired unique ID. If there are no matches by uniqueID, return the first source whose name matches.
        // Otherwise, return nil.
        if let uniqueID = uniqueID,
           let match = inputSources.first(where: { $0.inputStreamSourceUniqueID.int32Value == uniqueID }) {
            return match
        }
        else if let name = name,
                let match = inputSources.first(where: { $0.inputStreamSourceName == name }) {
            return match
        }
        else {
            return nil
        }
    }

}

// TODO These notifications should just be delegate methods.

public extension Notification.Name {

    static let inputStreamReadingSysEx = Notification.Name("SMInputStreamReadingSysExNotification")
    // contains key @"length" with NSNumber (NSUInteger) size of data read so far
    // contains key @"source" with id<SMInputStreamSource> that this sysex data was read from

    static let inputStreamDoneReadingSysEx = Notification.Name("SMInputStreamDoneReadingSysExNotification")
    // contains key @"length" with NSNumber (NSUInteger) indicating size of data read
    // contains key @"source" with id<SMInputStreamSource> that this sysex data was read from
    // contains key @"valid" with NSNumber (BOOL) indicating whether sysex ended properly or not

    static let inputStreamSelectedInputSourceDisappeared = Notification.Name("SMInputStreamSelectedInputSourceDisappearedNotification")
    // contains key @"source" with id<SMInputStreamSource> which disappeared

    static let inputStreamSourceListChanged = Notification.Name("SMInputStreamSourceListChangedNotification")

    // TODO Formalize these things, if we have to have them

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc public extension NSNotification {

    static let inputStreamReadingSysEx = Notification.Name.inputStreamReadingSysEx
    static let inputStreamDoneReadingSysEx = Notification.Name.inputStreamDoneReadingSysEx
    static let inputStreamSelectedInputSourceDisappeared = Notification.Name.inputStreamSelectedInputSourceDisappeared
    static let inputStreamSourceListChanged = Notification.Name.inputStreamSourceListChanged

}

private func inputStreamMIDIReadProc(_ packetListPtr: UnsafePointer<MIDIPacketList>, _ readProcRefCon: UnsafeMutableRawPointer?, _ srcConnRefCon: UnsafeMutableRawPointer?) {
    // NOTE: This function is called in a high-priority, time-constraint thread,
    // created for us by CoreMIDI.
    //
    // Because we're in a time-constraint thread, we should avoid allocating memory,
    // since the allocator uses a single app-wide lock. (If another low-priority thread holds
    // that lock, we'll have to wait for that thread to release it, which is priority inversion.)
    // We're not even attempting to do that yet, because neither MIDI Monitor nor SysEx Librarian
    // need that level of performance. (Probably the best solution is to stuff the packet list
    // into a ring buffer, then consume it in the other queue, but the devil is in the details.)

    guard let readProcRefCon = readProcRefCon else { return }
    let numPackets = packetListPtr.pointee.numPackets
    guard numPackets > 0 else { return }

    let inputStream = Unmanaged<SMInputStream>.fromOpaque(readProcRefCon).takeUnretainedValue()
    // NOTE: There is a race condition here.
    // By the time the async block runs, the input stream may be gone or in a different state.
    // Make sure that the input stream retains itself, and anything that depends on the
    // srcConnRefCon, during the interval between now and the time that parser.take(packetList)
    // is done working.
    // TODO There's still a race. The inputStream could get deallocated at any time
    // while this code is running on the MIDI thread.
    // We should make the refCon be some kind of token that we can use to safely
    // look up the input stream, only when on the appropriate queue, handling cases
    // when the stream is gone.
    inputStream.retainForIncomingMIDI(sourceConnectionRefCon: srcConnRefCon)

    let packetListSize: Int
    if #available(OSX 10.15, *) {
        packetListSize = MIDIPacketList.sizeInBytes(pktList: packetListPtr)
    }
    else {
        // Fallback on earlier versions
        // Jump through hoops just to get a pointer...
        packetListSize = withUnsafePointer(to: packetListPtr.pointee.packet) { (packetPtr: UnsafePointer<MIDIPacket>) -> Int in
            // Find the last packet in the packet list, by stepping forward numPackets-1 times
            var lastPacketPtr = packetPtr
            for _ in 0 ..< numPackets - 1 {
                lastPacketPtr = SMWorkaroundMIDIPacketNext(lastPacketPtr)
            }
            // Then do the pointer math to determine the whole size of the packet
            return UnsafeRawPointer(lastPacketPtr) - UnsafeRawPointer(packetListPtr) + Int(lastPacketPtr.pointee.length)
        }
    }

    // Copy the packet data for later
    let data = Data(bytes: packetListPtr, count: packetListSize)

    // And process it on the queue
    inputStream.readQueue.async {
        autoreleasepool {
            data.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) in
                let packetListPtr = rawPtr.bindMemory(to: MIDIPacketList.self).baseAddress!

                // Starting with an input stream (captured above),
                // find the parser that is associated with this particular connection
                // (which may be nil, if the input stream was disconnected from this source)
                // and give it the packet list.
                inputStream.parser(sourceConnectionRefCon: srcConnRefCon)?.take(packetListPtr)

                // Now that we're done with the input stream and its ref con (whatever that is),
                // release them.
                inputStream.releaseForIncomingMIDI(sourceConnectionRefCon: srcConnRefCon)
            }
        }
    }
}
