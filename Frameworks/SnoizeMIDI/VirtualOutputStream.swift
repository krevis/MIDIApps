/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class VirtualOutputStream: OutputStream {

    public let endpoint: Source

    public init?(midiContext: MIDIContext, name: String, uniqueID: MIDIUniqueID) {
        guard let newEndpoint = midiContext.createVirtualSource(name: name, uniqueID: uniqueID) else { return nil }
        endpoint = newEndpoint

        super.init(midiContext: midiContext)
    }

    override func send(_ packetListPtr: UnsafePointer<MIDIPacketList>) {
        MIDIReceived(endpoint.endpointRef, packetListPtr)
    }

}
