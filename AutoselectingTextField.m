//
//  AutoselectingTextField.m
//  Checksum
//
//  Created by Marc Liyanage on 17.07.09.
//  Copyright 2009 Marc Liyanage <http://www.entropy.ch>. All rights reserved.
//

#import "AutoselectingTextField.h"


@implementation AutoselectingTextField

- (BOOL)becomeFirstResponder {
	BOOL state = [super becomeFirstResponder];
	[self performSelector:@selector(selectText:) withObject:self afterDelay:0.0];
	return state;
}



@end
