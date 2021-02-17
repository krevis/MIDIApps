/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa
import SnoizeMIDI

class MIDIController: NSObject {

    init(mainWindowController: MainWindowController) {
        self.mainWindowController = mainWindowController

        guard let context = (NSApp.delegate as? AppController)?.midiContext else { fatalError() }
        self.midiContext = context

        self.inputStream = PortInputStream(midiContext: midiContext)
        self.outputStream = CombinationOutputStream(midiContext: midiContext)

        super.init()

        let center = NotificationCenter.default

        inputStream.delegate = self
        inputStream.messageDestination = self
        inputStream.selectedInputSources = Set(inputStream.inputSources)

        center.addObserver(self, selector: #selector(customSysexBufferSizeChanged(_:)), name: .customSysexBufferSizePreferenceChanged, object: nil)
        outputStream.delegate = self
        outputStream.ignoresTimeStamps = true
        outputStream.sendsSysExAsynchronously = true
        outputStream.customSysExBufferSize = UserDefaults.standard.integer(forKey: Self.customSysexBufferSizePreferenceKey)
        outputStream.setVirtualDisplayName(NSLocalizedString("Act as a source for other programs", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "display name of virtual source"))

        sendPreferenceDidChange(nil)
        center.addObserver(self, selector: #selector(sendPreferenceDidChange(_:)), name: .sysExSendPreferenceChanged, object: nil)

        receivePreferenceDidChange(nil)
        center.addObserver(self, selector: #selector(receivePreferenceDidChange(_:)), name: .sysExReceivePreferenceChanged, object: nil)

        listenForProgramChangesPreferenceDidChange(nil)
        center.addObserver(self, selector: #selector(listenForProgramChangesPreferenceDidChange(_:)), name: .listenForProgramChangesPreferenceChanged, object: nil)

        var didSetDestinationFromDefaults = false
        if let destinationSettings = UserDefaults.standard.dictionary(forKey: Self.selectedDestinationPreferenceKey) {
            let missingDestinationName = outputStream.takePersistentSettings(destinationSettings)
            if missingDestinationName == nil {
                didSetDestinationFromDefaults = true
            }
        }
        if !didSetDestinationFromDefaults {
            selectFirstAvailableDestination()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        virtualInputStream?.messageDestination = nil
        inputStream.messageDestination = nil
    }

    var destinations: [OutputStreamDestination] {
        outputStream.destinations
    }

    var groupedDestinations: [[OutputStreamDestination]] {
        outputStream.groupedDestinations
    }

    var selectedDestination: OutputStreamDestination? {
        get {
            outputStream.selectedDestination
        }
        set {
            outputStream.selectedDestination = newValue

            mainWindowController?.synchronizeDestinations()
            UserDefaults.standard.set(outputStream.persistentSettings, forKey: Self.selectedDestinationPreferenceKey)
        }
    }

    var messages: [SystemExclusiveMessage] = [] {
        didSet {
            sendingMessageCount = messages.count
            sendingMessageIndex = 0
            bytesToSend = messages.reduce(0, { $0 + $1.fullMessageDataLength })
            bytesSent = 0
        }
    }

    // Listening to sysex messages

    func listenForOneMessage() {
        listenToMultipleSysexMessages = false
        startListening()
    }

    func listenForMultipleMessages() {
        listenToMultipleSysexMessages = true
        startListening()
    }

    func cancelMessageListen() {
        listeningToSysexMessages = false
        inputStream.cancelReceivingSysExMessage()

        messages = []
        messageBytesRead = 0
        totalBytesRead = 0
    }

    func doneWithMultipleMessageListen() {
        listeningToSysexMessages = false
        inputStream.cancelReceivingSysExMessage()
    }

    struct MessageListenStatus {
        let messageCount: Int
        let bytesRead: Int
        let totalBytesRead: Int
    }

    var messageListenStatus: MessageListenStatus {
        return MessageListenStatus(
            messageCount: messages.count,
            bytesRead: messageBytesRead,
            totalBytesRead: totalBytesRead
        )
    }

    // Sending sysex messages

    func sendMessages() {
        guard messages.count > 0 else { return }

        if !outputStream.canSendSysExAsynchronously {
            // Just dump all the messages out at once
            outputStream.takeMIDIMessages(messages)
            // And we're done
            bytesSent = bytesToSend
            sendingMessageIndex = messages.count - 1
            NotificationCenter.default.post(name: .sendFinishedImmediately, object: self)
            messages = []
        }
        else {
            currentSendRequest = nil
            sendingMessageIndex = 0
            bytesSent = 0
            sendStatus = .idle

            NotificationCenter.default.post(name: .sendWillStart, object: self)

            sendNextSysExMessage()
        }
    }

    func cancelSendingMessages() {
        switch sendStatus {
        case .sending:
            sendStatus = .cancelled
            outputStream.cancelPendingSysExSendRequests()
            // We will get notified when the current send request is finished
        case .willDelayBeforeNext:
            sendStatus = .cancelled
            // sendNextSysExMessageAfterDelay() is going to happen in the main thread, but hasn't happened yet.
            // We can't stop it from happening, so let it do the cancellation work when it happens.
        case .delayingBeforeNext:
            // sendNextSysExMessageAfterDelay() has scheduled the next sendNextSysExMessage(),
            // but it hasn't happened yet.
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(sendNextSysExMessage), object: nil)
            sendStatus = .finishing
            finishedSendingMessages(success: false)
        default:
            break
        }
    }

    struct MessageSendStatus {
        let messageCount: Int
        let messageIndex: Int
        let bytesToSend: Int
        let bytesSent: Int
    }

    var messageSendStatus: MessageSendStatus {
        return MessageSendStatus(
            messageCount: sendingMessageCount,
            messageIndex: sendingMessageIndex,
            bytesToSend: bytesToSend,
            bytesSent: bytesSent + (currentSendRequest?.bytesSent ?? 0)
        )
    }

    // MARK: Private

    private weak var mainWindowController: MainWindowController?

    // MIDI processing
    private let midiContext: MIDIContext
    private let inputStream: PortInputStream
    private var virtualInputStream: VirtualInputStream?
    private let outputStream: CombinationOutputStream

    // Transient data
    // ... for listening for sysex
    private var listeningToSysexMessages = false
    private var listenToMultipleSysexMessages = false
    private var messageBytesRead = 0
    private var totalBytesRead = 0

    // ... for sending sysex
    private enum SendStatus {
        case idle
        case sending
        case willDelayBeforeNext
        case delayingBeforeNext
        case cancelled
        case finishing
    }

    private var pauseTimeBetweenMessages = TimeInterval(0)
    private weak var currentSendRequest: SysExSendRequest?
    private var sendingMessageCount = 0
    private var sendingMessageIndex = 0
    private var bytesToSend = 0
    private var bytesSent = 0
    private var sendStatus: SendStatus = .idle
    private var scheduledUpdateSysExReadIndicator = false

    // ... for listening to program change messages
    private var listeningToProgramChangeMessages = false

}

extension MIDIController: MessageDestination {

    func takeMIDIMessages(_ incomingMessages: [Message]) {
        for incomingMessage in incomingMessages {
            if listeningToSysexMessages,
               let sysExMessage = incomingMessage as? SystemExclusiveMessage {
                messages.append(sysExMessage)
                totalBytesRead += messageBytesRead
                messageBytesRead = 0

                updateSysExReadIndicator()

                if listenToMultipleSysexMessages == false {
                    listeningToSysexMessages = false
                    NotificationCenter.default.post(name: .readFinished, object: self)
                    break
                }
            }
            else if listeningToProgramChangeMessages,
                    let voiceMessage = incomingMessage as? VoiceMessage,
                    voiceMessage.status == .program,
                    voiceMessage.originatingEndpoint == virtualInputStream?.endpoint {
                let program = voiceMessage.dataByte1
                mainWindowController?.playEntry(withProgramNumber: program)
            }
        }
    }

}

extension MIDIController /* Preferences Keys*/ {

    static let selectedDestinationPreferenceKey = "SSESelectedDestination"
    static let sysExReadTimeOutPreferenceKey = "SSESysExReadTimeOut"
    static let timeBetweenSentSysExPreferenceKey = "SSESysExIntervalBetweenSentMessages"
    static let listenForProgramChangesPreferenceKey = "SSEListenForProgramChanges"
    static let interruptOnProgramChangePreferenceKey = "SSEInterruptOnProgramChange"
    static let programChangeBaseIndexPreferenceKey = "SSEProgramChangeBaseIndex"
    static let customSysexBufferSizePreferenceKey = "SSECustomSysexBufferSize"

}

extension Notification.Name {

    static let readStatusChanged = Notification.Name("SSEMIDIControllerReadStatusChangedNotification")
    static let readFinished = Notification.Name("SSEMIDIControllerReadFinishedNotification")

    static let sendWillStart = Notification.Name("SSEMIDIControllerSendWillStartNotification")
    static let sendFinished = Notification.Name("SSEMIDIControllerSendFinishedNotification")
        // userInfo has NSNumber for key "success" indicating if all messages were sent
    static let sendFinishedImmediately = Notification.Name("SSEMIDIControllerSendFinishedImmediatelyNotification")

    static let programChangeBaseIndexPreferenceChanged = Notification.Name("SSEProgramChangeBaseIndexChangedNotification")
    static let customSysexBufferSizePreferenceChanged = Notification.Name("SSECustomSysexBufferSizePreferenceChangedNotification")

}

extension MIDIController /* Private */ {

    @objc private func sendPreferenceDidChange(_ notification: Notification?) {
        pauseTimeBetweenMessages = Double(UserDefaults.standard.integer(forKey: Self.timeBetweenSentSysExPreferenceKey)) / 1000.0
    }

    @objc private func receivePreferenceDidChange(_ notification: Notification?) {
        inputStream.sysExTimeOut = Double(UserDefaults.standard.integer(forKey: Self.sysExReadTimeOutPreferenceKey)) / 1000.0
    }

    @objc private func listenForProgramChangesPreferenceDidChange(_ notification: Notification?) {
        if UserDefaults.standard.bool(forKey: Self.listenForProgramChangesPreferenceKey) {
            if virtualInputStream == nil {
                let stream = VirtualInputStream(midiContext: midiContext)
                stream.delegate = self
                stream.messageDestination = self
                stream.selectedInputSources = Set(stream.inputSources)
                virtualInputStream = stream
            }
        }
        else {
            if let stream = virtualInputStream {
                stream.messageDestination = nil
                virtualInputStream = nil
            }
        }
    }

    private func selectFirstAvailableDestination() {
        if let destination = outputStream.destinations.first {
            selectedDestination = destination
        }
    }

    // MARK: Listening to sysex messages

    private func startListening() {
        inputStream.cancelReceivingSysExMessage()
            // In case a sysex message is currently being received

        messages = []
        messageBytesRead = 0
        totalBytesRead = 0

        listeningToSysexMessages = true
    }

    private func updateSysExReadStatus(byteCount: Int) {
        messageBytesRead = byteCount

        // We want multiple updates to get coalesced, so only do this once
        if !scheduledUpdateSysExReadIndicator {
            self.performSelector(onMainThread: #selector(updateSysExReadIndicator), with: nil, waitUntilDone: false)
            scheduledUpdateSysExReadIndicator = true
        }
    }

    @objc func updateSysExReadIndicator() {
        NotificationCenter.default.post(name: .readStatusChanged, object: self)
        scheduledUpdateSysExReadIndicator = false
    }

    // MARK: Sending sysex messages

    @objc private func sendNextSysExMessage() {
        sendStatus = .sending
        outputStream.takeMIDIMessages([messages[sendingMessageIndex]])
    }

    private func sendNextSysExMessageAfterDelay() {
        if sendStatus == .willDelayBeforeNext {
            // wait for pauseTimeBetweenMessages, then sendNextSysExMessage
            sendStatus = .delayingBeforeNext
            self.perform(#selector(sendNextSysExMessage), with: nil, afterDelay: pauseTimeBetweenMessages)
        }
        else if sendStatus == .cancelled {
            // The user cancelled before we got here, so finish the cancellation now
            sendStatus = .finishing
            finishedSendingMessages(success: false)
        }
    }

    private func finishedSendingMessages(success: Bool) {
        NotificationCenter.default.post(name: .sendFinished, object: self, userInfo: ["success": success])

        // Now we are done with the messages and can get rid of them
        messages = []

        sendStatus = .idle
    }

    @objc private func customSysexBufferSizeChanged(_ notification: Notification) {
        outputStream.customSysExBufferSize = UserDefaults.standard.integer(forKey: Self.customSysexBufferSizePreferenceKey)
    }

}

extension MIDIController: InputStreamDelegate {

    func inputStreamReadingSysEx(_ stream: SnoizeMIDI.InputStream, byteCountSoFar: Int, streamSource: InputStreamSource) {
        updateSysExReadStatus(byteCount: byteCountSoFar)
    }

    func inputStreamFinishedReadingSysEx(_ stream: SnoizeMIDI.InputStream, byteCount: Int, streamSource: InputStreamSource, isValid: Bool) {
        updateSysExReadStatus(byteCount: byteCount)
    }

    func inputStreamSourceListChanged(_ stream: SnoizeMIDI.InputStream) {
        if stream === inputStream {
            inputStream.selectedInputSources = Set(inputStream.inputSources)
        }
    }

}

extension MIDIController: CombinationOutputStreamDelegate {

    func combinationOutputStreamDestinationsChanged(_ stream: CombinationOutputStream) {
        mainWindowController?.synchronizeDestinations()
    }

    func combinationOutputStreamDestinationDisappeared(_ stream: CombinationOutputStream) {
        if sendStatus == .sending || sendStatus == .willDelayBeforeNext || sendStatus == .delayingBeforeNext {
            cancelSendingMessages()
        }

        selectFirstAvailableDestination()
    }

    // Sent when sysex begins sending and ends sending.
    func combinationOutputStream(_ stream: CombinationOutputStream, willBeginSendingSysEx request: SysExSendRequest) {
        currentSendRequest = request
    }

    func combinationOutputStream(_ stream: CombinationOutputStream, didEndSendingSysEx request: SysExSendRequest) {
        // NOTE: The request may or may not have finished successfully.
        guard request == currentSendRequest else { return }

        bytesSent += request.bytesSent
        sendingMessageIndex += 1
        currentSendRequest = nil

        if sendStatus == .cancelled {
            sendStatus = .finishing
            finishedSendingMessages(success: false)
        }
        else if sendingMessageIndex < sendingMessageCount && request.wereAllBytesSent {
            sendStatus = .willDelayBeforeNext
            sendNextSysExMessageAfterDelay()
        }
        else {
            sendStatus = .finishing
            finishedSendingMessages(success: request.wereAllBytesSent)
        }

    }

}
