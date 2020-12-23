/*
 Copyright (c) 2002-2014, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class CombinationInputStreamSourceGroup: NSObject {
    let name: String
    let expandable: Bool
    fileprivate(set) var sources: [SMInputStreamSource]

    init(name myName: String, expandable myExpandable: Bool) {
        name = myName
        expandable = myExpandable
        sources = []
        super.init()
    }
}

class CombinationInputStream: NSObject, SMMessageDestination {

    // TODO Reorganize, make things private, etc.

    var messageDestination: SMMessageDestination?

    private let portInputStream = SMPortInputStream()
    private let virtualInputStream = SMVirtualInputStream()
    private let spyingInputStream: SpyingInputStream?

    private var willPostSourceListChangedNotification = false

    override init() {
        if let spyClient = (NSApp.delegate as? AppController)?.midiSpyClient {
            spyingInputStream = SpyingInputStream(midiSpyClient: spyClient)
        }
        else {
            spyingInputStream = nil
        }

        super.init()

        func observeNotificationsFromStream(_ object: AnyObject) {
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(self.repostNotification(_:)), name: .SMInputStreamReadingSysEx, object: object)
            center.addObserver(self, selector: #selector(self.repostNotification(_:)), name: .SMInputStreamDoneReadingSysEx, object: object)
            center.addObserver(self, selector: #selector(self.repostNotification(_:)), name: .SMInputStreamSelectedInputSourceDisappeared, object: object)
            center.addObserver(self, selector: #selector(self.inputSourceListChanged(_:)), name: .SMInputStreamSourceListChanged, object: object)
        }

        portInputStream.setMessageDestination(self)
        observeNotificationsFromStream(portInputStream)

        virtualInputStream.setMessageDestination(self)
        observeNotificationsFromStream(virtualInputStream)

        if let stream = spyingInputStream {
            stream.setMessageDestination(self)
            observeNotificationsFromStream(stream)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)

        portInputStream.setMessageDestination(nil)
        virtualInputStream.setMessageDestination(nil)
        if let stream = spyingInputStream {
            stream.setMessageDestination(nil)
        }
    }

    @objc func takeMIDIMessages(_ messages: [SMMessage]!) {
        messageDestination?.takeMIDIMessages(messages)
    }

    private lazy var portGroup = CombinationInputStreamSourceGroup(name: NSLocalizedString("MIDI sources", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "name of group for ordinary sources"), expandable: true)
    private lazy var virtualGroup = CombinationInputStreamSourceGroup(name: NSLocalizedString("Act as a destination for other programs", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "name of source item for virtual destination"), expandable: false)
    private var spyingGroup: CombinationInputStreamSourceGroup?

    var sourceGroups: [CombinationInputStreamSourceGroup] {
        var groups = [portGroup, virtualGroup]

        portGroup.sources = portInputStream.inputSources
        virtualGroup.sources = virtualInputStream.inputSources

        if let stream = spyingInputStream {
            if spyingGroup == nil {
                spyingGroup = CombinationInputStreamSourceGroup(name: NSLocalizedString("Spy on output to destinations", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "name of group for spying on destinations"), expandable: true)
            }

            if let group = spyingGroup {
                groups.append(group)

                group.sources = stream.inputSources
            }
        }

        return groups
    }

    var selectedInputSources: Set<AnyHashable> /* TODO Should be SMInputStreamSource */ {
        get {
            var inputSources: Set<AnyHashable> = []
            inputSources.formUnion(portInputStream.selectedInputSources)
            inputSources.formUnion(virtualInputStream.selectedInputSources)
            if let stream = spyingInputStream {
                inputSources.formUnion(stream.selectedInputSources)
            }
            return inputSources
        }
        set {
            portInputStream.selectedInputSources = newValue.intersection(portInputStream.inputSources as! [AnyHashable])
            virtualInputStream.selectedInputSources = newValue.intersection(virtualInputStream.inputSources as! [AnyHashable])
            if let stream = spyingInputStream {
                stream.selectedInputSources = newValue.intersection(stream.inputSources as! [AnyHashable])
            }
        }
    }

    var persistentSettings: [String: Any]? {
        var persistentSettings: [String: Any] = [:]

        if let streamSettings = portInputStream.persistentSettings() {
            persistentSettings["portInputStream"] = streamSettings
        }

        if let streamSettings = virtualInputStream.persistentSettings() {
            persistentSettings["virtualInputStream"] = streamSettings
        }

        if let stream = spyingInputStream,
           let streamSettings = stream.persistentSettings() {
            persistentSettings["spyingInputStream"] = streamSettings
        }

        return persistentSettings.count > 0 ? persistentSettings : nil
    }

    func takePersistentSettings(_ settings: [String: Any]) -> [String]? {
        // If any endpoints couldn't be found, their names are returned
        var missingNames: [String] = []

        // Clear out the current input sources
        selectedInputSources = []

        if let oldStyleUniqueID = settings["portEndpointUniqueID"] as? NSNumber {
            // This is an old-style document, specifiying an endpoint for the port input stream.
            // We may have an endpoint name under key "portEndpointName"
            let sourceEndpointName = settings["portEndpointName"] as? String

            var sourceEndpoint = SMSourceEndpoint(uniqueID: oldStyleUniqueID.int32Value)
            if sourceEndpoint == nil, let name = sourceEndpointName {
                sourceEndpoint = SMSourceEndpoint(name: name)
            }

            if let endpoint = sourceEndpoint {
                portInputStream.addEndpoint(endpoint)
            }
            else {
                let missingName = sourceEndpointName ?? NSLocalizedString("Unknown", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "name of missing endpoint if not specified in document")
                missingNames.append(missingName)
            }

        }
        else if let oldStyleUniqueID = settings["virtualEndpointUniqueID"] as? NSNumber {
            // This is an old-style document, specifying to use a virtual input stream.
            virtualInputStream.setUniqueID(oldStyleUniqueID.int32Value)
            virtualInputStream.selectedInputSources = Set(virtualInputStream.inputSources as! [AnyHashable])
        }
        else {
            // This is a current-style document

            func makeInputStreamTakePersistentSettings(_ stream: SMInputStream, _ streamSettings: Any?) {
                guard let streamSettings = streamSettings else { return }
                if let streamMissingNames = stream.takePersistentSettings(streamSettings) {
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
            return virtualInputStream.virtualEndpointName()
        }
        set {
            virtualInputStream.setVirtualEndpointName(newValue)
        }
    }

    @objc func repostNotification(_ notification: Notification) {
        NotificationCenter.default.post(name: notification.name, object: self, userInfo: notification.userInfo)
    }

    @objc func inputSourceListChanged(_ notification: Notification) {
        // We may get this notification from more than one of our streams, so coalesce all the notifications from all of the streams into one notification from us.

        if !willPostSourceListChangedNotification {
            willPostSourceListChangedNotification = true

            DispatchQueue.main.async {
                self.willPostSourceListChangedNotification = false
                NotificationCenter.default.post(name: notification.name, object: self)
            }
        }
    }

}

// Notifications
//
// This class will repost these notifications from its streams (with self as object):
//    SMInputStreamReadingSysExNotification
//    SMInputStreamDoneReadingSysExNotification
//    SMInputStreamSelectedInputSourceDisappearedNotification
//
// It will also listen to SMInputStreamSourceListChangedNotification from its streams,
// and coalesce them into a single notification (with the same name) from this object.
