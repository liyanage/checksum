#import "AppController.h"

@implementation AppController

@synthesize compareChecksum;

#define WINDOW_EXPANSION_DELTA_Y 35

#pragma mark NSNibAwaking protocol

- (void)awakeFromNib {
	algorithmTags = [[NSArray arrayWithObjects:@"-sha1", @"-md5", @"-md4", @"-md2", @"-mdc2", @"-ripemd160", nil] retain];
	NSArray *dragTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
	chosenAlgorithm = [[popup selectedItem] tag];
	[window registerForDraggedTypes:dragTypes];
	pathControl.URL = [NSURL fileURLWithPath:[@"~/Desktop/" stringByExpandingTildeInPath]];
//	[self updateCompareExpanded];
	[self updateUI];
}

#pragma mark NSApplicationDelegate protocol

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)aFilename
{
	[self setValue:aFilename forKey:@"filename"];
	[self processFile];
	return YES;
}

#pragma mark lifecycle

- (void)dealloc {
	[algorithmTags release];
	[compareChecksum release];
	[filename release];
	[super dealloc];
}

#pragma mark accessors

- (void)setCompareChecksum:(NSString *)value {
	if (compareChecksum != value) {
		[compareChecksum release];
		compareChecksum = [value copy];
	}
	[self updateUI];
}


#pragma mark open panel handling

- (IBAction)pathClicked:(NSPathControl *)sender {
	NSPathComponentCell *cell = [sender clickedPathComponentCell];

	NSURL *url = cell.URL ? cell.URL : sender.URL;
	if (!url) return;
	NSString *path = [url path];
	NSString *dir = [path stringByDeletingLastPathComponent];
	NSString *file = [path lastPathComponent];

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setTreatsFilePackagesAsDirectories:YES];
	[panel beginSheetForDirectory:dir
							 file:file
							types:nil
				   modalForWindow:window
					modalDelegate:self
				   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
}


- (void)openPanelDidEnd:(NSOpenPanel *)thePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[thePanel close];
	if (returnCode != NSOKButton) return;
	[checksumField setStringValue:@""];
	[self setValue:[[thePanel filenames] objectAtIndex:0] forKey:@"filename"];
	[self processFile];
}


#pragma mark copy menu command
// enable copy: menu command only when a checksum is available
- (BOOL)validateMenuItem:(NSMenuItem *)item {
	if ([item action] != @selector(copy:)) return YES;
	return [[checksumField stringValue] length] > 0;
}


- (IBAction)copy:(id)sender {
	NSPasteboard *pboard = [NSPasteboard generalPasteboard];
	[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pboard setString:[checksumField stringValue] forType:NSStringPboardType];
}


#pragma mark other IBActions

- (IBAction)calculateChecksum:(id)sender {
	[checksumField setStringValue:@""];
	if (!filename) return;
	[self updateUI];
	[self processFile];
}

- (IBAction)chooseAlgorithm:(id)sender {
	chosenAlgorithm = [[sender selectedItem] tag];
	[self calculateChecksum:sender];
}


- (IBAction)toggleCompareView:(NSButton *)sender {
	[expandButton setEnabled:NO];
	[self updateCompareExpanded];
}


- (IBAction)selectChecksumField:(id)sender {
	NSLog(@"selected");
}



#pragma mark hash calculation implementation

- (void)processFile {
	if (!filename) return;
	if (task) return;
	[self setUiEnabled:NO];
	[indicator startAnimation:self];
	[checksumField setStringValue:@"calculating..."];

	[self processFileBackground];
}


- (void)processFileBackground {
    task = [[NSTask alloc] init];
    [task setStandardOutput: [NSPipe pipe]];
    [task setStandardError: [task standardOutput]];
    [task setLaunchPath:@"/usr/bin/env"];
	[task setArguments:
		[NSArray arrayWithObjects:
			@"openssl",
			@"dgst",
			[algorithmTags objectAtIndex:chosenAlgorithm],
			filename,
			nil
		]
	];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDidTerminate:) name:NSTaskDidTerminateNotification object:task];
	[task launch];
}

- (void)taskDidTerminate:(NSNotification *)notification
{
//	NSLog(@"task did terminate: %@, mainthread %d, status %d", notification, [[NSThread currentThread] isMainThread], [task terminationStatus]);
	NSString *result = @"";
	if ([task terminationStatus] == 0) {
		NSData *data = [[[task standardOutput] fileHandleForReading] availableData];
		NSString *output = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
		NSRange firstSpace = [output rangeOfString:@"= "];
		result = output;
		if (firstSpace.location && firstSpace.length) {
			result = [output substringFromIndex:firstSpace.location + 2];
		}
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];
	[task release];
	task = nil;
	[self handleProcessFileResult:result];
}

- (void)handleProcessFileResult:(NSString *)result {
	result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[checksumField setStringValue:result];
	[indicator stopAnimation:self];
	[self setUiEnabled:YES];
	[self updateUI];
	[checksumField selectText:self];
}

- (void)cancelTask:(id)sender
{
	[task terminate];
}



