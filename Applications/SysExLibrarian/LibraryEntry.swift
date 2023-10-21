/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class LibraryEntry: NSObject {

    init(library: Library) {
        self.library = library
        super.init()
    }

    convenience init(library: Library, dictionary: [String: Any]) {
        self.init(library: library)
        setValues(fromDictionary: dictionary)
    }

    unowned var library: Library!

    var dictionaryValues: [String: Any] {
        var dict: [String: Any] = [:]

        if let bookmarkData = alias?.data {
            dict["bookmark"] = bookmarkData
        }

        if let oldAliasRecordData {
            dict["alias"] = oldAliasRecordData
        }

        if let name {
            dict["name"] = name
        }

        if let manufacturer {
            dict["manufacturerName"] = manufacturer
        }

        if let size {
            dict["size"] = size
        }

        if let messageCount {
            dict["messageCount"] = messageCount
        }

        if let programNumber {
            dict["programNumber"] = programNumber
        }

        return dict
    }

    var path: String? {
        get {
            let wasFilePresent = hasLookedForFile && privateIsFilePresent
            hasLookedForFile = true

            let filePath = alias?.path(allowingMountingUI: false)
            if let extantFilePath = filePath {
                privateIsFilePresent = FileManager.default.fileExists(atPath: extantFilePath)
                if privateIsFilePresent {
                    name = FileManager.default.displayName(atPath: extantFilePath)
                }
            }
            else {
                privateIsFilePresent = false
            }

            if privateIsFilePresent != wasFilePresent {
                library.noteEntryChanged()
            }

            return filePath
        }
        set {
            alias = newValue != nil ? Alias(path: newValue!) : nil
            oldAliasRecordData = nil

            library.noteEntryChanged()
        }
    }

    private(set) var name: String? {
        didSet {
            if name != oldValue {
                NotificationCenter.default.post(name: .libraryEntryNameDidChange, object: self)
                library.noteEntryChanged()
            }
        }
    }

    func setNameFromFile() {
        var newName: String?

        if let path {
            newName = FileManager.default.displayName(atPath: path)
        }

        name = newName ?? NSLocalizedString("Unknown", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Unknown")
    }

    func renameFile(_ newFileName: String) -> Bool {
        guard let path else { return false }

        let fixResult = fixNewFileName(path, newFileName)

        let newPath = ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(fixResult.fixedNewFileName)
        var success = false

        if newPath == path {
            success = true
        }
        else if FileManager.default.fileExists(atPath: newPath) {
            success = false
        }
        else {
            do {
                try FileManager.default.moveItem(atPath: path, toPath: newPath)
                success = true
            }
            catch { /* success is still false */ }
        }

        if success && (fixResult.shouldHideExtension || fixResult.shouldShowExtension) {
            do {
                try FileManager.default.setAttributes([.extensionHidden: fixResult.shouldHideExtension], ofItemAtPath: newPath)
            }
            catch { /* It is no big deal if this fails */ }
        }

        if success {
            self.path = newPath // Update our alias to the file
            setNameFromFile()   // Make sure we are consistent with the Finder
        }

        return success
    }

    private struct FileNameFixResult {
        let fixedNewFileName: String
        let shouldHideExtension: Bool
        let shouldShowExtension: Bool
    }

    private func fixNewFileName(_ path: String, _ newFileName: String) -> FileNameFixResult {
        let fileName = (path as NSString).lastPathComponent
        let fileExtension = (fileName as NSString).pathExtension

        // Calculate the new file name, keeping the same extension as before.
        let modifiedNewFileName: String
        var shouldHideExtension = false
        var shouldShowExtension = false
        if !fileExtension.isEmpty {
            // The old file name had an extension. We need to make sure the new name has the same extension.
            let newExtension = (newFileName as NSString).pathExtension
            if !newExtension.isEmpty {
                // Both the old and new file names have extensions.
                if newExtension == fileExtension {
                    // The extensions are the same, so use the new name as it is.
                    modifiedNewFileName = newFileName
                    // But show the extension, since the user explicitly stated it.
                    shouldShowExtension = true
                }
                else {
                    // The extensions are different. Just tack the old extension on to the new name.
                    modifiedNewFileName = (newFileName as NSString).appendingPathExtension(fileExtension) ?? newFileName
                    // And make sure the extension is hidden in the filesystem.
                    shouldHideExtension = true
                    // FUTURE: In this case, we should ask the user whether they really want to change the extension.
                }
            }
            else {
                // The new file name has no extension, so add the old one on.
                modifiedNewFileName = (newFileName as NSString).appendingPathExtension(fileExtension) ?? newFileName
                // We also want to hide the extension from the user, so it looks like the new name was granted.
                shouldHideExtension = true
            }
        }
        else {
            // The old file name had no extension, so just accept the new name as it is.
            modifiedNewFileName = newFileName
        }

        /* FUTURE: We should do something like the code below (not sure if it's correct):
        // Limit new file name to 255 unicode characters, because that's all HFS+ will allow.
        // NOTE Yes, we should be taking into account the actual filesystem, which might not be HFS+.
        if ([modifiedNewFileName length] > 255) {
            NSString *withoutExtension;
            NSString *newExtension;

            withoutExtension = [modifiedNewFileName stringByDeletingPathExtension];
            newExtension =  [modifiedNewFileName pathExtension];
            withoutExtension = [withoutExtension substringToIndex:(255 - [newExtension length] - 1)];
            modifiedNewFileName = [withoutExtension stringByAppendingPathExtension:newExtension];
        }
        */

        // Path separator idiocy:
        // The Finder does not allow the ':' character in file names -- it beeps and changes it to '-'. So we do the same.
        // We always need to change '/' to a different character, since (as far as I know) there is no way of escaping the '/' character from NSFileManager calls. It gets changed to ":" in the Finder for all file systems, so let's just do that. (Note that the character will still display as '/'!)
        let fixedNewFileName = modifiedNewFileName.replacingOccurrences(of: ":", with: "-", options: .literal).replacingOccurrences(of: "/", with: ":", options: .literal)

        return FileNameFixResult(fixedNewFileName: fixedNewFileName, shouldHideExtension: shouldHideExtension, shouldShowExtension: shouldShowExtension)
    }

    var messages: [SystemExclusiveMessage] {
        var messages: [SystemExclusiveMessage] = []

        if let path,
           let data = NSData(contentsOfFile: path) as Data? {
            switch library.typeOfFile(atPath: path) {
            case .raw:
                messages = SystemExclusiveMessage.messages(fromData: data)
                updateDerivedInformation(messages)
            case .standardMIDI:
                messages = SystemExclusiveMessage.messages(fromStandardMIDIFileData: data)
                updateDerivedInformation(messages)
            default:
                break
            }
        }

        return messages
    }

    var isFilePresent: Bool {
        if !hasLookedForFile {
            _ = self.path
        }

        return privateIsFilePresent
    }

    var isFilePresentIgnoringCachedValue: Bool {
        hasLookedForFile = false
        return isFilePresent
    }

    var isFileInLibraryFileDirectory: Bool {
        guard isFilePresentIgnoringCachedValue, let path else { return false }
        return library.isPathInFileDirectory(path)
    }

    var fileReadError: Error? {
        guard let path else { return nil }
        do {
            _ = try NSData(contentsOfFile: path, options: [])
            return nil
        }
        catch {
            return error
        }
    }

    var programNumber: UInt8? /* 0 ..< 127 */ {
        didSet {
            if oldValue != programNumber {
                library.noteEntryChanged()
            }
        }
    }

    // Derived information (comes from messages, but gets cached in the entry)

    private(set) var manufacturer: String? {
        didSet {
            if oldValue != manufacturer {
                library.noteEntryChanged()
            }
        }
    }

    private(set) var size: Int? {
        didSet {
            if oldValue != size {
                library.noteEntryChanged()
            }
        }
    }

    private(set) var messageCount: Int? {
        didSet {
            if oldValue != messageCount {
                library.noteEntryChanged()
            }
        }
    }

    // MARK: Private

    private var hasLookedForFile = false
    private var privateIsFilePresent = false
    private var alias: Alias?
    private var oldAliasRecordData: Data?

}

extension Notification.Name {

    // notification.object is the LibraryEntry
    static let libraryEntryNameDidChange = Notification.Name("SSELibraryEntryNameDidChangeNotification")

}

extension LibraryEntry /* Private */ {

    static private func manufacturer(messages: [SystemExclusiveMessage]) -> String {
        var newManufacturer: String?
        for message in messages {
            if let messageManufacturer = message.manufacturerName {
                if let manufacturerSoFar = newManufacturer {
                    if manufacturerSoFar != messageManufacturer {
                        newManufacturer = NSLocalizedString("Various", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Various")
                        break
                    }
                }
                else {
                    newManufacturer = messageManufacturer
                }
            }
        }

        return newManufacturer ?? NSLocalizedString("Unknown", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "Unknown")
    }

    static private func size(messages: [SystemExclusiveMessage]) -> Int {
        messages.map(\.fullMessageDataLength).reduce(0, (+))
        // messages.reduce(0, { $0 + $1.fullMessageDataLength })
    }

    static private func messageCount(messages: [SystemExclusiveMessage]) -> Int {
        messages.count
    }

    private func updateDerivedInformation(_ messages: [SystemExclusiveMessage]) {
        manufacturer = Self.manufacturer(messages: messages)
        size = Self.size(messages: messages)
        messageCount = Self.messageCount(messages: messages)
    }

    private func setValues(fromDictionary dict: [String: Any]) {
        precondition(alias == nil)
        if let bookmarkData = dict["bookmark"] as? Data {
            alias = Alias(data: bookmarkData)
        }
        // backwards compatibility
        if let oldAliasData = dict["alias"] as? Data {
            // Use this to create an alias if we didn't already
            if alias == nil {
                alias = Alias(aliasRecordData: oldAliasData)
            }
            // Save this data to write out for old clients
            oldAliasRecordData = oldAliasData
        }

        precondition(name == nil)
        if let string = dict["name"] as? String {
            name = string
        }
        else {
            setNameFromFile()
        }

        precondition(manufacturer == nil)
        if let string = dict["manufacturerName"] as? String {
            manufacturer = string
        }

        if let number = dict["programNumber"] as? UInt8 {
            programNumber = number
        }

        precondition(size == nil)
        if let number = dict["size"] as? Int {
            size = number
        }

        precondition(messageCount == nil)
        if let number = dict["messageCount"] as? Int {
            messageCount = number
        }
    }

}
