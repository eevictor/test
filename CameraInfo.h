//
//  CameraInfo.h
//  Sketch with Perspective View
//
//  Created by Victor NG on 24/6/2015.
//  Copyright (c) 2015年 Victor WP NG. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

// =========================================================================================
@interface CameraInfo : NSObject <NSCopying>

- (instancetype)initWithMatrix:(GLKMatrix4)viewMatrix focusDistance:(float)focusDistance;

// vector in World Coordinate
@property (nonatomic, assign) GLKVector3 position;
@property (nonatomic, assign) GLKVector3 viewDirection;
@property (nonatomic, assign) GLKVector3 upDirection;
@property (nonatomic) float xFov;			// in radians
@property (nonatomic) float farPlane;
@property (nonatomic) float nearPlane;
@property (nonatomic) BOOL orthographic;
@property (nonatomic) float aspectRatio;

@property (nonatomic, assign) float focusDistance;
@property (nonatomic, assign) GLKVector3 focusPoint;

@property (nonatomic, assign) CGRect viewPort;
@property (nonatomic, assign) GLKMatrix4 viewMatrix;
@property (nonatomic, assign) GLKMatrix4 invertedViewMatrix;
@property (nonatomic, assign) GLKMatrix4 projectionMatrix;
//@property (nonatomic, readonly) BOOL isValid;

- (GLKVector3)projectPointInWC:(GLKVector3)pointInWC;
- (GLKVector3)unprojectPointInWindow:(GLKVector3)pointInWindow;

@end

// =========================================================================================
@protocol CameraManipulable <NSObject>

@required
- (CGRect)getViewPort;
- (GLKMatrix4)getModelMatrix;
- (GLKMatrix4)getModelViewMatrix;
- (GLKMatrix4)getModelViewProjectionMatrix;
- (GLKMatrix3)getNormalMatrix;
- (NSArray*)getBounds;
- (GLKVector3)getBoundsCenter;
- (float)getBoundsMaxSize;

- (BOOL)hasSelectedObject;
- (GLKVector3)selectionCentroid;

@optional
- (void)lookAt:(GLKVector3)center;
- (void)lookAt:(GLKVector3)center completion:(void (^)(void))completionHandler;
- (void)lookAt:(GLKVector3)center encompass:(CGFloat)radius completion:(void (^)(void))completionHandler;
- (void)setCameraFocalDistanceTo:(GLKVector3)position;
- (void)setCameraFocalDistance:(CGFloat)focalDistance;
- (void)setCameraYAxisUp:(BOOL)Yup;
- (BOOL)isCameraYAxisUp;
- (void)setCameraFoV:(CGFloat)radian;
- (float)getDefaultFieldOfViewInDegree;

- (BOOL)shouldChannelGesture:(UIGestureRecognizer*)gesture;
- (void)channelGestureHandler:(UIGestureRecognizer*)gesture;
// true indicates moved
- (BOOL)moveCameraForAdditionalTouchWhenPanning:(UIGestureRecognizer *)sender;

// return true to continue next step processing, return false to stop further processing.
- (BOOL)gestureDetectedPreprocessing:(UIGestureRecognizer*)sender;
- (void)gestureDetectedPostprocessing:(UIGestureRecognizer*)sender;

