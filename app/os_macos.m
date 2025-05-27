// SPDX-License-Identifier: Unlicense OR MIT

// +build darwin,!ios

#import <AppKit/AppKit.h>

#include "_cgo_export.h"

__attribute__ ((visibility ("hidden"))) CALayer *gio_layerFactory(BOOL presentWithTrans);

@interface GioAppDelegate : NSObject<NSApplicationDelegate>
@end

@interface GioWindowDelegate : NSObject<NSWindowDelegate>
@end

@interface GioLayerShellWindow : NSWindow
@property int keyboardInteractivity;
@end

@interface GioView : NSView <CALayerDelegate,NSTextInputClient>
@property uintptr_t handle;
@property BOOL presentWithTrans;
@end

@implementation GioWindowDelegate
- (void)windowWillMiniaturize:(NSNotification *)notification {
	NSWindow *window = (NSWindow *)[notification object];
  GioView *view = (GioView *)window.contentView;
	gio_onDraw(view.handle);
}
- (void)windowDidDeminiaturize:(NSNotification *)notification {
	NSWindow *window = (NSWindow *)[notification object];
  GioView *view = (GioView *)window.contentView;
	gio_onDraw(view.handle);
}
- (void)windowWillEnterFullScreen:(NSNotification *)notification {
	NSWindow *window = (NSWindow *)[notification object];
  GioView *view = (GioView *)window.contentView;
	gio_onDraw(view.handle);
}
- (void)windowWillExitFullScreen:(NSNotification *)notification {
	NSWindow *window = (NSWindow *)[notification object];
  GioView *view = (GioView *)window.contentView;
	gio_onDraw(view.handle);
}
- (void)windowDidChangeScreen:(NSNotification *)notification {
	NSWindow *window = (NSWindow *)[notification object];
	CGDirectDisplayID dispID = [[[window screen] deviceDescription][@"NSScreenNumber"] unsignedIntValue];
  GioView *view = (GioView *)window.contentView;
	gio_onChangeScreen(view.handle, dispID);
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
	NSWindow *window = (NSWindow *)[notification object];
	GioView *view = (GioView *)window.contentView;
	if ([window firstResponder] == view) {
		gio_onFocus(view.handle, 1);
	}
}
- (void)windowDidResignKey:(NSNotification *)notification {
	NSWindow *window = (NSWindow *)[notification object];
	GioView *view = (GioView *)window.contentView;
	if ([window firstResponder] == view) {
		gio_onFocus(view.handle, 0);
	}
}
@end

@implementation GioLayerShellWindow
- (BOOL)canBecomeKeyWindow {
	// KeyboardInteractivityNone = 0, KeyboardInteractivityExclusive = 1, KeyboardInteractivityOnDemand = 2
	return self.keyboardInteractivity != 0;
}

- (BOOL)canBecomeMainWindow {
	// Only allow becoming main window for on-demand interactivity
	return self.keyboardInteractivity == 2;
}

- (BOOL)acceptsFirstResponder {
	return self.keyboardInteractivity != 0;
}
@end

static void handleMouse(GioView *view, NSEvent *event, int typ, CGFloat dx, CGFloat dy) {
	NSPoint p = [view convertPoint:[event locationInWindow] fromView:nil];
	if (!event.hasPreciseScrollingDeltas) {
		// dx and dy are in rows and columns.
		dx *= 10;
		dy *= 10;
	}
	// Origin is in the lower left corner. Convert to upper left.
	CGFloat height = view.bounds.size.height;
	gio_onMouse(view.handle, (__bridge CFTypeRef)event, typ, event.buttonNumber, p.x, height - p.y, dx, dy, [event timestamp], [event modifierFlags]);
}

