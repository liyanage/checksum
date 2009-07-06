#import "AppController.h"

@implementation AppController


#pragma mark NSNibAwaking protocol

- (void)awakeFromNib {
	algorithmTags = [[NSArray arrayWithObjects:@"-sha1", @"-md5", @"-md4", @"-md2", @"-mdc2", @"-ripemd160", nil] retain];
	NSArray *dragTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];
	chosenAlgorithm = [[popup selectedItem] tag];
	[window registerForDraggedTypes:dragTypes];
	pathControl.URL = [NSURL fileURLWithPath:[@"~/Desktop/" stringByExpandingTildeInPath]];
}


#pragma mark lifecycle

- (void)dealloc {
	[algorithmTags release];
	[super dealloc];
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
	[NSThread detachNewThreadSelector:@selector(processFile) toTarget:self withObject:nil];
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


#pragma mark hash calculation implementation

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
}


@end
