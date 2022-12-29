/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI
import Sparkle.SPUStandardUpdaterController

class AppController: NSObject {

    override init() {
        super.init()
    }

    @IBOutlet var updaterController: SPUStandardUpdaterController?

    private(set) var midiContext: MIDIContext?

    // MARK: Private
    private var hasFinishedLaunching = false
    private var filePathsToImport: [String] = []

}

extension AppController: NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large
        // pause after it stops bouncing but before the app's window opens.
        // (CoreMIDI needs to find and possibly start its server process, which can take a while.)
        let context = MIDIContext()
        midiContext = context
        if !context.connectedToCoreMIDI {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Error", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of error alert")
            alert.informativeText = NSLocalizedString("There was a problem initializing the MIDI system. To try to fix this, log out and log back in, or restart the computer.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "error message if MIDI initialization fails")
            alert.addButton(withTitle: NSLocalizedString("Quit", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of quit button"))

            _ = alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        hasFinishedLaunching = true

        if let preflightErrorString = Library.shared.preflightAndLoadEntries() {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = NSLocalizedString("Error", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of error alert")
            alert.informativeText = preflightErrorString
            alert.addButton(withTitle: NSLocalizedString("Quit", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of quit button"))

            _ = alert.runModal()
            NSApp.terminate(nil)
        }
        else {
            showMainWindow(nil)

            if !filePathsToImport.isEmpty {
                importFiles()
            }
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        filePathsToImport.append(filename)

        if hasFinishedLaunching {
            showMainWindow(nil)
            importFiles()
        }

        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            if let mainWindow = MainWindowController.shared.window,
               mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
        }
        else {
            showMainWindow(nil)
        }

        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

}

extension AppController: NSUserInterfaceValidations {

    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(self.showMainWindowAndAddToLibrary(_:)) {
            // Don't allow adds if the main window is open and has a sheet on it
            let mainWindow = MainWindowController.shared.window
            return (mainWindow == nil || mainWindow!.attachedSheet == nil)
        }

        return true
    }

}

extension AppController /* Actions */ {

    @IBAction func showPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.showWindow(nil)
    }

    @IBAction func showAboutBox(_ sender: Any?) {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]

        // Don't show the version as "Version 1.5 (1.5)". Omit the "(1.5)".
        options[NSApplication.AboutPanelOptionKey.version] = ""

        // The RTF file Credits.rtf has foreground text color = black, but that's wrong for 10.14 dark mode.
        // Similarly the font is not necessarily the system font. Override both.
        if let creditsURL = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
           let credits = try? NSMutableAttributedString(url: creditsURL, options: [:], documentAttributes: nil) {
            let range = NSRange(location: 0, length: credits.length)
            credits.addAttribute(.font, value: NSFont.labelFont(ofSize: NSFont.labelFontSize), range: range)
            credits.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
            options[NSApplication.AboutPanelOptionKey.credits] = credits
        }

        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @IBAction func showHelp(_ sender: Any?) {
        var message: String?

        if var url = Bundle.main.url(forResource: "docs", withExtension: "htmld") {
            url.appendPathComponent("index.html")
            if !NSWorkspace.shared.open(url) {
                message = NSLocalizedString("The help file could not be opened.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "error message if opening the help file fails")
            }
        }
        else {
            message = NSLocalizedString("The help file could not be found.", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "error message if help file can't be found")
        }

        if let message {
            let title = NSLocalizedString("Error", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of error alert")

            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            _ = alert.runModal()
        }
    }

    @IBAction func sendFeedback(_ sender: Any?) {
        var success = false

        let feedbackEmailAddress = "SysExLibrarian@snoize.com"    // Don't localize this
        let feedbackEmailSubject = NSLocalizedString("SysEx Librarian Feedback", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "subject of feedback email")
        let mailToURLString = "mailto:\(feedbackEmailAddress)?Subject=\(feedbackEmailSubject)"

        // Escape the whitespace characters in the URL before opening
        let allowedCharacterSet = CharacterSet.whitespaces.inverted
        if let escapedMailToURLString = mailToURLString.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet),
           let mailToURL = URL(string: escapedMailToURLString) {
            success = NSWorkspace.shared.open(mailToURL)
        }

        if !success {
            let message = NSLocalizedString("SysEx Librarian could not ask your email application to create a new message.\nPlease send email to:\n%@", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "message of alert when can't send feedback email")

            let title = NSLocalizedString("Error", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "title of error alert")

            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = String.localizedStringWithFormat(message, feedbackEmailAddress)
            _ = alert.runModal()
        }
    }

    @IBAction func showMainWindow(_ sender: Any?) {
        MainWindowController.shared.showWindow(nil)
    }

    @IBAction func showMainWindowAndAddToLibrary(_ sender: Any?) {
        MainWindowController.shared.showWindow(nil)
        MainWindowController.shared.addToLibrary(sender)
    }

}

extension AppController /* Private */ {

    private func importFiles() {
        MainWindowController.shared.importFiles(filePathsToImport, showingProgress: false)
        filePathsToImport = []
    }

}
