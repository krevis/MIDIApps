/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class CombinationInputStream: NSObject {

    init(midiContext: MIDIContext) {
        self.midiContext = midiContext

        portInputStream = PortInputStream(midiContext: midiContext)
        virtualInputStream = VirtualInputStream(midiContext: midiContext)

        if let spyClient = (NSApp.delegate as? AppController)?.midiSpyClient {
            spyingInputStream = SpyingInputStream(midiContext: midiContext, midiSpyClient: spyClient)
        }
        else {
            spyingInputStream = nil
        }

        super.init()

        portInputStream.messageDestination = self
        portInputStream.delegate = self

        virtualInputStream.messageDestination = self
        virtualInputStream.delegate = self

        if let stream = spyingInputStream {
            stream.messageDestination = self
            stream.delegate = self
        }
    }

    weak var delegate: CombinationInputStreamDelegate?
    weak var messageDestination: MessageDestination?

    var sourceGroups: [CombinationInputStreamSourceGroup] {
        var groups = [portGroup, virtualGroup]

        portGroup.sources = portInputStream.inputSources
        virtualGroup.sources = virtualInputStream.inputSources

        if let stream = spyingInputStream {
            if spyingGroup == nil {
                spyingGroup = CombinationInputStreamSourceGroup(name: NSLocalizedString("Spy on output to destinations", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "name of group for spying on destinations"), expandable: true)
            }

            if let group = spyingGroup {
                groups.append(group)

                group.sources = stream.inputSources
            }
        }

        return groups
    }

    var selectedInputSources: Set<InputStreamSource> {
        get {
            var inputSources: Set<InputStreamSource> = []
            inputSources.formUnion(portInputStream.selectedInputSources)
            inputSources.formUnion(virtualInputStream.selectedInputSources)
            if let stream = spyingInputStream {
                inputSources.formUnion(stream.selectedInputSources)
            }
            return inputSources
        }
        set {
            portInputStream.selectedInputSources = newValue.intersection(portInputStream.inputSourcesSet)
            virtualInputStream.selectedInputSources = newValue.intersection(virtualInputStream.inputSourcesSet)
            if let stream = spyingInputStream {
                stream.selectedInputSources = newValue.intersection(stream.inputSourcesSet)
            }
        }
    }

    var persistentSettings: [String: Any]? {
        var persistentSettings: [String: Any] = [:]

        if let streamSettings = portInputStream.persistentSettings {
            persistentSettings["portInputStream"] = streamSettings
        }

        if let streamSettings = virtualInputStream.persistentSettings {
            persistentSettings["virtualInputStream"] = streamSettings
        }

        if let stream = spyingInputStream,
           let streamSettings = stream.persistentSettings {
            persistentSettings["spyingInputStream"] = streamSettings
        }

        return persistentSettings.count > 0 ? persistentSettings : nil
    }

    @discardableResult func takePersistentSettings(_ settings: [String: Any]) -> [String]? {
        // If any sources couldn't be found, their names are returned
        var missingNames: [String] = []

        // Clear out the current input sources
        selectedInputSources = []

        if let oldStyleUniqueID = settings["portEndpointUniqueID"] as? NSNumber {
            // This is an old-style document, specifiying an endpoint for the port input stream.
            // We may have an endpoint name under key "portEndpointName"
            let sourceName = settings["portEndpointName"] as? String

            var source = midiContext.findSource(uniqueID: oldStyleUniqueID.int32Value)
            if source == nil, let name = sourceName {
                source = midiContext.findSource(name: name)
            }

            if let source {
                portInputStream.addSource(source)
            }
            else {
                let missingName = sourceName ?? NSLocalizedString("Unknown", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "name of missing source if not specified in document")
                missingNames.append(missingName)
            }

        }
        else if let oldStyleUniqueID = settings["virtualEndpointUniqueID"] as? NSNumber {
            // This is an old-style document, specifying to use a virtual input stream.
            virtualInputStream.uniqueID = oldStyleUniqueID.int32Value
            virtualInputStream.selectedInputSources = virtualInputStream.inputSourcesSet
        }
        else {
            // This is a current-style document

            func makeInputStreamTakePersistentSettings(_ stream: SnoizeMIDI.InputStream, _ streamSettings: Any?) {
                if let streamSettings {
                    let streamMissingNames = stream.takePersistentSettings(streamSettings)
                    missingNames += streamMissingNames
                }
            }

            makeInputStreamTakePersistentSettings(portInputStream, settings["portInputStream"])
            makeInputStreamTakePersistentSettings(virtualInputStream, settings["virtualInputStream"])
            if let stream = spyingInputStream {
                makeInputStreamTakePersistentSettings(stream, settings["spyingInputStream"])
            }
        }

        return missingNames.count > 0 ? missingNames : nil
    }

    var virtualEndpointName: String {
        get {
            return virtualInputStream.virtualEndpointName
        }
        set {
            virtualInputStream.virtualEndpointName = newValue
        }
    }

    // MARK: Private

    private let midiContext: MIDIContext
    private let portInputStream: PortInputStream
    private let virtualInputStream: VirtualInputStream
    private let spyingInputStream: SpyingInputStream?

    private var willSendSourceListChanged = false

    private lazy var portGroup = CombinationInputStreamSourceGroup(name: NSLocalizedString("MIDI sources", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "name of group for ordinary sources"), expandable: true)
    private lazy var virtualGroup = CombinationInputStreamSourceGroup(name: NSLocalizedString("Act as a destination for other programs", tableName: "MIDIMonitor", bundle: Bundle.main, comment: "name of source item for virtual destination"), expandable: false)
    private var spyingGroup: CombinationInputStreamSourceGroup?

}

