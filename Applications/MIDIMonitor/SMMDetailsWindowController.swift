/*
 Copyright (c) 2001-2020, Kurt Revis.  All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Cocoa

class SMMDetailsWindowController: SMMWindowController, NSWindowDelegate {

    // TODO Get rid of the @objc's here

    @objc let message: SMMessage

    @objc init(message myMessage: SMMessage) {
        message = myMessage
        super.init(window: nil)
        shouldCascadeWindows = true

        NotificationCenter.default.addObserver(self, selector: #selector(self.displayPreferencesDidChange(_:)), name: .SMMDisplayPreferenceChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .SMMDisplayPreferenceChanged, object: nil)
    }

    //
    // To be overridden by subclasses
    //

    override var windowNibName: NSNib.Name? {
        return "Details"
    }

    var dataForDisplay: Data {
        return message.otherData() ?? Data()  // TODO otherData should be a property
    }

    //
    // Private
    //

    @IBOutlet var timeField: NSTextField!
    @IBOutlet var sizeField: NSTextField!
    @IBOutlet var textView: NSTextView!

    override func windowDidLoad() {
        super.windowDidLoad()

        synchronizeDescriptionFields()

        textView.string = formatData(dataForDisplay)
    }

    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        return displayName.appending(" Details")    // TODO Should be localized
    }

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        if let midiDocument = document as? SMMDocument {
            midiDocument.encodeRestorableState(state, for: self)
        }
    }

    @objc func displayPreferencesDidChange(_ notification: NSNotification) {
        synchronizeDescriptionFields()
    }

    func synchronizeDescriptionFields() {
        let formattedLength = SMMessage.formatLength(UInt(dataForDisplay.count))!
        let sizeString = "\(formattedLength) bytes"
            // TODO Localize like NSLocalizedStringFromTableInBundle(@"%@ bytes", @"MIDIMonitor", SMBundleForObject(self), "Details size format string"),

        sizeField.stringValue = sizeString
        timeField.stringValue = message.timeStampForDisplay() ?? "" // TODO should be a non-nil property
    }

    func formatData(_ data: Data) -> String {
        // TODO Implement
        return "TODO";

        /*
         NSUInteger dataLength = data.length;
         if (dataLength == 0) {
             return @"";
         }

         const unsigned char *bytes = data.bytes;

         // Figure out how many bytes dataLength takes to represent
         int lengthDigitCount = 0;
         NSUInteger scratchLength = dataLength;
         while (scratchLength > 0) {
             lengthDigitCount += 2;
             scratchLength >>= 8;
         }

         NSMutableString *formattedString = [NSMutableString string];
         for (NSUInteger dataIndex = 0; dataIndex < dataLength; dataIndex += 16) {
             // This C stuff may be a little ugly but it is a hell of a lot faster than doing it with NSStrings...

             static const char hexchars[] = "0123456789ABCDEF";
             char lineBuffer[100];
             char *p = lineBuffer;

             p += sprintf(p, "%.*lX", lengthDigitCount, (unsigned long)dataIndex);

             for (NSUInteger index = dataIndex; index < dataIndex+16; index++) {
                 *p++ = ' ';
                 if (index % 8 == 0) {
                     *p++ = ' ';
                 }

                 if (index < dataLength) {
                     unsigned char byte = bytes[index];
                     *p++ = hexchars[(byte & 0xF0) >> 4];
                     *p++ = hexchars[byte & 0x0F];
                 } else {
                     *p++ = ' ';
                     *p++ = ' ';
                 }
             }

             *p++ = ' ';
             *p++ = ' ';
             *p++ = '|';

             for (NSUInteger index = dataIndex; index < dataIndex+16 && index < dataLength; index++) {
                 unsigned char byte = bytes[index];
                 *p++ = (isprint(byte) ? byte : ' ');
             }

             *p++ = '|';
             *p++ = '\n';
             *p++ = 0;

             NSString *lineString = [[NSString alloc] initWithCString:lineBuffer encoding:NSASCIIStringEncoding];
             [formattedString appendString:lineString];
             [lineString release];
         }

         return formattedString;

         */
    }

}
