/*
 Copyright (c) 2021-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Foundation

// Box a Swift struct (or class) in an NSObject, e.g. if you are passing it to AppKit or other APIs that expect NSObjects.

class Box<T>: NSObject {

    let unbox: T

    init(_ value: T) {
        self.unbox = value
        super.init()
    }

}
