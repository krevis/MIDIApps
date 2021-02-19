/*
 Copyright (c) 2001-2004, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public class PortInputStream: InputStream {

    public override init(midiContext: MIDIContext) {
        super.init(midiContext: midiContext)

        if #available(OSX 10.11, *) {
            _ = midiContext.interface.inputPortCreateWithBlock(midiContext.client, "Input port" as CFString, &inputPort, midiReadBlock)
        }
        else {
            _ = midiContext.interface.inputPortCreate(midiContext.client, "Input port" as CFString, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.midiObjectListChanged(_:)), name: .midiObjectListChanged, object: midiContext)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .midiObjectListChanged, object: midiContext)

        _ = midiContext.interface.portDispose(inputPort)
    }

    public var sources: Set<Source> = [] {
        didSet {
            // The closure-based notification observer API is still awkward to use without creating retain cycles.
            // Easier to use ObjC selectors.
            let center = NotificationCenter.default
            oldValue.subtracting(sources).forEach { source in
                _ = midiContext.interface.portDisconnectSource(inputPort, source.endpointRef)
                // An error can happen in normal circumstances (if the source has disappeared), so ignore it.

                // At any time after MIDIPortDisconnectSource(), we can expect that
                // retainForIncomingMIDI() will no longer be called.
                // However, parser(sourceConnectionRefCon:) may still be called, on the main thread,
                // later on; it should not crash or fail, but it may return nil.
                parsersForSources[source] = nil

                center.removeObserver(self, name: .midiObjectDisappeared, object: source)
                center.removeObserver(self, name: .midiObjectWasReplaced, object: source)
            }
            sources.subtracting(oldValue).forEach { source in
                parsersForSources[source] = createParser(originatingEndpoint: source)

                center.addObserver(self, selector: #selector(self.sourceDisappeared(_:)), name: .midiObjectDisappeared, object: source)
                center.addObserver(self, selector: #selector(self.sourceWasReplaced(_:)), name: .midiObjectWasReplaced, object: source)

                _ = midiContext.interface.portConnectSource(inputPort, source.endpointRef, Unmanaged.passUnretained(source).toOpaque())

                // At any time after MIDIPortConnectSource(), we can expect
                // retainForIncomingMIDI() and parser(sourceConnectionRefCon:) to be called.
            }
        }
    }

    public func addSource(_ source: Source) {
        sources = sources.union([source])
    }

    public func removeSource(_ source: Source) {
        sources = sources.subtracting([source])
    }

    // MARK: InputStream subclass

    public override var parsers: [MessageParser] {
        return Array(parsersForSources.values)
    }

    public override func parser(sourceConnectionRefCon: UnsafeMutableRawPointer?) -> MessageParser? {
        // Note: sourceConnectionRefCon points to a Source.
        // We are allowed to return nil if we are no longer listening to this source.
        guard let refCon = sourceConnectionRefCon else { return nil }
        let source = Unmanaged<Source>.fromOpaque(refCon).takeUnretainedValue()
        return parsersForSources[source]
    }

    public override func streamSource(parser: MessageParser) -> InputStreamSource? {
        return parser.originatingEndpoint?.asInputStreamSource()
    }

    public override var inputSources: [InputStreamSource] {
        midiContext.sources.map { $0.asInputStreamSource() }
    }

    public override var selectedInputSources: Set<InputStreamSource> {
        get {
            return Set(sources.map { $0.asInputStreamSource() })
        }
        set {
            sources = Set(newValue.compactMap { $0.provider as? Source })
        }
    }

    // MARK: Private

    private var inputPort: MIDIPortRef = 0
    private var parsersForSources: [Source: MessageParser] = [:]
        // FUTURE: Consider making the key be source.endpointRef (a MIDIObjectRef)
        // to avoid retain and identity issues. But note MessageParser.originatingEndpoint.

    @objc private func midiObjectListChanged(_ notification: Notification) {
        if let midiObjectType = notification.userInfo?[MIDIContext.objectType] as? MIDIObjectType,
           midiObjectType == .source {
            sourceListChanged()
        }
    }

    @objc private func sourceDisappeared(_ notification: Notification) {
        guard let source = notification.object as? Source,
              sources.contains(source) else { return }
        removeSource(source)
    }

    @objc private func sourceWasReplaced(_ notification: Notification) {
        guard let source = notification.object as? Source,
              sources.contains(source) else { return }
        removeSource(source)
        if let newSource = notification.userInfo?[MIDIContext.objectReplacement] as? Source {
            addSource(newSource)
        }
    }

}
