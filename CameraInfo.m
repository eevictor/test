//
//  CameraInfo.m
//  Sketch with Perspective View
//
//  Created by Victor NG on 24/6/2015.
//  Copyright (c) 2015年 Victor WP NG. All rights reserved.
//

#import "CameraInfo.h"

// use notification constants
#import "MenuViewController.h"

#import "CPanAndMoreGestureRecognizer.h"
#import "CGrabAndGrabGestureRecognizer.h"
#import "CArrowShape.h"
#import "CMeshSelectionMenu.h" //"CShadowHolder.h"

@implementation CameraInfo

@synthesize position=_position;
@synthesize viewDirection=_viewDirection;
@synthesize upDirection=_upDirection;
@synthesize xFov=_xFov;
@synthesize farPlane=_farPlane;
@synthesize nearPlane=_nearPlane;
@synthesize orthographic=_orthographic;
@synthesize aspectRatio=_aspectRatio;
@synthesize focusDistance=_focusDistance;
@synthesize focusPoint=_focusPoint;
@synthesize viewMatrix=_viewMatrix;
@synthesize invertedViewMatrix=_invertedViewMatrix;
@synthesize projectionMatrix=projectionMatrix;
//@synthesize isValid=_isValid;

- (instancetype)init
{
	self = [super init];
	if (self) {
		_focusDistance = 1;
		_aspectRatio = 1.0;
		_xFov = 75;
		_nearPlane = 1;
		_farPlane = 500;
		self.viewMatrix = GLKMatrix4Identity;
	}
	return self;
}

- (instancetype)initWithMatrix:(GLKMatrix4)viewMatrix focusDistance:(float)focusDistance
{
	self = [super init];
	if (self) {
		_focusDistance = focusDistance;
		_aspectRatio = 1.0;
		_xFov = 75;
		_nearPlane = 1;
		_farPlane = 500;
		[self setViewMatrix:viewMatrix];
	}
	return self;
}

- (void)setViewMatrix:(GLKMatrix4)viewMatrix
{
	bool isInvertible;
	GLKMatrix4 invertedCamera = GLKMatrix4Invert(viewMatrix, &isInvertible);

	if ( !isInvertible) {
		NSLog(@"camera info, viewMatrix is not invertible!");
	}
	
	_viewMatrix = viewMatrix;
	_invertedViewMatrix = invertedCamera;

	_position = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f)).v);
	_viewDirection = GLKVector3Normalize( GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, -1.0f, 0.0f)).v) );
	_upDirection = GLKVector3Normalize( GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 1.0f, 0.0f, 0.0f)).v) );
	
	_focusPoint = GLKVector3Add(_position, GLKVector3MultiplyScalar(_viewDirection, _focusDistance ));

}

- (void)setFocusDistance:(float)focusDistance
{
	_focusDistance = focusDistance;
	_focusPoint = GLKVector3Add(_position, GLKVector3MultiplyScalar(_viewDirection, _focusDistance ));
}

- (GLKVector3)projectPointInWC:(GLKVector3)pointInWC
{
	GLint viewport[4] = { _viewPort.origin.x, _viewPort.origin.y, _viewPort.size.width, _viewPort.size.height };

	return GLKMathProject(pointInWC, self.viewMatrix, self.projectionMatrix, viewport);
}

- (GLKVector3)unprojectPointInWindow:(GLKVector3)pointInWindow
{
	GLint viewport[4] = { _viewPort.origin.x, _viewPort.origin.y, _viewPort.size.width, _viewPort.size.height };
	
	bool success;
	GLKVector3 pointInWC = GLKMathUnproject(pointInWindow, self.viewMatrix, self.projectionMatrix, viewport, &success);
	if ( success ) return pointInWC;
	
	return GLKVector3Make(0, 0, 0);
}

#pragma mark - override
- (id)copyWithZone:(NSZone *)zone
{
	CameraInfo *newCameraInfo = [[CameraInfo allocWithZone: zone] initWithMatrix: self.viewMatrix focusDistance: self.focusDistance];
	
	newCameraInfo.projectionMatrix = self.projectionMatrix;
	newCameraInfo.viewPort = self.viewPort;
	newCameraInfo.xFov = self.xFov;
	newCameraInfo.nearPlane = self.nearPlane;
	newCameraInfo.farPlane = self.farPlane;
	newCameraInfo.orthographic = self.orthographic;
	newCameraInfo.aspectRatio = self.aspectRatio;
	
	return newCameraInfo;
}

@end

// =========================================================================================
@implementation CameraOperator
{
	BOOL _hasDeltaCameraMatrix;
	BOOL _hasDeltaCameraMatrix_forPostPend;
	GLKMatrix4 _deltaCameraMatrix;
	GLKMatrix4 _deltaCameraMatrix_forPostPend;
	NSMutableArray *_cameraMatrixList;
	
	BOOL _hasDeltaCameraQuaternion;
	GLKMatrix4 _deltaCameraQuaternionMatrix;
	
	BOOL _hasDeltaZoomFactor_FOV;
	float _cameraZoomFactorDelta_FOV;
	BOOL _hasDeltaZoomFactor_Distance;
	float _cameraZoomFactorDelta_Distance;
	float _deltaDistanceZoomed;
	BOOL _hasDeltaForwardDistance;
	float _deltaDistanceMoved;

	NSTimeInterval _lastActionTimestamp;
	NSTimeInterval MAX_INACTIVE_TIME;
	BOOL _continueGestureProcessing;
	
	BOOL _cameraInAction;
	//BOOL _mayExpandTransformEditor;
	BOOL _cameraStopAction;
	BOOL _cameraMoveInView;
	BOOL _cameraRotateHorizontal;
	BOOL _cameraRotateVertical;
	BOOL _cameraRotateLeftWise;
	BOOL _cameraRotateRightWise;
	BOOL _cameraRotateTopWise;
	BOOL _cameraPan;
	BOOL _cameraPan_AndSelect;
	BOOL _cameraPan_AndDeSelect;
	BOOL _cameraMoveForwardBackward;
	BOOL _cameraChangeFOV;
	BOOL _cameraPanAndRotateInTandem;
	BOOL _cameraTumbling;
	BOOL _cameraRotateAroundFocalPlaneVerically;
	BOOL _cameraRotateAroundFocalPlaneHorizontally;
	BOOL _cameraDragRotateResize;
	BOOL _changingFocalPlane;
	BOOL _screenEdgePan;
	BOOL _screenEdgeLeftPan;
	CGPoint _firstTouch;
	CGPoint _lastTouch;
	BOOL _debugActionDisplayed;

	// gesture begin state for dragRotateResize.
	GLKVector2 _firstFingersDirection;  // the screen direction of 2 touching fingers. Magnitude is the distance of the 2 fingers.
	GLKVector2 _firstFingersCenter;
	GLKVector3 _firstFingersCenterWC;
	GLKVector2 _lastFingersDirection;
	BOOL _lastFingersDirectionSwapped;
	BOOL _lastSingleFingerLifted;
	BOOL _resetFirstTouch_ForDragRotateResize;
	GLKVector2 _lastFingersCenter;
	GLKVector2 _lastFingersCenterDeviation;
	GLKMatrix4 _lastCameraMatrix;
	GLKMatrix4 _lastInvertedCamera;
	GLKVector3 _lastCameraPositionInWC;
	GLKVector3 _lastCameraViewDirection;
	GLKVector3 _lastCameraUpDirection;
	GLKVector3 _lastCentroidInWC;
	GLKMatrix4 _lastProjectionMatrix;
	GLKMatrix4 _lastModelView;
	GLKMatrix4 _lastDeltaApplied;
	
	BOOL _pinchCenterMoved;
	
	CameraInfo * _lastCameraInfoAtGestureBegan;

	CGPoint _firstTouch_ForPanMore;
	CGPoint _lastTouch_ForPanMore;
	BOOL _resetFirstTouch_ForPanMore;
	BOOL _cameraPan_ForPanMore;
	BOOL _cameraTumbling_ForPanMore;
	BOOL _cameraRotate_ForPanMore;
	BOOL _cameraPinch_ForPanMore;
	BOOL _pencilPinch_ForPanMore;
	float _cameraPinch_startingSize;
	BOOL _touchFromLeftSide_ForPanMore;
	BOOL _tapSecondary_forPanMore;
	CGPoint _secondaryFirstTouchAt_ForPanMore;
	NSTimeInterval _secondaryTouchBeginTime;
	BOOL _tapSecondaryTargetForDeviateNormalDir_ForPanMore;
	BOOL _shouldDeviateNormalDir_ForPanMore;
	CGPoint _workingTouchCenter_ForPanMore;
	
	// panning ending velocity
	NSTimer *panSwipeTimer;
	BOOL continuousTumbling;
	float panEndingVelocityThreshold;
	GLKVector2 initialVelocity;
	GLKVector2 panDirection;
	GLKMatrix4 lastDeltaContinue;
	GLKMatrix4 lastDeltaContinue2;
	int timerCount;
	float SMALL_MOVEMENT_FOR_FOV;
	float _THUMB_SIZE;
	
	// this layer is to assist continuous tumbling animation
	CArrowShape *arrowLayer;
	NSTimer *undoTimer;
	BOOL continuousUndoCameraDelta;
	
	UILabel * touchingFocus;
	CShadowHolder * _axisUpIcon;
	NSLayoutConstraint *_axisUpIcon_cn_centerx, *_axisUpIcon_cn_centery;
	
}

@synthesize cameraInfo=_cameraInfo;

- (instancetype)initWithView:(UIView*)view manipulable:(id<CameraManipulable>)manipulable
{
	self = [super init];
	if ( self ) {
		_view = view;
		_delegate = manipulable;
		
		_epsilon = 0.000001f;
		_cameraMatrixList = [[NSMutableArray alloc] init];
		_cameraPerspective = YES;
		_nearPlane = 1.0f;
		_farPlane = 500.0f;
		_defaultFovInDegree = 60;
		_smallestFovFactor = 0.001f;   // _defaultFovInDegree * _smallestFovFactor = 0.01 degree, too small.  0.06 degree is just good.
		_cameraZoomFactor = 1.0f;
		_focalPlaneDistance = 100.0;

		// screen native scale is 2.61 for 6s+, while others tally with scale.
		_nativeScale = [UIScreen mainScreen].scale;
		CGRect _nativeBounds = CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, self.view.frame.size.width*_nativeScale, self.view.frame.size.height*_nativeScale);
		if ( [[UIScreen mainScreen] respondsToSelector:@selector(nativeScale)] ) {
			_nativeScale = [UIScreen mainScreen].nativeScale;
			_nativeBounds = CGRectMake(self.view.frame.origin.x*_nativeScale, self.view.frame.origin.y*_nativeScale, self.view.frame.size.width*_nativeScale, self.view.frame.size.height*_nativeScale);
		}

		[self viewFrameChanged];

		_cameraInfo = [[CameraInfo alloc] init];
		self.cameraInfo.projectionMatrix = self.getProjectionMatrix;
		self.cameraInfo.viewPort = CGRectMake( self.view.frame.origin.x*_nativeScale, self.view.frame.origin.y*_nativeScale, self.view.frame.size.width*_nativeScale, self.view.frame.size.height*_nativeScale );
		self.cameraInfo.xFov = _defaultFovInDegree * M_PI / 180.0;
		self.cameraInfo.nearPlane = self.nearPlane;
		self.cameraInfo.farPlane = self.farPlane;
		self.cameraInfo.orthographic = !self.cameraPerspective;
		self.cameraInfo.aspectRatio = self.aspectRatio;
	
		MAX_INACTIVE_TIME = 3.0;
		_THUMB_SIZE = 20 ;
		
		// should use small movement when field of view is very small.
		//SMALL_MOVEMENT_FOR_FOV = 0.001;  // M_PI / 30.0;   // 6° degree.
		// too small, double tap focusing action is not precise.
		SMALL_MOVEMENT_FOR_FOV = self.smallestFovFactor;  // M_PI / 30.0;   // 1° degree.
		
		[self setupUIAndGestures];
	}
	
	return self;
}

- (void)setupUIAndGestures
{
	// Use subclassed pan recognizer to get reference to underlying touches.  This gesture together with the _axisManipulator and moveCameraForAdditionalTouchWhenPanning method, forms the multi-touches drag-through-space feature.
	self.panRecognizer = [[CPanAndMoreGestureRecognizer alloc] initWithTarget:self action:@selector(panDetected:)] ;
	((CPanAndMoreGestureRecognizer*)self.panRecognizer).verboseName = @"CameraOperator.panRecognizer";
	
	// this delegate is to ensure the gesture is targeting for self.view, rather than other subviews in-front.
	self.panRecognizer.delegate = self;
	[self.view addGestureRecognizer: self.panRecognizer];

	UIPinchGestureRecognizer * pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchDetected:)];
	//pinchRecognizer.name = @"pinchRecognizer";
	pinchRecognizer.delegate = self;
	[self.view addGestureRecognizer:pinchRecognizer];
	self.pinchRecognizer = pinchRecognizer;
	
	UITapGestureRecognizer * doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapDetected:)];
	// this delegate is to avoid tapping button as double tapping the view.
	doubleTap.delegate = self;
	doubleTap.numberOfTapsRequired = 2;
	[self.view addGestureRecognizer: doubleTap];
	self.doubleTapRecognizer = doubleTap;

	UITapGestureRecognizer * tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDetected:)];
	// this delegate is to avoid blocking subview, the collectionView, selections.
	tapRecognizer.delegate = self;
	[tapRecognizer requireGestureRecognizerToFail:doubleTap];
	[self.view addGestureRecognizer:tapRecognizer];
	self.tapRecognizer = tapRecognizer;

	CGrabAndGrabGestureRecognizer * longPressRecognizer = [[CGrabAndGrabGestureRecognizer alloc] initWithTarget:self action:@selector(longPressDetected:)];
	//longPressRecognizer.verboseName = @"CameraOperator.longPressRecognizer";
	[longPressRecognizer setMinimumPressDuration:0.2];
	// this delegate is to ensure the gesture is targeting for self.view, rather than other subviews in-front.
	longPressRecognizer.delegate = self;
	[self.view addGestureRecognizer:longPressRecognizer];
	self.longPressRecognizer = longPressRecognizer;

	{
		arrowLayer = [[CArrowShape alloc] init];
		[touchingFocus.layer addSublayer:arrowLayer];
	}
	{
		touchingFocus = [[UILabel alloc] init];
		
		touchingFocus.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.05];
		touchingFocus.textColor = UIColor.clearColor;
		touchingFocus.userInteractionEnabled = NO;
		touchingFocus.hidden = NO;
		
		touchingFocus.layer.cornerRadius = 10.0; //round the corners on the layer..
		touchingFocus.layer.borderWidth = 1.0;
		touchingFocus.layer.borderColor = [UIColor colorWithRed:1.0 green:99.0/255.0 blue:71.0/255.0 alpha:0.1].CGColor;
		touchingFocus.clipsToBounds = YES;
		
		touchingFocus.frame = CGRectMake(0, 0, 20, 20);
		touchingFocus.translatesAutoresizingMaskIntoConstraints = YES;
		[self.view addSubview:touchingFocus];
		
		//touchingFocus_AnimatingHint = nil;
	}
	
	{
		//_axisUpIcon = [[UILabel alloc] initWithFrame: CGRectZero];
		_axisUpIcon = [CMeshSelectionMenu prepareShadowUILabel];
		_axisUpIcon.text = @"";
		_axisUpIcon.label.layer.borderWidth = 0.0;
		_axisUpIcon.label.font = [UIFont fontWithName:@"Helvetica" size:8.0];
		_axisUpIcon.label.adjustsFontSizeToFitWidth = NO;
		//_axisUpIcon.layer.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.0].CGColor;
		_axisUpIcon.layer.shadowRadius = 8;
		_axisUpIcon.layer.shadowColor = [UIColor colorWithRed:0 green:1.0 blue:1.0 alpha:1.0].CGColor;
		_axisUpIcon.layer.backgroundColor = [UIColor colorWithRed:0 green:1.0 blue:1.0 alpha:0.6].CGColor;
		_axisUpIcon.layer.cornerRadius = 10;
		
		_axisUpIcon.userInteractionEnabled = NO;
		_axisUpIcon.hidden = YES;
		
		_axisUpIcon.translatesAutoresizingMaskIntoConstraints = NO;
		[self.view addSubview: _axisUpIcon];
		[self.view sendSubviewToBack: _axisUpIcon];
		
		NSLayoutConstraint *cn = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
		_axisUpIcon_cn_centerx = cn;
		[self.view addConstraint:cn];
		cn = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem: self.view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
		_axisUpIcon_cn_centery = cn;
		[self.view addConstraint:cn];
		cn = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20];
		[self.view addConstraint:cn];
		cn = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:20];
		[self.view addConstraint:cn];
		
	}
	

	//debug
	{
		/*
		UISlider *_slider1 = [[UISlider alloc] init];
		[_slider1 addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
		_slider1.minimumValue = 1.0 * M_PI / 180.0;
		_slider1.maximumValue = 179.0 * M_PI / 180.0;
		_slider1.value = self.getCameraFoV;

		_slider1.translatesAutoresizingMaskIntoConstraints = NO;
		[self.view addSubview: _slider1];
		
		NSLayoutConstraint * cn = [NSLayoutConstraint constraintWithItem:_slider1 attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0.0];
		[self.view addConstraint: cn];
		cn = [NSLayoutConstraint constraintWithItem:_slider1 attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-20.0];
		[self.view addConstraint: cn];
		cn = [NSLayoutConstraint constraintWithItem:_slider1 attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0.0];
		[self.view addConstraint: cn];
		cn = [NSLayoutConstraint constraintWithItem:_slider1 attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:20.0];
		[self.view addConstraint: cn];
		*/
	}
}

- (void)sliderValueChanged:(UISlider*)sender
{
	[self setCameraFoV: sender.value];
}

- (CameraInfo *)cameraInfo
{
	CameraInfo * info = [[CameraInfo alloc] initWithMatrix:[self getCameraMatrix:YES] focusDistance:self.adjustedFocalPlaneDistance];
	
	info.projectionMatrix = [self getProjectionMatrix];
	info.viewPort = CGRectMake(VIEW_FRAME.origin.x * _nativeScale, VIEW_FRAME.origin.y*_nativeScale, VIEW_FRAME.size.width*_nativeScale, VIEW_FRAME.size.height*_nativeScale); // [self.delegate getViewPort];
	info.xFov = [self getCameraFoV];
	info.nearPlane = self.nearPlane;
	info.farPlane = self.farPlane;
	info.orthographic = !self.cameraPerspective;
	info.aspectRatio = self.aspectRatio;
	
	return info;
}

- (CameraInfo *)getCameraInfo
{
	return [self cameraInfo];
}

- (void)setCameraInfo:(CameraInfo *)cameraInfo
{
	_cameraInfo = cameraInfo;
	
	_nearPlane = cameraInfo.nearPlane;
	_farPlane = cameraInfo.farPlane;
	[self setCameraFoV: cameraInfo.xFov];
	[self setAspectRatio: cameraInfo.aspectRatio];
	self.cameraPerspective = !cameraInfo.orthographic;
	GLKMatrix4 currentInverse = GLKMatrix4Invert([self getCameraMatrix], nil);
	GLKMatrix4 newViewMatrix = GLKMatrix4Multiply(cameraInfo.viewMatrix, currentInverse);
	[self applyCameraDeltaCompleted: newViewMatrix];
	
	[self resetFocusToLocation: cameraInfo.focusPoint ];
}

- (GLKVector3)getCameraPosition
{
	GLKMatrix4 invertedCamera = [self getCameraInverse];
	GLKVector4 cameraPositionInWC = GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f));
	//NSLog(@"camera position : %@", NSStringFromGLKVector4(cameraPositionInWC));
	return GLKVector3Make(cameraPositionInWC.x, cameraPositionInWC.y, cameraPositionInWC.z);
}

- (GLKVector3)getCameraPositionWithDeltaMatrix
{
	bool isInvertible;
	GLKMatrix4 invertedCamera = GLKMatrix4Invert([self getCameraMatrix:YES], &isInvertible);
#if defined(DEBUG)
	if ( !isInvertible)
		NSLog(@"camera matrix is not invertible!");
#endif
	GLKVector4 cameraPositionInWC = GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f));
	return GLKVector3Make(cameraPositionInWC.x, cameraPositionInWC.y, cameraPositionInWC.z);
}

- (void)resetToDefaults
{
	CGFloat _cameraPullBack = -2.0;
	[self resetToDefaultsWithMatrix:GLKMatrix4MakeLookAt(0.0, 0.0, -_cameraPullBack, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0)];
}
- (void)resetToDefaultsWithMatrix:(GLKMatrix4)startingCameraMatrix
{
	_cameraPerspective = YES;
	_nearPlane = 1.0f;
	_farPlane = 500.0f;
	_aspectRatio = VIEW_FRAME.size.width / VIEW_FRAME.size.height;   //self.view.frame.size.width / self.view.frame.size.height;
	_defaultFovInDegree = 60;
	if ( [self.delegate respondsToSelector:@selector(getDefaultFieldOfViewInDegree)] ) {
		float preferredDefaultFov = [self.delegate getDefaultFieldOfViewInDegree];
		if ( preferredDefaultFov > 0.0 && preferredDefaultFov < 180.0) {
			_defaultFovInDegree = preferredDefaultFov;
		}
	}

	_cameraZoomFactor = 1.0f;
	_cameraZoomFactorDelta_FOV = 1.0f;
	_cameraZoomFactorDelta_Distance = 1.0f;

	_focalPlane = [self.delegate getBoundsCenter];
	_adjustedFocalPlaneFactor = 0.0;
	
	//[self viewFrameChanged];
	
	_hasDeltaCameraMatrix = NO;
	_hasDeltaCameraMatrix_forPostPend = NO;
	[_cameraMatrixList removeAllObjects];
	
	CGFloat _cameraPullBack = -10.0;
	[self addCameraMatrix: startingCameraMatrix];
	
	_hasDeltaCameraQuaternion = NO;
	_hasDeltaZoomFactor_FOV = NO;
	_hasDeltaZoomFactor_Distance = NO;
	_hasDeltaForwardDistance = NO;
	
	_focalPlaneDistance = GLKVector3Distance([self getCameraPosition], _focalPlane);
	if ( isnan(_focalPlaneDistance) ) {
		NSLog(@"_focalPlaneDistance should not be NaN");
		_focalPlane = GLKVector3Make(0, 0, 0);
		_focalPlaneDistance = -_cameraPullBack;
	} else if ( isinf(_focalPlaneDistance)) {
		NSLog(@"_focalPlaneDistance should not be Infinity");
		_focalPlane = GLKVector3Make(0, 0, 0);
		_focalPlaneDistance = -_cameraPullBack;
	}
	
	if ( self.cameraChangeNotificationEnabled ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1)} ];
	}
	
}

- (GLKMatrix4)getInitialCameraMatrix
{
	GLKMatrix4 initMatrix = GLKMatrix4Identity;
	if ( _cameraMatrixList.count > 0 ) {
		NSValue * value = _cameraMatrixList.lastObject;
		[value getValue:&initMatrix];
	}
	
	return initMatrix;
}

- (void)replaceInitialCameraMatrix:(GLKMatrix4)matrix
{
	@synchronized( _cameraMatrixList) {
		NSInteger lastIndex = _cameraMatrixList.count - 1;
		NSValue *value = [NSValue valueWithBytes:&matrix objCType:@encode(GLKMatrix4)];
		if ( lastIndex >= 0) {
			[_cameraMatrixList replaceObjectAtIndex:lastIndex withObject:value];
		} else {
			[_cameraMatrixList addObject:value];
		}
	}
}

- (void)viewFrameChanged
{
	VIEW_FRAME = self.view.bounds;
	CGSize viewsize = self.view.bounds.size;
	ONE_THIRD_WIDTH = viewsize.width / 3.0f;
	ONE_THIRD_HEIGHT= viewsize.height / 3.0f;
	ONE_FOURTH_WIDTH= viewsize.width / 4.0f;
	ONE_FOURTH_HEIGHT= viewsize.height / 4.0f;
	ONE_FIFTH_WIDTH= viewsize.width / 5.0f;
	ONE_FIFTH_HEIGHT= viewsize.height / 5.0f;
	ONE_SIXTH_WIDTH= viewsize.width / 6.0f;
	ONE_SIXTH_HEIGHT = viewsize.height / 6.0f;
	_aspectRatio = viewsize.width / viewsize.height;
}

- (GLKMatrix4)getProjectionMatrix
{
	GLKMatrix4 projectionMatrix = GLKMatrix4Identity;
	if (self.cameraPerspective == YES)
		projectionMatrix = GLKMatrix4MakePerspective( [self getCameraFoV], self.aspectRatio, _nearPlane, _farPlane);
	else {
		float top = _nearPlane * tanf( [self getCameraFoV]/2.0 );
		float right = top * self.aspectRatio;
		projectionMatrix = GLKMatrix4MakeOrtho(-right, right, -top, top, _nearPlane, _farPlane);
	}
	return projectionMatrix;
}
- (GLKMatrix4)cameraMatrix
{
	return [self getCameraMatrix:YES];
}
- (GLKMatrix4)getCameraMatrix
{
	return [self getCameraMatrix:YES];
}
- (GLKMatrix4)getCameraMatrix:(BOOL)withDelta
{
	GLKMatrix4 cameraMatrix = GLKMatrix4Identity;
	int cameraScenario = 0;  // 0 - for using all matrix in the _cameraMatrixList.
	if ( cameraScenario == 1 ) {
		cameraMatrix = GLKMatrix4Translate(cameraMatrix, 0.0f, -1.0f, -7.0f);
		//cameraMatrix = GLKMatrix4Rotate( cameraMatrix, M_PI/18, 1.0f, 0.0f, 0.0f);
	} else if ( cameraScenario == 2 ) {
		cameraMatrix = GLKMatrix4Rotate( cameraMatrix, -M_PI/18, 1.0f, 0.0f, 0.0f);
		cameraMatrix = GLKMatrix4Translate(cameraMatrix, 0.0f, 0.0f, -7.0f);
	}
	
	// apply additional delta camera matrix
	@synchronized(_cameraMatrixList) {
		GLKMatrix4 matrix;
		// use copy to avoid contention
		NSArray *tempArrayList = [_cameraMatrixList copy];
		
		// result is M[0]*M[1]*M[2]*M[3] ... * M[n].
		// Where M[n] is the first matrix applied to the object, and, M[0] is the latest manipulation matrix.
		// camera space <-  M[0]*M[1]*M[2]*M[3] ... * M[n]  <- world space, this is the returned matrix, view(camera) matrix.
		// world space <-  M[n] ... *M[3]*M[2]*M[1]*M[0]  <- camera space, this is the inverted matrix, also is the sceneKit Node.transform.
		for (NSValue *value in tempArrayList) {
			[value getValue:&matrix];
			cameraMatrix = GLKMatrix4Multiply(cameraMatrix, matrix);
		}
	}
	if ( withDelta ) {
		@synchronized(self) {
			if (_hasDeltaCameraMatrix ) {
				// this is the correct one: [delta, M0, M1, M2, M3 ... Mn ]
				cameraMatrix = GLKMatrix4Multiply(_deltaCameraMatrix, cameraMatrix );
			}
			if (_hasDeltaCameraQuaternion) {
				cameraMatrix = GLKMatrix4Multiply(_deltaCameraQuaternionMatrix, cameraMatrix);
			}
			if (_hasDeltaCameraMatrix_forPostPend) {
				cameraMatrix = GLKMatrix4Multiply(cameraMatrix, _deltaCameraMatrix_forPostPend );
			}
		}
	}
	return cameraMatrix;
}

// prepend input matrix in front of the array.
- (void)addCameraMatrix:(GLKMatrix4)matrix
{
	NSValue *value = [NSValue valueWithBytes:&matrix objCType:@encode(GLKMatrix4)];
	[_cameraMatrixList insertObject:value atIndex:0];
}

// pospend input matrix at the end of the array.
- (void)addCameraMatrix:(GLKMatrix4)matrix pospend:(BOOL)pospend
{
	NSValue *value = [NSValue valueWithBytes:&matrix objCType:@encode(GLKMatrix4)];
	if (pospend)
		[_cameraMatrixList addObject:value];
	else
		[_cameraMatrixList insertObject:value atIndex:0];
}

// the camera inverse is without delta.  Including the delta may result in unstable delta transformation.
- (GLKMatrix4)getCameraInverse
{
	bool isInvertible;
	GLKMatrix4 result = GLKMatrix4Invert([self getCameraMatrix:NO], &isInvertible);
#if defined(DEBUG)
	if ( !isInvertible)
		NSLog(@"camera matrix is not invertible!");
#endif
	return result;
}

- (int)getCameraMoveCount
{
	return (int)_cameraMatrixList.count;
}

- (float)getCameraFoV
{
	float limitFactor = 180.0 / _defaultFovInDegree - _epsilon;
	if ( _cameraZoomFactor < _smallestFovFactor ) _cameraZoomFactor = _smallestFovFactor;			// too small will be affected by precision error.
	if ( _cameraZoomFactor > limitFactor ) _cameraZoomFactor = limitFactor;  // about 180 degrees field of view.
	
	if ( _hasDeltaZoomFactor_FOV ) {
		if ( _cameraZoomFactor * _cameraZoomFactorDelta_FOV  > limitFactor ) {
			_cameraZoomFactorDelta_FOV = limitFactor / _cameraZoomFactor;
		}
		return GLKMathDegreesToRadians( _defaultFovInDegree ) * _cameraZoomFactor * _cameraZoomFactorDelta_FOV;
	}
	return GLKMathDegreesToRadians( _defaultFovInDegree ) * _cameraZoomFactor;
}

- (void)setCameraFoV:(float)radian
{
	float newFactor = radian / GLKMathDegreesToRadians( _defaultFovInDegree )  ;
	if ( _hasDeltaZoomFactor_FOV ) {
		newFactor /= _cameraZoomFactorDelta_FOV;
	}
	
	float limitFactor = 180.0 / _defaultFovInDegree - _epsilon;
	if ( newFactor < 0.001f ) newFactor = 0.001f;
	if ( newFactor > limitFactor ) newFactor = limitFactor;  // about 180 degrees field of view.
	
	_cameraZoomFactor = newFactor;
}

- (void)setCameraZoomFactor:(float)cameraZoomFactor
{
	//	[self willChangeValueForKey:@"cameraZoomFactor"];
	_cameraZoomFactor = cameraZoomFactor;
	//	[self didChangeValueForKey:@"cameraZoomFactor"];
	
	if ( self.cameraChangeNotificationEnabled ) {
		dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1)} ];
		});
	}
}

// refactor to CameraOperator
- (void)adjustFocalPlaneFactor:(float)percentage
{
	//NSLog(@"request _adjustedFocalPlaneFactor : %f", percentage);
	//if (percentage < 1.0 && percentage > -1.0) {
	if ( ! isnan(percentage) && ! isinf(percentage)) {
		float newFocal =  _focalPlaneDistance + (percentage * ( [self.delegate getBoundsMaxSize] ));
		// prevent moving focal plane out of the view frustum.
		if (newFocal < (_nearPlane + _epsilon) || newFocal > (_farPlane - _epsilon)) return;
		
		_adjustedFocalPlaneFactor = percentage;
		//NSLog(@"_adjustedFocalPlaneFactor : %f", _adjustedFocalPlaneFactor);
	} else {
		NSLog(@"_adjustedFocalPlaneFactor : %f", _adjustedFocalPlaneFactor);
	}
}

- (GLKVector3)getCameraViewDirection
{
	GLKMatrix4 invertedCamera = [self getCameraInverse];
	GLKVector3 cameraViewDirection = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, -1.0f, 0.0f)).v);
	return cameraViewDirection;
}

- (GLKVector3)focalPlaneCenter
{
	GLKMatrix4 invertedCamera = [self getCameraInverse];
	GLKVector3 cameraPositionInWC = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f)).v);
	GLKVector3 cameraViewDirection = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, -1.0f, 0.0f)).v);
	
	GLKVector3 focalCenter = GLKVector3Add(cameraPositionInWC, GLKVector3MultiplyScalar(GLKVector3Normalize(cameraViewDirection), _focalPlaneDistance) );
	return focalCenter;
}

- (float)adjustedFocalPlaneDistance
{
	return [self adjustedFocalPlaneDistance:NO];
}

- (void)setNearPlane:(float)nearPlane
{
	//if ( nearPlane < 0.01 ) return;
	if ( nearPlane < _epsilon ) return;
	if ( nearPlane > (_farPlane - _epsilon) ) return;
	if ( nearPlane > (_focalPlaneDistance - _epsilon) ) return;
	_nearPlane = nearPlane;
}

- (void)setFarPlane:(float)farPlane
{
	if ( farPlane < (_nearPlane + _epsilon) ) return;
	if ( farPlane < (_focalPlaneDistance + _epsilon) ) return;
	_farPlane = farPlane;
}

- (float)aspectRatio
{
	//return VIEW_FRAME.size.width / VIEW_FRAME.size.height;
	return _aspectRatio;
}

// change the focal plane distance, and reset the adjust factor to zero if it is gesture end.
- (float)adjustedFocalPlaneDistance:(BOOL)gestureEnded
{
	float result = _focalPlaneDistance;
	if ( _adjustedFocalPlaneFactor != 0.0 ) {
		result =  _focalPlaneDistance + (_adjustedFocalPlaneFactor * ( [self.delegate getBoundsMaxSize]));
	}
	
	@synchronized(self) {
		if (_hasDeltaForwardDistance) {
			result -= _deltaDistanceMoved;
			
			// maintain focal plane in between near and far plane.
			if ( result < _nearPlane ) {
				result = _nearPlane;
			}
			if ( result > _farPlane ) {
				result = _farPlane;
			}
		}
		if (gestureEnded) {
			if ( isnan(_focalPlaneDistance) ) {
				NSLog(@"_focalPlaneDistance should not be NaN, reset to 5");
				_focalPlaneDistance = 5;
			} else if ( isinf(_focalPlaneDistance) ) {
				NSLog(@"_focalPlaneDistance should not be Inf, reset to 5");
				_focalPlaneDistance = 5;
			} else {
				_focalPlaneDistance = result;
			}
			
			_adjustedFocalPlaneFactor = 0.0;
		}
		//cater for focal plane changes when zoom by distance. ie. maintain focal plane fix at world coord when zoom by distance.
		if (_hasDeltaZoomFactor_Distance) {
			result -= _deltaDistanceZoomed;
		}
	}
	
	return result;
}

- (GLKMatrix4)getCameraDelta
{
	if ( _hasDeltaCameraMatrix ) {
		return _deltaCameraMatrix;
	}
	return GLKMatrix4Identity;
}
- (void)applyCameraDelta:(GLKMatrix4)deltaMatrix
{
	[self applyCameraDelta:deltaMatrix withNotification:YES];
}
- (void)applyCameraDelta:(GLKMatrix4)deltaMatrix withNotification:(BOOL)notify
{
	@synchronized(self) {
		if ( isnan( deltaMatrix.m00 ) || isinf(deltaMatrix.m00) || isnan(deltaMatrix.m30) || isinf(deltaMatrix.m30)) {
			NSLog(@"delta matrix contains nan ");
			return;
		}
		_deltaCameraMatrix = deltaMatrix;
		_hasDeltaCameraMatrix = YES;
		
		if (self.cameraChangeNotificationEnabled && notify ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(0), @"notify":@(1)} ];
		} else {
			//[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(0), @"notify":@(0)} ];
		}
	}
}

