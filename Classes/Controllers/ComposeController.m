//
//  ComposeController.m
//  newsyc
//
//  Created by Grant Paul on 3/30/11.
//  Copyright 2011 Xuzz Productions, LLC. All rights reserved.
//

#import "ComposeController.h"
#import "UIActionSheet+Context.h"
#import <HNKit/HNKit.h>
#import "PlaceholderTextView.h"

@implementation ComposeController
@synthesize delegate;

- (id)initWithSession:(HNSession *)session_ {
    if ((self = [super init])) {
        session = [session_ retain];

        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            [self setModalPresentationStyle:UIModalPresentationPageSheet];
        }
    }
    
    return self;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (BOOL)hasText {
    return [[textView text] length] > 0;
}

- (void)_cancel {
    [self close];
    
    if ([delegate respondsToSelector:@selector(composeControllerDidCancel:)])
        [delegate composeControllerDidCancel:self];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if ([[sheet sheetContext] isEqual:@"cancel"]) {
        if (index == [sheet cancelButtonIndex]) return;
        
        [self _cancel];
    }
}

- (void)cancel {
    if (![self hasText]) {
        [self _cancel];
    } else {
        UIActionSheet *sheet = [[UIActionSheet alloc] init];
        [sheet addButtonWithTitle:@"Discard"];
        [sheet addButtonWithTitle:@"Cancel"];
        [sheet setDestructiveButtonIndex:0];
        [sheet setCancelButtonIndex:1];
        [sheet setSheetContext:@"cancel"];
        [sheet setDelegate:self];
        [sheet showFromBarButtonItemInWindow:cancelItem animated:YES];
        [sheet release];
    }
}

- (void)_sendFinished {
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
}

- (void)sendComplete {
    [self _sendFinished];
    
    [self close];
    
    if ([delegate respondsToSelector:@selector(composeControllerDidSubmit:)])
        [delegate composeControllerDidSubmit:self];
}

- (void)sendFailed {
    [self _sendFinished];
    
    [[self navigationItem] setRightBarButtonItem:completeItem];
    
    UIAlertView *alert = [[UIAlertView alloc] init];
    [alert setTitle:@"Error Posting"];
    [alert setMessage:@"Unable to post. Ensure you have a data connection and can perform this post."];
    [alert addButtonWithTitle:@"Continue"];
    [alert show];
    [alert release];
}

- (void)performSubmission {
    // Overridden in subclasses.
}