#pragma mark drag and drop handling

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {	

	if (task) {
		return NSDragOperationNone;
	}
	
	NSView *view = [window contentView];

	if (![self dragIsFile:sender]) {
		return NSDragOperationNone;
	}

	[view lockFocus];

	[[NSColor selectedControlColor] set];
	[NSBezierPath setDefaultLineWidth:5];
	[NSBezierPath strokeRect:[view bounds]];

	[view unlockFocus];
	[window flushWindow];
	
	return NSDragOperationGeneric;
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	[self setValue:[self getFileForDrag:sender] forKey:@"filename"];
	[[window contentView] setNeedsDisplay:YES];
	[self processFile];
	[self updateUI];
	return YES;
}


- (NSDragOperation)pathControl:(NSPathControl *)pathControl validateDrop:(id <NSDraggingInfo>)info {
	if (task || ![self dragIsFile:info]) {
		return NSDragOperationNone;
	}
	return NSDragOperationGeneric;
}


- (BOOL)pathControl:(NSPathControl *)pathControl acceptDrop:(id <NSDraggingInfo>)info {
	return [self performDragOperation:info];
}


- (BOOL)dragIsFile:(id <NSDraggingInfo>)sender {
	NSString *dragFilename = [self getFileForDrag:sender];
	BOOL isDirectory;
	[[NSFileManager defaultManager] fileExistsAtPath:dragFilename isDirectory:&isDirectory];
	return !isDirectory;
}


- (NSString *)getFileForDrag:(id <NSDraggingInfo>)sender {
	NSPasteboard *pb = [sender draggingPasteboard];
	NSString *availableType = [pb availableTypeFromArray:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
	NSString *dragFilename;
	NSArray *props;

	props = [pb propertyListForType:availableType];
	dragFilename = [props objectAtIndex:0];

	return dragFilename;
}


- (void)draggingExited:(id <NSDraggingInfo>)sender {
	[[window contentView] setNeedsDisplay:YES];
}


#pragma mark UI updating

- (void)updateUI {
	if (filename) {
		pathControl.URL = [NSURL fileURLWithPath:filename];
		[refreshButton setEnabled:YES];
	} else {
		[refreshButton setEnabled:NO];
	}
	[self updateCompareExpanded];
	[self checkCompareChecksum];
}


- (void)updateCompareExpanded {
	BOOL buttonIsDisclosed = [expandButton intValue];
	BOOL isExpanded = ![compareView isHidden];
	if (buttonIsDisclosed == isExpanded) return;
	if (runningAnimationCount > 0) return;

	int delta = buttonIsDisclosed ? WINDOW_EXPANSION_DELTA_Y : -WINDOW_EXPANSION_DELTA_Y;

	NSSize size = window.maxSize;
	size.height += delta;
	window.maxSize = size;

	size = window.minSize;
	size.height += delta;
	window.minSize = size;

	NSRect frame = window.frame;
	frame.size.height += delta;
	frame.origin.y -= delta;

	NSDictionary *windowEffects = [NSDictionary dictionaryWithObjectsAndKeys:
		window, NSViewAnimationTargetKey,
		[NSValue valueWithRect:frame], NSViewAnimationEndFrameKey,
		nil
	];
	NSViewAnimation *windowAnimation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:windowEffects, nil]];
	[windowAnimation setDuration:0.2];
	[windowAnimation setDelegate:self];

	NSDictionary *viewEffects = [NSDictionary dictionaryWithObjectsAndKeys:
		compareView, NSViewAnimationTargetKey,
		(buttonIsDisclosed ? NSViewAnimationFadeInEffect : NSViewAnimationFadeOutEffect), NSViewAnimationEffectKey,
		nil
	];
	NSViewAnimation *viewAnimation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects:viewEffects, nil]];
	[viewAnimation setDuration:0.2];
	[viewAnimation setDelegate:self];

	NSAnimation *first = windowAnimation, *second = viewAnimation;
	if (!buttonIsDisclosed) {
		// reverse the order when collapsing
		first = viewAnimation;
		second = windowAnimation;
	}
	
	[second startWhenAnimation:first reachesProgress:1.0];
	[first startAnimation];
}



- (void)checkCompareChecksum {
	NSString *trimmed = [compareChecksum stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	// trimmed can be nil
	if (![trimmed length]) {
		[compareField setBackgroundColor:[NSColor whiteColor]];
		return;
	}

	BOOL checksumsMatch = [trimmed isEqualToString:[checksumField stringValue]];
	NSColor *bgcolor = checksumsMatch ? [NSColor greenColor] : [NSColor redColor];
	[compareField setBackgroundColor:[bgcolor highlightWithLevel:0.7]];
}


- (void)setUiEnabled:(BOOL)state {
	[popup setEnabled:state];
	[pathControl setEnabled:state];
	[refreshButton setAction:state ? @selector(calculateChecksum:) : @selector(cancelTask:)];
	[refreshButton setImage:[NSImage imageNamed:state ? @"NSRefreshFreestandingTemplate" : @"NSStopProgressFreestandingTemplate"]];
	[checksumField setEditable:state];
}


# pragma mark NSAnimation delegate methods

- (BOOL)animationShouldStart:(NSAnimation *)animation {
	runningAnimationCount++;
	return YES;
}


- (void)animationDidEnd:(NSAnimation *)animation {
	runningAnimationCount--;
	if (runningAnimationCount == 0) [expandButton setEnabled:YES];
	[animation release];
}

#pragma mark NSText delegate methods

- (void)textDidBeginEditing:(NSNotification *)aNotification {
	NSLog(@"begin edit");
}





@end
