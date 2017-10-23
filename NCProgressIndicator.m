/* Copyright (c) 2011-2017 Michael Buckley
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

#import "NCProgressIndicator.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSProgressIndicator ()

@property (nonatomic, readonly, assign) BOOL overridesDrawing;
@property (nonatomic, readonly, assign) BOOL bouncesRainbow;
@property (nonatomic, readonly, assign) BOOL shouldResize;
@property (nonatomic, readwrite, assign, getter=isAnimating) BOOL animating;
@property (nonatomic, readwrite, assign) NSInteger occulsionCount;
@property (nonatomic, readonly, assign) double percentValue;

@property (class, nonatomic, readonly) NSBundle* bundle;
@property (class, nonatomic, readonly) NSArray<NSImage*>* starSprites;
@property (class, nonatomic, readonly) NSArray<NSImage*>* regularCatSprites;
@property (class, nonatomic, readonly) NSArray<NSImage*>* smallCatSprites;
@property (class, nonatomic, readonly) NSArray<NSColor*>* rainbowColors;
@property (class, nonatomic, readonly) dispatch_queue_t queue;
@property (class, nonatomic, readonly) dispatch_source_t animationTimer;
@property (class, nonatomic, readonly) NSUInteger frameNum;
@property (class, nonatomic, readonly) NSMutableSet<NCProgressIndicator*>* animatingViews;

@end

const NSInteger      kNCProgressIndicatorFrameDelay           = 0.07 * NSEC_PER_SEC;
const CGFloat        kNCProgressIndicatorRegularBarHeight     = 20.0;
const CGFloat        kNCProgressIndicatorRainbowSegmentWidth  = 9.0;
const CGFloat        kNCProgressIndicatorStarSpeed            = 6.0;
const CGFloat        kNCProgressIndicatorStarDistance         = 18.0;
const NSUInteger     kNCProgressIndicatorNumRegularCatSprites = 6;
const NSUInteger     kNCProgressIndicatorRainbowPeriod        = 4;
const CGFloat        kNCProgressIndicatorRegularRainbowOffset = 16.0;
const CGFloat        kNCProgressIndicatorSmallRainbowOffset   = 3.0;

static NSUInteger sNCProgressIndicatorFrameNum = 0;

static dispatch_queue_t animationTimerQueue;
static dispatch_source_t animationTimer;

@implementation NCProgressIndicator

@dynamic overridesDrawing;
@dynamic bouncesRainbow;
@dynamic shouldResize;
@dynamic percentValue;

@synthesize animating;
@synthesize occulsionCount;

- (void)dealloc
{
    [self stopAnimation:self];
}

#pragma mark - Class methods

+ (NSBundle*)bundle
{
    static dispatch_once_t onceToken = 0;
    static NSBundle* bundle = nil;

    dispatch_once(&onceToken, ^{
        bundle = [NSBundle bundleWithIdentifier:@"com.buckleyisms.NCProgressIndicator"];
    });

    return bundle;
}

+ (NSArray<NSImage*>*)starSprites
{
    static dispatch_once_t onceToken = 0;
    static NSArray<NSImage*>* starSprites = nil;

    dispatch_once(&onceToken, ^
    {
        starSprites = @[[self.bundle imageForResource:@"star1"],
                        [self.bundle imageForResource:@"star2"],
                        [self.bundle imageForResource:@"star3"],
                        [self.bundle imageForResource:@"star4"],
                        [self.bundle imageForResource:@"star5"],
                        [self.bundle imageForResource:@"star6"]];
    });

    return starSprites;
}

+ (NSArray<NSImage*>*)regularCatSprites
{
    static dispatch_once_t onceToken = 0;
    static NSArray<NSImage*>* catSprites = nil;

    dispatch_once(&onceToken, ^
    {
        catSprites = @[[self.bundle imageForResource:@"ptc_small1"],
                       [self.bundle imageForResource:@"ptc_small2"],
                       [self.bundle imageForResource:@"ptc_small3"],
                       [self.bundle imageForResource:@"ptc_small4"],
                       [self.bundle imageForResource:@"ptc_small5"],
                       [self.bundle imageForResource:@"ptc_small6"]];
    });

    return catSprites;
}

+ (NSArray<NSImage*>*)smallCatSprites
{
    static dispatch_once_t onceToken = 0;
    static NSArray<NSImage*>* catSprites = nil;

    dispatch_once(&onceToken, ^
    {
        catSprites = @[[self.bundle imageForResource:@"ptc_small_head"]];
    });

    return catSprites;
}

+ (NSArray<NSColor*>*)rainbowColors
{
    static dispatch_once_t onceToken = 0;
    static NSArray<NSColor*>* rainbowColors = nil;

    dispatch_once(&onceToken, ^{
        rainbowColors = @[[NSColor colorWithDeviceRed:1.0 green:0   blue:0   alpha:1.0],
                          [NSColor colorWithDeviceRed:1.0 green:0.6 blue:0   alpha:1.0],
                          [NSColor colorWithDeviceRed:1.0 green:1.0 blue:0   alpha:1.0],
                          [NSColor colorWithDeviceRed:0.2 green:1.0 blue:0   alpha:1.0],
                          [NSColor colorWithDeviceRed:0   green:0.6 blue:1.0 alpha:1.0],
                          [NSColor colorWithDeviceRed:0.4 green:0.2 blue:1.0 alpha:1.0]];
    });

    return rainbowColors;
}

+ (dispatch_queue_t)queue
{
    static dispatch_once_t onceToken = 0;
    static dispatch_queue_t queue;

    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.buckleyisms.NCProgressIndicator.queue", DISPATCH_QUEUE_SERIAL);
    });

    return queue;
}

+ (dispatch_source_t)animationTimer
{
    static dispatch_once_t onceToken = 0;

    dispatch_once(&onceToken, ^{
        animationTimerQueue = dispatch_queue_create("com.buckleyisms.NCProgressIndicator.timer", DISPATCH_QUEUE_SERIAL);
        animationTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, animationTimerQueue);

        dispatch_source_set_timer(animationTimer,
                                  dispatch_time(DISPATCH_TIME_NOW, kNCProgressIndicatorFrameDelay),
                                  kNCProgressIndicatorFrameDelay,
                                  0);

        dispatch_source_set_event_handler(animationTimer, ^
        {
            dispatch_async(self.class.queue, ^
            {
                ++sNCProgressIndicatorFrameNum;

                for (NCProgressIndicator* view in self.animatingViews)
                {
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        view.needsDisplay = YES;
                    });
                }
            });
        });
    });

    return animationTimer;
}

+ (NSUInteger)frameNum
{
    __block NSUInteger frameNum = 0;

    dispatch_sync(self.queue, ^
    {
        frameNum = sNCProgressIndicatorFrameNum;
    });

    return frameNum;
}

+ (NSMutableSet<NCProgressIndicator*>*)animatingViews
{
    static dispatch_once_t onceToken = 0;
    static NSMutableSet<NCProgressIndicator*>* animatingViews = nil;

    dispatch_once(&onceToken, ^
    {
        animatingViews = [NSMutableSet new];
    });

    return animatingViews;
}

#pragma mark - Animation

- (void)viewWillMoveToWindow:(nullable NSWindow*)newWindow
{
    NSNotificationCenter* nc = NSNotificationCenter.defaultCenter;

    [nc removeObserver:self name:NSWindowDidChangeOcclusionStateNotification object:self.window];

    [nc addObserver:self
           selector:@selector(occulsionChanged:)
               name:NSWindowDidChangeOcclusionStateNotification
             object:newWindow];
}

- (void)occulsionChanged:(NSNotification*)notification
{
    if (self.window.occlusionState & NSWindowOcclusionStateVisible)
    {
        if (self.occulsionCount > 0)
        {
            [self startAnimation:self];
            self.occulsionCount = 0;
        }
    }
    else if (self.isAnimating)
    {
        // After this method returns, Appkit will immediately call
        // -stopAnimation:, which will decrement this to 1. If the user calls
        // -stopAnimation while the window is still occluded, it will be
        // decremented again, so we don't restart the animation when the window
        // becomes visible again.
        self.occulsionCount = 2;
    }
}

- (void)startAnimation:(nullable id)sender
{
    self.animating = YES;

    if (self.overridesDrawing)
    {
        dispatch_async(self.class.queue, ^
                       {
                           if (![self.class.animatingViews containsObject: self])
                           {
                               [self.class.animatingViews addObject: self];

                               if (self.class.animatingViews.count == 1)
                               {
                                   dispatch_resume(self.class.animationTimer);
                               }
                           }
                       });
    }
    else
    {
        [super startAnimation:sender];
    }
}

- (void)stopAnimation:(nullable id)sender
{
    self.animating = NO;

    if (self.overridesDrawing)
    {
        if (self.occulsionCount > 0)
        {
            --self.occulsionCount;
        }

        dispatch_async(self.class.queue, ^
                       {
                           [self.class.animatingViews removeObject: self];

                           if (self.class.animatingViews.count == 0)
                           {
                               dispatch_suspend(self.class.animationTimer);
                           }
                       });
    }
    else
    {
        [super stopAnimation:sender];
    }
}


#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.overridesDrawing)
    {
        [NSGraphicsContext saveGraphicsState];
                
        [NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationNone;
        
        [[NSBezierPath bezierPathWithRect:dirtyRect] addClip];
        
        NSUInteger frameNum = self.class.frameNum;
        
        [self drawBackground:dirtyRect frameNum:frameNum];
        [self drawRainbow:dirtyRect frameNum:frameNum];
        [self drawStars:dirtyRect frameNum:frameNum];
        [self drawSprite:dirtyRect frameNum:frameNum];
                        
        [NSGraphicsContext restoreGraphicsState];
    }
    else
    {
        [super drawRect:dirtyRect];
    }
}

- (void)drawBackground:(NSRect)dirtyRect frameNum:(NSUInteger)frameNum
{
    NSColor *backgroundColor = [NSColor colorWithDeviceRed:0 green:0.2 blue:0.4 alpha:1.0];
    [backgroundColor set];
    
    [NSBezierPath fillRect:self.bounds];
}

- (void)drawStars:(NSRect)dirtyRect frameNum:(NSUInteger)frameNum
{
    if (self.class.starSprites.count > 0)
    {
        BOOL bottom            = YES;    
        NSImage *bottomSprite  = self.class.starSprites[frameNum % self.class.starSprites.count];
        NSImage *topSprite     = self.class.starSprites[(frameNum + (self.class.starSprites.count / 2)) % self.class.starSprites.count];
        
        CGFloat x              = 0 - kNCProgressIndicatorStarSpeed * (frameNum % self.class.starSprites.count);
        CGFloat bottomY        = self.bounds.size.height - bottomSprite.size.height - 1;
        CGFloat topY           = 1;
        
        while (x <= self.bounds.size.width)
        {
            if (bottom)
            {
                [bottomSprite drawAtPoint:NSMakePoint(x, bottomY)
                                 fromRect:NSZeroRect
                                operation:NSCompositingOperationSourceOver
                                 fraction:1.0];
            }
            else
            {
                [topSprite drawAtPoint:NSMakePoint(x, topY)
                              fromRect:NSZeroRect
                             operation:NSCompositingOperationSourceOver
                              fraction:1.0];
            }
            
            x += kNCProgressIndicatorStarDistance;
            bottom = !bottom;
        }
    }
}

- (void)drawRainbow:(NSRect)dirtyRect frameNum:(NSUInteger)frameNum
{
    if (self.class.rainbowColors.count > 0)
    {
        CGFloat rainbowStipeHeight = floor(self.bounds.size.height / self.class.rainbowColors.count);
        CGFloat rightEdge          = floor(self.percentValue * self.bounds.size.width - kNCProgressIndicatorRainbowSegmentWidth);
        
        if (self.controlSize == NSControlSizeSmall)
        {
            rightEdge -= kNCProgressIndicatorSmallRainbowOffset;
        }
        else
        {
            rightEdge -= kNCProgressIndicatorRegularRainbowOffset;
        }
        
        BOOL offsetColumn = frameNum % kNCProgressIndicatorRainbowPeriod >= kNCProgressIndicatorRainbowPeriod / 2;
        
        NSInteger stripeColorIndex = 0;
        
        if (self.indeterminate)
        {
            stripeColorIndex = self.class.rainbowColors.count - ((frameNum / 2) % self.class.rainbowColors.count);
            
            if (stripeColorIndex == self.class.rainbowColors.count)
            {
                stripeColorIndex = 0;
            }
        }
        
        while (rightEdge > 0)
        {
            for (NSInteger row = 0; row < self.class.rainbowColors.count; ++ row)
            {
                NSRect stripe = NSMakeRect(rightEdge - kNCProgressIndicatorRainbowSegmentWidth,
                                           row * rainbowStipeHeight,
                                           kNCProgressIndicatorRainbowSegmentWidth,
                                           rainbowStipeHeight);
                
                if (self.shouldResize)
                {
                    stripe.origin.y += 1;
                }
                
                if (self.bouncesRainbow && offsetColumn)
                {
                    stripe.origin.y += 1;
                }
                
                [(NSColor *) self.class.rainbowColors[stripeColorIndex] set];
                [NSBezierPath fillRect:stripe];
                
                stripeColorIndex = (stripeColorIndex + 1) % self.class.rainbowColors.count;
            }
                    
            rightEdge -= kNCProgressIndicatorRainbowSegmentWidth;
            offsetColumn = !offsetColumn;
        }
    }
}

- (void)drawSprite:(NSRect)dirtyRect frameNum:(NSUInteger)frameNum
{
    NSArray<NSImage*>* catSprites = nil;
    
    if (self.controlSize == NSControlSizeRegular)
    {
        catSprites = self.class.regularCatSprites;
    }
    else
    {
        catSprites = self.class.smallCatSprites;
    }
    
    if (catSprites != nil && catSprites.count > 0)
    {
        NSImage *sprite = catSprites[frameNum % catSprites.count];

        NSRect target = NSMakeRect(floor(self.percentValue * self.bounds.size.width - sprite.size.width),
                                   0,
                                   sprite.size.width,
                                   sprite.size.height);

        [sprite drawInRect:target
                  fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
                  fraction:1.0
            respectFlipped:YES
                     hints:nil];
    }
}

- (BOOL)overridesDrawing
{
    return self.style == NSProgressIndicatorBarStyle;
}

- (BOOL)bouncesRainbow
{
    return self.style == NSProgressIndicatorBarStyle && self.controlSize == NSControlSizeRegular;
}

- (BOOL)shouldResize
{
    return self.style == NSProgressIndicatorBarStyle && self.controlSize == NSControlSizeRegular;
}

#pragma mark - NSProgressIndicator Accessors

- (double)percentValue
{
    if (self.indeterminate)
    {
        return 1.0;
    }
    else
    {
        return (self.doubleValue - self.minValue) / (self.maxValue - self.minValue);
    }
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)setControlSize:(NSControlSize)controlSize
{
    if (self.isAnimating)
    {
        [self stopAnimation:nil];
        [super setControlSize:controlSize];
        [self startAnimation:nil];
    }
    else
    {
        [super setControlSize:controlSize];
    }
}

@end

NS_ASSUME_NONNULL_END
