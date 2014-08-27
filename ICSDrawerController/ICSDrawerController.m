//
//  ICSDrawerController.m
//
//  Created by Vito Modena
//
//  Copyright (c) 2014 ice cream studios s.r.l. - http://icecreamstudios.com
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "ICSDrawerController.h"

static const CGFloat kICSDrawerControllerDrawerDepth = 260.0f;
static const CGFloat kICSDrawerControllerSlideViewInitialOffset = -60.0f;
static const NSTimeInterval kICSDrawerControllerAnimationDuration = 0.5;
static const CGFloat kICSDrawerControllerOpeningAnimationSpringDamping = 0.7f;
static const CGFloat kICSDrawerControllerOpeningAnimationSpringDampingNone = 1;
static const CGFloat kICSDrawerControllerOpeningAnimationSpringInitialVelocity = 0.1f;
static const CGFloat kICSDrawerControllerClosingAnimationSpringDamping = 1.0f;
static const CGFloat kICSDrawerControllerClosingAnimationSpringInitialVelocity = 0.5f;
static const CGFloat kICSDrawerControllerDefaultShadowAlpha = 0.7f;

typedef NS_ENUM(NSUInteger, ICSDrawerControllerState)
{
    ICSDrawerControllerStateClosed = 0,
    ICSDrawerControllerStateOpening,
    ICSDrawerControllerStateOpen,
    ICSDrawerControllerStateClosing
};


@interface ICSDrawerController () <UIGestureRecognizerDelegate>

@property (nonatomic) float slideOffset;

@property(nonatomic, strong, readwrite) UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *leftViewController;
@property(nonatomic, strong, readwrite) UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *rightViewController;
@property(nonatomic, strong, readwrite) UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *topViewController;
@property(nonatomic, strong, readwrite) UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *bottomViewController;
@property(nonatomic, strong, readwrite) UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *centerViewController;

@property(nonatomic, strong) UIView *slideView;
@property(nonatomic, strong) UIView *centerView;

@property(nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;
@property(nonatomic, strong) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, assign) CGPoint panGestureStartLocation;

@property(nonatomic, assign) ICSDrawerControllerState drawerState;

@end



@implementation ICSDrawerController
{
    ICSDrawerControllerDirection    _currentOpenDirection;
    NSMutableDictionary             *_slideOffsetForDirections;
    UIView      *_statusBarView;
}

- (CGFloat)slideOffset {
    if(_currentOpenDirection == 0) return kICSDrawerControllerDrawerDepth;
    return [_slideOffsetForDirections[@(_currentOpenDirection)] floatValue];
}

- (void)setEnableGestures:(BOOL)enableGestures {
    self.tapGestureRecognizer.enabled = enableGestures;
    self.panGestureRecognizer.enabled = enableGestures;
}

- (id)initWithCenterViewController:(UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *)centerViewController
{
    NSParameterAssert(centerViewController);
    
    self = [super init];
    if (self) {
        _slideOffsetForDirections = [[NSMutableDictionary alloc] init];
        _slideOffsetForDirections[@(ICSDrawerControllerDirectionLeft)] = @(kICSDrawerControllerDrawerDepth);
        _slideOffsetForDirections[@(ICSDrawerControllerDirectionRight)] = @(kICSDrawerControllerDrawerDepth);
        _slideOffsetForDirections[@(ICSDrawerControllerDirectionTop)] = @(kICSDrawerControllerDrawerDepth);
        _slideOffsetForDirections[@(ICSDrawerControllerDirectionBottom)] = @(kICSDrawerControllerDrawerDepth);
        _currentOpenDirection = 0;
        self.shadowAlpha = -1;
        _centerViewController = centerViewController;
 
        if ([_centerViewController respondsToSelector:@selector(setDrawer:)]) {
            _centerViewController.drawer = self;
        }

        _statusBarView = [[UIApplication sharedApplication] valueForKey:@"statusBar"];
        _statusBarView.clipsToBounds = YES;
    }

    return self;
}

