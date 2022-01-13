/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

class PreferenceKeys: NSObject {

    static let saveSysExWithEOXAlways = "SMMSaveSysExWithEOXAlways"

    static let openWindowsForNewSources = "SMMOpenWindowsForNewSources"  // Obsolete

    static let selectOrdinarySourcesInNewDocument = "SMMAutoSelectOrdinarySources"
    static let selectVirtualDestinationInNewDocument = "SMMAutoSelectVirtualDestination"
    static let selectSpyingDestinationsInNewDocument = "SMMAutoSelectSpyingDestinations"

    static let selectFirstSourceInNewDocument = "SMMAutoSelectFirstSource"  // Obsolete

    static let askBeforeClosingModifiedWindow = "SMMAskBeforeClosingModifiedWindow"

    static let autoConnectNewSources = "SMMAutoConnectNewSources"
}
