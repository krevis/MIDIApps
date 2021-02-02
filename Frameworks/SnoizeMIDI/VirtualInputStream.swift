/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class VirtualInputStream: InputStream {

    @objc public override init(midiContext: MIDIContext) {
        virtualEndpointName = midiContext.name
        uniqueID = 0 // Let CoreMIDI assign a unique ID to the virtual endpoint when it is created

        singleSource = SingleInputStreamSource(name: virtualEndpointName)

        super.init(midiContext: midiContext)
    }

    deinit {
        isActive = false
    }

    @objc public var uniqueID: MIDIUniqueID {
        didSet {
            if uniqueID != oldValue, let endpoint = endpoint {
                endpoint.uniqueID = uniqueID
                // that may or may not have worked
                uniqueID = endpoint.uniqueID
            }
        }
    }

    @objc public var virtualEndpointName: String {
        didSet {
            if virtualEndpointName != oldValue {
                endpoint?.name = virtualEndpointName
            }
        }
    }

    @objc public func setInputSourceName(_ name: String) {
        singleSource.name = name
    }

    @objc public private(set) var endpoint: Destination?

    // MARK: InputStream subclass

    public override var parsers: [MessageParser] {
        if let parser = parser {
            return [parser]
        }
        else {
            return []
        }
    }

    public override func parser(sourceConnectionRefCon refCon: UnsafeMutableRawPointer?) -> MessageParser? {
        // refCon is ignored, since it only applies to connections created with MIDIPortConnectSource()
        return parser
    }

    public override func streamSource(parser: MessageParser) -> InputStreamSource? {
        return singleSource.asInputStreamSource()
    }

    public override var inputSources: [InputStreamSource] {
        [singleSource.asInputStreamSource()]
    }

    public override var selectedInputSources: Set<InputStreamSource> {
        get {
            isActive ? [singleSource.asInputStreamSource()] : []
        }
        set {
            isActive = newValue.contains(singleSource.asInputStreamSource())
        }
    }

    // MARK: InputStream overrides

    @objc public override var persistentSettings: Any? {
        if isActive {
            return ["uniqueID": uniqueID]
        }
        else {
            return nil
        }
    }

    @objc public override func takePersistentSettings(_ settings: Any!) -> [String]! {
        if let settings = settings as? [String: Any?],
           let settingsUniqueID = settings["uniqueID"] as? MIDIUniqueID {
            uniqueID = settingsUniqueID
            isActive = true
        }
        else {
            isActive = false
        }
        return nil
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
        endpoint = midiContext.createVirtualDestination(name: virtualEndpointName, uniqueID: uniqueID, midiReadProc: midiReadProc, readProcRefCon: Unmanaged.passUnretained(self).toOpaque())

        if let endpoint = endpoint {
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