- (void)applyCameraDeltaCompleted:(GLKMatrix4)deltaMatrix
{
	[self applyCameraDeltaCompleted:deltaMatrix withNotification:YES];
}
- (void)applyCameraDeltaCompleted:(GLKMatrix4)deltaMatrix withNotification:(BOOL)notify
{
	@synchronized(self) {
		if ( isnan( deltaMatrix.m00 ) || isinf(deltaMatrix.m00) || isnan(deltaMatrix.m30) || isinf(deltaMatrix.m30)) {
			NSLog(@"delta matrix contains nan ");
			if ( !_hasDeltaCameraMatrix ) {
				_deltaCameraMatrix = GLKMatrix4Identity;
			}
		} else {
			_deltaCameraMatrix = deltaMatrix;
		}
		// To add your struct value to a NSMutableArray
		NSValue *value = [NSValue valueWithBytes:&_deltaCameraMatrix objCType:@encode(GLKMatrix4)];
		// camera delta motion appended at the end approach.
		//[_cameraMatrixList addObject:value];
		
		_hasDeltaCameraMatrix = NO;
		_deltaCameraMatrix = GLKMatrix4Identity;
		
		// camera delta pre-pended approach.
		[_cameraMatrixList insertObject:value atIndex:0];
		
		/*
		 // To retrieve the stored value
		 GLKMatrix4 matrix;
		 NSValue *value = [_cameraMatrixList objectAtIndex:0];
		 [value getValue:&matrix];
		 */
		
		if ( self.cameraChangeNotificationEnabled && notify ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1), @"notify":@(1)} ];
		} else {
			//[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1), @"notify":@(0)} ];
		}
		
		_cameraZoomFactorDelta_FOV = 1.0;
		_cameraZoomFactorDelta_Distance = 1.0;
	}
}

- (void)applyCameraDelta:(GLKMatrix4)deltaMatrix postpend:(BOOL)postpend
{
	@synchronized(self) {
		if ( isnan( deltaMatrix.m00 ) ) {
			NSLog(@"delta matrix contains nan ");
		}
		if ( postpend ) {
			_deltaCameraMatrix_forPostPend = deltaMatrix;
			_hasDeltaCameraMatrix_forPostPend = YES;
		} else {
			_deltaCameraMatrix = deltaMatrix;
			_hasDeltaCameraMatrix = YES;
		}
		
		if ( self.cameraChangeNotificationEnabled ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(0)} ];
		}
	}
}
- (void)applyCameraDeltaCompleted:(GLKMatrix4)deltaMatrix postpend:(BOOL)postpend
{
	@synchronized(self) {
		if ( isnan( deltaMatrix.m00 ) ) {
			NSLog(@"delta matrix contains nan ");
		}
		if ( postpend ) {
			_hasDeltaCameraMatrix_forPostPend = NO;
			_deltaCameraMatrix_forPostPend = GLKMatrix4Identity;
			// To add your struct value to a NSMutableArray
			NSValue *value = [NSValue valueWithBytes:&deltaMatrix objCType:@encode(GLKMatrix4)];
			// camera delta motion appended at the end approach.
			[_cameraMatrixList addObject:value];
			
		} else {
			_hasDeltaCameraMatrix = NO;
			_deltaCameraMatrix = GLKMatrix4Identity;
			// To add your struct value to a NSMutableArray
			NSValue *value = [NSValue valueWithBytes:&deltaMatrix objCType:@encode(GLKMatrix4)];
			
			// camera delta pre-pended approach.
			[_cameraMatrixList insertObject:value atIndex:0];
		}
		
		/*
		 // To retrieve the stored value
		 GLKMatrix4 matrix;
		 NSValue *value = [_cameraMatrixList objectAtIndex:0];
		 [value getValue:&matrix];
		 */
		
		if ( self.cameraChangeNotificationEnabled ) {
			[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1)} ];
		}
	}
}

- (BOOL)applyCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundsCenter
{
	BOOL isZoomingIn = scale > 1.0 + _epsilon ;
	BOOL isZoomingOut = scale < 1.0 - _epsilon ;
	
	GLKVector3 cameraPosition = [self getCameraPosition];
	//GLKVector3 boundsCenter = [self getBoundsCenter];
	float currentCameraDistance = GLKVector3Distance(cameraPosition, boundsCenter);
	float adjustedDistance = currentCameraDistance * ((_cameraZoomFactorDelta_Distance * _cameraZoomFactorDelta_FOV) / scale);
	float currentCameraFoV = GLKMathRadiansToDegrees([self getCameraFoV]);
	
	BOOL zoomByDistance = NO;
	BOOL zoomByFOV = NO;
	/**
	 float boundsMaxSize = [self getBoundsMaxSize];
	 if ( (adjustedDistance-(0.6f*boundsMaxSize)) < _nearPlane && isZoomingIn ) {
	 // when zoom in, zoom by fov if the camera pulls in near bounds center.
	 zoomByFOV = YES;
	 }*/
	
	//NSLog(@"camera : current = %0.4f, adj = %0.4f, focal = %0.4f", currentCameraDistance, adjustedDistance, _focalPlaneDistance);
	if ( isZoomingIn && ((currentCameraDistance - adjustedDistance + _epsilon) > (_focalPlaneDistance - 2.0*_nearPlane))) {
		// when zoom in, if not reaching the focal plane, use zoom by distance, otherwise, use zoom by fov.
		zoomByFOV = YES;
	}
	
	if ( isZoomingIn && currentCameraFoV > _defaultFovInDegree) {
		zoomByFOV = YES;
	}
	
	if ( isZoomingOut && currentCameraFoV < _defaultFovInDegree) {
		zoomByFOV = YES;
	}
	
	if ( useFov || !self.cameraPerspective ) {
		// under orthographic view, moving in distance does not have zoom effect.
		zoomByFOV = YES;
	}
	
	if ( !zoomByFOV && (isZoomingIn || isZoomingOut) ) zoomByDistance = YES;
	
	// guarding zoom content out of frustum
	if ( zoomByDistance && isZoomingOut && adjustedDistance > _farPlane ) {
		zoomByDistance = NO;
	}
	
	if ( zoomByDistance ) {
		
		float tmpDelta = _cameraZoomFactorDelta_Distance / scale;
		_deltaDistanceZoomed = currentCameraDistance * (1.0 - (tmpDelta));
		_deltaCameraMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, _deltaDistanceZoomed);
		
		_hasDeltaCameraMatrix = YES;
		_hasDeltaZoomFactor_Distance = YES;
		_cameraZoomFactorDelta_Distance = tmpDelta;
		//NSLog(@"zooming distance, fov : %0.2f°, scale: %@, %f, delta fov : %0.2f, dis: %0.2f", currentCameraFoVInDegree, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
		//NSLog(@"zooming distance, fov : %0.2f°, scale: %@, %f, dis : %0.2f, boundsMaxSize: %0.2f, _nearPlane %0.2f, check: %0.2f", currentCameraFoV, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, boundsMaxSize, _nearPlane, (adjustedDistance-boundsMaxSize) );
		
	}
	
	if ( zoomByFOV ) {
		float tmpDelta = _cameraZoomFactorDelta_FOV / scale;
		
		_hasDeltaZoomFactor_FOV = YES;
		_cameraZoomFactorDelta_FOV = tmpDelta;
		//NSLog(@"zooming FOV, fov : %0.2f°, scale: %@, %f, adj dis: %0.2f, delta fovd : %0.2f, disd: %0.2f", currentCameraFoVInDegree, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
		//NSLog(@"zooming FOV, fov : %0.2f°, scale: %@, %f, adj dis: %0.2f, boundsMaxSize : %0.2f", currentCameraFoV, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, boundsMaxSize);
		
		// stablize the current fov to avoid oscillation between _defaultFovInDegree
		if ( (isZoomingIn && currentCameraFoV > _defaultFovInDegree && GLKMathRadiansToDegrees([self getCameraFoV]) < _defaultFovInDegree )
			|| ( isZoomingOut && currentCameraFoV < _defaultFovInDegree && GLKMathRadiansToDegrees([self getCameraFoV]) > _defaultFovInDegree ) ) {
			_cameraZoomFactorDelta_FOV = 1.0 / _cameraZoomFactor ;
		}
	}
	
	if ( self.cameraChangeNotificationEnabled ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(0)} ];
	}
	
	return zoomByFOV || zoomByDistance ;
}

- (BOOL)applyCameraZoomFactorCompleted:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundCenter
{
	@synchronized(self) {
		[self applyCameraZoomFactorDelta:scale fovOnly:useFov usingReferenceBoundsCenter:boundCenter];
		if (_hasDeltaZoomFactor_FOV) {
			_hasDeltaZoomFactor_FOV = NO;
			self.cameraZoomFactor = _cameraZoomFactor * _cameraZoomFactorDelta_FOV;
		}
		_cameraZoomFactorDelta_FOV = 1.0;
		if (_hasDeltaZoomFactor_Distance) {
			_hasDeltaZoomFactor_Distance = NO;
			[self applyCameraDeltaCompleted:_deltaCameraMatrix];
			
			//cater for focal plane changes when zoom by distance. ie. maintain focal plane fix at world coord when zoom by distance.
			// note: the above applyCameraDeltaCompleted will calculate _deltaDistanceZoomed, if zoom by distance.
			_focalPlaneDistance -= _deltaDistanceZoomed;
		}
		_cameraZoomFactorDelta_Distance = 1.0;
		if ( _hasDeltaCameraMatrix ) {
			// last catching
			[self applyCameraDeltaCompleted:_deltaCameraMatrix];
		}
		//NSLog(@"zoomed, fov : %0.2f°, scale: %0.6f, delta fov : %0.2f, dis: %0.2f", GLKMathRadiansToDegrees([self getCameraFoV]), scale, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
	}
	
	if ( self.cameraChangeNotificationEnabled ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1)} ];
	}
	
	return _hasDeltaZoomFactor_FOV || _hasDeltaZoomFactor_Distance ;
}

- (GLKMatrix4)computeCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundCenter resultFOV:(CGFloat *)resultDeltaFovZoomFactor
{
	GLKMatrix4 resultMatrix = GLKMatrix4Identity;
	
	BOOL isZoomingIn = scale > 1.0 + _epsilon ;
	BOOL isZoomingOut = scale < 1.0 - _epsilon ;
	
	GLKVector3 cameraPosition = [self getCameraPosition];
	//GLKVector3 boundsCenter = [self getBoundsCenter];
	float currentCameraDistance = GLKVector3Distance(cameraPosition, boundCenter);
	float adjustedDistance = currentCameraDistance * ((_cameraZoomFactorDelta_Distance * _cameraZoomFactorDelta_FOV) / scale);
	float currentCameraFoV = GLKMathRadiansToDegrees([self getCameraFoV]);
	
	BOOL zoomByDistance = NO;
	BOOL zoomByFOV = NO;
	/**
	 float boundsMaxSize = [self getBoundsMaxSize];
	 if ( (adjustedDistance-(0.6f*boundsMaxSize)) < _nearPlane && isZoomingIn ) {
	 // when zoom in, zoom by fov if the camera pulls in near bounds center.
	 zoomByFOV = YES;
	 }*/
	
	//NSLog(@"camera : current = %0.4f, adj = %0.4f, focal = %0.4f", currentCameraDistance, adjustedDistance, _focalPlaneDistance);
	if ( isZoomingIn && ((currentCameraDistance - adjustedDistance + _epsilon) > (_focalPlaneDistance - 2.0*_nearPlane))) {
		// when zoom in, if not reaching the focal plane, use zoom by distance, otherwise, use zoom by fov.
		zoomByFOV = YES;
	}
	
	if ( isZoomingIn && currentCameraFoV > _defaultFovInDegree) {
		zoomByFOV = YES;
	}
	
	if ( isZoomingOut && currentCameraFoV < _defaultFovInDegree) {
		zoomByFOV = YES;
	}
	
	if ( useFov || !self.cameraPerspective ) {
		// under orthographic view, moving in distance does not have zoom effect.
		zoomByFOV = YES;
	}
	
	if ( !zoomByFOV && (isZoomingIn || isZoomingOut) ) zoomByDistance = YES;
	
	// guarding zoom content out of frustum
	if ( zoomByDistance && isZoomingOut && adjustedDistance > _farPlane ) {
		zoomByDistance = NO;
	}
	
	if ( zoomByDistance ) {
		
		float tmpDelta = _cameraZoomFactorDelta_Distance / scale;
		_deltaDistanceZoomed = currentCameraDistance * (1.0 - (tmpDelta));
		resultMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, _deltaDistanceZoomed);
		
		//_hasDeltaCameraMatrix = YES;
		//_hasDeltaZoomFactor_Distance = YES;
		_cameraZoomFactorDelta_Distance = tmpDelta;
		//NSLog(@"zooming distance, fov : %0.2f°, scale: %@, %f, delta fov : %0.2f, dis: %0.2f", currentCameraFoVInDegree, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
		//NSLog(@"zooming distance, fov : %0.2f°, scale: %@, %f, dis : %0.2f, boundsMaxSize: %0.2f, _nearPlane %0.2f, check: %0.2f", currentCameraFoV, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, boundsMaxSize, _nearPlane, (adjustedDistance-boundsMaxSize) );
		
	}
	
	if ( zoomByFOV ) {
		float tmpDelta = _cameraZoomFactorDelta_FOV / scale;
		
		if ( resultDeltaFovZoomFactor ) {
			*resultDeltaFovZoomFactor = tmpDelta;
		}
		
		//_hasDeltaZoomFactor_FOV = YES;
		_cameraZoomFactorDelta_FOV = tmpDelta;
		//NSLog(@"zooming FOV, fov : %0.2f°, scale: %@, %f, adj dis: %0.2f, delta fovd : %0.2f, disd: %0.2f", currentCameraFoVInDegree, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
		//NSLog(@"zooming FOV, fov : %0.2f°, scale: %@, %f, adj dis: %0.2f, boundsMaxSize : %0.2f", currentCameraFoV, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, boundsMaxSize);
		
		// stablize the current fov to avoid oscillation between _defaultFovInDegree
		if ( (isZoomingIn && currentCameraFoV > _defaultFovInDegree && GLKMathRadiansToDegrees([self getCameraFoV]) < _defaultFovInDegree )
			|| ( isZoomingOut && currentCameraFoV < _defaultFovInDegree && GLKMathRadiansToDegrees([self getCameraFoV]) > _defaultFovInDegree ) ) {
			*resultDeltaFovZoomFactor = 1.0 / _cameraZoomFactor ;
		}
	}
	
	return resultMatrix ;
}


- (BOOL)applyCameraZoomFactorDelta:(float)scale
{
	return [self applyCameraZoomFactorDelta:scale fovOnly:NO];
}
- (BOOL)applyCameraZoomFactorCompleted:(float)scale
{
	return [self applyCameraZoomFactorCompleted:scale fovOnly:NO];
}
- (BOOL)applyCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov
{
	GLKVector3 boundsCenter = [self.delegate getBoundsCenter];
	return [self applyCameraZoomFactorDelta:scale fovOnly:useFov usingReferenceBoundsCenter: boundsCenter ];
}
- (BOOL)applyCameraZoomFactorCompleted:(float)scale fovOnly:(BOOL)useFov
{
	GLKVector3 boundsCenter = [self.delegate getBoundsCenter];
	return [self applyCameraZoomFactorCompleted:scale fovOnly:useFov usingReferenceBoundsCenter: boundsCenter ];
}
// ------------------------------------------------------------------------------

// similar to methods without deviateInView
- (BOOL)applyCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundsCenter deviateInView:(GLKVector2)deviateInView
{
	BOOL isZoomingIn = scale > 1.0;
	BOOL isZoomingOut = ! isZoomingIn ;
	
	GLKVector3 cameraPosition = [self getCameraPosition];
	//GLKVector3 boundsCenter = [self getBoundsCenter];
	float currentCameraDistance = GLKVector3Distance(cameraPosition, boundsCenter);
	float adjustedDistance = currentCameraDistance * ((_cameraZoomFactorDelta_Distance * _cameraZoomFactorDelta_FOV) / scale);
	float currentCameraFoV = GLKMathRadiansToDegrees([self getCameraFoV]);
	
	BOOL zoomByDistance = NO;
	BOOL zoomByFOV = NO;
	/**
	 float boundsMaxSize = [self getBoundsMaxSize];
	 if ( (adjustedDistance-(0.6f*boundsMaxSize)) < _nearPlane && isZoomingIn ) {
	 // when zoom in, zoom by fov if the camera pulls in near bounds center.
	 zoomByFOV = YES;
	 }*/
	
	//NSLog(@"camera : current = %0.4f, adj = %0.4f, focal = %0.4f", currentCameraDistance, adjustedDistance, _focalPlaneDistance);
	if ( isZoomingIn && ((currentCameraDistance - adjustedDistance + _epsilon) > (_focalPlaneDistance - 2.0*_nearPlane))) {
		// when zoom in, if not reaching the focal plane, use zoom by distance, otherwise, use zoom by fov.
		zoomByFOV = YES;
	}
	
	if ( isZoomingIn && currentCameraFoV > _defaultFovInDegree) {
		zoomByFOV = YES;
	}
	
	if ( isZoomingOut && currentCameraFoV < _defaultFovInDegree) {
		zoomByFOV = YES;
	}
	
	if ( useFov || !self.cameraPerspective ) {
		// under orthographic view, moving in distance does not have zoom effect.
		zoomByFOV = YES;
	}
	
	if ( !zoomByFOV && (isZoomingIn || isZoomingOut) ) zoomByDistance = YES;
	
	// guarding zoom content out of frustum
	if ( zoomByDistance && isZoomingOut && adjustedDistance > _farPlane ) {
		zoomByDistance = NO;
	}
	
	// new approach, cater deviate center of zoom
	// compute screen vector in camera space
	GLKMatrix4 deltaDeviate = GLKMatrix4Identity;
	BOOL hasDeviate = NO;
	if (deviateInView.x != 0 || deviateInView.y != 0) {
		//NSLog(@"movement in view space: %0.4f, %0.4, %0.4f", movedVectorInViewSpace.x, movedVectorInViewSpace.y, movedVectorInViewSpace.z);
		
		GLint viewport[4] = { self.cameraInfo.viewPort.origin.x, self.cameraInfo.viewPort.origin.y, self.cameraInfo.viewPort.size.width, self.cameraInfo.viewPort.size.height };
		{
			CGFloat xFov = [self getCameraFoV];
			if ( self.cameraPerspective ) {
				// 0.8 is visual adjustment to the arc effect.
				CGFloat angleInX = (deviateInView.x / (viewport[2] * 0.8)) * xFov;
				CGFloat angleInY = (deviateInView.y / (viewport[3] * 0.8)) * (xFov / (self.aspectRatio));
				deltaDeviate = GLKMatrix4MakeRotation( angleInX, 0, -1, 0);
				deltaDeviate = GLKMatrix4Rotate(deltaDeviate, angleInY, 1, 0, 0);
				//NSLog(@"radians, xy : %0.3f, %0.3f, %d, byD %d, byFov %d", angleInX, angleInY, _hasDeltaCameraMatrix, zoomByDistance, zoomByFOV);
			} else {
				GLKMatrix4 viewMatrix = [self getCameraMatrix:NO];
				
				GLKVector3 screenCenterInWC = [self pointFromTouchWithoutDeltaCamera: GLKVector3Make( viewport[2]*0.5, viewport[3]*0.5, 0)];
				GLKVector3 deviateInWC = [self pointFromTouchWithoutDeltaCamera: GLKVector3Make( deviateInView.x+viewport[2]*0.5, deviateInView.y+viewport[3]*0.5, 0)];
				
				GLKVector3 vectorInWC = GLKVector3Subtract( deviateInWC, screenCenterInWC );
				GLKVector3 vectorInView = GLKMatrix4MultiplyVector3( viewMatrix, vectorInWC);
				
				deltaDeviate = GLKMatrix4MakeTranslation( vectorInView.x, vectorInView.y, 0);
				//NSLog(@"deviate, xy : %0.3f, %0.3f, %d, byD %d, byFov %d", deviateInX, deviateInY, _hasDeltaCameraMatrix, zoomByDistance, zoomByFOV);
			}
			
			hasDeviate = YES;
		}
	}
	
	if ( zoomByDistance ) {
		
		float tmpDelta = _cameraZoomFactorDelta_Distance / scale;
		_deltaDistanceZoomed = currentCameraDistance * (1.0 - (tmpDelta));
		_deltaCameraMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, _deltaDistanceZoomed);
		
		if ( hasDeviate ) {
			_deltaCameraMatrix = GLKMatrix4Multiply( deltaDeviate, _deltaCameraMatrix );
		}
		
		_hasDeltaCameraMatrix = YES;
		_hasDeltaZoomFactor_Distance = YES;
		_cameraZoomFactorDelta_Distance = tmpDelta;
		//NSLog(@"zooming distance, fov : %0.2f°, scale: %@, %f, delta fov : %0.2f, dis: %0.2f", currentCameraFoVInDegree, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
		//NSLog(@"zooming distance, fov : %0.2f°, scale: %@, %f, dis : %0.2f, boundsMaxSize: %0.2f, _nearPlane %0.2f, check: %0.2f", currentCameraFoV, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, boundsMaxSize, _nearPlane, (adjustedDistance-boundsMaxSize) );
		
	}
	
	if ( hasDeviate && !zoomByDistance ) {
		if ( _hasDeltaZoomFactor_Distance ) {
			_deltaCameraMatrix = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, _deltaDistanceZoomed);
			_deltaCameraMatrix = GLKMatrix4Multiply( deltaDeviate, _deltaCameraMatrix );
		} else {
			_deltaCameraMatrix = deltaDeviate;
		}
		_hasDeltaCameraMatrix = YES;
	}
	
	if ( zoomByFOV ) {
		if ( !self.cameraPerspective ) {
			scale = [self convertToOrthoViewSizeScale: scale];
		}
		float tmpDelta = _cameraZoomFactorDelta_FOV / scale;
		
		_hasDeltaZoomFactor_FOV = YES;
		_cameraZoomFactorDelta_FOV = tmpDelta;
		//NSLog(@"zooming FOV, fov : %0.2f°, scale: %@, %f, adj dis: %0.2f, delta fovd : %0.2f, disd: %0.2f", GLKMathRadiansToDegrees([self getCameraFoV]), isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
		//NSLog(@"zooming FOV, fov : %0.2f°, scale: %@, %f, adj dis: %0.2f, boundsMaxSize : %0.2f", currentCameraFoV, isZoomingIn?@"isZoomingIn":(isZoomingOut?@"isZoomingOut":@"nil"), scale, adjustedDistance, boundsMaxSize);
		
		// stablize the current fov to avoid oscillation between _defaultFovInDegree
		if ( (isZoomingIn && currentCameraFoV > _defaultFovInDegree && GLKMathRadiansToDegrees([self getCameraFoV]) < _defaultFovInDegree )
			|| ( isZoomingOut && currentCameraFoV < _defaultFovInDegree && GLKMathRadiansToDegrees([self getCameraFoV]) > _defaultFovInDegree ) ) {
			_cameraZoomFactorDelta_FOV = 1.0 / _cameraZoomFactor ;
		}
	}
	
	if ( self.cameraChangeNotificationEnabled ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(0)} ];
	}
	
	return zoomByFOV || zoomByDistance ;
}

- (BOOL)applyCameraZoomFactorCompleted:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundCenter deviateInView:(GLKVector2)deviateInView
{
	@synchronized(self) {
		[self applyCameraZoomFactorDelta:scale fovOnly:useFov usingReferenceBoundsCenter:boundCenter deviateInView: deviateInView];
		if (_hasDeltaZoomFactor_FOV) {
			_hasDeltaZoomFactor_FOV = NO;
			self.cameraZoomFactor = _cameraZoomFactor * _cameraZoomFactorDelta_FOV;
		}
		_cameraZoomFactorDelta_FOV = 1.0;
		if (_hasDeltaZoomFactor_Distance) {
			_hasDeltaZoomFactor_Distance = NO;
			[self applyCameraDeltaCompleted:_deltaCameraMatrix];
			
			//cater for focal plane changes when zoom by distance. ie. maintain focal plane fix at world coord when zoom by distance.
			// note: the above applyCameraDeltaCompleted will calculate _deltaDistanceZoomed, if zoom by distance.
			_focalPlaneDistance -= _deltaDistanceZoomed;
		}
		_cameraZoomFactorDelta_Distance = 1.0;
		if ( _hasDeltaCameraMatrix ) {
			// last catching
			[self applyCameraDeltaCompleted:_deltaCameraMatrix];
		}
		//NSLog(@"zoomed, fov : %0.2f°, scale: %0.6f, delta fov : %0.2f, dis: %0.2f", GLKMathRadiansToDegrees([self getCameraFoV]), scale, _cameraZoomFactorDelta_FOV, _cameraZoomFactorDelta_Distance);
	}
	
	if ( self.cameraChangeNotificationEnabled ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1)} ];
	}
	
	return _hasDeltaZoomFactor_FOV || _hasDeltaZoomFactor_Distance ;
}
- (BOOL)applyCameraZoomFactorDelta:(float)scale deviateInView:(GLKVector2)deviateInView
{
	return [self applyCameraZoomFactorDelta:scale fovOnly:NO deviateInView:(GLKVector2)deviateInView];
}
- (BOOL)applyCameraZoomFactorCompleted:(float)scale deviateInView:(GLKVector2)deviateInView
{
	return [self applyCameraZoomFactorCompleted:scale fovOnly:NO deviateInView:(GLKVector2)deviateInView];
}
- (BOOL)applyCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov deviateInView:(GLKVector2)deviateInView
{
	GLKVector3 boundsCenter = [self.delegate getBoundsCenter];
	return [self applyCameraZoomFactorDelta:scale fovOnly:useFov usingReferenceBoundsCenter: boundsCenter  deviateInView:(GLKVector2)deviateInView];
}
- (BOOL)applyCameraZoomFactorCompleted:(float)scale fovOnly:(BOOL)useFov deviateInView:(GLKVector2)deviateInView
{
	GLKVector3 boundsCenter = [self.delegate getBoundsCenter];
	return [self applyCameraZoomFactorCompleted:scale fovOnly:useFov usingReferenceBoundsCenter: boundsCenter  deviateInView:(GLKVector2)deviateInView];
}

// ------------------------------------------------------------------------------

- (void)moveCameraForwardDelta:(float)deltaDist
{
	@synchronized(self) {
		_deltaDistanceMoved = deltaDist;
		_hasDeltaForwardDistance = YES;
	}
	GLKMatrix4 delta = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, deltaDist);
	[self applyCameraDelta:delta];
}

- (void)moveCameraForwardDeltaCompleted:(float)deltaDist
{
	@synchronized(self) {
		_deltaDistanceMoved = deltaDist;
		_hasDeltaForwardDistance = YES;
		[self adjustedFocalPlaneDistance:YES];
		_hasDeltaForwardDistance = NO;
	}
	GLKMatrix4 delta = GLKMatrix4Translate(GLKMatrix4Identity, 0.0, 0.0, deltaDist);
	[self applyCameraDeltaCompleted:delta];
}

- (void)rotateCameraDelta:(GLKQuaternion)quaternion
{
	@synchronized(self) {
		_deltaCameraQuaternionMatrix = GLKMatrix4MakeWithQuaternion(quaternion);
		_hasDeltaCameraQuaternion = YES;
	}
	
	if ( self.cameraChangeNotificationEnabled ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(0)} ];
	}
	
}

- (void)rotateCameraDeltaCompleted:(GLKQuaternion)quaternion
{
	@synchronized(self) {
		_deltaCameraQuaternionMatrix = GLKMatrix4MakeWithQuaternion(quaternion);
		NSValue *value = [NSValue valueWithBytes:&_deltaCameraQuaternionMatrix objCType:@encode(GLKMatrix4)];
		[_cameraMatrixList insertObject:value atIndex:0];
		//[_cameraMatrixList addObject:value];
		_hasDeltaCameraQuaternion = NO;
	}
	
	if ( self.cameraChangeNotificationEnabled ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1)} ];
	}
	
}

- (GLKMatrix4)undoCameraDelta
{
	GLKMatrix4 result = GLKMatrix4Identity;
	@synchronized(self) {
		if (_cameraMatrixList.count > 1) {
			//NSValue *value = [_cameraMatrixList lastObject];
			//[_cameraMatrixList removeLastObject];
			NSValue *value = [_cameraMatrixList firstObject];
			[_cameraMatrixList removeObjectAtIndex:0];
			GLKMatrix4 matrix;
			[value getValue:&matrix];
			
			if ( self.cameraChangeNotificationEnabled ) {
				[[NSNotificationCenter defaultCenter] postNotificationName:SPVNotificationCameraChanged object:self userInfo:@{@"isCompleted":@(1)} ];
			}
			
			result = matrix;
		}
	}
	
	if ( self.getCameraMoveCount <= 1 ) {
		continuousUndoCameraDelta = NO;
	}
	
	if ( !continuousUndoCameraDelta ) {
		if (undoTimer != nil) {
			[undoTimer invalidate];
			undoTimer = nil;
		}
	}

	return result;
}

- (void)continusTumbleCameraDelta
{
	@synchronized( panSwipeTimer) {
		if ( timerCount < 500 && !_cameraInAction && panSwipeTimer != nil && [panSwipeTimer isValid]) {
			if (continuousTumbling) {
				float movedDistance = GLKVector2Length(panDirection);
				if (movedDistance > _epsilon) {
					float t = panSwipeTimer.timeInterval * (1+timerCount);
					GLKVector2 acceleration = GLKVector2MultiplyScalar( GLKVector2Normalize(initialVelocity), -1550);
					//GLKVector2 acceleration = GLKVector2MultiplyScalar( GLKVector2Normalize(initialVelocity), -3550);
					// initialVelocity * t + 0.5 * acceleration * t * t;
					panDirection = GLKVector2Add( GLKVector2MultiplyScalar( initialVelocity, t) , GLKVector2MultiplyScalar( acceleration, 0.5 * t * t) );
					GLKVector2 lastVelocity = GLKVector2Add( initialVelocity , GLKVector2MultiplyScalar(acceleration, panSwipeTimer.timeInterval * (1+1+timerCount)) );
					BOOL willVelocityTurnDirection = GLKVector2DotProduct(lastVelocity, initialVelocity) < 0.0;
					//NSLog(@"continue tumbling with direction : %@, Vf %@, mag: %f, turned %d", NSStringFromGLKVector2(panDirection), NSStringFromGLKVector2(lastVelocity), GLKVector2Length(lastVelocity), willTurnDirection);
					if (!willVelocityTurnDirection) {
						NSString *userInfo = [panSwipeTimer userInfo];
						if ([userInfo isEqualToString:@"tumble"]) {
							GLKMatrix4 delta = [self tumbleWithTimer];
							lastDeltaContinue = delta;
							[self applyCameraDelta:lastDeltaContinue];
						} else if ([userInfo isEqualToString:@"tumble_turntable"]) {
							GLKMatrix4 delta2;
							GLKMatrix4 delta = [self tumbleTurntableWithTimer_AdditionalResult:&delta2];
							lastDeltaContinue = delta;
							lastDeltaContinue2 = delta2;
							[self applyCameraDelta:lastDeltaContinue];
							// use approach 2 for turntable, so, no need to postpend delta2 matrix
							//[self applyCameraDelta:lastDeltaContinue2 postpend:YES];
						} else if ([userInfo isEqualToString:@"rotate"]) {
							GLKMatrix4 delta = [self rotateWithTimer];
							lastDeltaContinue = delta;
							[self applyCameraDelta:lastDeltaContinue];
						}
						timerCount++;
					} else {
						// completes animation because velocity vector turned direction.
						NSString *userInfo = [panSwipeTimer userInfo];
						if ([userInfo isEqualToString:@"tumble"]) {
							GLKMatrix4 delta = [self tumbleWithTimer];
							lastDeltaContinue = delta;
							[self applyCameraDeltaCompleted:lastDeltaContinue];
							// spring back the locked viewing direction before tumbling.
							if ( self.lockingTumbling ) {
								[self springCameraBackToLockingDirection];
							}
						} else if ([userInfo isEqualToString:@"tumble_turntable"]) {
							GLKMatrix4 delta2;
							GLKMatrix4 delta = [self tumbleTurntableWithTimer_AdditionalResult:&delta2];
							lastDeltaContinue = delta;
							lastDeltaContinue2 = delta2;
							[self applyCameraDeltaCompleted:lastDeltaContinue];
							// use approach 2 for turntable, so, no need to postpend delta2 matrix
							//[self applyCameraDeltaCompleted:lastDeltaContinue2 postpend:YES];
							// spring back the locked viewing direction before tumbling.
							if ( self.lockingTumbling ) {
								[self springCameraBackToLockingDirection];
							}
						} else if ([userInfo isEqualToString:@"rotate"]) {
							GLKMatrix4 delta = [self rotateWithTimer];
							lastDeltaContinue = delta;
							[self applyCameraDeltaCompleted:lastDeltaContinue];
						}
						continuousTumbling = NO;
					}
					//NSLog(@"continue tumbling completed with direction : %@", NSStringFromGLKVector2(panDirection));
				} else {
					continuousTumbling = NO;
				}
			}
		} else {
			float movedDistance = GLKVector2Length(panDirection);
			if (movedDistance > _epsilon) {
				[self applyCameraDeltaCompleted:lastDeltaContinue];
				if (self.orbitStyleTurntable) {
					// use approach 2 for turntable, so, no need to postpend delta2 matrix
					//[self applyCameraDeltaCompleted:lastDeltaContinue2 postpend:YES];
				}
				//NSLog(@"continue tumbling ended with direction : %@", NSStringFromGLKVector2(panDirection));
			}
			
			continuousTumbling = NO;
		}
		
		if ( !continuousTumbling ) {
			[panSwipeTimer invalidate];
			panSwipeTimer = nil;
		}
		
	}
}

- (void)stopContinuousTumbling
{
	@synchronized(panSwipeTimer) {
		if (continuousTumbling) {
			//NSLog(@"stopContinuousTumbling");
			[panSwipeTimer invalidate];		// Note! This is important, otherwise, the timer any trigger again and become jerky.
			continuousTumbling = NO;
			[self continusTumbleCameraDelta];
		}
	}
}

