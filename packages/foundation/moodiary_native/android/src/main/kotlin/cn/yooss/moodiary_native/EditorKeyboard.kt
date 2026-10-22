package cn.yooss.moodiary_native

import android.app.Activity
import android.os.Build
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowInsets
import android.view.inputmethod.InputMethodManager
import android.webkit.WebView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsAnimationCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import kotlin.math.abs
import kotlin.math.max

class EditorKeyboard(private val binding: FlutterPlugin.FlutterPluginBinding) : EditorKeyboardApi {
    private data class State(val visible: Boolean, val height: Double, val floating: Boolean)

    var activity: Activity? = null
        set(value) {
            field = value
            refresh()
        }

    private var webView: WebView? = null
    private var sink: PigeonEventSink<KeyboardEvent>? = null
    private var decor: View? = null
    private var observer: ViewTreeObserver? = null
    private val running = mutableSetOf<WindowInsetsAnimationCompat>()
    private var lastInsets: WindowInsets? = null
    private var last = State(false, 0.0, false)

    val events = object : KeyboardEventsStreamHandler() {
        override fun onListen(p0: Any?, sink: PigeonEventSink<KeyboardEvent>) {
            this@EditorKeyboard.sink = sink
            refresh()
        }

        override fun onCancel(p0: Any?) {
            this@EditorKeyboard.sink = null
            refresh()
        }
    }

    override fun attach(webViewId: Long) {
        webView = WebViewFlutterAndroidExternalApi.getWebView(binding, webViewId)
            ?: throw FlutterError("no-webview", "No WebView with identifier $webViewId", null)
        refresh()
    }

    override fun detach() {
        webView = null
        refresh()
    }

    fun dispose() {
        webView = null
        sink = null
        activity = null
    }

    override fun setKeyboardSuppressed(suppressed: Boolean): Boolean {
        val view = webView ?: return false
        // JS blur 后 WebView 仍有安卓焦点，要靠 onCheckIsTextEditor 看 DOM 焦点；不能 requestFocus，会抢 Flutter 输入框
        if (!view.hasWindowFocus() || !view.hasFocus() || !view.onCheckIsTextEditor()) return false
        val imm = (activity ?: view.context).getSystemService(InputMethodManager::class.java)
            ?: return false
        if (suppressed) {
            if (!imm.isActive(view)) return false
            imm.hideSoftInputFromWindow(view.windowToken, 0)
        } else {
            if (!imm.showSoftInput(view, 0)) view.post { imm.showSoftInput(view, 0) }
        }
        return true
    }

    override fun focusWebView() {
        webView?.requestFocus()
    }

    private fun refresh() {
        val target = if (sink != null && webView != null) activity?.window?.decorView else null
        if (target === decor) return
        decor?.let(::uninstall)
        decor = target
        target?.let(::install)
    }

    private fun install(view: View) {
        running.clear()
        lastInsets = null
        last = State(false, 0.0, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ViewCompat.setWindowInsetsAnimationCallback(view, animationCallback)
        }
        observer = view.viewTreeObserver.also { it.addOnPreDrawListener(preDrawListener) }
        reconcile()
    }

    private fun uninstall(view: View) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ViewCompat.setWindowInsetsAnimationCallback(view, null)
        }
        (observer?.takeIf { it.isAlive } ?: view.viewTreeObserver)
            .removeOnPreDrawListener(preDrawListener)
        observer = null
        running.clear()
    }

    private val animationCallback =
        object : WindowInsetsAnimationCompat.Callback(
            WindowInsetsAnimationCompat.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE,
        ) {
            override fun onPrepare(animation: WindowInsetsAnimationCompat) {
                if (animation.isIme) running.add(animation)
            }

            override fun onStart(
                animation: WindowInsetsAnimationCompat,
                bounds: WindowInsetsAnimationCompat.BoundsCompat,
            ): WindowInsetsAnimationCompat.BoundsCompat {
                if (animation.isIme) {
                    current(bounds.upperBound.bottom)?.let { emit(it, animation.durationMillis, true) }
                }
                return bounds
            }

            override fun onProgress(
                insets: WindowInsetsCompat,
                runningAnimations: MutableList<WindowInsetsAnimationCompat>,
            ) = insets

            override fun onEnd(animation: WindowInsetsAnimationCompat) {
                if (!running.remove(animation) || running.isNotEmpty()) return
                val state = current(null) ?: return
                emit(state, animation.durationMillis, false)
                last = state
            }
        }

    private val preDrawListener = ViewTreeObserver.OnPreDrawListener {
        reconcile()
        true
    }

    private fun reconcile() {
        if (running.isNotEmpty()) return
        val raw = decor?.rootWindowInsets ?: return
        if (raw === lastInsets) return
        lastInsets = raw
        val state = current(null) ?: return
        if (state.visible == last.visible &&
            state.floating == last.floating &&
            abs(state.height - last.height) < 0.5
        ) {
            return
        }
        emit(state, 0, true)
        emit(state, 0, false)
        last = state
    }

    private fun current(fallbackImeBottom: Int?): State? {
        val view = decor ?: return null
        val insets = ViewCompat.getRootWindowInsets(view) ?: return null
        val visible = insets.isVisible(WindowInsetsCompat.Type.ime())
        if (!visible) return State(false, 0.0, false)
        var ime = insets.getInsets(WindowInsetsCompat.Type.ime()).bottom
        if (ime == 0 && fallbackImeBottom != null) ime = fallbackImeBottom
        val nav = insets.getInsets(WindowInsetsCompat.Type.navigationBars()).bottom
        val heightPx = max(0, ime - nav)
        // 与 iOS 同判据：低于窗口 20% 的是硬件键盘工具条、手写条之类
        val floating = heightPx < view.height * 0.2 || activity?.isInMultiWindowMode == true
        return State(true, heightPx / view.resources.displayMetrics.density.toDouble(), floating)
    }

    private fun emit(state: State, durationMs: Long, isStart: Boolean) {
        sink?.success(KeyboardEvent(state.visible, state.height, durationMs, isStart, state.floating))
    }

    private val WindowInsetsAnimationCompat.isIme
        get() = (typeMask and WindowInsetsCompat.Type.ime()) != 0
}
