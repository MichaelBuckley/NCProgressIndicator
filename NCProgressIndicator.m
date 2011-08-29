/* Copyright (c) 2011 Michael Buckley
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * The graphics distributed with this code are licensed under a Creative Commons
 * Attribution-NonCommercial 3.0 Unported License with the attribution notice
 * listed below. To view a copy of this license, visit
 * http://creativecommons.org/licenses/by-nc/3.0/ or send a letter to Creative
 * Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
 *
 * Attribution Notice:
 * The graphics distributed with this code are derived from the original Pop
 * Tart Cat gif created by Chris Torres, located at
 * http://www.prguitarman.com/index.php?id=348
 */

#import <objc/message.h>

#import "NCProgressIndicator.h"

#ifdef NC_PROGRESS_INDICATOR_SIMBL_PLUGIN
#import "JRSwizzle.h"

#define NC_PROGRESS_INDICATOR_METHOD(x)     NCProgressIndicator_##x
#define NC_PROGRESS_INDICATOR_SUPER_CALL(x) [self NC_PROGRESS_INDICATOR_METHOD(x)]

#else

#define NC_PROGRESS_INDICATOR_METHOD(x)     x
#define NC_PROGRESS_INDICATOR_SUPER_CALL(x) [super x]

#endif

@interface NCProgressIndicatorTimer : NSObject
{
    @protected
    NSMutableSet* views;
    NSTimer* timer;
}

- (void)animationTimerMethod;

- (void)addView:(NSView*)aView;
- (void)removeView:(NSView*)aView;

@end

@interface NCProgressIndicatorThread : NSObject
{
@protected
    NSMutableSet* views;
    NSThread* thread;
}

- (void)animationThreadMethod:(id)aParam;

- (void)addView:(NSView*)aView;
- (void)removeView:(NSView*)aView;

@end

@interface NCProgressIndicator ()

- (void)NC_PROGRESS_INDICATOR_METHOD(setup);
- (void)NC_PROGRESS_INDICATOR_METHOD(startAnimationTimerIfNeeded);
- (void)NC_PROGRESS_INDICATOR_METHOD(startAnimationThreadIfNeeded);

- (BOOL)NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle);
- (BOOL)NC_PROGRESS_INDICATOR_METHOD(shouldResize);
- (BOOL)NC_PROGRESS_INDICATOR_METHOD(bouncesRainbow);

- (double)NC_PROGRESS_INDICATOR_METHOD(percentValue);

- (void)NC_PROGRESS_INDICATOR_METHOD(drawBackground:(NSRect)dirtyRect frameCount:(NSUInteger)frameCount);
- (void)NC_PROGRESS_INDICATOR_METHOD(drawRainbow:   (NSRect)dirtyRect frameCount:(NSUInteger)frameCount);
- (void)NC_PROGRESS_INDICATOR_METHOD(drawStars:     (NSRect)dirtyRect frameCount:(NSUInteger)frameCount);
- (void)NC_PROGRESS_INDICATOR_METHOD(drawSprite:    (NSRect)dirtyRect frameCount:(NSUInteger)frameCount);

@end

const NSTimeInterval kNCProgressIndicatorFrameDelay           = 0.07;
const CGFloat        kNCProgressIndicatorRegularBarHeight     = 20.0;
const CGFloat        kNCProgressIndicatorRainbowSegmentWidth  = 9.0;
const NSUInteger     kNCProgressIndicatorNumAnimationFrames   = 60;
const NSUInteger     kNCProgressIndicatorNumStarSprites       = 6;
const CGFloat        kNCProgressIndicatorStarSpeed            = 6.0;
const CGFloat        kNCProgressIndicatorStarDistance         = 18.0;
const NSUInteger     kNCProgressIndicatorNumRegularCatSprites = 6;
const NSUInteger     kNCProgressIndicatorRainbowPeriod        = 4;
const CGFloat        kNCProgressIndicatorRegularRainbowOffset = 16.0;
const CGFloat        kNCProgressIndicatorSmallRainbowOffset   = 3.0;

