#import <oak/oak.h>
#import <OakTextView/OakDocumentView.h>
#import <document/document.h>
#import <document/collection.h>

PUBLIC @interface CommitWindow : NSWindowController <OakTextViewDelegate, NSMenuDelegate>
{
	IBOutlet OakDocumentView* documentView;
	IBOutlet NSButton* commitButton;
	IBOutlet NSButton* cancelButton;
	IBOutlet NSTableView* tableView;
	IBOutlet NSArrayController* arrayController;

	document::document_ptr commitMessage;
}
@property (nonatomic, retain) NSMutableDictionary* options;
@property (nonatomic, retain) NSMutableArray* parameters;
- (IBAction)commit:(id)sender;
- (IBAction)cancelCommit:(id)sender;
- (IBAction)showDiff:(id)sender;
- (IBAction)performActionCommand:(id)sender;
- (IBAction)checkAll:(id)sender;
- (IBAction)uncheckAll:(id)sender;
@end
