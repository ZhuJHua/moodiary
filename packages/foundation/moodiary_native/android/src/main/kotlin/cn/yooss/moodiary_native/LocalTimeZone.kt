package cn.yooss.moodiary_native

class LocalTimeZone : LocalTimeZoneApi {
    override fun localTimeZoneId(): String = java.util.TimeZone.getDefault().id
}
