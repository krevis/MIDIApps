/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class MessageFilter: NSObject, SMMessageDestination {

    @objc public weak var messageDestination: SMMessageDestination?

    @objc public var filterMask: SMMessageType = SMMessageTypeNothingMask
    @objc public var channelMask: SMChannelMask = SMChannelMaskAll

    // MARK: SMMessageDestination protocol

    @objc public func takeMIDIMessages(_ messages: [SMMessage]) {
        let filteredMessages = filterMessages(messages)
        if filteredMessages.count > 0 {
            messageDestination?.takeMIDIMessages(filteredMessages)
        }
    }

    // MARK: Private

    private func filterMessages(_ messages: [SMMessage]) -> [SMMessage] {
        return messages.filter { message -> Bool in
            if message.matchesMessageTypeMask(filterMask) {
                // NOTE: This type checking kind of smells, but I can't think of a better way to do it.
                // We could implement matchesChannelMask() on all SMMessages, but I don't know if the default should be YES or NO...
                // I could see it going either way, in different contexts.
                if let voiceMessage = message as? SMVoiceMessage {
                    return voiceMessage.matchesChannelMask(channelMask)
                }
                else {
                    return true
                }
            }
            else {
                return false
            }
        }
    }

}