- (GLKMatrix4)tumbleWithTimer
{
	GLKMatrix4 delta = GLKMatrix4Identity;
	// opengl y axis is up.
	GLKVector2 direction = GLKVector2Make( panDirection.x, -panDirection.y );
	float radians;
	float movedDistance = GLKVector2Length(direction);
	// checking EPSILON to guard against initial flicker due to small rotation.
	if (movedDistance > _epsilon) {
		//float cameraDistance = GLKVector3Distance([self getCameraPosition], self.focalPlane);
		float cameraDistance = self.adjustedFocalPlaneDistance;
		float cameraFov = [self getCameraFoV];
		float viewSize = 2.0*cameraDistance * tanf(cameraFov/2.0);
		float modelSize = [self.delegate getBoundsMaxSize];
		direction = GLKVector2Normalize(direction);
		if (viewSize < modelSize && cameraFov < SMALL_MOVEMENT_FOR_FOV) {
			// adjust tumbling radians acoording to fov.
			radians = atan2f(viewSize, modelSize) *movedDistance/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*2.0);
		} else {
			radians = M_PI *movedDistance/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*4.0);
		}
		GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radians, direction.y, -direction.x, 0.0 );
		
		// new implementation: use focal plane for tumbling.
		float viewTumblingDistance = cameraDistance;
		delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -viewTumblingDistance);
		delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
		delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, viewTumblingDistance);
		if ( isnan( delta.m00 ) ) {
			NSLog(@"delta matrix contains nan ");
		}
	}
	return delta;
}

- (GLKMatrix4)tumbleTurntableWithTimer_AdditionalResult:(GLKMatrix4*)result2
{
	GLKMatrix4 delta = GLKMatrix4Identity, delta2 = GLKMatrix4Identity;
	// opengl y axis is up.
	GLKVector2 direction = GLKVector2Make( panDirection.x, -panDirection.y );
	float radians, radians2;
	float movedDistance = GLKVector2Length(direction);
	// checking EPSILON to guard against initial flicker due to small rotation.
	if (movedDistance > _epsilon) {
		//float cameraDistance = GLKVector3Distance([self getCameraPosition], self.focalPlane);
		float cameraDistance = self.adjustedFocalPlaneDistance;
		float cameraFov = [self getCameraFoV];
		float viewSize = 2.0*cameraDistance * tanf(cameraFov/2.0);
		float modelSize = [self.delegate getBoundsMaxSize];
		if (viewSize < modelSize && cameraFov < SMALL_MOVEMENT_FOR_FOV) {
			// adjust tumbling radians acoording to fov.
			radians = atan2f(viewSize, modelSize) *direction.y/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*1.0);
			radians2 = atan2f(viewSize, modelSize) *direction.x/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*1.0);
		} else {
			radians = M_PI *direction.y/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*2.0);
			radians2 = M_PI *direction.x/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*2.0);
		}
		direction = GLKVector2Normalize(direction);
		
		/*
		 GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radians, -1.0, 0.0, 0.0 );
		 
		 // new implementation: use focal plane for tumbling.
		 float viewTumblingDistance = cameraDistance;
		 delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -viewTumblingDistance);
		 delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
		 delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, viewTumblingDistance);
		 
		 delta2 = GLKMatrix4MakeRotation(-radians2, 0.0, 0.0, -1.0);
		 */
		
		delta = [self computeDeltaTumbling: radians horizontalRadians:radians2 withCamera: _lastCameraInfoAtGestureBegan];
	}
	
	*result2 = delta2;
	return delta;
}

- (GLKMatrix4)rotateWithTimer
{
	GLKMatrix4 delta = GLKMatrix4Identity;
	GLKVector3 rotateAxis = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make(0.0f, 0.0f, -1.0f));
	GLKVector2 direction = GLKVector2Make( panDirection.x, panDirection.y );
	GLKVector3 v1 = GLKVector3Make(_lastTouch.x - 2*ONE_FOURTH_WIDTH, _lastTouch.y - 2*ONE_FOURTH_WIDTH, 0.0);
	GLKVector3 v2 = GLKVector3Add(v1, GLKVector3Make( direction.x, direction.y, 0.0));
	GLKVector3 crossed = GLKVector3CrossProduct(v1, v2);
	GLKVector3 zDir = GLKVector3Make(0.0, 0.0, 1.0);
	float movedDistance = GLKVector2Length(panDirection) * (GLKVector3DotProduct(crossed, zDir)>0?1.0:-1.0);
	float radians = M_PI * movedDistance/(ONE_FOURTH_WIDTH*4.0);
	if ( ! isnan(radians) ) {
		delta = GLKMatrix4RotateWithVector3(delta, radians, rotateAxis);
	}
	return delta;
}


// ---------------------------------------------------------------------
- (float)getApparentViewingModelSize
{
	float cameraFov = [self getCameraFoV];
	
	float viewSize;
	if (self.cameraPerspective) {
		viewSize = 2.0 * self.focalPlaneDistance * tanf(cameraFov/2.0);
	} else {
		viewSize = 2.0 * self.nearPlane * tanf(cameraFov/2.0);
	}
	float modelSize = [self.delegate getBoundsMaxSize];
	return atan2f(viewSize, modelSize) ;
}

// refactor to CameraOperator
- (float)convertToOrthoViewSizeScale:(float)fovScale
{
	float orphoViewSizeScale = 1.0;
	float currentFov = [self getCameraFoV];
	float viewHalfSize = _nearPlane * tanf(currentFov/2.0);
	viewHalfSize /= fovScale;
	float newFoV = atanf( viewHalfSize/ _nearPlane ) * 2.0;
	orphoViewSizeScale = currentFov / newFoV;
	return orphoViewSizeScale;
}

// refactor to CameraOperator
- (BOOL)isModelOutOfView
{
	GLKVector3 modelCenter = [self.delegate getBoundsCenter];
	//float modelSize = [self getBoundsMaxSize];
	float modelSize = [self.delegate getBoundsMaxSize] * 0.6;  // 60%
	
	float currentFov = [self getCameraFoV];
	
	GLKMatrix4 invertedCamera = [self getCameraInverse];
	GLKVector3 cameraPositionInWC = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f)).v);
	GLKVector3 cameraViewDirection = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, -1.0f, 0.0f)).v);
	
	GLKVector3 vectorToCenter = GLKVector3Subtract(modelCenter, cameraPositionInWC);
	float distanceToModelCenter = GLKVector3DotProduct(vectorToCenter, cameraViewDirection);
	
	if ( self.focalPlaneDistance <= 0 ) return YES;
	if ( distanceToModelCenter < (self.nearPlane - modelSize)) return YES;
	if ( distanceToModelCenter > (self.farPlane + modelSize)) return YES;
	
	CGFloat radian = acosf( GLKVector3DotProduct(GLKVector3Normalize( vectorToCenter ), cameraViewDirection) );
	if ( self.cameraPerspective ) {
		if ( distanceToModelCenter * tanf( currentFov/2.0 ) < (distanceToModelCenter * tanf( radian ) - modelSize) ) {
			return YES;
		}
	} else {
		if ( self.nearPlane * tanf( currentFov/2.0 ) < (distanceToModelCenter * tanf( radian ) - modelSize) ) {
			return YES;
		}
	}
	
	if ( currentFov >= ( M_PI - _epsilon ) ) {
		return YES;
	}
	
	return NO;
}

- (void)adjustCameraToCenterOnBounds:(NSArray *)minmax
{
	//NSArray *minmax = [wavefrontObjectModel getBounds];
	//NSLog(@"model bounds %@", minmax);
	if ( minmax && [minmax count] == 2) {
		GLKVector3 min, max ;
		[[minmax objectAtIndex:0] getValue:&min];
		[[minmax objectAtIndex:1] getValue:&max];
		float xsize = max.x - min.x;
		float ysize = max.y - min.y;
		float zsize = max.z - min.z;
		GLKVector3 mid = GLKVector3DivideScalar(GLKVector3Add(min, max), 2.0);
		float maxsize = MAX(MAX(xsize, ysize), zsize);
		if ( max.x > min.x && max.y > min.y && max.z > min.z ) {
			float distance = maxsize + ((maxsize)) / tanf(GLKMathDegreesToRadians( _defaultFovInDegree/2.0 )) ;
			if ( (distance*2) > _farPlane) _farPlane = distance * 2;
			if ( _farPlane < 100.0f) _farPlane = 100.0f;
			// setting near plane to be greater than 1.0 will clip front objects when inside a building.
			//_nearPlane = distance - 1.5*maxsize;
			_nearPlane = 1.0;
			if ( distance - 1.5*maxsize < _nearPlane ) _nearPlane = distance - 1.5*maxsize;
			if (_nearPlane < 0.01) _nearPlane = 0.01;
			NSLog(@"adjust camera distance : %0.0f, near/far : (%0.5f, %0.5f)", distance, _nearPlane, _farPlane);
			if ( distance > 10000 ) {
				NSLog(@"distance too far : %0.0f", distance);
			}
			
			GLKMatrix4 lookat = GLKMatrix4MakeLookAt(mid.x, mid.y, mid.z + distance, mid.x, mid.y, mid.z, 0.0, 1.0, 0.0);
			//GLKMatrix4 lookat = GLKMatrix4MakeLookAt(mid.x, mid.y - distance, mid.z, mid.x, mid.y, mid.z, 0.0, 0.0, 1.0);
			NSLog(@"model bounds min %@ to max %@", NSStringFromGLKVector3(min), NSStringFromGLKVector3(max));
			NSLog(@"camera look at center %@, z+ %0.5f, model size %0.2f", NSStringFromGLKVector3(mid), distance, maxsize);
			//(0.0, 0.0, distance, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0);
			[_cameraMatrixList removeAllObjects];
			[self addCameraMatrix:lookat];
		}
		
		// move focal plane center to mid of the model.
		self.focalPlane = mid;
		_focalPlaneDistance = GLKVector3Distance([self getCameraPosition], _focalPlane);
		if ( isnan(_focalPlaneDistance) ) {
			NSLog(@"_focalPlaneDistance should not be NaN");
		}
		
	}
}
- (void)adjustCameraToCenterOnModel
{
	[self adjustCameraToCenterOnBounds:[self.delegate getBounds]];
}

- (void)resetFocalPlaneToBoundsCenter
{
	_focalPlane = [self.delegate getBoundsCenter];
	_focalPlaneDistance = GLKVector3Distance([self getCameraPosition], _focalPlane);
	if ( isnan(_focalPlaneDistance) ) {
		NSLog(@"_focalPlaneDistance should not be NaN");
	}
	
	_adjustedFocalPlaneFactor = 0.0;
}

// return a value from -1, 0, +1, interpolating model center to the near plane, focal, far plane positions.
- (float)modelInViewingRegion
{
	float relativePosition = 0.0;
	GLKVector3 modelCenter = [self.delegate getBoundsCenter];
	GLKVector3 viewingRay[2];
	
	GLint viewport[4] = { self.cameraInfo.viewPort.origin.x, self.cameraInfo.viewPort.origin.y, self.cameraInfo.viewPort.size.width, self.cameraInfo.viewPort.size.height };
	float width = viewport[2];
	float height = viewport[3];
	
	[self rayFromTouch:CGPointMake(width/2.0, height/2.0) into:viewingRay];
	GLKVector3 cameraPosition = [self getCameraPositionWithDeltaMatrix];
	float adjustedFocalLength = self.adjustedFocalPlaneDistance;
	
	GLKVector3 unitNear2Far = GLKVector3Normalize( GLKVector3Subtract( viewingRay[1], viewingRay[0] ) );
	GLKVector3 focalPosition = GLKVector3Add(cameraPosition, GLKVector3MultiplyScalar(unitNear2Far, adjustedFocalLength));
	GLKVector3 vectorFocal2Model = GLKVector3Subtract(modelCenter, focalPosition);
	float projectedLengthOfModelVector = GLKVector3DotProduct(vectorFocal2Model, unitNear2Far);
	
	float relative2Focal = projectedLengthOfModelVector ;
	if (relative2Focal > 0.0) {
		// normalize to focal-near distance
		relativePosition = relative2Focal / ABS(adjustedFocalLength - _nearPlane);
	} else {
		// normalize to focal-near distance
		relativePosition = relative2Focal / ABS(adjustedFocalLength - _nearPlane);
	}
	
	return relativePosition;
}

- (void)rayFromTouch:(CGPoint)touchOrigin into:(GLKVector3*)holder
{
	bool success = NO;
	GLfloat realY;
	
	GLint viewport[4] = { self.cameraInfo.viewPort.origin.x, self.cameraInfo.viewPort.origin.y, self.cameraInfo.viewPort.size.width, self.cameraInfo.viewPort.size.height };
	//NSLog(@"%d, %d, %d, %d", viewport[0], viewport[1], viewport[2], viewport[3]);
	
	//CGPoint touchOrigin = [recognizer locationInView:self.view];
	//NSLog(@"tap coordinates: %8.2f, %8.2f", touchOrigin.x, touchOrigin.y);
	
	realY = viewport[3] - touchOrigin.y;
	
	//GLKMatrix4 projectionMatrix = self.effect.transform.projectionMatrix;
	//GLKMatrix4 modelView = self.effect.transform.modelviewMatrix;
	GLKMatrix4 projectionMatrix = [self getProjectionMatrix];
	GLKMatrix4 modelView = [self.delegate getModelViewMatrix];
	
	// near plane
	GLKVector3 originInWindowNear = GLKVector3Make(touchOrigin.x, realY, 0.0f);
	
	// about middle in view.
	//GLKVector3 originInWindowNear = GLKVector3Make(touchOrigin.x, realY, 0.987f);
	
	GLKVector3 result1 = GLKMathUnproject(originInWindowNear, modelView, projectionMatrix, viewport, &success);
	
	//GLKMatrix4 matrix4_1 = GLKMatrix4Translate(GLKMatrix4Identity, result1.x, result1.y, 0.0f);
	//_squareUnprojectNear.modelMatrixUsage = GLKMatrix4Multiply(matrix4_1, _squareUnprojectNear.modelMatrixBase);
	
	GLKVector3 rayOrigin = GLKVector3Make(result1.x, result1.y, result1.z);
	
	// far plane
	
	GLKVector3 originInWindowFar = GLKVector3Make(touchOrigin.x, realY, 1.0f);
	
	GLKVector3 result2 = GLKMathUnproject(originInWindowFar, modelView, projectionMatrix, viewport, &success);
	
	//GLKMatrix4 matrix4_2 = GLKMatrix4Translate(GLKMatrix4Identity, result2.x, result2.y, 0.0f);
	
	GLKVector3 rayDirection = GLKVector3Make(result2.x - rayOrigin.x, result2.y - rayOrigin.y, result2.z - rayOrigin.z);
	if ( holder != NULL ) {
		//GLKVector3 *holder = (GLKVector3*)calloc(2, sizeof(GLKVector3));
		holder[0] = rayOrigin;
		holder[1] = rayDirection;
	}
	//_tappedAt = rayOrigin;
	//_hasTapped = YES;
	return ;
}

// pointInWindow should have multiplied with screen pixel scale. Assume pointInWindow specified in GL window coordinates, which is 0,0 at lower left.
- (GLKVector3)pointFromTouch:(GLKVector3)pointInWindow
{
	bool success = NO;
	
	GLint viewport[4] = { self.cameraInfo.viewPort.origin.x, self.cameraInfo.viewPort.origin.y, self.cameraInfo.viewPort.size.width, self.cameraInfo.viewPort.size.height };
	
	//GLfloat realY;
	//realY = viewport[3] - pointInWindow.y;
	
	//GLKMatrix4 projectionMatrix = self.effect.transform.projectionMatrix;
	//GLKMatrix4 modelView = self.effect.transform.modelviewMatrix;
	GLKMatrix4 projectionMatrix = [self getProjectionMatrix];
	GLKMatrix4 modelView = [self.delegate getModelViewMatrix];
	
	// depth is specified in z component.
	GLKVector3 result1 = GLKMathUnproject(pointInWindow, modelView, projectionMatrix, viewport, &success);
	
	return result1;
}

// pointInWindow should have multiplied with screen pixel scale. Assume pointInWindow specified in GL window coordinates, which is 0,0 at lower left.
- (GLKVector3)pointFromTouchWithoutDeltaCamera:(GLKVector3)pointInWindow
{
	bool success = NO;
	
	GLint viewport[4] = { self.cameraInfo.viewPort.origin.x, self.cameraInfo.viewPort.origin.y, self.cameraInfo.viewPort.size.width, self.cameraInfo.viewPort.size.height };
	
	//GLfloat realY;
	//realY = viewport[3] - pointInWindow.y;
	
	//GLKMatrix4 projectionMatrix = self.effect.transform.projectionMatrix;
	//GLKMatrix4 modelView = self.effect.transform.modelviewMatrix;
	GLKMatrix4 projectionMatrix = [self getProjectionMatrix];
	GLKMatrix4 modelView = [self getCameraMatrix:NO];
	
	// depth is specified in z component.
	GLKVector3 result1 = GLKMathUnproject(pointInWindow, modelView, projectionMatrix, viewport, &success);
	
	return result1;
}

- (GLKVector3)projectForPoint:(GLKVector3)pointInWC
{
	GLint viewport[4] = { self.cameraInfo.viewPort.origin.x, self.cameraInfo.viewPort.origin.y, self.cameraInfo.viewPort.size.width, self.cameraInfo.viewPort.size.height };
	GLKMatrix4 projectionMatrix = [self getProjectionMatrix];
	GLKMatrix4 modelView = [self.delegate getModelViewMatrix];
	GLKVector3 result = GLKMathProject(pointInWC, modelView, projectionMatrix, viewport);
	if (isnan(result.x) || isnan(result.y)) return GLKVector3Make(0.0, 0.0, 0.0);
	return result;
}

- (GLKVector3)projectForPointWithoutDeltaCamera:(GLKVector3)pointInWC
{
	GLint viewport[4] = { self.cameraInfo.viewPort.origin.x, self.cameraInfo.viewPort.origin.y, self.cameraInfo.viewPort.size.width, self.cameraInfo.viewPort.size.height };
	GLKMatrix4 projectionMatrix = [self getProjectionMatrix];
	GLKMatrix4 modelView = [self getCameraMatrix:NO];
	GLKVector3 result = GLKMathProject(pointInWC, modelView, projectionMatrix, viewport);
	if (isnan(result.x) || isnan(result.y)) return GLKVector3Make(0.0, 0.0, 0.0);
	return result;
}

- (GLKVector3)projectedVectorInWC:(CameraInfo *) camera viewSize:(float) viewSize startingPointInWC:(GLKVector3) startingPointInWC directionInWC:(GLKVector3) directionInWC;
{
	// obtain depth in z;
	GLKVector3 centroidInView = [camera projectPointInWC: startingPointInWC];
	
	GLKVector3 rightVector = ( GLKVector3Subtract([camera unprojectPointInWindow: GLKVector3Make(centroidInView.x + viewSize, centroidInView.y, centroidInView.z )], startingPointInWC));
	
	float viewSizeInWC = GLKVector3Length( rightVector ) ;
	
	// assume directionInWC is unit vector
	GLKVector3 targetMovedToInWC = GLKVector3MultiplyScalar( directionInWC, viewSizeInWC) ;
	
	return targetMovedToInWC;
}

// ---------------------------------------------------------------------
- (void)setCameraPerspective:(BOOL)cameraPerspective
{
	BOOL currentPerspective = self.cameraPerspective;
	if ( currentPerspective != cameraPerspective ) {
		if ( currentPerspective == YES ) {
			// switch from perspective view to orthographic view.
			// visible scene up around focal plane should be also viewable under orphographic view.
			float currentFov = [self getCameraFoV];
			float viewSize = self.focalPlaneDistance * tanf( currentFov/2.0 );
			float newFov = 2.0 * atan2f(viewSize, self.nearPlane);
			float factor = currentFov / newFov ;
			[self applyCameraZoomFactorCompleted:factor fovOnly:YES];
		} else {
			// switch from orthographic view to perspective view.
			// reverse of the above.
			float currentFov = [self getCameraFoV];
			float viewSize = self.nearPlane * tanf( currentFov/2.0 );
			float newFov = 2.0 * atan2f(viewSize, self.focalPlaneDistance);
			float factor = currentFov / newFov ;
			[self applyCameraZoomFactorCompleted:factor fovOnly:YES];
		}
	}
	[self willChangeValueForKey:@"cameraPerspective"];
	_cameraPerspective = cameraPerspective;
	if ( cameraPerspective ) {
		_cameraFrontView = NO;
		_cameraSideView = NO;
		_cameraTopView = NO;
		_cameraBottomView = NO;
		_cameraLeftView = NO;
		_cameraBackView = NO;
	}
	[self didChangeValueForKey:@"cameraPerspective"];
}

- (void)setCameraTopView:(BOOL)cameraTopView
{
	_cameraTopView = cameraTopView;
	if (cameraTopView == YES) {
		[_cameraMatrixList removeAllObjects];
		GLKVector3 eye = GLKVector3Make(0, _focalPlaneDistance, 0);
		GLKMatrix4 lookat = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, 0, 0, 0, 0.0, 0.0, -1.0);
		[_cameraMatrixList removeAllObjects];
		[self addCameraMatrix:lookat];
		
		_cameraFrontView = NO;
		_cameraSideView = NO;
		_cameraTopView = YES;
		
		_cameraBottomView = NO;
		_cameraLeftView = NO;
		_cameraBackView = NO;
		
		self.cameraPerspective = NO;
		
	} else {
		self.cameraPerspective = self.cameraPerspective;
	}
}

- (void)setCameraBottomView:(BOOL)cameraBottomView
{
	_cameraBottomView = cameraBottomView;
	if (cameraBottomView == YES) {
		[_cameraMatrixList removeAllObjects];
		GLKVector3 eye = GLKVector3Make(0, -_focalPlaneDistance, 0);
		GLKMatrix4 lookat = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, 0, 0, 0, 0.0, 0.0, 1.0);
		[_cameraMatrixList removeAllObjects];
		[self addCameraMatrix:lookat];
		
		_cameraFrontView = NO;
		//wildMagicModel_blank_stage_grid.showXYGrid = NO;
		_cameraSideView = NO;
		//wildMagicModel_blank_stage_grid.showYZGrid = NO;
		_cameraTopView = NO;
		//wildMagicModel_blank_stage_grid.showXZGrid = YES;
		
		_cameraBottomView = YES;
		_cameraLeftView = NO;
		_cameraBackView = NO;
		
		self.cameraPerspective = NO;
		
	} else {
		self.cameraPerspective = self.cameraPerspective;
		//wildMagicModel_blank_stage_grid.showXZGrid = NO;
	}
}

- (void)setCameraFrontView:(BOOL)cameraFrontView
{
	_cameraFrontView = cameraFrontView;
	if (cameraFrontView == YES) {
		//GLKVector3 eye = GLKVector3Make(0, 0, _focalPlaneDistance);
		//GLKMatrix4 lookat = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, 0, 0, 0, 0.0, 1.0, 0.0);
		
		GLKMatrix4 invertedCamera = [self getCameraInverse];
		
		GLKVector3 cameraPosition = [self getCameraPosition];
		GLKVector3 viewDirection = [self getCameraViewDirection];
		GLKVector3 p = GLKVector3Add(cameraPosition, GLKVector3MultiplyScalar(GLKVector3Normalize(viewDirection), _focalPlaneDistance));
		
		GLKVector3 eye = GLKVector3Make( p.x, p.y, p.z + _focalPlaneDistance);
		GLKMatrix4 lookat = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, p.x, p.y, p.z, 0.0, 1.0, 0.0);
		
		//[_cameraMatrixList removeAllObjects];
		[self addCameraMatrix: GLKMatrix4Multiply(lookat, invertedCamera) ];
		
		_cameraFrontView = YES;
		//wildMagicModel_blank_stage_grid.showXYGrid = YES;
		_cameraSideView = NO;
		//wildMagicModel_blank_stage_grid.showYZGrid = NO;
		_cameraTopView = NO;
		//wildMagicModel_blank_stage_grid.showXZGrid = NO;
		
		_cameraBottomView = NO;
		_cameraLeftView = NO;
		_cameraBackView = NO;
		
		self.cameraPerspective = NO;
		
	} else {
		self.cameraPerspective = self.cameraPerspective;
		//wildMagicModel_blank_stage_grid.showXYGrid = NO;
	}
}

- (void)setCameraBackView:(BOOL)cameraBackView
{
	_cameraBackView = cameraBackView;
	if (cameraBackView == YES) {
		[_cameraMatrixList removeAllObjects];
		GLKVector3 eye = GLKVector3Make(0, 0, -_focalPlaneDistance);
		GLKMatrix4 lookat = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, 0, 0, 0, 0.0, 1.0, 0.0);
		[_cameraMatrixList removeAllObjects];
		[self addCameraMatrix:lookat];
		
		_cameraFrontView = NO;
		//wildMagicModel_blank_stage_grid.showXYGrid = YES;
		_cameraBackView = YES;
		_cameraSideView = NO;
		//wildMagicModel_blank_stage_grid.showYZGrid = NO;
		_cameraLeftView = NO;
		_cameraTopView = NO;
		//wildMagicModel_blank_stage_grid.showXZGrid = NO;
		_cameraBottomView = NO;
		
		self.cameraPerspective = NO;
		
	} else {
		self.cameraPerspective = self.cameraPerspective;
		//wildMagicModel_blank_stage_grid.showXYGrid = NO;
	}
}

- (void)setCameraSideView:(BOOL)cameraSideView
{
	_cameraSideView = cameraSideView;
	if (cameraSideView == YES) {
		[_cameraMatrixList removeAllObjects];
		GLKVector3 eye = GLKVector3Make(_focalPlaneDistance, 0, 0);
		GLKMatrix4 lookat = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, 0, 0, 0, 0.0, 1.0, 0.0);
		[_cameraMatrixList removeAllObjects];
		[self addCameraMatrix:lookat];
		
		_cameraFrontView = NO;
		//wildMagicModel_blank_stage_grid.showXZGrid = NO;
		_cameraSideView = YES;
		//wildMagicModel_blank_stage_grid.showYZGrid = YES;
		_cameraTopView = NO;
		//wildMagicModel_blank_stage_grid.showXYGrid = NO;
		
		_cameraBottomView = NO;
		_cameraLeftView = NO;
		_cameraBackView = NO;
		
		self.cameraPerspective = NO;
		
	} else {
		self.cameraPerspective = self.cameraPerspective;
		//wildMagicModel_blank_stage_grid.showYZGrid = NO;
	}
}

- (void)setCameraLeftView:(BOOL)cameraLeftView
{
	_cameraLeftView = cameraLeftView;
	if (cameraLeftView == YES) {
		[_cameraMatrixList removeAllObjects];
		GLKVector3 eye = GLKVector3Make(-_focalPlaneDistance, 0, 0);
		GLKMatrix4 lookat = GLKMatrix4MakeLookAt(eye.x, eye.y, eye.z, 0, 0, 0, 0.0, 1.0, 0.0);
		[_cameraMatrixList removeAllObjects];
		[self addCameraMatrix:lookat];
		
		_cameraFrontView = NO;
		//wildMagicModel_blank_stage_grid.showXZGrid = NO;
		_cameraSideView = NO;
		//wildMagicModel_blank_stage_grid.showYZGrid = YES;
		_cameraTopView = NO;
		//wildMagicModel_blank_stage_grid.showXYGrid = NO;
		
		_cameraBottomView = NO;
		_cameraLeftView = YES;
		_cameraBackView = NO;
		
		self.cameraPerspective = NO;
		
	} else {
		self.cameraPerspective = self.cameraPerspective;
		//wildMagicModel_blank_stage_grid.showYZGrid = NO;
	}
}

- (void)setOrbitStyleTurntable:(BOOL)orbitStyleTurntable
{
	_orbitStyleTurntable = orbitStyleTurntable;
	if ( orbitStyleTurntable ) {
		_orbitStyleTurntableYup = NO;
	}

	[self animateCameraStickWithOrbitTurntableStyleWithCompletion:^{
		//dispatch_async( dispatch_get_main_queue(), ^{
		// refresh MenuStatus has to be in main thread
		//[menuViewController refreshMenuStatus];
		//});
	}];
}

- (void)setOrbitStyleTurntableYup:(BOOL)orbitStyleTurntableYup
{
	_orbitStyleTurntableYup = orbitStyleTurntableYup;
	if ( orbitStyleTurntableYup ) {
		_orbitStyleTurntable = NO;
	}
	
	[self animateCameraStickWithOrbitTurntableStyleWithCompletion:^{
		//dispatch_async( dispatch_get_main_queue(), ^{
		// refresh MenuStatus has to be in main thread
		//[menuViewController refreshMenuStatus];
		//});
	}];

}

// ----------------------------- Gestures Begin ---------------------------------------

- (void)touchLastActiveTimestamp
{
	_lastActionTimestamp = [[NSDate date] timeIntervalSince1970];
}

- (BOOL)isInactiveElapsed
{
	return ([[NSDate date] timeIntervalSince1970] - _lastActionTimestamp) > MAX_INACTIVE_TIME;
}

/*
 Sort of completed camera manipulation:
 2-touch dragging in the center to move viewing direction.
 2-touch in the edges to pan the camera.
 2-touch pinch in the center zoom in, zoom out.
 2-touch pinch at the top-right corner to change field of view.
 1-touch moving in the center area to rotate camera around the focal plane.  \nPinch to zoom in, zoom out.  \n2-touches dragging to move viewing direction.
 1-touch at top edge, moving horizontally to rotate camera in z-axis.  \nSubsequently moving around screen center to continue the rotation.
 1-touch at right edge, moving vertically to rotate camera in z-axis.  \nSubsequently moving around screen center to continue the rotation.
 1-touch at top-left edge to rotate camera in x-axis .
 1-touch at lower-left edge, moving horizontally to rotate camera in y-axis .
 1-touch at the lower-left edge, moving vertically to pull camera forwards/backwards.
 1-touch panning to left from the top-right screen edge to show/hide the menu.
 1-touch panning to left from above mid-right screen edge to show the right side menu.
 1-touch panning to left from the lower-right screen edge to show the control items.
 1-touch long press at the top-left corner to reset camera movement and focal plane adjustment.
 1-touch long press at the top-right corner to toggle focal plane visual guide on/off.  \nDrag the oval buttons to adjust the focal plane. Double tap to reset it.  \nPinch near this area also changes camera field of view.
 1-touch long press in the center to tumbling around the focal plane.
 1-touch long press at the mid-right edge, and then moving in small circle to rotate camera vertically around the focal plane.
 1-touch long press at the mid-bottom edge, and then moving in small circle to rotate camera horizontally around the focal plane.
 1-touch long press at the edges to pan the camera.
 */
