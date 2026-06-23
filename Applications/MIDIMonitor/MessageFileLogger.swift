/*
 Copyright (c) 2026, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import SnoizeMIDI

final class MessageFileLogger: NSObject, MessageDestination {
    private var fileHandle: FileHandle?
    private var logURL: URL?

    func startLogging(toFileNamed name: String) {
        stopLogging()

        let url = resolveLogURL(from: name)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            fileHandle = handle
            logURL = url
        }
        catch {
            NSLog("Unable to open log file at %@: %@", url.path, String(describing: error))
            fileHandle = nil
            logURL = nil
        }
    }

    func stopLogging() {
        fileHandle?.closeFile()
        fileHandle = nil
        logURL = nil
    }

    // MARK: MessageDestination

    func takeMIDIMessages(_ messages: [Message]) {
        guard let fileHandle else { return }

        let expertMode = UserDefaults.standard.bool(forKey: MessageFormatter.expertModePreferenceKey)
        let lines = messages.map { message -> String in
            let data = expertMode ? message.expertDataForDisplay : message.dataForDisplay
            return [
                message.timeStampForDisplay,
                message.originatingEndpointForDisplay,
                message.typeForDisplay,
                message.channelForDisplay,
                data
            ].joined(separator: "\t")
        }
        let payload = lines.joined(separator: "\n") + "\n"
        if let data = payload.data(using: .utf8) {
            fileHandle.write(data)
        }
    }

    private func resolveLogURL(from name: String) -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = (trimmed as NSString).expandingTildeInPath
        if path.contains("/") {
            return URL(fileURLWithPath: path)
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents", isDirectory: true)
        let baseURL = documentsURL.appendingPathComponent("MIDI Monitor Logs", isDirectory: true)
        return baseURL.appendingPathComponent(path)
    }
}
