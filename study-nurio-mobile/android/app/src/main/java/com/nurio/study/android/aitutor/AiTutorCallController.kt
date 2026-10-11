package com.nurio.study.android.aitutor

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import com.nurio.study.android.BuildConfig
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * Process-wide owner of the class-review call. The call screen and the foreground service only
 * observe it, so rotation, activity recreation, or backgrounding never creates or drops a call.
 * All methods must be called on the main thread.
 */
@SuppressLint("StaticFieldLeak") // Holds only the application context.
object AiTutorCallController {
    interface UiListener {
        fun onCallSnapshot(snapshot: AiTutorCallSnapshot)
    }

    private const val TICK_MILLIS = 1_000L

    private lateinit var appContext: Context
    private val mainHandler = Handler(Looper.getMainLooper())
    private val uiListeners = linkedSetOf<UiListener>()
    private var pendingReviewUrl: String? = null
    private var reviewRouter: ((String) -> Unit)? = null

    private val engine: AiTutorCallEngine by lazy {
        AiTutorCallEngine(
            api = AiTutorCallApi(
                transport = HttpUrlConnectionTransport(),
                cookieStore = WebViewCookieStore(),
                baseUrl = BuildConfig.BASE_URL
            ),
            roomFactory = { LiveKitAiTutorRoom(appContext) },
            backgroundExecutor = Executors.newCachedThreadPool { runnable ->
                Thread(runnable, "nurio-study-ai-tutor-call").apply { isDaemon = true }
            },
            mainExecutor = Executor { command -> mainHandler.post(command) }
        ).also { it.listener = EngineListener }
    }

    private val ticker = object : Runnable {
        override fun run() {
            engine.tick()
            if (engine.isActive) {
                notifyUi()
                mainHandler.postDelayed(this, TICK_MILLIS)
            }
        }
    }

    val isActive: Boolean
        get() = ::appContext.isInitialized && engine.isActive

    val snapshot: AiTutorCallSnapshot?
        get() = if (::appContext.isInitialized) engine.snapshot else null

    /** Starts a call; returns false when one is already active (duplicate `start`). */
    fun start(context: Context, request: AiTutorCallRequest): Boolean {
        appContext = context.applicationContext
        if (!engine.start(request)) return false

        AiTutorCallService.start(appContext)
        mainHandler.removeCallbacks(ticker)
        mainHandler.post(ticker)
        return true
    }

    /** Ends a session whose call could not begin (microphone denied) and opens its review. */
    fun endWithoutCall(context: Context, request: AiTutorCallRequest) {
        appContext = context.applicationContext
        engine.endWithoutCall(request)
    }

    fun toggleMute() = whenInitialized { engine.toggleMute() }

    fun retry() = whenInitialized { engine.retry() }

    fun end() = whenInitialized { engine.end() }

    fun refreshAudioRouting() = whenInitialized { engine.refreshAudioRouting() }

    fun addUiListener(listener: UiListener) {
        uiListeners += listener
        snapshot?.let(listener::onCallSnapshot)
    }

    fun removeUiListener(listener: UiListener) {
        uiListeners -= listener
    }

    /**
     * The visible Hotwire activity registers a router while resumed. A review URL produced while
     * no router is registered (call screen on top, app in background) waits here until one is.
     */
    fun setReviewRouter(router: ((String) -> Unit)?) {
        reviewRouter = router
        deliverPendingReview()
    }

    private fun deliverPendingReview() {
        val router = reviewRouter ?: return
        val url = pendingReviewUrl ?: return
        pendingReviewUrl = null
        router(url)
    }

    private fun notifyUi() {
        val current = snapshot ?: return
        uiListeners.toList().forEach { it.onCallSnapshot(current) }
    }

    private fun whenInitialized(action: () -> Unit) {
        if (::appContext.isInitialized) action()
    }

    private object EngineListener : AiTutorCallEngine.Listener {
        override fun onSnapshot(snapshot: AiTutorCallSnapshot) {
            uiListeners.toList().forEach { it.onCallSnapshot(snapshot) }
        }

        override fun onFinished(reviewUrl: String) {
            mainHandler.removeCallbacks(ticker)
            AiTutorCallService.stop(appContext)
            pendingReviewUrl = reviewUrl
            deliverPendingReview()
        }
    }
}

private class WebViewCookieStore : AiTutorCookieStore {
    override fun cookieHeader(url: String): String? = CookieManager.getInstance().getCookie(url)

    override fun save(url: String, setCookies: List<String>) {
        val cookieManager = CookieManager.getInstance()
        setCookies.forEach { cookie -> cookieManager.setCookie(url, cookie) }
        cookieManager.flush()
    }
}
