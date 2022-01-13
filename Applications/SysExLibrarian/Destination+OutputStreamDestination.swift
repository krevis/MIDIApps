/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation
import SnoizeMIDI

extension Destination: OutputStreamDestination {

    public var outputStreamDestinationName: String? {
        displayName
    }

}
