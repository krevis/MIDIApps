/*
 Copyright (c) 2003-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class InvalidMessage: Message {

    public var data: Data

    init(timeStamp: MIDITimeStamp, data: Data) {
        self.data = data
        super.init(timeStamp: timeStamp, statusByte: 0x00)  // statusByte is ignored
    }

    public required init?(coder: NSCoder) {
        guard let data = coder.decodeObject(forKey: "data") as? Data else { return nil }
        self.data = data
        super.init(coder: coder)
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(data, forKey: "data")
    }

    public var sizeForDisplay: String {
        let format = NSLocalizedString("%@ bytes", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "Invalid message length format string")
        return String.localizedStringWithFormat(format, MessageFormatter.formatLength(otherDataLength))
    }

    // MARK: Message overrides

    public override var messageType: TypeMask {
        .invalid
    }

    public override var otherDataLength: Int {
        data.count
    }

    public override var otherData: Data? {
        data
    }

    public override var typeForDisplay: String {
        NSLocalizedString("Invalid", tableName: "SnoizeMIDI", bundle: Bundle.snoizeMIDI, comment: "displayed type of Invalid event")
    }

    public override var dataForDisplay: String {
        sizeForDisplay
    }

}