@implementation GioView
- (void)setFrameSize:(NSSize)newSize {
	[super setFrameSize:newSize];
	[self setNeedsDisplay:YES];
}
// drawRect is called when OpenGL is used, displayLayer otherwise.
// Don't know why.
- (void)drawRect:(NSRect)r {
	gio_onDraw(self.handle);
}
- (void)displayLayer:(CALayer *)layer {
	layer.contentsScale = self.window.backingScaleFactor;
	gio_onDraw(self.handle);
}
- (CALayer *)makeBackingLayer {
	CALayer *layer = gio_layerFactory(self.presentWithTrans);
	layer.delegate = self;
	return layer;
}
- (void)viewDidMoveToWindow {
	gio_onAttached(self.handle, self.window != nil ? 1 : 0);
}
- (void)mouseDown:(NSEvent *)event {
	handleMouse(self, event, MOUSE_DOWN, 0, 0);
}
- (void)mouseUp:(NSEvent *)event {
	handleMouse(self, event, MOUSE_UP, 0, 0);
}
- (void)rightMouseDown:(NSEvent *)event {
	handleMouse(self, event, MOUSE_DOWN, 0, 0);
}
- (void)rightMouseUp:(NSEvent *)event {
	handleMouse(self, event, MOUSE_UP, 0, 0);
}
- (void)otherMouseDown:(NSEvent *)event {
	handleMouse(self, event, MOUSE_DOWN, 0, 0);
}
- (void)otherMouseUp:(NSEvent *)event {
	handleMouse(self, event, MOUSE_UP, 0, 0);
}
- (void)mouseMoved:(NSEvent *)event {
	handleMouse(self, event, MOUSE_MOVE, 0, 0);
}
- (void)mouseDragged:(NSEvent *)event {
	handleMouse(self, event, MOUSE_MOVE, 0, 0);
}
- (void)rightMouseDragged:(NSEvent *)event {
	handleMouse(self, event, MOUSE_MOVE, 0, 0);
}
- (void)otherMouseDragged:(NSEvent *)event {
	handleMouse(self, event, MOUSE_MOVE, 0, 0);
}
- (void)scrollWheel:(NSEvent *)event {
	CGFloat dx = -event.scrollingDeltaX;
	CGFloat dy = -event.scrollingDeltaY;
	handleMouse(self, event, MOUSE_SCROLL, dx, dy);
}
- (void)keyDown:(NSEvent *)event {
	NSString *keys = [event charactersIgnoringModifiers];
	gio_onKeys(self.handle, (__bridge CFTypeRef)event, (__bridge CFTypeRef)keys, [event timestamp], [event modifierFlags], true);
}
- (void)flagsChanged:(NSEvent *)event {
	[self interpretKeyEvents:[NSArray arrayWithObject:event]];
	gio_onFlagsChanged(self.handle, [event modifierFlags]);
}
- (void)keyUp:(NSEvent *)event {
	NSString *keys = [event charactersIgnoringModifiers];
	gio_onKeys(self.handle, (__bridge CFTypeRef)event, (__bridge CFTypeRef)keys, [event timestamp], [event modifierFlags], false);
}
- (void)insertText:(id)string {
	gio_onText(self.handle, (__bridge CFTypeRef)string);
}
- (void)doCommandBySelector:(SEL)action {
	if (!gio_onCommandBySelector(self.handle)) {
		[super doCommandBySelector:action];
	}
}
- (BOOL)hasMarkedText {
	int res = gio_hasMarkedText(self.handle);
	return res ? YES : NO;
}
- (NSRange)markedRange {
	return gio_markedRange(self.handle);
}
- (NSRange)selectedRange {
	return gio_selectedRange(self.handle);
}
- (void)unmarkText {
	gio_unmarkText(self.handle);
}
- (void)setMarkedText:(id)string
        selectedRange:(NSRange)selRange
     replacementRange:(NSRange)replaceRange {
	NSString *str;
	// string is either an NSAttributedString or an NSString.
	if ([string isKindOfClass:[NSAttributedString class]]) {
		str = [string string];
	} else {
		str = string;
	}
	gio_setMarkedText(self.handle, (__bridge CFTypeRef)str, selRange, replaceRange);
}
- (NSArray<NSAttributedStringKey> *)validAttributesForMarkedText {
	return nil;
}
- (NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range
                                                actualRange:(NSRangePointer)actualRange {
	NSString *str = CFBridgingRelease(gio_substringForProposedRange(self.handle, range, actualRange));
	return [[NSAttributedString alloc] initWithString:str attributes:nil];
}
- (void)insertText:(id)string
  replacementRange:(NSRange)replaceRange {
	NSString *str;
	// string is either an NSAttributedString or an NSString.
	if ([string isKindOfClass:[NSAttributedString class]]) {
		str = [string string];
	} else {
		str = string;
	}
	gio_insertText(self.handle, (__bridge CFTypeRef)str, replaceRange);
}
- (NSUInteger)characterIndexForPoint:(NSPoint)p {
	return gio_characterIndexForPoint(self.handle, p);
}
- (NSRect)firstRectForCharacterRange:(NSRange)rng
                         actualRange:(NSRangePointer)actual {
    NSRect r = gio_firstRectForCharacterRange(self.handle, rng, actual);
    r = [self convertRect:r toView:nil];
    return [[self window] convertRectToScreen:r];
}
- (void)applicationWillUnhide:(NSNotification *)notification {
	gio_onDraw(self.handle);
}
- (void)applicationDidHide:(NSNotification *)notification {
	gio_onDraw(self.handle);
}
- (void)dealloc {
	gio_onDestroy(self.handle);
}
- (BOOL) becomeFirstResponder {
	gio_onFocus(self.handle, 1);
	return [super becomeFirstResponder];
 }
- (BOOL) resignFirstResponder {
	gio_onFocus(self.handle, 0);
	return [super resignFirstResponder];
}
@end

// Delegates are weakly referenced from their peers. Nothing
// else holds a strong reference to our window delegate, so
// keep a single global reference instead.
static GioWindowDelegate *globalWindowDel;

static CVReturn displayLinkCallback(CVDisplayLinkRef dl, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *handle) {
	gio_onFrameCallback(dl);
	return kCVReturnSuccess;
}

CFTypeRef gio_createDisplayLink(void) {
	CVDisplayLinkRef dl;
	CVDisplayLinkCreateWithActiveCGDisplays(&dl);
	CVDisplayLinkSetOutputCallback(dl, displayLinkCallback, nil);
	return dl;
}

int gio_startDisplayLink(CFTypeRef dl) {
	return CVDisplayLinkStart((CVDisplayLinkRef)dl);
}

int gio_stopDisplayLink(CFTypeRef dl) {
	return CVDisplayLinkStop((CVDisplayLinkRef)dl);
}

void gio_releaseDisplayLink(CFTypeRef dl) {
	CVDisplayLinkRelease((CVDisplayLinkRef)dl);
}

void gio_setDisplayLinkDisplay(CFTypeRef dl, uint64_t did) {
	CVDisplayLinkSetCurrentCGDisplay((CVDisplayLinkRef)dl, (CGDirectDisplayID)did);
}

void gio_hideCursor() {
	@autoreleasepool {
		[NSCursor hide];
	}
}

void gio_showCursor() {
	@autoreleasepool {
		[NSCursor unhide];
	}
}

// some cursors are not public, this tries to use a private cursor
// and uses fallback when the use of private cursor fails.
static void trySetPrivateCursor(SEL cursorName, NSCursor* fallback) {
	if ([NSCursor respondsToSelector:cursorName]) {
		id object = [NSCursor performSelector:cursorName];
		if ([object isKindOfClass:[NSCursor class]]) {
			[(NSCursor*)object set];
			return;
		}
	}
	[fallback set];
}

void gio_setCursor(NSUInteger curID) {
	@autoreleasepool {
		switch (curID) {
			case 0: // pointer.CursorDefault
				[NSCursor.arrowCursor set];
				break;
			// case 1: // pointer.CursorNone
			case 2: // pointer.CursorText
				[NSCursor.IBeamCursor set];
				break;
			case 3: // pointer.CursorVerticalText
				[NSCursor.IBeamCursorForVerticalLayout set];
				break;
			case 4: // pointer.CursorPointer
				[NSCursor.pointingHandCursor set];
				break;
			case 5: // pointer.CursorCrosshair
				[NSCursor.crosshairCursor set];
				break;
			case 6: // pointer.CursorAllScroll
				// For some reason, using _moveCursor fails on Monterey.
				// trySetPrivateCursor(@selector(_moveCursor), NSCursor.arrowCursor);
				[NSCursor.arrowCursor set];
				break;
			case 7: // pointer.CursorColResize
				[NSCursor.resizeLeftRightCursor set];
				break;
			case 8: // pointer.CursorRowResize
				[NSCursor.resizeUpDownCursor set];
				break;
			case 9: // pointer.CursorGrab
				[NSCursor.openHandCursor set];
				break;
			case 10: // pointer.CursorGrabbing
				[NSCursor.closedHandCursor set];
				break;
			case 11: // pointer.CursorNotAllowed
				[NSCursor.operationNotAllowedCursor set];
				break;
			case 12: // pointer.CursorWait
				trySetPrivateCursor(@selector(busyButClickableCursor), NSCursor.arrowCursor);
				break;
			case 13: // pointer.CursorProgress
				trySetPrivateCursor(@selector(busyButClickableCursor), NSCursor.arrowCursor);
				break;
			case 14: // pointer.CursorNorthWestResize
				trySetPrivateCursor(@selector(_windowResizeNorthWestCursor), NSCursor.resizeUpDownCursor);
				break;
			case 15: // pointer.CursorNorthEastResize
				trySetPrivateCursor(@selector(_windowResizeNorthEastCursor), NSCursor.resizeUpDownCursor);
				break;
			case 16: // pointer.CursorSouthWestResize
				trySetPrivateCursor(@selector(_windowResizeSouthWestCursor), NSCursor.resizeUpDownCursor);
				break;
			case 17: // pointer.CursorSouthEastResize
				trySetPrivateCursor(@selector(_windowResizeSouthEastCursor), NSCursor.resizeUpDownCursor);
				break;
			case 18: // pointer.CursorNorthSouthResize
				[NSCursor.resizeUpDownCursor set];
				break;
			case 19: // pointer.CursorEastWestResize
				[NSCursor.resizeLeftRightCursor set];
				break;
			case 20: // pointer.CursorWestResize
				[NSCursor.resizeLeftCursor set];
				break;
			case 21: // pointer.CursorEastResize
				[NSCursor.resizeRightCursor set];
				break;
			case 22: // pointer.CursorNorthResize
				[NSCursor.resizeUpCursor set];
				break;
			case 23: // pointer.CursorSouthResize
				[NSCursor.resizeDownCursor set];
				break;
			case 24: // pointer.CursorNorthEastSouthWestResize
				trySetPrivateCursor(@selector(_windowResizeNorthEastSouthWestCursor), NSCursor.resizeUpDownCursor);
				break;
			case 25: // pointer.CursorNorthWestSouthEastResize
				trySetPrivateCursor(@selector(_windowResizeNorthWestSouthEastCursor), NSCursor.resizeUpDownCursor);
				break;
			default:
				[NSCursor.arrowCursor set];
				break;
		}
	}
}

CFTypeRef gio_createWindow(CFTypeRef viewRef, CGFloat width, CGFloat height, CGFloat minWidth, CGFloat minHeight, CGFloat maxWidth, CGFloat maxHeight) {
	@autoreleasepool {
		NSRect rect = NSMakeRect(0, 0, width, height);
		NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
			NSWindowStyleMaskResizable |
			NSWindowStyleMaskMiniaturizable |
			NSWindowStyleMaskClosable;

		NSWindow* window = [[NSWindow alloc] initWithContentRect:rect
													   styleMask:styleMask
														 backing:NSBackingStoreBuffered
														   defer:NO];
		if (minWidth > 0 || minHeight > 0) {
			window.contentMinSize = NSMakeSize(minWidth, minHeight);
		}
		if (maxWidth > 0 || maxHeight > 0) {
			window.contentMaxSize = NSMakeSize(maxWidth, maxHeight);
		}
		[window setAcceptsMouseMovedEvents:YES];
		NSView *view = (__bridge NSView *)viewRef;
		[window setContentView:view];
		window.delegate = globalWindowDel;
		return (__bridge_retained CFTypeRef)window;
	}
}

CFTypeRef gio_createLayerShellWindow(CFTypeRef viewRef, CGFloat width, CGFloat height, 
									 int layer, int anchor, int keyboardInteractivity, 
									 int marginTop, int marginBottom, int marginLeft, int marginRight) {
	@autoreleasepool {
		NSRect rect = NSMakeRect(0, 0, width, height);
		
		GioLayerShellWindow* window = [[GioLayerShellWindow alloc] initWithContentRect:rect
																			 styleMask:NSWindowStyleMaskBorderless
																			   backing:NSBackingStoreBuffered
																				 defer:NO];
		window.keyboardInteractivity = keyboardInteractivity;
		
		[window setAcceptsMouseMovedEvents:YES];
		NSView *view = (__bridge NSView *)viewRef;
		[window setContentView:view];
		window.delegate = globalWindowDel;
		
		// Configure layer shell properties
		configureLayerShellWindow((__bridge CFTypeRef)window, layer, anchor, keyboardInteractivity, YES);
		
		// Set initial position based on anchors
		setWindowFrameForAnchors((__bridge CFTypeRef)window, width, height, anchor, 
								 marginTop, marginBottom, marginLeft, marginRight);
		
		return (__bridge_retained CFTypeRef)window;
	}
}

CFTypeRef gio_createView(int presentWithTrans) {
	@autoreleasepool {
		NSRect frame = NSMakeRect(0, 0, 0, 0);
		GioView* view = [[GioView alloc] initWithFrame:frame];
		view.presentWithTrans = presentWithTrans ? YES : NO;
		view.wantsLayer = YES;
		view.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;

		[[NSNotificationCenter defaultCenter] addObserver:view
												 selector:@selector(applicationWillUnhide:)
													 name:NSApplicationWillUnhideNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:view
												 selector:@selector(applicationDidHide:)
													 name:NSApplicationDidHideNotification
												   object:nil];
		return CFBridgingRetain(view);
	}
}

void gio_viewSetHandle(CFTypeRef viewRef, uintptr_t handle) {
	@autoreleasepool {
		GioView *v = (__bridge GioView *)viewRef;
		v.handle = handle;
	}
}

@implementation GioAppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
	[NSApp activateIgnoringOtherApps:YES];
	gio_onFinishLaunching();
}
@end

