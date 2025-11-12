/*
 Copyright (c) 2025, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import UniformTypeIdentifiers

extension UTType {

    static var rawSysEx: UTType { UTType("com.snoize.midi-sysex")! }
    // This must be defined in the app's `Info.plist` in `UTExportedTypeDeclarations`

}
