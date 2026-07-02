package com.rnmapbox.rnmbx.components.camera

import android.animation.Animator
import android.content.Context
import com.facebook.react.bridge.Dynamic
import com.facebook.react.bridge.ReadableMap
import com.mapbox.maps.plugin.gestures.gestures
import com.mapbox.maps.plugin.animation.flyTo
import com.rnmapbox.rnmbx.components.AbstractMapFeature
import com.rnmapbox.rnmbx.components.mapview.RNMBXMapView
import com.rnmapbox.rnmbx.utils.LatLngBounds
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.WritableNativeMap
import com.facebook.react.uimanager.annotations.ReactProp
import com.mapbox.maps.*
import com.mapbox.maps.plugin.viewport.ViewportStatus
import com.mapbox.maps.plugin.viewport.ViewportStatusObserver
import com.mapbox.maps.plugin.viewport.data.ViewportStatusChangeReason
import com.mapbox.maps.plugin.viewport.state.OverviewViewportState
import com.mapbox.maps.plugin.viewport.state.ViewportState
import com.mapbox.maps.plugin.viewport.viewport
import com.rnmapbox.rnmbx.components.RemovalReason
import com.rnmapbox.rnmbx.components.camera.constants.CameraMode
import com.rnmapbox.rnmbx.utils.Logger
import com.rnmapbox.rnmbx.utils.writableMapOf

