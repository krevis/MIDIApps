/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class SMMPreferencesWindowController: SMMWindowController, NSWindowRestoration {

    @objc static let sharedInstance = SMMPreferencesWindowController(windowNibName: "Preferences")

    //
    // Internal
    //

    static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        completionHandler(sharedInstance.window, nil)
    }

    @IBOutlet var tabView: NSTabView!
    @IBOutlet var timeFormatMatrix: NSMatrix!
    @IBOutlet var noteFormatMatrix: NSMatrix!
    @IBOutlet var controllerFormatMatrix: NSMatrix!
    @IBOutlet var dataFormatMatrix: NSMatrix!
    @IBOutlet var programChangeBaseIndexMatrix: NSMatrix!
    @IBOutlet var autoSelectOrdinarySourcesCheckbox: NSButton!
    @IBOutlet var autoSelectVirtualDestinationCheckbox: NSButton!
    @IBOutlet var autoSelectSpyingDestinationsCheckbox: NSButton!
    @IBOutlet var autoConnectRadioButtons: NSMatrix!
    @IBOutlet var askBeforeClosingModifiedWindowCheckbox: NSButton!
    @IBOutlet var alwaysSaveSysExWithEOXMatrix: NSMatrix!
    @IBOutlet var expertModeCheckbox: NSButton!
    @IBOutlet var expertModeTextField: NSTextField!

    override func windowDidLoad() {
        guard let window = window else { fatalError() }

        super.windowDidLoad()

        window.restorationClass = Self.self

        // Make sure the first tab is selected (just in case someone changed it while editing the nib)
        tabView.selectFirstTabViewItem(nil)

        let defaults = UserDefaults.standard

        timeFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMTimeFormatPreferenceKey))
        noteFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMNoteFormatPreferenceKey))
        controllerFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMControllerFormatPreferenceKey))
        dataFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMDataFormatPreferenceKey))
        programChangeBaseIndexMatrix.selectCell(withTag: defaults.integer(forKey: SMProgramChangeBaseIndexPreferenceKey))

        expertModeCheckbox.intValue = defaults.bool(forKey: SMExpertModePreferenceKey) ? 1 : 0
        updateExpertModeTextField()

        autoSelectOrdinarySourcesCheckbox.intValue = defaults.bool(forKey: SMMPreferenceKeys.autoSelectOrdinarySourcesInNewDocument) ? 1 : 0
        autoSelectVirtualDestinationCheckbox.intValue = defaults.bool(forKey: SMMPreferenceKeys.autoSelectVirtualDestinationInNewDocument) ? 1 : 0
        autoSelectSpyingDestinationsCheckbox.intValue = defaults.bool(forKey: SMMPreferenceKeys.autoSelectSpyingDestinationsInNewDocument) ? 1 : 0
        autoConnectRadioButtons.selectCell(withTag: defaults.integer(forKey: SMMPreferenceKeys.autoConnectNewSources))

        askBeforeClosingModifiedWindowCheckbox.intValue = defaults.bool(forKey: SMMPreferenceKeys.askBeforeClosingModifiedWindow) ? 1 : 0
        alwaysSaveSysExWithEOXMatrix.selectCell(withTag: defaults.bool(forKey: SMMPreferenceKeys.saveSysExWithEOXAlways) ? 1 : 0)
    }

    @IBAction func changeTimeFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMTimeFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeNoteFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMNoteFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeControllerFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMControllerFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeDataFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMDataFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeAutoSelectOrdinarySources(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: SMMPreferenceKeys.autoSelectOrdinarySourcesInNewDocument)
    }

    @IBAction func changeAutoSelectVirtualDestination(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: SMMPreferenceKeys.autoSelectVirtualDestinationInNewDocument)
    }

    @IBAction func changeAutoSelectSpyingDestinations(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: SMMPreferenceKeys.autoSelectSpyingDestinationsInNewDocument)
    }

    @IBAction func changeAskBeforeClosingModifiedWindow(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: SMMPreferenceKeys.askBeforeClosingModifiedWindow)
    }

    @IBAction func changeAlwaysSaveSysExWithEOX(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: SMMPreferenceKeys.saveSysExWithEOXAlways)
    }

    @IBAction func changeExpertMode(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey:SMExpertModePreferenceKey)
        updateExpertModeTextField()
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeNewSourcesRadio(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMMPreferenceKeys.autoConnectNewSources)
    }

    @IBAction func changeProgramChangeBaseIndex(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMProgramChangeBaseIndexPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    func sendDisplayPreferenceChangedNotification() {
        NotificationCenter.default.post(name: .displayPreferenceChanged, object: nil)
    }

    func updateExpertModeTextField() {
        let text: String
        if UserDefaults.standard.bool(forKey: SMExpertModePreferenceKey) {
            text = NSLocalizedString("EXPERT_ON", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), value: "• Data formatted as raw hexadecimal\n• Note On with velocity 0 shows as Note On\n• Zero timestamp shows 0", comment: "Explanation when expert mode is on")
        }
        else {
            text = NSLocalizedString("EXPERT_OFF", tableName: "MIDIMonitor", bundle: SMBundleForObject(self), value: "• Data formatted according to settings above\n• Note On with velocity 0 shows as Note Off\n• Zero timestamp shows time received", comment: "Explanation when expert mode is off")
        }

        expertModeTextField.stringValue = text
    }

}

extension Notification.Name {
    static let displayPreferenceChanged = Notification.Name("SMMDisplayPreferenceChangedNotification")
}

// TODO Get rid of this when objc is fully removed
@objc extension NSNotification {
    static let displayPreferenceChangedNotification = Notification.Name.displayPreferenceChanged
}
