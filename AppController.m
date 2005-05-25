#import "AppController.h"

@implementation AppController

- init {

	if (self = [super init]) {
		algorithmTags = [[NSArray arrayWithObjects:@"-md5", @"-md4", @"-md2", @"-sha1", @"-sha", @"-mdc2", @"-ripemd160", nil] retain];
	}

	filename = nil;

	//test
	
	
	return self;
}

- (void)awakeFromNib {

	NSArray *dragTypes = [NSArray arrayWithObjects:NSFilenamesPboardType, nil];

	NSLog(@"awakeFromNib");

	chosenAlgorithm = [[popup selectedItem] tag];
	
	[window registerForDraggedTypes:dragTypes];

	
}


- (IBAction)chooseAlgorithm:(id)sender
{

	[checksumField setStringValue:@""];
	chosenAlgorithm = [[sender selectedItem] tag];

	[self processFile];
	[self updateUI];

//	NSLog(@"openssl dgst %@", [algorithmTags objectAtIndex:chosenAlgorithm]);

}

- (IBAction)openFile:(id)sender {
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	if ([panel runModalForDirectory:nil file:nil types:nil] != NSOKButton) {
		return;
	}

	filename = [[panel filenames] objectAtIndex:0];

	[self processFile];
	[self updateUI];

}

- (IBAction)showHelp:(id)sender {

	NSLog(@"show help");

}

- (void)processFile {

    NSTask *task = [[NSTask alloc] init];
    NSData *data;
	NSMutableString *output = [[NSMutableString alloc] init];
	NSRange firstSpace;


	if (filename == nil) {
		return;
	}

	
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


	while ((data = [[[task standardOutput] fileHandleForReading] availableData]) && [data length])
	{
		[output appendString: [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease]];
	}

	// Make sure the task has actually stopped!
    [task terminate];

	firstSpace = [output rangeOfString:@"= "];

	[checksumField setStringValue:[output substringFromIndex:firstSpace.location + 2]];

	[output release];

	

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

	BOOL isDirectory;
	
	NSString *dragFilename = [self getFileForDrag:sender];

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

}


@end