- (void)setViewController:(UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *)viewController slideOffset:(CGFloat)slideOffset forDirection:(ICSDrawerControllerDirection)direction {
    if ([viewController respondsToSelector:@selector(setDrawer:)]) {
        viewController.drawer = self;
    }
    
    _slideOffsetForDirections[@(direction)] = @(slideOffset);
    
    switch (direction) {
        case ICSDrawerControllerDirectionLeft:
            self.leftViewController = viewController;
            break;
        case ICSDrawerControllerDirectionRight:
            self.rightViewController = viewController;
            break;
        case ICSDrawerControllerDirectionTop:
            self.topViewController = viewController;
            break;
        case ICSDrawerControllerDirectionBottom:
            self.bottomViewController = viewController;
            break;
        default:
            break;
    }
}

- (void)addCenterViewController
{
    NSParameterAssert(self.centerViewController);
    NSParameterAssert(self.centerView);
    
    [self addChildViewController:self.centerViewController];
    self.centerViewController.view.frame = self.view.bounds;
    [self.centerView addSubview:self.centerViewController.view];
    [self.centerViewController didMoveToParentViewController:self];
}

#pragma mark - Managing the view

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    // Initialize left and center view containers
    self.slideView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.centerView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.centerView.layer.shadowOffset = CGSizeZero;
    self.centerView.layer.shadowOpacity = self.shadowAlpha != -1? self.shadowAlpha : kICSDrawerControllerDefaultShadowAlpha;

    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:self.centerView.bounds];
    self.centerView.layer.shadowPath = shadowPath.CGPath;

    self.slideView.autoresizingMask = self.view.autoresizingMask;
    self.centerView.autoresizingMask = self.view.autoresizingMask;
    
    // Add the center view container
    [self.view addSubview:self.centerView];

    // Add the center view controller to the container
    [self addCenterViewController];

    [self setupGestureRecognizers];
}

#pragma mark - Configuring the view’s layout behavior

- (UIViewController *)childViewControllerForStatusBarHidden
{
    NSParameterAssert(self.leftViewController);
    NSParameterAssert(self.centerViewController);
    
    if (self.drawerState == ICSDrawerControllerStateOpening) {
        return self.leftViewController;
    }
    return self.centerViewController;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    NSParameterAssert(self.leftViewController);
    NSParameterAssert(self.centerViewController);
    
    if (self.drawerState == ICSDrawerControllerStateOpening) {
        return self.leftViewController;
    }
    return self.centerViewController;
}

#pragma mark - Gesture recognizers

- (void)setupGestureRecognizers
{
    NSParameterAssert(self.centerView);
    
    self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGestureRecognized:)];
    self.panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGestureRecognized:)];
    self.panGestureRecognizer.maximumNumberOfTouches = 1;
    self.panGestureRecognizer.delegate = self;
    
    [self.centerView addGestureRecognizer:self.panGestureRecognizer];
}

- (void)addClosingGestureRecognizers
{
    NSParameterAssert(self.centerView);
    NSParameterAssert(self.panGestureRecognizer);
    
    [self.centerView addGestureRecognizer:self.tapGestureRecognizer];
}

- (void)removeClosingGestureRecognizers
{
    NSParameterAssert(self.centerView);
    NSParameterAssert(self.panGestureRecognizer);

    [self.centerView removeGestureRecognizer:self.tapGestureRecognizer];
}

#pragma mark Tap to close the drawer
- (void)tapGestureRecognized:(UITapGestureRecognizer *)tapGestureRecognizer
{
    if (tapGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [self close];
    }
}