- (IBAction)panDetected:(UIPanGestureRecognizer *)sender {
	
	[self touchLastActiveTimestamp];
	
	CGPoint lastTouchAt = [sender locationInView:self.view];
	if ( sender.view != nil ) {
		// this is to cater for the case when the gesture capturing view is not self.view
		lastTouchAt = [sender locationInView: sender.view];
	}
	
	CGPoint moved = [sender translationInView:self.view];
	if ( sender.view != nil ) {
		// this is to cater for the case when the gesture capturing view is not self.view
		moved = [sender translationInView: sender.view];
	}
	
	CGPoint firstTouchAt = CGPointMake(0, 0);
	firstTouchAt.x = lastTouchAt.x - moved.x;
	firstTouchAt.y = lastTouchAt.y - moved.y;
	NSInteger state = [sender state];
	
	
	//BOOL isPaintingColor = !_colorPicker.isHidden && _colorPicker.applyState;
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPreprocessing:)] ) {
		_continueGestureProcessing = [self.delegate gestureDetectedPreprocessing:sender];
	}
	
	if (state == UIGestureRecognizerStateBegan ) {
		// hide touching focus
		[touchingFocus setHidden:YES];
		
		/*
		if ( !self.collectionView.isHidden ) {
			// this is to stop scrolling animation immediately to avoid blocking user interaction.
			[self.collectionView setContentOffset:self.collectionView.contentOffset animated:NO];
		}
		
		// this setContentOffset to itself is to stop scrolling animation immediately to avoid blocking user interaction.
		if ( !_rightSideMenuPane.isHidden ) {
			[menuViewController.collectionView setContentOffset:menuViewController.collectionView.contentOffset animated:NO];
		}
		 */
		
		// channel the pan gesture to the axis manipulator, such as to detect tap in this view
		// and, allow manipulation in axis manipulator.
		_channelGestureInAction = NO;
		
		if ( [self.delegate respondsToSelector:@selector(shouldChannelGesture:)] ) {
			_channelGestureInAction = [self.delegate shouldChannelGesture: sender];
		}

		_continueGestureProcessing = YES;

		/*
		 CGRect rect;
		_channelGesturePencilInAction = NO;
		_singleBoneRollInAction = NO;
		
		if ( self.delegate.isPencilDrawingOn ) {
			rect = [self.view convertRect:_pencilManipulator.circleForGrabbing fromView:_pencilManipulator];
			// no need to shrink effective radius
			if ( !_channelGestureInAction && CGRectContainsPoint( rect, lastTouchAt)) {
				//GLKVector2 dist2grabCenter = GLKVector2Make( lastTouchAt.x - _pencilManipulator.center.x,  lastTouchAt.y - _pencilManipulator.center.y );
				//if ( GLKVector2Length(dist2grabCenter) < _pencilManipulator.centralGrabCircleSize * 1.5 ) {
				_channelGesturePencilInAction = YES;
				//}
			}
			
			// long press large effective area
			if ( sender == pencilRecognizer && pencilRecognizer.isLongPressed ) {
				if ( !_channelGestureInAction && CGRectContainsPoint( rect, lastTouchAt)) {
					_channelGesturePencilInAction = YES;
					NSLog( @"isLongPressed pencil");
					
					// detected start of drawing with long pressed on pencil manipulator
					[self setupPencilStateForStartDrawing:(CPanAndMoreGestureRecognizer*)sender useCurrentMovingState:NO stitchFromSelected:YES];
				}
			}
		}
		
		// self.view.superview may be null because is presenting the scene kit controller.
		if ( !_channelGesturePencilInAction && self.view.superview != NULL) {
			rect = [self.view convertRect:_axisManipulator.circleForResizing fromView:_axisManipulator];
			if ( !_axisManipulator.isHidden && CGRectContainsPoint( rect, lastTouchAt) && sender.numberOfTouches == 1) {
				_channelGestureInAction = YES;
			}
			rect = [self.view convertRect:_axisManipulator.circleForViewRotationLeft fromView:_axisManipulator];
			if ( !_axisManipulator.isHidden && CGRectContainsPoint( rect, lastTouchAt) && sender.numberOfTouches == 1) {
				_channelGestureInAction = YES;
			}
			rect = [self.view convertRect:_axisManipulator.circleForViewRotationRight fromView:_axisManipulator];
			if ( !_axisManipulator.isHidden && CGRectContainsPoint( rect, lastTouchAt) && sender.numberOfTouches == 1) {
				_channelGestureInAction = YES;
				if ( [theGround isBoneNode: theGround.selectedObject] ) {
					_singleBoneRollInAction = YES;
				}
			}
			rect = [self.view convertRect:_axisManipulator.circleForGrabbing fromView:_axisManipulator];
			if ( !_axisManipulator.isHidden && CGRectContainsPoint( rect, lastTouchAt)) {
				GLKVector2 dist2grabCenter = GLKVector2Make( firstTouchAt.x - _axisManipulator.center.x,  firstTouchAt.y - _axisManipulator.center.y );
				if ( GLKVector2Length(dist2grabCenter) < _axisManipulator.centralGrabCircleSize * 1.5) {
					//CGPoint velocity = [sender velocityInView:self.view];
					//NSLog(@"velocity : %@", NSStringFromCGPoint(velocity));
					// swipe up to un-select all
					_channelGestureInAction = YES;
				} else {
					// large effective radius.
					_channelGestureInAction = YES;
				}
			}
		}
		
		_editingElementsBoxSelectionAddToSet_Moving = NO;
		_editingElementsBoxSelectionMinusFromSet_Moving = NO;
		if ( !_channelGestureInAction || (sender.numberOfTouches == 2) ) {
			if ( _editingElementsBoxSelectionAddToSet_InSelection && CGRectContainsPoint(_editingElementsBoxSelectionAddToSet.frame, lastTouchAt)) {
				_editingElementsBoxSelectionAddToSet_Moving = YES;
				_firstTouch = _editingElementsBoxSelectionAddToSet.center;
				_channelGestureInAction = NO;
			} else if ( _editingElementsBoxSelectionMinusFromSet_InSelection && CGRectContainsPoint(_editingElementsBoxSelectionMinusFromSet.frame, lastTouchAt)) {
				_editingElementsBoxSelectionMinusFromSet_Moving = YES;
				_firstTouch = _editingElementsBoxSelectionMinusFromSet.center;
				_channelGestureInAction = NO;
			}
		}
		
		// editing texture uv if applicable
		if ( !_channelGestureInAction ) {
			if ( self.textureViewActive && _textureView.textureUVInAction && !_textureView.uvSelectedView.box.isHidden) {
				rect = [self.view convertRect:_textureView.uvSelectedView.box.frame fromView:_textureView.uvSelectedView] ;
				if ( rect.size.width < 2*_THUMB_SIZE || rect.size.height < 2*_THUMB_SIZE || !CGRectIntersectsRect( CGRectInset(_textureView.frame, _THUMB_SIZE/2, _THUMB_SIZE/2), rect))
					rect = CGRectInset(rect, - 2*_THUMB_SIZE, - 2*_THUMB_SIZE);
				if ( CGRectContainsPoint(rect, lastTouchAt) ) {
					_channelGestureUVInAction = YES;
					_channelGestureInAction = NO;
					_textureView.axisManipulator = _axisManipulator;
					_textureView.theGround = theGround;
				}
			}
		}
		
		// pick-and-paint, when apply color is active and pan slowly
		if ( !_channelGesturePencilInAction && !_channelGestureUVInAction && (sender.numberOfTouches == 1) && isPaintingColor && theGround.hasActiveMeshEditingObject
			// moving at the focus but not an editing representation(point, line or face)
			&& !(_channelGestureInAction && ![theGround isAnEditingRepresentation: theGround.selectedObject])
			) {
			//CGPoint velocity = [sender velocityInView:self.view];
			//NSLog(@"velocity : %@", NSStringFromCGPoint(velocity));
			
			// whenever, isPaintingColor, cannot grab, so, no need to check velocity
			//if ( fabs(velocity.x) < 130 && fabs(velocity.y) < 130 ) {
			// instead, if not already selected elements, then have to pan in screen center, 1/6 from upper-left, 1/4 from lower-right area for painting.
			// this is to avoid painting in a dense mesh occupying the entire screen .
			CGRect rect = CGRectMake(ONE_SIXTH_WIDTH*1, ONE_SIXTH_HEIGHT*1, ONE_SIXTH_WIDTH*3.5, ONE_SIXTH_HEIGHT*(3.5) );
			if ( theGround.hasSelectedObject || (!theGround.hasSelectedObject && CGRectContainsPoint(rect, lastTouchAt)) )
			{
				GLKVector2 screenCoord = GLKVector2Make(lastTouchAt.x * _nativeScale, lastTouchAt.y * _nativeScale);
				NSArray * picked = [theGround getSelectedEditingElements];
				if ( !_channelGestureInAction ) {
					picked = [theGround getNearestEditingElementWithScreenCoord:screenCoord withTolerance:_THUMB_SIZE* _nativeScale];
					if ( picked.count <= 0 ) {
						picked = [theGround getNearestEditingSurfaceWithScreenCoord:screenCoord withTolerance:_THUMB_SIZE* _nativeScale];
					}
				}
				
				if ( picked != nil && picked.count >= 1) {
					//NSLog(@"pan-and-paint : %d elements", (int)[picked count]);
					
					[theGround selectObjectWithEditingRecords:picked pickSingle:YES];
					[self updateAxisManipulatorWithAnimation:YES];
					_axisManipulator.circleOnly = YES;
					_channelGestureInAction = YES;
					_shouldRefocusUponGestureCompletion = YES;
					// deliberatly not to refocus on last picked, when after pick-and-paint gesture.
					// This is to avoid needing pre-picking, or de-picking, when changing color.
					_refousSelectionRecords = [NSArray new];
					_lastTouch = lastTouchAt;
				}
			}
		}
		 */
	}
	
	if ( !_continueGestureProcessing) return;
	
	if ( self.channelGestureInAction ) {
		
		if ( [self.delegate respondsToSelector:@selector(channelGestureHandler:)] ) {
			[self.delegate channelGestureHandler:sender];
		}
		
		if ( [self.delegate respondsToSelector:@selector(moveCameraForAdditionalTouchWhenPanning:)] ) {
			[self.delegate moveCameraForAdditionalTouchWhenPanning:sender];
		}
		
		if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
			[self.delegate gestureDetectedPostprocessing:sender];
		}
		
		return;
	}
	
	/*
	if ( _channelGestureInAction ) {
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			_proportionalEditCircleInAction = YES;
			// show proportional radius if applying color
			if ( !isPaintingColor) {
				_proportionalEditCircle.hidden = YES;
			}
		}
		
		// prepare camera info for grabbing
		if ( state == UIGestureRecognizerStateBegan ) {
			_axisManipulator.lastCamera = [theGround getCameraInfo];
			
			//test to hide axis
			//_axisManipulator_lastCircleOnlyState = _axisManipulator.shouldShowAxises;
			//_axisManipulator.shouldShowAxises = NO ;
		}
		
		// as a flag to make the grabbing effective in the translationInCamera method
		if ( _axisManipulator.lastCamera == nil ) {
			// lastCamera may have nullified as a flag to ignore first touch dragging momentarily, so, resume last camera
			_axisManipulator.lastCamera = [theGround getCameraInfo];
		}
		
		if ( ![self moveCameraForAdditionalTouchWhenPanning:sender] ) {
			[_axisManipulator panGestureDetected:sender];
		} else {
			// continue channeling could prevent jumping, however, the transform is not desired.
			[_axisManipulator panGestureDetected:sender];
		}
		_lastTouch = lastTouchAt;
		
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			// after the END state, set to NO will make the proportional edit circle as if no present.
			// So, check if the manipulator is still in hanlder-in-action before setting it to NO.
			if (!_axisManipulator.handlerInAction) {
				_proportionalEditCircleInAction = NO;
			}
			[_proportionalEditCircle setHidden:NO];
		}
		
		if ( !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)  ) {
			if ( _shouldRefocusUponGestureCompletion && _refousSelectionRecords != nil ) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[theGround selectObjectWithEditingRecords:_refousSelectionRecords pickSingle:YES];
					[self updateAxisManipulatorWithAnimation:YES];
					[self updateSelectionObjectInfo];
					_refousSelectionRecords = nil;
				});
			}
			if ( _shouldRefocusUponGestureCompletion ) {
				_axisManipulator.circleOnly = NO;
			}
			_shouldRefocusUponGestureCompletion = NO;
			
			// test, to reveal axis after gesture pan
			//_axisManipulator.shouldShowAxises = _axisManipulator_lastCircleOnlyState;
			
			[UIView animateWithDuration:0.5 animations:^{
				_panAtViewAroundFocusButton.layer.opacity = 0;
				_tumbleAroundFocusButton.layer.opacity = 0;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.layer.opacity = 0;
					_tumbleAroundFocusButton_LeftSide.layer.opacity = 0;
				}
			} completion:^(BOOL finished) {
				_panAtViewAroundFocusButton.hidden = YES;
				_tumbleAroundFocusButton.hidden = YES;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.hidden = YES;
					_tumbleAroundFocusButton_LeftSide.hidden = YES;
				}
			}];
			
			_axisManipulator.shouldShowTumblingHint = NO;
		}
		
		return;
	}
	 */
	
	/*
	// channel gesture to texture image view for editing texture coordinates
	if ( _channelGestureUVInAction ) {
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			_proportionalEditCircleInAction = YES;
			[_proportionalEditCircle setHidden:YES];
		}
		
		_lastTouch = lastTouchAt;
		[_textureView panGestureDetected:sender];
		
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			// after the END state, set to NO will make the proportional edit circle as if no present.
			// So, check if the manipulator is still in hanlder-in-action before setting it to NO.
			if (!_axisManipulator.handlerInAction) {
				_proportionalEditCircleInAction = NO;
			}
			[_proportionalEditCircle setHidden:NO];
		}
		
		if ( !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)  ) {
			_channelGestureUVInAction = NO;
			_textureView.axisManipulator = nil;
			_textureView.theGround = nil;
		}
		return;
	}
	 */
	
	/*
	// channel gesture to pencil manipulator, very similar to axis manipulator
	if ( _channelGesturePencilInAction ) {
		
		// prepare camera info for grabbing
		if ( state == UIGestureRecognizerStateBegan ) {
			_pencilManipulator.lastCamera = [theGround getCameraInfo];
			_pencilManipulator.shouldShowRotateIcon = pencilRecognizer.isLongPressed;
			_pencilManipulator.shouldShowRotate90Degrees = YES;
			[_pencilManipulator setNeedsDisplay];
		}
		
		// as a flag to make the grabbing effective in the translationInCamera method
		if ( _pencilManipulator.lastCamera == nil ) {
			// lastCamera may have nullified as a flag to ignore first touch dragging momentarily, so, resume last camera
			_pencilManipulator.lastCamera = [theGround getCameraInfo];
		}
		
		if ( ![self moveCameraForAdditionalTouchWhenPanning:sender] ) {
			[_pencilManipulator panGestureDetected:sender];
		} else {
			// continue channeling could prevent jumping, however, the transform is not desired.
			[_pencilManipulator panGestureDetected:sender];
		}
		_lastTouch = lastTouchAt;
		//_pencilManipulator.center = _lastTouch;
		
		if ( !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)  ) {
			
			// dismiss visual feedback (that the camera can be further changed in the middle of pan gesture).
			[UIView animateWithDuration:0.5 animations:^{
				_panAtViewAroundFocusButton.layer.opacity = 0;
				_tumbleAroundFocusButton.layer.opacity = 0;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.layer.opacity = 0;
					_tumbleAroundFocusButton_LeftSide.layer.opacity = 0;
				}
			} completion:^(BOOL finished) {
				_panAtViewAroundFocusButton.hidden = YES;
				_tumbleAroundFocusButton.hidden = YES;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.hidden = YES;
					_tumbleAroundFocusButton_LeftSide.hidden = YES;
				}
			}];
			
			_pencilManipulator.shouldShowRotateIcon = NO;
			_pencilManipulator.shouldShowRotate90Degrees = NO;
			_pencilManipulator.pencilDrawingInAction = NO;
			_pencilManipulator.shouldShowTumblingHint = NO;
			[_pencilManipulator setNeedsDisplay];
		}
		
		return;
	}
	 */
	
	/*
	// priority when panning in the selection area
	if ( _editingElementsBoxSelectionAddToSet_Moving ) {
		if ( state == UIGestureRecognizerStateBegan ) {
			_frameBeforeGesture = _editingElementsBoxSelectionAddToSet.frame;
		}
		if ( state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged ) {
			//_editingElementsBoxSelectionAddToSet.center = CGPointMake(_firstTouch.x + moved.x, _firstTouch.y + moved.y);
			CGRect newRect = CGRectOffset(_frameBeforeGesture, moved.x, moved.y);
			[self updateConstraints:_editingElementsBoxSelectionAddToSet withKey:@"_editingElementsBoxSelectionAddToSet" toFrame:newRect];
		} else if ( state == UIGestureRecognizerStateEnded ) {
			_editingElementsBoxSelectionAddToSet_Moving = NO;
		} else {
			_editingElementsBoxSelectionAddToSet_Moving = NO;
		}
		
		return;
	}
	
	if ( _editingElementsBoxSelectionMinusFromSet_Moving ) {
		if ( state == UIGestureRecognizerStateBegan ) {
			_frameBeforeGesture = _editingElementsBoxSelectionMinusFromSet.frame;
		}
		if ( state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged ) {
			//_editingElementsBoxSelectionMinusFromSet.center = CGPointMake(_firstTouch.x + moved.x, _firstTouch.y + moved.y);
			CGRect newRect = CGRectOffset(_frameBeforeGesture, moved.x, moved.y);
			[self updateConstraints:_editingElementsBoxSelectionMinusFromSet withKey:@"_editingElementsBoxSelectionMinusFromSet" toFrame:newRect];
		} else if ( state == UIGestureRecognizerStateEnded ) {
			_editingElementsBoxSelectionMinusFromSet_Moving = NO;
		} else {
			_editingElementsBoxSelectionMinusFromSet_Moving = NO;
		}
		
		return;
	}
	
	// reveal the transform editor by paning downward in its hidden frame.  This gesture is the counter action of the panning upward to hide it.
	if ( state == UIGestureRecognizerStateBegan ) {
		_mayExpandTransformEditor = NO;
		
		if (_preferredTransformEditorOff == YES && CGRectContainsPoint(_transformEditor.frame, firstTouchAt) && (sender.numberOfTouches == 1) && theGround.hasSelectedObject) {
			_mayExpandTransformEditor = YES;
		}
	}
	
	// for iOS 8, the began state has moved 0,0.
	//if (state == UIGestureRecognizerStateBegan)
	//	NSLog(@"panDetected: at (%0.1f, %0.1f) tranlated (%0.1f, %0.1f), state:%ld, touches:%lu, action:%@", firstTouchAt.x, firstTouchAt.y, moved.x, moved.y, (long)state, (unsigned long)sender.numberOfTouches, [self stringFromCameraAction]);
	
	// for controlling the ground's grid size.
	//theGround.gridSize += (int)(moved.x/10.f);
	//theGround.patternSize += (int)(moved.y/50.f);
	*/
	 
	 
	if ( ( state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged || state == UIGestureRecognizerStateEnded) ) {
		if ( state == UIGestureRecognizerStateBegan) {
			_cameraInAction = NO; _cameraStopAction = NO;
			_cameraRotateHorizontal = NO;
			_cameraRotateVertical = NO;
			_cameraRotateLeftWise = NO;
			_cameraRotateRightWise = NO;
			_cameraRotateTopWise = NO;
			_cameraMoveInView = NO;
			_cameraPan = NO;
			_cameraMoveForwardBackward = NO;
			_cameraChangeFOV = NO;
			_cameraPanAndRotateInTandem = NO;
			_cameraTumbling = NO;
			_cameraDragRotateResize = NO;
			
			_screenEdgePan = NO;
			_screenEdgeLeftPan = NO;
			_debugActionDisplayed = NO;
			
			_cameraPan_ForPanMore = NO;
			_cameraRotate_ForPanMore = NO;
			_cameraTumbling_ForPanMore = NO;
			_cameraPinch_ForPanMore = NO;
			_pencilPinch_ForPanMore = NO;
			
			//_internalTestView_Moving = NO;
			
			if ( continuousTumbling ) {
				[self stopContinuousTumbling];
			}
			
			// pre-save gesture begin camera info
			if ( self.orbitStyleTurntable ) {
				_lastCameraInfoAtGestureBegan = self.getCameraInfo;
				
				// reset turntable flag to NO if the up axis is not aligned upwards.
				CameraInfo * lastCamera = _lastCameraInfoAtGestureBegan;
				GLKVector3 unitZ = GLKVector3Make(0, 0, 1);
				GLKVector3 cameraRight = GLKVector3CrossProduct( lastCamera.viewDirection, lastCamera.upDirection );
				float dotCameraRightAligningToUnitZ = GLKVector3DotProduct( cameraRight, unitZ );
				if ( dotCameraRightAligningToUnitZ < -2*_epsilon || dotCameraRightAligningToUnitZ > 2*_epsilon ) {
					// no need to toggle off because of revised turntable logic
					//theGround.orbitStyleTurntable = NO;
				}
			}
			
			// pre-save gesture begin camera info
			if ( self.orbitStyleTurntableYup ) {
				_lastCameraInfoAtGestureBegan = self.getCameraInfo;
				
				// reset turntable flag to NO if the up axis is not aligned upwards.
				CameraInfo * lastCamera = _lastCameraInfoAtGestureBegan;
				GLKVector3 unitY = GLKVector3Make(0, 1, 0);
				GLKVector3 cameraRight = GLKVector3CrossProduct( lastCamera.viewDirection, lastCamera.upDirection );
				float dotCameraRightAligningToUnitY = GLKVector3DotProduct( cameraRight, unitY );
				if ( dotCameraRightAligningToUnitY < -2*_epsilon || dotCameraRightAligningToUnitY > 2*_epsilon ) {
					// assumes non-turntable if the y-axis is not already aligned up.
				}
			}
			
			/*
			// moving internal test view
			if ( _internalTestView != nil && CGRectContainsPoint( _internalTestView.frame, lastTouchAt) ) {
				_cameraInAction = YES;
				_internalTestView_Moving = YES;
				_frameBeforeGesture = _internalTestView.frame;
			}
			 */
		}
		
		/*
		// expand transform editor if pan downwards at the original editor frame, with an object selected.
		if ( _mayExpandTransformEditor && state == UIGestureRecognizerStateChanged ) {
			if ( self.hasSelectedObject && fabs(moved.y) > 2*fabs(moved.x)) {
				if ( moved.y > 0 ) {
					self.preferredTransformEditorOff = NO;
					//[sender cancelsTouchesInView];
					sender.enabled = NO; sender.enabled = YES;
					_cameraInAction = NO;
					return;
				}
			} else {
				_mayExpandTransformEditor = NO;
			}
		}
		 */
		
		// 2-touch for pan.
		if ( !_cameraInAction && (sender.numberOfTouches == 2) ) {
			if (self.orbitStyleTurntable || self.orbitStyleTurntableYup
				// this checking is for using pan when panning starts from edges
				//|| ( (firstTouchAt.y < ONE_FOURTH_HEIGHT || firstTouchAt.y > 3*ONE_FOURTH_HEIGHT) || (firstTouchAt.x < ONE_FOURTH_WIDTH || firstTouchAt.x > 3*ONE_FOURTH_WIDTH) )
				) {
				//_cameraPan = YES;
				//_lastTouch = lastTouchAt;
				[self beginDragRotateResizeAtTheSameTime: sender];
				
			} else {
				//if ( self.glkviewVisible || self.scnviewVisible ) {
					[self beginDragRotateResizeAtTheSameTime: sender];
				//} else {
				//	_cameraMoveInView = YES;
				//}
			}
			_cameraInAction = YES;
			// save firstTouchAt for possible 3 touches pan and rotate.
			//_firstTouch = firstTouchAt;
		}
		
		// this tandem thing not used and not well tested.
		if ( !_cameraPanAndRotateInTandem && _cameraPan && sender.numberOfTouches == 3 ) {
			_cameraPanAndRotateInTandem = YES;
			// tmp storage
			_lastTouch = moved;
		}
		
		// 1-touch pan.
		if (  (sender.numberOfTouches == 1) ) {
			if ( !_cameraInAction && !_screenEdgePan && state == UIGestureRecognizerStateChanged ) {
				if ( fabs(moved.x) > fabs(moved.y) ) {
					/*
					// dismiss texture image if pan horizontally inside its preferred thumb frame, when it is displaying
					if ( self.textureViewActive && CGRectContainsPoint(_textureView.preferredThumbFrame, firstTouchAt)
						&& CGRectContainsPoint(_textureView.preferredThumbFrame, lastTouchAt)
						&& ( lastTouchAt.x < firstTouchAt.x )
						) {
						[self dismissTopLeftImage];
						//[sender cancelsTouchesInView];
						_cameraInAction = YES;
						_cameraStopAction = YES;
						return;
					}
					 */
					
					/*
					if ( (lastTouchAt.x < firstTouchAt.x) && (
															  (firstTouchAt.y < ONE_FIFTH_HEIGHT && firstTouchAt.x > 5*ONE_FIFTH_WIDTH - 105.0)
															  || (firstTouchAt.y > ONE_FIFTH_HEIGHT && firstTouchAt.y < ONE_FIFTH_HEIGHT*3.0 && firstTouchAt.x > 5*ONE_FIFTH_WIDTH - 105.0)
															  || (firstTouchAt.y > ONE_FIFTH_HEIGHT*3.0 && firstTouchAt.x > 5*ONE_FIFTH_WIDTH - 25.0)
															  ) ) {
						// manual detect right screen edge pan
						_screenEdgePan = YES;
						_cameraInAction = NO;
					} else if ( (lastTouchAt.x > firstTouchAt.x)
							   && (firstTouchAt.y > _textureView.frame.origin.y && firstTouchAt.y < _textureView.frame.origin.y+MAX(_textureView.bounds.size.height, _textureView.preferredThumbSize.height))
							   && ( (firstTouchAt.y < ONE_FIFTH_HEIGHT && firstTouchAt.x < 105.0)
									|| (firstTouchAt.y > ONE_FIFTH_HEIGHT && firstTouchAt.y < ONE_FIFTH_HEIGHT*3.0 && firstTouchAt.x < 105.0)
									|| (firstTouchAt.y > ONE_FIFTH_HEIGHT*3.0 && firstTouchAt.x < 65.0)
									)
							   ) {
						// manual detect left screen edge pan
						// only having texture image view from the left edge pan. If added more feature via left edge pan, then, should change this testing condition.
						_screenEdgePan = YES;
						_cameraInAction = NO;
						_screenEdgeLeftPan = YES;
					} else
					 */
					if ( firstTouchAt.y < ONE_FIFTH_HEIGHT && firstTouchAt.x > ONE_SIXTH_WIDTH) {
						_cameraRotateTopWise = YES ;
						if ( self.orbitStyleTurntable ) {
							// Note! Don't set the turntable property if not necessary because animation thread may kick on.
							self.orbitStyleTurntable = NO;
						} else if ( self.orbitStyleTurntableYup ) {
							self.orbitStyleTurntableYup = NO;
						}
						_cameraInAction = YES;
					} else if ( firstTouchAt.y > (4*ONE_FOURTH_HEIGHT - 65.0) && (firstTouchAt.x < 2*ONE_FOURTH_WIDTH ) ) {
						_cameraRotateHorizontal = YES && self.cameraPerspective;
						if ( self.orbitStyleTurntable ) {
							// Note! Don't set the turntable property if not necessary because animation thread may kick on.
							self.orbitStyleTurntable = NO;
						} else if ( self.orbitStyleTurntableYup ) {
							self.orbitStyleTurntableYup = NO;
						}
						_cameraInAction = YES;
					} else {
						// allow switch to tumbling under top, front side view.
						if ( !(self.cameraTopView || self.cameraFrontView || self.cameraSideView ||
							   self.cameraBottomView || self.cameraBackView || self.cameraLeftView) ) {
							_cameraTumbling = YES;
						} else {
							//_cameraPan = YES;
							_cameraTumbling = YES;
							self.cameraTopView = NO;
							self.cameraFrontView = NO;
							self.cameraSideView = NO;
							self.cameraBottomView = NO;
							self.cameraBackView = NO;
							self.cameraLeftView = NO;
						}
						_firstTouch = lastTouchAt;
						_lastTouch = lastTouchAt;
						_cameraInAction = YES;
					}
				}
				
				if (fabs(moved.y) > fabs(moved.x)) {
					if ( firstTouchAt.x < ( 65.0 ) && firstTouchAt.y < 2*ONE_FOURTH_HEIGHT) {
						_cameraRotateLeftWise = YES && self.cameraPerspective;
					} else if ( firstTouchAt.x < ONE_FIFTH_WIDTH && firstTouchAt.y > 2*ONE_FOURTH_HEIGHT) {
						_cameraMoveForwardBackward = YES;
					} else if ( firstTouchAt.x > 4.0f*ONE_FIFTH_WIDTH && !( self.orbitStyleTurntable || self.orbitStyleTurntableYup ) ) {
						_cameraRotateRightWise = YES;
						if ( self.orbitStyleTurntable ) {
							// Note! Don't set the turntable property if not necessary because animation thread may kick on.
							self.orbitStyleTurntable = NO;
						} else if ( self.orbitStyleTurntableYup ) {
							self.orbitStyleTurntableYup = NO;
						}
						//} else if (firstTouchAt.y < ONE_SIXTH_HEIGHT || firstTouchAt.y > 5*ONE_SIXTH_HEIGHT) {
						//	_cameraRotateVertical = YES;
					} else {
						if ( !(self.cameraTopView || self.cameraFrontView || self.cameraSideView ||
							   self.cameraBottomView || self.cameraBackView || self.cameraLeftView) ) {
							_cameraTumbling = YES;
						} else {
							//_cameraPan = YES;
							_cameraTumbling = YES;
							self.cameraTopView = NO;
							self.cameraFrontView = NO;
							self.cameraSideView = NO;
							self.cameraBottomView = NO;
							self.cameraBackView = NO;
							self.cameraLeftView = NO;
						}
						_firstTouch = lastTouchAt;
						_lastTouch = lastTouchAt;
					}
					_cameraInAction = YES;
				}
			}
		}
		
		if ( _screenEdgePan ) {
			/*
			if ( _screenEdgeLeftPan ) {
				[self screenLeftEdgePanDetected:sender];
			} else {
				[self screenEdgePanDetected:sender];
			}
			 */
			if (state == UIGestureRecognizerStateEnded) {
				_screenEdgePan = NO;
				//_expandingPopoverMenu = NO;
				_screenEdgeLeftPan = NO;
			}
		}
		
		if ( _cameraInAction ) {
#if defined(DEBUG)
			if (!_debugActionDisplayed) {
				//NSLog(@"panDetected: at (%0.1f, %0.1f) tranlated (%0.1f, %0.1f), state:%ld, touches:%lu, action:%@", firstTouchAt.x, firstTouchAt.y, moved.x, moved.y, (long)state, (unsigned long)sender.numberOfTouches, [self stringFromCameraAction]);
				_debugActionDisplayed = YES;
			}
#endif
			GLKMatrix4 delta = GLKMatrix4Identity;
			//GLKMatrix4 delta2 = GLKMatrix4Identity;
			GLKVector3 rotateAxis;
			float radians = 0;
			float radians2 = 0.0;
			float deltaDist = 0;   // only used by moving forward/backward.
			/*
			if ( _internalTestView_Moving && _internalTestView != nil && !_internalTestView.hidden ) {
				CGRect newRect = CGRectOffset(_frameBeforeGesture, moved.x, moved.y);
				_internalTestView.frame = newRect;
			} else
			 */
			if ( _cameraRotateHorizontal ) {
				// rotate along view y-axis.
				rotateAxis = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make(0.0f, 1.0f, 0.0f));
				// use adaptive center to avoid large angle change.
				radians = atan2f( lastTouchAt.y - (firstTouchAt.y - ONE_SIXTH_HEIGHT), lastTouchAt.x - firstTouchAt.x) - atan2f(firstTouchAt.y - (firstTouchAt.y - ONE_SIXTH_HEIGHT), firstTouchAt.x - firstTouchAt.x);
				if ( ! isnan(radians) ) {
					//delta = GLKMatrix4RotateWithVector3(delta, M_PI_2*(moved.x/self.view.bounds.size.width) * CAMERA_PAN_HORIZONTAL_FACTOR, rotateAxis);
					//delta = GLKMatrix4Translate(delta, 0.0f, -1.0f, -7.0f);
					//NSLog(@"_cameraRay : %@, radians : %f", NSStringFromGLKVector3(_cameraRay[0]), radians);
					delta = GLKMatrix4RotateWithVector3(delta, radians, rotateAxis);
					//delta = GLKMatrix4Translate(delta, cameraPositionInWC.x, cameraPositionInWC.y, cameraPositionInWC.z);
				}
			} else if ( _cameraRotateVertical || _cameraRotateLeftWise) {
				// rotate along view z-axis.
				rotateAxis = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make(1.0f, 0.0f, 0.0f));
				// use adaptive center to avoid large angle change.
				radians = atan2f( lastTouchAt.y - firstTouchAt.y, lastTouchAt.x - (firstTouchAt.x + ONE_FIFTH_WIDTH)) - atan2f(firstTouchAt.y - firstTouchAt.y, firstTouchAt.x - (firstTouchAt.x + ONE_FIFTH_WIDTH));
				if ( ! isnan(radians) ) {
					//delta = GLKMatrix4RotateWithVector3(delta, M_PI_2*(moved.y/self.view.bounds.size.height) * CAMERA_PAN_VERTICAL_FACTOR, rotateAxis);
					delta = GLKMatrix4RotateWithVector3(delta, radians, rotateAxis);
				}
			} else if ( _cameraRotateTopWise || _cameraRotateRightWise ) {
				rotateAxis = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make(0.0f, 0.0f, -1.0f));
				if ( _cameraRotateTopWise && (self.cameraTopView || self.cameraFrontView || self.cameraSideView ||
											  self.cameraBottomView || self.cameraBackView || self.cameraLeftView) ) {
					radians = atan2f( lastTouchAt.y - ONE_FOURTH_HEIGHT*2, lastTouchAt.x - ONE_FOURTH_WIDTH*2) - atan2f(firstTouchAt.y - ONE_FOURTH_HEIGHT*2, firstTouchAt.x - ONE_FOURTH_WIDTH*2);
					// limit to 45 degrees.
					radians =  (int)(radians / M_PI_4) * M_PI_4;
				} else {
					// angle between lastTouch and firstTouch, with respect to screen center.
					radians = atan2f( lastTouchAt.y - ONE_FOURTH_HEIGHT*2, lastTouchAt.x - ONE_FOURTH_WIDTH*2) - atan2f(firstTouchAt.y - ONE_FOURTH_HEIGHT*2, firstTouchAt.x - ONE_FOURTH_WIDTH*2);
				}
				if ( ! isnan(radians) ) {
					//delta = GLKMatrix4Translate(delta, 0.0f, 1.0f, 0.0f);
					//delta = GLKMatrix4RotateWithVector3(delta, M_PI_2*(moved.y/self.view.bounds.size.height) * CAMERA_PAN_VERTICAL_FACTOR, rotateAxis);
					delta = GLKMatrix4RotateWithVector3(delta, radians, rotateAxis);
					//delta = GLKMatrix4Translate(delta, 0.0f, -1.0f, 0.0f);
				}
				
				// testing.
				/*
				if (NO && _showingHelpScreen) {
					dispatch_async(dispatch_get_main_queue(), ^{
						if (sender.numberOfTouches > 0) {
							CGPoint touch = [sender locationOfTouch:0 inView: sender.view];
							_helpScreen.control = [self adjustWithFinger:touch];
						}
						_textBanner.text = [NSString stringWithFormat:@"respect to center\ncontrol {%3.0f, %3.0f} - pen {%3.0f, %3.0f}\ncontrol {%3.0f, %3.0f} - pen {%3.0f, %3.0f}", _helpScreen.control.x - _helpScreen.center.x, _helpScreen.control.y - _helpScreen.center.y, _helpScreen.pen.x - _helpScreen.center.x, _helpScreen.pen.y - _helpScreen.center.y, _helpScreen.control.x - _helpScreen.dotCenter.x, _helpScreen.control.y - _helpScreen.dotCenter.y, _helpScreen.pen.x - _helpScreen.dotCenter.x, _helpScreen.pen.y - _helpScreen.dotCenter.y] ;
					});
				}
				 */
			} else if ( _cameraPan ) {
				float camerDistance = MAX(self.focalPlaneDistance, self.nearPlane);
				float cameraFov = [self getCameraFoV];
				float viewSize = self.cameraPerspective? camerDistance * tanf(cameraFov/2.0) : self.nearPlane * tanf(cameraFov/2.0);
				//float viewSize = [self getApparentViewingModelSize];
				float panHorizontalDistance = (moved.x/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
				float panVerticalDistance = -(moved.y/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
				GLKVector3 v = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( panHorizontalDistance, panVerticalDistance, 0.0f));
				delta = GLKMatrix4TranslateWithVector3(delta, v);
			} else if ( _cameraMoveForwardBackward ) {
				/*
				 float distance_factor = sqrtf((moved.x*moved.x+moved.y*moved.y))/(3*ONE_THIRD_WIDTH);
				 //float modelSize = [self getBoundsMaxSize];
				 float camerDistance = MIN( MAX(self.focalPlaneDistance, self.nearPlane * 3.0), [self getBoundsMaxSize]);
				 float cameraFov = [self getCameraFoV];
				 float viewSize = camerDistance * tanf(cameraFov/2.0);
				 deltaDist = -viewSize*distance_factor*(moved.y/(ONE_THIRD_HEIGHT*3));
				 */
				float minDistance = MAX( self.focalPlaneDistance, self.nearPlane * 3.0);
				float maxDistance = MIN( MAX( minDistance, [self.delegate getBoundsMaxSize]/2 ), self.farPlane - self.nearPlane) ;
				float factorAffectedMax = powf( MIN(1.0, MAX(0.0, fabs(moved.x)/(ONE_FOURTH_WIDTH*2.0))), 4.0);
				float percentage = (moved.y / (MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)));
				deltaDist = - (minDistance*percentage * (1.0 - factorAffectedMax) + maxDistance*percentage*factorAffectedMax);
				//NSLog(@"(%0.2f, %0.2f), f: %0.2f, %0.2f%%", minDistance, maxDistance, factorAffectedMax, percentage);
			} else if ( _cameraMoveInView ) {
				GLKVector2 direction = GLKVector2Make( moved.x, -moved.y );
				float movedDistance = GLKVector2Length(direction);
				if ( movedDistance > _epsilon) {
					if ( self.cameraPerspective ) {
						// opengl y axis is up.
						direction = GLKVector2Normalize(direction);
						// The rotation axis is a found by swapping x, y coordinate and negate the x value.
						GLKQuaternion quaternion = GLKQuaternionMakeWithAngleAndAxis( [self getCameraFoV]*movedDistance/(ONE_FOURTH_WIDTH*4), direction.y, -direction.x, 0.0 );
						delta = GLKMatrix4MakeWithQuaternion(quaternion);
						if ( isnan( delta.m00 ) ) {
							NSLog(@"delta matrix contains nan ");
						}
					} else {
						float cameraFov = [self getCameraFoV];
						float viewSize = self.nearPlane * tanf(cameraFov/2.0);
						float panHorizontalDistance = (moved.x/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
						float panVerticalDistance = -(moved.y/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
						GLKVector3 v = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( panHorizontalDistance, panVerticalDistance, 0.0f));
						delta = GLKMatrix4TranslateWithVector3(delta, v);
						if ( isnan( delta.m00 ) ) {
							NSLog(@"delta matrix contains nan ");
						}
					}
					
					// another implementaion
					/*
					 GLKVector3 ray2[2];
					 [self screenToEyeCoordinates:firstTouchAt into:_cameraRay];
					 [self screenToEyeCoordinates:lastTouchAt into:ray2];
					 // using projected rays fails when rotated or translated.
					 GLKQuaternion quaternion = [self quaternionFromVector:GLKVector3Subtract(_cameraRay[1], _cameraRay[0]) toVector:GLKVector3Subtract(ray2[1], ray2[0])];
					 // using the far plane having the feel of exact following touch, but fails when rotated and translated.
					 //GLKQuaternion quaternion = [self quaternionFromVector:_cameraRay[1] toVector:ray2[1]];
					 delta = GLKMatrix4MakeWithQuaternion(quaternion);
					 */
				}
			} else if ( _cameraDragRotateResize ) {
				if ( sender.numberOfTouches > 0 ) {
					delta = [self computeDragRotateResizeDelta: sender useParallelFocalPlanePanningForGrabbing:YES];
					//[self updateFovButtonTitle];
					
					_lastDeltaApplied = delta;
				} else {
					delta = _lastDeltaApplied;
					// ends recongizer
					sender.enabled = NO; sender.enabled = YES;
				}
			} else if ( _cameraTumbling ) {
				//GLKVector2 direction = GLKVector2Make(_lastTouch.x - _firstTouch.x, -(_lastTouch.y -_firstTouch.y) );
				GLKVector2 direction = GLKVector2Make(moved.x, -moved.y);
				float movedDistance = GLKVector2Length(direction);
				if (movedDistance > _epsilon) {
					// checking EPSILON to guard against initial flicker due to small rotation.
					float cameraDistance = self.adjustedFocalPlaneDistance;
					float cameraFov = [self getCameraFoV];
					float viewSize = 2.0*cameraDistance * tanf(cameraFov/2.0);
					float modelSize = [self.delegate getBoundsMaxSize];
					
					if ( self.orbitStyleTurntable || self.orbitStyleTurntableYup) {
						if (viewSize < modelSize && cameraFov < SMALL_MOVEMENT_FOR_FOV) {
							// adjust tumbling radians acoording to fov.
							radians = atan2f(viewSize, modelSize) *direction.y/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*1.0);
							radians2 = atan2f(viewSize, modelSize) *direction.x/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*1.0);
						} else {
							radians = M_PI *direction.y/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*2.0);
							radians2 = M_PI *direction.x/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*2.0);
						}
						
						// working approach 1:
						/*
						 GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radians, 1.0, 0.0, 0.0 );
						 
						 // new implementation: use focal plane for tumbling.
						 float viewTumblingDistance = cameraDistance;
						 delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -viewTumblingDistance);
						 delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
						 delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, viewTumblingDistance);
						 
						 delta2 = GLKMatrix4MakeRotation(-radians2, 0.0, 0.0, -1.0);
						 */
						
						delta = [self computeDeltaTumbling: radians horizontalRadians: radians2 withCamera:_lastCameraInfoAtGestureBegan];
						
					} else {
						if (viewSize < modelSize && cameraFov < SMALL_MOVEMENT_FOR_FOV ) {
							// adjust tumbling radians acoording to fov.
							radians = atan2f(viewSize, modelSize) *movedDistance/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*2.0);
						} else {
							radians = M_PI *movedDistance/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*4.0);
						}
						
						direction = GLKVector2Normalize(direction);
						GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radians, direction.y, -direction.x, 0.0 );
						
						// initial approach: use camera distance as approximation?  This approach has a interesting side effect of centering towards the world origin upon sequences of tumbling actions.
						// float cameraDistance = GLKVector3Length([self getCameraPosition]);
						
						// new implementation: use focal plane for tumbling.
						float viewTumblingDistance = cameraDistance;
						delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -viewTumblingDistance);
						delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
						delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, viewTumblingDistance);
						
						//if (state == UIGestureRecognizerStateEnded) {
						//	NSLog(@"cameraDistance : %0.6f, %0.6f", cameraDistance, viewTumblingDistance);
						//}
						///if (state == UIGestureRecognizerStateChanged) {
						//	NSLog(@"cameraDistance : %0.6f, %0.6f, viewSize %0.6f, modelSize %0.6f, movedf %0.6f, angle %0.2f", cameraDistance, viewTumblingDistance, viewSize, modelSize, movedDistance/(ONE_FOURTH_WIDTH*4), GLKMathRadiansToDegrees(atan2f(viewSize, modelSize)));
						//}
					}
					
				}
				if ( sender.numberOfTouches == 2 || sender.numberOfTouches == 1) {
					// if using 2 fingers for tubmling and should (sender.numberOfTouches == 2) to avoid flickering when lifting finger.
					_lastTouch = lastTouchAt;
				}
				
				/*
				// testing.
				if (NO && _showingHelpScreen) {
					dispatch_async(dispatch_get_main_queue(), ^{
						if (sender.numberOfTouches > 0) {
							CGPoint touch = [sender locationOfTouch:0 inView: sender.view];
							_helpScreen.pen = [self adjustWithFinger:touch];
						}
						_textBanner.text = [NSString stringWithFormat:@"respect to center\ncontrol {%3.0f, %3.0f} - pen {%3.0f, %3.0f}\ncontrol {%3.0f, %3.0f} - pen {%3.0f, %3.0f}", _helpScreen.control.x - _helpScreen.center.x, _helpScreen.control.y - _helpScreen.center.y, _helpScreen.pen.x - _helpScreen.center.x, _helpScreen.pen.y - _helpScreen.center.y, _helpScreen.control.x - _helpScreen.dotCenter.x, _helpScreen.control.y - _helpScreen.dotCenter.y, _helpScreen.pen.x - _helpScreen.dotCenter.x, _helpScreen.pen.y - _helpScreen.dotCenter.y] ;
					});
				}
				 */
				
			}
			
			
