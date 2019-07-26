//
//  RogueDriver.m
//  Brogue
//
//  Created by Brian and Kevin Walker on 12/26/08.
//  Copyright 2012. All rights reserved.
//
//  This file is part of Brogue.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as
//  published by the Free Software Foundation, either version 3 of the
//  License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Affero General Public License for more details.
//
//  You should have received a copy of the GNU Affero General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import <SpriteKit/SpriteKit.h>
#include <limits.h>
#include <unistd.h>
#include "CoreFoundation/CoreFoundation.h"
#import "RogueDriver.h"
#import <QuartzCore/QuartzCore.h>
#import <Brogue-Swift.h>

#define BROGUE_VERSION	4	// A special version number that's incremented only when
// something about the OS X high scores file structure changes.

static SKView *theMainView;
short mouseX, mouseY;
static CGColorSpaceRef _colorSpace;
static RogueScene *scene;

@implementation RogueDriver {
    IBOutlet NSMenu *fileMenu;
    IBOutlet SKView *skGameView;
    IBOutlet NSWindow *mainWindow;
}

- (void)awakeFromNib
{
	NSSize theSize;
	short versionNumber;
    
	versionNumber = [[NSUserDefaults standardUserDefaults] integerForKey:@"Brogue version"];
	if (versionNumber == 0 || versionNumber < BROGUE_VERSION) {
		// This is so we know when to purge the relevant preferences and save them anew.
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSWindow Frame Brogue main window"];
        
		if (versionNumber != 0) {
			[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Brogue version"];
		}
		[[NSUserDefaults standardUserDefaults] setInteger:BROGUE_VERSION forKey:@"Brogue version"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}

    [mainWindow setOrderedIndex:0];

    theMainView = skGameView;
    
	[mainWindow setFrameAutosaveName:@"Brogue main window"];
	[mainWindow useOptimizedDrawing:YES];
	[mainWindow setAcceptsMouseMovedEvents:YES];

    // Comment out this line if you're trying to compile on a system earlier than OS X 10.7:
    [mainWindow setCollectionBehavior:NSWindowCollectionBehaviorFullScreenPrimary];
    
	theSize.height = 7 * VERT_PX * kROWS / FONT_SIZE;
	theSize.width = 7 * HORIZ_PX * kCOLS / FONT_SIZE;
	[mainWindow setContentMinSize:theSize];
 
	mouseX = mouseY = 0;
    
    
    if (!skGameView.scene) {
     //   skGameView.showsFPS = YES;
   //     skGameView.showsNodeCount = YES;
        //skView.showsDrawCount = YES;
        //skView.showsQuadCount = YES;
        // Create and configure the scene.
        
        
        // Size doesn't matter, but a larger initial size means the cells will be downscaled (pretty),
        // rather than upscaled (ugly)
        CGFloat backingScaleFactor = mainWindow.screen.backingScaleFactor;
        NSSize screenSize = mainWindow.screen.frame.size;
        NSSize initalSize = NSMakeSize(screenSize.width * backingScaleFactor, screenSize.height * backingScaleFactor); // Total screen size, taking retina display into account
        
        scene = [[RogueScene alloc] initWithSize:initalSize rows:ROWS cols: COLS];
        scene.scaleMode = SKSceneScaleModeFill;
        // Present the scene.
        [skGameView presentScene:scene];
    }
}

- (void)playBrogue
{
    _colorSpace = CGColorSpaceCreateDeviceRGB();
    // this takes over the thread until qutting.
	rogueMain();
    [NSApp terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)__unused aNotification
{
	[mainWindow makeMainWindow];
	[mainWindow makeKeyWindow];
    
	//NSLog(@"\nAspect ratio is %@", [theWindow aspectRatio]);

    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(playBrogue) object:nil];
    [thread setStackSize:500 * 8192];
    [thread start];
}

@end

//  plotChar: plots inputChar at (xLoc, yLoc) with specified background and foreground colors.
//  Color components are given in ints from 0 to 100.

void plotChar(uchar inputChar,
			  short xLoc, short yLoc,
			  short foreRed, short foreGreen, short foreBlue,
			  short backRed, short backGreen, short backBlue) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    CGFloat backComponents[] = {(CGFloat)(backRed/100.), (CGFloat)(backGreen/100.), (CGFloat)(backBlue/100.), 1.};
    CGColorRef backColor = CGColorCreate(_colorSpace, backComponents);
    
    CGFloat foreComponents[] = {(CGFloat)(foreRed/100.), (CGFloat)(foreGreen/100.), (CGFloat)(foreBlue/100.), 1.};
    CGColorRef foreColor = CGColorCreate(_colorSpace, foreComponents);
    
    [scene setCellWithX:xLoc y:yLoc code:inputChar bgColor:backColor fgColor:foreColor];
    
    CGColorRelease(backColor);
    CGColorRelease(foreColor);

	[pool drain];
}

boolean isApplicationActive() {
    return [[NSRunningApplication currentApplication] isActive];
}

void eventLocation(NSEvent *theEvent, short *x, short *y) {
    NSPoint event_location;
    NSPoint local_point;
    
    event_location = [theEvent locationInWindow];
    local_point = [theMainView convertPoint:event_location fromView:nil];
    
    NSRect frameRect = [theMainView.window contentRectForFrameRect:[theMainView.window frame]];
    *x = COLS * local_point.x / frameRect.size.width;
    *y = ROWS - ROWS * local_point.y / frameRect.size.height;
    
    // Correct for the fact that truncation occurs in a positive direction when we're below zero:
    if (local_point.x < 0) {
        (*x)--;
    }
    if (frameRect.size.height < local_point.y) {
        (*y)--;
    }
}

// Return true if the event is a mouse move event within the same cell.
boolean discardEvent(NSEvent *theEvent) {
    short x, y;
    NSEventType theEventType = [theEvent type];
    eventLocation(theEvent, &x, &y);
    return (theEventType == NSEventTypeMouseMoved && x == mouseX && y == mouseY);
}

// Returns true if the player interrupted the wait with a keystroke or mouse action; otherwise false.
boolean pauseForMilliseconds(short milliseconds) {
    if (isApplicationActive()) {
        for (; milliseconds > 0; milliseconds -= 16) {
            if (scene.aEvent) {
                if (discardEvent(scene.aEvent)) {
                    scene.aEvent = nil;
                } else {
                    return YES;
                }
            }
            if (milliseconds >= 16) {
                [NSThread sleepForTimeInterval:0.016];
            } else {
                [NSThread sleepForTimeInterval:((double) milliseconds) / 1000];
            }
        }
    } else {
        [NSThread sleepForTimeInterval:((double) milliseconds) / 1000];
    }
    if (scene.aEvent) {
        return YES;
    }
    return NO;
}

void nextKeyOrMouseEvent(rogueEvent *returnEvent, __unused boolean textInput, boolean colorsDance) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSEvent *theEvent = nil;
	NSEventType theEventType = nil;
	short x, y;
    
    for(;;) {
        theEvent = [scene aEvent];
        // nil the event or it will repeat (e.g. 'x' to explore will be pressed repeatedly).
        scene.aEvent = nil;
        
        theEventType = [theEvent type];
        if (theEventType == NSKeyDown && !([theEvent modifierFlags] & NSCommandKeyMask)) {
            returnEvent->eventType = KEYSTROKE;
            returnEvent->param1 = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
            //printf("\nKey pressed: %i", returnEvent->param1);
            returnEvent->param2 = 0;
            returnEvent->controlKey = ([theEvent modifierFlags] & NSControlKeyMask ? 1 : 0);
            returnEvent->shiftKey = ([theEvent modifierFlags] & NSShiftKeyMask ? 1 : 0);
            break;
        } else if (theEventType == NSEventTypeLeftMouseDown
                   || theEventType == NSEventTypeLeftMouseUp
                   || theEventType == NSEventTypeRightMouseDown
                   || theEventType == NSEventTypeRightMouseUp
                   || theEventType == NSEventTypeMouseMoved
                   || theEventType == NSEventTypeLeftMouseDragged
                   || theEventType == NSEventTypeRightMouseDragged) {
            
            switch (theEventType) {
                    // TODO: these const are depcrecated. Use new names.
                case NSEventTypeLeftMouseDown:
                    returnEvent->eventType = MOUSE_DOWN;
                    break;
                case NSEventTypeLeftMouseUp:
                    returnEvent->eventType = MOUSE_UP;
                    break;
                case NSEventTypeRightMouseDown:
                    returnEvent->eventType = RIGHT_MOUSE_DOWN;
                    break;
                case NSEventTypeRightMouseUp:
                    returnEvent->eventType = RIGHT_MOUSE_UP;
                    break;
                case NSEventTypeMouseMoved:
                case NSEventTypeLeftMouseDragged:
                case NSEventTypeRightMouseDragged:
                    returnEvent->eventType = MOUSE_ENTERED_CELL;
                    break;
                default:
                    break;
            }
            eventLocation(theEvent, &x, &y);
            returnEvent->param1 = x;
            returnEvent->param2 = y;
            returnEvent->controlKey = ([theEvent modifierFlags] & NSControlKeyMask ? 1 : 0);
            returnEvent->shiftKey = ([theEvent modifierFlags] & NSShiftKeyMask ? 1 : 0);
            mouseX = x;
            mouseY = y;
            break;
        } else {
            if (isApplicationActive()) {
                [NSThread sleepForTimeInterval:0.016667];
                if (colorsDance) {
                    shuffleTerrainColors(3, true);
                    commitDraws();
                }
            } else {
                [NSThread sleepForTimeInterval:0.5];
            }
        }
    }
    
    theEvent = nil;

	[pool drain];
}