#pragma mark Pan to open/close the drawer
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    NSParameterAssert([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]);
    CGPoint velocity = [(UIPanGestureRecognizer *)gestureRecognizer velocityInView:self.view];
    
    if (self.drawerState == ICSDrawerControllerStateClosed) {
        if (self.leftViewController && velocity.x > 0.0f) {
            _currentOpenDirection = ICSDrawerControllerDirectionLeft;
            return YES;
        }else if (self.rightViewController && velocity.x < 0.0f) {
            _currentOpenDirection = ICSDrawerControllerDirectionRight;
            return YES;
        }else if (self.topViewController && velocity.y > 0.0f) {
            _currentOpenDirection = ICSDrawerControllerDirectionTop;
            return YES;
        }else if (self.bottomViewController && velocity.x < 0.0f) {
            _currentOpenDirection = ICSDrawerControllerDirectionBottom;
            return YES;
        }
    }
    else if (self.drawerState == ICSDrawerControllerStateOpen) {
        if (_currentOpenDirection == ICSDrawerControllerDirectionLeft && velocity.x < 0.0f) {
            return YES;
        }else if (_currentOpenDirection == ICSDrawerControllerDirectionRight && velocity.x > 0.0f) {
            return YES;
        }else if (_currentOpenDirection == ICSDrawerControllerDirectionTop && velocity.y < 0.0f) {
            return YES;
        }else if (_currentOpenDirection == ICSDrawerControllerDirectionBottom && velocity.x > 0.0f) {
            return YES;
        }
    }
    
    return NO;
}

