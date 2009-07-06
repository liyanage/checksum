/* AppController */

#import <Cocoa/Cocoa.h>

@interface AppController : NSObject {
    IBOutlet NSTextField *checksumField, *compareField;
    IBOutlet NSPopUpButton *popup;
    IBOutlet NSWindow *window;
	IBOutlet NSProgressIndicator *indicator;
	IBOutlet NSPathControl *pathControl;
	IBOutlet NSView *compareView;
	IBOutlet NSButton *expandButton;
	NSArray *algorithmTags;
	NSString *filename;
	int chosenAlgorithm;
	NSString *compareChecksum;
}

@property (retain) NSString *compareChecksum;

- (void)processFile;
- (void)processFileBackground;
- (void)handleProcessFileResult:(NSString *)result;
- (void)updateUI;
- (void)updateCompareExpanded;
- (void)checkCompareChecksum;
- (IBAction)chooseAlgorithm:(id)sender;
- (IBAction)pathClicked:(NSPathControl *)sender;
- (IBAction)toggleCompareView:(NSButton *)sender;
- (BOOL)dragIsFile:(id <NSDraggingInfo>)sender;
- (NSString *)getFileForDrag:(id <NSDraggingInfo>)sender;
@end
