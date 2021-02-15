/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import SnoizeMIDI

class CombinationOutputStream: NSObject, MessageDestination {

    static func destinationsInContext(_ midiContext: MIDIContext) -> [Destination] {
        // The regular set of destination endpoints, but without any of our own virtual endpoints
        midiContext.destinations.filter { !$0.isOwnedByThisProcess }
    }

    init(midiContext: MIDIContext) {
        self.midiContext = midiContext
        virtualStreamDestination = SingleOutputStreamDestination(name: midiContext.name)

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.midiObjectListChanged(_:)), name: .midiObjectListChanged, object: midiContext)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    weak var delegate: CombinationOutputStreamDelegate?

    var messageDestination: MessageDestination?

    var destinations: [OutputStreamDestination] {
        // Flatten the groups
        Array(groupedDestinations.joined())
    }

    // Returns an array of arrays. Each of the 2nd level arrays contains destinations that are of the same kind.
    // (That is, the first array has destinations for the port stream, the second array has destinations for the virtual stream, etc.)
    var groupedDestinations: [[OutputStreamDestination]] {
        // TODO perhaps do it like CombinationInputStreamSourceGroup instead
        [ Self.destinationsInContext(midiContext),
          [virtualStreamDestination]
        ]
    }

    var selectedDestination: OutputStreamDestination? {
        get {
            if virtualStream != nil {
                return virtualStreamDestination
            }
            else if portStream != nil {
                return portStream!.endpoints.first
            }
            else {
                return nil
            }
        }
        set {
            if newValue != nil {
                if let newDestination = newValue as? Destination {
                    selectEndpoint(newDestination)
                }
                else {
                    selectEndpoint(nil) // Use the virtual stream
                }
            }
            else {
                // Deselect everything
                removePortStream()
                removeVirtualStream()
            }
        }
    }

    func setVirtualDisplayName(_ name: String?) {
        virtualStreamDestination.name = name
    }

    var persistentSettings: [String: Any]? {
        var persistentSettings: [String: Any] = [:]

        if let stream = portStream {
            if let endpoint = stream.endpoints.first {
                persistentSettings["portEndpointUniqueID"] = NSNumber(value: endpoint.uniqueID)
                if let name = endpoint.name {
                    persistentSettings["portEndpointName"] = name
                }
            }
        }
        else if let stream = virtualStream {
            persistentSettings["virtualEndpointUniqueID"] = NSNumber(value: stream.endpoint.uniqueID)
        }

        return persistentSettings.count > 0 ? persistentSettings : nil
    }

    func takePersistentSettings(_ settings: [String: Any]) -> String? {
        // If the endpoint indicated by the persistent settings couldn't be found, its name is returned

        if let number = settings["portEndpointUniqueID"] as? NSNumber {
            if let endpoint = midiContext.findDestination(uniqueID: number.int32Value) {
                selectEndpoint(endpoint)
            }
            else if let endpointName = settings["portEndpointName"] as? String {
                // Maybe an endpoint with this name still exists, but with a different unique ID.
                if let endpoint = midiContext.findDestination(name: endpointName) {
                    selectEndpoint(endpoint)
                }
                else {
                    return endpointName
                }
            }
            else {
                return NSLocalizedString("Unknown", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "name of missing endpoint if not specified in document")
            }
        }
        else if let number = settings["virtualEndpointUniqueID"] as? NSNumber {
            removeVirtualStream()
            virtualEndpointUniqueID = number.int32Value
            selectEndpoint(nil) // Use the virtual stream
        }

        return nil
    }

    // If YES, then ignore the timestamps in the messages we receive, and send immediately instead
    var ignoresTimeStamps: Bool = false {
        didSet {
            stream?.ignoresTimeStamps = ignoresTimeStamps
        }
    }

    // If YES, then use MIDISendSysex() to send sysex messages. Otherwise, use plain old MIDI packets.
    // (This can only work on port streams, not virtual ones.)
    var sendsSysExAsynchronously = false {
        didSet {
            if stream == portStream {
                portStream?.sendsSysExAsynchronously = sendsSysExAsynchronously
            }
        }
    }

    var canSendSysExAsynchronously: Bool {
        self.stream == portStream && portStream != nil && portStream!.sendsSysExAsynchronously
    }

    var customSysExBufferSize: Int = 0 {
        didSet {
            portStream?.customSysExBufferSize = customSysExBufferSize
        }
    }

    func cancelPendingSysExSendRequests() {
        if stream == portStream {
            portStream?.cancelPendingSysExSendRequests()
        }
    }

    var currentSysExSendRequest: SysExSendRequest? {
        if stream == portStream {
            return portStream?.pendingSysExSendRequests.first
        }
        else {
            return nil
        }
    }

    // MARK: MessageDestination

    func takeMIDIMessages(_ messages: [Message]) {
        stream?.takeMIDIMessages(messages)
    }

    // MARK: Private

    private let midiContext: MIDIContext

    private var virtualStream: VirtualOutputStream?
    private var portStream: PortOutputStream?

    // Returns the actual stream in use (either virtualStream or portStream)
    private var stream: SnoizeMIDI.OutputStream? {
        virtualStream ?? portStream
    }

    private let virtualStreamDestination: SingleOutputStreamDestination
    private var virtualEndpointUniqueID: MIDIUniqueID = 0

    private func selectEndpoint(_ destination: Destination?) {
        if let destination = destination {
            // Set up the port stream
            if portStream == nil {
                createPortStream()
            }
            portStream?.endpoints = Set([destination])

            removeVirtualStream()
        }
        else {
            // Set up the virtual stream
            if virtualStream == nil {
                createVirtualStream()
            }

            removePortStream()
        }
    }

    private func createPortStream() {
        guard portStream == nil else { return }

        let stream = PortOutputStream(midiContext: midiContext)
        stream.ignoresTimeStamps = ignoresTimeStamps
        stream.sendsSysExAsynchronously = sendsSysExAsynchronously
        stream.customSysExBufferSize = customSysExBufferSize
        stream.delegate = self
        portStream = stream
    }

    private func removePortStream() {
        portStream = nil
    }

    private func createVirtualStream() {
        guard virtualStream == nil else { return }

        if let stream = VirtualOutputStream(midiContext: midiContext, name: midiContext.name, uniqueID: virtualEndpointUniqueID) {
            stream.ignoresTimeStamps = ignoresTimeStamps

            // We may not have specified a unique ID for the virtual endpoint, or it may not have actually stuck,
            // so update our idea of what it is.
            virtualEndpointUniqueID = stream.endpoint.uniqueID

            virtualStream = stream
        }
    }

    private func removeVirtualStream() {
        self.virtualStream = nil
    }

    @objc private func midiObjectListChanged(_ notification: Notification) {
        // TODO Make sure this comes through; remove if nothing needs it
        if let midiObjectType = notification.userInfo?[MIDIContext.objectType] as? MIDIObjectType,
           midiObjectType == .destination {
            NotificationCenter.default.post(name: .combinationOutputStreamDestinationListChanged, object: self)
        }
    }

}