void gio_main() {
	@autoreleasepool {
		[NSApplication sharedApplication];
		GioAppDelegate *del = [[GioAppDelegate alloc] init];
		[NSApp setDelegate:del];

		NSMenuItem *mainMenu = [NSMenuItem new];

		NSMenu *menu = [NSMenu new];
		NSMenuItem *hideMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hide"
															  action:@selector(hide:)
													   keyEquivalent:@"h"];
		[menu addItem:hideMenuItem];
		NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
															  action:@selector(terminate:)
													   keyEquivalent:@"q"];
		[menu addItem:quitMenuItem];
		[mainMenu setSubmenu:menu];
		NSMenu *menuBar = [NSMenu new];
		[menuBar addItem:mainMenu];
		[NSApp setMainMenu:menuBar];

		globalWindowDel = [[GioWindowDelegate alloc] init];

		[NSApp run];
	}
}

// Layer shell support functions
void setWindowLevel(CFTypeRef windowRef, int level) {
	@autoreleasepool {
		NSWindow *window = (__bridge NSWindow *)windowRef;
		NSWindowLevel windowLevel;
		switch (level) {
			case 0: // LayerBackground
				windowLevel = kCGDesktopWindowLevel;
				break;
			case 1: // LayerBottom
				windowLevel = kCGNormalWindowLevel - 1;
				break;
			case 2: // LayerTop
				windowLevel = kCGFloatingWindowLevel;
				break;
			case 3: // LayerOverlay
				windowLevel = kCGScreenSaverWindowLevel;
				break;
			default:
				windowLevel = kCGNormalWindowLevel;
				break;
		}
		[window setLevel:windowLevel];
	}
}