#if defined(DEBUG)
			//NSLog(@"rotate along : %@, for %f degrees", NSStringFromGLKVector3(rotateAxis), GLKMathRadiansToDegrees(radians));
#endif
			
			if ( sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled ) {
				if ( _cameraMoveForwardBackward ) {
					// special treatment for moving forward/backward.
					if ( !_cameraStopAction ) {
						[self moveCameraForwardDeltaCompleted:deltaDist];
					} else {
						return;
					}
				} else {
					if ( !_cameraStopAction ) {
						if (self.orbitStyleTurntable && _cameraTumbling) {
							[self applyCameraDeltaCompleted:delta];
							// use approach 2 for orbitStyleTurntable, so, no need for postpend delta2 matrix
							//[self applyCameraDeltaCompleted:delta2 postpend:YES];
						} else {
							[self applyCameraDeltaCompleted:delta];
						}
					} else {
						return;
					}
				}
				_cameraInAction = NO;
				
				if (_cameraPan) {
					//NSLog(@"camera position: %@", NSStringFromGLKVector3([self getCameraPosition]));
				}
				//if (!self.orbitStyleTurntable && ( _cameraTumbling || (_cameraRotateRightWise || _cameraRotateTopWise) ) ) {
				if ( ( _cameraTumbling || (_cameraRotateRightWise || _cameraRotateTopWise) ) ) {
					CGPoint velocity = [sender velocityInView:self.view];
					if ( sender.view != nil ) {
						// this is to cater for the case when the gesture capturing view is not self.view
						velocity = [sender velocityInView: sender.view];
					}
					
					//NSLog(@"panDetected: at (%0.1f, %0.1f) moved (%0.1f, %0.1f), state:%ld, velocity:%@, action:%@", firstTouchAt.x, firstTouchAt.y, moved.x, moved.y, (long)state, NSStringFromCGPoint(velocity), [self stringFromCameraAction]);
					
					// check ending velocity and determine to continuously tumble.
					initialVelocity = GLKVector2Make( velocity.x, velocity.y );
					float velocityMagnitude = GLKVector2Length( initialVelocity );
					//NSLog(@"pan ends with velocity magnitude : %f", velocityMagnitude);
					if ( velocityMagnitude > panEndingVelocityThreshold) {
						if (panSwipeTimer != nil) {
							[panSwipeTimer invalidate];
							panSwipeTimer = nil;
						}
						dispatch_async(dispatch_get_main_queue(), ^(void) {
							timerCount = 0;
							panDirection = initialVelocity;  // for continuous ending.
							lastDeltaContinue = GLKMatrix4Identity;
							lastDeltaContinue2 = GLKMatrix4Identity;
							continuousTumbling = YES;
							if ((_cameraRotateRightWise || _cameraRotateTopWise)) {
								_lastTouch = lastTouchAt;
								panSwipeTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(continusTumbleCameraDelta) userInfo:@"rotate" repeats:YES];
							} else {
								if (self.orbitStyleTurntable || self.orbitStyleTurntableYup) {
									_lastTouch = lastTouchAt;
									_lastCameraInfoAtGestureBegan = self.getCameraInfo;
									panSwipeTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(continusTumbleCameraDelta) userInfo:@"tumble_turntable" repeats:YES];
								} else {
									panSwipeTimer = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(continusTumbleCameraDelta) userInfo:@"tumble" repeats:YES];
								}
							}
						});
					} else {
						// spring back the locked viewing direction before tumbling.
						if ( self.lockingTumbling && _cameraTumbling) {
							[self springCameraBackToLockingDirection];
						}
					}
				} else if ( _cameraDragRotateResize ) {
					// spring back the locked viewing direction before tumbling.
					if ( self.lockingTumbling ) {
						[self springCameraBackToLockingDirection];
					}
				}
			} else {
				if ( continuousTumbling ) {
					[self stopContinuousTumbling];
				}
				if ( _cameraMoveForwardBackward ) {
					// special treatment for moving forward/backward.
					[self moveCameraForwardDelta:deltaDist];
				} else {
					if (self.orbitStyleTurntable && _cameraTumbling) {
						[self applyCameraDelta:delta];
						// use approach 2 for orbitStyleTurntable, so, no need for postpend delta2 matrix
						//[self applyCameraDelta:delta2 postpend:YES];
					} else {
						if ( ! isnan( delta.m00 ) ) {
							[self applyCameraDelta:delta];
						}
					}
				}
			}
		}
	}
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
		[self.delegate gestureDetectedPostprocessing:sender];
	}

	// reset some states after done gesture
	if ( sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateCancelled ) {
		_cameraInAction = NO;
		_cameraRotateHorizontal = NO;
		_cameraRotateVertical = NO;
		_cameraRotateLeftWise = NO;
		//_cameraRotateRightWise = NO;			// not reset, state may be used by continuous tumbling
		//_cameraRotateTopWise = NO;			// not reset, state may be used by continuous tumbling
		_cameraMoveInView = NO;
		_cameraPan = NO;
		_cameraMoveForwardBackward = NO;
		_cameraChangeFOV = NO;
		_cameraPanAndRotateInTandem = NO;
		//_cameraTumbling = NO;					// not reset, state may be used by continuous tumbling
		_cameraDragRotateResize = NO;
		
		_screenEdgePan = NO;
		_screenEdgeLeftPan = NO;
		_debugActionDisplayed = NO;
		
		_cameraPan_ForPanMore = NO;
		_cameraRotate_ForPanMore = NO;
		_cameraTumbling_ForPanMore = NO;
		_cameraPinch_ForPanMore = NO;
		_pencilPinch_ForPanMore = NO;
		
		//_internalTestView_Moving = NO;
		
		//[self updateFovButtonTitle];
	}
	
#if defined(DEBUG)
	//NSLog(@"panDetected: _action %i, horizontal %i, vertical %i, pan %i", _cameraInAction, _cameraRotateHorizontal, _cameraRotateVertical, _cameraPan);
#endif
	
}

- (IBAction)tapDetected:(UITapGestureRecognizer *)sender {
	
	// reset the last active timestamp.
	[self touchLastActiveTimestamp];
	CGPoint lastTouchAt = [sender locationInView:self.view];
	if ( sender.view != nil ) {
		lastTouchAt = [sender locationInView: sender.view];
	}
	
	//[self screenToEyeCoordinates:lastTouchAt into:_cameraRay];
	//NSLog(@"tapDetected: %@, at (%0.1f, %0.1f), tap near plane at %@, far plane at %@, camera at WC : %@", sender, lastTouchAt.x, lastTouchAt.y,  NSStringFromGLKVector3(_cameraRay[0]), NSStringFromGLKVector3(_cameraRay[1]), NSStringFromGLKVector3([self getCameraPosition]));
	
	if ( sender.numberOfTouches == 1 ) {
		touchingFocus.center = [sender locationOfTouch:0 inView: sender.view];
		touchingFocus.hidden = YES;
		
		// animate the touching focus
		//[self animateTouchingFocus];
	}
	
	if ( sender.state == UIGestureRecognizerStateEnded ) {
		_channelGestureInAction = NO;
		
		if ( [self.delegate respondsToSelector:@selector(shouldChannelGesture:)] ) {
			_channelGestureInAction = [self.delegate shouldChannelGesture: sender];
		}
		_continueGestureProcessing = YES;
	}
	
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPreprocessing:)] ) {
		_continueGestureProcessing = [self.delegate gestureDetectedPreprocessing:sender];
	}
	
	if ( !_continueGestureProcessing) return;
	
	if ( self.channelGestureInAction ) {
		
		if ( [self.delegate respondsToSelector:@selector(channelGestureHandler:)] ) {
			[self.delegate channelGestureHandler:sender];
		}
		
		if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
			[self.delegate gestureDetectedPostprocessing:sender];
		}
		
		return;
	}
	

/*
	// channel to tapping fovControl
	if ( CGRectContainsPoint(fovControl.frame, lastTouchAt)) {
		[UIView animatePushView: fovControl];
		[self fovControlTapped:sender];
		return;
	}
*/

/*
	// tap for previous camera view.
	if ( CGRectContainsPoint( CGRectMake(undoViewButton.frame.origin.x, undoViewButton.frame.origin.y, undoViewButton.frame.size.width, ONE_FOURTH_HEIGHT*4.0 - undoViewButton.frame.origin.y), lastTouchAt) ) {
		//[UIView animatePushView: undoViewButton];
		[self undoCameraDelta];
		sender.enabled = NO;  sender.enabled = YES;
		return;
	}
*/

/*
	// tap at lock tumbling icon to toggle between lock and unlock.
	if ( CGRectContainsPoint(self.lockTumblingIcon.frame, lastTouchAt) ) {
		NSLog(@"toggle lock tumbling");
		//[UIView animatePushView: lockTumblingIcon];
		self.lockingTumbling = !self.lockingTumbling;
		if ( self.lockingTumbling ) {
			//lockTumblingIcon.image = [UIImage imageNamed: @"tumbling_lock_icon.png"];
			self.lockingViewDir = [self getCameraViewDirection];
		} else {
			//lockTumblingIcon.image = [UIImage imageNamed: @"tumbling_unlock_icon.png"];
		}
		return;
	}
*/
	
	// reset the last active timestamp.
	[self touchLastActiveTimestamp];
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
		[self.delegate gestureDetectedPostprocessing:sender];
	}
	
}

- (IBAction)doubleTapDetected:(UITapGestureRecognizer *)sender
{
	
	[self touchLastActiveTimestamp];
	CGPoint lastTouchAt = [sender locationInView:self.view];
	if ( sender.view != nil ) {
		lastTouchAt = [sender locationInView: sender.view];
	}
	
	//[self screenToEyeCoordinates:lastTouchAt into:_cameraRay];
	//NSLog(@"doubleTapDetected: %@, at (%0.1f, %0.1f), tap near plane at %@, far plane at %@, camera at WC : %@", sender, lastTouchAt.x, lastTouchAt.y,  NSStringFromGLKVector3(_cameraRay[0]), NSStringFromGLKVector3(_cameraRay[1]), NSStringFromGLKVector3([self getCameraPosition]));
	
	if ( sender.state == UIGestureRecognizerStateEnded ) {
		_channelGestureInAction = NO;
		
		if ( [self.delegate respondsToSelector:@selector(shouldChannelGesture:)] ) {
			_channelGestureInAction = [self.delegate shouldChannelGesture: sender];
		}
		_continueGestureProcessing = YES;
		
		/*
		CGRect rect = [self.view convertRect:_axisManipulator.circleForGrabbing fromView:_axisManipulator];
		if ( !_axisManipulator.isHidden && CGRectContainsPoint(rect, lastTouchAt) ) {
			_channelGestureInAction = YES;
		}
		
		// turn camera view to left, right, or top
		rect = [self.view convertRect:_axisManipulator.circleForLeft90DegreeView fromView:_axisManipulator];
		if ( !_axisManipulator.isHidden && CGRectContainsPoint( rect, lastTouchAt) ) {
			[self animateCameraViewToLeft:M_PI_2];
			//[sender cancelsTouchesInView];
			return;
		}
		rect = [self.view convertRect:_axisManipulator.circleForRight90DegreeView fromView:_axisManipulator];
		if ( !_axisManipulator.isHidden && CGRectContainsPoint( rect, lastTouchAt) ) {
			[self animateCameraViewToRight:M_PI_2];
			//[sender cancelsTouchesInView];
			return;
		}
		rect = [self.view convertRect:_axisManipulator.circleForTop90DegreeView fromView:_axisManipulator];
		if ( !_axisManipulator.isHidden && CGRectContainsPoint( rect, lastTouchAt) ) {
			[self animateCameraViewToTop:M_PI_2];
			//[sender cancelsTouchesInView];
			return;
		}
		if (self.textureViewActive && !_channelGestureInAction ) {
			// double tap at lower right corner of the axis manipulator, or the texture view, ie., the uv icons, to toggle UV editing
			BOOL fingerInsideTextureView = CGRectContainsPoint(_textureView.frame, lastTouchAt);
			rect = [self.view convertRect:_axisManipulator.circleForUVMapping fromView:_axisManipulator];
			CGRect otherRect = CGRectMake(_textureView.frame.origin.x + _textureView.frame.size.width - 50, _textureView.frame.origin.y + _textureView.frame.size.height - 50, 50, 50);
			if ( CGRectContainsPoint(rect, lastTouchAt) || ( fingerInsideTextureView && CGRectContainsPoint(otherRect, lastTouchAt) ) ) {
				[UIView animatePushView: _textureView.uvActionStatusButton];
				[UIView animatePushView: _axisManipulator];
				_textureView.textureUVInAction = !_textureView.textureUVInAction;
				_axisManipulator.textureUVInAction = _textureView.textureUVInAction;
				[self refreshTextureMappingFromMesh];
				//[sender cancelsTouchesInView];
				return;
			}
			
			// double tap at the zoomingImageIcon for reset image to fit the imageView.
			if ( fingerInsideTextureView && [_textureView hitZoomingIcons: [self.view convertPoint: lastTouchAt toView:_textureView]] ) {
				[UIView animatePushView: _textureView.zoomingImageIcon];
				[UIView animatePushView: _textureView.zoomingImageIcon2];
				[_textureView resetTextureMappingImageOffsets];
				return;
			}
		}
		
		// double tap icon for minimize
		if ( !_channelGestureInAction && (_editingElementsBoxSelectionAddToSet_InSelection||_editingElementsBoxSelectionMinusFromSet_InSelection) ) {
			// minimize box selection and circle selection.
			if ( _editingElementsBoxSelectionAddToSet_InSelection && !_editingElementsBoxSelectionAddToSet.isHidden && CGRectContainsPoint(_editingElementsBoxSelectionAddToSet.frame, lastTouchAt) ) {
				CGRect newRect = _editingElementsBoxSelectionAddToSet.frame;
				if ( _editingElementsBoxSelectionAddToSet_InSelection ) {
					_editingElementsBoxSelectionAddToSet_InSelection = NO;
					newRect = _editingElementsBoxSelectionAddToSet_savedFrame;
				}
				
				[self updateConstraints:_editingElementsBoxSelectionAddToSet withKey:@"_editingElementsBoxSelectionAddToSet" toFrame:newRect];
				[UIView animateWithDuration:0.3 animations:^{
					//_editingElementsBoxSelectionAddToSet.frame = newRect;
					[self.view layoutIfNeeded];
					_editingElementsBoxSelectionAddToSet.layer.borderColor = grayColor.CGColor;
					if ( _editingElementsBoxSelectionAddToSet.layer.cornerRadius > 2 ) {
						_editingElementsBoxSelectionAddToSet.layer.cornerRadius = newRect.size.width/2.0;
					}
				} completion:^(BOOL finished) {
				}];
				//[sender cancelsTouchesInView];
				return;
			}
			
			if ( _editingElementsBoxSelectionMinusFromSet_InSelection && !_editingElementsBoxSelectionMinusFromSet.isHidden && CGRectContainsPoint(_editingElementsBoxSelectionMinusFromSet.frame, lastTouchAt) ) {
				CGRect newRect ;
				if ( _editingElementsBoxSelectionMinusFromSet_InSelection ) {
					_editingElementsBoxSelectionMinusFromSet_InSelection = NO;
					newRect =_editingElementsBoxSelectionMinusFromSet_savedFrame;
				}
				
				[self updateConstraints:_editingElementsBoxSelectionMinusFromSet withKey:@"_editingElementsBoxSelectionMinusFromSet" toFrame:newRect];
				[UIView animateWithDuration:0.3 animations:^{
					//_editingElementsBoxSelectionMinusFromSet.frame = newRect;
					[self.view layoutIfNeeded];
					_editingElementsBoxSelectionMinusFromSet.layer.borderColor = grayColor.CGColor;
					if ( _editingElementsBoxSelectionMinusFromSet.layer.cornerRadius > 2 ) {
						_editingElementsBoxSelectionMinusFromSet.layer.cornerRadius = newRect.size.width/2.0;
					}
				} completion:^(BOOL finished) {
				}];
				//[sender cancelsTouchesInView];
				return;
			}
		}
		
		// do nothing if double tap at the minimized selection icons.
		if ( !_channelGestureInAction && !_editingElementsBoxSelectionAddToSet.isHidden && (CGRectContainsPoint(_editingElementsBoxSelectionAddToSet.frame, lastTouchAt) || CGRectContainsPoint(_editingElementsBoxSelectionMinusFromSet.frame, lastTouchAt))) {
			//[sender cancelsTouchesInView];
			return;
		}
		*/
	}
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPreprocessing:)] ) {
		_continueGestureProcessing = [self.delegate gestureDetectedPreprocessing:sender];
	}
	
	if ( !_continueGestureProcessing) return;
	
	if ( self.channelGestureInAction ) {
		
		if ( [self.delegate respondsToSelector:@selector(channelGestureHandler:)] ) {
			[self.delegate channelGestureHandler:sender];
		}
		
		if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
			[self.delegate gestureDetectedPostprocessing:sender];
		}
		
		return;
	}
	
	/*
	if ( _channelGestureInAction ) {
		[_axisManipulator tapGestureDetected:sender];
		return;
	}
	 */
	
	/*
	// tap within mini axis for redo action.
	if ( CGRectContainsPoint(_miniAxisView.frame, lastTouchAt)) {
		if ( theGround.canRedo ) {
			[menuViewController activateMenuCommand: CMD_OBJECT_MODE_REDO];
		}
		return;
	}
	
	// tap within undo operation button for redo action.
	if ( self.glkviewVisible && CGRectContainsPoint(undoOperationButton.frame, lastTouchAt)) {
		if ( theGround.canRedo ) {
			[menuViewController activateMenuCommand: CMD_OBJECT_MODE_REDO];
		}
		return;
	}
	
	// double tap at focus hint to refocus on center.
	if ( !_refocusHint.isHidden ) {
		if ( CGRectContainsPoint(_refocusHint.frame, lastTouchAt)) {
			if ( [theGround getCameraFoV] >= (M_PI - EPSILON) ) {
				[theGround setCameraFoV: GLKMathDegreesToRadians( theGround.defaultFovInDegree ) ];
				[self updateFovButtonTitle];
			}
			
			[self animateCameraCenterTo:theGround.selectionCentroid completion:^{
				if ( theGround.orbitStyleTurntable ) {
					// re-adjust z-up after animating center
					theGround.orbitStyleTurntable = YES;
				} else if ( theGround.orbitStyleTurntableYup ) {
					theGround.orbitStyleTurntableYup = YES;
				} else {
					// spring back the locked viewing direction before tumbling.
					if ( lockingTumbling ) {
						[self springCameraBackToLockingDirection];
					}
				}
			}];
			if ( theGround.hasSelectedObject ) {
				[theGround resetFocalPlaneToSelectedCentroid];
				if ( self.isPencilDrawingOn ) {
					[self updatePencilViewPortCentroid];
				}
			} else {
				[theGround resetFocalPlaneToBoundsCenter];
			}
			
			//[sender cancelsTouchesInView];
			return;
		}
	}
	
	// doulbe tap at trash bin to clear history
	if ( CGRectContainsPoint(_trashBinButton.frame, lastTouchAt)) {
		if ( [theGround canRedo] || [theGround canUndo] ) {
			[self clearUndoHistory];
		}
		//[sender cancelsTouchesInView];
		return;
	}
	
	// tap within right side menu to expand the menu.
	if ( _rightSideMenuPane.isHidden && !([self isLeftSideMenuVisible] && self.collectionView.bounds.size.width > _rightSideMenuPane.frame.origin.x) && CGRectContainsPoint(_rightSideMenuPane.frame, lastTouchAt) ) {
		[self expandRightSideMenu:sender];
		return;
	}
	
	// minimize and hidden proportional edit circle, when double tapped.
	if ( !_proportionalEditCircle.isHidden && CGRectContainsPoint(_proportionalEditCircle.frame, lastTouchAt) ) {
		_proportionalEditCircleAdjusting = NO;
		CGRect newRect = [self.view convertRect:_axisManipulator.circleForGrabbing fromView:_axisManipulator];
		newRect = CGRectInset(newRect, newRect.size.width/4.0, newRect.size.height/4.0);
		[UIView animateWithDuration:0.3 animations:^{
			_proportionalEditCircle.frame = newRect;
			_proportionalEditCircle.layer.cornerRadius = newRect.size.width/2.0;
		} completion:^(BOOL finished) {
			_proportionalEditCircle.frame = newRect;
			_proportionalEditCircle.layer.cornerRadius = newRect.size.width/2.0;
			[_proportionalEditCircle setHidden:YES];
			theGround.currentProportionalRadius = 0;
		}];
		//[sender cancelsTouchesInView];
		return;
	}
	*/
	
	// double tap, near the bottom area, to zoom in or zoom out.
	if ( lastTouchAt.y > 4*ONE_FIFTH_HEIGHT ) {
		float zoom = 1.0;
		if ( lastTouchAt.y < 2*ONE_FOURTH_HEIGHT || lastTouchAt.x < 2*ONE_FOURTH_WIDTH) {
			zoom = 0.5;
		} else {
			zoom = 2.0;
		}
		if ( self.cameraPerspective ) {
			[self applyCameraZoomFactorCompleted:zoom];
		} else {
			[self applyCameraZoomFactorCompleted:[self convertToOrthoViewSizeScale:zoom]];
		}
		// show the field of view degree after zooming.
		//[self updateFovButtonTitle];
		return;
	}
	
	BOOL hasSelection = self.delegate.hasSelectedObject;
	if ( !hasSelection ) {
		// otherwise, serve as tap to select, if none had selected.
		/*
		if ( [self selectObjectWithScreenCoord:lastTouchAt]) {
			return;
		} else {
			if (theGround.hasActiveMeshEditingObject) {
				[theGround meshEditPickPreviousSet];
				[menuViewController refreshMenuStatus];
				//[sender cancelsTouchesInView];
			}
		}
		 */
	} else {
		// use background queue to test if the arrow animation will use non-main thread.
		// no use, the layer animation still launch from the main thread.
		//dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

			[self centerOnLocation: self.delegate.selectionCentroid];
		//});
		
		/*
		if ( self.isPencilDrawingOn ) {
			[self updatePencilViewPortCentroid];
		}
		 */
		
		// screen capture testing,  this works good
		/*
		 GLKView *view = (GLKView *)self.view;
		 UIImage * snapshot = [view snapshot];
		 if ( snapshot ) {
		 NSLog(@"snapshotted : %@", snapshot);
		 UIPasteboard * board = [UIPasteboard generalPasteboard];
		 board.image = snapshot;
		 }
		 */
	}
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
		[self.delegate gestureDetectedPostprocessing:sender];
	}
	

}

- (IBAction)pinchDetected:(UIPinchGestureRecognizer *)sender {
	[self touchLastActiveTimestamp];
	CGPoint lastTouchAt = [sender locationInView:self.view];
	NSInteger state = [sender state];
	
	if ( state == UIGestureRecognizerStateBegan ) {
		_channelGestureInAction = NO;
		
		if ( [self.delegate respondsToSelector:@selector(shouldChannelGesture:)] ) {
			_channelGestureInAction = [self.delegate shouldChannelGesture: sender];
		}
		
		_continueGestureProcessing = YES;
	}
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPreprocessing:)] ) {
		_continueGestureProcessing = [self.delegate gestureDetectedPreprocessing:sender];
	}
	
	if ( !_continueGestureProcessing) return;
	
	if ( self.channelGestureInAction ) {
		
		if ( [self.delegate respondsToSelector:@selector(channelGestureHandler:)] ) {
			[self.delegate channelGestureHandler:sender];
		}
		
		if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
			[self.delegate gestureDetectedPostprocessing:sender];
		}
		
		return;
	}
	

	if ( YES ) {
		if ( state == UIGestureRecognizerStateBegan ) {
			// hide touching focus
			[touchingFocus setHidden:YES];
			_firstTouch = lastTouchAt;
			
			_cameraInAction = NO;
			_cameraRotateHorizontal = NO;
			_cameraRotateVertical = NO;
			_cameraRotateLeftWise = NO;
			_cameraRotateRightWise = NO;
			_cameraRotateTopWise = NO;
			_cameraMoveInView = NO;
			_cameraPan = NO;
			_cameraMoveForwardBackward = NO;
			_cameraChangeFOV = NO;
			_cameraDragRotateResize = NO;
			_cameraPanAndRotateInTandem = NO;
			_cameraTumbling = NO;
			_screenEdgePan = NO;
			_debugActionDisplayed = NO;
			//_proportionalEditCircleInAction = NO;
			//_resizingTextureViewAction = NO;
			_channelGestureInAction = NO;
			//_channelGestureUVInAction = NO;
			//_pencilManipulator.resizingPencilAction = NO;
			_lastSingleFingerLifted = NO;
			
			_continueGestureProcessing = YES;
			
			if (lastTouchAt.x > 2.0*ONE_THIRD_WIDTH && lastTouchAt.y < 2.0*ONE_SIXTH_HEIGHT) {
				// pinch in upper right corner, change camera field of view, FOV
				_cameraInAction = YES;
				_cameraChangeFOV = YES;
				
			}
			
			// other pinching area, move camera forward, or backward.
			if (!_cameraInAction && _continueGestureProcessing ) {
				_cameraInAction = YES;
				_cameraMoveForwardBackward = YES;
				
				// pinch with camera move in view, toggle between old implementation and new approach
				_cameraMoveInView = YES;
				
				if ( _cameraMoveInView ) {
					// supports both scnview and glkview
					// for scnview, the panning under pinching is still not perfect. there are flickrings.
					_lastCameraInfoAtGestureBegan = self.getCameraInfo;
					_firstTouch = lastTouchAt;
					_lastTouch = lastTouchAt;
					// reuse variable, handles deviation when lifting and retouching down one of the pinching fingers.
					_lastFingersCenterDeviation = GLKVector2Make( 0, 0 );
					_pinchCenterMoved = NO;
				} else {
					// old implementation, pinching does not pan center
					//_lastCameraInfoAtGestureBegan = _sceneKitController.getCameraInfo;
				}
			}
			
		}
		

		if ( _cameraInAction ) {
#if defined(DEBUG)
			if (!_debugActionDisplayed) {
				//NSLog(@"pinchDetected: scale = %f, last touch at (%0.1f, %0.1f), state:%ld, touches:%lu, action:%@", sender.scale, lastTouchAt.x, lastTouchAt.y, (long)state, (unsigned long)sender.numberOfTouches, [self stringFromCameraAction]);
				_debugActionDisplayed = YES;
			}
#endif
			
			GLKMatrix4 delta = GLKMatrix4Identity;
			GLKVector2 movedInView = GLKVector2Make(0, 0);
			if ( sender.numberOfTouches == 2 ) {
				if ( _lastSingleFingerLifted == YES ) {
					_lastSingleFingerLifted = NO;
					_lastFingersCenterDeviation = GLKVector2Make( lastTouchAt.x - _lastTouch.x, lastTouchAt.y - _lastTouch.y );
				}
				if ( !_pinchCenterMoved && GLKVector2Length(GLKVector2Make(lastTouchAt.x - _firstTouch.x, lastTouchAt.y - _firstTouch.y)) < 2*_THUMB_SIZE ) {
					// this is to make the pinching center less sensitive to un-intended flickring movment.
					_lastFingersCenterDeviation = GLKVector2Make( lastTouchAt.x - _firstTouch.x, lastTouchAt.y - _firstTouch.y );
				} else {
					_pinchCenterMoved = YES;
				}
				_lastTouch = CGPointMake( lastTouchAt.x - _lastFingersCenterDeviation.x, lastTouchAt.y - _lastFingersCenterDeviation.y );
			} else {
				// lifted a finger
				if ( _lastSingleFingerLifted != YES ) {
					_lastSingleFingerLifted = YES;
					_lastFingersCenterDeviation = GLKVector2Make( lastTouchAt.x - _lastTouch.x, lastTouchAt.y - _lastTouch.y );
				}
				_lastTouch = CGPointMake( lastTouchAt.x - _lastFingersCenterDeviation.x, lastTouchAt.y - _lastFingersCenterDeviation.y );
			}
			CGPoint moved = CGPointMake(_lastTouch.x - _firstTouch.x, _lastTouch.y - _firstTouch.y);
			movedInView = GLKVector2Make( moved.x * _nativeScale, (- moved.y) * _nativeScale );
			
			if ( _cameraChangeFOV ) {
				if ( !self.cameraPerspective ) {
					self.cameraZoomFactor /= [self convertToOrthoViewSizeScale:sender.scale];
				} else {
					self.cameraZoomFactor /= sender.scale;
				}
				//[self updateFovButtonTitle];
				
			} else if ( _cameraMoveForwardBackward ) {
				[self stopContinuousTumbling];
				//if ( self.scnviewVisible ) {
				//	[theGround applyCameraZoomFactorDelta:sender.scale fovOnly:NO usingReferenceBoundsCenter: _lastCameraInfoAtGestureBegan.focusPoint];
				//} else
				{
					
					if ( _cameraDragRotateResize ) {
						delta = [self computeDragRotateResizeDelta: sender useParallelFocalPlanePanningForGrabbing:YES];
						_lastDeltaApplied = delta;
					} else if ( _cameraMoveInView ) {
						// move and pinch
						if ( self.cameraPerspective ) {
							[self applyCameraZoomFactorDelta: sender.scale deviateInView: movedInView];
						} else {
							[self applyCameraZoomFactorDelta: sender.scale fovOnly:YES deviateInView: movedInView];
						}
					} else {
						[self applyCameraZoomFactorDelta:sender.scale];
					}
					
				}
				// this impacts performance
				//[self updateFovButtonTitle];
				
				//NSLog(@"zoom scale : %0.6f", sender.scale);
			}
			
			if ( (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) && _cameraMoveForwardBackward ) {
				//if ( self.scnviewVisible ) {
				//	[theGround applyCameraZoomFactorCompleted:sender.scale fovOnly:NO usingReferenceBoundsCenter: _lastCameraInfoAtGestureBegan.focusPoint];
				//} else
				{
					
					if ( _cameraDragRotateResize ) {
						[self applyCameraDeltaCompleted: delta];
						// spring back the locked viewing direction before tumbling.
						if ( self.lockingTumbling ) {
							[self springCameraBackToLockingDirection];
						}
					} else if ( _cameraMoveInView ) {
						if ( self.cameraPerspective ) {
							[self applyCameraZoomFactorCompleted:sender.scale deviateInView: movedInView];
							// spring back the locked viewing direction before tumbling.
							if ( self.lockingTumbling ) {
								[self springCameraBackToLockingDirection];
							}
							
						} else {
							[self applyCameraZoomFactorCompleted: sender.scale fovOnly:YES deviateInView: movedInView];
						}
					} else {
						[self applyCameraZoomFactorCompleted:sender.scale];
					}
				}
				//[self updateFovButtonTitle];
				
			} else if (_cameraMoveForwardBackward) {
				if ( _cameraDragRotateResize ) {
					[self applyCameraDelta: delta];
				} else if ( _cameraMoveInView ) {
					if ( self.cameraPerspective ) {
						[self applyCameraZoomFactorDelta: sender.scale deviateInView: movedInView];
					} else {
						[self applyCameraZoomFactorDelta: sender.scale fovOnly:YES deviateInView: movedInView];
						//[self updateFovButtonTitle];
					}
				}
			}
		}
		//NSLog(@"theGround.patternSize : %f", theGround.patternSize);
	}
	
	/*
	 // for controlling the ground's grid size.
	 if ([sender state] == UIGestureRecognizerStateBegan || [sender state] == UIGestureRecognizerStateChanged) {
	 theGround.gridSize /= sender.scale;
	 NSLog(@"theGround.gridSize : %f", theGround.gridSize);
	 [theGround modifyGroundSize];
	 }
	 */
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
		[self.delegate gestureDetectedPostprocessing:sender];
	}
	
	// pinch gesture reset scale.
	if ([sender state] == UIGestureRecognizerStateBegan || [sender state] == UIGestureRecognizerStateChanged) {
		
		if ( _cameraInAction ) {
			[sender setScale:1];
		}
	}
	
	if ( state != UIGestureRecognizerStateBegan && state != UIGestureRecognizerStateChanged ) {
		
		_cameraInAction = NO;
		_cameraMoveForwardBackward = NO;
		_cameraDragRotateResize = NO;
		_cameraChangeFOV = NO;
		//_channelGestureUVInAction = NO;
		_cameraMoveInView = NO;
		
		//_editingElementsBoxSelectionAddToSet_Moving = NO;
		//_editingElementsBoxSelectionMinusFromSet_Moving = NO;
		//_proportionalEditCircleInAction = NO;
		//_resizingTextureViewAction = NO;
		//_pencilManipulator.resizingPencilAction = NO;
		_lastSingleFingerLifted = NO;
		
		// try to make recognizers more responsive immediately after an gesture end.
		self.panRecognizer.enabled = NO; self.panRecognizer.enabled = YES;
		self.longPressRecognizer.enabled = NO; self.longPressRecognizer.enabled = YES;
		
	}
	
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	/*
	if ( gestureRecognizer == holdAndSelectGesture && otherGestureRecognizer == holdAndDeSelectGesture ) {
		return YES;
	}
	if ( gestureRecognizer == holdAndDeSelectGesture && otherGestureRecognizer == holdAndSelectGesture ) {
		return YES;
	}
	if ( gestureRecognizer == holdAndSlideVertexGesture || otherGestureRecognizer == holdAndSlideVertexGesture ) {
		return YES;
	}
	if ( gestureRecognizer == panRecognizer && otherGestureRecognizer == revolvingAxisGesture ) {
		return YES;
	}
	 */
	if ( gestureRecognizer == self.panRecognizer && otherGestureRecognizer == self.pinchRecognizer ) {
		return NO;
	}
	
	return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	/*
	if ( gestureRecognizer == longPressRecognizer && otherGestureRecognizer == holdAndSelectGesture ) {
		// the long press gesture will wait until hold-n-select gesture failed
		return YES;
	}
	if ( gestureRecognizer == longPressRecognizer && otherGestureRecognizer == holdAndDeSelectGesture ) {
		// the long press gesture will wait until hold-n-deselect gesture failed
		return YES;
	}
	if ( gestureRecognizer == longPressRecognizer && otherGestureRecognizer == pencilRecognizer) {
		// the long press gesture will wait until the pencil gesture failed.
		return YES;
	}
	if ( gestureRecognizer == longPressRecognizer && otherGestureRecognizer == holdAndSlideVertexGesture) {
		// the long press gesture will wait until hold-n-deselect gesture failed
		return YES;
	}
	if ( gestureRecognizer == panRecognizer && otherGestureRecognizer == revolvingAxisGesture) {
		// panning gesture will wait until the revolving gesture failed.
		//return YES;
	}
	 */
	if ( gestureRecognizer == self.pinchRecognizer && otherGestureRecognizer == self.panRecognizer) {
		return NO;
	}
	
	return NO;
}