- (void)panGestureRecognized:(UIPanGestureRecognizer *)panGestureRecognizer
{
    NSParameterAssert(self.slideView);
    NSParameterAssert(self.centerView);
    
    UIGestureRecognizerState state = panGestureRecognizer.state;
    CGPoint location = [panGestureRecognizer locationInView:self.view];
    CGPoint velocity = [panGestureRecognizer velocityInView:self.view];
    
    switch (state) {

        case UIGestureRecognizerStateBegan:
            self.panGestureStartLocation = location;
            if (self.drawerState == ICSDrawerControllerStateClosed) {
                [self willOpen];
            }
            else {
                [self willClose];
            }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            CGFloat delta = 0.0f;
            NSInteger signFlag =( _currentOpenDirection == ICSDrawerControllerDirectionLeft ||  _currentOpenDirection == ICSDrawerControllerDirectionTop) ? 1 : -1;
            
            if (self.drawerState == ICSDrawerControllerStateOpening) {
                if (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                    delta = location.x - self.panGestureStartLocation.x;
                }else {
                    delta = location.y - self.panGestureStartLocation.y;
                }
            }
            else if (self.drawerState == ICSDrawerControllerStateClosing) {
                if (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                    delta = self.slideOffset * signFlag  - (self.panGestureStartLocation.x - location.x);
                }else {
                    delta = self.slideOffset * signFlag  - (self.panGestureStartLocation.y - location.y);
                }
            }
            
            CGRect l = self.slideView.frame;
            CGRect c = self.centerView.frame;
            CGRect s = _statusBarView.frame;
            
            if (((_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionTop) && delta > self.slideOffset) || ((_currentOpenDirection == ICSDrawerControllerDirectionRight || _currentOpenDirection == ICSDrawerControllerDirectionBottom) && delta < -self.slideOffset)) {
                
                if (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                    l.origin.x = 0.0f;
                    c.origin.x = self.slideOffset * signFlag;
                }else {
                    l.origin.y = 0.0f;
                    c.origin.y = self.slideOffset * signFlag;
                }

                if(self.shouldMoveStatusBar){
                    if (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                         s.origin.x = self.slideOffset * signFlag;
                    }else {
                        s.origin.y = self.slideOffset * signFlag;
                    }
                }
            }
            else if (((_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionTop) && delta < 0.0f) || ((_currentOpenDirection == ICSDrawerControllerDirectionRight || _currentOpenDirection == ICSDrawerControllerDirectionBottom) && delta > 0.0f)) {
                if (_currentOpenDirection == ICSDrawerControllerDirectionLeft) {
                    l.origin.x = kICSDrawerControllerSlideViewInitialOffset;
                }else if (_currentOpenDirection == ICSDrawerControllerDirectionRight){
                    l.origin.x = - kICSDrawerControllerSlideViewInitialOffset;
                }else if (_currentOpenDirection == ICSDrawerControllerDirectionTop){
                    l.origin.y = kICSDrawerControllerSlideViewInitialOffset;
                }else if (_currentOpenDirection == ICSDrawerControllerDirectionBottom){
                    l.origin.y = - kICSDrawerControllerSlideViewInitialOffset;
                }
                
                c.origin.x = 0.0f;
                if(self.shouldMoveStatusBar) {
                    if (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                        s.origin.x = 0.0f;
                    }else {
                        s.origin.y = 0.0f;
                    }
                }
            }
            else {
                // While the centerView can move up to kICSDrawerControllerDrawerDepth points, to achieve a parallax effect
                // the leftView has move no more than kICSDrawerControllerLeftViewInitialOffset points
                if(_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                    l.origin.x = signFlag * kICSDrawerControllerSlideViewInitialOffset
                    - (delta * kICSDrawerControllerSlideViewInitialOffset) / self.slideOffset ;
                    c.origin.x = delta;
                    if(self.shouldMoveStatusBar) s.origin.x = delta;
                }else {
                    l.origin.y = signFlag * kICSDrawerControllerSlideViewInitialOffset
                    - (delta * kICSDrawerControllerSlideViewInitialOffset) / self.slideOffset ;
                    c.origin.y = delta;
                    if(self.shouldMoveStatusBar) s.origin.y = delta;
                }
            }
            
            self.slideView.frame = l;
            self.centerView.frame = c;
            if(self.shouldMoveStatusBar) _statusBarView.frame = s;
            break;
        }
            
        case UIGestureRecognizerStateEnded:

            if (self.drawerState == ICSDrawerControllerStateOpening) {
                CGFloat centerViewLocation = (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight)? self.centerView.frame.origin.x : self.centerView.frame.origin.y;
                
                if (fabsf(centerViewLocation) == self.slideOffset ) {
                    // Open the drawer without animation, as it has already being dragged in its final position
                    [self setNeedsStatusBarAppearanceUpdate];
                    [self didOpen];
                }
                else if ((_currentOpenDirection == ICSDrawerControllerDirectionLeft && centerViewLocation > self.view.bounds.size.width / 3
                          && velocity.x > 0.0f) || (_currentOpenDirection == ICSDrawerControllerDirectionRight && centerViewLocation < - self.view.bounds.size.width / 3
                                                    && velocity.x < 0.0f) || (_currentOpenDirection == ICSDrawerControllerDirectionTop && centerViewLocation > self.view.bounds.size.height / 3
                                                                              && velocity.x > 0.0f) || (_currentOpenDirection == ICSDrawerControllerDirectionBottom && centerViewLocation < - self.view.bounds.size.height / 3
                                                                                                        && velocity.x < 0.0f)) {
                    // Animate the drawer opening
                    [self animateOpening];
                }else {
                    // Animate the drawer closing, as the opening gesture hasn't been completed or it has
                    // been reverted by the user
                    [self didOpen];
                    [self willClose];
                    [self animateClosing];
                }

            } else if (self.drawerState == ICSDrawerControllerStateClosing) {
                CGFloat centerViewLocation = (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight)? self.centerView.frame.origin.x : self.centerView.frame.origin.y;
                if (centerViewLocation == 0.0f) {
                    // Close the drawer without animation, as it has already being dragged in its final position
                    [self setNeedsStatusBarAppearanceUpdate];
                    [self didClose];
                }
                else if ((_currentOpenDirection == ICSDrawerControllerDirectionLeft && centerViewLocation < self.slideOffset / 2
                          && velocity.x < 0.0f) || (_currentOpenDirection == ICSDrawerControllerDirectionRight && centerViewLocation > - self.slideOffset / 2
                                                    && velocity.x > 0.0f) || (_currentOpenDirection == ICSDrawerControllerDirectionTop && centerViewLocation < self.slideOffset / 2
                                                                              && velocity.y < 0.0f) || (_currentOpenDirection == ICSDrawerControllerDirectionBottom && centerViewLocation > - self.slideOffset / 2
                                                                                                        && velocity.y > 0.0f)) {
                    // Animate the drawer closing
                    [self animateClosing];
                }
                else {
                    // Animate the drawer opening, as the opening gesture hasn't been completed or it has
                    // been reverted by the user
                    [self didClose];
                    
                    // Here we save the current position for the leftView since
                    // we want the opening animation to start from the current position
                    // and not the one that is set in 'willOpen'
                    CGRect l = self.slideView.frame;
                    [self willOpen];
                    self.slideView.frame = l;
                    
                    [self animateOpening];
                }
            }
            break;
            
        default:
            break;
    }
}

