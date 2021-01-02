/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

@objc public class MessageHistory: NSObject, SMMessageDestination {

    // Remembers the most recent received messages.

    @objc public var savedMessages: [SMMessage] = [] {
        didSet {
            _ = limitSavedMessages()
        }
    }

    @objc public func clearSavedMessages() {
        if savedMessages.count > 0 {
            savedMessages = []
            historyChanged(newMessages: false)
        }
    }

    // How many messages to remember.

    @objc public var historySize: Int = MessageHistory.defaultHistorySize {
        didSet {
            if limitSavedMessages() {
                historyChanged(newMessages: false)
            }
        }
    }

    @objc public static let defaultHistorySize: Int = 1000

    // When the history changes, a notification named .messageHistoryChanged is posted.
    // User info contains a Bool under key MessageHistory.wereMessagesAdded which is true
    // when new messages were added to the history.
    static public let wereMessagesAdded = "SMMessageHistoryWereMessagesAdded"

    // MARK: SMMessageDestination protocol

    @objc public func takeMIDIMessages(_ messages: [SMMessage]) {
        savedMessages += messages
        historyChanged(newMessages: true)
    }

    // MARK: Internal

    private func limitSavedMessages() -> Bool {
        if savedMessages.count > historySize {
            savedMessages = savedMessages.suffix(historySize)
            return true
        }
        else {
            return false
        }
    }

    private func historyChanged(newMessages: Bool) {
        let userInfo = [MessageHistory.wereMessagesAdded: newMessages]
        NotificationCenter.default.post(name: .messageHistoryChanged, object: self, userInfo: userInfo)
    }

}

public extension Notification.Name {

    static let messageHistoryChanged = Notification.Name("SMMessageHistoryChangedNotification")

}
