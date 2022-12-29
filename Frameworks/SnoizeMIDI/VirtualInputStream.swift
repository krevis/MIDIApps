/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class VirtualInputStream: InputStream {

    public override init(midiContext: MIDIContext) {
        virtualEndpointName = midiContext.name
        uniqueID = 0 // Let CoreMIDI assign a unique ID to the virtual endpoint when it is created

        singleSource = SingleInputStreamSource(name: virtualEndpointName)

        super.init(midiContext: midiContext)
    }

    deinit {
        isActive = false
    }

    public var uniqueID: MIDIUniqueID {
        didSet {
            if uniqueID != oldValue, let endpoint {
                endpoint.uniqueID = uniqueID
                // that may or may not have worked
                uniqueID = endpoint.uniqueID
            }
        }
    }

    public var virtualEndpointName: String {
        didSet {
            if virtualEndpointName != oldValue {
                endpoint?.name = virtualEndpointName
            }
        }
    }

    public func setInputSourceName(_ name: String) {
        singleSource.name = name
    }

    public private(set) var endpoint: Destination?

    // MARK: InputStream subclass

    public override var parsers: [MessageParser] {
        if let parser {
            return [parser]
        }
        else {
            return []
        }
    }

    public override func parser(sourceConnectionRefCon refCon: UnsafeMutableRawPointer?) -> MessageParser? {
        // refCon is ignored, since it only applies to connections created with MIDIPortConnectSource()
        parser
    }

    public override func streamSource(parser: MessageParser) -> InputStreamSource? {
        singleSource.asInputStreamSource
    }

    public override var inputSources: [InputStreamSource] {
        [singleSource.asInputStreamSource]
    }

    public override var selectedInputSources: Set<InputStreamSource> {
        get {
            isActive ? [singleSource.asInputStreamSource] : []
        }
        set {
            isActive = newValue.contains(singleSource.asInputStreamSource)
        }
    }

    // MARK: InputStream overrides

    public override var persistentSettings: Any? {
        isActive ? ["uniqueID": uniqueID] : nil
    }

    public override func takePersistentSettings(_ settings: Any) -> [String] {
        if let settings = settings as? [String: Any],
           let settingsUniqueID = settings["uniqueID"] as? MIDIUniqueID {
            uniqueID = settingsUniqueID
            isActive = true
        }
        else {
            isActive = false
        }
        return []
    }

    // MARK: Private

    private let singleSource: SingleInputStreamSource
    private var parser: MessageParser?

    private var isActive: Bool {
        get {
            endpoint != nil
        }
        set {
            if newValue && endpoint == nil {
                createEndpoint()
            }
            else if !newValue && endpoint != nil {
                disposeEndpoint()
            }
        }
    }

    private func createEndpoint() {

        endpoint = midiContext.createVirtualDestination(name: virtualEndpointName, uniqueID: uniqueID, midiReadBlock: midiReadBlock)

        if let endpoint {
            if parser == nil {
                parser = createParser(originatingEndpoint: endpoint)
            }
            else {
                parser!.originatingEndpoint = endpoint
            }

            // We requested a specific uniqueID, but we might not have gotten it.
            // Update our copy of it from the actual value in CoreMIDI.
            uniqueID = endpoint.uniqueID
        }
    }

    private func disposeEndpoint() {
        endpoint?.remove()
        endpoint = nil
        parser?.originatingEndpoint = nil
    }

}
