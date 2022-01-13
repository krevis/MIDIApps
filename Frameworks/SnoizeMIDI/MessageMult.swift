/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class MessageMult: NSObject, MessageDestination {
    public var destinations: [MessageDestination] = []

    public func addDestination(_ destination: MessageDestination) {
        if !destinations.contains(where: { $0 === destination }) {
            destinations.append(destination)
        }
    }

    public func removeDestination(_ destination: MessageDestination) {
        destinations.removeAll { $0 === destination }
    }

    // MARK: MessageDestination

    public func takeMIDIMessages(_ messages: [Message]) {
        destinations.forEach { $0.takeMIDIMessages(messages) }
    }

}
