/*
 Copyright (c) 2002-2021, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

extension NSPopUpButton {

    func addItem(title: String, representedObject: AnyObject) {
        // We should just do addItem(withTitle: title), but that is documented to have annoying behavior:
        // if there is already an item with the same title in the menu, it will be removed when this one is added.
        // We can either jump through hoops to make a properly configured NSMenuItem and add it to self.menu,
        // or just do this easy workaround.

        addItem(withTitle: "*** Placeholder ***")
        lastItem?.title = title
        lastItem?.representedObject = representedObject
    }

    func addSeparatorItem() {
        menu?.addItem(NSMenuItem.separator())
    }

}