#pragma mark - Animations
#pragma mark Opening animation
- (void)animateOpening
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateOpening);
    NSParameterAssert(self.slideView);
    NSParameterAssert(self.centerView);
    
    // Calculate the final frames for the container views
    CGRect slideViewFinalFrame = self.view.bounds;
    CGRect centerViewFinalFrame = self.view.bounds;
    
    switch (_currentOpenDirection) {
        case ICSDrawerControllerDirectionLeft:
            centerViewFinalFrame.origin.x = self.slideOffset;
            break;
        case ICSDrawerControllerDirectionRight:
            centerViewFinalFrame.origin.x = -self.slideOffset;
            break;
        case ICSDrawerControllerDirectionTop:
            centerViewFinalFrame.origin.y = self.slideOffset;
            break;
        case ICSDrawerControllerDirectionBottom:
            centerViewFinalFrame.origin.y = -self.slideOffset;
            break;
    }

    [UIView animateWithDuration:kICSDrawerControllerAnimationDuration
                          delay:0
         usingSpringWithDamping:(self.isBounce?kICSDrawerControllerOpeningAnimationSpringDamping:kICSDrawerControllerOpeningAnimationSpringDampingNone)
          initialSpringVelocity:kICSDrawerControllerOpeningAnimationSpringInitialVelocity
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         self.centerView.frame = centerViewFinalFrame;
                         self.slideView.frame = slideViewFinalFrame;

                         if(self.shouldMoveStatusBar)
                         {
                             CGRect statusViewFinalFrame = _statusBarView.frame;
                             if (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                                 statusViewFinalFrame.origin.x = centerViewFinalFrame.origin.x;
                             }else {
                                 statusViewFinalFrame.origin.y = centerViewFinalFrame.origin.y;
                             }
                             
                            _statusBarView.frame = statusViewFinalFrame;
                         }
                         
                         [self setNeedsStatusBarAppearanceUpdate];
                     }
                     completion:^(BOOL finished) {
                         [self didOpen];
                     }];
}
#pragma mark Closing animation
- (void)animateClosing
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateClosing);
    NSParameterAssert(self.slideView);
    NSParameterAssert(self.centerView);
    
    // Calculate final frames for the container views
    CGRect slideViewFinalFrame = self.slideView.frame;
    
    switch (_currentOpenDirection) {
        case ICSDrawerControllerDirectionLeft:
            slideViewFinalFrame.origin.x = kICSDrawerControllerSlideViewInitialOffset;
            break;
        case ICSDrawerControllerDirectionRight:
            slideViewFinalFrame.origin.x = -kICSDrawerControllerSlideViewInitialOffset;
            break;
        case ICSDrawerControllerDirectionTop:
            slideViewFinalFrame.origin.y = kICSDrawerControllerSlideViewInitialOffset;
            break;
        case ICSDrawerControllerDirectionBottom:
            slideViewFinalFrame.origin.x = -kICSDrawerControllerSlideViewInitialOffset;
            break;
    }

    
    CGRect centerViewFinalFrame = self.view.bounds;

    [UIView animateWithDuration:kICSDrawerControllerAnimationDuration
                          delay:0
         usingSpringWithDamping:kICSDrawerControllerClosingAnimationSpringDamping
          initialSpringVelocity:kICSDrawerControllerClosingAnimationSpringInitialVelocity
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         self.centerView.frame = centerViewFinalFrame;
                         self.slideView.frame = slideViewFinalFrame;

                         if(self.shouldMoveStatusBar)
                         {
                             CGRect statusViewFinalFrame = _statusBarView.frame;
                             if (_currentOpenDirection == ICSDrawerControllerDirectionLeft || _currentOpenDirection == ICSDrawerControllerDirectionRight) {
                                 statusViewFinalFrame.origin.x = 0;
                             }else {
                                 statusViewFinalFrame.origin.y = 0;
                             }
                             
                             _statusBarView.frame = statusViewFinalFrame;
                         }
                         
                         [self setNeedsStatusBarAppearanceUpdate];
                     }
                     completion:^(BOOL finished) {
                         [self didClose];
                     }];
}