extension CombinationOutputStream: PortOutputStreamDelegate {

    func portOutputStreamEndpointDisappeared(_ portOutputStream: PortOutputStream) {
        // TODO Make sure this comes through
        delegate?.combinationOutputStreamEndpointDisappeared(self)
    }

    @objc(portOutputStream:willBeginSendingSysEx:) func portOutputStream(_ portOutputStream: PortOutputStream, willBeginSendingSysEx request: SysExSendRequest) {
        delegate?.combinationOutputStream(self, willBeginSendingSysEx: request)
    }

    func portOutputStream(_ portOutputStream: PortOutputStream, didEndSendingSysEx request: SysExSendRequest) {
        delegate?.combinationOutputStream(self, didEndSendingSysEx: request)
    }

}

protocol CombinationOutputStreamDelegate: NSObjectProtocol {

    // Sent when one of the stream's destination endpoints is removed by the system.
    func combinationOutputStreamEndpointDisappeared(_ stream: CombinationOutputStream)

    // Sent when sysex begins sending and ends sending.
    func combinationOutputStream(_ stream: CombinationOutputStream, willBeginSendingSysEx request: SysExSendRequest)
    func combinationOutputStream(_ stream: CombinationOutputStream, didEndSendingSysEx request: SysExSendRequest)

}

extension Notification.Name {

    // TODO Does anything actually need this?
    static let combinationOutputStreamDestinationListChanged = Notification.Name("SSECombinationOutputStreamDestinationListChangedNotification")

}