static NSUInteger                 sNCProgressIndicatorTimerFrameCount   = 0;
static NSUInteger                 sNCProgressIndicatorThreadFrameCount  = 0;
static NCProgressIndicatorThread* sNCProgressIndicatorAnimationThread   = nil;
static NCProgressIndicatorTimer*  sNCProgressIndicatorAnimationTimer    = nil;
static NSArray*                   sNCProgressIndicatorStarSprites       = nil;
static NSArray*                   sNCProgressIndicatorRegularCatSprites = nil;
static NSArray*                   sNCProgressIndicatorSmallCatSprites   = nil;
static NSArray*                   sNCProgressIndicatorRainbowColors     = nil;

@implementation NCProgressIndicatorTimer

- (id)init
{
    if (self = [super init])
    {
        sNCProgressIndicatorTimerFrameCount = sNCProgressIndicatorThreadFrameCount;
        
        views = [[NSMutableSet alloc] init];
        
        NSMethodSignature* signature = [[self class] instanceMethodSignatureForSelector:@selector(animationTimerMethod)]; 
        NSInvocation* invocation     = [NSInvocation invocationWithMethodSignature:signature];
        
        [invocation setTarget:self];
        [invocation setSelector:@selector(animationTimerMethod)];
        
        timer = [NSTimer timerWithTimeInterval:kNCProgressIndicatorFrameDelay
                                    invocation:invocation
                                       repeats:YES];
        
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    }
    
    return self;
}

- (void)dealloc
{
    @synchronized([self class])
    {
        [views release];
        views = nil;
    }
    
    if (timer != nil)
    {
        [timer invalidate];
        timer = nil;
    }
    
    [super dealloc];
}

- (void)animationTimerMethod
{
    sNCProgressIndicatorTimerFrameCount = sNCProgressIndicatorTimerFrameCount + 1 % kNCProgressIndicatorNumAnimationFrames;
    
    @synchronized([self class])
    {
        for (NSView* view in views)
        {
            [view display];
        }
    }
}

- (void)addView:(NSView*)aView
{
    @synchronized([self class])
    {
        [views addObject:aView];
    }
}

- (void)removeView:(NSView*)aView
{
    @synchronized([self class])
    {
        [views removeObject:aView];
        
        if ([views count] == 0)
        {
            sNCProgressIndicatorAnimationTimer = nil;
            
            [timer invalidate];
            timer = nil;
            
            [self release];
        }
    }
}

@end

@implementation NCProgressIndicatorThread

- (id)init
{
    if (self = [super init])
    {
        views  = [[NSMutableSet alloc] init];
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(animationThreadMethod:) object:nil];
        [thread start];
    }
    
    return self;
}

- (void)dealloc
{
    @synchronized([self class])
    {
        [views release];
        views = nil;
    }
    
    [thread release];
    thread = nil;
    
    [super dealloc];
}

- (void)animationThreadMethod:(id)aParam
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    sNCProgressIndicatorThreadFrameCount = sNCProgressIndicatorTimerFrameCount - 1;
    
    while (![thread isCancelled])
    {
        NSDate* startDate = [[NSDate alloc] init];
        
        sNCProgressIndicatorThreadFrameCount = sNCProgressIndicatorThreadFrameCount + 1 % kNCProgressIndicatorNumAnimationFrames;
        
        @synchronized([self class])
        {
            for (NSView* view in views)
            {
                [view setNeedsDisplay:YES];
            }
        }
        
        NSDate* awakeDate = [[NSDate alloc] initWithTimeInterval:kNCProgressIndicatorFrameDelay
                                                       sinceDate:startDate];
        
        [NSThread sleepUntilDate:awakeDate];
        
        [startDate release];
        [awakeDate release];
    }
    
    [pool drain];
    
    [self release];
}

- (void)addView:(NSView*)aView
{
    @synchronized([self class])
    {
        [views addObject:aView];
    }
}

- (void)removeView:(NSView*)aView
{
    @synchronized([self class])
    {
        [views removeObject:aView];
        
        if ([views count] == 0)
        {
            sNCProgressIndicatorAnimationThread = nil;
            [thread cancel];
        }
    }
}

@end

@implementation NCProgressIndicator

- (id)NC_PROGRESS_INDICATOR_METHOD(initWithFrame:(NSRect)frameRect)
{
    if (self = NC_PROGRESS_INDICATOR_SUPER_CALL(initWithFrame:frameRect))
    {
        [self NC_PROGRESS_INDICATOR_METHOD(setup)];
    }
    
    return self;
}

