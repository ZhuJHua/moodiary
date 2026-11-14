package cn.yooss.moodiary_native

import android.app.Activity
import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowInsets

// Root insets already hold the final IME height when its animation starts, so
// the first layout pass after a show or hide reports where the keyboard ends.
class KeyboardHeight : KeyboardHeightStreamHandler() {
    var activity: Activity? = null
        set(value) {
            field = value
            attach()
        }

    private var sink: PigeonEventSink<Double>? = null
    private var root: View? = null
    private var last: Double? = null
    private val frame = Rect()
    private val listener = ViewTreeObserver.OnGlobalLayoutListener { report() }

    override fun onListen(p0: Any?, sink: PigeonEventSink<Double>) {
        this.sink = sink
        last = null
        attach()
    }

    override fun onCancel(p0: Any?) {
        sink = null
        detach()
    }

    private fun attach() {
        detach()
        if (sink == null) return
        val view = activity?.window?.decorView?.rootView ?: return
        view.viewTreeObserver.addOnGlobalLayoutListener(listener)
        root = view
        report()
    }

    private fun detach() {
        root?.viewTreeObserver?.takeIf { it.isAlive }?.removeOnGlobalLayoutListener(listener)
        root = null
    }

    private fun report() {
        val view = root ?: return
        val windowHeight = view.height
        val ime = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            view.rootWindowInsets?.getInsets(WindowInsets.Type.ime())?.bottom ?: 0
        } else {
            view.getWindowVisibleDisplayFrame(frame)
            windowHeight - frame.bottom
        }
        // Below 15% of the window it is a nav bar or a floating / hardware keyboard.
        val height = if (ime > windowHeight * 0.15) {
            ime / view.resources.displayMetrics.density.toDouble()
        } else {
            0.0
        }
        if (height == last) return
        last = height
        sink?.success(height)
    }
}