- (UIViewController <ICSDrawerControllerChild, ICSDrawerControllerPresenting>*)viewControllerForCurrentDirection{
    UIViewController <ICSDrawerControllerChild, ICSDrawerControllerPresenting>*viewController = nil;
    switch (_currentOpenDirection) {
        case ICSDrawerControllerDirectionLeft:
            viewController = self.leftViewController;
            break;
        case ICSDrawerControllerDirectionRight:
            viewController = self.rightViewController;
            break;
        case ICSDrawerControllerDirectionTop:
            viewController = self.topViewController;
            break;
        case ICSDrawerControllerDirectionBottom:
            viewController = self.bottomViewController;
            break;
        default:
            break;
    }
    
    return viewController;
}

#pragma mark - Opening the drawer

- (void)openFromDirection:(ICSDrawerControllerDirection)direction
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateClosed);
    _currentOpenDirection = direction;
    
    UIViewController *slideController = [self viewControllerForCurrentDirection];
    if(!slideController) return;
    
    [self willOpen];
    
    [self animateOpening];
}

- (void)willOpen
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateClosed);
    NSParameterAssert(self.slideView);
    NSParameterAssert(self.centerView);
    NSParameterAssert(self.centerViewController);
    
    UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *slideController = [self viewControllerForCurrentDirection];
    // Keep track that the drawer is opening
    self.drawerState = ICSDrawerControllerStateOpening;
    
    // Position the slide view
    CGRect f = self.view.bounds;
    switch (_currentOpenDirection) {
        case ICSDrawerControllerDirectionLeft:
            f.origin.x = kICSDrawerControllerSlideViewInitialOffset;
            break;
        case ICSDrawerControllerDirectionRight:
            f.origin.x = -kICSDrawerControllerSlideViewInitialOffset;
            break;
        case ICSDrawerControllerDirectionTop:
            f.origin.y = kICSDrawerControllerSlideViewInitialOffset;
            break;
        case ICSDrawerControllerDirectionBottom:
            f.origin.y = -kICSDrawerControllerSlideViewInitialOffset;
            break;
    }
    
    self.slideView.frame = f;
    
    // Start adding the left view controller to the container
    [self addChildViewController:slideController];
    slideController.view.frame = self.slideView.bounds;
    [self.slideView addSubview:slideController.view];

    // Add the left view to the view hierarchy
    [self.view insertSubview:self.slideView belowSubview:self.centerView];
    
    // Notify the child view controllers that the drawer is about to open
    if ([slideController respondsToSelector:@selector(drawerControllerWillOpen:)]) {
        [slideController drawerControllerWillOpen:self];
    }
    if ([self.centerViewController respondsToSelector:@selector(drawerControllerWillOpen:)]) {
        [self.centerViewController drawerControllerWillOpen:self];
    }
}

- (void)didOpen
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateOpening);
    NSParameterAssert(self.centerViewController);
    
    // Complete adding the left controller to the container
    UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *slideController = [self viewControllerForCurrentDirection];
    [slideController didMoveToParentViewController:self];
    
    [self addClosingGestureRecognizers];
    
    // Keep track that the drawer is open
    self.drawerState = ICSDrawerControllerStateOpen;
    
    // Notify the child view controllers that the drawer is open
    if ([slideController respondsToSelector:@selector(drawerControllerDidOpen:)]) {
        [slideController drawerControllerDidOpen:self];
    }
    if ([self.centerViewController respondsToSelector:@selector(drawerControllerDidOpen:)]) {
        [self.centerViewController drawerControllerDidOpen:self];
    }
}

