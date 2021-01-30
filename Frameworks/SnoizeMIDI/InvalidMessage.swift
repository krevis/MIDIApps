/*
 Copyright (c) 2003-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class InvalidMessage: Message {

    @objc public var data: Data

    @objc init(timeStamp: MIDITimeStamp, data: Data) {
        self.data = data
        super.init(timeStamp: timeStamp, statusByte: 0x00)  // statusByte is ignored
    }

    @objc public required init?(coder: NSCoder) {
        guard let data = coder.decodeObject(forKey: "data") as? Data else { return nil }
        self.data = data
        super.init(coder: coder)
    }

    public override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(data, forKey: "data")
    }

    @objc public var sizeForDisplay: String {
        let format = NSLocalizedString("%@ bytes", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "Invalid message length format string")
        return String.localizedStringWithFormat(format, Message.formatLength(otherDataLength))
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
        NSLocalizedString("Invalid", tableName: "SnoizeMIDI", bundle: SMBundleForObject(self), comment: "displayed type of Invalid event")
    }

    public override var dataForDisplay: String {
        sizeForDisplay
    }

}
