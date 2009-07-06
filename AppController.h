/* AppController */

#import <Cocoa/Cocoa.h>

@interface AppController : NSObject {
    IBOutlet NSTextField *checksumField;
    IBOutlet NSTextField *filenameField;
    IBOutlet NSPopUpButton *popup;
    IBOutlet NSWindow *window;
	IBOutlet NSProgressIndicator *indicator;
	IBOutlet NSPathControl *pathControl;
	NSArray *algorithmTags;
	NSString *filename;
	int chosenAlgorithm;
}


- (void)processFile;
- (void)processFileBackground;
- (void)handleProcessFileResult:(NSString *)result;
- (void)updateUI;
- (IBAction)chooseAlgorithm:(id)sender;
- (IBAction)pathClicked:(NSPathControl *)sender;
- (BOOL)dragIsFile:(id <NSDraggingInfo>)sender;
- (NSString *)getFileForDrag:(id <NSDraggingInfo>)sender;
@end
