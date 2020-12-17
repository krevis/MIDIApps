/*
 Copyright (c) 2002-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Snoize nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class SNDisclosableView: NSView {

    //
    // API
    //

    // TODO Remove @objc when possible

    @objc var shown = true {
        willSet {
            if newValue != shown {
                if newValue {
                    show()
                }
                else {
                    hide()
                }
            }
        }
    }

    @objc var hiddenHeight: CGFloat = 0

    @IBAction func toggleDisclosure(_ sender: AnyObject?) {
        shown = !shown
    }

    //
    // Internal
    //

    private var originalHeight: CGFloat = 0
    private var hiddenSubviews: [NSView] = []
    private weak var originalNextKeyView: NSView? = nil
    private weak var lastChildKeyView: NSView? = nil
    private var sizeBeforeHidden: CGSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        originalHeight = frame.height
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        originalHeight = frame.height
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        if autoresizingMask.contains(.height) {
            NSLog("Warning: SNDisclosableView: You probably don't want this view to be resizeable vertically. I suggest turning that off in the inspector in IB.")
        }
    }

    override var acceptsFirstResponder: Bool {
        return false
    }

    private func hide() {
        var keyLoopView = nextKeyView
        if keyLoopView != nil && keyLoopView!.isDescendant(of: self) {
            // We need to remove our subviews (which will be hidden) from the key loop.

            // Remember our nextKeyView so we can restore it later.
            originalNextKeyView = keyLoopView

            // Find the last view in the key loop which is one of our descendants.
            repeat {
                lastChildKeyView = keyLoopView
                keyLoopView = keyLoopView!.nextKeyView
            }
            while keyLoopView != nil && keyLoopView!.isDescendant(of: self)

            // Set our nextKeyView to its nextKeyView, and set its nextKeyView to nil.
            // (If we don't do the last step, when we restore the key loop later, it will be missing views in the backwards direction.)
            nextKeyView = keyLoopView
            lastChildKeyView?.nextKeyView = nil
        }
        else {
            originalNextKeyView = nil
        }

        // Remember our current size.
        // When showing, we will use this to resize the subviews properly.
        // (The window width may change while the subviews are hidden.)
        sizeBeforeHidden = frame.size

        // Now shrink the window, causing this view to shrink and our subviews to be obscured.
        // Also remove the subviews from the view hierarchy.
        changeWindowHeight(by: -(originalHeight - hiddenHeight))
        removeSubviews()

        needsDisplay = true
    }

    private func show() {
        // Expand the window, causing this view to expand, and put our hidden subviews back into the view hierarchy.

        // First put the subviews back.
        restoreSubviews()

        // Temporarily set our frame back to its original height.
        // Then tell our subviews to resize themselves, according to their normal autoresize masks.
        // (This may cause their widths to change, if the window was resized horizontally while the subviews were out of the view hierarchy.)
        // Then set our frame size back so we are hidden again.
        let hiddenSize = frame.size
        setFrameSize(CGSize(width: hiddenSize.width, height: originalHeight))
        resizeSubviews(withOldSize: sizeBeforeHidden)
        setFrameSize(hiddenSize)

        // Finally resize the window, causing our height to increase.
        changeWindowHeight(by: originalHeight - hiddenHeight)

        if originalNextKeyView != nil {
            // Restore the key loop to its old configuration.
            lastChildKeyView?.nextKeyView = nextKeyView
            nextKeyView = originalNextKeyView
        }

        needsDisplay = true
    }

    private func removeSubviews() {
        hiddenSubviews = subviews
        for subview in hiddenSubviews {
            subview.removeFromSuperview()
        }
    }

    private func restoreSubviews() {
        for subview in hiddenSubviews {
            addSubview(subview)
        }
        hiddenSubviews = []
    }

    private func changeWindowHeight(by amount: CGFloat) {
        // This turns out to be more complicated than one might expect, because the way that the other views in the window should move is different than the normal case that the AppKit handles.
        //
        // We want the other views in the window to stay the same size. If a view is above us, we want it to stay in the same position relative to the top of the window; likewise, if a view is below us, we want it to stay in the same position relative to the bottom of the window.
        // Also, we want this view to resize vertically, with its top and bottom attached to the top and bottom of its parent.
        // And: this view's subviews should not resize vertically, and should stay attached to the top of this view.
        //
        // However, all of these views may have their autoresize masks configured differently than we want. So:
        //
        // * For each of the window's content view's immediate subviews, including this view,
        //   - Save the current autoresize mask
        //   - And set the autoresize mask how we want
        // * Do the same for the view's subviews.
        // * Then resize the window, and fix up the window's min/max sizes.
        // * For each view that we touched earlier, restore the old autoresize mask.

        guard let window = window else { return }

        // Compute the window's new frame.
        var newWindowFrame = window.frame
        newWindowFrame.origin.y -= amount
        newWindowFrame.size.height += amount

        // If we're growing a visible window, will AppKit constrain it?  It might not fit on the screen.
        if window.isVisible && amount > 0 {
            let constrainedNewWindowFrame = window.constrainFrameRect(newWindowFrame, to: window.screen)
            if constrainedNewWindowFrame.size.height < newWindowFrame.size.height {
                // We can't actually make the window that size. Something will have to give.
                // Shrink to a height such that, when we grow later on, the window will fit.
                let shrunkenHeight = constrainedNewWindowFrame.size.height - amount
                var immediateNewFrame = window.frame
                immediateNewFrame.origin.y += (immediateNewFrame.size.height - shrunkenHeight)
                immediateNewFrame.size.height = shrunkenHeight
                window.setFrame(immediateNewFrame, display: true, animate: true)

                // Have to recompute based on the new frame...
                newWindowFrame = window.frame
                newWindowFrame.origin.y -= amount
                newWindowFrame.size.height += amount
            }
        }

        // Now that we're in a configuration where we can change the window's size how we want, start with our current frame.

        // Adjust the autoresize masks of the window's subviews, remembering the original masks.
        let windowSubviews = window.contentView?.subviews ?? []
        let windowSubviewsAndMasks = windowSubviews.map { ($0, $0.autoresizingMask) }
        for (windowSubview, originalMask) in windowSubviewsAndMasks {
            var mask = originalMask

            if windowSubview == self {
                // This is us.  Make us stick to the top and bottom of the window, and resize vertically.
                mask.insert(.height)
                mask.remove(.maxYMargin)
                mask.remove(.minYMargin)
            } else if windowSubview.frame.maxY < frame.maxY {
                // This subview is below us. Make it stick to the bottom of the window.
                // It should not change height.
                mask.remove(.height)
                mask.insert(.maxYMargin)
                mask.remove(.minYMargin)
            } else {
                // This subview is above us. Make it stick to the top of the window.
                // It should not change height.
                mask.remove(.height)
                mask.remove(.maxYMargin)
                mask.insert(.minYMargin)
            }

            windowSubview.autoresizingMask = mask
        }

        // Adjust the autoresize masks of our subviews, remembering the original masks.
        let ourSubviewsAndMasks = subviews.map { ($0, $0.autoresizingMask) }
        for (ourSubview, originalMask) in ourSubviewsAndMasks {
            var mask = originalMask

            // Don't change height, and stick to the top of the view.
            mask.remove(.height)
            mask.remove(.maxYMargin)
            mask.insert(.minYMargin)

            ourSubview.autoresizingMask = mask
        }

        // Finally we can resize the window.
        if window.isVisible {
            let didPreserve = window.preservesContentDuringLiveResize
            window.preservesContentDuringLiveResize = false
            window.setFrame(newWindowFrame, display: true, animate: true)
            window.preservesContentDuringLiveResize = didPreserve
        } else {
            window.setFrame(newWindowFrame, display: false, animate: false)
        }

        // Adjust the window's min and max sizes to make sense.
        var newWindowMinSize = window.minSize
        newWindowMinSize.height += amount
        window.minSize = newWindowMinSize

        var newWindowMaxSize = window.maxSize
        // If there is no max size set (height of 0), don't change it.
        if newWindowMaxSize.height > 0 {
            newWindowMaxSize.height += amount
            window.maxSize = newWindowMaxSize
        }

        // Restore the saved autoresize masks.
        for (view, mask) in windowSubviewsAndMasks {
            view.autoresizingMask = mask
        }
        for (view, mask) in ourSubviewsAndMasks {
            view.autoresizingMask = mask
        }
    }

}
