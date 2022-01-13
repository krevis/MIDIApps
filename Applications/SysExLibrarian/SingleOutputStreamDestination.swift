/*
 Copyright (c) 2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

class SingleOutputStreamDestination: NSObject, OutputStreamDestination {

    init(name: String?) {
        self.name = name
        super.init()
    }

    var name: String?

    var outputStreamDestinationName: String? {
        name
    }

}
