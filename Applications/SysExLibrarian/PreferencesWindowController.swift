/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class PreferencesWindowController: GeneralWindowController {

    static let shared = PreferencesWindowController()

    init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return "Preferences"
    }

    // Allow bindings in the nib to get to the app's updater
    @objc var updater: SPUUpdater? {
        (NSApp.delegate as? AppController)?.updaterController?.updater
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Make sure the "General" tab is showing, just in case it was changed in the nib
        tabView.selectTabViewItem(withIdentifier: "general")
    }

    func windowWillClose(_ notification: Notification) {
        if isSysExSpeedTabViewItem(tabView.selectedTabViewItem) {
            sysExSpeedController.willHide()
        }
    }

    // MARK: Actions

    @IBAction override func showWindow(_ sender: Any?) {
        _ = window  // Make sure the window gets loaded before we do anything else

        synchronizeControls()

        if isSysExSpeedTabViewItem(tabView.selectedTabViewItem) {
            sysExSpeedController.willShow()
        }

        super.showWindow(sender)
    }

    @IBAction func changeSizeFormat(_ sender: Any?) {
        guard let control = sender as? NSControl, let cell = control.selectedCell() else { return }
        let boolValue = cell.tag == 1
        UserDefaults.standard.set(boolValue, forKey: MainWindowController.abbreviateSizesInLibraryPreferenceKey)
        NotificationCenter.default.post(name: .displayPreferenceChanged, object: nil)
    }

    @IBAction func changeDoubleClickToSendMessages(_ sender: Any?) {
        guard let control = sender as? NSControl else { return }
        let boolValue = control.integerValue > 0
        UserDefaults.standard.set(boolValue, forKey: MainWindowController.doubleClickToSendPreferenceKey)
        NotificationCenter.default.post(name: .doubleClickToSendPreferenceChanged, object: nil)
    }

    @IBAction func changeSysExFolder(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false

        openPanel.directoryURL = NSURL(fileURLWithPath: Library.shared.fileDirectoryPath, isDirectory: true) as URL
        openPanel.beginSheetModal(for: window!) { result in
            if result == .OK && openPanel.urls.count == 1,
               let url = openPanel.urls.first {
                Library.shared.fileDirectoryPath = url.path
                self.synchronizeControls()
            }
        }
    }

    @IBAction func changeReadTimeOut(_ sender: Any?) {
        guard let control = sender as? NSControl else { return }
        UserDefaults.standard.set(control.integerValue, forKey: MIDIController.sysExReadTimeOutPreferenceKey)
        synchronizeReadTimeOutField()
        NotificationCenter.default.post(name: .sysExReceivePreferenceChanged, object: nil)
    }

    @IBAction func changeIntervalBetweenSentMessages(_ sender: Any?) {
        guard let control = sender as? NSControl else { return }
        UserDefaults.standard.set(control.integerValue, forKey: MIDIController.timeBetweenSentSysExPreferenceKey)
        synchronizeIntervalBetweenSentMessagesField()
        NotificationCenter.default.post(name: .sysExSendPreferenceChanged, object: nil)
    }

    @IBAction func listenForProgramChanges(_ sender: Any?) {
        guard let control = sender as? NSControl else { return }
        let boolValue = control.integerValue > 0
        UserDefaults.standard.set(boolValue, forKey: MIDIController.listenForProgramChangesPreferenceKey)
        NotificationCenter.default.post(name: .listenForProgramChangesPreferenceChanged, object: nil)
    }

    @IBAction func interruptOnProgramChange(_ sender: Any?) {
        guard let control = sender as? NSControl else { return }
        let boolValue = control.integerValue > 0
        UserDefaults.standard.set(boolValue, forKey: MIDIController.interruptOnProgramChangePreferenceKey)
        // no need for a notification to be posted; relevant code looks up this value each time
    }

    @IBAction func programChangeBaseIndex(_ sender: Any?) {
        guard let control = sender as? NSControl, let cell = control.selectedCell() else { return }
        UserDefaults.standard.set(cell.tag, forKey: MIDIController.programChangeBaseIndexPreferenceKey)
        NotificationCenter.default.post(name: .programChangeBaseIndexPreferenceChanged, object: nil)
    }

    // MARK: Private

    @IBOutlet private var sizeFormatMatrix: NSMatrix!
    @IBOutlet private var sysExFolderPathField: NSTextField!
    @IBOutlet private var sysExReadTimeOutSlider: NSSlider!
    @IBOutlet private var sysExReadTimeOutField: NSTextField!
    @IBOutlet private var sysExIntervalBetweenSentMessagesSlider: NSSlider!
    @IBOutlet private var sysExIntervalBetweenSentMessagesField: NSTextField!
    @IBOutlet private var tabView: NSTabView!
    @IBOutlet private var doubleClickToSendMessagesButton: NSButton!
    @IBOutlet private var listenForProgramChangesButton: NSButton!
    @IBOutlet private var interruptOnProgramChangeButton: NSButton!
    @IBOutlet private var programChangeBaseIndexMatrix: NSMatrix!
    @IBOutlet private var sysExSpeedController: SysExSpeedController!

}

