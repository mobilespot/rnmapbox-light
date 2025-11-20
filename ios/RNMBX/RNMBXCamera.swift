import Foundation
import MapboxMaps
import Turf

extension NSNumber {
  /// Converts an `NSNumber` to a `CGFloat` value from its `Double` representation.
  internal var CGFloat: CGFloat {
    CoreGraphics.CGFloat(doubleValue)
  }
}

public enum RemovalReason {
    case ViewRemoval, StyleChange, OnDestroy, ComponentChange, Reorder
}

/// Base protocol for all map components
public protocol RNMBXMapComponentProtocol: AnyObject {
  func waitForStyleLoad() -> Bool
}

/// Default implementation: most components don't need to wait for style load
extension RNMBXMapComponentProtocol {
  public func waitForStyleLoad() -> Bool {
    return false
  }
}

/// Protocol for components that can work without direct MapView access
public protocol RNMBXMapComponent: RNMBXMapComponentProtocol {
  func addToMap(_ map: RNMBXMapView, style: Style)
  func removeFromMap(_ map: RNMBXMapView, reason: RemovalReason) -> Bool
}

/// Protocol for components that require a valid MapView instance for both add and remove operations.
/// Use this protocol when your component needs to interact with the native MapView directly.
/// The MapView parameter is guaranteed to be non-nil when these methods are called.
///
/// This protocol inherits from RNMBXMapComponent to ensure compatibility with existing code,
/// but provides default implementations of the base protocol methods that throw errors,
/// forcing implementers to use the mapView-aware versions.
public protocol RNMBXMapAndMapViewComponent: RNMBXMapComponent {
  func addToMap(_ map: RNMBXMapView, mapView: MapView, style: Style)
  func removeFromMap(_ map: RNMBXMapView, mapView: MapView, reason: RemovalReason) -> Bool
}

/// Default implementations for RNMBXMapAndMapViewComponent that prevent accidental use of base protocol methods
extension RNMBXMapAndMapViewComponent {
  public func addToMap(_ map: RNMBXMapView, style: Style) {
    Logger.error("CRITICAL: addToMap(_:style:) called on RNMBXMapAndMapViewComponent. Use addToMap(_:mapView:style:) instead. Component: \(type(of: self))")
  }

  public func removeFromMap(_ map: RNMBXMapView, reason: RemovalReason) -> Bool {
    Logger.error("CRITICAL: removeFromMap(_:reason:) called on RNMBXMapAndMapViewComponent. Use removeFromMap(_:mapView:reason:) instead. Component: \(type(of: self))")
    return false
  }
}

enum CameraMode: Int {
  case flight = 1
  case ease = 2
  case linear = 3
  case move = 4
  case none = 5
}

struct CameraUpdateItem {
  var camera: CameraOptions
  var mode: CameraMode
  var duration: TimeInterval?
  
  func execute(map: RNMBXMapView, cameraAnimator: inout BasicCameraAnimator?) {
    logged("CameraUpdateItem.execute") {
      if let center = camera.center {
        try center.validate()
      }

      switch mode {
      case .flight:
        map.mapView.camera.fly(to: camera, duration: duration)
      case .ease:
        map.mapView.camera.ease(to: camera, duration: duration ?? 0, curve: .easeInOut, completion: nil)
      case .linear:
        map.mapView.camera.ease(to: camera, duration: duration ?? 0, curve: .linear, completion: nil)
      default:
        map.mapboxMap.setCamera(to: camera)
      }
    }
  }
}

class CameraUpdateQueue {
  var queue: [CameraUpdateItem] = [];
  
  func dequeue() -> CameraUpdateItem? {
    guard !queue.isEmpty else {
      return nil
    }
    return queue.removeFirst()
  }
  
  func enqueue(stop: CameraUpdateItem) {
    queue.append(stop)
  }
  
  func execute(map: RNMBXMapView, cameraAnimator: inout BasicCameraAnimator?) {
    guard let stop = dequeue() else {
      return
    }
    
    stop.execute(map: map, cameraAnimator: &cameraAnimator)
  }
}

open class RNMBXMapComponentBase : UIView, RNMBXMapComponent {
  private weak var _map: RNMBXMapView! = nil
  private var _mapCallbacks: [(RNMBXMapView) -> Void] = []

  weak var map : RNMBXMapView? {
    return _map;
  }

