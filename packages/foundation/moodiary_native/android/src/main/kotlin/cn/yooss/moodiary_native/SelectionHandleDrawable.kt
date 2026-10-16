package cn.yooss.moodiary_native

import android.content.res.Resources
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import org.xmlpull.v1.XmlPullParser

// WebView 每次显示手柄都从 Activity 主题重新取图；不给 ConstantState 就不会被缓存，所以总能拿到当前主色
open class SelectionHandleDrawable(private val attr: Int) : Drawable() {
    companion object : SelectionHandleApi {
        @Volatile
        private var color: Int? = null

        override fun setColor(argb: Long) {
            color = argb.toInt()
        }
    }

    private lateinit var handle: Drawable

    override fun inflate(r: Resources, parser: XmlPullParser, attrs: AttributeSet, theme: Resources.Theme?) {
        val platform = r.newTheme().apply { applyStyle(android.R.style.Theme_DeviceDefault, true) }
        val a = platform.obtainStyledAttributes(intArrayOf(attr))
        handle = a.getDrawable(0)!!.mutate()
        a.recycle()
        color?.let(handle::setTint)
    }

    override fun draw(canvas: Canvas) = handle.draw(canvas)

    override fun onBoundsChange(bounds: Rect) {
        handle.bounds = bounds
    }

    override fun getIntrinsicWidth() = handle.intrinsicWidth

    override fun getIntrinsicHeight() = handle.intrinsicHeight

    override fun setAlpha(alpha: Int) {
        handle.alpha = alpha
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        handle.colorFilter = colorFilter
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
}

class SelectionHandleLeftDrawable : SelectionHandleDrawable(android.R.attr.textSelectHandleLeft)

class SelectionHandleRightDrawable : SelectionHandleDrawable(android.R.attr.textSelectHandleRight)

class SelectionHandleCenterDrawable : SelectionHandleDrawable(android.R.attr.textSelectHandle)