- (IBAction)longPressDetected:(UIGestureRecognizer *)sender {
	NSInteger state = [sender state];
	//NSLog(@"long press: %d, camera(%d): %@", state, _cameraInAction, [self stringFromCameraAction]);
	
	[self touchLastActiveTimestamp];
	CGPoint lastTouchAt = [sender locationInView:self.view];
	if ( sender.view != nil ) {
		lastTouchAt = [sender locationInView: sender.view];
	}
	
	//BOOL isPaintingColor = !_colorPicker.isHidden && _colorPicker.applyState;
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPreprocessing:)] ) {
		_continueGestureProcessing = [self.delegate gestureDetectedPreprocessing:sender];
	}
	
	if ( sender.state == UIGestureRecognizerStateBegan ) {
		// hide touching focus
		[touchingFocus setHidden:YES];
		[sender setCancelsTouchesInView:YES];
		
		// channel the gesture to the axis manipulator, such as to detect tap in this view
		// and, allow manipulation in axis manipulator.
		_channelGestureInAction = NO;

		if ( [self.delegate respondsToSelector:@selector(shouldChannelGesture:)] ) {
			_channelGestureInAction = [self.delegate shouldChannelGesture: sender];
		}
		_continueGestureProcessing = YES;

		// long press at mid-upper edge, toggle between orbit Z-up styles.
		if ( !_channelGestureInAction && lastTouchAt.x > 2.0*ONE_FIFTH_WIDTH && lastTouchAt.x < 3.0*ONE_FIFTH_WIDTH && lastTouchAt.y < 65.0) {
			self.orbitStyleTurntable ^= YES;
			//[sender cancelsTouchesInView];
			sender.enabled = NO; sender.enabled = YES;
			return;
		}
		
		// long press at mid-left edge, toggle between orbit Y-up styles.
		if ( !_channelGestureInAction && lastTouchAt.y > 2.0*ONE_FOURTH_HEIGHT-35.0 && lastTouchAt.y < 2.0*ONE_FOURTH_HEIGHT+35 && lastTouchAt.x < 65.0) {
			self.orbitStyleTurntableYup ^= YES;
			//[sender cancelsTouchesInView];
			sender.enabled = NO; sender.enabled = YES;
			return;
		}
			
	}
	
	if ( !_continueGestureProcessing) return;
	
	if ( self.channelGestureInAction ) {
		
		if ( [self.delegate respondsToSelector:@selector(channelGestureHandler:)] ) {
			[self.delegate channelGestureHandler:sender];
		}
		
		if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
			[self.delegate gestureDetectedPostprocessing:sender];
		}
		
		return;
	}
	
	/*
	if ( _channelGestureInAction ) {
		// hide proportional circle when moving gesture.
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			_proportionalEditCircleInAction = YES;
			// show proportional radius if applying color
			if ( !isPaintingColor) {
				_proportionalEditCircle.hidden = YES;
			}
		}
		
		// prepare camera info for grabbing
		if ( state == UIGestureRecognizerStateBegan ) {
			_axisManipulator.lastCamera = [theGround getCameraInfo];
			_axisManipulator.panningGesture = sender;
		}
		
		_lastTouch = lastTouchAt;
		// channel the gesture event to the axis manipulator
		
		// as a flag to make the grabbing effective in the translationInCamera method
		if ( _axisManipulator.lastCamera == nil ) {
			// lastCamera may have nullified as a flag to ignore first touch dragging momentarily, so, resume last camera
			_axisManipulator.lastCamera = [theGround getCameraInfo];
		}
		
		[self moveCameraForAdditionalTouchWhenDragging: sender touches:nil withEvent:nil];
		if ( _singleBoneTailInAction || _singleBoneHeadInAction || _singleBoneMidInAction ) {
			// start long press handling even initial touch is not at the circle grab
			CGPoint pointInSelfView = [self.view convertPoint:_axisManipulator.center toView:_axisManipulator];
			[_axisManipulator longPressHandler:lastTouchAt inSelf:pointInSelfView state:sender.state];
		} else {
			[_axisManipulator longPressDetected:sender];
		}
		
		// disable dash guide line if moving orthogonally to the guideline forward and back again
		// , with distance exceed thumbsize
		// , in 1 second
		if ( _axisManipulator.shouldShowDirectionDashGuideline ) {
			[_axisManipulator checkDashGuidelineCancelingCondition:sender];
		}
		
		// show proportional circle after done.
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			// after the END state, set to NO will make the proportional edit circle as if no present.
			// So, check if the manipulator is still in hanlder-in-action before setting it to NO.
			if (!_axisManipulator.handlerInAction) {
				_proportionalEditCircleInAction = NO;
			}
			[_proportionalEditCircle setHidden:NO];
		}
		if ( !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)  ) {
			if ( _shouldRefocusUponGestureCompletion && _refousSelectionRecords != nil ) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[theGround selectObjectWithEditingRecords:_refousSelectionRecords pickSingle:YES];
					[self updateAxisManipulatorWithAnimation:YES];
					[self updateSelectionObjectInfo];
					_refousSelectionRecords = nil;
					
					if (self.textureViewActive) {
						[self refreshTextureMappingFromMesh];
					}
				});
			}
			if ( _shouldRefocusUponGestureCompletion ) {
				_axisManipulator.circleOnly = NO;
			}
			_shouldRefocusUponGestureCompletion = NO;
			_axisManipulator.shouldShowDirectionDashGuideline = NO;
			
			[self updateAxisManipulatorWithAnimation:YES];
			
			[UIView animateWithDuration:0.5 animations:^{
				_panAtViewAroundFocusButton.layer.opacity = 0;
				_tumbleAroundFocusButton.layer.opacity = 0;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.layer.opacity = 0;
					_tumbleAroundFocusButton_LeftSide.layer.opacity = 0;
				}
			} completion:^(BOOL finished) {
				_panAtViewAroundFocusButton.hidden = YES;
				_tumbleAroundFocusButton.hidden = YES;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.hidden = YES;
					_tumbleAroundFocusButton_LeftSide.hidden = YES;
				}
			}];
		}
		return;
	}
	*/
	
	/*
	// channel gesture to texture image view for editing texture coordinates
	if ( _channelGestureUVInAction ) {
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			_proportionalEditCircleInAction = YES;
			[_proportionalEditCircle setHidden:YES];
		}
		
		_lastTouch = lastTouchAt;
		[_textureView longPressGestureDetected:sender];
		
		if ( _proportionalEditCircleAdjusting && theGround.meshModeEdit && !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			// after the END state, set to NO will make the proportional edit circle as if no present.
			// So, check if the manipulator is still in hanlder-in-action before setting it to NO.
			if (!_axisManipulator.handlerInAction) {
				_proportionalEditCircleInAction = NO;
			}
			[_proportionalEditCircle setHidden:NO];
		}
		
		if ( !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)  ) {
			_channelGestureUVInAction = NO;
			_textureView.axisManipulator = nil;
			
			// the Capture function needs theGround for drawing UV grid, so, we let texture view hold referrence to the ground.
			//_textureView.theGround = nil;
		}
		
		return;
	}
	
	// channel long press gesture to pencil manipulator
	//test
	_channelGesturePencilInAction = NO;
	if ( _channelGesturePencilInAction ) {
		
		// prepare camera info for grabbing
		if ( state == UIGestureRecognizerStateBegan ) {
			_pencilManipulator.lastCamera = [theGround getCameraInfo];
		}
		
		if ( ![self moveCameraForAdditionalTouchWhenDragging:sender touches:nil withEvent:nil] ) {
			[_pencilManipulator longPressDetected:sender];
		} else {
			// continue channeling could prevent jumping, however, the transform is not desired.
			[_pencilManipulator longPressDetected:sender];
		}
		_lastTouch = lastTouchAt;
		//_pencilManipulator.center = _lastTouch;
		
		if ( !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)  ) {
			
			// dismiss visual feedback (that the camera can be further changed in the middle of pan gesture).
			[UIView animateWithDuration:0.5 animations:^{
				_panAtViewAroundFocusButton.layer.opacity = 0;
				_tumbleAroundFocusButton.layer.opacity = 0;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.layer.opacity = 0;
					_tumbleAroundFocusButton_LeftSide.layer.opacity = 0;
				}
			} completion:^(BOOL finished) {
				_panAtViewAroundFocusButton.hidden = YES;
				_tumbleAroundFocusButton.hidden = YES;
				if (  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
					_panAtViewAroundFocusButton_LeftSide.hidden = YES;
					_tumbleAroundFocusButton_LeftSide.hidden = YES;
				}
			}];
		}
		
		return;
	}
	
	// channel gesture to change focal plane distance.
	if ( _channelGestureFocalPlaneInAction ) {
		_lastTouch = lastTouchAt;
		[self focalPlaneAdjustingPressed:sender];
		
		if ( !(state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			_channelGestureFocalPlaneInAction = NO;
		}
		return ;
	}
	
	// channel gesture to change selection box
	if ( _editingElementsBoxSelectionAddToSet_Moving) {
		if ( sender.numberOfTouches == 2 && (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) ) {
			CGPoint finger1 = [sender locationOfTouch:0 inView: sender.view];
			CGPoint finger2 = [sender locationOfTouch:1 inView: sender.view];
			CGFloat x = MIN(finger1.x, finger2.x);
			CGFloat y = MIN(finger1.y, finger2.y);
			CGFloat width = MAX(finger1.x, finger2.x) - x ;
			CGFloat height = MAX(finger1.y, finger2.y) - y ;
			CGRect newRect = CGRectMake( x, y, width, height);
			if ( CGPointEqualToPoint(finger1, newRect.origin) || CGPointEqualToPoint(finger2, newRect.origin) ) {
				_editingElementsBoxSelectionAddToSet.layer.borderColor = unselectionColor.CGColor;
				_editingElementsBoxSelectionAddToSet.text = @"-";
			} else {
				_editingElementsBoxSelectionAddToSet.layer.borderColor = selectionColor.CGColor;
				_editingElementsBoxSelectionAddToSet.text = @"+";
			}
			
			//newRect = CGRectInset(newRect, _THUMB_SIZE, _THUMB_SIZE);
			// the inset is made smaller than the actual touch down positions, such as to make the selection boundary clearly visible.
			UIEdgeInsets insets = UIEdgeInsetsMake(_THUMB_SIZE+_THUMB_SIZE, _THUMB_SIZE+9, _THUMB_SIZE, _THUMB_SIZE+_THUMB_SIZE-5);
			newRect = UIEdgeInsetsInsetRect(newRect, insets);
			if ( newRect.size.width < 0 ) {
				newRect.origin.x += newRect.size.width;
			}
			if ( newRect.size.height < 0 ) {
				newRect.origin.y += newRect.size.height;
			}
			newRect.size.width = fabs( newRect.size.width);
			newRect.size.height = fabs( newRect.size.height);
			[self updateConstraints:_editingElementsBoxSelectionAddToSet withKey:@"_editingElementsBoxSelectionAddToSet" toFrame:newRect];
			
		} else {
			if ( state == UIGestureRecognizerStateEnded ) {
				// perform confirm action
				CGRect selection = _editingElementsBoxSelectionAddToSet.frame;
				float scale = _nativeScale;
				selection.origin.x *= scale;
				selection.origin.y *= scale;
				selection.size.width *= scale;
				selection.size.height *= scale;
				if ( selection.size.width > 0 && selection.size.height > 0 ) {
					BOOL selectingFromTextureView = NO;
					if ( self.textureViewActive && _textureView.uvMappingVisible && CGRectContainsPoint(_textureView.frame, _editingElementsBoxSelectionAddToSet.center) ) {
						selectingFromTextureView = YES;
					}
					if ( [_editingElementsBoxSelectionAddToSet.text startsWith:@"+"] ) {
						if ( selectingFromTextureView ) {
							NSArray * selectedTexCoords = [_textureView selectTexCoordWithBox:[self.view convertRect:_editingElementsBoxSelectionAddToSet.frame toView:_textureView] addToExisting:NO];
							[theGround selectEditingElementsByID:selectedTexCoords addToExisting:!theGround.meshModePickSingle];
						} else {
							[theGround selectEditingElementsWithBox:selection addToExisting:!theGround.meshModePickSingle];
						}
					} else if ( [_editingElementsBoxSelectionAddToSet.text startsWith:@"-"] ) {
						if ( selectingFromTextureView ) {
							NSArray * selectedTexCoords = [_textureView selectTexCoordWithBox:[self.view convertRect:_editingElementsBoxSelectionAddToSet.frame toView:_textureView] addToExisting:NO];
							[theGround unselectEditingElementsByID: selectedTexCoords];
						} else {
							[theGround unselectEditingElementsWithBox:selection];
						}
					}
					
					// get the average vertex color and set it to the color picker.
					if (!_colorPicker.isHidden) {
						UIColor * color = [theGround getVertexColorFromSelected];
						if ( color != nil && ![color isEqual:_colorPicker.previousColor] ) {
							_colorPicker.previousColor = color;
						}
					}
					
					if (self.textureViewActive) {
						[self refreshTextureMappingFromMesh];
					}
					
				}
			}
			
			// minimize and restore the initial state of the selection box.
			_editingElementsBoxSelectionAddToSet_InSelection = NO;
			_editingElementsBoxSelectionAddToSet_Moving = NO;
			CGRect newRect = _editingElementsBoxSelectionAddToSet_savedFrame;
			[self updateConstraints:_editingElementsBoxSelectionAddToSet withKey:@"_editingElementsBoxSelectionAddToSet" toFrame:newRect];
			[UIView animateWithDuration:0.3 animations:^{
				//_editingElementsBoxSelectionAddToSet.frame = newRect;
				[self.view layoutIfNeeded];
				_editingElementsBoxSelectionAddToSet.layer.borderColor = grayColor.CGColor;
				_editingElementsBoxSelectionAddToSet.text = @"+";
			} completion:^(BOOL finished) {
				//_editingElementsBoxSelectionAddToSet.frame = newRect;
				//[self updateConstraints:_editingElementsBoxSelectionAddToSet withKey:@"_editingElementsBoxSelectionAddToSet" toFrame:newRect];
				
				//_editingElementsBoxSelectionAddToSet.layer.borderColor = grayColor.CGColor;
				//_editingElementsBoxSelectionAddToSet.text = @"+";
				if ( _transformEditor.isHidden ) {
					[_editingElementsBoxSelectionAddToSet setHidden: YES];
				}
			}];
			//[sender cancelsTouchesInView];
		}
		return;
	}
	*/
	
	//NSLog(@"longPressDetected: sender = %@, touches : %hd", sender, (short)sender.numberOfTouches);
	if ( sender.state == UIGestureRecognizerStateBegan ) {
		_cameraInAction = NO;
		_cameraTumbling = NO;
		_cameraPan = NO;
		_cameraMoveInView = NO;
		_cameraRotateAroundFocalPlaneVerically = NO;
		_cameraRotateAroundFocalPlaneHorizontally = NO;
		_cameraDragRotateResize = NO;
		_debugActionDisplayed = NO;
		_firstTouch = lastTouchAt;
		
		// long-press at the upper-left corner, but not over the texture image
		if ( sender.numberOfTouches == 1 && lastTouchAt.x < ONE_FIFTH_WIDTH && lastTouchAt.y < ONE_FIFTH_HEIGHT
			//&& !(self.textureViewActive && CGRectContainsPoint(_textureView.frame, lastTouchAt))
			) {
			// reset camera view to default when long press on the upper-left 1/5 region, with 1 touch.
#if defined(DEBUG)
			NSLog(@"reset camera to defaults");
#endif
			[self resetToDefaults];
			//[self updateFovButtonTitle];
			
			//[self dismissUrlTextField];
			//[_popover dismissPopoverAnimated:YES];
			//[self.searchResults removeAllObjects];
			//[self.searches removeAllObjects];
			//[self.collectionView reloadData];
	/*
		} else if ( sender.numberOfTouches == 1 && lastTouchAt.x > 4*ONE_FOURTH_WIDTH - 80.0 && lastTouchAt.y < ONE_FIFTH_HEIGHT ) {
			// long-press at the upper-right corner
			//self.showFocalPlaneVisualGuide ^= YES;
	*/
		} else {
			// long-press for other camera actions
			if ( sender.numberOfTouches == 1 ) {
				if (lastTouchAt.x > 4*ONE_FIFTH_WIDTH && (lastTouchAt.y > 2*ONE_FIFTH_HEIGHT && lastTouchAt.y < 3*ONE_FIFTH_HEIGHT) ) {
					_cameraRotateAroundFocalPlaneVerically = YES && self.cameraPerspective;
				} else if (lastTouchAt.y > 4*ONE_FIFTH_HEIGHT && (lastTouchAt.x > 2*ONE_FIFTH_WIDTH && lastTouchAt.x < 3*ONE_FIFTH_WIDTH) ) {
					_cameraRotateAroundFocalPlaneHorizontally = YES && self.cameraPerspective;
					if (_cameraRotateAroundFocalPlaneHorizontally) {
						if ( self.orbitStyleTurntable ) {
							// Note! Don't set the turntable property if not necessary because animation thread may kick on.
							self.orbitStyleTurntable = NO;
						} else if ( self.orbitStyleTurntableYup ) {
							self.orbitStyleTurntableYup = NO;
						}
					}
			/*
				} else if ( (lastTouchAt.y < ONE_FOURTH_HEIGHT || lastTouchAt.y > 3*ONE_FOURTH_HEIGHT) || (lastTouchAt.x < ONE_FOURTH_WIDTH || lastTouchAt.x > 3*ONE_FOURTH_WIDTH) ) {
					_cameraPan = YES;
					
					// visual hint to allow pan and select/de-select
					[self meshModePanAndSelectDeselectChanged:nil];
			*/
				} else if ( lastTouchAt.y < 4*ONE_FIFTH_HEIGHT ) {
					_cameraMoveInView = YES;
				}
				_cameraInAction = YES;
			} else if (sender.numberOfTouches == 2) {
				// if not channelling action , and not in editing mode
				// 2 touches long-press to rotate, resize and drag camera view at the same time
				if ( !_channelGestureInAction && sender.numberOfTouches == 2 ) {
						[self beginDragRotateResizeAtTheSameTime: sender];
				} else {
					_cameraMoveInView = YES;
					_cameraInAction = YES;
				}
			}
		}
	}
	
	CGPoint moved = CGPointMake(lastTouchAt.x - _firstTouch.x, lastTouchAt.y - _firstTouch.y);
	GLKVector2 direction = GLKVector2Make( moved.x, moved.y );
	float movedDistance = GLKVector2Length(direction);
	if ( _cameraInAction && (movedDistance) > _epsilon ) {
		GLKMatrix4 delta = GLKMatrix4Identity;
		float radians = 0.0f;
#if defined(DEBUG)
		if ( _cameraInAction && !_debugActionDisplayed) {
			//NSLog(@"longPressDetected: at (%0.1f, %0.1f) moved (%0.1f, %0.1f), state:%ld, touches:%lu, action:%@", _firstTouch.x, _firstTouch.y, moved.x, moved.y, (long)state, (unsigned long)sender.numberOfTouches, [self stringFromCameraAction]);
			_debugActionDisplayed = YES;
		}
#endif
		
		// tumbling
		if ( _cameraTumbling ) {
			GLKVector2 direction = GLKVector2Make(_lastTouch.x - _firstTouch.x, -(_lastTouch.y -_firstTouch.y) );
			float movedDistance = GLKVector2Length(direction);
			direction = GLKVector2Normalize(direction);
			radians = [self getCameraFoV]*1.2f*movedDistance/(ONE_FOURTH_WIDTH*4);
			GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radians, direction.y, -direction.x, 0.0 );
			
			
			delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -7.0f);
			delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
			delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, 7.0f);
			
		} else if ( _cameraPan ) {
			/*
			 float camerDistance = GLKVector3Length([self getCameraPosition]);
			 float panHorizontalDistance = [theGround getCameraFoV]*(moved.x/(ONE_FOURTH_WIDTH*4))*camerDistance;
			 float panVerticalDistance = -[theGround getCameraFoV]*(moved.y/(ONE_FOURTH_HEIGHT*4))*camerDistance;
			 GLKVector3 v = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( panHorizontalDistance, panVerticalDistance, 0.0f));
			 delta = GLKMatrix4TranslateWithVector3(delta, v);
			 */
			float camerDistance = MAX(self.focalPlaneDistance, self.nearPlane);
			float cameraFov = [self getCameraFoV];
			float viewSize = self.cameraPerspective? camerDistance * tanf(cameraFov/2.0) : self.nearPlane * tanf(cameraFov/2.0);
			float panHorizontalDistance = (moved.x/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
			float panVerticalDistance = -(moved.y/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
			GLKVector3 v = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( panHorizontalDistance, panVerticalDistance, 0.0f));
			delta = GLKMatrix4TranslateWithVector3(delta, v);
			
			// visual hint to allow pan and select/de-select
			//[self meshModePanAndSelectDeselectChanged:nil];
			
		} else if ( _cameraMoveInView ) {
			
			if ( self.cameraPerspective ) {
				// opengl y axis is up.
				GLKVector2 direction = GLKVector2Make( moved.x, -moved.y );
				float movedDistance = GLKVector2Length(direction);
				direction = GLKVector2Normalize(direction);
				// The rotation axis is a found by swapping x, y coordinate and negate the x value.
				GLKQuaternion quaternion = GLKQuaternionMakeWithAngleAndAxis( [self getCameraFoV]*movedDistance/(ONE_FOURTH_WIDTH*4), direction.y, -direction.x, 0.0 );
				delta = GLKMatrix4MakeWithQuaternion(quaternion);
			} else {
				float cameraFov = [self getCameraFoV];
				float viewSize = self.nearPlane * tanf(cameraFov/2.0);
				float panHorizontalDistance = (moved.x/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
				float panVerticalDistance = -(moved.y/(MIN(ONE_FOURTH_WIDTH, ONE_FOURTH_HEIGHT)*2.0))*viewSize;
				GLKVector3 v = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( panHorizontalDistance, panVerticalDistance, 0.0f));
				delta = GLKMatrix4TranslateWithVector3(delta, v);
			}
			
		} else if ( _cameraRotateAroundFocalPlaneVerically ) {
			
			//float cameraDistance = GLKVector3Distance([self getCameraPosition], theGround.focalPlane);
			//float cameraDistance = GLKVector3Distance([self getCameraPosition], theGround.adjustedFocalPlane);
			float cameraDistance = self.adjustedFocalPlaneDistance;
			//radians = M_PI *movedDistance/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*4.0);
			// use adaptive center to avoid large angle change.
			CGPoint adaptiveCenter = CGPointMake(_firstTouch.x - 80.0, 2*ONE_FOURTH_HEIGHT);
			radians = atan2f( lastTouchAt.y - adaptiveCenter.y, lastTouchAt.x - adaptiveCenter.x) - atan2f(_firstTouch.y - adaptiveCenter.y, _firstTouch.x - adaptiveCenter.x);
			if ( ! isnan(radians) ) {
				GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radians, 1.0, 0.0, 0.0 );
				
				// new implementation: use focal plane for tumbling.
				float viewTumblingDistance = cameraDistance;
				delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -viewTumblingDistance);
				delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
				delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, viewTumblingDistance);
			}
			
		} else if ( _cameraRotateAroundFocalPlaneHorizontally ) {
			
			//float cameraDistance = GLKVector3Distance([self getCameraPosition], theGround.focalPlane);
			//float cameraDistance = GLKVector3Distance([self getCameraPosition], theGround.adjustedFocalPlane);
			float cameraDistance = self.adjustedFocalPlaneDistance;
			//radians = M_PI *movedDistance/(MIN(ONE_FOURTH_WIDTH,ONE_FOURTH_HEIGHT)*4.0);
			// use adaptive center to avoid large angle change.
			CGPoint adaptiveCenter = CGPointMake(2*ONE_FOURTH_WIDTH, _firstTouch.y - 80.0 );
			radians = atan2f( lastTouchAt.y - adaptiveCenter.y, lastTouchAt.x - adaptiveCenter.x) - atan2f(_firstTouch.y - adaptiveCenter.y, _firstTouch.x - adaptiveCenter.x);
			if ( ! isnan(radians) ) {
				GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radians, 0.0, 1.0, 0.0 );
				
				// new implementation: use focal plane for tumbling.
				float viewTumblingDistance = cameraDistance;
				delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -viewTumblingDistance);
				delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
				delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, viewTumblingDistance);
			}
			
		} else if ( _cameraDragRotateResize && sender.numberOfTouches == 2 ) {
			delta = [self computeDragRotateResizeDelta: sender];
			// this call impacts performance
			//[self updateFovButtonTitle];
			
			_lastDeltaApplied = delta;
		}
		
		if ( state == UIGestureRecognizerStateEnded ) {
			if ( ! isnan( delta.m00 ) ) {
				[self applyCameraDeltaCompleted:delta ];
			}
			
			if ( _cameraMoveInView || _cameraTumbling || _cameraDragRotateResize ) {
				// spring back the locked viewing direction before tumbling.
				if ( self.lockingTumbling ) {
					[self springCameraBackToLockingDirection];
				}
			}
			
		} else {
			[self stopContinuousTumbling];
			if ( ! isnan( delta.m00 ) ) {
				[self applyCameraDelta:delta];
			}
		}
		_lastTouch = lastTouchAt;
	}
	
	if ( [self.delegate respondsToSelector:@selector(gestureDetectedPostprocessing:)] ) {
		[self.delegate gestureDetectedPostprocessing:sender];
	}

	if ( state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled ) {
		_cameraInAction = NO;
		_cameraTumbling = NO;
		_cameraPan = NO;
		_cameraMoveInView = NO;
		_cameraRotateAroundFocalPlaneVerically = NO;
		_cameraRotateAroundFocalPlaneHorizontally = NO;
		_cameraDragRotateResize = NO;
		//_singleLineEditingInAction = NO;
		
		// visual hint to allow pan and select/de-select
		//[self meshModePanAndSelectDeselectChanged:nil];
		
		//[self updateFovButtonTitle];
	}
}


// ----------------------------------------------------------------------------------------
// using layer assisted animation.
- (void)animateCameraTo:(GLKVector3)newPosition lookingAt:(GLKVector3)lookingAt upDir:(GLKVector3)upDir completion:(void (^)(void))completion
{
	CameraInfo * currentCamera = self.getCameraInfo;

	GLKMatrix4 invertedCamera = currentCamera.invertedViewMatrix;
	GLKVector3 cameraPositionInWC = currentCamera.position;
	GLKVector3 cameraViewDirection = currentCamera.viewDirection;
	GLKVector3 currentFocus = currentCamera.focusPoint;
	GLKVector3 currentUpVector = currentCamera.upDirection;
	
	CGFloat radian = fabs( acos( GLKVector3DotProduct(GLKVector3Normalize( upDir ), GLKVector3Normalize(currentUpVector) ) ) );
	
	GLKVector3 axis = GLKVector3Normalize( GLKVector3CrossProduct(currentUpVector, upDir) );
	if ( radian == 0.0 || GLKVector3Length(axis) < _epsilon || isnan(radian) || isnan(axis.x)|| isnan(axis.y)|| isnan(axis.z)) {
		radian = 0;
		axis = GLKVector3Normalize(cameraViewDirection);
	}
	
	__block float focalLength = self.adjustedFocalPlaneDistance;
	
	if ( true ) {
		// animation:
		// cameraPositionInWC ->> newPosition		Position LERP
		// currentFocus ->> lookingAt				Position LERP
		// currentUpVector ->> upDir				Quaternion SLERP
		
		__block GLKVector3 lastViewDir = currentCamera.viewDirection;
		__block GLKVector3 lastUpDir = currentCamera.upDirection;
		
		CGFloat duration = 0.3;
		[self animateViaArrowLayer:duration values:@[[NSValue valueWithCGPoint:(CGPointMake(0.0, 0.0))],
													 [NSValue valueWithCGPoint:(CGPointMake(0.5, 0.5*radian))],
													 [NSValue valueWithCGPoint:(CGPointMake(1.0, radian))] ]
						animations:^(NSValue * interValue)
		 {
			 CGPoint interpolated;
			 [interValue getValue:&interpolated];
			 //NSLog(@"inter: %@", interValue);
			 GLKVector3 eye = GLKVector3Lerp(cameraPositionInWC, newPosition, interpolated.x);
			 GLKVector3 center = GLKVector3Lerp(currentFocus, lookingAt, interpolated.x);
			 
			 // make eye equi-distance to center as of current focal plance distance
			 eye = GLKVector3Add( center, GLKVector3MultiplyScalar(GLKVector3Normalize( GLKVector3Subtract(eye, center) ), focalLength) );
			 
			 GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( interpolated.y, axis.x, axis.y, axis.z );
			 GLKMatrix4 rotation = GLKMatrix4MakeWithQuaternion(quat);
			 GLKVector3 up = GLKVector3Normalize( GLKMatrix4MultiplyVector3(rotation, currentUpVector) );
			 
			 // if no upDir preference, maintain natrual up of the begining frame
			 if ( GLKVector3AllEqualToScalar(upDir, 0.0) ) {
				 GLKVector3 deltaViewDir = GLKVector3Make(center.x-eye.x, center.y-eye.y, center.z-eye.z);
				 GLKQuaternion quatRotatingDeltaView = [ViewController quaternionFromVector:lastViewDir toVector:deltaViewDir];
				 GLKMatrix4 matForRotation = GLKMatrix4MakeWithQuaternion( quatRotatingDeltaView);
				 up = GLKVector3Normalize( GLKMatrix4MultiplyVector3(matForRotation, lastUpDir));
				 lastViewDir = deltaViewDir;
				 lastUpDir = up;
			 }
			 
			 GLKMatrix4 delta = GLKMatrix4MakeLookAt( eye.x, eye.y, eye.z, center.x, center.y, center.z, up.x, up.y, up.z);
			 
			 if ( isnan(delta.m00) ) {
				 NSLog(@"Nan");
			 }
			 
			 [self applyCameraDelta: GLKMatrix4Multiply(delta, invertedCamera) ];
		 } completion:^(NSValue * finalValue) {
			 CGPoint interpolated;
			 [finalValue getValue:&interpolated];
			 //NSLog(@"completed: %@, %@", NSStringFromCGPoint(interpolated), finalValue);
			 
			 GLKVector3 eye = GLKVector3Lerp(cameraPositionInWC, newPosition, interpolated.x);
			 GLKVector3 center = GLKVector3Lerp(currentFocus, lookingAt, interpolated.x);
			 
			 GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( interpolated.y, axis.x, axis.y, axis.z );
			 GLKMatrix4 rotation = GLKMatrix4MakeWithQuaternion(quat);
			 
			 GLKVector3 up = GLKVector3Normalize( GLKMatrix4MultiplyVector3(rotation, currentUpVector) );
			 GLKMatrix4 delta = GLKMatrix4MakeLookAt( eye.x, eye.y, eye.z, center.x, center.y, center.z, up.x, up.y, up.z);
			 [self applyCameraDelta: GLKMatrix4Multiply(delta, invertedCamera) ];
			 
			 eye = newPosition;
			 center = lookingAt;
			 up = upDir;
			 
			 // if no upDir preference, maintain natrual up of the begining frame
			 if ( GLKVector3AllEqualToScalar(upDir, 0.0) ) {
				 GLKVector3 deltaViewDir = GLKVector3Make(center.x-eye.x, center.y-eye.y, center.z-eye.z);
				 GLKQuaternion quatRotatingDeltaView = [ViewController quaternionFromVector:lastViewDir toVector:deltaViewDir];
				 GLKMatrix4 matForRotation = GLKMatrix4MakeWithQuaternion( quatRotatingDeltaView);
				 up = GLKVector3Normalize( GLKMatrix4MultiplyVector3(matForRotation, lastUpDir));
				 lastViewDir = deltaViewDir;
				 lastUpDir = up;
			 }
			 
			 delta = GLKMatrix4MakeLookAt( eye.x, eye.y, eye.z, center.x, center.y, center.z, up.x, up.y, up.z);
			 [self applyCameraDeltaCompleted: GLKMatrix4Multiply(delta, invertedCamera) ];
			 
			 // further check if out of view far plane.
			 float distanceToFocal = GLKVector3Distance(lookingAt, newPosition);
			 if ( distanceToFocal > self.farPlane ) {
				 float deltaDist = ( distanceToFocal - self.farPlane/4.0 ) ;
				 [self moveCameraForwardDeltaCompleted:deltaDist];
			 }
			 
			 // process completion block
			 if ( completion ) {
				 completion();
			 }
		 }];
	}
}

