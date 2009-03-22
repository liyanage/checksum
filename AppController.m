#import "AppController.h"

@implementation AppController

- (void)awakeFromNib {
	algorithmTags = [[NSArray arrayWithObjects:@"-md5", @"-md4", @"-md2", @"-sha1", @"-sha", @"-mdc2", @"-ripemd160", nil] retain];
	NSArray *dragTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
	chosenAlgorithm = [[popup selectedItem] tag];
	[window registerForDraggedTypes:dragTypes];
}


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


- (IBAction)chooseAlgorithm:(id)sender {
	if (!filename) return;
	[checksumField setStringValue:@""];
	chosenAlgorithm = [[sender selectedItem] tag];
	[self processFile];
	[self updateUI];
}


- (IBAction)openFile:(id)sender {	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setTreatsFilePackagesAsDirectories:YES];
	[panel beginSheetForDirectory:nil
							 file:nil
							types:nil
				   modalForWindow:window
					modalDelegate:self
				   didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:)
					  contextInfo:nil];
}


- (void)openPanelDidEnd:(NSOpenPanel *)thePanel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo {
	[thePanel close];
	if (returnCode != NSOKButton) return
	
	[filenameField setStringValue:@""];
	[checksumField setStringValue:@""];
	
	filename = [[thePanel filenames] objectAtIndex:0];
	[filenameField setStringValue:filename];
	
	[NSThread detachNewThreadSelector:@selector(processFile) toTarget:self withObject:nil];
}


- (IBAction)showHelp:(id)sender {
	NSLog(@"show help");
}


- (void)processFile {
	[popup setEnabled:NO];
	[openFile setEnabled:NO];
	
	NSAutoreleasePool *threadPool = [[NSAutoreleasePool alloc] init];
	
    NSTask *task = [[NSTask alloc] init];
	
    NSData *data;
	NSMutableString *output = [[NSMutableString alloc] init];
	NSRange firstSpace;
	
	[indicator startAnimation:nil];
	if (filename == nil) return;
	
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

	while ((data = [[[task standardOutput] fileHandleForReading] availableData]) && [data length]) {
		[output appendString: [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]];
	}

	// Make sure the task has actually stopped!
    [task terminate];

	firstSpace = [output rangeOfString:@"= "];
	
	if (firstSpace.location && firstSpace.length) {
		[checksumField setStringValue:[output substringFromIndex:firstSpace.location + 2]];
	} else {
		[checksumField setStringValue:output];
	}

	[output release];
	
	[indicator stopAnimation:nil];
	[self updateUI];
	
	[popup setEnabled:YES];
	[openFile setEnabled:YES];
	
	[threadPool release];
}


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


- (void)updateUI {
	if (filename != nil) {
		[filenameField setStringValue:filename];
	}
	[filenameField setNeedsDisplay:YES];
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


- (void)dealloc {
	[algorithmTags release];
	[super dealloc];
}


@end
