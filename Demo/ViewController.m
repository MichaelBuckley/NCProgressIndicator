//
//  ViewController.m
//  Demo
//
//  Created by Buckley on 8/22/16.
//
//

#import "ViewController.h"

@interface ViewController ()
@property (nonatomic, readwrite, strong) NSTimer *timer;
@property (nonatomic, readwrite, assign) IBOutlet NSProgressIndicator* progressBar;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self restart:self];
}

- (void)animate
{
    self.progressBar.doubleValue += 1.0;

    if (self.progressBar.doubleValue >= 100.0)
    {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (IBAction)restart:(id)sender
{
    if (self.timer != nil)
    {
        [self.timer invalidate];
    }

    self.progressBar.doubleValue = 0.0f;

    self.progressBar.usesThreadedAnimation = YES;

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 24.0
                                                  target:self
                                                selector:@selector(animate)
                                                userInfo:nil
                                                 repeats:YES];
}

@end