extension PreferencesWindowController: NSTabViewDelegate {

    func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        if isSysExSpeedTabViewItem(tabView.selectedTabViewItem) {
            sysExSpeedController.willHide()
        }
        if isSysExSpeedTabViewItem(tabViewItem) {
            sysExSpeedController.willShow()
        }
    }

}

extension PreferencesWindowController /* Private */ {

    private func isSysExSpeedTabViewItem(_ tabViewItem: NSTabViewItem?) -> Bool {
        guard let identifier = tabViewItem?.identifier as? String else { return false }
        return identifier == "speed"
    }

    private func synchronizeControls() {
        let defaults = UserDefaults.standard

        sizeFormatMatrix.selectCell(withTag: defaults.bool(forKey: MainWindowController.abbreviateSizesInLibraryPreferenceKey) ? 1 : 0)
        doubleClickToSendMessagesButton.integerValue = defaults.bool(forKey: MainWindowController.doubleClickToSendPreferenceKey) ? 1 : 0
        sysExFolderPathField.stringValue = Library.shared.fileDirectoryPath
        sysExReadTimeOutSlider.integerValue = defaults.integer(forKey: MIDIController.sysExReadTimeOutPreferenceKey)
        listenForProgramChangesButton.integerValue = defaults.bool(forKey: MIDIController.listenForProgramChangesPreferenceKey) ? 1 : 0
        interruptOnProgramChangeButton.integerValue = defaults.bool(forKey: MIDIController.interruptOnProgramChangePreferenceKey) ? 1 : 0
        programChangeBaseIndexMatrix.selectCell(withTag: defaults.integer(forKey: MIDIController.programChangeBaseIndexPreferenceKey))
        synchronizeReadTimeOutField()
        sysExIntervalBetweenSentMessagesSlider.integerValue = defaults.integer(forKey: MIDIController.timeBetweenSentSysExPreferenceKey)
        synchronizeIntervalBetweenSentMessagesField()
    }

    private func synchronizeReadTimeOutField() {
        sysExReadTimeOutField.stringValue = formatMilliseconds(UserDefaults.standard.integer(forKey: MIDIController.sysExReadTimeOutPreferenceKey))
    }

    private func synchronizeIntervalBetweenSentMessagesField() {
        sysExIntervalBetweenSentMessagesField.stringValue = formatMilliseconds(UserDefaults.standard.integer(forKey: MIDIController.timeBetweenSentSysExPreferenceKey))
    }

    private static var millisecondsFormat = NSLocalizedString("%ld milliseconds", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "format for milliseconds")
    private static var oneSecondString = NSLocalizedString("1 second", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "string for one second exactly")
    private static var oneSecondOrMoreFormat = NSLocalizedString("%#.3g seconds", tableName: "SysExLibrarian", bundle: Bundle.main, comment: "one second or more (formatting of milliseconds)")

    private func formatMilliseconds(_ msec: Int) -> String {
        if msec > 1000 {
            return String.localizedStringWithFormat(Self.oneSecondOrMoreFormat, Double(msec) / 1000.0)
        }
        else if msec == 1000 {
            return Self.oneSecondString
        }
        else {
            return String.localizedStringWithFormat(Self.millisecondsFormat, msec)
        }
    }

}

extension Notification.Name {

    static let displayPreferenceChanged = Notification.Name("SSEDisplayPreferenceChangedNotification")
    static let doubleClickToSendPreferenceChanged = Notification.Name("SSEDoubleClickToSendPreferenceChangedNotification")
    static let sysExSendPreferenceChanged = Notification.Name("SSESysExSendPreferenceChangedNotification")
    static let sysExReceivePreferenceChanged = Notification.Name("SSESysExReceivePreferenceChangedNotification")
    static let listenForProgramChangesPreferenceChanged = Notification.Name("SSEListenForProgramChangesPreferenceChangedNotification")

}
