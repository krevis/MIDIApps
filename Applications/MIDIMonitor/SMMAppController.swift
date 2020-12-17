/*
 Copyright (c) 2001-2014, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa
import CoreMIDI

class SMMAppController: NSObject {

    // TODO
    // @property (nonatomic, readonly) MIDISpyClientRef midiSpyClient;

    private let SMMOpenWindowsForNewSourcesPreferenceKey = "SMMOpenWindowsForNewSources"  // Obsolete

    enum AutoConnectOption: Int {
        case disabled
        case addInCurrentWindow
        case openNewWindow
    }

    private var shouldOpenUntitledDocument = false
    private var newlyAppearedSources: Set<SMSourceEndpoint>?

    override init() {
        super.init()
    }

    override func awakeFromNib() {
        // Migrate autoconnect preference, before we show any windows.
        // Old: SMMOpenWindowsForNewSourcesPreferenceKey = BOOL (default: false)
        // New: SMMPreferenceKeys.autoConnectNewSources = int (default: 1 = AutoConnectOption.addInCurrentWindow)

        let defaults = UserDefaults.standard
        if defaults.object(forKey: SMMOpenWindowsForNewSourcesPreferenceKey) != nil {
            let option: AutoConnectOption = defaults.bool(forKey: SMMOpenWindowsForNewSourcesPreferenceKey) ? .openNewWindow : .disabled
            defaults.set(option.rawValue, forKey: SMMPreferenceKeys.autoConnectNewSources)
            defaults.removeObject(forKey: SMMOpenWindowsForNewSourcesPreferenceKey)
        }
    }

}

extension SMMAppController: NSApplicationDelegate {

    // MARK: NSApplicationDelegate

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Before CoreMIDI is initialized, make sure the spying driver is installed
        let installError = MIDISpyInstallDriverIfNecessary()

        // Initialize CoreMIDI while the app's icon is still bouncing, so we don't have a large pause after it stops bouncing
        // but before the app's window opens.  (CoreMIDI needs to find and possibly start its server process, which can take a while.)
        guard SMClient.shared() != nil else {
            failedToInitCoreMIDI()
            return
        }

        // After this point, we are OK to open documents (untitled or otherwise)
        shouldOpenUntitledDocument = true

        if let err = installError {
            failedToInstallSpyDriver(err)
        }
        else {
            // Create our client for spying on MIDI output.
            let status = noErr // TODO MIDISpyClientCreate(&_midiSpyClient)
            if status != noErr {
                failedToConnectToSpyClient()
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return shouldOpenUntitledDocument
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Listen for new source endpoints. Don't do this earlier--we only are interested in ones
        // that appear after we've been launched.
        NotificationCenter.default.addObserver(self, selector: #selector(self.sourceEndpointsAppeared(_:)), name: .SMMIDIObjectsAppeared, object: SMSourceEndpoint.self)
    }

}

extension SMMAppController {

    // MARK: Menus and actions

    @IBAction func showPreferences(_ sender: AnyObject?) {
        SMMPreferencesWindowController.sharedInstance.showWindow(nil)
    }

    @IBAction func showAboutBox(_ sender: AnyObject?) {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]

        if #available(macOS 10.13, *) {
            options[NSApplication.AboutPanelOptionKey.version] = ""
        }
        else {
            // This works before the above API was available in 10.13
            options[NSApplication.AboutPanelOptionKey(rawValue: "Version")] = ""
        }

        // The RTF file Credits.rtf has foreground text color = black, but that's wrong for 10.14 dark mode.
        // Similarly the font is not necessarily the systme font. Override both.
        if #available(macOS 10.13, *) {
            if let creditsURL = Bundle.main.url(forResource: "Credits", withExtension: "rtf"),
               let credits = NSMutableAttributedString(url: creditsURL, documentAttributes: nil) {
                let range = NSRange(location: 0, length: credits.length)
                credits.addAttribute(.font, value: NSFont.labelFont(ofSize: NSFont.labelFontSize), range: range)
                if #available(macOS 10.14, *) {
                    credits.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
                }
                options[NSApplication.AboutPanelOptionKey.credits] = credits
            }
        }

        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @IBAction func showHelp(_ sender: AnyObject?) {
        var message: String?

        if var url = SMBundleForObject(self).url(forResource: "docs", withExtension: "htmld") {
            url.appendPathComponent("index.html")
            if !NSWorkspace.shared.open(url) {
                message = NSLocalizedString("The help file could not be opened.", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "error message if opening the help file fails")
            }
        }
        else {
            message = NSLocalizedString("The help file could not be found.", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "error message if help file can't be found")
        }

        if let message = message {
            let title = NSLocalizedString("Error", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "title of error alert")

            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
        }
    }

    @IBAction func sendFeedback(_ sender: AnyObject?) {
        var success = false

        let feedbackEmailAddress = "MIDIMonitor@snoize.com"    // Don't localize this
        let feedbackEmailSubject = NSLocalizedString("MIDI Monitor Feedback", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "subject of feedback email")
        let mailToURLString = "mailto:\(feedbackEmailAddress)?Subject=\(feedbackEmailSubject)"

        // Escape the whitespace characters in the URL before opening
        let allowedCharacterSet = CharacterSet.whitespaces.inverted
        if let escapedMailToURLString = mailToURLString.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet),
           let mailToURL = URL(string: escapedMailToURLString) {
            success = NSWorkspace.shared.open(mailToURL)
        }

        if !success {
            let message = NSLocalizedString("MIDI Monitor could not ask your email application to create a new message.\nPlease send email to:\n%@", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "message of alert when can't send feedback email")

            let title = NSLocalizedString("Error", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "title of error alert")

            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = String.localizedStringWithFormat(message, feedbackEmailAddress)
            alert.runModal()
        }
    }

    @IBAction func restartMIDI(_ sender: AnyObject?) {
        let status = MIDIRestart()
        if status != noErr {
            let message = NSLocalizedString("Rescanning the MIDI system resulted in an unexpected error (%d).", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "error message if MIDIRestart() fails")
            let title = NSLocalizedString("MIDI Error", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), comment: "title of MIDI error panel")

            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = String.localizedStringWithFormat(message, status)
            alert.runModal()
        }
    }

}

extension SMMAppController {

    // MARK: Startup failure handling

    private func failedToInitCoreMIDI() {
        let bundle = SMBundleForObject(self)!

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString("The MIDI system could not be started.", tableName: "MIDIMonitor", bundle: bundle, comment: "error message if MIDI initialization fails")
        alert.informativeText = NSLocalizedString("This probably affects all apps that use MIDI, not just MIDI Monitor.\n\nMost likely, the cause is a bad MIDI driver. Remove any MIDI drivers that you don't recognize, then try again.", tableName: "MIDIMonitor", bundle: bundle, comment: "informative text if MIDI initialization fails")
        alert.addButton(withTitle: NSLocalizedString("Quit", tableName: "MIDIMonitor", bundle: bundle, comment: "title of quit button"))
        alert.addButton(withTitle: NSLocalizedString("Show MIDI Drivers", tableName: "MIDIMonitor", bundle: bundle, comment: "Show MIDI Drivers button after MIDI spy client creation fails"))

        if alert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Library/Audio/MIDI Drivers"))
        }

        NSApp.terminate(nil)
    }

    private func failedToInstallSpyDriver(_ error: Error) {
        // Failure to install. Customize the error before presenting it.

        let bundle = SMBundleForObject(self)!
        let installError = error as NSError

        var presentedErrorUserInfo: [String: Any] = installError.userInfo
        presentedErrorUserInfo[NSLocalizedDescriptionKey] = NSLocalizedString("MIDI Monitor could not install its driver.", tableName: "MIDIMonitor", bundle: bundle, comment: "error message if spy driver install fails")

        if installError.domain == MIDISpyDriverInstallationErrorDomain {
            // Errors with this domain should be very rare and indicate a problem with the app itself.

            if let reason = installError.localizedFailureReason, reason != "" {
                presentedErrorUserInfo[NSLocalizedRecoverySuggestionErrorKey] =
                    reason
                    + "\n\n"
                    + NSLocalizedString("This shouldn't happen. Try downloading MIDI Monitor again.", tableName: "MIDIMonitor", bundle: bundle, comment: "suggestion if spy driver install fails due to our own error")
                    + "\n\n"
                    + NSLocalizedString("MIDI Monitor will not be able to see the output of other MIDI applications, but all other features will still work.", tableName: "MIDIMonitor", bundle: bundle, comment: "more suggestion if spy driver install fails")
            }
        }
        else {
            var fullSuggestion = ""

            if let reason = installError.localizedFailureReason, reason != "" {
                fullSuggestion += reason
            }

            if let suggestion = installError.localizedRecoverySuggestion, suggestion != "" {
                if fullSuggestion != "" {
                    fullSuggestion += "\n\n"
                }
                fullSuggestion += suggestion
            }

            if fullSuggestion != "" {
                presentedErrorUserInfo[NSLocalizedRecoverySuggestionErrorKey] =
                    fullSuggestion
                    + "\n\n"
                    + NSLocalizedString("MIDI Monitor will not be able to see the output of other MIDI applications, but all other features will still work.", tableName: "MIDIMonitor", bundle: bundle, comment: "more suggestion if spy driver install fails")
            }

            // To find the path involved, look for NSDestinationFilePath first (it's set for failures to copy, and is better than the source path),
            // then fall back to the documented keys.
            var filePath = installError.userInfo["NSDestinationFilePath"] as? String
            if filePath == nil {
                filePath = installError.userInfo[NSFilePathErrorKey] as? String
            }
            if filePath == nil {
                if let url = installError.userInfo[NSURLErrorKey] as? URL,
                   url.isFileURL {
                    filePath = url.path
                }
            }

            if let realFilePath = filePath, realFilePath != "" {
                presentedErrorUserInfo[NSFilePathErrorKey] = realFilePath
                presentedErrorUserInfo[NSLocalizedRecoveryOptionsErrorKey] = [
                    NSLocalizedString("Continue", tableName: "MIDIMonitor", bundle: bundle, comment: "Continue button if spy driver install fails"),
                    NSLocalizedString("Show in Finder", tableName: "MIDIMonitor", bundle: bundle, comment: "Show in Finder button if spy driver install fails")
                ]
                presentedErrorUserInfo[NSRecoveryAttempterErrorKey] = self
            }
        }

        let presentedError = NSError(domain: installError.domain, code: installError.code, userInfo: presentedErrorUserInfo)
        NSApp.presentError(presentedError)
    }

    // NSErrorRecoveryAttempting informal protocol
    @objc override func attemptRecovery(fromError error: Error, optionIndex recoveryOptionIndex: Int) -> Bool {
        if recoveryOptionIndex == 0 {
            // Continue: do nothing
        }
        else if recoveryOptionIndex == 1 {
            // Show in Finder
            let nsError = error as NSError
            if let filePath = nsError.userInfo[NSFilePathErrorKey] as? String {
                NSWorkspace.shared.selectFile(filePath, inFileViewerRootedAtPath: "")
            }
        }

        return true // recovery was successful
    }

    private func failedToConnectToSpyClient() {
        let bundle = SMBundleForObject(self)!

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("MIDI Monitor could not make a connection to its MIDI driver.", tableName: "MIDIMonitor", bundle: bundle, comment: "error message if MIDI spy client creation fails")
        alert.informativeText = NSLocalizedString("If you continue, MIDI Monitor will not be able to see the output of other MIDI applications, but all other features will still work.\n\nTo fix the problem:\n1. Remove any old 32-bit-only drivers from /Library/Audio/MIDI Drivers.\n2. Restart your computer.", tableName: "MIDIMonitor", bundle: bundle, comment: "second line of warning when MIDI spy is unavailable")
        alert.addButton(withTitle: NSLocalizedString("Continue", tableName: "MIDIMonitor", bundle: bundle, comment: "Continue button after MIDI spy client creation fails"))
        alert.addButton(withTitle: NSLocalizedString("Restart", tableName: "MIDIMonitor", bundle: bundle, comment: "Restart button after MIDI spy client creation fails"))
        alert.addButton(withTitle: NSLocalizedString("Show MIDI Drivers", tableName: "MIDIMonitor", bundle: bundle, comment: "Show MIDI Drivers button after MIDI spy client creation fails"))

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // Restart
            let ynAlert = NSAlert()
            ynAlert.messageText = NSLocalizedString("Are you sure you want to restart now?", tableName: "MIDIMonitor", bundle: bundle, comment: "Restart y/n?")
            ynAlert.addButton(withTitle: NSLocalizedString("Restart", tableName: "MIDIMonitor", bundle: bundle, comment: "Restart button title"))
            ynAlert.addButton(withTitle: NSLocalizedString("Cancel", tableName: "MIDIMonitor", bundle: bundle, comment: "Cancel button title"))
            if ynAlert.runModal() == .alertFirstButtonReturn {
                let appleScript = NSAppleScript(source: "tell application \"Finder\" to restart")
                appleScript?.executeAndReturnError(nil)
            }
        }
        else if response == .alertThirdButtonReturn {
            // Show MIDI Drivers
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Library/Audio/MIDI Drivers"))
        }
    }

}

extension SMMAppController {

    // MARK: When sources appear

    @objc func sourceEndpointsAppeared(_ notification: NSNotification) {
        guard let endpoints = notification.userInfo?[SMMIDIObjectsThatAppeared] as? [SMSourceEndpoint], endpoints.count > 0 else { return }

        if newlyAppearedSources == nil {
            newlyAppearedSources = Set<SMSourceEndpoint>()

            let autoConnectOption = AutoConnectOption(rawValue: UserDefaults.standard.integer(forKey: SMMPreferenceKeys.autoConnectNewSources))

            switch autoConnectOption {
            case .addInCurrentWindow:
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                    self.autoConnectToNewlyAppearedSources()
                }
            case .openNewWindow:
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                    self.openWindowForNewlyAppearedSources()
                }
            default:
                break
            }
        }

        newlyAppearedSources?.formUnion(endpoints)
    }

    private func autoConnectToNewlyAppearedSources() {
        if let sources = newlyAppearedSources,
           sources.count > 0,
           let document = (NSDocumentController.shared.currentDocument ?? NSApp.orderedDocuments.first) as? SMMDocument {
            document.selectedInputSources = document.selectedInputSources?.union(sources) ?? (sources as Set<AnyHashable>)

            if let windowController = document.windowControllers.first as? SMMMonitorWindowController {
                windowController.revealInputSources(sources as NSSet)
                document.updateChangeCount(.changeCleared)
            }
        }

        newlyAppearedSources = nil
    }

    private func openWindowForNewlyAppearedSources() {
        if let sources = newlyAppearedSources,
           sources.count > 0,
           let document = try? NSDocumentController.shared.openUntitledDocumentAndDisplay(false) as? SMMDocument {
            document.makeWindowControllers()
            document.selectedInputSources = sources as Set<AnyHashable>
            document.showWindows()

            if let windowController = document.windowControllers.first as? SMMMonitorWindowController {
                windowController.revealInputSources(sources as NSSet)
                document.updateChangeCount(.changeCleared)
            }
        }

        newlyAppearedSources = nil
    }

}
