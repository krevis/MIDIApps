/*
 Copyright (c) 2002-2022, Kurt Revis.  All rights reserved.

 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree.
 */

import Cocoa

class DisclosableView: NSView {

    //
    // API
    //

    var shown = true {
        didSet {
            guard oldValue != shown else { return }
            if shown {
                show()
            }
            else {
                hide()
            }
        }
    }

    var hiddenHeight: CGFloat = 0

    @IBAction func toggleDisclosure(_ sender: Any?) {
        shown = !shown
    }

    //
    // Internal
    //

    private var originalHeight: CGFloat = 0
    private var hiddenSubviews: [NSView] = []
    private weak var originalNextKeyView: NSView?
    private weak var lastChildKeyView: NSView?
    private var sizeBeforeHidden: CGSize = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        originalHeight = frame.height
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        originalHeight = frame.height
        clipsToBounds = true
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        if autoresizingMask.contains(.height) {
            NSLog("Warning: DisclosableView: You probably don't want this view to be resizeable vertically. I suggest turning that off in the inspector in IB.")
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

        let completion = { [self] in
            // After the animation, remove our subviews from the view hierarchy.
            removeSubviews()
            needsDisplay = true
        }

        if let window, window.styleMask.contains(.fullScreen) {
            // We're in full screen, so we can't resize the window. Resize ourself and other content views instead.
            NSAnimationContext.runAnimationGroup { animationContext in
                animationContext.completionHandler = completion
                animationContext.allowsImplicitAnimation = true
                changeSelfHeightAndAdjustOtherContentViews(by: -(originalHeight - hiddenHeight))
            }
        }
        else {
            // Now shrink the window, causing this view to shrink and our subviews to be obscured.
            changeWindowHeight(by: -(originalHeight - hiddenHeight))
            completion()
        }
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

        let completion = { [self] in
            if originalNextKeyView != nil {
                // Restore the key loop to its old configuration.
                lastChildKeyView?.nextKeyView = nextKeyView
                nextKeyView = originalNextKeyView
            }

            needsDisplay = true
        }

        if let window, window.styleMask.contains(.fullScreen) {
            // We're in full screen, so we can't resize the window. Resize ourself and other content views instead.
            NSAnimationContext.runAnimationGroup { animationContext in
                animationContext.completionHandler = completion
                animationContext.allowsImplicitAnimation = true
                changeSelfHeightAndAdjustOtherContentViews(by: (originalHeight - hiddenHeight))
            }
        }
        else {
            // Finally resize the window, causing our height to increase.
            changeWindowHeight(by: originalHeight - hiddenHeight)
            completion()
        }
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

        guard let window else { return }

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
        let windowSubviewsAndMasks = temporarilyAdjustWindowSubviewMasks(window.contentView?.subviews ?? [])

        // Adjust the autoresize masks of our subviews, remembering the original masks.
        let ourSubviewsAndMasks = temporarilyAdjustOurSubviewMasks()

        // Finally we can resize the window.
        if window.isVisible {
            let didPreserve = window.preservesContentDuringLiveResize
            window.preservesContentDuringLiveResize = false
            window.setFrame(newWindowFrame, display: true, animate: true)
            window.preservesContentDuringLiveResize = didPreserve
        }
        else {
            window.setFrame(newWindowFrame, display: false, animate: false)
        }

        changeWindowMinMaxHeightBy(window, amount)

        // Restore the saved autoresize masks.
        restoreViewMasks(windowSubviewsAndMasks)
        restoreViewMasks(ourSubviewsAndMasks)
    }

    func temporarilyAdjustWindowSubviewMasks(_ windowSubviews: [NSView]) -> [(NSView, NSView.AutoresizingMask)] {
        let windowSubviewsAndMasks = windowSubviews.map { ($0, $0.autoresizingMask) }
        for (windowSubview, originalMask) in windowSubviewsAndMasks {
            var mask = originalMask

            if windowSubview == self {
                // This is us.  Make us stick to the top and bottom of the window, and resize vertically.
                mask.insert(.height)
                mask.remove(.maxYMargin)
                mask.remove(.minYMargin)
            }
            else if windowSubview.frame.maxY < frame.maxY {
                // This subview is below us. Make it stick to the bottom of the window.
                // It should not change height.
                mask.remove(.height)
                mask.insert(.maxYMargin)
                mask.remove(.minYMargin)
            }
            else {
                // This subview is above us. Make it stick to the top of the window.
                // It should not change height.
                mask.remove(.height)
                mask.remove(.maxYMargin)
                mask.insert(.minYMargin)
            }

            windowSubview.autoresizingMask = mask
        }

        return windowSubviewsAndMasks
    }

    func temporarilyAdjustOurSubviewMasks() -> [(NSView, NSView.AutoresizingMask)] {
        let ourSubviewsAndMasks = subviews.map { ($0, $0.autoresizingMask) }
        for (ourSubview, originalMask) in ourSubviewsAndMasks {
            var mask = originalMask

            // Don't change height, and stick to the top of the view.
            mask.remove(.height)
            mask.remove(.maxYMargin)
            mask.insert(.minYMargin)

            ourSubview.autoresizingMask = mask
        }

        return ourSubviewsAndMasks
    }

    func restoreViewMasks(_ viewsAndMasks: [(NSView, NSView.AutoresizingMask)]) {
        for (view, mask) in viewsAndMasks {
            view.autoresizingMask = mask
        }
    }

    private func changeWindowMinMaxHeightBy(_ window: NSWindow, _ amount: CGFloat) {
        // Adjust the window's min and max sizes to make sense.
        window.minSize = CGSize(width: window.minSize.width, height: window.minSize.height + amount)
        // If there is no max size set (height of 0), don't change it.
        if window.maxSize.height > 0 {
            window.maxSize = CGSize(width: window.maxSize.width, height: window.maxSize.height + amount)
        }
    }

    private func changeSelfHeightAndAdjustOtherContentViews(by amount: CGFloat) {
        guard let window else { return }

        // Change this view's height by the given amount, and adjust the window's content view's other subviews
        // to make sense. Specifically, the subviews below us. If the subview can resize, change its height;
        // if it can't, change its position.

        for windowSubview in window.contentView?.subviews ?? [] {
            if windowSubview == self {
                // This is us. Resize to be shorter or taller, keeping the same top (maxY).
                var frame = windowSubview.frame
                frame.origin.y -= amount
                frame.size.height += amount
                windowSubview.frame = frame
            }
            else if windowSubview.frame.maxY < self.frame.maxY {
                // This subview is below us
                if windowSubview.autoresizingMask.contains(.height) {
                    // and resizes when the window height changes. Make it taller or shorter, staying fixed to the bottom of the window.
                    var frame = windowSubview.frame
                    frame.size.height -= amount
                    windowSubview.frame = frame
                }
                else {
                    // and doesn't resize when the window height changes. Keep its same top (maxY).
                    var frame = windowSubview.frame
                    frame.origin.y -= amount
                    windowSubview.frame = frame
                }
            }
            else {
                // This subview is above us. Don't change it.
            }
        }

        changeWindowMinMaxHeightBy(window, amount)
    }

}
