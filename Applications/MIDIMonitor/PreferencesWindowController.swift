/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class PreferencesWindowController: UtilityWindowController, NSWindowRestoration {

    static let sharedInstance = PreferencesWindowController(windowNibName: "Preferences")

    //
    // Internal
    //

    static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        completionHandler(sharedInstance.window, nil)
    }

    @IBOutlet private var tabView: NSTabView!
    @IBOutlet private var timeFormatMatrix: NSMatrix!
    @IBOutlet private var noteFormatMatrix: NSMatrix!
    @IBOutlet private var controllerFormatMatrix: NSMatrix!
    @IBOutlet private var dataFormatMatrix: NSMatrix!
    @IBOutlet private var programChangeBaseIndexMatrix: NSMatrix!
    @IBOutlet private var autoSelectOrdinarySourcesCheckbox: NSButton!
    @IBOutlet private var autoSelectVirtualDestinationCheckbox: NSButton!
    @IBOutlet private var autoSelectSpyingDestinationsCheckbox: NSButton!
    @IBOutlet private var autoConnectRadioButtons: NSMatrix!
    @IBOutlet private var askBeforeClosingModifiedWindowCheckbox: NSButton!
    @IBOutlet private var alwaysSaveSysExWithEOXMatrix: NSMatrix!
    @IBOutlet private var expertModeCheckbox: NSButton!
    @IBOutlet private var expertModeTextField: NSTextField!

    override func windowDidLoad() {
        guard let window = window else { fatalError() }

        super.windowDidLoad()

        window.restorationClass = Self.self

        // Make sure the first tab is selected (just in case someone changed it while editing the nib)
        tabView.selectFirstTabViewItem(nil)

        let defaults = UserDefaults.standard

        timeFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMMessage.timeFormatPreferenceKey))
        noteFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMMessage.noteFormatPreferenceKey))
        controllerFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMMessage.controllerFormatPreferenceKey))
        dataFormatMatrix.selectCell(withTag: defaults.integer(forKey: SMMessage.dataFormatPreferenceKey))
        programChangeBaseIndexMatrix.selectCell(withTag: defaults.integer(forKey: SMMessage.programChangeBaseIndexPreferenceKey))

        expertModeCheckbox.intValue = defaults.bool(forKey: SMMessage.expertModePreferenceKey) ? 1 : 0
        updateExpertModeTextField()

        autoSelectOrdinarySourcesCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.selectOrdinarySourcesInNewDocument) ? 1 : 0
        autoSelectVirtualDestinationCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.selectVirtualDestinationInNewDocument) ? 1 : 0
        autoSelectSpyingDestinationsCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.selectSpyingDestinationsInNewDocument) ? 1 : 0
        autoConnectRadioButtons.selectCell(withTag: defaults.integer(forKey: PreferenceKeys.autoConnectNewSources))

        askBeforeClosingModifiedWindowCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.askBeforeClosingModifiedWindow) ? 1 : 0
        alwaysSaveSysExWithEOXMatrix.selectCell(withTag: defaults.bool(forKey: PreferenceKeys.saveSysExWithEOXAlways) ? 1 : 0)
    }

    @IBAction func changeTimeFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMMessage.timeFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeNoteFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMMessage.noteFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeControllerFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMMessage.controllerFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeDataFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMMessage.dataFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeAutoSelectOrdinarySources(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: PreferenceKeys.selectOrdinarySourcesInNewDocument)
    }

    @IBAction func changeAutoSelectVirtualDestination(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: PreferenceKeys.selectVirtualDestinationInNewDocument)
    }

    @IBAction func changeAutoSelectSpyingDestinations(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: PreferenceKeys.selectSpyingDestinationsInNewDocument)
    }

    @IBAction func changeAskBeforeClosingModifiedWindow(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: PreferenceKeys.askBeforeClosingModifiedWindow)
    }

    @IBAction func changeAlwaysSaveSysExWithEOX(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: PreferenceKeys.saveSysExWithEOXAlways)
    }

    @IBAction func changeExpertMode(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.intValue, forKey: SMMessage.expertModePreferenceKey)
        updateExpertModeTextField()
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeNewSourcesRadio(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: PreferenceKeys.autoConnectNewSources)
    }

    @IBAction func changeProgramChangeBaseIndex(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: SMMessage.programChangeBaseIndexPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    private func sendDisplayPreferenceChangedNotification() {
        NotificationCenter.default.post(name: .displayPreferenceChanged, object: nil)
    }

    private func updateExpertModeTextField() {
        let text: String
        if UserDefaults.standard.bool(forKey: SMMessage.expertModePreferenceKey) {
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