// one call to invoke general, assisted by arrowLayer, animations
- (void)animateViaArrowLayer:(CFTimeInterval)duration values:(NSArray*)values animations:(void (^)(NSValue*))animations completion:(void (^)(NSValue*))completion
{
	// setting value to key path: "animationValue" in the arrow layer,
	// the layer's setAnimationValue method will then trigger the block(set by setAnimationBlock) with the animated values.
	CAKeyframeAnimation * anim = [CAKeyframeAnimation animationWithKeyPath:@"animationValue"];
	anim.values = values;
	anim.calculationMode = kCAAnimationCubic;
	
	CAAnimationGroup * group = [CAAnimationGroup animation];
	group.animations = [NSArray arrayWithObjects:anim, nil];
	group.duration = duration;
	
	[CArrowShape.shared setAnimationBlock:animations];
	
	[CATransaction begin]; {
		[CATransaction setCompletionBlock:^{
			arrowLayer.animationValue = [values lastObject];
			//NSLog(@"animation completed. value:%@", arrowLayer.animationValue);
			if (completion != nil) {
				completion( [values lastObject] );
			}
		}];
		[arrowLayer addAnimation:group forKey:@"Custom Animation via CArrowLayer"];
	} [CATransaction commit];
}

- (void)animateCameraCenterTo:(GLKVector3)center completion:(void (^)(void))completion
{
	// This works, with each step more close to the center.
	//[self deltaCameraCenterTo:center withCompleted:YES];
	
	// Another approach of using layer assisted animation.
	GLKMatrix4 cameraMatrix = [self getCameraMatrix:NO];
	
	CameraInfo * camera = [self getCameraInfo];
	
	//GLKMatrix4 invertedCamera = camera.invertedViewMatrix;
	GLKVector3 cameraPositionInWC = camera.position;
	GLKVector3 cameraViewDirection = camera.viewDirection;
	
	GLKVector3 vectorToCenter = GLKVector3Subtract(center, cameraPositionInWC);
	GLKVector3 unitVectorToCenter = GLKVector3Normalize( vectorToCenter );
	double cosToView = fabs( GLKVector3DotProduct( unitVectorToCenter, cameraViewDirection ) );
	double cosToUp = fabs( GLKVector3DotProduct( unitVectorToCenter, camera.upDirection ) );
	GLKQuaternion rotationQuaternion = GLKQuaternionIdentity;
	if ( cosToUp < cosToView ) {
		// target vector is more close to View vector than Up vector.
		GLKQuaternion rotateToUp = [ViewController quaternionFromVector: camera.upDirection toVector: unitVectorToCenter];
		GLKQuaternion rotateToView = [ViewController quaternionFromVector: camera.viewDirection toVector: camera.upDirection ];
		rotationQuaternion = GLKQuaternionMultiply( rotateToUp, rotateToView );
	} else {
		rotationQuaternion = [ViewController quaternionFromVector: camera.viewDirection  toVector: unitVectorToCenter ];
	}
	GLKVector3 axis = GLKQuaternionAxis( rotationQuaternion );
	
	if (self.cameraPerspective || GLKVector3Length(axis) == 0.0) {
		//CGFloat radian = -acosf( GLKVector3DotProduct( unitVectorToCenter, cameraViewDirection) );
		CGFloat radian = -GLKQuaternionAngle( rotationQuaternion );
		
		// convert axis from world coord to camera coord, for calling applyCameraDelta
		axis = GLKMatrix4MultiplyVector3(cameraMatrix, axis);
		//NSLog(@"angle: %0.2f, around: %@", GLKMathRadiansToDegrees(radian), NSStringFromGLKVector3(axis));
		
		if ( GLKVector3Length(axis) < _epsilon || isnan(radian) || isnan(axis.x)|| isnan(axis.y)|| isnan(axis.z)) {
			radian = 0.0;
			axis = GLKVector3Normalize(cameraViewDirection);
		}
		axis = GLKVector3Normalize(axis);
		
		//NSLog(@"target degree %0.2f", GLKMathRadiansToDegrees(radian));
		
		[self animateViaArrowLayer:3 values:@[[NSValue valueWithCGPoint:(CGPointMake(0.0, 0.0))],
												[NSValue valueWithCGPoint:(CGPointMake(0.5, 0.5*radian))],
												[NSValue valueWithCGPoint:(CGPointMake(1.0, radian))] ]
						animations:^(NSValue * interValue) {
							CGPoint interpolated;
							[interValue getValue:&interpolated];
							NSLog(@"inter: %0.2f, %@, %@", GLKMathRadiansToDegrees(interpolated.y), interValue, NSStringFromGLKVector3(axis));
							GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( interpolated.y, axis.x, axis.y, axis.z );
							GLKMatrix4 delta = GLKMatrix4MakeWithQuaternion(quat);
							[self applyCameraDelta:delta];
						} completion:^(NSValue * finalValue) {
							CGPoint interpolated;
							[finalValue getValue:&interpolated];
							NSLog(@"completed: target %0.2f, final %0.2f", GLKMathRadiansToDegrees(radian), GLKMathRadiansToDegrees(interpolated.y) );
							GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( radian, axis.x, axis.y, axis.z );
							GLKMatrix4 delta = GLKMatrix4MakeWithQuaternion(quat);
							[self applyCameraDeltaCompleted:delta];
							
							// further check if out of view far plane.
							float distanceToFocal = GLKVector3DotProduct(vectorToCenter, cameraViewDirection);
							CameraInfo * camera = [self getCameraInfo];
							float eyeDist = GLKVector3Distance(center, camera.position);
							if ( distanceToFocal > self.farPlane || eyeDist > self.farPlane ) {
								float deltaDist = ( eyeDist - self.farPlane/4.0 ) ;
								[self moveCameraForwardDeltaCompleted:deltaDist];
							} else if ( distanceToFocal > 0 && distanceToFocal < self.nearPlane ) {
								float deltaDist = -( self.nearPlane + eyeDist ) ;
								[self moveCameraForwardDeltaCompleted:deltaDist];
							}
							
							// process completion block
							if ( completion ) {
								completion();
							}
						}];
	} else {
		// To obtain the projected part, u, of a vector, v, on a plane with normal, n:
		// u=n×(v×n)=v(n⋅n)−n(v⋅n)=v−n(v⋅n)
		GLKVector3 u = GLKVector3CrossProduct(cameraViewDirection, GLKVector3CrossProduct(vectorToCenter, cameraViewDirection));
		
		//convert axis from world coord to camera coord, for calling applyCameraDelta
		u = GLKMatrix4MultiplyVector3(cameraMatrix, u);
		
		float distance = GLKVector3DotProduct(vectorToCenter, cameraViewDirection);
		if ( distance < 0 ) {
			u.z = -2.0 * distance;
		}
		u = GLKVector3Negate(u);
		
		[self animateViaArrowLayer:0.3 values:@[[NSValue valueWithCGRect:(CGRectMake(0, 0, 0, 0))] ,
												[NSValue valueWithCGRect:(CGRectMake(u.x/2.0, u.y/2.0, u.z/2.0, 0))],
												[NSValue valueWithCGRect:(CGRectMake(u.x, u.y, u.z, 0))]
												] animations:^(NSValue * interValue)
		 {
			 CGRect interpolated;
			 [interValue getValue:&interpolated];
			 //NSLog(@"inter: %@, %@", NSStringFromCGRect(interpolated), interValue );
			 GLKVector3 displace = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( interpolated.origin.x, interpolated.origin.y, interpolated.size.width));
			 GLKMatrix4 delta = GLKMatrix4TranslateWithVector3(GLKMatrix4Identity, displace);
			 [self applyCameraDelta:delta];
		 } completion:^(NSValue * finalValue) {
			 //NSLog(@"completed: %@", finalValue );
			 GLKVector3 displace = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( u.x, u.y, u.z));
			 GLKMatrix4 delta = GLKMatrix4TranslateWithVector3(GLKMatrix4Identity, displace);
			 [self applyCameraDeltaCompleted:delta];
			 
			 // process completion block
			 if ( completion ) {
				 completion();
			 }
		 }];
		
	}
}

- (void)centerOnLocation:(GLKVector3)locationInWC
{
	[self stopContinuousTumbling];
		
	// center the selection, if had selected something.
	[self animateCameraCenterTo: locationInWC completion:^{
		/*
		// adjust the center a little bit to the right side (aka shift camera left) because of the texture view occupying left screen.
		if ( self.shouldEvadeCenterFromTextureView) {
			GLKVector3 centroidInViewPort = [theGround projectForPoint: locationInWC];
			
			// this delta right is pixel amount to be shifted towards right.
			float deltaRight = (ONE_FOURTH_WIDTH*4 - _textureView.bounds.size.width - _rightSideMenuPane.bounds.size.width) * 0.5;
			deltaRight += _textureView.frame.size.width;
			deltaRight = deltaRight - ONE_FOURTH_WIDTH*2;
			deltaRight = deltaRight * _nativeScale;
			
			GLKVector3 movedToInViewPort = GLKVector3Make(centroidInViewPort.x - deltaRight, centroidInViewPort.y, centroidInViewPort.z);
			GLKVector3 movedToInWC = [theGround pointFromTouch: movedToInViewPort ];
			
			dispatch_async( dispatch_get_main_queue(), ^{
				[self animateCameraCenterTo: movedToInWC completion:^{
					if ( theGround.orbitStyleTurntable ) {
						// re-adjust z-up after animating center
						theGround.orbitStyleTurntable = YES;
					} else if ( theGround.orbitStyleTurntableYup ) {
						theGround.orbitStyleTurntableYup = YES;
					}
				}];
			});
		} else */
		{
			if ( self.orbitStyleTurntable ) {
				// re-adjust z-up after animating center
				self.orbitStyleTurntable = YES;
			} else if ( self.orbitStyleTurntableYup) {
				self.orbitStyleTurntableYup = YES;
			}
		}
		
		[self resetFocusToLocation: locationInWC];
		
		// spring back the locked viewing direction before tumbling.
		if ( self.lockingTumbling ) {
			[self springCameraBackToLockingDirection];
		}
	}];
	
}

// change focus distance of the camera to the specified location in world space
- (void)resetFocusToLocation:(GLKVector3)locationInWC
{
	_focalPlane = locationInWC;
	_focalPlaneDistance = GLKVector3Distance([self getCameraPosition], _focalPlane);
	if ( isnan(_focalPlaneDistance) ) {
		NSLog(@"_focalPlaneDistance to locationInWC should not be NaN");
	}
	_adjustedFocalPlaneFactor = 0.0;
}

- (void)springCameraBackToLockingDirection
{
	[self stopContinuousTumbling];
	
	CameraInfo * currentCamera = [self getCameraInfo];
	GLKVector3 targetPosition = GLKVector3Add( currentCamera.focusPoint, GLKVector3MultiplyScalar(self.lockingViewDir, -currentCamera.focusDistance));
	// zero up indicates no preference
	GLKVector3 up = GLKVector3Make(0.0,0.0,0.0);  // currentCamera.upDirection;
	
	[self animateCameraTo: targetPosition lookingAt: currentCamera.focusPoint upDir: up completion:^{
		
	}];
	
}

/*
 // utility for camera tumbling, core logic for Y or Z axis-up constraints.
 // parameters : radians, rotation angle around the Camera Right direction.
 //			  : radians2, rotation angle around the Camera Up Direction.
	Implementation details: First of all, compute the angle between target axis (Z-axis or Y-axis) and the camera's upward, view, eye and downward directions.  Depends on which direction the target axis aligns to, and the direction of the given radians (positive value indicates panning down, while negative indicates panning up), then, rotate the target axis to first align with the above 4 camera directions, which will bring the target axis to align in vertical direction.  And then rotate it vertically and limit to either the camera view or eye direction.  If the target axis starts at a position with degree not more then 45 degrees overshooting the limit, then it cannot rotate further away from the limiting direction, it can only allowed to bring backwards.
 
 */
- (GLKMatrix4)computeDeltaTumbling:(CGFloat)radians horizontalRadians:(CGFloat)radians2 withCamera:(CameraInfo*)lastCamera
{
	return [self computeDeltaTumbling: radians horizontalRadians: radians2 withCamera: lastCamera andTumblingDistance: lastCamera.focusDistance];
}
- (GLKMatrix4)computeDeltaTumbling:(CGFloat)radians horizontalRadians:(CGFloat)radians2 withCamera:(CameraInfo*)lastCamera andTumblingDistance:(CGFloat)tumblingDistance
{
	// working approach 2: rotate at z-axis, center at focuspoint, using horizontal movement
	// and also rotate at camera right axis, center at focuspoint, using vertical movement, and constrainted z-axis to be within view direction and up direction.
	// limit vertical radians
	
	//CameraInfo * lastCamera = _lastCameraInfoAtGestureBegan;
	
	GLKVector3 targetAxis = GLKVector3Make(0, 0, 1);	// align Z-axis up
	if ( self.orbitStyleTurntableYup ) {
		targetAxis = GLKVector3Make(0, 1, 0);			// align Y-axis up
	}
	
	float dotCameraUpToTargetAxis = GLKVector3DotProduct( lastCamera.upDirection, targetAxis );
	float dotCameraViewToTargetAxis = GLKVector3DotProduct( lastCamera.viewDirection, targetAxis );
	float radianAxisTowardsUp = acosf( dotCameraUpToTargetAxis );
	float radianAxisTowardsEye = acosf( GLKVector3DotProduct( GLKVector3Negate(lastCamera.viewDirection), targetAxis ) );
	float radianAxisTowardsView = acosf( GLKVector3DotProduct( (lastCamera.viewDirection), targetAxis ) );
	float radianAxisTowardsDown = acosf( GLKVector3DotProduct( GLKVector3Negate(lastCamera.upDirection), targetAxis ) );
	GLKVector3 axisPerpendicularToUpAndAxisDirection = GLKVector3Make(1.0, 0.0, 0.0);

	BOOL targetAxisUpwards = dotCameraUpToTargetAxis >= 0;
	BOOL taregtAxisOutwards = dotCameraViewToTargetAxis >= 0;

	BOOL targetAxisAlreadyInLockingRegion = (dotCameraUpToTargetAxis >= 0 && dotCameraViewToTargetAxis < 0);
	BOOL targetAxisMoreUpAndOutwards = dotCameraUpToTargetAxis > cosf(M_PI_4) && taregtAxisOutwards;
	BOOL targetAxisNotTooDownAndInwards = !taregtAxisOutwards && !targetAxisUpwards && dotCameraViewToTargetAxis < cosf(M_PI-M_PI_4);
	BOOL targetAxisNotTooDownAndOutwards = taregtAxisOutwards && !targetAxisUpwards && dotCameraViewToTargetAxis > cosf(M_PI_4);
	BOOL targetAxisUpAndOutwards = targetAxisUpwards && taregtAxisOutwards;
			
	GLKVector3 axis_forTowardsVertical = GLKVector3Make(1, 0, 0);
	float radians_forTowardsVertical = 0.0;
	
	if ( radians < 0 ) {
		// finger panning down, then radian should be constrainted in a way such as to move it towards the view-to-eye quadrant.
		float downwardLimit;
	
		//compute the right rotating axis such that when rotating it will help to re-align the target up axis to vertical plane.
		GLKVector3 upDownRotatingAxis = GLKVector3CrossProduct(lastCamera.viewDirection, targetAxis);

		if ( targetAxisAlreadyInLockingRegion ) {
			// up vector is generally upwards, and towards the viewer.  So, moving downwards will limit towards viewer direction.
			downwardLimit = -(radianAxisTowardsEye);
		} else if ( targetAxisMoreUpAndOutwards ) {
			// up vector is generally upwards, and away from viewer.  So, moving downwards will passing up and limit towards viewer direction.
			downwardLimit = -(radianAxisTowardsEye);
			{
				// another approach,
				// when target axis is upwards and slightly outwords, finger moves downwards will bring it towards the up vertical direction first, then, and then towards the eye.
				if ( fabs(radians) < (radianAxisTowardsUp) ) {
					// moving angle less than axis-up angle. So, prefer to move towards up direction first
					radians_forTowardsVertical = radians;
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.upDirection);
					radians = 0;
				} else {
					radians_forTowardsVertical = -(radianAxisTowardsUp);
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.upDirection);
					radians = radians - (radians_forTowardsVertical);
					downwardLimit = -(M_PI_2);
					upDownRotatingAxis = GLKMatrix4MultiplyVector3(lastCamera.invertedViewMatrix, GLKVector3Make(1, 0, 0));
				}
			}
		} else if ( targetAxisNotTooDownAndOutwards || (taregtAxisOutwards && !targetAxisUpwards) ) {
			downwardLimit = -(radianAxisTowardsEye);
			{
				// another approach,
				// when target axis is outwards, finger moves downwards will bring the axis outwards, and upwards, and finally inwards to eye.
				// so, the first rotation could be towards to the up direction first and then towards the eye.
				if ( fabs(radians) < (radianAxisTowardsView) ) {
					// moving angle less than axis-to-up angle. So, prefer to move towards up direction first
					radians_forTowardsVertical = radians;
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.viewDirection);
					radians = 0;
				} else {
					radians_forTowardsVertical = -(radianAxisTowardsView);
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.viewDirection);
					radians = radians - (radians_forTowardsVertical);
					downwardLimit = -(M_PI_2 + M_PI_2);
					upDownRotatingAxis = GLKMatrix4MultiplyVector3(lastCamera.invertedViewMatrix, GLKVector3Make(1, 0, 0));
				}
			}
		} else if ( targetAxisNotTooDownAndInwards ) {
			// locked, cannot move further downwards.
			downwardLimit = 0;
			radians = 0;
		} else if ( targetAxisUpAndOutwards) {
			// up vector is generally away from viewer.  So, panning down will bring up from backwards,
			// towards up direction, and then inwards and limited to eye direction.
			downwardLimit = -(radianAxisTowardsEye);
			{
				// another approach,
				// when target axis is outwards, finger moves downwards will bring the axis outwards, and upwards, and finally inwards to eye.
				// so, the first rotation could be towards to the up direction first and then towards the eye.
				if ( fabs(radians) < (radianAxisTowardsUp) ) {
					// moving angle less than axis-to-up angle. So, prefer to move towards up direction first
					radians_forTowardsVertical = radians;
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.upDirection);
					radians = 0;
				} else {
					radians_forTowardsVertical = -(radianAxisTowardsUp);
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.upDirection);
					radians = radians - (radians_forTowardsVertical);
					downwardLimit = -(M_PI_2);
					upDownRotatingAxis = GLKMatrix4MultiplyVector3(lastCamera.invertedViewMatrix, GLKVector3Make(1, 0, 0));
				}
			}
		} else if ( !targetAxisUpwards && !taregtAxisOutwards) {
			// target axis is generally down and towards from viewer.  So, panning down will bring up from backwards,
			// towards down direction, and the outwards and then upwards, and then inwards and limited to eye direction.
			downwardLimit = -(radianAxisTowardsEye);
			{
				// another approach,
				// when target axis is outwards, finger moves downwards will bring the axis outwards, and upwards, and finally inwards to eye.
				// so, the first rotation could be towards to the up direction first and then towards the eye.
				if ( fabs(radians) < (radianAxisTowardsDown) ) {
					// moving angle less than axis-to-up angle. So, prefer to move towards up direction first
					radians_forTowardsVertical = radians;
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, GLKVector3Negate( lastCamera.upDirection) );
					radians = 0;
				} else {
					radians_forTowardsVertical = -(radianAxisTowardsDown);
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, GLKVector3Negate( lastCamera.upDirection) );
					radians = radians - (radians_forTowardsVertical);
					downwardLimit = -(M_PI + M_PI_2);
					upDownRotatingAxis = GLKMatrix4MultiplyVector3(lastCamera.invertedViewMatrix, GLKVector3Make(1, 0, 0));
				}
			}
		} else {
			// locked
			downwardLimit = 0;
			radians = 0;
		}
		if ( radians < downwardLimit ) radians = downwardLimit;
		
		// convert rotating axis from world space to camera space
		if ( GLKVector3Length(upDownRotatingAxis) > _epsilon ) {
			axisPerpendicularToUpAndAxisDirection = GLKVector3Normalize( upDownRotatingAxis );
			axisPerpendicularToUpAndAxisDirection = GLKMatrix4MultiplyVector3(lastCamera.viewMatrix, axisPerpendicularToUpAndAxisDirection);
		}

		// convert rotating axis from world space to camera space
		if ( GLKVector3Length(axis_forTowardsVertical) > _epsilon ) {
			axis_forTowardsVertical = GLKVector3Normalize( axis_forTowardsVertical );
			axis_forTowardsVertical = GLKMatrix4MultiplyVector3(lastCamera.viewMatrix, axis_forTowardsVertical);
		}
	} else {
		// finger moving upwards, then radian should limit to be less or equal to right-angle complement of
		float upwardLimit;
		
		//compute the right rotating axis such that when rotating it will help to re-align the target axis to vertical plane.
		GLKVector3 upDownRotatingAxis = GLKVector3CrossProduct(lastCamera.upDirection, targetAxis);

		if ( targetAxisAlreadyInLockingRegion ) {
			upwardLimit = M_PI_2 + radianAxisTowardsUp; //radianAxisTowardsUp;
			{
				// another approach,
				// when target axis is up and inwards, finger moves upwords will bring it towards the vertical up direction first,  and then limit to the view direction.
				if ( fabs(radians) < (radianAxisTowardsUp) ) {
					// moving angle less than axis-up angle. So, prefer to move towards up direction first
					radians_forTowardsVertical = radians;
					axis_forTowardsVertical = GLKVector3CrossProduct(lastCamera.upDirection, targetAxis);
					radians = 0;
				} else {
					radians_forTowardsVertical = (radianAxisTowardsUp);
					axis_forTowardsVertical = GLKVector3CrossProduct(lastCamera.upDirection, targetAxis);
					radians = radians - (radians_forTowardsVertical);
					upwardLimit = M_PI_2 ;
					upDownRotatingAxis = GLKMatrix4MultiplyVector3(lastCamera.invertedViewMatrix, GLKVector3Make(1, 0, 0));
				}
			}
		} else if ( targetAxisMoreUpAndOutwards ) {
			//upwardLimit = 0;
			//radians = 0;
			upDownRotatingAxis = GLKVector3CrossProduct(lastCamera.viewDirection, targetAxis);
			upwardLimit = radianAxisTowardsView;
		} else if ( targetAxisUpAndOutwards ) {
			upDownRotatingAxis = GLKVector3CrossProduct(lastCamera.viewDirection, targetAxis);
			upwardLimit = radianAxisTowardsView;
		} else if ( targetAxisNotTooDownAndOutwards ) {
			upwardLimit = 0;
			radians = 0;
		} else if ( targetAxisNotTooDownAndInwards || (!targetAxisUpwards && !taregtAxisOutwards) ) {
			// up vector is generally downwards, and towards the viewer.  So, panning up will continue towards viewer and upwards, and then limit to view direction.
			upwardLimit = M_PI_2 + radianAxisTowardsUp;
			{
				// another approach,
				// up vector is generally downwards, and towards the viewer.  So, panning up will continue towards viewer and upwards, and then limit to view direction.
				if ( fabs(radians) < (radianAxisTowardsEye) ) {
					// moving angle less than axis-up angle. So, prefer to move towards up direction first
					radians_forTowardsVertical = radians;
					axis_forTowardsVertical = GLKVector3CrossProduct(GLKVector3Negate(lastCamera.viewDirection), targetAxis );
					radians = 0;
				} else {
					radians_forTowardsVertical = (radianAxisTowardsEye);
					axis_forTowardsVertical = GLKVector3CrossProduct(GLKVector3Negate(lastCamera.viewDirection), targetAxis );
					radians = radians - (radians_forTowardsVertical);
					upwardLimit = (M_PI) ;
					upDownRotatingAxis = GLKMatrix4MultiplyVector3(lastCamera.invertedViewMatrix, GLKVector3Make(1, 0, 0));
				}
			}

		} else if ( dotCameraViewToTargetAxis >= 0 ) {
			// up vector is generally outwards, and away from viewer.  So, moving downwards will bring it inwards to viewer and then continues upward and limit to updirection
			upDownRotatingAxis = GLKVector3CrossProduct(targetAxis, lastCamera.upDirection);
			upwardLimit = M_PI_2 + radianAxisTowardsUp; //M_PI + M_PI - radianAxisTowardsUp;
			{
				// another approach,
				// when target axis is outwords, finger moves upwords will bring it towards the vertical down direction first, then, and then towards the eye, and limit the up direction.
				if ( fabs(radians) < (M_PI-radianAxisTowardsUp) ) {
					// moving angle less than axis-up angle. So, prefer to move towards up direction first
					radians_forTowardsVertical = radians;
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.upDirection);
					radians = 0;
				} else {
					radians_forTowardsVertical = (M_PI-radianAxisTowardsUp);
					axis_forTowardsVertical = GLKVector3CrossProduct(targetAxis, lastCamera.upDirection);
					radians = radians - (radians_forTowardsVertical);
					upwardLimit = (M_PI) + M_PI_2 ;
					upDownRotatingAxis = GLKMatrix4MultiplyVector3(lastCamera.invertedViewMatrix, GLKVector3Make(1, 0, 0));
				}
			}

		} else {
			// locked
			upwardLimit = 0;
			radians = 0;
		}
		if ( radians > upwardLimit ) radians = upwardLimit;

		if ( GLKVector3Length(upDownRotatingAxis) > _epsilon ) {
			axisPerpendicularToUpAndAxisDirection = GLKVector3Normalize( upDownRotatingAxis );
			axisPerpendicularToUpAndAxisDirection = GLKMatrix4MultiplyVector3(lastCamera.viewMatrix, axisPerpendicularToUpAndAxisDirection);
		}

		// convert rotating axis from world space to camera space
		if ( GLKVector3Length(axis_forTowardsVertical) > _epsilon ) {
			axis_forTowardsVertical = GLKVector3Normalize( axis_forTowardsVertical );
			axis_forTowardsVertical = GLKMatrix4MultiplyVector3(lastCamera.viewMatrix, axis_forTowardsVertical);
		}
	}
	
	GLKMatrix4 delta = GLKMatrix4Identity;
	GLKMatrix4 delta2 = GLKMatrix4Identity;
	
	GLKQuaternion quat = GLKQuaternionMakeWithAngleAndVector3Axis(-radians, axisPerpendicularToUpAndAxisDirection);
	GLKQuaternion quat_forTowardsVertical = GLKQuaternionMakeWithAngleAndVector3Axis(-radians_forTowardsVertical, axis_forTowardsVertical);
	
	float viewTumblingDistance = tumblingDistance;
	delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, -viewTumblingDistance);
	delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat));
	delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat_forTowardsVertical) );
	delta = GLKMatrix4Translate(delta, 0.0f, 0.0f, viewTumblingDistance);
	

	GLKVector3 zUpInCameraSpace = GLKMatrix4MultiplyVector3(lastCamera.viewMatrix, targetAxis);
	GLKQuaternion quat2 = GLKQuaternionMakeWithAngleAndVector3Axis( radians2, zUpInCameraSpace);
	delta2 = GLKMatrix4Translate(delta2, 0.0f, 0.0f, -viewTumblingDistance);
	delta2 = GLKMatrix4Multiply(delta2, GLKMatrix4MakeWithQuaternion( quat2 ));
	delta2 = GLKMatrix4Translate(delta2, 0.0f, 0.0f, viewTumblingDistance);
	
	delta = GLKMatrix4Multiply( delta, delta2 );
	delta2 = GLKMatrix4Identity;

	if ( isnan(delta.m00) || isnan(delta2.m00)  ) {
		NSLog(@"delta matrix contains nan ");
	}

	return delta;
}

- (void)beginDragRotateResizeAtTheSameTime:(UIGestureRecognizer*)sender
{
	_cameraInAction = YES;
	_cameraDragRotateResize = YES;
	_lastDeltaApplied = GLKMatrix4Identity;
	_lastFingersDirectionSwapped = NO;
	_lastSingleFingerLifted = NO;
	_lastFingersCenterDeviation = GLKVector2Make(0, 0);
	_resetFirstTouch_ForDragRotateResize = YES;
	//NSLog(@"cameraDragRotateResize at the same time");
	
	CGPoint finger1 = [sender locationOfTouch:0 inView: sender.view];
	CGPoint finger2 = [sender locationOfTouch:1 inView: sender.view];
	
	_firstFingersDirection = GLKVector2Make(finger1.x-finger2.x, finger1.y-finger2.y);
	_lastFingersDirection = _firstFingersDirection;
	_firstFingersCenter = GLKVector2Make( (finger1.x+finger2.x) * 0.5, (finger1.y+finger2.y) * 0.5);
	_lastFingersCenter = _firstFingersCenter;
	
	_lastCameraInfoAtGestureBegan = self.getCameraInfo;
	/*
	if ( self.glkviewVisible ) {
		_lastCameraInfoAtGestureBegan = self.getCameraInfo;
	} else if ( self.scnviewVisible ) {
		_lastCameraInfoAtGestureBegan = _sceneKitController.getCameraInfo;
	}
	 */
	
	// if having selection centroid on screen, then, re-adjust focal distance to make it more heuristical
	if ( self.delegate.hasSelectedObject && !self.isModelOutOfView ) {
		//CGFloat oldFocal = _lastCameraInfoAtGestureBegan.focusDistance;
		CGFloat newFocal = GLKVector3DotProduct(GLKVector3Subtract(self.delegate.selectionCentroid, _lastCameraInfoAtGestureBegan.position), _lastCameraInfoAtGestureBegan.viewDirection);
		_lastCameraInfoAtGestureBegan.focusDistance = newFocal;
		_lastCameraInfoAtGestureBegan.focusPoint = GLKVector3Add(_lastCameraInfoAtGestureBegan.position, GLKVector3MultiplyScalar(_lastCameraInfoAtGestureBegan.viewDirection, _lastCameraInfoAtGestureBegan.focusDistance ));
		//NSLog(@"re-adjusted focal distance : %0.2f to %0.2f", oldFocal, newFocal);
	}
	
	//_lastCameraMatrix = [self getCameraMatrix:NO];
	//_lastInvertedCamera = [self getCameraInverse];
	//_lastCameraPositionInWC = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(_lastInvertedCamera, GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f)).v);
	//_lastCameraViewDirection = GLKVector3Normalize( GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(_lastInvertedCamera, GLKVector4Make(0.0f, 0.0f, -1.0f, 0.0f)).v) );
	//_lastProjectionMatrix = [self getProjectionMatrix];
	//_lastModelView = [self getModelViewMatrix];
	
	GLKVector3 focusPointDepth = [_lastCameraInfoAtGestureBegan projectPointInWC: _lastCameraInfoAtGestureBegan.focusPoint];
	GLKVector3 viewAt = GLKVector3Make( (_firstFingersCenter.x ) * _nativeScale , (ONE_FOURTH_HEIGHT*4.0 - 1 - (_firstFingersCenter.y)) * _nativeScale, focusPointDepth.z );
	_firstFingersCenterWC = [_lastCameraInfoAtGestureBegan unprojectPointInWindow: viewAt];
	
	//NSLog(@"viewport touch at : %@, cp : %@", NSStringFromGLKVector3(viewAt) , NSStringFromGLKVector3(_lastCameraPositionInWC));
}