- (id)NC_PROGRESS_INDICATOR_METHOD(initWithCoder:(NSCoder *)aDecoder)
{
    if (self = NC_PROGRESS_INDICATOR_SUPER_CALL(initWithCoder:aDecoder))
    {
        [self NC_PROGRESS_INDICATOR_METHOD(setup)];
    }
    
    return self;
}

- (void)NC_PROGRESS_INDICATOR_METHOD(dealloc)
{
    @synchronized([NCProgressIndicatorTimer class])
    {
        [sNCProgressIndicatorAnimationTimer removeView:self];
    }
    
    @synchronized([NCProgressIndicatorThread class])
    {
        [sNCProgressIndicatorAnimationThread removeView:self];
    }
    
    NC_PROGRESS_INDICATOR_SUPER_CALL(dealloc);
}

- (void)NC_PROGRESS_INDICATOR_METHOD(setup)
{
    @synchronized([self class])
    {
        if (sNCProgressIndicatorRainbowColors == nil)
        {
            sNCProgressIndicatorRainbowColors = [[NSArray alloc] initWithObjects:
                                                 [NSColor colorWithDeviceRed:1.0 green:0   blue:0   alpha:1.0],
                                                 [NSColor colorWithDeviceRed:1.0 green:0.6 blue:0   alpha:1.0],
                                                 [NSColor colorWithDeviceRed:1.0 green:1.0 blue:0   alpha:1.0],
                                                 [NSColor colorWithDeviceRed:0.2 green:1.0 blue:0   alpha:1.0],
                                                 [NSColor colorWithDeviceRed:0   green:0.6 blue:1.0 alpha:1.0],
                                                 [NSColor colorWithDeviceRed:0.4 green:0.2 blue:1.0 alpha:1.0],
                                                 nil];
        }
        
    #ifdef NC_PROGRESS_INDICATOR_SIMBL_PLUGIN
        NSBundle* bundle = [NSBundle bundleWithIdentifier:@"com.buckleyisms.NCProgressIndicatorSIMBL"];
    #else
        NSBundle* bundle = [NSBundle bundleWithIdentifier:@"com.buckleyisms.NCProgressIndicator"];
    #endif
        
        
        if (bundle)
        {
            NSImage* regularCatSprites[kNCProgressIndicatorNumRegularCatSprites];
            NSImage* starSprites[kNCProgressIndicatorNumStarSprites];
            
            if (sNCProgressIndicatorRegularCatSprites == nil)
            {
                for (NSUInteger i = 0; i < kNCProgressIndicatorNumRegularCatSprites; ++i)
                {
                    NSString* imageName = [NSString stringWithFormat:@"ptc_small%d", i + 1];
                    regularCatSprites[i] = [[NSImage alloc] initWithContentsOfURL:[bundle URLForResource:imageName withExtension:@"png"]];
                    [regularCatSprites[i] setFlipped:YES];
                }
                
                sNCProgressIndicatorRegularCatSprites = [[NSArray alloc] initWithObjects:regularCatSprites
                                                                                   count:kNCProgressIndicatorNumRegularCatSprites];
            
                for (NSUInteger i = 0; i < kNCProgressIndicatorNumRegularCatSprites; ++i)
                {
                    [regularCatSprites[i] release];
                }
                
            }
            
            if (sNCProgressIndicatorStarSprites == nil)
            {
                for (NSUInteger i = 0; i < kNCProgressIndicatorNumStarSprites; ++i)
                {
                    NSString* imageName = [NSString stringWithFormat:@"star%d", i + 1];
                    starSprites[i] = [[NSImage alloc] initWithContentsOfURL:[bundle URLForResource:imageName withExtension:@"png"]];
                    [starSprites[i] setFlipped:YES];
                }
                
                sNCProgressIndicatorStarSprites = [[NSArray alloc] initWithObjects:starSprites
                                                                             count:kNCProgressIndicatorNumStarSprites];
                
                for (NSUInteger i = 0; i < kNCProgressIndicatorNumStarSprites; ++i)
                {
                    [starSprites[i] release];
                }
            }
            
            if (sNCProgressIndicatorSmallCatSprites == nil)
            {
                NSImage* smallHead = [[NSImage alloc] initWithContentsOfURL:
                                      [bundle URLForResource:@"ptc_small_head" withExtension:@"png"]];
                
                [smallHead setFlipped:YES];
                
                sNCProgressIndicatorSmallCatSprites = [[NSArray alloc] initWithObjects:&smallHead count:1];
                
                [smallHead release];
            }
        }
    }
    
    [self sizeToFit];
        
    if ([self usesThreadedAnimation])
    {
        [self NC_PROGRESS_INDICATOR_METHOD(startAnimationThreadIfNeeded)];
    }
    else
    {
        [self NC_PROGRESS_INDICATOR_METHOD(startAnimationTimerIfNeeded)];
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(startAnimationTimerIfNeeded)
{
    if ([self NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)])
    {
        @synchronized([NCProgressIndicatorTimer class])
        {
            if (sNCProgressIndicatorAnimationTimer == nil)
            {
                sNCProgressIndicatorAnimationTimer = [[NCProgressIndicatorTimer alloc] init];
            }
            
            [sNCProgressIndicatorAnimationTimer addView:self];
        }
        
        [sNCProgressIndicatorAnimationThread removeView:self];
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(startAnimationThreadIfNeeded)
{
    if ([self NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)])
    {
        @synchronized([NCProgressIndicatorThread class])
        {
            if (sNCProgressIndicatorAnimationThread  == nil)
            {
                sNCProgressIndicatorAnimationThread = [[NCProgressIndicatorThread alloc] init];
            }
            
            [sNCProgressIndicatorAnimationThread addView:self];
        }
        
        [sNCProgressIndicatorAnimationTimer removeView:self];
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(setUsesThreadedAnimation:(BOOL)threadedAnimation)
{
    NC_PROGRESS_INDICATOR_SUPER_CALL(setUsesThreadedAnimation:threadedAnimation);
    
    if (threadedAnimation)
    {
        [self NC_PROGRESS_INDICATOR_METHOD(startAnimationThreadIfNeeded)];
    }
    else
    {
        [self NC_PROGRESS_INDICATOR_METHOD(startAnimationTimerIfNeeded)];
    }
}

- (BOOL)NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)
{
    return [self style] == NSProgressIndicatorBarStyle;
}

- (BOOL)NC_PROGRESS_INDICATOR_METHOD(bouncesRainbow)
{
    return [self style] == NSProgressIndicatorBarStyle && [self controlSize] == NSRegularControlSize;
}

- (BOOL)NC_PROGRESS_INDICATOR_METHOD(shouldResize)
{
    return [self style] == NSProgressIndicatorBarStyle && [self controlSize] == NSRegularControlSize;
}

- (void)NC_PROGRESS_INDICATOR_METHOD(sizeToFit)
{
    if ([self NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)] && [self NC_PROGRESS_INDICATOR_METHOD(shouldResize)])
    {
        NSRect frame = [self frame];
        frame.size.height = kNCProgressIndicatorRegularBarHeight;
        [self setFrame:frame];
        
        frame.origin.x = 0;
        frame.origin.y = 0;
        [self setBounds:frame];
    }
    else if (![self NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)])
    {
        [sNCProgressIndicatorAnimationTimer  removeView:self];
        [sNCProgressIndicatorAnimationThread removeView:self];
    }
}

- (double)NC_PROGRESS_INDICATOR_METHOD(percentValue)
{
    if ([self isIndeterminate])
    {
        return 1.0;
    }
    else
    {
        return ([self doubleValue] - [self minValue]) / ([self maxValue] - [self minValue]);
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(startAnimation:(id)sender)
{
    if (![self NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)])
    {
        NC_PROGRESS_INDICATOR_SUPER_CALL(startAnimation:sender);
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(stopAnimation:(id)sender)
{
    if (![self NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)])
    {
        NC_PROGRESS_INDICATOR_SUPER_CALL(stopAnimation:sender);
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(drawRect:(NSRect)dirtyRect)
{
    if (sNCProgressIndicatorAnimationThread      == nil
        || sNCProgressIndicatorAnimationTimer    == nil
        || sNCProgressIndicatorStarSprites       == nil
        || sNCProgressIndicatorRegularCatSprites == nil
        || sNCProgressIndicatorSmallCatSprites   == nil
        || sNCProgressIndicatorRainbowColors     == nil)
    {
        [self NC_PROGRESS_INDICATOR_METHOD(setup)];
    }
    
    if ([self NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)])
    {
        [NSGraphicsContext saveGraphicsState];
                
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
        
        [[NSBezierPath bezierPathWithRect:dirtyRect] addClip];
        
        NSUInteger frameCount = 0;
        
        if ([self usesThreadedAnimation])
        {
            frameCount = sNCProgressIndicatorThreadFrameCount;
        }
        else
        {
            frameCount = sNCProgressIndicatorTimerFrameCount;
        }
        
        [self NC_PROGRESS_INDICATOR_METHOD(drawBackground:dirtyRect frameCount:frameCount)];
        [self NC_PROGRESS_INDICATOR_METHOD(drawRainbow:dirtyRect frameCount:frameCount)];
        [self NC_PROGRESS_INDICATOR_METHOD(drawStars:dirtyRect frameCount:frameCount)];
        [self NC_PROGRESS_INDICATOR_METHOD(drawSprite:dirtyRect frameCount:frameCount)];
                        
        [NSGraphicsContext restoreGraphicsState];
    }
    else
    {
        NC_PROGRESS_INDICATOR_SUPER_CALL(drawRect:dirtyRect);
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(drawBackground:(NSRect)dirtyRect frameCount:(NSUInteger)frameCount)
{
    NSColor* backgroundColor = [NSColor colorWithDeviceRed:0 green:0.2 blue:0.4 alpha:1.0];
    [backgroundColor set];
    
    [NSBezierPath fillRect:[self bounds]];
}

- (void)NC_PROGRESS_INDICATOR_METHOD(drawStars:(NSRect)dirtyRect frameCount:(NSUInteger)frameCount)
{
    if (sNCProgressIndicatorStarSprites != nil && [sNCProgressIndicatorStarSprites count] > 0)
    {
        BOOL bottom            = YES;    
        NSImage* bottomSprite  = [sNCProgressIndicatorStarSprites objectAtIndex:
                                  frameCount % [sNCProgressIndicatorStarSprites count]];
        NSImage* topSprite     = [sNCProgressIndicatorStarSprites objectAtIndex:
                                  (frameCount + (kNCProgressIndicatorNumStarSprites / 2)) % [sNCProgressIndicatorStarSprites count]];
        
        CGFloat x              = 0 - kNCProgressIndicatorStarSpeed * (frameCount % [sNCProgressIndicatorStarSprites count]);
        CGFloat bottomY        = [self bounds].size.height - [bottomSprite size].height - 1;
        CGFloat topY           = 1;
        
        while (x <= [self bounds].size.width)
        {
            if (bottom)
            {
                [bottomSprite drawAtPoint:NSMakePoint(x, bottomY)
                                 fromRect:NSZeroRect
                                operation:NSCompositeSourceOver
                                 fraction:1.0];
            }
            else
            {
                [topSprite drawAtPoint:NSMakePoint(x, topY)
                              fromRect:NSZeroRect
                             operation:NSCompositeSourceOver
                              fraction:1.0];
            }
            
            x += kNCProgressIndicatorStarDistance;
            bottom = !bottom;
        }
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(drawRainbow:(NSRect)dirtyRect frameCount:(NSUInteger)frameCount)
{
    if (sNCProgressIndicatorRainbowColors != nil && [sNCProgressIndicatorRainbowColors count] > 0)
    {
        CGFloat rainbowStipeHeight = floor([self bounds].size.height / [sNCProgressIndicatorRainbowColors count]);
        CGFloat rightEdge          = floor([self NC_PROGRESS_INDICATOR_METHOD(percentValue)] * [self bounds].size.width - kNCProgressIndicatorRainbowSegmentWidth);
        
        if ([self controlSize] == NSSmallControlSize)
        {
            rightEdge -= kNCProgressIndicatorSmallRainbowOffset;
        }
        else
        {
            rightEdge -= kNCProgressIndicatorRegularRainbowOffset;
        }
        
        BOOL offsetColumn = frameCount % kNCProgressIndicatorRainbowPeriod >= kNCProgressIndicatorRainbowPeriod / 2;
        
        NSInteger stripeColorIndex = 0;
        
        if ([self isIndeterminate])
        {
            stripeColorIndex = [sNCProgressIndicatorRainbowColors count] - ((frameCount / 2) % [sNCProgressIndicatorRainbowColors count]);
            
            if (stripeColorIndex == [sNCProgressIndicatorRainbowColors count])
            {
                stripeColorIndex = 0;
            }
        }
        
        while (rightEdge > 0)
        {
            for (NSInteger row = 0; row < [sNCProgressIndicatorRainbowColors count]; ++ row)
            {
                NSRect stripe = NSMakeRect(rightEdge - kNCProgressIndicatorRainbowSegmentWidth,
                                           row * rainbowStipeHeight,
                                           kNCProgressIndicatorRainbowSegmentWidth,
                                           rainbowStipeHeight);
                
                if ([self NC_PROGRESS_INDICATOR_METHOD(shouldResize)])
                {
                    stripe.origin.y += 1;
                }
                
                if ([self NC_PROGRESS_INDICATOR_METHOD(bouncesRainbow)] && offsetColumn)
                {
                    stripe.origin.y += 1;
                }
                
                [[sNCProgressIndicatorRainbowColors objectAtIndex:stripeColorIndex] set];
                [NSBezierPath fillRect:stripe];
                
                stripeColorIndex = (stripeColorIndex + 1) % [sNCProgressIndicatorRainbowColors count];
            }
                    
            rightEdge -= kNCProgressIndicatorRainbowSegmentWidth;
            offsetColumn = !offsetColumn;
        }
    }
}

- (void)NC_PROGRESS_INDICATOR_METHOD(drawSprite:(NSRect)dirtyRect frameCount:(NSUInteger)frameCount)
{
    NSArray* catSprites = nil;
    
    if ([self controlSize] == NSRegularControlSize)
    {
        catSprites = sNCProgressIndicatorRegularCatSprites;
    }
    else
    {
        catSprites = sNCProgressIndicatorSmallCatSprites;
    }
    
    if (catSprites != nil && [catSprites count] > 0)
    {
        NSImage* sprite = [catSprites objectAtIndex:frameCount % [catSprites count]];
        
        [sprite drawAtPoint:NSMakePoint(floor([self NC_PROGRESS_INDICATOR_METHOD(percentValue)] * [self bounds].size.width - [sprite size].width), 0)
                   fromRect:NSZeroRect
                  operation:NSCompositeSourceOver
                   fraction:1.0];
    }
}

- (BOOL)NC_PROGRESS_INDICATOR_METHOD(isFlipped)
{
    return YES;
}

#ifdef NC_PROGRESS_INDICATOR_SIMBL_PLUGIN

+ (void)load
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    BOOL succeeded = YES;
    
    succeeded = class_addMethod([NSProgressIndicator class],
                                @selector(NC_PROGRESS_INDICATOR_METHOD(setup)),
                                class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(setup))),
                                "v@:");
    
    succeeded = class_addMethod([NSProgressIndicator class],
                                @selector(NC_PROGRESS_INDICATOR_METHOD(startAnimationTimerIfNeeded)),
                                class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(startAnimationTimerIfNeeded))),
                                "v@:");
    
    succeeded = class_addMethod([NSProgressIndicator class],
                                @selector(NC_PROGRESS_INDICATOR_METHOD(startAnimationThreadIfNeeded)),
                                class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(startAnimationThreadIfNeeded))),
                                "v@:");
    
    succeeded = class_addMethod([NSProgressIndicator class],
                                @selector(NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle)),
                                class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(drawsSizeAndStyle))),
                                "B@:");
    
    succeeded = class_addMethod([NSProgressIndicator class],
                                @selector(NC_PROGRESS_INDICATOR_METHOD(shouldResize)),
                                class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(shouldResize))),
                                "B@:");
    
    succeeded = class_addMethod([NSProgressIndicator class],
                                @selector(NC_PROGRESS_INDICATOR_METHOD(bouncesRainbow)),
                                class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(bouncesRainbow))),
                                "B@:");
    
    succeeded = class_addMethod([NSProgressIndicator class],
                                @selector(NC_PROGRESS_INDICATOR_METHOD(percentValue)),
                                class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(percentValue))),
                                "d@:");
    
    char* nsRectType     = { 0 };
    char  types[37]      = { 0 };
    if (sizeof(CGFloat) == sizeof(double))
    {
        nsRectType = "{NSRect={CGPoint=dd}{CGSize=dd}}";
    }
    else
    {
        nsRectType = "{NSRect={CGPoint=ff}{CGSize=ff}}";
    }
    
    sprintf(types, "v@:%s", nsRectType);
    
    if (sizeof(NSUInteger) == sizeof(unsigned int))
    {
        types[35] = 'I';
    }
    else
    {
        types[35] = 'L';
    }
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(drawBackground:frameCount:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(drawBackground:frameCount:))),
                                             types);
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(drawRainbow:frameCount:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(drawRainbow:frameCount:))),
                                             types);
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(drawStars:frameCount:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(drawStars:frameCount:))),
                                             types);
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(drawSprite:frameCount:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(drawSprite:frameCount:))),
                                             types);
    
    types[35] = '\0';
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(initWithCoder:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(initWithCoder:))),
                                             "v@:@");
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(dealloc)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(dealloc))),
                                             "v@:");
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(setUsesThreadedAnimation:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(setUsesThreadedAnimation:))),
                                             "v@:B");
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(sizeToFit)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(sizeToFit))),
                                             "v@:");
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(startAnimation:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(startAnimation:))),
                                             "v@:@");
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(stopAnimation:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(stopAnimation:))),
                                             "v@:@");
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(drawRect:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(drawRect:))),
                                             types);
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(isFlipped)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(isFlipped))),
                                             "v@:");
    
    types[0] = '@';
    
    succeeded = succeeded && class_addMethod([NSProgressIndicator class],
                                             @selector(NC_PROGRESS_INDICATOR_METHOD(initWithFrame:)),
                                             class_getMethodImplementation(self, @selector(NC_PROGRESS_INDICATOR_METHOD(initWithFrame:))),
                                             types);
    
    if (succeeded)
    {
        NSArray* unswizzledSelectors = [[NSArray alloc] initWithObjects:[NSValue valueWithPointer:@selector(initWithFrame:)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(initWithFrame:))],
                                        [NSValue valueWithPointer:@selector(initWithCoder:)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(initWithCoder:))],
                                        [NSValue valueWithPointer:@selector(dealloc)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(dealloc))],
                                        [NSValue valueWithPointer:@selector(setUsesThreadedAnimation:)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(setUsesThreadedAnimation:))],
                                        [NSValue valueWithPointer:@selector(sizeToFit)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(sizeToFit))],
                                        [NSValue valueWithPointer:@selector(startAnimation:)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(startAnimation:))],
                                        [NSValue valueWithPointer:@selector(stopAnimation:)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(stopAnimation:))],
                                        [NSValue valueWithPointer:@selector(drawRect:)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(drawRect:))],
                                        [NSValue valueWithPointer:@selector(isFlipped)],
                                        [NSValue valueWithPointer:@selector(NC_PROGRESS_INDICATOR_METHOD(isFlipped))],
                                        nil];
        
        NSMutableArray* swizzledSelectors = [[NSMutableArray alloc] initWithCapacity:18];
        
        for (NSUInteger i = 0; i < [unswizzledSelectors count] && succeeded; i += 2)
        {
            NSError* error = nil;
            succeeded = [NSProgressIndicator jr_swizzleMethod:[[unswizzledSelectors objectAtIndex:i] pointerValue]
                                                   withMethod:[[unswizzledSelectors objectAtIndex:i + 1] pointerValue]
                                                        error:nil];
            
            if (error != nil)
            {
                NSLog(@"%@", [error localizedDescription]);
            }
            
            if (succeeded)
            {
                [swizzledSelectors addObject:[unswizzledSelectors objectAtIndex:i + 1]];
                [swizzledSelectors addObject:[unswizzledSelectors objectAtIndex:i]];
            }
        }
        
        if (!succeeded)
        {
            for (NSUInteger i = 0; i < [swizzledSelectors count] && succeeded; i += 2)
            {
                NSError* error = nil;
                [NSProgressIndicator jr_swizzleMethod:[[swizzledSelectors objectAtIndex:i] pointerValue]
                                           withMethod:[[swizzledSelectors objectAtIndex:i + 1] pointerValue]
                                                error:nil];
                
                if (error != nil)
                {
                    NSLog(@"%@", [error localizedDescription]);
                }
            }
        }
        
        [unswizzledSelectors release];
        [swizzledSelectors   release];
    }
    
    [pool drain];
}

#endif

@end
