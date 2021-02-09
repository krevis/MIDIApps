/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

@objc class PreferencesWindowController: SSEWindowController {

    @objc static let sharedInstance = PreferencesWindowController()

    init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var windowNibName: NSNib.Name? {
        return "Preferences"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Make sure the "General" tab is showing, just in case it was changed in the nib
        tabView.selectTabViewItem(withIdentifier: "general")
    }

    override func windowWillClose(_ notification: Notification) {
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

    @IBAction func changeSizeFormat(_ sender: AnyObject?) {
        guard let control = sender as? NSControl, let cell = control.selectedCell() else { return }
        let boolValue = cell.tag == 1
        UserDefaults.standard.set(boolValue, forKey: SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey)
        NotificationCenter.default.post(name: .displayPreferenceChanged, object: nil)
    }

    @IBAction func changeSysExFolder(_ sender: AnyObject?) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false

        guard let oldPath = SSELibrary.shared()?.fileDirectoryPath() else { return }
        openPanel.directoryURL = NSURL(fileURLWithPath: oldPath, isDirectory: true) as URL
        openPanel.beginSheetModal(for: window!) { result in
            if result == .OK && openPanel.urls.count == 1,
               let url = openPanel.urls.first {
                SSELibrary.shared()?.setFileDirectoryPath(url.path)
                self.synchronizeControls()
            }
        }
    }

    @IBAction func changeReadTimeOut(_ sender: AnyObject?) {
        guard let control = sender as? NSControl else { return }
        UserDefaults.standard.set(control.integerValue, forKey: MIDIController.sysExReadTimeOutPreferenceKey)
        synchronizeReadTimeOutField()
        NotificationCenter.default.post(name: .sysExReceivePreferenceChanged, object: nil)
    }

    @IBAction func changeIntervalBetweenSentMessages(_ sender: AnyObject?) {
        guard let control = sender as? NSControl else { return }
        UserDefaults.standard.set(control.integerValue, forKey: MIDIController.sysExIntervalBetweenSentMessagesPreferenceKey)
        synchronizeIntervalBetweenSentMessagesField()
        NotificationCenter.default.post(name: .sysExSendPreferenceChanged, object: nil)
    }

    @IBAction func listenForProgramChanges(_ sender: AnyObject?) {
        guard let control = sender as? NSControl else { return }
        let boolValue = control.integerValue > 0
        UserDefaults.standard.set(boolValue, forKey: MIDIController.listenForProgramChangesPreferenceKey)
        NotificationCenter.default.post(name: .listenForProgramChangesPreferenceChanged, object: nil)
    }

    @IBAction func interruptOnProgramChange(_ sender: AnyObject?) {
        guard let control = sender as? NSControl else { return }
        let boolValue = control.integerValue > 0
        UserDefaults.standard.set(boolValue, forKey: MIDIController.interruptOnProgramChangePreferenceKey)
        // no need for a notification to be posted; relevant code looks up this value each time
    }

    @IBAction func programChangeBaseIndex(_ sender: AnyObject?) {
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

        sizeFormatMatrix.selectCell(withTag: defaults.bool(forKey: SSEAbbreviateFileSizesInLibraryTableViewPreferenceKey) ? 1 : 0)
        sysExFolderPathField.stringValue = SSELibrary.shared()!.fileDirectoryPath()
        sysExReadTimeOutSlider.integerValue = defaults.integer(forKey: MIDIController.sysExReadTimeOutPreferenceKey)
        listenForProgramChangesButton.integerValue = defaults.bool(forKey: MIDIController.listenForProgramChangesPreferenceKey) ? 1 : 0
        interruptOnProgramChangeButton.integerValue = defaults.bool(forKey: MIDIController.interruptOnProgramChangePreferenceKey) ? 1 : 0
        programChangeBaseIndexMatrix.selectCell(withTag: defaults.integer(forKey: MIDIController.programChangeBaseIndexPreferenceKey))
        synchronizeReadTimeOutField()
        sysExIntervalBetweenSentMessagesSlider.integerValue = defaults.integer(forKey: MIDIController.sysExIntervalBetweenSentMessagesPreferenceKey)
        synchronizeIntervalBetweenSentMessagesField()
    }

    private func synchronizeReadTimeOutField() {
        sysExReadTimeOutField.stringValue = formatMilliseconds(UserDefaults.standard.integer(forKey: MIDIController.sysExReadTimeOutPreferenceKey))
    }

    private func synchronizeIntervalBetweenSentMessagesField() {
        sysExIntervalBetweenSentMessagesField.stringValue = formatMilliseconds(UserDefaults.standard.integer(forKey: MIDIController.sysExIntervalBetweenSentMessagesPreferenceKey))
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
    static let sysExSendPreferenceChanged = Notification.Name("SSESysExSendPreferenceChangedNotification")
    static let sysExReceivePreferenceChanged = Notification.Name("SSESysExReceivePreferenceChangedNotification")
    static let listenForProgramChangesPreferenceChanged = Notification.Name("SSEListenForProgramChangesPreferenceChangedNotification")

}

// TODO Duplicate stuff while migrating from ObjC to Swift
@objc extension NSNotification {

    static let displayPreferenceChanged = Notification.Name.displayPreferenceChanged
    static let sysExSendPreferenceChanged = Notification.Name.sysExSendPreferenceChanged
    static let sysExReceivePreferenceChanged = Notification.Name.sysExReceivePreferenceChanged
    static let listenForProgramChangesPreferenceChanged = Notification.Name.listenForProgramChangesPreferenceChanged

}
