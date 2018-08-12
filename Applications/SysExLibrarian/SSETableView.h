/*
 Copyright (c) 2002-2006, Kurt Revis.  All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 * Neither the name of Kurt Revis, nor Snoize, nor the names of other contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>


@interface SSETableView : NSTableView
{
    struct {
        unsigned int shouldEditNextItemWhenEditingEnds:1;
        unsigned int dataSourceCanDeleteRows:1;
        unsigned int dataSourceCanDrag:1;
        unsigned int drawsDraggingHighlight:1;
    } flags;
    NSDragOperation draggingOperation;
}

+ (NSImage *)tableHeaderSortImage;
+ (NSImage *)tableHeaderReverseSortImage;

- (BOOL)shouldEditNextItemWhenEditingEnds;
- (void)setShouldEditNextItemWhenEditingEnds:(BOOL)value;

- (void)setSortColumn:(NSTableColumn *)column isAscending:(BOOL)isSortAscending;

@end


@protocol SSETableViewDataSource <NSTableViewDataSource>

@optional

- (void)tableView:(SSETableView *)tableView deleteRows:(NSIndexSet *)rows;

- (NSDragOperation)tableView:(SSETableView *)tableView draggingEntered:(id <NSDraggingInfo>)sender;
- (BOOL)tableView:(SSETableView *)tableView performDragOperation:(id <NSDraggingInfo>)sender;

@end


@protocol SSETableViewDelegate <NSTableViewDelegate>

@optional

- (BOOL)tableViewKeyDownReceivedSpace:(SSETableView *)tableView;
    // Return YES if delegate handled the space key. Return NO if you did nothing and want the table view to do it.

@end
