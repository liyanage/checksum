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
	IBOutlet NSButton *refreshButton;
	NSMutableArray *algorithmTags;
	NSString *filename;
	int chosenAlgorithm;
	NSString *compareChecksum;
	int runningAnimationCount;
	NSTask *task;
}

@property (retain) NSString *compareChecksum;

- (IBAction)chooseAlgorithm:(id)sender;
- (IBAction)calculateChecksum:(id)sender;
- (IBAction)pathClicked:(NSPathControl *)sender;
- (IBAction)toggleCompareView:(NSButton *)sender;
//- (IBAction)selectChecksumField:(id)sender;

- (void)processFile;
- (void)processFileBackground;
- (void)handleProcessFileResult:(NSString *)result;
- (void)updateUI;
- (void)updateCompareExpanded;
- (void)checkCompareChecksum;
- (BOOL)dragIsFile:(id <NSDraggingInfo>)sender;
- (NSString *)getFileForDrag:(id <NSDraggingInfo>)sender;
- (void)setUiEnabled:(BOOL)state;
- (void)taskDidTerminate:(NSNotification *)notification;
- (void)cancelTask:(id)sender;
- (void)setupAlgorithmsPopup;
- (NSString *)opensslPath;

@end
