/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class PortInputStream: InputStream {

    public override init(midiContext: MIDIContext) {
        super.init(midiContext: midiContext)

        _ = midiContext.interface.inputPortCreateWithBlock(midiContext.client, "Input port" as CFString, &inputPort, midiReadBlock)

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

                parsersForSourceEndpointRefs[source.endpointRef] = nil

                center.removeObserver(self, name: .midiObjectDisappeared, object: source)
                center.removeObserver(self, name: .midiObjectWasReplaced, object: source)
            }
            sources.subtracting(oldValue).forEach { source in
                parsersForSourceEndpointRefs[source.endpointRef] = createParser(originatingEndpoint: source)

                center.addObserver(self, selector: #selector(self.sourceDisappeared(_:)), name: .midiObjectDisappeared, object: source)
                center.addObserver(self, selector: #selector(self.sourceWasReplaced(_:)), name: .midiObjectWasReplaced, object: source)

                let connRefCon = UnsafeMutableRawPointer(bitPattern: Int(source.endpointRef))   // like casting to void* in C
                _ = midiContext.interface.portConnectSource(inputPort, source.endpointRef, connRefCon)
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
        return Array(parsersForSourceEndpointRefs.values)
    }

    public override func parser(sourceConnectionRefCon: UnsafeMutableRawPointer?) -> MessageParser? {
        // Note: sourceConnectionRefCon is a MIDIEndpointRef of a Source.
        // We are allowed to return nil, e.g. if we are no longer listening to this source, or if the source has gone away.
        guard let refCon = sourceConnectionRefCon else { return nil }
        let endpointRef = MIDIEndpointRef(Int(bitPattern: refCon))   // like casting from void* in C
        return parsersForSourceEndpointRefs[endpointRef]
    }

    public override func streamSource(parser: MessageParser) -> InputStreamSource? {
        parser.originatingEndpoint?.asInputStreamSource
    }

    public override var inputSources: [InputStreamSource] {
        midiContext.sources.map(\.asInputStreamSource)
    }

    public override var selectedInputSources: Set<InputStreamSource> {
        get {
            Set(sources.map(\.asInputStreamSource))
        }
        set {
            sources = Set(newValue.compactMap { $0.provider as? Source })
        }
    }

    // MARK: Private

    private var inputPort: MIDIPortRef = 0
    private var parsersForSourceEndpointRefs: [MIDIEndpointRef: MessageParser] = [:]

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