protocol CombinationInputStreamDelegate: NSObjectProtocol {

    // Like InputStreamDelegate

    // Sent when the stream begins or continues receiving a SystemExclusive message
    func combinationInputStreamReadingSysEx(_ stream: CombinationInputStream, byteCountSoFar: Int, streamSource: InputStreamSource)

    // Sent when the stream finishes receiving a SystemExclusive message
    func combinationInputStreamFinishedReadingSysEx(_ stream: CombinationInputStream, byteCount: Int, streamSource: InputStreamSource, isValid: Bool)

    func combinationInputStreamSourceListChanged(_ stream: CombinationInputStream)

}

extension CombinationInputStream: MessageDestination {

    func takeMIDIMessages(_ messages: [Message]) {
        messageDestination?.takeMIDIMessages(messages)
    }

}

extension CombinationInputStream: InputStreamDelegate {

    func inputStreamReadingSysEx(_ stream: SnoizeMIDI.InputStream, byteCountSoFar: Int, streamSource: InputStreamSource) {
        delegate?.combinationInputStreamReadingSysEx(self, byteCountSoFar: byteCountSoFar, streamSource: streamSource)
    }

    func inputStreamFinishedReadingSysEx(_ stream: SnoizeMIDI.InputStream, byteCount: Int, streamSource: InputStreamSource, isValid: Bool) {
        delegate?.combinationInputStreamFinishedReadingSysEx(self, byteCount: byteCount, streamSource: streamSource, isValid: isValid)
    }

    func inputStreamSourceListChanged(_ stream: SnoizeMIDI.InputStream) {
        // We may get this notification from more than one of our streams, so coalesce all the notifications from all of the streams into one notification from us.

        if !willSendSourceListChanged {
            willSendSourceListChanged = true

            DispatchQueue.main.async {
                self.willSendSourceListChanged = false
                self.delegate?.combinationInputStreamSourceListChanged(self)
            }
        }
    }

}

class CombinationInputStreamSourceGroup: NSObject {

    let name: String
    let expandable: Bool

    fileprivate(set) var sources: [InputStreamSource] {
        didSet {
            boxedSources = sources.map { Box($0) }
        }
    }

    private(set) var boxedSources: [Box<InputStreamSource>]

    init(name myName: String, expandable myExpandable: Bool) {
        name = myName
        expandable = myExpandable
        sources = []
        boxedSources = []
        super.init()
    }

}
