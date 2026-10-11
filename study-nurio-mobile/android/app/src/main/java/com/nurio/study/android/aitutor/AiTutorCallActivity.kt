package com.nurio.study.android.aitutor

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.updatePadding
import com.google.android.material.button.MaterialButton
import com.nurio.study.android.R
import java.util.Locale

/**
 * Full-screen class-review call. It only renders [AiTutorCallController] state and forwards
 * taps; it never creates a call, so recreation (rotation, process-visible restarts) is safe.
 *
 * Product rule: Back does not end the review — it sends the app to the background and the call
 * keeps running (ongoing notification). Only End, the deadline, or a lost connection ends it.
 */
class AiTutorCallActivity : AppCompatActivity(), AiTutorCallController.UiListener {
    private lateinit var topicView: TextView
    private lateinit var timerView: TextView
    private lateinit var statusView: TextView
    private lateinit var muteButton: MaterialButton
    private lateinit var endButton: MaterialButton
    private lateinit var retryButton: MaterialButton

    private val bluetoothPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) AiTutorCallController.refreshAudioRouting()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (AiTutorCallController.snapshot == null) {
            finish()
            return
        }

        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT)
        )
        setContentView(R.layout.activity_ai_tutor_call)
        applySystemBarInsets()
        topicView = findViewById(R.id.ai_tutor_call_topic)
        timerView = findViewById(R.id.ai_tutor_call_timer)
        statusView = findViewById(R.id.ai_tutor_call_status)
        muteButton = findViewById(R.id.ai_tutor_call_mute)
        endButton = findViewById(R.id.ai_tutor_call_end)
        retryButton = findViewById(R.id.ai_tutor_call_retry)

        muteButton.setOnClickListener { AiTutorCallController.toggleMute() }
        endButton.setOnClickListener { AiTutorCallController.end() }
        retryButton.setOnClickListener { AiTutorCallController.retry() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                moveTaskToBack(true)
            }
        })

        if (savedInstanceState == null) requestBluetoothPermissionIfHeadsetConnected()
    }

    override fun onStart() {
        super.onStart()
        if (::statusView.isInitialized) AiTutorCallController.addUiListener(this)
    }

    override fun onStop() {
        AiTutorCallController.removeUiListener(this)
        super.onStop()
    }

    override fun onCallSnapshot(snapshot: AiTutorCallSnapshot) {
        if (snapshot.status == AiTutorCallStatus.ENDED) {
            finish()
            return
        }

        topicView.text = snapshot.topic
        topicView.visibility = if (snapshot.topic.isBlank()) View.GONE else View.VISIBLE
        statusView.setText(statusText(snapshot.status))
        timerView.text = snapshot.deadlineAtMillis
            ?.let { AiTutorCountdown.format(it - System.currentTimeMillis()) }
            ?: getString(R.string.ai_tutor_call_timer_placeholder)

        muteButton.isEnabled = snapshot.status.isConnected
        muteButton.setText(if (snapshot.muted) R.string.ai_tutor_call_unmute else R.string.ai_tutor_call_mute)
        endButton.isEnabled = snapshot.status != AiTutorCallStatus.ENDING
        retryButton.visibility =
            if (snapshot.status == AiTutorCallStatus.FAILED) View.VISIBLE else View.GONE
    }

    private fun statusText(status: AiTutorCallStatus): Int = when (status) {
        AiTutorCallStatus.PROVISIONING -> R.string.ai_tutor_call_status_provisioning
        AiTutorCallStatus.CONNECTING -> R.string.ai_tutor_call_status_connecting
        AiTutorCallStatus.TUTOR_JOINING -> R.string.ai_tutor_call_status_tutor_joining
        AiTutorCallStatus.LIVE -> R.string.ai_tutor_call_status_live
        AiTutorCallStatus.RECONNECTING -> R.string.ai_tutor_call_status_reconnecting
        AiTutorCallStatus.FAILED -> R.string.ai_tutor_call_status_failed
        AiTutorCallStatus.ENDING -> R.string.ai_tutor_call_status_ending
        AiTutorCallStatus.ENDED -> R.string.ai_tutor_call_status_ending
    }

    private fun applySystemBarInsets() {
        val root = findViewById<View>(R.id.ai_tutor_call_root)
        val initialTop = root.paddingTop
        val initialBottom = root.paddingBottom
        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.updatePadding(top = initialTop + bars.top, bottom = initialBottom + bars.bottom)
            insets
        }
    }

    /**
     * Android 12+ hides Bluetooth headsets from call audio routing until BLUETOOTH_CONNECT is
     * granted. Ask only when a Bluetooth audio device is actually connected.
     */
    private fun requestBluetoothPermissionIfHeadsetConnected() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val audioManager = getSystemService(AudioManager::class.java) ?: return
        val bluetoothConnected = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any {
            it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO || it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
        }
        if (bluetoothConnected) {
            bluetoothPermissionLauncher.launch(Manifest.permission.BLUETOOTH_CONNECT)
        }
    }

    companion object {
        fun intent(context: Context): Intent =
            Intent(context, AiTutorCallActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)

        fun open(context: Context) {
            val intent = intent(context)
            if (context !is android.app.Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        }
    }
}

internal object AiTutorCountdown {
    fun format(remainingMillis: Long): String {
        val totalSeconds = (remainingMillis.coerceAtLeast(0) + 999) / 1_000
        return String.format(Locale.ROOT, "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
