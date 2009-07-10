#import "AppController.h"

@implementation AppController

@synthesize compareChecksum;


#pragma mark NSNibAwaking protocol

- (void)awakeFromNib {
	algorithmTags = [[NSArray arrayWithObjects:@"-sha1", @"-md5", @"-md4", @"-md2", @"-mdc2", @"-ripemd160", nil] retain];
	NSArray *dragTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
	chosenAlgorithm = [[popup selectedItem] tag];
	[window registerForDraggedTypes:dragTypes];
	pathControl.URL = [NSURL fileURLWithPath:[@"~/Desktop/" stringByExpandingTildeInPath]];
	[self updateCompareExpanded];
}


#pragma mark lifecycle

- (void)dealloc {
	[algorithmTags release];
	[compareChecksum release];
	[super dealloc];
}


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
	NSLog(@"path clicked: %@, %@", cell.URL, sender.URL);

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
	filename = [[thePanel filenames] objectAtIndex:0];
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

- (IBAction)chooseAlgorithm:(id)sender {
	[checksumField setStringValue:@""];
	chosenAlgorithm = [[sender selectedItem] tag];
	if (!filename) return;
	[self processFile];
	[self updateUI];
}


- (IBAction)toggleCompareView:(NSButton *)sender {
	[self updateCompareExpanded];
}




#pragma mark hash calculation implementation

//  UI update on main thread
- (void)processFile {
	if (filename == nil) return;
	[pathControl setEnabled:NO];
	[popup setEnabled:NO];
	[indicator startAnimation:self];
	[checksumField setStringValue:@"calculating..."];
	[self performSelectorInBackground:@selector(processFileBackground) withObject:nil];
}


//  calculation on background thread
- (void)processFileBackground {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSTask *task = [[[NSTask alloc] init] autorelease];
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
    [task launch];

    NSData *data;
	NSMutableString *output = [[[NSMutableString alloc] init] autorelease];
	while ((data = [[[task standardOutput] fileHandleForReading] availableData]) && [data length]) {
		[output appendString: [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]];
	}

    [task terminate];

	NSRange firstSpace = [output rangeOfString:@"= "];
	NSString *result = output;
	if (firstSpace.location && firstSpace.length) {
		result = [output substringFromIndex:firstSpace.location + 2];
	}
	
	[self performSelectorOnMainThread:@selector(handleProcessFileResult:) withObject:result waitUntilDone:YES];
	[pool release];
}


//  UI update on main thread again
- (void)handleProcessFileResult:(NSString *)result {
	result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[checksumField setStringValue:result];
	[indicator stopAnimation:self];
	[self updateUI];
	[popup setEnabled:YES];
	[pathControl setEnabled:YES];
}


#pragma mark drag and drop handling

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender {	
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
	filename = [self getFileForDrag:sender];
	[[window contentView] setNeedsDisplay:YES];
	[self processFile];
	[self updateUI];
	return YES;
}


- (NSDragOperation)pathControl:(NSPathControl *)pathControl validateDrop:(id <NSDraggingInfo>)info {
	if (![self dragIsFile:info]) {
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
	if (filename != nil) {
		pathControl.URL = [NSURL fileURLWithPath:filename];
	}
	[self updateCompareExpanded];
	[self checkCompareChecksum];
}


- (void)updateCompareExpanded {

	BOOL buttonIsDisclosed = [expandButton intValue];
	BOOL isExpanded = ![compareView isHidden];
	if (buttonIsDisclosed == isExpanded) return;

	int delta = buttonIsDisclosed ? 30 : -30;

	NSRect frame = window.frame;
	frame.size.height += delta;
	frame.origin.y -= delta;

	[[NSAnimationContext currentContext] setDuration:0.2];
	[[window animator] setFrame:frame display:YES];
	
	NSSize size = window.maxSize;
	size.height += delta;
	window.maxSize = size;

	size = window.minSize;
	size.height += delta;
	window.minSize = size;
	
	[compareView setHidden:!buttonIsDisclosed];

}


- (void)checkCompareChecksum {
	NSString *trimmed = [compareChecksum stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	// trimmed can be nil
	if (![trimmed length]) {
		[compareField setBackgroundColor:[NSColor whiteColor]];
		return;
	}

	NSColor *bgcolor = [trimmed isEqualToString:[checksumField stringValue]] ? [NSColor greenColor] : [NSColor redColor];
	[compareField setBackgroundColor:bgcolor];
}

@end
