package cn.yooss.moodiary_native

internal class ReminderTapDelivery {
    private var pending = false
    private var listener: (() -> Unit)? = null

    fun receive(id: String, lastConsumed: String?, persist: (String) -> Boolean) {
        if (id == lastConsumed || !persist(id)) return
        val deliver = listener
        if (deliver == null) pending = true else deliver()
    }

    fun start(deliver: () -> Unit): Boolean {
        listener = deliver
        return pending.also { pending = false }
    }

    fun detach(deliver: () -> Unit) {
        if (listener === deliver) listener = null
    }
}