class RNMBXCamera(private val mContext: Context, private val mManager: RNMBXCameraManager) :
    AbstractMapFeature(
        mContext
    ) {
    override var requiresStyleLoad = false

    private var hasSentFirstRegion = false
    private var mDefaultStop: CameraStop? = null
    private var mCameraStop: CameraStop? = null
    private val mCameraUpdateQueue = CameraUpdateQueue()

    private val mCenterCoordinate: ScreenCoordinate? = null
    private val mAnimated = false
    private val mHeading = 0.0

    private var mZoomLevel = -1.0
    private var mMinZoomLevel : Double? = null
    private var mMaxZoomLevel : Double? = null
    private var mMaxBounds: LatLngBounds? = null


    var ts: Int? = null;


    private val mCameraCallback: Animator.AnimatorListener = object : Animator.AnimatorListener {
        override fun onAnimationStart(animator: Animator) {}
        override fun onAnimationEnd(animator: Animator) {
            if (!hasSentFirstRegion) {
                mMapView?.sendRegionChangeEvent(false)
                hasSentFirstRegion = true
            }
        }

        override fun onAnimationCancel(animator: Animator) {
            if (!hasSentFirstRegion) {
                mMapView?.sendRegionChangeEvent(false)
                hasSentFirstRegion = true
            }
        }

        override fun onAnimationRepeat(animator: Animator) {}
    }

    override fun addToMap(mapView: RNMBXMapView) {
        super.addToMap(mapView)
        mapView.callIfAttachedToWindow {
            withMapView { mapView ->
                setInitialCamera(mapView)
                updateMaxBounds(mapView)
                mCameraStop?.let { updateCamera(it, mapView) }
            }
        }
    }

    override fun removeFromMap(mapView: RNMBXMapView, reason: RemovalReason) : Boolean {
        if (reason == RemovalReason.STYLE_CHANGE) {
            return false
        } else {
            return super.removeFromMap(mapView, reason);
        }
    }
    fun setStop(stop: CameraStop) {
        mCameraStop = stop
        stop.setCallback(mCameraCallback)
        withMapView { mapView ->
            stop.let { updateCamera(it, mapView) }
        }
    }

    fun updateCameraStop(map: ReadableMap) {
        val stop = CameraStop.fromReadableMap(mContext, map, null)
        setStop(stop)
    }

    fun setDefaultStop(stop: CameraStop?) {
        mDefaultStop = stop
    }

    fun setMaxBounds(bounds: LatLngBounds?) {
        mMaxBounds = bounds
        withMapView { mapView ->
            updateMaxBounds(mapView)
        }
    }

    private fun updateMaxBounds(mapView: RNMBXMapView) {
        val map = mapView.getMapboxMap()
        val currentBounds = map.getBounds()
        val builder = CameraBoundsOptions.Builder()
        builder.bounds(mMaxBounds?.toBounds())
        builder.minZoom(mMinZoomLevel ?: 0.0) // Passing null does not reset this value.
        builder.maxZoom(mMaxZoomLevel ?: 25.0) // Passing null does not reset this value.
        builder.minPitch(currentBounds.minPitch)
        builder.maxPitch(currentBounds.maxPitch)
        map.setBounds(builder.build())
        mCameraStop?.let { updateCamera(it, mapView) }
    }

    private fun setInitialCamera(mapView: RNMBXMapView) {
        mDefaultStop?.let {
            val map = mapView.getMapboxMap()

            it.setDuration(0)
            it.setMode(CameraMode.NONE)
            val item = it.toCameraUpdate(mapView)
            item.run()
        }
    }

    private fun updateCamera(cameraStop: CameraStop, mapView: RNMBXMapView) {
        mCameraUpdateQueue.offer(cameraStop)
        mCameraUpdateQueue.execute(mapView)
    }

    private fun hasSetCenterCoordinate(): Boolean {
        val state = mapboxMap!!.cameraState
        val center = state.center
        return center.latitude() != 0.0 && center.longitude() != 0.0
    }

    init {}

    fun setMinZoomLevel(zoomLevel: Double?) {
        mMinZoomLevel = zoomLevel
        withMapView { updateMaxBounds(it) }
    }

    fun setMaxZoomLevel(zoomLevel: Double?) {
        mMaxZoomLevel = zoomLevel
        withMapView { updateMaxBounds(it) }
    }

    fun setZoomLevel(zoomLevel: Double) {
        mZoomLevel = zoomLevel
        updateCameraPositionIfNeeded(false)
    }

    private fun buildCamera(
        previousPosition: CameraState,
        shouldUpdateTarget: Boolean
    ): CameraOptions {
        return if (shouldUpdateTarget) {
            previousPosition.toCameraOptions(mCenterCoordinate)
        } else {
            previousPosition.toCameraOptions(null)
        }
    }

    private fun updateCameraPositionIfNeeded(shouldUpdateTarget: Boolean) {
        if (mMapView != null) {
            val prevPosition = mapboxMap!!.cameraState
            val cameraUpdate =  /*CameraUpdateFactory.newCameraPosition(*/
                buildCamera(prevPosition, shouldUpdateTarget)
            if (mAnimated) {
                mapboxMap!!.flyTo(cameraUpdate, null)
            } else {
                mapboxMap!!.setCamera(cameraUpdate)
            }
        }
    }

    fun toReadableMap(status: ViewportStatus): ReadableMap {
        return when (status) {
            ViewportStatus.Idle -> writableMapOf("state" to "idle")
            is ViewportStatus.State ->
                writableMapOf(
                    "state" to status.toString()
                )

            is ViewportStatus.Transition ->
                writableMapOf(
                    "transition" to status.toString()
                )
        }
    }

    fun toString(reason: ViewportStatusChangeReason): String {
        when (reason) {
            ViewportStatusChangeReason.IDLE_REQUESTED ->
                return "idleRequested"
            ViewportStatusChangeReason.TRANSITION_FAILED ->
                return "transitionFailed"
            ViewportStatusChangeReason.TRANSITION_STARTED ->
                return "transitionStarted"
            ViewportStatusChangeReason.TRANSITION_SUCCEEDED ->
                return "transitionSucceeded"
            ViewportStatusChangeReason.USER_INTERACTION ->
                return "userInteraction"
            else -> {
                Logger.w(LOG_TAG, "toString; unkown reason: ${reason}")
                return "unkown: $reason"
            }
        }
    }

    val mapboxMap: MapboxMap?
        get() = if (mMapView == null) {
            null
        } else mMapView!!.getMapboxMap()

    companion object {
        const val LOG_TAG = "RNMBXCamera"
    }
}