/*
 Sample implemenation

// reflect the camera operator's changes onto the view's pointOfView to take effect.
- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time
{
	if ( _controller ) {
		SCNMatrix4 cameraMatrix = SCNMatrix4FromGLKMatrix4( [_controller.cameraOperator getCameraMatrix] );
		SCNNode * cameraNode = renderer.pointOfView;
		// this call channels the view matrix from CameraOperator to the view and thus take effect of camera manipulation.
		cameraNode.transform = SCNMatrix4Invert( cameraMatrix );
	}
}


// make sure the view frame size is correctly tracked by the camera operator.
- (void)viewDidLayoutSubviews
{
	NSLog(@"viewDidLayoutSubviews, %@", NSStringFromCGRect( self.view.frame ));
	[cameraOperator viewFrameChanged];
}

// used as reference for focusing.
- (NSArray *)getBounds {
	GLKVector3 min = GLKVector3Make(-0.5, -0.5, -0.5);
	GLKVector3 max = GLKVector3Negate( min );
	if ( self.selectedObject ) {
		SCNVector3 a, b;
		if ([self.selectedObject getBoundingBoxMin: &a max: &b]) {
			min = SCNVector3ToGLKVector3( a );
			max = SCNVector3ToGLKVector3( b );
		}
	}
	
	NSArray * _unitBounds = @[[NSValue valueWithBytes:&min objCType:@encode(GLKVector3)], [NSValue valueWithBytes:&max objCType:@encode(GLKVector3)]];
	
	return _unitBounds;
}

// this center indirectly affects the way of pulling camera, either by changing FoV or move forward/backward.
- (GLKVector3)getBoundsCenter {
	NSArray *boundingBox = [self getBounds];
	GLKVector3 min, max;
	[boundingBox[0] getValue:&min];
	[boundingBox[1] getValue:&max];
	return GLKVector3DivideScalar(GLKVector3Add(min, max), 2.0);
}

// this max size indirectly affects the way of pulling camera, either by changing FoV or move forward/backward.
- (float)getBoundsMaxSize {
	NSArray *boundingBox = [self getBounds];
	GLKVector3 min, max;
	[boundingBox[0] getValue:&min];
	[boundingBox[1] getValue:&max];
	return GLKVector3Distance(min, max);
}

- (GLKMatrix4)getModelMatrix {
	GLKMatrix4 modelMatrix = GLKMatrix4Identity;
	return modelMatrix;
}


- (GLKMatrix4)getModelViewMatrix {
	GLKMatrix4 viewMatrix = [cameraOperator getCameraMatrix];
	GLKMatrix4 modelMatrix = [self getModelMatrix];
	GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply(viewMatrix, modelMatrix);
	return modelViewMatrix;
}


- (GLKMatrix4)getModelViewProjectionMatrix {
	GLKMatrix4 modelViewMatrix = [self getModelViewMatrix];
	GLKMatrix4 projectionMatrix = [cameraOperator getProjectionMatrix];
	GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply( projectionMatrix, modelViewMatrix );
	return modelViewProjectionMatrix;
}

- (GLKMatrix3)getNormalMatrix {
	GLKMatrix4 modelViewMatrix = [self getModelViewMatrix];
	GLKMatrix3 normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
	return normalMatrix;
}

- (CGRect)getViewPort {
	CGRect viewport = CGRectMake(0, 0, self.view.frame.size.width * cameraOperator.nativeScale, self.view.frame.size.height * cameraOperator.nativeScale);
	return viewport;
}

- (GLKVector3)selectionCentroid {
	GLKVector3 centroid = GLKVector3Make(0, 0, 0);
	if ( self.selectedObject ) {
		centroid = [self getBoundsCenter];
	}
	return centroid;
}
 
 */

@end

// =========================================================================================
@interface CameraOperator : NSObject <UIGestureRecognizerDelegate>
{
	// pre-computed view size.
	CGRect VIEW_FRAME;
	float ONE_THIRD_WIDTH;
	float ONE_THIRD_HEIGHT;
	float ONE_FOURTH_WIDTH;
	float ONE_FOURTH_HEIGHT;
	float ONE_FIFTH_WIDTH;
	float ONE_FIFTH_HEIGHT;
	float ONE_SIXTH_WIDTH;
	float ONE_SIXTH_HEIGHT;
	
}

// initialize this class with a UIView and a CameraManipulable.
// The view is used as viewable rect for determining gesture area.
// The CameraManipulable is to send detected operations for the desired result.
- (instancetype)initWithView:(UIView*)view manipulable:(id<CameraManipulable>)manipulable;

@property (nonatomic) id<CameraManipulable> delegate;
@property (nonatomic, weak, nullable) UIView * view;
@property (nonatomic, readonly) CGFloat nativeScale;
- (void)viewFrameChanged;

// visual overlay on the view.
@property (nonatomic) BOOL axisUpIconVisible;

@property (nonatomic) CameraInfo * _Nonnull cameraInfo;

@property (nonatomic) float cameraZoomFactor;
@property (nonatomic, readonly) float defaultFovInDegree;
@property (nonatomic, readonly) float smallestFovFactor;

@property (nonatomic) GLKVector3 focalPlane;
@property (nonatomic) float focalPlaneDistance;
@property (nonatomic, readonly) float adjustedFocalPlaneFactor;
@property (nonatomic, readonly) float adjustedFocalPlaneDistance;
@property (nonatomic) float nearPlane;
@property (nonatomic) float farPlane;
@property (nonatomic) float aspectRatio;

@property (nonatomic, readonly) float epsilon;
@property (nonatomic, assign) BOOL orbitStyleTurntable;
@property (nonatomic) BOOL orbitStyleTurntableYup;
@property (nonatomic) BOOL cameraFrontView;
@property (nonatomic) BOOL cameraTopView;
@property (nonatomic) BOOL cameraSideView;
@property (nonatomic) BOOL cameraPerspective;
@property (nonatomic) BOOL cameraBackView;
@property (nonatomic) BOOL cameraBottomView;
@property (nonatomic) BOOL cameraLeftView;

@property (nonatomic) BOOL cameraChangeNotificationEnabled;