void setWindowCollectionBehavior(CFTypeRef windowRef, int canJoinAllSpaces, int stationary) {
	@autoreleasepool {
		NSWindow *window = (__bridge NSWindow *)windowRef;
		NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorDefault;
		
		if (canJoinAllSpaces) {
			behavior |= NSWindowCollectionBehaviorCanJoinAllSpaces;
		}
		if (stationary) {
			behavior |= NSWindowCollectionBehaviorStationary;
		}
		
		// For layer shell windows, we typically want them to be transient
		// and not participate in normal window cycling
		behavior |= NSWindowCollectionBehaviorTransient;
		behavior |= NSWindowCollectionBehaviorIgnoresCycle;
		
		[window setCollectionBehavior:behavior];
	}
}

void setWindowMovable(CFTypeRef windowRef, int movable) {
	@autoreleasepool {
		NSWindow *window = (__bridge NSWindow *)windowRef;
		[window setMovable:movable];
	}
}

NSRect getScreenFrame(CFTypeRef windowRef) {
	@autoreleasepool {
		NSWindow *window = (__bridge NSWindow *)windowRef;
		return [[window screen] frame];
	}
}

NSRect getScreenVisibleFrame(CFTypeRef windowRef) {
	@autoreleasepool {
		NSWindow *window = (__bridge NSWindow *)windowRef;
		return [[window screen] visibleFrame];
	}
}

