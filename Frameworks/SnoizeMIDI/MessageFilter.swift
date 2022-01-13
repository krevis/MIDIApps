/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class MessageFilter: NSObject, MessageDestination {

    public weak var messageDestination: MessageDestination?

    public var filterMask: Message.TypeMask = []
    public var channelMask: VoiceMessage.ChannelMask = VoiceMessage.ChannelMask.all

    // MARK: MessageDestination

    public func takeMIDIMessages(_ messages: [Message]) {
        let filteredMessages = filterMessages(messages)
        if filteredMessages.count > 0 {
            messageDestination?.takeMIDIMessages(filteredMessages)
        }
    }

    // MARK: Private

    private func filterMessages(_ messages: [Message]) -> [Message] {
        return messages.filter { message -> Bool in
            if message.matchesMessageTypeMask(filterMask) {
                // NOTE: This type checking kind of smells, but I can't think of a better way to do it.
                // We could implement matchesChannelMask() on all SMMessages, but I don't know if the default should be YES or NO...
                // I could see it going either way, in different contexts.
                if let voiceMessage = message as? VoiceMessage {
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