- (void)send {
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [[self navigationItem] setRightBarButtonItem:loadingItem];
    
    [self performSubmission];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [entryCells count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [entryCells objectAtIndex:[indexPath row]];
}

- (UITableViewCell *)generateTextFieldCell {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    CGRect cellFrame = [cell frame];
    cellFrame.size.width = 320.0f;
    [cell setFrame:cellFrame];
    [[cell textLabel] setTextColor:[UIColor darkGrayColor]];
    [[cell textLabel] setFont:[UIFont systemFontOfSize:16.0f]];
    return [cell autorelease];
}

- (UITextField *)generateTextFieldForCell:(UITableViewCell *)cell {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 11, 295, 30)];
    [field setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [field setAdjustsFontSizeToFitWidth:YES];
    [field setTextColor:[UIColor blackColor]];
    [field setDelegate:self];
    [field setBackgroundColor:[UIColor whiteColor]];
    [field setAutocorrectionType:UITextAutocorrectionTypeNo];
    [field setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [field setTextAlignment:NSTextAlignmentLeft];
    [field setEnabled:YES];
    
    CGSize label = [[[cell textLabel] text] sizeWithFont:[[cell textLabel] font]];
    CGRect frame = [field frame];
    frame.origin.x = 10.0f + label.width + 10.0f;
    frame.size.width -= label.width + 10.0f;
    [field setFrame:frame];
    
    return [field autorelease];
}

- (UITableViewCell *)entryInputCellWithTitle:(NSString *)title {
    UITableViewCell *cell = [self generateTextFieldCell];
    [[cell textLabel] setText:title];
    UITextField *field = [self generateTextFieldForCell:cell];
    [cell addSubview:field];
    return cell;
}

- (BOOL)includeMultilineEditor {
    return YES;
}

- (NSString *)multilinePlaceholder {
    return nil;
}

- (NSArray *)inputEntryCells {
    return [NSArray array];
}

- (void)textDidChange:(NSNotification *)notification {
    [completeItem setEnabled:[self ableToSubmit]];
}

- (void)textViewDidChange:(UITextView *)textView_ {
    [completeItem setEnabled:[self ableToSubmit]];
}

- (BOOL)ableToSubmit {
    return NO;
}

- (void)loadView {
    [super loadView];
    
    // Match background color in case the keyboard animation is
    // slightly off, and you would otherwise see an ugly black
    // background behind the keyboard.
    [[self view] setBackgroundColor:[UIColor whiteColor]];
    
    entryCells = [[self inputEntryCells] retain];
    
    textView = [[PlaceholderTextView alloc] initWithFrame:[[self view] bounds]];
    [textView setDelegate:self];
    [textView setAlwaysBounceVertical:YES];
    [textView setFont:[UIFont systemFontOfSize:16.0f]];
    [textView setPlaceholder:[self multilinePlaceholder]];
    [textView setEditable:[self includeMultilineEditor]];
    [textView setScrollEnabled:[self includeMultilineEditor]];
    [textView setAutoresizingMask:UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth];
    [[self view] addSubview:textView];
    
    tableView = [[UITableView alloc] initWithFrame:[[self view] bounds] style:UITableViewStylePlain];
    [tableView setAllowsSelection:NO];
    [tableView setDelegate:self];
    [tableView setScrollEnabled:NO];
    [tableView setDataSource:self];
    [textView addSubview:tableView];

    // Make sure that the text view's height is setup properly.
    // (Reloading is needed to force the cells to be initialized.)
    [tableView reloadData];

    CGSize tableSize = [tableView sizeThatFits:CGSizeMake([[self view] bounds].size.width, CGFLOAT_MAX)];
    [tableView setFrame:CGRectMake(0, -tableSize.height, tableSize.width, tableSize.height)];

    UIEdgeInsets textInset = [textView contentInset];
    textInset.top += tableSize.height;
    [textView setContentInset:textInset];

    if ([textView respondsToSelector:@selector(textContainerInset)]) {
        UITableViewCell *firstCell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if (firstCell != nil) {
            if ([firstCell respondsToSelector:@selector(separatorInset)]) {
                UIEdgeInsets containerInset = [textView textContainerInset];
                containerInset.left += [firstCell separatorInset].left - 4.0;
                [textView setTextContainerInset:containerInset];
            }
        }
    }

    completeItem = [[BarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(send)];
    [completeItem setEnabled:NO];
    cancelItem = [[BarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    loadingItem = [[ActivityIndicatorItem alloc] initWithSize:kActivityIndicatorItemStandardSize];
}

- (NSString *)title {
    return @"Compose";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:[[self view] window]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:[[self view] window]];
    
    [[self navigationItem] setRightBarButtonItem:completeItem];
    [[self navigationItem] setLeftBarButtonItem:cancelItem];
    
    [self setTitle:[self title]];
}

- (void)viewDidUnload {    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:[[self view] window]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:[[self view] window]];

    [super viewDidUnload];
    
    [[self navigationItem] setLeftBarButtonItem:nil];
    [[self navigationItem] setRightBarButtonItem:nil];
    
    [tableView release];
    tableView = nil;
    [textView release];
    textView = nil;
    [loadingItem release];
    loadingItem = nil;
    [cancelItem release];
    cancelItem = nil;
    [completeItem release];
    completeItem = nil;
    [entryCells release];
    entryCells = nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:[[self view] window]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:[[self view] window]];
    
    [tableView release];
    [completeItem release];
    [cancelItem release];
    [textView release];
    [loadingItem release];
    [entryCells release];

    [session release];
    
    [super dealloc];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (!keyboardVisible) return;
    
    NSDictionary *info = [notification userInfo];
    NSValue *boundsValue = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    NSNumber *curve = [info objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    NSNumber *duration = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    CGSize keyboardSize = [boundsValue CGRectValue].size;
    
    CGRect frame = [textView frame];
    if (UIInterfaceOrientationIsPortrait([self interfaceOrientation])) {
        frame.size.height += keyboardSize.height;
    } else {
        frame.size.height += keyboardSize.width;
    }
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationCurve:[curve intValue]];
    [UIView setAnimationDuration:[duration floatValue]];
    [textView setFrame:frame];
    [UIView commitAnimations];
    
    keyboardVisible = NO;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    if (keyboardVisible) return;
    
    NSDictionary *info = [notification userInfo];
    NSValue *boundsValue = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
    NSNumber *curve = [info objectForKey:UIKeyboardAnimationCurveUserInfoKey];
    NSNumber *duration = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    CGSize keyboardSize = [boundsValue CGRectValue].size;
    
    CGRect frame = [textView frame];
    if (UIInterfaceOrientationIsPortrait([self interfaceOrientation])) {
        frame.size.height -= keyboardSize.height;
    } else {
        frame.size.height -= keyboardSize.width;
    }
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationBeginsFromCurrentState:YES];
    [UIView setAnimationCurve:[curve intValue]];
    [UIView setAnimationDuration:[duration floatValue]];
    [textView setFrame:frame];
    [UIView commitAnimations];
    
    keyboardVisible = YES;
}

- (UIResponder *)initialFirstResponder {
    return nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [[self initialFirstResponder] becomeFirstResponder];
}

AUTOROTATION_FOR_PAD_ONLY

@end
