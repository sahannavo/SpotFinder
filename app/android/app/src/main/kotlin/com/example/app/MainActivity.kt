package com.example.app

import android.content.Context
import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.PhoneStateListener
import android.telephony.SignalStrength
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.app/telephony_methods"
    private val EVENT_CHANNEL = "com.example.app/telephony_events"

    private var telephonyManager: TelephonyManager? = null
    private var eventSink: EventChannel.EventSink? = null

    // For Android 12 (API 31)+
    private var telephonyCallback: TelephonyCallback? = null

    // For Android < 12
    private var phoneStateListener: PhoneStateListener? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        // MethodChannel for one-shot reads
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSignalStrength" -> {
                    val dbm = readCurrentSignalDbm()
                    result.success(dbm)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for real-time streaming
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startListeningSignalStrength()
                }

                override fun onCancel(arguments: Any?) {
                    stopListeningSignalStrength()
                    eventSink = null
                }
            }
        )
    }

    private fun readCurrentSignalDbm(): Int {
        try {
            val cellList: List<CellInfo>? = telephonyManager?.allCellInfo
            if (!cellList.isNullOrEmpty()) {
                for (info in cellList) {
                    if (info.isRegistered) {
                        return extractDbmFromCellInfo(info)
                    }
                }
                return extractDbmFromCellInfo(cellList[0])
            }
        } catch (_: SecurityException) {
            // Location permission not granted yet
        } catch (_: Exception) {}
        return -999
    }

    private fun extractDbmFromCellInfo(info: CellInfo): Int {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && info is CellInfoNr -> {
                (info.cellSignalStrength as? android.telephony.CellSignalStrengthNr)?.dbm ?: -999
            }
            info is CellInfoLte -> info.cellSignalStrength.dbm
            info is CellInfoWcdma -> info.cellSignalStrength.dbm
            info is CellInfoGsm -> info.cellSignalStrength.dbm
            else -> -999
        }
    }

    private fun startListeningSignalStrength() {
        val tm = telephonyManager ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            registerTelephonyCallback(tm)
        } else {
            registerLegacyListener(tm)
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun registerTelephonyCallback(tm: TelephonyManager) {
        val callback = object : TelephonyCallback(), TelephonyCallback.SignalStrengthsListener {
            override fun onSignalStrengthsChanged(signalStrength: SignalStrength) {
                val dbm = parseSignalStrength(signalStrength)
                eventSink?.success(dbm)
            }
        }
        telephonyCallback = callback
        try {
            tm.registerTelephonyCallback(mainExecutor, callback)
        } catch (_: SecurityException) {}
    }

    @Suppress("DEPRECATION")
    private fun registerLegacyListener(tm: TelephonyManager) {
        phoneStateListener = object : PhoneStateListener() {
            @Deprecated("Deprecated in Java")
            override fun onSignalStrengthsChanged(signalStrength: SignalStrength?) {
                if (signalStrength != null) {
                    val dbm = parseSignalStrength(signalStrength)
                    eventSink?.success(dbm)
                }
            }
        }
        try {
            tm.listen(phoneStateListener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
        } catch (_: SecurityException) {}
    }

    private fun stopListeningSignalStrength() {
        val tm = telephonyManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let {
                tm.unregisterTelephonyCallback(it)
                telephonyCallback = null
            }
        } else {
            phoneStateListener?.let {
                tm.listen(it, PhoneStateListener.LISTEN_NONE)
                phoneStateListener = null
            }
        }
    }

    private fun parseSignalStrength(signalStrength: SignalStrength): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            for (cellSignal in signalStrength.cellSignalStrengths) {
                val dbm = cellSignal.dbm
                if (dbm != CellInfo.UNAVAILABLE && dbm != Integer.MAX_VALUE && dbm < 0) {
                    return dbm
                }
            }
        }
        // Fallback for older versions
        val fallbackDbm = readCurrentSignalDbm()
        return if (fallbackDbm != -999) fallbackDbm else -85
    }
}