  func withMapView(_ callback: @escaping (_ mapView: MapView) -> Void) {
    withRNMBXMapView { mapView in
      callback(mapView.mapView)
    }
  }

  func withRNMBXMapView(_ callback: @escaping (_ map: RNMBXMapView) -> Void) {
    if let map = _map {
      callback(map)
    } else {
      _mapCallbacks.append(callback)
    }
  }

  public func addToMap(_ map: RNMBXMapView, style: Style) {
    _mapCallbacks.forEach { callback in
        callback(map)
    }
    _mapCallbacks = []
    _map = map
  }

  public func removeFromMap(_ map: RNMBXMapView, reason: RemovalReason) -> Bool {
    _mapCallbacks = []
    _map = nil
    return true
  }
}

/// Base class for components that require MapView to be non-nil
open class RNMBXMapAndMapViewComponentBase : UIView, RNMBXMapAndMapViewComponent {
  private weak var _map: RNMBXMapView! = nil
  private var _mapCallbacks: [(RNMBXMapView) -> Void] = []

  weak var map : RNMBXMapView? {
    return _map;
  }

  func withMapView(_ callback: @escaping (_ mapView: MapView) -> Void) {
    withRNMBXMapView { mapView in
      callback(mapView.mapView)
    }
  }

  func withRNMBXMapView(_ callback: @escaping (_ map: RNMBXMapView) -> Void) {
    if let map = _map {
      callback(map)
    } else {
      _mapCallbacks.append(callback)
    }
  }

  // Uses default implementation from RNMBXMapComponentProtocol extension

  public func addToMap(_ map: RNMBXMapView, mapView: MapView, style: Style) {
    _mapCallbacks.forEach { callback in
        callback(map)
    }
    _mapCallbacks = []
    _map = map
  }

  public func removeFromMap(_ map: RNMBXMapView, mapView: MapView, reason: RemovalReason) -> Bool {
    _mapCallbacks = []
    _map = nil
    return true
  }
}

@objc(RNMBXCamera)
open class RNMBXCamera : RNMBXMapAndMapViewComponentBase {
  var cameraAnimator: BasicCameraAnimator?
  let cameraUpdateQueue = CameraUpdateQueue()
  
  // MARK: React properties
  
  @objc public var animationDuration: NSNumber?
  
  @objc public var animationMode: NSString?
  
  @objc public var defaultStop: [String: Any]?
  
  @objc public var maxZoomLevel: NSNumber? {
    didSet { _updateMaxBounds() }
  }
  
  @objc public var minZoomLevel: NSNumber? {
    didSet { _updateMaxBounds() }
  }
  
  @objc public var stop: [String: Any]? {
    didSet {
      _updateCamera()
    }
  }
  
  @objc public var maxBounds: String? {
    didSet {
      if let maxBounds = maxBounds {
        logged("RNMBXCamera.maxBounds") {
          maxBoundsFeature = try JSONDecoder().decode(FeatureCollection.self, from: maxBounds.data(using: .utf8)!)
        }
      } else {
        maxBoundsFeature = nil
      }
      _updateMaxBounds()
    }
  }
  var maxBoundsFeature : FeatureCollection? = nil
  
  // MARK: Update methods

  func _updateCameraFromJavascript() {
    guard let stop = stop else {
      return
    }

    if let stops = stop["stops"] as? [[String:Any]] {
      stops.forEach {
        if let stop = toUpdateItem(stop: $0) {
          cameraUpdateQueue.enqueue(stop: stop)
        }
      }
    } else {
      if let stop = toUpdateItem(stop: stop) {
        cameraUpdateQueue.enqueue(stop: stop)
      }
    }

    if let map = map {
      cameraUpdateQueue.execute(map: map, cameraAnimator: &cameraAnimator)
    }
  }
  
  @objc public func updateCameraStop(_ stop: [String: Any]) {
    self.stop = stop
  }
  
  func _toCoordinateBounds(_ bounds: FeatureCollection) throws -> CoordinateBounds  {
    guard bounds.features.count == 2 else {
      throw RNMBXError.paramError("Expected two Points in FeatureColletion")
    }
    let swFeature = bounds.features[0]
    let neFeature = bounds.features[1]
    
    guard case let .point(sw) = swFeature.geometry,
          case let .point(ne) = neFeature.geometry else {
      throw RNMBXError.paramError("Expected two Points in FeatureColletion")
    }

    return CoordinateBounds(southwest: sw.coordinates, northeast: ne.coordinates)
  }
  
