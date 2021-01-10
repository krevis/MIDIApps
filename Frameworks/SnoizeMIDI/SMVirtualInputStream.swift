/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class SMVirtualInputStream: SMInputStream {

    @objc override public init() {
        virtualEndpointName = SMClient.sharedClient?.name ?? "Virtual Endpoint"
        uniqueID = 0 // Let CoreMIDI assign a unique ID to the virtual endpoint when it is created

        inputStreamSource = SimpleInputStreamSource(name: virtualEndpointName)

        super.init()

        parser = createParser(originatingEndpoint: nil)
            // TODO We should create the parser up front using a class method
            // then set parser.delegate = self after super init
            // After that, remove ! from parser declaration
    }

    deinit {
        isActive = false
    }

    @objc public var uniqueID: MIDIUniqueID {
        didSet {
            if uniqueID != oldValue, let endpoint = endpoint {
                if endpoint.setUniqueID(uniqueID) == false {
                    // we tried to change the unique ID, but failed
                    uniqueID = endpoint.uniqueID()
                }
            }
        }
    }

    @objc public var virtualEndpointName: String {
        didSet {
            if virtualEndpointName != oldValue {
                endpoint?.setName(virtualEndpointName)
            }
        }
    }

    @objc public func setInputSourceName(_ name: String) {
        inputStreamSource.name = name
    }

    @objc public private(set) var endpoint: SMDestinationEndpoint?

    // MARK: SMInputStream subclass

    override public var parsers: [SMMessageParser] {
        if let parser = parser {
            return [parser]
        }
        else {
            return []
        }
    }

    override public func parser(sourceConnectionRefCon refCon: UnsafeMutableRawPointer?) -> SMMessageParser? {
        // refCon is ignored, since it only applies to connections created with MIDIPortConnectSource()
        return parser
    }

    override public func streamSource(parser: SMMessageParser) -> SMInputStreamSource? {
        return inputStreamSource
    }

    override public var inputSources: [SMInputStreamSource] {
        [inputStreamSource]
    }

    override public var selectedInputSources: Set<AnyHashable> {
        get {
            isActive ? [inputStreamSource] : []
        }
        set {
            isActive = newValue.contains(inputStreamSource)
        }
    }

    // MARK: SMInputStream overrides

    @objc override public var persistentSettings: Any? {
        if isActive {
            return ["uniqueID": uniqueID]
        }
        else {
            return nil
        }
    }

    @objc override public func takePersistentSettings(_ settings: Any!) -> [String]! {
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

    private let inputStreamSource: SimpleInputStreamSource
    private var parser: SMMessageParser!

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
        endpoint = SMDestinationEndpoint.createVirtualDestinationEndpoint(withName: virtualEndpointName, readProc: midiReadProc, readProcRefCon: Unmanaged.passUnretained(self).toOpaque(), uniqueID: uniqueID)
        // TODO Should this be passRetained? if so, balance later
        if let endpoint = endpoint {
            parser.setOriginatingEndpoint(endpoint)

            // We requested a specific uniqueID earlier, but we might not have gotten it.
            // We have to update our idea of what it is, regardless.
            uniqueID = endpoint.uniqueID()
        }
    }

    private func disposeEndpoint() {
        endpoint?.remove()
        endpoint = nil
        parser.setOriginatingEndpoint(nil)
    }

}