- (GLKMatrix4)computeDragRotateResizeDelta:(UIGestureRecognizer*)sender
{
	return [self computeDragRotateResizeDelta: sender useParallelFocalPlanePanningForGrabbing: NO];
}
- (GLKMatrix4)computeDragRotateResizeDelta:(UIGestureRecognizer*)sender useParallelFocalPlanePanningForGrabbing:(BOOL)useParallelFocalPlanePanningForGrabbing
{
	//NSTimeInterval startTime = [ [NSDate date] timeIntervalSince1970];
	
	GLKMatrix4 delta = GLKMatrix4Identity;
	if ( sender.numberOfTouches < 1 ) return delta;
	
	//CGPoint lastTouchAt = [sender locationInView: sender.view];
	
	GLKVector2 fingersDirection;
	GLKVector2 fingersCenter;
	
	BOOL reportOldA = NO;
	
	CPanAndMoreGestureRecognizer * panAndMore = nil;
	CGPoint finger1 = [sender locationOfTouch:0 inView: sender.view];
	if ( sender.numberOfTouches > 1 ) {
		CGPoint finger2 = [sender locationOfTouch:1 inView: sender.view];
		
		if ( [sender isKindOfClass: CPanAndMoreGestureRecognizer.class] ) {
			panAndMore = (CPanAndMoreGestureRecognizer*)sender;
			__block BOOL hasTouchBeganPhase = NO;
			__block BOOL hasTouchEndPhase = NO;
			[panAndMore.allTouches enumerateObjectsUsingBlock:^(UITouch * _Nonnull obj, BOOL * _Nonnull stop) {
				if ([obj phase] == UITouchPhaseBegan) {
					hasTouchBeganPhase = YES;
				} else if ( [obj phase] == UITouchPhaseEnded ) {
					hasTouchEndPhase = YES;
				}
			}];
			
			// separate 2 fingers in panningTouches to panningTouches finger and secondaryTouches finger.
			if ( panAndMore.allTouches.count == 2 && [panAndMore.allTouches isEqualToSet: panAndMore.panningTouches] ) {
				//NSLog(@"panning contains all 2 fingers");
				__block UITouch * firstFinger = nil;
				__block UITouch * secondFinger = nil;
				[panAndMore.panningTouches enumerateObjectsUsingBlock:^(UITouch * _Nonnull obj, BOOL * _Nonnull stop) {
					if ( firstFinger == nil ) {
						firstFinger = obj;
					} else {
						secondFinger = obj;
					}
				}];
				if ( secondFinger) {
					[panAndMore.panningTouches removeObject: secondFinger];
					[panAndMore.secondaryTouches addObject: secondFinger];
					
					_lastSingleFingerLifted = YES;
				}
			}
			
			if ( panAndMore.secondaryTouches.count > 0
				//|| ((panAndMore.secondaryTouches.count + panAndMore.panningTouches.count) < panAndMore.allTouches.count)
				) {
				{
					if ( _lastFingersDirectionSwapped ) {
						finger2 = [panAndMore centroidForTouchSet: panAndMore.panningTouches];
						finger1 = [panAndMore centroidForTouchSet: panAndMore.secondaryTouches];
					} else {
						finger1 = [panAndMore centroidForTouchSet: panAndMore.panningTouches];
						finger2 = [panAndMore centroidForTouchSet: panAndMore.secondaryTouches];
					}
				}
				
				if ( (panAndMore.secondaryTouches.count > 1 && hasTouchBeganPhase)
					|| ((panAndMore.secondaryTouches.count + panAndMore.panningTouches.count) < panAndMore.allTouches.count)
					) {
					_lastSingleFingerLifted = YES;
				}
			} else if ((panAndMore.secondaryTouches.count + panAndMore.panningTouches.count) < panAndMore.allTouches.count) {
				_lastSingleFingerLifted = YES;
			} else {
				// default use the first 2 fingers for calculation.
			}
		}
		
		fingersDirection = GLKVector2Make(finger1.x-finger2.x, finger1.y-finger2.y);
		fingersCenter = GLKVector2Make( (finger1.x+finger2.x) * 0.5, (finger1.y+finger2.y) * 0.5);
		fingersCenter = GLKVector2Add( _lastFingersCenterDeviation, fingersCenter );
		// reuse variable as delta
		//_firstTouch = CGPointZero;
		
		// re-touch down, treat subsequent delta rotate or resize starting from re-touch down.
		if ( _lastSingleFingerLifted ) {
			_lastSingleFingerLifted = NO;
			reportOldA = YES;
			
			// rotation restarts from current fingers direction.
			_lastCentroidInWC = _firstFingersCenterWC;
			NSNumber * lastTiltedRadian = 0;
			NSNumber * currentTiltedRadian = 0;
			[self computeCameraRotateAroundFocus: CGPointMake(_lastFingersDirection.x, _lastFingersDirection.y) firstTouchAt: CGPointMake(_firstFingersDirection.x, _firstFingersDirection.y) touchCenter: CGPointZero feedbackRadians: &lastTiltedRadian];
			//NSLog(@"last tilted angle : %0.2f", GLKMathRadiansToDegrees( lastTiltedRadian.floatValue ) );
			[self computeCameraRotateAroundFocus: CGPointMake(fingersDirection.x, fingersDirection.y) firstTouchAt: CGPointMake(_firstFingersDirection.x, _firstFingersDirection.y) touchCenter: CGPointZero feedbackRadians: &currentTiltedRadian];
			//NSLog(@"current tilted angle : %0.2f", GLKMathRadiansToDegrees( currentTiltedRadian.floatValue ) );
			if ( !isnan(currentTiltedRadian.floatValue) && !isnan(lastTiltedRadian.floatValue) ) {
				GLKMatrix3 rotatingMatrix = GLKMatrix3MakeRotation( currentTiltedRadian.floatValue - lastTiltedRadian.floatValue, 0, 0, 1);
				GLKVector3 adjustedFirstFingerDirection = GLKMatrix3MultiplyVector3(rotatingMatrix, GLKVector3Make(_firstFingersDirection.x, _firstFingersDirection.y, 0));
				
				_firstFingersDirection = GLKVector2Make( adjustedFirstFingerDirection.x, adjustedFirstFingerDirection.y );
				
				[self computeCameraRotateAroundFocus: CGPointMake(fingersDirection.x, fingersDirection.y) firstTouchAt: CGPointMake(_firstFingersDirection.x, _firstFingersDirection.y) touchCenter: CGPointZero feedbackRadians: &currentTiltedRadian];
				//NSLog(@"new tilted angle : %0.2f", GLKMathRadiansToDegrees( currentTiltedRadian.floatValue ) );
			}
			
			// resize restarts from current fingers length.
			_lastFingersDirection = fingersDirection;
			
			if ( YES ) {
				GLKVector2 diff = GLKVector2Subtract(_lastFingersCenter, fingersCenter);
				_lastFingersCenterDeviation = GLKVector2Add( _lastFingersCenterDeviation, diff );
				fingersCenter = _lastFingersCenter;
			}
			
		}
	} else {
		fingersDirection = _lastFingersDirection;
		
		if ( [sender isKindOfClass: CPanAndMoreGestureRecognizer.class] ) {
			CPanAndMoreGestureRecognizer * panAndMore = (CPanAndMoreGestureRecognizer*)sender;
			
			if ( panAndMore.panningTouches.count >= 1 && panAndMore.allTouches.count > panAndMore.panningTouches.count ) {
				// reuse as delta
				finger1 = [panAndMore centroidForTouchSet: panAndMore.panningTouches];
				_firstTouch = CGPointMake( _lastFingersCenter.x - finger1.x, _lastFingersCenter.y - finger1.y);
				// check if finger 1 lifted
				GLKVector2 shouldBeDirection = GLKVector2Make( finger1.x - _lastFingersCenter.x, finger1.y - _lastFingersCenter.y);
				if ( GLKVector2DotProduct( shouldBeDirection, fingersDirection ) < 0 ) {
					_lastFingersDirectionSwapped = YES;
				} else {
					_lastFingersDirectionSwapped = NO;
				}
				_lastSingleFingerLifted = YES;
			}
			GLKVector2 deviate = GLKVector2Make( _firstTouch.x, _firstTouch.y );
			fingersCenter = GLKVector2Make( finger1.x + deviate.x, finger1.y + deviate.y );
		} else {
			fingersCenter = _lastFingersCenter;
		}
	}
	
	//NSLog(@"fingerDirection: %@", NSStringFromGLKVector2( fingersDirection ) );
	//NSLog(@"fingerCenter: %@, swapped: %d", NSStringFromGLKVector2( fingersCenter ), _lastFingersDirectionSwapped );
	
	// transform steps:
	// rotate with the angle between last finger center to first finger center.
	// rotate around view with the tilt difference between last finger direction and first finger direction.
	// resize with the difference between last fingers separation and first fingers separation.
	
	// resize view alike pinch
	float zoomScale = 1.0;
	// avoid trembling of first move.
	if ( _resetFirstTouch_ForDragRotateResize ) {
		fingersDirection = _lastFingersDirection;
		_firstFingersDirection = _lastFingersDirection;
	}
	zoomScale = GLKVector2Length( fingersDirection ) / GLKVector2Length( _lastFingersDirection );
	
	//GLKVector3 viewAt = GLKVector3Make( (fingersCenter.x ) * _nativeScale , (ONE_FOURTH_HEIGHT*4.0  - 1 - (fingersCenter.y)) * _nativeScale, 1.0 );
	
	CameraInfo * initialCameraInfo = _lastCameraInfoAtGestureBegan;
	CameraInfo * newCameraInfo = nil;
	
	GLKVector3 lastFingerCenterInWC;
	
	// calculate planar movment following finger center.
	if ( YES ) {
		// revised approach, better and much more exact.
		
		newCameraInfo = [initialCameraInfo copyWithZone:nil];
		CGFloat newFovB = self.defaultFovInDegree * (self.cameraZoomFactor /[self convertToOrthoViewSizeScale:zoomScale]);
		newFovB = GLKMathDegreesToRadians( newFovB );
		GLKMatrix4 newProjectionMatrix ;
		if ( !initialCameraInfo.orthographic )
			newProjectionMatrix = GLKMatrix4MakePerspective( newFovB, initialCameraInfo.aspectRatio, initialCameraInfo.nearPlane, initialCameraInfo.farPlane);
		else {
			float top = initialCameraInfo.nearPlane * tanf( newFovB/2.0 );
			float right = top * initialCameraInfo.aspectRatio;
			newProjectionMatrix = GLKMatrix4MakeOrtho(-right, right, -top, top, initialCameraInfo.nearPlane, initialCameraInfo.farPlane);
		}
		newCameraInfo.projectionMatrix = newProjectionMatrix;
		newCameraInfo.viewPort = initialCameraInfo.viewPort;
		newCameraInfo.xFov = newFovB;
		newCameraInfo.nearPlane = initialCameraInfo.nearPlane;
		newCameraInfo.farPlane = initialCameraInfo.farPlane;
		newCameraInfo.orthographic = initialCameraInfo.orthographic;
		newCameraInfo.aspectRatio = initialCameraInfo.aspectRatio;
		newCameraInfo.viewMatrix = initialCameraInfo.viewMatrix;
		
		// enforce using line of sight for grabbing because the focus point is not at sight.
		if ( self.isModelOutOfView || _lastCameraInfoAtGestureBegan.focusDistance <= 0) {
			useParallelFocalPlanePanningForGrabbing = NO;
		}
		
		if ( useParallelFocalPlanePanningForGrabbing || initialCameraInfo.orthographic ) {
			// move camera parallel to focal plane to simulate grabbing.
			
			if ( _resetFirstTouch_ForDragRotateResize ) {
				//NSLog(@"reset first deviation to avoid trembling effect");
				_lastCameraInfoAtGestureBegan = newCameraInfo;
				initialCameraInfo = newCameraInfo;
			}
			
			GLKVector3 focusPointDepth = [initialCameraInfo projectPointInWC: initialCameraInfo.focusPoint];
			GLKVector3 firstCenterAtViewPort = GLKVector3Make( (_firstFingersCenter.x ) * _nativeScale , (ONE_FOURTH_HEIGHT*4.0 - 1 - (_firstFingersCenter.y)) * _nativeScale, focusPointDepth.z );
			GLKVector3 centerInWCA = [initialCameraInfo unprojectPointInWindow: firstCenterAtViewPort];
			GLKVector3 lastCenterAtViewPort = GLKVector3Make( (fingersCenter.x ) * _nativeScale , (ONE_FOURTH_HEIGHT*4.0 - 1 - (fingersCenter.y)) * _nativeScale, focusPointDepth.z );
			GLKVector3 centerInWCB = [newCameraInfo unprojectPointInWindow: lastCenterAtViewPort];
			// deviation along near plane.
			GLKVector3 deviate = GLKVector3Subtract(centerInWCB, centerInWCA);
			
			//NSLog(@"A : %@, %0.2f, %0.2f", NSStringFromGLKVector3( centerInWCA ), focusPointDepth.z, newFovB );
			//NSLog(@"B : %@", NSStringFromGLKVector3( centerInWCB ) );
			//NSLog(@"new deviate : %@", NSStringFromGLKVector3( deviate ) );
			
#if defined( DEBUG )
			if ( reportOldA ) {
				GLKVector3 centerAtViewPort_beforeTouchDown = GLKVector3Make( (_lastFingersCenter.x ) * _nativeScale , (ONE_FOURTH_HEIGHT*4.0 - 1 - (_lastFingersCenter.y)) * _nativeScale, focusPointDepth.z );
				GLKVector3 lastCenterInWCC = [newCameraInfo unprojectPointInWindow: centerAtViewPort_beforeTouchDown];
				NSLog(@"oldA : %@, %0.2f, %0.2f", NSStringFromGLKVector3( GLKVector3Add(centerInWCA, GLKVector3Subtract(lastCenterInWCC, centerInWCB) )), focusPointDepth.z, newFovB );
			}
#endif
			
			// convert from world coordinate to view coordinate
			GLKVector3 deviationInVC = GLKMatrix4MultiplyVector3( newCameraInfo.viewMatrix, deviate);
			delta = GLKMatrix4Translate(delta, deviationInVC.x, deviationInVC.y, deviationInVC.z);
			
			// set for later uses,
			lastFingerCenterInWC = centerInWCB;
		} else {
			// rotate camera at current camera position for simulating grabbing
			
			GLKVector3 focusPointDepth = [initialCameraInfo projectPointInWC: initialCameraInfo.focusPoint];
			GLKVector3 lastCenterAtViewPort = GLKVector3Make( (fingersCenter.x ) * _nativeScale , (ONE_FOURTH_HEIGHT*4.0 - 1 - (fingersCenter.y)) * _nativeScale, focusPointDepth.z );
			GLKVector3 fingerCenterInWC = [newCameraInfo unprojectPointInWindow: lastCenterAtViewPort];
			GLKVector3 vectorToCenter = GLKVector3Subtract( fingerCenterInWC, newCameraInfo.position) ;
			// avoid trembling of first move.
			if ( _resetFirstTouch_ForDragRotateResize ) {
				_firstFingersCenterWC = fingerCenterInWC;
				
				GLKVector2 diff = GLKVector2Subtract(_lastFingersCenter, fingersCenter);
				_lastFingersCenterDeviation = GLKVector2Add( _lastFingersCenterDeviation, diff );
				fingersCenter = _lastFingersCenter;
				_firstFingersCenter = fingersCenter;
			}
			GLKVector3 vectorToFirstCenter = GLKVector3Subtract( _firstFingersCenterWC, initialCameraInfo.position);
			GLKVector3 axis = GLKVector3CrossProduct( vectorToCenter, vectorToFirstCenter);
			
			if (!initialCameraInfo.orthographic || GLKVector3Length(axis) == 0.0) {
				CGFloat radian = acosf( GLKVector3DotProduct(GLKVector3Normalize(vectorToCenter), GLKVector3Normalize( vectorToFirstCenter )) );
				
				// project the rotating axis to be parallel to focal plane
				// To obtain the projected part, u, of a vector, v, on a plane with normal, n:
				// u=n×(v×n)=v(n⋅n)−n(v⋅n)=v−n(v⋅n)
				axis = GLKVector3CrossProduct(newCameraInfo.viewDirection, GLKVector3CrossProduct(axis, newCameraInfo.viewDirection));
				
				// convert axis from world coord to camera coord, for calling applyCameraDelta
				axis = GLKMatrix4MultiplyVector3( initialCameraInfo.viewMatrix, axis);
				//NSLog(@"angle: %0.2f, around: %@", GLKMathRadiansToDegrees(radian), NSStringFromGLKVector3(axis));
				
				if ( radian == 0.0 || GLKVector3Length(axis) < _epsilon || isnan(radian) || isnan(axis.x)|| isnan(axis.y)|| isnan(axis.z))
				{
					// delta unchanged
				} else {
					axis = GLKVector3Normalize(axis);
					
					// this works fine
					GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( -radian, axis.x, axis.y, axis.z );
					delta = GLKMatrix4Multiply(delta, GLKMatrix4MakeWithQuaternion(quat)) ;
				}
				
				//NSLog(@"new degree : %0.4f", GLKMathRadiansToDegrees( radian ) );
				
			}
			
		}
	}
	
	// tilt around _lastCentroidInWC, the last finger center, along view direction.
	if ( YES ) {
		GLKMatrix4 tiltDelta = GLKMatrix4Identity;
		GLKVector3 fingerCenterInWC;
		_lastCentroidInWC = _firstFingersCenterWC;
		NSNumber * feedbackRadian = 0;
		[self computeCameraRotateAroundFocus: CGPointMake(fingersDirection.x, fingersDirection.y) firstTouchAt: CGPointMake(_firstFingersDirection.x, _firstFingersDirection.y) touchCenter: CGPointZero feedbackRadians: &feedbackRadian];
		
		//NSLog(@"feedbackRadian : %0.4f", feedbackRadian.floatValue);
		
		// adjustment,
		if ( newCameraInfo.focusDistance < 0 ) {
			feedbackRadian = [NSNumber numberWithFloat: -feedbackRadian.floatValue];
			//NSLog(@"adjustment feedbackRadian : %0.4f", feedbackRadian.floatValue);
		}
		
		// at this point, the delta holds deviation of camera due to grab and resize.
		GLKMatrix4 newViewMatrix = GLKMatrix4Multiply( delta, initialCameraInfo.viewMatrix );
		
		newCameraInfo = [newCameraInfo copyWithZone:nil];
		newCameraInfo.viewMatrix = newViewMatrix;
		
		//GLKVector2 fingersCenter_UsedForRotation = GLKVector2Subtract( fingersCenter, _lastFingersCenterDeviation);
		GLKVector3 focusPointDepth = [initialCameraInfo projectPointInWC: initialCameraInfo.focusPoint];
		GLKVector3 lastCenterAtViewPort = GLKVector3Make( (fingersCenter.x ) * _nativeScale , (ONE_FOURTH_HEIGHT*4.0 - 1 - (fingersCenter.y)) * _nativeScale, focusPointDepth.z );
		fingerCenterInWC = [newCameraInfo unprojectPointInWindow: lastCenterAtViewPort];
		
		if ( useParallelFocalPlanePanningForGrabbing || newCameraInfo.orthographic ) {
			GLKVector3 vectorToCenter = GLKVector3Subtract( fingerCenterInWC, newCameraInfo.position) ;
			GLKVector3 vectorToNewView = newCameraInfo.viewDirection;
			
			if ( !newCameraInfo.orthographic ) {
				GLKQuaternion quat = [ViewController quaternionFromVector: vectorToNewView toVector: vectorToCenter];
				
				GLKVector3 axis = GLKQuaternionAxis( quat );
				CGFloat radian = GLKQuaternionAngle( quat );
				
				// convert axis from world coord to camera coord, for calling applyCameraDelta
				axis = GLKMatrix4MultiplyVector3( newCameraInfo.viewMatrix, axis);
				
				if ( GLKVector3Length(axis) < _epsilon || isnan(radian) || isnan(axis.x)|| isnan(axis.y)|| isnan(axis.z) ) {
					// no tiltDelta
				} else {
					axis = GLKVector3Normalize(axis);
					
					quat = GLKQuaternionMakeWithAngleAndAxis( radian, axis.x, axis.y, axis.z );
					
					tiltDelta = GLKMatrix4Multiply(tiltDelta, GLKMatrix4MakeWithQuaternion( (quat) ) );
					tiltDelta = GLKMatrix4Multiply(tiltDelta, GLKMatrix4MakeRotation( feedbackRadian.floatValue, 0, 0, -1) );
					tiltDelta = GLKMatrix4Multiply(tiltDelta, GLKMatrix4MakeWithQuaternion( GLKQuaternionInvert( quat ) ) );
				}
			} else {
				// under orthographic view, this planar deviation is to bring the touch center to screen center after grab and resize.
				GLKVector3 planarDeviation = GLKVector3Subtract(vectorToCenter, GLKVector3MultiplyScalar(newCameraInfo.viewDirection, (GLKVector3DotProduct(vectorToCenter, newCameraInfo.viewDirection))));
				// convert deviation to camera coord.
				GLKVector3 planarDeviationInVC = GLKMatrix4MultiplyVector3( newCameraInfo.viewMatrix, planarDeviation);
				tiltDelta = GLKMatrix4Multiply( tiltDelta, GLKMatrix4MakeTranslation(planarDeviationInVC.x, planarDeviationInVC.y, planarDeviationInVC.z));
				tiltDelta = GLKMatrix4Multiply(tiltDelta, GLKMatrix4MakeRotation( feedbackRadian.floatValue, 0, 0, -1) );
				tiltDelta = GLKMatrix4Multiply( tiltDelta, GLKMatrix4MakeTranslation(-planarDeviationInVC.x, -planarDeviationInVC.y, -planarDeviationInVC.z));
			}
		} else {
			GLKVector3 vectorToFirstCenter = GLKVector3Subtract( _firstFingersCenterWC, initialCameraInfo.position);
			GLKQuaternion quat = [ViewController quaternionFromVector: vectorToFirstCenter toVector: initialCameraInfo.viewDirection ];
			
			GLKVector3 axis = GLKQuaternionAxis( quat );
			CGFloat radian = GLKQuaternionAngle( quat );
			
			// convert axis from world coord to camera coord, for calling applyCameraDelta
			axis = GLKMatrix4MultiplyVector3( newCameraInfo.viewMatrix, axis);
			
			if ( GLKVector3Length(axis) < _epsilon || isnan(radian) || isnan(axis.x)|| isnan(axis.y)|| isnan(axis.z)) {
				// tiltDelta unchanged
			} else {
				axis = GLKVector3Normalize(axis);
				
				quat = GLKQuaternionMakeWithAngleAndAxis( radian, axis.x, axis.y, axis.z );
				
				tiltDelta = GLKMatrix4Multiply(tiltDelta, GLKMatrix4MakeWithQuaternion( GLKQuaternionInvert(quat) ) );
				tiltDelta = GLKMatrix4Multiply(tiltDelta, GLKMatrix4MakeRotation( feedbackRadian.floatValue, 0, 0, -1) );
				tiltDelta = GLKMatrix4Multiply(tiltDelta, GLKMatrix4MakeWithQuaternion( ( quat ) ) );
			}
		}
		
		touchingFocus.center = CGPointMake(fingersCenter.x, fingersCenter.y);
		touchingFocus.hidden = NO;
		
#if defined( DEBUG )
		// debug, bypass tilt
		//tiltDelta = GLKMatrix4Identity;
#endif
		
		if ( !isnan(feedbackRadian.floatValue) ) {
			if ( useParallelFocalPlanePanningForGrabbing || newCameraInfo.orthographic ) {
				delta = GLKMatrix4Multiply( tiltDelta, delta );
			} else {
				delta = GLKMatrix4Multiply( delta, tiltDelta );
			}
		}
	}
	
	// resize view alike pinch, always changing field of view
	if ( !self.cameraPerspective ) {
		self.cameraZoomFactor /= [self convertToOrthoViewSizeScale:zoomScale];		// change fov
		//[self applyCameraZoomFactorDelta:zoomScale];		// this will override deltaMatrix if zoom by distance.
	} else {
		self.cameraZoomFactor /= zoomScale;				// change fov
		// this call will override value in the deltaMatrix if zoom by distance, which will be further overrided by the returning delta.  So, should only use the above property changes to zoom by fov only .
		//[self applyCameraZoomFactorDelta:zoomScale];
	}
	// This call impacts performance.
	//[self updateFovButtonTitle];
	
	_lastFingersDirection = fingersDirection;
	_lastFingersCenter = fingersCenter;
	if ( _resetFirstTouch_ForDragRotateResize ) {
		_resetFirstTouch_ForDragRotateResize = NO;
	}
	
	//NSLog(@"zoom scale : %0.6f", zoomScale);
	
	//NSTimeInterval _loadTimeUsed = [ [NSDate date] timeIntervalSince1970] - startTime;
	//NSLog(@"computeDragRotateResize, elapsed time : %0.3f", _loadTimeUsed);
	
	return delta;
}

// note: _lastCentroidInWC has been set
- (GLKMatrix4)computeCameraRotateAroundFocus:(CGPoint)lastTouchAt firstTouchAt:(CGPoint)firstTouchAt touchCenter:(CGPoint)touchCenter feedbackRadians:(NSNumber**)feedbackRadians
{
	return [self computeCameraRotateAroundCentroid:(GLKVector3)_lastCentroidInWC underCamera:(CameraInfo*)_lastCameraInfoAtGestureBegan lastTouchAt:(CGPoint)lastTouchAt firstTouchAt:(CGPoint)firstTouchAt touchCenter:(CGPoint)touchCenter feedbackRadians:(NSNumber**)feedbackRadians];
}
// this method could be class method
- (GLKMatrix4)computeCameraRotateAroundCentroid:(GLKVector3)centroidInWC underCamera:(CameraInfo*)camera lastTouchAt:(CGPoint)lastTouchAt firstTouchAt:(CGPoint)firstTouchAt touchCenter:(CGPoint)touchCenter feedbackRadians:(NSNumber**)feedbackRadians
{
	float radians;
	
	GLKMatrix4 delta = GLKMatrix4Identity;
	GLKMatrix4 deviateReverse = GLKMatrix4Identity;
	
	GLKVector3 deviateFromCenter = GLKVector3Make(0, 0, 0);
	
	//if ( [theGround hasSelectedObject] ) {
	GLKVector3 currentSelectionCentroid = centroidInWC;  // theGround.selectionCentroid;  ;
	GLKVector3 cameraToCentroid = GLKVector3Subtract( currentSelectionCentroid, camera.position );
	float viewLength = GLKVector3DotProduct(cameraToCentroid, camera.viewDirection);
	deviateFromCenter = GLKVector3Subtract(cameraToCentroid, GLKVector3MultiplyScalar(camera.viewDirection, viewLength)  ) ;
	
	GLKVector3 viewRightDirection = GLKVector3CrossProduct( camera.viewDirection, camera.upDirection);
	
	float rightDeviate = GLKVector3DotProduct(deviateFromCenter, viewRightDirection);
	float upDeviate = GLKVector3DotProduct(deviateFromCenter, camera.upDirection);
	
	//NSLog(@"deviateFromCenter: %@", NSStringFromGLKVector3(deviateFromCenter));
	deviateFromCenter = GLKVector3Make( rightDeviate, upDeviate , 0);
	//NSLog(@"deviate in view port: %@", NSStringFromGLKVector3(deviateFromCenter) );
	
	//if ( GLKVector3Length( deviateFromCenter ) > EPSILON ) {
	GLKMatrix4 cameraMatrix = camera.viewMatrix;
	
	bool isInvertible = NO;
	GLKMatrix4 invertedCamera = GLKMatrix4Invert(cameraMatrix, &isInvertible);;
	if ( !isInvertible ) {
		if ( feedbackRadians != nil ) {
			*feedbackRadians = [NSNumber numberWithFloat:0.0];
		}
		return GLKMatrix4Identity;
	}
	
	GLKVector3 cameraPositionInWC = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, 0.0f, 1.0f)).v);
	GLKVector3 cameraViewDirection = GLKVector3MakeWithArray(GLKMatrix4MultiplyVector4(invertedCamera, GLKVector4Make(0.0f, 0.0f, -1.0f, 0.0f)).v);
	
	GLKVector3 vectorToCenter = GLKVector3Subtract( currentSelectionCentroid, cameraPositionInWC);
	GLKVector3 axis = GLKVector3CrossProduct(cameraViewDirection, vectorToCenter);
	
	if ( !camera.orthographic || GLKVector3Length(axis) == 0.0) {
		CGFloat radian = -acosf( GLKVector3DotProduct(GLKVector3Normalize( vectorToCenter ), cameraViewDirection) );
		
		// convert axis from world coord to camera coord, for calling applyCameraDelta
		axis = GLKMatrix4MultiplyVector3(cameraMatrix, axis);
		
		if ( radian == 0.0 || GLKVector3Length(axis) < _epsilon || isnan(radian) || isnan(axis.x)|| isnan(axis.y)|| isnan(axis.z)) {
			radian = 0.0;
			axis = GLKVector3Normalize(cameraViewDirection);
		}
		axis = GLKVector3Normalize(axis);
		
		GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis( radian, axis.x, axis.y, axis.z );
		delta = GLKMatrix4MakeWithQuaternion(quat);
		deviateReverse = GLKMatrix4Invert(delta, 0);
		
	} else {
		// To obtain the projected part, u, of a vector, v, on a plane with normal, n:
		// u=n×(v×n)=v(n⋅n)−n(v⋅n)=v−n(v⋅n)
		GLKVector3 u = GLKVector3CrossProduct(cameraViewDirection, GLKVector3CrossProduct(vectorToCenter, cameraViewDirection));
		
		//convert axis from world coord to camera coord, for calling applyCameraDelta
		u = GLKMatrix4MultiplyVector3(cameraMatrix, u);
		
		float distance = GLKVector3DotProduct(vectorToCenter, cameraViewDirection);
		if ( distance < 0 ) {
			u.z = -2.0 * distance;
		}
		u = GLKVector3Negate(u);
		
		GLKVector3 displace = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make( u.x, u.y, u.z));
		delta = GLKMatrix4TranslateWithVector3(GLKMatrix4Identity, displace);
		deviateReverse = GLKMatrix4Invert(delta, 0);
		
	}
	
	GLKVector3 rotateAxis = GLKMatrix4MultiplyVector3(GLKMatrix4Identity, GLKVector3Make(0.0f, 0.0f, -1.0f));
	
	// angle between lastTouch and firstTouch, with respect to touchCenter.
	//radians = atan2f( lastTouchAt.y - ONE_FOURTH_HEIGHT*2, lastTouchAt.x - ONE_FOURTH_WIDTH*2) - atan2f(firstTouchAt.y - ONE_FOURTH_HEIGHT*2, firstTouchAt.x - ONE_FOURTH_WIDTH*2);
	radians = atan2f( lastTouchAt.y - touchCenter.y, lastTouchAt.x - touchCenter.x) - atan2f(firstTouchAt.y - touchCenter.y, firstTouchAt.x - touchCenter.x);
	
	//NSLog(@"radians (in degree): %0.2f", GLKMathRadiansToDegrees( radians ) );
	
	if ( ! isnan(radians) ) {
		//deviateFromCenter = GLKVector3Make(0, 5, 0);
		//delta = GLKMatrix4TranslateWithVector3(delta, ( deviateFromCenter ) );
		//delta = GLKMatrix4TranslateWithVector3(delta, GLKVector3Negate(deviateFromCenter) );
		
		GLKMatrix4 combined = GLKMatrix4RotateWithVector3(deviateReverse, radians, rotateAxis);
		delta = GLKMatrix4Multiply(combined, delta);
		
		if ( feedbackRadians != nil ) {
			*feedbackRadians = [NSNumber numberWithFloat: radians];
		}
	}
	
	return delta;
}

- (void)animateCameraStickWithOrbitTurntableStyleWithCompletion:(void (^)(void))completion
{
	if (self.orbitStyleTurntable || self.orbitStyleTurntableYup) {
		[self stopContinuousTumbling];
		
		GLKVector3 unitUp = GLKVector3Make(0, 0, 1);
		
		_axisUpIcon.hidden = self.axisUpIconVisible;
		[self.view removeConstraints: @[ _axisUpIcon_cn_centerx, _axisUpIcon_cn_centery ]];
		if ( self.orbitStyleTurntable ) {
			//_miniAxisView.zAxisColor = [UIColor cyanColor];
			//_miniAxisView.yAxisColor = _miniAxisView.defaultYAxisColor;
			unitUp = GLKVector3Make(0, 0, 1);   // target Z alings with up direction.
			
			_axisUpIcon.text = @"Z\u2191";
			_axisUpIcon_cn_centerx = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
			_axisUpIcon_cn_centery = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterY multiplier:1 constant: -self.view.frame.size.height*0.5 + _axisUpIcon.frame.size.height];
			
		} else if ( self.orbitStyleTurntableYup ) {
			//_miniAxisView.zAxisColor = _miniAxisView.defaultZAxisColor;
			//_miniAxisView.yAxisColor = [UIColor cyanColor];
			unitUp = GLKVector3Make(0, 1, 0);    // target Y alings with up direction.
			
			_axisUpIcon.text = @"Y\u2191";
			_axisUpIcon_cn_centerx = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1 constant:_axisUpIcon.frame.size.width];
			_axisUpIcon_cn_centery = [NSLayoutConstraint constraintWithItem:_axisUpIcon attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeCenterY multiplier:1 constant:-10];
		}
		[self.view addConstraints: @[ _axisUpIcon_cn_centerx, _axisUpIcon_cn_centery ]];
		[UIView animateWithDuration:0.5 animations:^{
			[self.view layoutIfNeeded];
		}];
		
		CameraInfo * currentCamera = [self getCameraInfo];
		
		GLKVector3 eye2focus = GLKVector3Subtract( currentCamera.focusPoint, currentCamera.position);
		
		GLKVector3 projectedPart = [self getProjectedPartVector: eye2focus onPlaneNormal:unitUp];
		
		GLKVector3 targetPosition = currentCamera.position;
		if ( GLKVector3Length( projectedPart ) < _epsilon ) {
			targetPosition = GLKVector3Add( currentCamera.focusPoint, GLKVector3MultiplyScalar(currentCamera.upDirection, -currentCamera.focusDistance));
		}
		
		// this animation brings the target axis to up direction.
		[self animateCameraTo: targetPosition lookingAt: currentCamera.focusPoint upDir: unitUp completion:^{
			CameraInfo * afterCamera = self.getCameraInfo;
			
			GLKVector3 eye2focus = GLKVector3Subtract( afterCamera.focusPoint, afterCamera.position);
			float deviateFromPlane = GLKVector3DotProduct( eye2focus, unitUp );
			GLKVector3 newEye2focusDir = GLKVector3Normalize( GLKVector3Add( eye2focus, GLKVector3MultiplyScalar( unitUp, -deviateFromPlane) ) );
			GLKVector3 newCameraPosition = afterCamera.position;
			if ( ! isnan( newEye2focusDir.x) ) {
				newCameraPosition = GLKVector3Add( afterCamera.focusPoint, GLKVector3MultiplyScalar(newEye2focusDir, - afterCamera.focusDistance));
			}
			
			//NSLog(@"mid camera : %@", NSStringFromGLKVector3(newCameraPosition) ) ;
			if ( isnan(newCameraPosition.x) ) {
				NSLog(@"mid camera position Nan");
			}
			
			[self animateCameraTo: newCameraPosition lookingAt: afterCamera.focusPoint upDir: unitUp completion:^{
				//CameraInfo * completedCamera = theGround.getCameraInfo;
				//NSLog(@"end camera : %@", NSStringFromGLKVector3(completedCamera.position) ) ;
				
				if ( completion ) {
					NSLog(@"animate sticky up axis : %@", self.orbitStyleTurntable?@"Z":@"Y");
					completion();
				}
				
			}];
			
		}];
		
	} else {
		NSLog(@"orbit turntable style disabled");
		[UIView animateWithDuration:0.5 animations:^{
			//_miniAxisView.zAxisColor = _miniAxisView.defaultZAxisColor;
			//_miniAxisView.yAxisColor = _miniAxisView.defaultYAxisColor;
			_axisUpIcon.hidden = YES;
		} completion:^(BOOL finished) {
			if ( completion ) {
				NSLog(@"animate sticky up axis : none");
				completion();
			}
		}];
	}
	
	//[menuViewController refreshMenuStatus];
	return;
}

- (GLKVector3)getProjectedPartVector:(GLKVector3)v onPlaneNormal:(GLKVector3)n
{
	//To obtain the projected part, u, of a vector, v, on a plane with normal, n:
	//u=n×(v×n)=v(n⋅n)−n(v⋅n)=v−n(v⋅n)
	//GLKVector3 projectedPartU = GLKVector3Subtract( v, GLKVector3MultiplyScalar(n, GLKVector3DotProduct(v, n) ) );
	
	// or
	GLKVector3 u = GLKVector3CrossProduct(n, GLKVector3CrossProduct(v, n));
	
	return u;
}


@end
// =========================================================================================