boolean controlKeyIsDown() {
	return (([[NSApp currentEvent] modifierFlags] & NSControlKeyMask) ? true : false);
}

boolean shiftKeyIsDown() {
	return (([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) ? true : false);
}

void initHighScores() {
	NSMutableArray *scoresArray, *textArray, *datesArray;
	short j, theCount;
    
	if ([[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores scores"] == nil
		|| [[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores text"] == nil
		|| [[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores dates"] == nil) {
        
		scoresArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
		textArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
		datesArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
        
		for (j=0; j<HIGH_SCORES_COUNT; j++) {
			[scoresArray addObject:[NSNumber numberWithLong:0]];
			[textArray addObject:[NSString string]];
			[datesArray addObject:[NSDate date]];
		}
        
		[[NSUserDefaults standardUserDefaults] setObject:scoresArray forKey:@"high scores scores"];
		[[NSUserDefaults standardUserDefaults] setObject:textArray forKey:@"high scores text"];
		[[NSUserDefaults standardUserDefaults] setObject:datesArray forKey:@"high scores dates"];
	}
    
	theCount = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores scores"] count];
    
	if (theCount < HIGH_SCORES_COUNT) { // backwards compatibility
		scoresArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
		textArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
		datesArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
        
		[scoresArray setArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores scores"]];
		[textArray setArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores text"]];
		[datesArray setArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores dates"]];
        
		for (j=theCount; j<HIGH_SCORES_COUNT; j++) {
			[scoresArray addObject:[NSNumber numberWithLong:0]];
			[textArray addObject:[NSString string]];
			[datesArray addObject:[NSDate date]];
		}
        
		[[NSUserDefaults standardUserDefaults] setObject:scoresArray forKey:@"high scores scores"];
		[[NSUserDefaults standardUserDefaults] setObject:textArray forKey:@"high scores text"];
		[[NSUserDefaults standardUserDefaults] setObject:datesArray forKey:@"high scores dates"];
	}
}

// returns the index number of the most recent score
short getHighScoresList(rogueHighScoresEntry returnList[HIGH_SCORES_COUNT]) {
	NSArray *scoresArray, *textArray, *datesArray;
	NSDateFormatter *dateFormatter;
	NSDate *mostRecentDate;
	short i, j, maxIndex, mostRecentIndex;
	long maxScore;
	boolean scoreTaken[HIGH_SCORES_COUNT];
    
	// no scores have been taken
	for (i=0; i<HIGH_SCORES_COUNT; i++) {
		scoreTaken[i] = false;
	}
    
	initHighScores();
    
	scoresArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores scores"];
	textArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores text"];
	datesArray = [[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores dates"];
    
	mostRecentDate = [NSDate distantPast];
	dateFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"%1m/%1d/%y" allowNaturalLanguage:YES];
    
	// store each value in order into returnList
	for (i=0; i<HIGH_SCORES_COUNT; i++) {
		// find the highest value that hasn't already been taken
		maxScore = 0; // excludes scores of zero
		for (j=0; j<HIGH_SCORES_COUNT; j++) {
			if (scoreTaken[j] == false && [[scoresArray objectAtIndex:j] longValue] >= maxScore) {
				maxScore = [[scoresArray objectAtIndex:j] longValue];
				maxIndex = j;
			}
		}
		// maxIndex identifies the highest non-taken score
		scoreTaken[maxIndex] = true;
		returnList[i].score = [[scoresArray objectAtIndex:maxIndex] longValue];
		strcpy(returnList[i].description, [[textArray objectAtIndex:maxIndex] cStringUsingEncoding:NSASCIIStringEncoding]);
		strcpy(returnList[i].date, [[dateFormatter stringFromDate:[datesArray objectAtIndex:maxIndex]] cStringUsingEncoding:NSASCIIStringEncoding]);
        
		// if this is the most recent score we've seen so far
		if ([mostRecentDate compare:[datesArray objectAtIndex:maxIndex]] == NSOrderedAscending) {
			mostRecentDate = [datesArray objectAtIndex:maxIndex];
			mostRecentIndex = i;
		}
	}
	return mostRecentIndex;
}

// saves the high scores entry over the lowest-score entry if it qualifies.
// returns whether the score qualified for the list.
// This function ignores the date passed to it in theEntry and substitutes the current
// date instead.
boolean saveHighScore(rogueHighScoresEntry theEntry) {
	NSMutableArray *scoresArray, *textArray, *datesArray;
	NSNumber *newScore;
	NSString *newText;
    
	short j, minIndex = -1;
	long minScore = theEntry.score;
    
	// generate high scores if prefs don't exist or contain no high scores data
	initHighScores();
    
	scoresArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
	textArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
	datesArray = [NSMutableArray arrayWithCapacity:HIGH_SCORES_COUNT];
    
	[scoresArray setArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores scores"]];
	[textArray setArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores text"]];
	[datesArray setArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"high scores dates"]];
    
	// find the lowest value
	for (j=0; j<HIGH_SCORES_COUNT; j++) {
		if ([[scoresArray objectAtIndex:j] longValue] < minScore) {
			minScore = [[scoresArray objectAtIndex:j] longValue];
			minIndex = j;
		}
	}
    
	if (minIndex == -1) { // didn't qualify
		return false;
	}
    
	// minIndex identifies the score entry to be replaced
	newScore = [NSNumber numberWithLong:theEntry.score];
	newText = [NSString stringWithCString:theEntry.description encoding:NSASCIIStringEncoding];
	[scoresArray replaceObjectAtIndex:minIndex withObject:newScore];
	[textArray replaceObjectAtIndex:minIndex withObject:newText];
	[datesArray replaceObjectAtIndex:minIndex withObject:[NSDate date]];
    
	[[NSUserDefaults standardUserDefaults] setObject:scoresArray forKey:@"high scores scores"];
	[[NSUserDefaults standardUserDefaults] setObject:textArray forKey:@"high scores text"];
	[[NSUserDefaults standardUserDefaults] setObject:datesArray forKey:@"high scores dates"];
	[[NSUserDefaults standardUserDefaults] synchronize];
    
	return true;
}

void initializeLaunchArguments(enum NGCommands *command, char *path, unsigned long *seed) {
    *command = NG_NOTHING;
    //*command = NG_SCUM;
	path[0] = '\0';
	*seed = 0;
}

void initializeBrogueSaveLocation() {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *err;
    
    // Look up the full path to the user's Application Support folder (usually ~/Library/Application Support/).
    NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
    
    // Use a folder under Application Support named after the application.
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"];
    NSString *supportPath = [basePath stringByAppendingPathComponent: appName];
    
    // Create our folder the first time it is needed.
    if (![manager fileExistsAtPath: supportPath]) {
        [manager createDirectoryAtPath:supportPath withIntermediateDirectories:YES attributes:nil error:&err];
    }
    
    // Set the working directory to this path, so that savegames and recordings will be stored here.
    [manager changeCurrentDirectoryPath: supportPath];
}

#define ADD_FAKE_PADDING_FILES 0

// Returns a malloc'ed fileEntry array, and puts the file count into *fileCount.
// Also returns a pointer to the memory that holds the file names, so that it can also
// be freed afterward.
fileEntry *listFiles(short *fileCount, char **dynamicMemoryBuffer) {
	short i, count, thisFileNameLength;
	unsigned long bufferPosition, bufferSize;
	unsigned long *offsets;
	fileEntry *fileList;
	NSArray *array;
	NSFileManager *manager = [NSFileManager defaultManager];
    NSError *err;
	NSDictionary *fileAttributes;
	NSDateFormatter *dateFormatter;
	const char *thisFileName;
    
	char tempString[500];
    
	bufferPosition = bufferSize = 0;
	*dynamicMemoryBuffer = NULL;
    
    dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateFormat:@"M/d/yy"];
    
	array = [manager contentsOfDirectoryAtPath:[manager currentDirectoryPath] error:&err];
	count = [array count];
    
	fileList = malloc((count + ADD_FAKE_PADDING_FILES) * sizeof(fileEntry));
	offsets = malloc((count + ADD_FAKE_PADDING_FILES) * sizeof(unsigned long));
    
	for (i=0; i < count + ADD_FAKE_PADDING_FILES; i++) {
		if (i < count) {
			thisFileName = [[array objectAtIndex:i] cStringUsingEncoding:NSASCIIStringEncoding];
			fileAttributes = [manager attributesOfItemAtPath:[array objectAtIndex:i] error:nil];
			strcpy(fileList[i].date,
				   [[dateFormatter stringFromDate:[fileAttributes fileModificationDate]] cStringUsingEncoding:NSASCIIStringEncoding]);
		} else {
			// Debug feature.
			sprintf(tempString, "Fake padding file %i.broguerec", i - count + 1);
			thisFileName = &(tempString[0]);
			strcpy(fileList[i].date, "12/12/12");
		}
        
		thisFileNameLength = strlen(thisFileName);
        
		if (thisFileNameLength + bufferPosition > bufferSize) {
			bufferSize += sizeof(char) * 1024;
			*dynamicMemoryBuffer = (char *) realloc(*dynamicMemoryBuffer, bufferSize);
		}
        
		offsets[i] = bufferPosition; // Have to store these as offsets instead of pointers, as realloc could invalidate pointers.
        
		strcpy(&((*dynamicMemoryBuffer)[bufferPosition]), thisFileName);
		bufferPosition += thisFileNameLength + 1;
	}
    
	// Convert the offsets to pointers.
	for (i = 0; i < count + ADD_FAKE_PADDING_FILES; i++) {
		fileList[i].path = &((*dynamicMemoryBuffer)[offsets[i]]);
	}
    
	free(offsets);
    [dateFormatter release];
    
	*fileCount = count + ADD_FAKE_PADDING_FILES;
	return fileList;
}


// Returns a pointer to a char* containing the contents of the clipboard
#ifdef USE_CLIPBOARD
char *getClipboard() {
    NSString *pasteboardData = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    return (char*)[pasteboardData cStringUsingEncoding:NSUTF8StringEncoding];
}
#endif
