/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

public class MessageHistory: NSObject, MessageDestination {

    // Remembers the most recent received messages.

    public weak var delegate: MessageHistoryDelegate?

    public var savedMessages: [Message] = [] {
        didSet {
            limitSavedMessages()
        }
    }

    public func clearSavedMessages() {
        if savedMessages.count > 0 {
            savedMessages = []
            historyChanged(messagesWereAdded: false)
        }
    }

    // How many messages to remember.

    public var historySize: Int = MessageHistory.defaultHistorySize {
        didSet {
            if limitSavedMessages() {
                historyChanged(messagesWereAdded: false)
            }
        }
    }

    public static let defaultHistorySize: Int = 1000

    // MARK: MessageDestination

    public func takeMIDIMessages(_ messages: [Message]) {
        savedMessages += messages
        historyChanged(messagesWereAdded: true)
    }

    // MARK: Private

    @discardableResult private func limitSavedMessages() -> Bool {
        if savedMessages.count > historySize {
            savedMessages = savedMessages.suffix(historySize)
            return true
        }
        else {
            return false
        }
    }

    private func historyChanged(messagesWereAdded: Bool) {
        delegate?.messageHistoryChanged(self, messagesWereAdded: messagesWereAdded)
    }

}

public protocol MessageHistoryDelegate: NSObjectProtocol {

    func messageHistoryChanged(_ messageHistory: MessageHistory, messagesWereAdded: Bool)

}