  func _updateMaxBounds() {
    withMapView { map in
      let current = map.mapboxMap.cameraBounds
      var options = CameraBoundsOptions()

      if let maxBounds = self.maxBoundsFeature {
        logged("RNMBXCamera._updateMaxBounds._toCoordinateBounds") {
          options.bounds = try self._toCoordinateBounds(maxBounds)
        }
      } else {
        options.bounds = nil
      }
      options.minZoom = self.minZoomLevel?.CGFloat
      options.maxZoom = self.maxZoomLevel?.CGFloat
      options.minPitch = current.minPitch
      options.maxPitch = current.maxPitch

      logged("RNMBXCamera._updateMaxBounds") {
        try map.mapboxMap.setCameraBounds(with: options)
      }
    }
  }
  
  private func toUpdateItem(stop: [String: Any]) -> CameraUpdateItem? {
    if (stop.isEmpty) {
      return nil
    }
    
    var zoom: CGFloat?
    if let z = stop["zoom"] as? Double {
      zoom = CGFloat(z)
    }

    var pitch: CGFloat?
    if let p = stop["pitch"] as? Double {
      pitch = CGFloat(p)
    }
    
    var heading: CLLocationDirection?
    if let h = stop["heading"] as? Double {
      heading = CLLocationDirection(h)
    }
    
    var padding: UIEdgeInsets = UIEdgeInsets(
      top: stop["paddingTop"] as? Double ?? 0,
      left: stop["paddingLeft"] as? Double ?? 0,
      bottom: stop["paddingBottom"] as? Double ?? 0,
      right: stop["paddingRight"] as? Double ?? 0
    )
    
    var camera: CameraOptions?
    
    if let feature = stop["centerCoordinate"] as? String {
      let centerFeature : Turf.Feature? = logged("RNMBXCamera.toUpdateItem.decode.cc") { try
        JSONDecoder().decode(Turf.Feature.self, from: feature.data(using: .utf8)!)
      }
      
      var center: LocationCoordinate2D?
      
      switch centerFeature?.geometry {
      case .point(let centerPoint):
        center = centerPoint.coordinates
      default:
        Logger.log(level: .error, message: "RNMBXCamera.toUpdateItem: Unexpected geometry: \(String(describing: centerFeature?.geometry))")
        return nil
      }
      
      camera = CameraOptions(
        center: center,
        padding: padding,
        anchor: nil,
        zoom: zoom,
        bearing: heading,
        pitch: pitch
      )
    } else if let feature = stop["bounds"] as? String {
      let collection : Turf.FeatureCollection? = logged("RNMBXCamera.toUpdateItem.decode.bound") { try
        JSONDecoder().decode(Turf.FeatureCollection.self, from: feature.data(using: .utf8)!) }
      let features = collection?.features
      
      let ne: CLLocationCoordinate2D
      switch features?.first?.geometry {
        case .point(let point):
          ne = point.coordinates
        default:
          Logger.log(level: .error, message: "RNMBXCamera.toUpdateItem: Unexpected geometry: \(String(describing: features?.first?.geometry))")
          return nil
      }
      
      let sw: CLLocationCoordinate2D
      switch features?.last?.geometry {
        case .point(let point):
          sw = point.coordinates
        default:
          Logger.log(level: .error, message: "RNMBXCamera.toUpdateItem: Unexpected geometry: \(String(describing: features?.last?.geometry))")
          return nil
      }
      
      withMapView { map in
        let bounds = [sw, ne]

        camera = map.mapboxMap.camera(
          for: bounds,
          padding: padding,
          bearing: heading ?? map.mapboxMap.cameraState.bearing,
          pitch: pitch ?? map.mapboxMap.cameraState.pitch
        )
      }
    } else {
      camera = CameraOptions(
        center: nil,
        padding: padding,
        anchor: nil,
        zoom: zoom,
        bearing: heading,
        pitch: pitch
      )
    }

    guard let camera = camera else {
      return nil
    }

    var duration: TimeInterval?
    if let d = stop["duration"] as? Double {
      duration = toSeconds(d)
    }
    
    var mode: CameraMode = .flight
    if let m = stop["mode"] as? NSNumber, let m = CameraMode(rawValue: m.intValue) {
      mode = m
    }

    return CameraUpdateItem(
      camera: camera,
      mode: mode,
      duration: duration
    )
  }
  