- (GLKMatrix4)getProjectionMatrix;
@property (nonatomic) GLKMatrix4 cameraMatrix;
- (GLKMatrix4)getCameraDelta;
- (void)applyCameraDelta:(GLKMatrix4)deltaMatrix;
- (void)applyCameraDeltaCompleted:(GLKMatrix4)deltaMatrix;
- (void)applyCameraDelta:(GLKMatrix4)deltaMatrix withNotification:(BOOL)notify;
- (void)applyCameraDeltaCompleted:(GLKMatrix4)deltaMatrix withNotification:(BOOL)notify;
- (void)applyCameraDelta:(GLKMatrix4)deltaMatrix postpend:(BOOL)postpend;
- (void)applyCameraDeltaCompleted:(GLKMatrix4)deltaMatrix postpend:(BOOL)postpend;
- (void)rotateCameraDelta:(GLKQuaternion)quaternion;
- (void)rotateCameraDeltaCompleted:(GLKQuaternion)quaternion;
- (BOOL)applyCameraZoomFactorDelta:(float)scale;
- (BOOL)applyCameraZoomFactorCompleted:(float)scale;
- (void)moveCameraForwardDelta:(float)deltaDist;
- (void)moveCameraForwardDeltaCompleted:(float)deltaDist;
- (BOOL)applyCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov;
- (BOOL)applyCameraZoomFactorCompleted:(float)scale fovOnly:(BOOL)useFov;
- (BOOL)applyCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundCenter;
- (BOOL)applyCameraZoomFactorCompleted:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundCenter;
//- (GLKMatrix4)computeCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov usingReferenceBoundsCenter:(GLKVector3)boundCenter resultFOV:(CGFloat*)resultDeltaFovZoomFactor;
- (BOOL)applyCameraZoomFactorDelta:(float)scale deviateInView:(GLKVector2)deviateInView;
- (BOOL)applyCameraZoomFactorCompleted:(float)scale deviateInView:(GLKVector2)deviateInView;
- (BOOL)applyCameraZoomFactorDelta:(float)scale fovOnly:(BOOL)useFov deviateInView:(GLKVector2)deviateInView;
- (BOOL)applyCameraZoomFactorCompleted:(float)scale fovOnly:(BOOL)useFov deviateInView:(GLKVector2)deviateInView;

- (void)resetToDefaults;
- (void)resetToDefaultsWithMatrix:(GLKMatrix4)startingCameraMatrix;
- (GLKMatrix4)getInitialCameraMatrix;
- (void)replaceInitialCameraMatrix:(GLKMatrix4)matrix;
- (GLKMatrix4)undoCameraDelta;
- (GLKMatrix4)getCameraInverse;
- (GLKMatrix4)getCameraMatrix;
- (GLKMatrix4)getCameraMatrix:(BOOL)withDelta;
- (int)getCameraMoveCount;
- (float)getCameraFoV;
- (void)setCameraFoV:(float)radian;
- (CameraInfo*)getCameraInfo;
- (GLKVector3)getCameraPosition;
- (GLKVector3)getCameraViewDirection;
- (void)adjustFocalPlaneFactor:(float)percentage;
- (float)adjustedFocalPlaneDistance:(BOOL)gestureEnded;
- (float)convertToOrthoViewSizeScale:(float)fovScale;

// convenient methods
- (float)getApparentViewingModelSize;
- (BOOL)isModelOutOfView;
- (void)adjustCameraToCenterOnBounds:(NSArray * _Nullable)minmax;
- (void)resetFocalPlaneToBoundsCenter;
- (void)resetFocusToLocation:(GLKVector3)locationInWC;
// return a value from -1, 0, +1, interpolating model center to the near plane, focal, far plane positions.
- (float)modelInViewingRegion;
- (void)adjustCameraToCenterOnModel;

// Assume touchOrigin specified in OS screen coordinates, which is 0,0 at upper left.
- (void)rayFromTouch:(CGPoint)touchOrigin into:(GLKVector3* _Nullable)holder;
// Assume pointInWindow specified in GL window coordinates, which is 0,0 at lower left.
- (GLKVector3)pointFromTouch:(GLKVector3)pointInWindow;
- (GLKVector3)pointFromTouchWithoutDeltaCamera:(GLKVector3)pointInWindow;
- (GLKVector3)projectForPoint:(GLKVector3)pointInWC;
- (GLKVector3)projectForPointWithoutDeltaCamera:(GLKVector3)pointInWC;
- (GLKVector3)projectedVectorInWC:(CameraInfo *) camera viewSize:(float) viewSize startingPointInWC:(GLKVector3) startingPointInWC directionInWC:(GLKVector3) directionInWC;

// gestures
@property (nonatomic) BOOL channelGestureInAction;
@property (nonatomic) BOOL channelGesturePencilInAction;
@property (nonatomic) BOOL singleBoneRollInAction;

@property (nonatomic) UIGestureRecognizer * panRecognizer;
@property (nonatomic) UIGestureRecognizer * pinchRecognizer;
@property (nonatomic) UIGestureRecognizer * doubleTapRecognizer;
@property (nonatomic) UIGestureRecognizer * tapRecognizer;
@property (nonatomic) UIGestureRecognizer * longPressRecognizer;

@property (nonatomic) BOOL lockingTumbling;
@property (nonatomic) GLKVector3 lockingViewDir;

- (void)animateCameraTo:(GLKVector3)newPosition lookingAt:(GLKVector3)lookingAt upDir:(GLKVector3)upDir completion:(void (^_Nullable)(void))completion;

@end

// ========================================================================================
