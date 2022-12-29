/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
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
    // If this ever gets more complicated, make an intermediate object like CombinationInputStreamSourceGroup.
    var groupedDestinations: [[OutputStreamDestination]] {
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
                return portStream!.destinations.first
            }
            else {
                return nil
            }
        }
        set {
            if newValue != nil {
                if let newDestination = newValue as? Destination {
                    selectDestination(newDestination)
                }
                else {
                    selectDestination(nil) // Use the virtual stream
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
            if let destination = stream.destinations.first {
                persistentSettings["portEndpointUniqueID"] = NSNumber(value: destination.uniqueID)
                if let name = destination.name {
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
                selectDestination(endpoint)
            }
            else if let endpointName = settings["portEndpointName"] as? String {
                // Maybe an endpoint with this name still exists, but with a different unique ID.
                if let endpoint = midiContext.findDestination(name: endpointName) {
                    selectDestination(endpoint)
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
            selectDestination(nil) // Use the virtual stream
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

    private func selectDestination(_ destination: Destination?) {
        if let destination {
            // Set up the port stream
            if portStream == nil {
                createPortStream()
            }
            portStream?.destinations = Set([destination])

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
        if let midiObjectType = notification.userInfo?[MIDIContext.objectType] as? MIDIObjectType,
           midiObjectType == .destination {
            delegate?.combinationOutputStreamDestinationsChanged(self)
        }
    }

}

extension CombinationOutputStream: PortOutputStreamDelegate {

    func portOutputStreamDestinationDisappeared(_ stream: PortOutputStream) {
        delegate?.combinationOutputStreamDestinationDisappeared(self)
    }

    @objc(portOutputStream:willBeginSendingSysEx:) func portOutputStream(_ portOutputStream: PortOutputStream, willBeginSendingSysEx request: SysExSendRequest) {
        delegate?.combinationOutputStream(self, willBeginSendingSysEx: request)
    }

    func portOutputStream(_ portOutputStream: PortOutputStream, didEndSendingSysEx request: SysExSendRequest) {
        delegate?.combinationOutputStream(self, didEndSendingSysEx: request)
    }

}

protocol CombinationOutputStreamDelegate: NSObjectProtocol {

    // Sent when the list of destinations changed.
    func combinationOutputStreamDestinationsChanged(_ stream: CombinationOutputStream)

    // Sent when one of the stream's destinations is removed by the system.
    func combinationOutputStreamDestinationDisappeared(_ stream: CombinationOutputStream)

    // Sent when sysex begins sending and ends sending.
    func combinationOutputStream(_ stream: CombinationOutputStream, willBeginSendingSysEx request: SysExSendRequest)
    func combinationOutputStream(_ stream: CombinationOutputStream, didEndSendingSysEx request: SysExSendRequest)

}