  func _updateCamera() {
    if let _ = map {
      self._updateCameraFromJavascript()
    }
  }
  
  func _setInitialCamera() {
    guard let stop = self.defaultStop, let map = map else {
      return
    }
    
    if var updateItem = toUpdateItem(stop: stop) {
      updateItem.mode = .none
      updateItem.duration = 0
      updateItem.execute(map: map, cameraAnimator: &cameraAnimator)
    }
  }
  
  func initialLayout() {
    _setInitialCamera()
    _updateCamera()
  }
  
  public override func addToMap(_ map: RNMBXMapView, mapView: MapView, style: Style) {
    super.addToMap(map, mapView: mapView, style: style)
    map.reactCamera = self
  }

  public override func removeFromMap(_ map: RNMBXMapView, mapView: MapView, reason: RemovalReason) -> Bool {
    if (reason == .StyleChange) {
      return false
    }

    mapView.viewport.removeStatusObserver(self)
    return super.removeFromMap(map, mapView: mapView, reason: reason)
  }

  @objc public func moveBy(x: Double, y: Double, animationMode: Double, animationDuration: Double, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    withMapView { mapView in
      let contentFrame = mapView.bounds.inset(by: mapView.safeAreaInsets)
      let centerPoint = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
      let endCameraPoint = CGPoint(x: centerPoint.x + x, y: centerPoint.y + y)
      let cameraOptions = mapView.mapboxMap.dragCameraOptions(from: centerPoint, to: endCameraPoint)
      
      let duration = animationDuration / 1000

      if (duration == 0.0) {
        mapView.mapboxMap.setCamera(to: cameraOptions)
        resolve(nil)
        return
      }
        
      var curve: UIView.AnimationCurve = .linear
      if let m = CameraMode(rawValue: Int(animationMode)) {
          curve = m == CameraMode.ease ? .easeInOut : .linear
      }

      mapView.camera.ease(to: cameraOptions, duration: duration, curve: curve, completion: { _ in resolve(nil) })
    }
  }
    
  @objc public func scaleBy(
    x: Double,
    y: Double,
    scaleFactor: Double,
    animationMode: Double,
    animationDuration: Double,
    resolve: @escaping RCTPromiseResolveBlock,
    reject: @escaping RCTPromiseRejectBlock
  ) {
    withMapView { mapView in
      let currentZoom = mapView.cameraState.zoom
      let newZoom = currentZoom + log2(scaleFactor)
      let anchor = CGPoint(x: x, y: y)
      let cameraOptions = CameraOptions(anchor: anchor, zoom: newZoom)
      let duration = animationDuration / 1000
        
      if (duration == 0.0) {
        mapView.mapboxMap.setCamera(to: cameraOptions)
        resolve(nil)
        return
      }
        
      var curve: UIView.AnimationCurve = .linear
      if let m = CameraMode(rawValue: Int(animationMode)) {
          curve = m == CameraMode.ease ? .easeInOut : .linear
      }

      mapView.camera.ease(to: cameraOptions, duration: duration, curve: curve) { _ in
        resolve(nil)
      }
    }
  }
}

// MARK: - ViewportStatusObserver

extension RNMBXCamera : ViewportStatusObserver {
  func toDict(_ status: ViewportStatus) -> [String: Any] {
    switch (status) {
    case .idle:
      return ["state":"idle"]
    case .state(let state):
      return ["state":String(describing: type(of: state))]
    case .transition(let transition, toState: let toState):
      return [
        "transition": String(describing: type(of: transition)),
        "state":String(describing: type(of: toState))
      ]
    }
  }

  func toString(_ reason: ViewportStatusChangeReason) -> String {
    if reason == .idleRequested {
      return "idleRequested"
    } else if reason == .transitionFailed {
      return "transitionFailed"
    } else if reason == .transitionStarted {
      return "transitionStarted"
    } else if reason == .transitionSucceeded {
      return "transitionSucceeded"
    } else if reason == .userInteraction {
      return "userInteraction"
    } else {
      return "unkown \(reason)"
    }
  }

  public func viewportStatusDidChange(from fromStatus: ViewportStatus,
                               to toStatus: ViewportStatus,
                               reason: ViewportStatusChangeReason)
  {

  }
}

private func toSeconds(_ ms: Double) -> TimeInterval {
  return ms * 0.001
}
