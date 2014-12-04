//
//  CommentTableCell.h
//  newsyc
//
//  Created by Grant Paul on 3/5/11.
//  Copyright 2011 Xuzz Productions, LLC. All rights reserved.
//

#import "TableViewCell.h"
#import "EntryActionsView.h"
#import "BodyTextView.h"

@protocol CommentTableCellDelegate;

@class HNEntry;
@interface CommentTableCell : TableViewCell <BodyTextViewDelegate> {
    HNEntry *comment;
    NSInteger indentationLevel;

    BOOL userHighlighted;
    BodyTextView *bodyTextView;
    
    __weak id<CommentTableCellDelegate> delegate;
    
    BOOL expanded;
    EntryActionsView *toolbarView;

    UITapGestureRecognizer *tapRecognizer;
    UITapGestureRecognizer *doubleTapRecognizer;
}

@property (nonatomic, assign) id<CommentTableCellDelegate> delegate;
@property (nonatomic, retain) HNEntry *comment;
@property (nonatomic, assign) NSInteger indentationLevel;
@property (nonatomic, assign) BOOL expanded;

+ (CGFloat)heightForEntry:(HNEntry *)entry withWidth:(CGFloat)width expanded:(BOOL)expanded indentationLevel:(NSInteger)indentationLevel;

- (id)initWithReuseIdentifier:(NSString *)identifier;

@end

@protocol CommentTableCellDelegate <EntryActionsViewDelegate>
@optional

- (void)commentTableCellTapped:(CommentTableCell *)cell;
- (void)commentTableCellTappedUser:(CommentTableCell *)cell;
- (void)commentTableCellDoubleTapped:(CommentTableCell *)cell;
- (void)commentTableCell:(CommentTableCell *)cell selectedURL:(NSURL *)url;

@end

