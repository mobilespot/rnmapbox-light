#ifdef RCT_NEW_ARCH_ENABLED

#import "RNMBXCameraComponentView.h"
#import "RNMBXFabricHelpers.h"

#import <React/RCTConversions.h>
#import <React/RCTFabricComponentsPlugins.h>

#import <react/renderer/components/rnmapbox_maps_specs/ComponentDescriptors.h>
#import <react/renderer/components/rnmapbox_maps_specs/EventEmitters.h>
#import <react/renderer/components/rnmapbox_maps_specs/Props.h>
#import <react/renderer/components/rnmapbox_maps_specs/RCTComponentViewHelpers.h>

using namespace facebook::react;

@interface RNMBXCameraComponentView () <RCTRNMBXCameraViewProtocol>
@end

@implementation RNMBXCameraComponentView {
    RNMBXCamera *_view;
}

// Needed because of this: https://github.com/facebook/react-native/pull/37274
+ (void)load
{
  [super load];
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNMBXCameraProps>();
    _props = defaultProps;
    [self prepareView];
  }

  return self;
}

- (void)prepareView
{
    _view =  [[RNMBXCamera alloc] init];
    
    // just need to pass something, it won't really be used on fabric, but it's used to create events (it won't impact sending them)
    _view.reactTag = @-1;
    
    __weak __typeof__(self) weakSelf = self;

  self.contentView = _view;
}

#pragma mark - RCTComponentViewProtocol

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<RNMBXCameraComponentDescriptor>();
}

- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps
{
    const auto &oldViewProps = static_cast<const RNMBXCameraProps &>(*oldProps);
    const auto &newViewProps = static_cast<const RNMBXCameraProps &>(*props);
    id maxBounds = RNMBXConvertFollyDynamicToId(newViewProps.maxBounds);
    if (maxBounds != nil) {
        _view.maxBounds = maxBounds;
    }
    id animationDuration = RNMBXConvertFollyDynamicToId(newViewProps.animationDuration);
    if (animationDuration != nil) {
        _view.animationDuration = animationDuration;
    }
    id animationMode = RNMBXConvertFollyDynamicToId(newViewProps.animationMode);
    if (animationMode != nil) {
        _view.animationMode = animationMode;
    }
    id defaultStop = RNMBXConvertFollyDynamicToId(newViewProps.defaultStop);
    if (defaultStop != nil) {
        _view.defaultStop = defaultStop;
    }
    id maxZoomLevel = RNMBXConvertFollyDynamicToId(newViewProps.maxZoomLevel);
    if (maxZoomLevel != nil) {
        _view.maxZoomLevel = maxZoomLevel;
    }
    id minZoomLevel = RNMBXConvertFollyDynamicToId(newViewProps.minZoomLevel);
    if (minZoomLevel != nil) {
        _view.minZoomLevel = minZoomLevel;
    }

    if (!oldProps || oldViewProps.stop != newViewProps.stop) {
      id stop = RNMBXConvertFollyDynamicToId(newViewProps.stop);
      if (stop != nil) {
        _view.stop = stop;
      }
    }
  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle
{
    [super prepareForRecycle];
    [self prepareView];
}

@end

Class<RCTComponentViewProtocol> RNMBXCameraCls(void)
{
  return RNMBXCameraComponentView.class;
}

#endif // RCT_NEW_ARCH_ENABLED
