/*
 Copyright (c) 2001-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI
import Sparkle.SPUUpdater

class PreferencesWindowController: UtilityWindowController, NSWindowRestoration {

    static let shared = PreferencesWindowController(windowNibName: "Preferences")

    // Allow bindings in the nib to get to the app's updater
    @objc var updater: SPUUpdater? {
        (NSApp.delegate as? AppController)?.updaterController?.updater
    }

    //
    // Internal
    //

    static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        completionHandler(shared.window, nil)
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
        guard let window else { fatalError() }

        super.windowDidLoad()

        window.restorationClass = Self.self

        // Make sure the first tab is selected (just in case someone changed it while editing the nib)
        tabView.selectFirstTabViewItem(nil)

        let defaults = UserDefaults.standard

        timeFormatMatrix.selectCell(withTag: defaults.integer(forKey: MessageFormatter.timeFormatPreferenceKey))
        noteFormatMatrix.selectCell(withTag: defaults.integer(forKey: MessageFormatter.noteFormatPreferenceKey))
        controllerFormatMatrix.selectCell(withTag: defaults.integer(forKey: MessageFormatter.controllerFormatPreferenceKey))
        dataFormatMatrix.selectCell(withTag: defaults.integer(forKey: MessageFormatter.dataFormatPreferenceKey))
        programChangeBaseIndexMatrix.selectCell(withTag: defaults.integer(forKey: MessageFormatter.programChangeBaseIndexPreferenceKey))

        expertModeCheckbox.intValue = defaults.bool(forKey: MessageFormatter.expertModePreferenceKey) ? 1 : 0
        updateExpertModeTextField()

        autoSelectOrdinarySourcesCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.selectOrdinarySourcesInNewDocument) ? 1 : 0
        autoSelectVirtualDestinationCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.selectVirtualDestinationInNewDocument) ? 1 : 0
        autoSelectSpyingDestinationsCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.selectSpyingDestinationsInNewDocument) ? 1 : 0
        autoConnectRadioButtons.selectCell(withTag: defaults.integer(forKey: PreferenceKeys.autoConnectNewSources))

        askBeforeClosingModifiedWindowCheckbox.intValue = defaults.bool(forKey: PreferenceKeys.askBeforeClosingModifiedWindow) ? 1 : 0
        alwaysSaveSysExWithEOXMatrix.selectCell(withTag: defaults.bool(forKey: PreferenceKeys.saveSysExWithEOXAlways) ? 1 : 0)
    }

    @IBAction func changeTimeFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: MessageFormatter.timeFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeNoteFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: MessageFormatter.noteFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeControllerFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: MessageFormatter.controllerFormatPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeDataFormat(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: MessageFormatter.dataFormatPreferenceKey)
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
        UserDefaults.standard.set(sender.intValue, forKey: MessageFormatter.expertModePreferenceKey)
        updateExpertModeTextField()
        sendDisplayPreferenceChangedNotification()
    }

    @IBAction func changeNewSourcesRadio(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: PreferenceKeys.autoConnectNewSources)
    }

    @IBAction func changeProgramChangeBaseIndex(_ sender: NSControl!) {
        UserDefaults.standard.set(sender.selectedTag(), forKey: MessageFormatter.programChangeBaseIndexPreferenceKey)
        sendDisplayPreferenceChangedNotification()
    }

    private func sendDisplayPreferenceChangedNotification() {
        NotificationCenter.default.post(name: .displayPreferenceChanged, object: nil)
    }

    private func updateExpertModeTextField() {
        let text: String
        if UserDefaults.standard.bool(forKey: MessageFormatter.expertModePreferenceKey) {
            text = NSLocalizedString("EXPERT_ON", tableName: "MIDIMonitor", bundle: Bundle.main, value: "• Data formatted as raw hexadecimal\n• Note On with velocity 0 shows as Note On\n• Zero timestamp shows 0", comment: "Explanation when expert mode is on")
        }
        else {
            text = NSLocalizedString("EXPERT_OFF", tableName: "MIDIMonitor", bundle: Bundle.main, value: "• Data formatted according to settings above\n• Note On with velocity 0 shows as Note Off\n• Zero timestamp shows time received", comment: "Explanation when expert mode is off")
        }

        expertModeTextField.stringValue = text
    }

}

extension Notification.Name {

    static let displayPreferenceChanged = Notification.Name("SMMDisplayPreferenceChangedNotification")

}
