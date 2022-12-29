/*
 Copyright (c) 2003-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa
import SnoizeMIDI

class SysExSpeedController: NSObject {

    override init() {
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func awakeFromNib() {
        outlineView.autoresizesOutlineColumn = false

        // Workaround to get continuous updates from the sliders in the table view.
        // You can't just set it, or its cell, to be continuous -- that still doesn't
        // give you continuous updates through the normal table view interface.
        // What DOES work is to have the cell message us directly.
        if let column = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "speed")),
           let dataCell = column.dataCell as? NSCell {
            dataCell.target = self
            dataCell.action = #selector(self.takeSpeedFromSelectedCellInTableView)
        }
    }

    func willShow() {
        NotificationCenter.default.addObserver(self, selector: #selector(midiObjectListChanged(_:)), name: .midiObjectListChanged, object: midiContext)

        captureDestinationsAndExternalDevices()

        outlineView.reloadData()

        let customBufferSize = UserDefaults.standard.integer(forKey: MIDIController.customSysexBufferSizePreferenceKey)

        bufferSizePopUpButton.selectItem(withTag: customBufferSize)
        if bufferSizePopUpButton.selectedTag() != customBufferSize {
            bufferSizePopUpButton.selectItem(withTag: 0)
        }
    }

    func willHide() {
        NotificationCenter.default.removeObserver(self, name: .midiObjectListChanged, object: midiContext)

        releaseDestinationsAndExternalDevices()

        outlineView.reloadData()
    }

    // MARK: Actions

    @objc func takeSpeedFromSelectedCellInTableView(_ sender: Any?) {
        // sender is the outline view; get the selected cell to find its new value.
        guard let cell = outlineView.selectedCell() else { return }
        let newValue = cell.integerValue

        // Don't actually set the value while we're tracking -- no need to update CoreMIDI
        // continuously.  Instead, remember which item is getting tracked and what its value
        // is "supposed" to be.  When tracking finishes, the new value comes through
        // -outlineView:setObjectValue:..., and we'll set it for real.
        let row = outlineView.clickedRow
        if let item = outlineView.item(atRow: row) as? MIDIObject {
            trackingMIDIObject = item
            speedOfTrackingMIDIObject = newValue

            // update the slider value based on the effective speed (which may be different than the tracking value)
            let effectiveValue = effectiveSpeedForItem(item)
            if newValue != effectiveValue {
                cell.integerValue = effectiveValue
            }
        }

        // redisplay
        invalidateRowAndParent(row)
    }

    @IBAction func changeBufferSize(_ sender: Any?) {
        let customBufferSize = bufferSizePopUpButton.selectedTag()
        if customBufferSize == 0 {
            UserDefaults.standard.removeObject(forKey: MIDIController.customSysexBufferSizePreferenceKey)
        }
        else {
            UserDefaults.standard.set(customBufferSize, forKey: MIDIController.customSysexBufferSizePreferenceKey)
        }
        NotificationCenter.default.post(name: .customSysexBufferSizePreferenceChanged, object: nil)
    }

    // MARK: Private

    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var bufferSizePopUpButton: NSPopUpButton!

    var destinations: [Destination] = []
    var externalDevices: [ExternalDevice] = []
    var trackingMIDIObject: MIDIObject?
    var speedOfTrackingMIDIObject: Int = 0

    var midiContext: MIDIContext {
        ((NSApp.delegate as? AppController)?.midiContext)!
    }

    func captureDestinationsAndExternalDevices() {
        let center = NotificationCenter.default

        for destination in destinations {
            center.removeObserver(self, name: .midiObjectPropertyChanged, object: destination)
        }
        for externalDevice in externalDevices {
            center.removeObserver(self, name: .midiObjectPropertyChanged, object: externalDevice)
        }

        destinations = CombinationOutputStream.destinationsInContext(midiContext)
        externalDevices = midiContext.externalDevices

        for destination in destinations {
            center.addObserver(self, selector: #selector(self.midiObjectChanged(_:)), name: .midiObjectPropertyChanged, object: destination)
        }
        for externalDevice in externalDevices {
            center.addObserver(self, selector: #selector(self.midiObjectChanged(_:)), name: .midiObjectPropertyChanged, object: externalDevice)
        }
    }

    func releaseDestinationsAndExternalDevices() {
        destinations = []
        externalDevices = []
    }

    @objc func midiObjectListChanged(_ notification: Notification) {
        captureDestinationsAndExternalDevices()

        if let window = outlineView.window, window.isVisible {
            outlineView.reloadData()
        }
    }

    @objc func midiObjectChanged(_ notification: Notification) {
        guard let propertyName = notification.userInfo?[MIDIContext.changedProperty] as? String else { return }
        if propertyName == kMIDIPropertyName as String {
             // invalidate only the row for this object
            let row = outlineView.row(forItem: notification.object)
            outlineView.setNeedsDisplay(outlineView.rect(ofRow: row))
        }
        else if propertyName == kMIDIPropertyMaxSysExSpeed as String {
             // invalidate this row and the parent (if any)
            let row = outlineView.row(forItem: notification.object)
            invalidateRowAndParent(row)
         }
     }

    func effectiveSpeedForItem(_ item: MIDIObject) -> Int {
        var effectiveSpeed = (item == trackingMIDIObject) ? speedOfTrackingMIDIObject : Int(item.maxSysExSpeed)

        if let destination = item as? Destination {
            // Return the minimum of this destination's speed and all of its external devices' speeds
            for extDevice in destination.connectedExternalDevices {
                let extDeviceSpeed = (extDevice == trackingMIDIObject) ? speedOfTrackingMIDIObject : Int(extDevice.maxSysExSpeed)
                effectiveSpeed = min(effectiveSpeed, extDeviceSpeed)
            }
        }

        return effectiveSpeed
    }

    func invalidateRowAndParent(_ row: Int) {
        if row >= 0 {
            outlineView.setNeedsDisplay(outlineView.rect(ofRow: row))

            let level = outlineView.level(forRow: row)
            if level > 0 && row > 0 {
                // walk up rows until we hit one at a higher level -- that will be our parent
                for higherRow in stride(from: row - 1, through: 0, by: -1) {
                    if outlineView.level(forRow: higherRow) < level {
                        outlineView.setNeedsDisplay(outlineView.rect(ofRow: higherRow))
                        return
                    }
                }
            }
        }
    }

}

extension SysExSpeedController: NSOutlineViewDataSource {

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            if index < destinations.count {
                return destinations[index]
            }
        }
        else if let destination = item as? Destination {
            let connectedExternaDevices = destination.connectedExternalDevices
            if index < connectedExternaDevices.count {
                return connectedExternaDevices[index]
            }
        }

        return () // shouldn't happen
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let destination = item as? Destination {
            return destination.connectedExternalDevices.count > 0
        }
        else {
            return false
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return destinations.count
        }
        else if let destination = item as? Destination {
            return destination.connectedExternalDevices.count
        }
        else {
            return 0
        }
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let midiObject = item as? MIDIObject,
              let column = tableColumn else { return nil }

        switch column.identifier.rawValue {
        case "name":
            return midiObject.name
        case "speed", "bytesPerSecond":
            return effectiveSpeedForItem(midiObject)
        case "percent":
            return (Double(effectiveSpeedForItem(midiObject)) / 3125.0) * 100.0
        default:
            return nil
        }
    }

    func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, byItem item: Any?) {
        guard let midiObject = item as? MIDIObject,
              let column = tableColumn,
              let number = object as? NSNumber else { return }

        if column.identifier.rawValue == "speed" {
            let newValue = number.int32Value
            if newValue > 0 && newValue != midiObject.maxSysExSpeed {
                midiObject.maxSysExSpeed = newValue

                // Work around bug where CoreMIDI doesn't pay attention to the new speed
                midiContext.forceCoreMIDIToUseNewSysExSpeed()
            }

            trackingMIDIObject = nil
        }
    }

}