void setWindowFrameForAnchors(CFTypeRef windowRef, CGFloat width, CGFloat height, 
									 int anchor, int marginTop, int marginBottom, 
									 int marginLeft, int marginRight) {
	@autoreleasepool {
		NSWindow *window = (__bridge NSWindow *)windowRef;
		NSScreen *screen = [window screen];
		if (!screen) {
			screen = [NSScreen mainScreen];
		}
		
		NSRect screenFrame = [screen frame];
		NSRect visibleFrame = [screen visibleFrame];
		
		// For layer shell windows, we want to use different frames based on anchoring
		NSRect targetFrame;
		BOOL anchorTop = (anchor & 1) != 0;
		BOOL anchorBottom = (anchor & 2) != 0;
		BOOL anchorLeft = (anchor & 4) != 0;
		BOOL anchorRight = (anchor & 8) != 0;
		
		// Use full screen frame for top-anchored windows (status bars)
		// Use visible frame for other positions to respect menu bar and dock
		if (anchorTop && !anchorBottom) {
			// Top-anchored status bar should use full screen width and be above menu bar
			targetFrame = screenFrame;
		} else {
			// Other positions should respect menu bar and dock
			targetFrame = visibleFrame;
		}
		
		// Apply margins
		targetFrame.origin.x += marginLeft;
		targetFrame.origin.y += marginBottom;
		targetFrame.size.width -= (marginLeft + marginRight);
		targetFrame.size.height -= (marginTop + marginBottom);
		
		CGFloat x = targetFrame.origin.x;
		CGFloat y = targetFrame.origin.y;
		CGFloat w = width;
		CGFloat h = height;
		
		// Horizontal positioning and sizing
		if (anchorLeft && anchorRight) {
			// Anchored to both left and right - stretch full width
			x = targetFrame.origin.x;
			w = targetFrame.size.width;
		} else if (anchorLeft) {
			// Anchored to left only
			x = targetFrame.origin.x;
			// Keep specified width
		} else if (anchorRight) {
			// Anchored to right only
			x = targetFrame.origin.x + targetFrame.size.width - w;
		} else {
			// Not anchored horizontally - center
			x = targetFrame.origin.x + (targetFrame.size.width - w) / 2;
		}
		
		// Vertical positioning and sizing
		if (anchorTop && anchorBottom) {
			// Anchored to both top and bottom - stretch full height
			y = targetFrame.origin.y;
			h = targetFrame.size.height;
		} else if (anchorTop) {
			// Anchored to top only - position at the very top
			y = targetFrame.origin.y + targetFrame.size.height - h;
		} else if (anchorBottom) {
			// Anchored to bottom only
			y = targetFrame.origin.y;
			// Keep specified height
		} else {
			// Not anchored vertically - center
			y = targetFrame.origin.y + (targetFrame.size.height - h) / 2;
		}
		
		NSRect newFrame = NSMakeRect(x, y, w, h);
		[window setFrame:newFrame display:YES];
		
		// IMPORTANT: Resize the content view AND all its subviews to match the window's content area
		// This ensures the Gio view reports the correct size
		NSView *contentView = [window contentView];
		if (contentView) {
			NSRect contentFrame = NSMakeRect(0, 0, newFrame.size.width, newFrame.size.height);
			[contentView setFrame:contentFrame];
			
			// Also resize all subviews (including the Gio view) to match
			for (NSView *subview in [contentView subviews]) {
				[subview setFrame:contentFrame];
			}
		}
	}
}

void configureLayerShellWindow(CFTypeRef windowRef, int layer, int anchor, 
									  int keyboardInteractivity, int canJoinAllSpaces) {
	@autoreleasepool {
		NSWindow *window = (__bridge NSWindow *)windowRef;
		
		// Set window level based on layer
		setWindowLevel(windowRef, layer);
		
		// Configure collection behavior
		setWindowCollectionBehavior(windowRef, canJoinAllSpaces, YES);
		
		// Make window non-movable for layer shell
		setWindowMovable(windowRef, NO);
		
		// Configure keyboard interactivity
		if (keyboardInteractivity == 0) { // KeyboardInteractivityNone
			// Prevent the window from becoming key
			// This is a bit tricky in AppKit, we'll handle it in the window delegate
		}
		
		// Remove standard window buttons and make borderless
		NSWindowStyleMask styleMask = NSWindowStyleMaskBorderless;
		[window setStyleMask:styleMask];
		[window setHasShadow:NO];
		[window setOpaque:NO];
		[window setBackgroundColor:[NSColor clearColor]];
	}
}