#pragma mark - Closing the drawer

- (void)close
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateOpen);

    [self willClose];

    [self animateClosing];
}

- (void)willClose
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateOpen);
    NSParameterAssert(self.centerViewController);
    
    UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *slideController = [self viewControllerForCurrentDirection];
    // Start removing the left controller from the container
    [slideController willMoveToParentViewController:nil];
    
    // Keep track that the drawer is closing
    self.drawerState = ICSDrawerControllerStateClosing;
    
    // Notify the child view controllers that the drawer is about to close
    if ([slideController respondsToSelector:@selector(drawerControllerWillClose:)]) {
        [slideController drawerControllerWillClose:self];
    }
    if ([self.centerViewController respondsToSelector:@selector(drawerControllerWillClose:)]) {
        [self.centerViewController drawerControllerWillClose:self];
    }
}

- (void)didClose
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateClosing);
    NSParameterAssert(self.slideView);
    NSParameterAssert(self.centerView);
    NSParameterAssert(self.centerViewController);
    
    UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *slideController = [self viewControllerForCurrentDirection];
    
    // Complete removing the left view controller from the container
    [slideController.view removeFromSuperview];
    [slideController removeFromParentViewController];
    
    // Remove the left view from the view hierarchy
    [self.slideView removeFromSuperview];
    
    [self removeClosingGestureRecognizers];
    
    // Keep track that the drawer is closed
    self.drawerState = ICSDrawerControllerStateClosed;
    
    // Notify the child view controllers that the drawer is closed
    if ([slideController respondsToSelector:@selector(drawerControllerDidClose:)]) {
        [slideController drawerControllerDidClose:self];
    }
    if ([self.centerViewController respondsToSelector:@selector(drawerControllerDidClose:)]) {
        [self.centerViewController drawerControllerDidClose:self];
    }
}

#pragma mark - Reloading/Replacing the center view controller

- (void)reloadCenterViewControllerUsingBlock:(void (^)(void))reloadBlock
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateOpen);
    NSParameterAssert(self.centerViewController);
    
    [self willClose];
    
    CGRect f = self.centerView.frame;
    f.origin.x = self.view.bounds.size.width;
    
    [UIView animateWithDuration: kICSDrawerControllerAnimationDuration / 2
                     animations:^{
                         self.centerView.frame = f;
                     }
                     completion:^(BOOL finished) {
                         // The center view controller is now out of sight
                         if (reloadBlock) {
                             reloadBlock();
                         }
                         // Finally, close the drawer
                         [self animateClosing];
                     }];
}

- (void)replaceCenterViewControllerWithViewController:(UIViewController<ICSDrawerControllerChild, ICSDrawerControllerPresenting> *)viewController
{
    NSParameterAssert(self.drawerState == ICSDrawerControllerStateOpen);
    NSParameterAssert(viewController);
    NSParameterAssert(self.centerView);
    NSParameterAssert(self.centerViewController);
    
    [self willClose];
    
    CGRect f = self.centerView.frame;
    f.origin.x = self.view.bounds.size.width;
    
    [self.centerViewController willMoveToParentViewController:nil];
    [UIView animateWithDuration: kICSDrawerControllerAnimationDuration / 2
                     animations:^{
                         self.centerView.frame = f;
                     }
                     completion:^(BOOL finished) {
                         // The center view controller is now out of sight
                         
                         // Remove the current center view controller from the container
                         if ([self.centerViewController respondsToSelector:@selector(setDrawer:)]) {
                             self.centerViewController.drawer = nil;
                         }
                         [self.centerViewController.view removeFromSuperview];
                         [self.centerViewController removeFromParentViewController];
                         
                         // Set the new center view controller
                         self.centerViewController = viewController;
                         if ([self.centerViewController respondsToSelector:@selector(setDrawer:)]) {
                             self.centerViewController.drawer = self;
                         }
                         
                         // Add the new center view controller to the container
                         [self addCenterViewController];
                         
                         // Finally, close the drawer
                         [self animateClosing];
                     }];
}

@end
