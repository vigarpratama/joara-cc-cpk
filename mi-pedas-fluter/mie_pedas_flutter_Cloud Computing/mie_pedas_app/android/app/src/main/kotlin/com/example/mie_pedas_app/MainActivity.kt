package com.example.mie_pedas_app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "mie_pedas_app/notification"
    private val PRINTER_CHANNEL = "mie_pedas_app/printer"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ===== NOTIFICATION CHANNEL =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playSound" -> {
                        try {
                            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                            RingtoneManager.getRingtone(applicationContext, uri)?.play()
                            result.success(true)
                        } catch (e: Exception) { result.error("ERROR", e.message, null) }
                    }
                    "playAlarm" -> {
                        try {
                            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            RingtoneManager.getRingtone(applicationContext, uri)?.play()
                            result.success(true)
                        } catch (e: Exception) { result.error("ERROR", e.message, null) }
                    }
                    else -> result.notImplemented()
                }
            }

        // ===== PRINTER CHANNEL =====
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPairedDevices" -> {
                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            if (adapter == null) { result.success(emptyList<Map<String, String>>()); return@setMethodCallHandler }
                            val devices = adapter.bondedDevices?.map { device ->
                                mapOf("name" to (device.name ?: "Unknown"), "address" to device.address)
                            } ?: emptyList()
                            result.success(devices)
                        } catch (e: Exception) { result.error("ERROR", e.message, null) }
                    }
                    "connectAndPrint" -> {
                        val address = call.argument<String>("address") ?: ""
                        val text = call.argument<String>("text") ?: ""
                        Thread {
                            try {
                                val adapter = BluetoothAdapter.getDefaultAdapter()
                                val device: BluetoothDevice = adapter.getRemoteDevice(address)
                                adapter.cancelDiscovery()
                                bluetoothSocket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                                bluetoothSocket?.connect()
                                outputStream = bluetoothSocket?.outputStream

                                // Kirim teks ke printer
                                val bytes = text.toByteArray(Charsets.UTF_8)
                                outputStream?.write(bytes)
                                outputStream?.flush()

                                // Feed paper
                                outputStream?.write(byteArrayOf(0x0A, 0x0A, 0x0A))
                                outputStream?.flush()

                                bluetoothSocket?.close()
                                runOnUiThread { result.success(true) }
                            } catch (e: IOException) {
                                try { bluetoothSocket?.close() } catch (_: IOException) {}
                                runOnUiThread { result.error("PRINT_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
