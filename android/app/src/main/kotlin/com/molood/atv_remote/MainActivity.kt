package com.molood.atv_remote

import android.content.Context
import android.hardware.ConsumerIrManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.molood.atv_remote/ir"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                val ir = getSystemService(Context.CONSUMER_IR_SERVICE)
                        as? ConsumerIrManager
                when (call.method) {
                    "hasIrEmitter" -> result.success(ir?.hasIrEmitter() == true)
                    "transmitNec" -> {
                        if (ir == null || !ir.hasIrEmitter()) {
                            result.success(false); return@setMethodCallHandler
                        }
                        val address = call.argument<Int>("address") ?: 0
                        val command = call.argument<Int>("command") ?: 0
                        val carrier = call.argument<Int>("carrier") ?: 38000
                        try {
                            ir.transmit(carrier, necPattern(address, command))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("IR_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Builds an NEC IR burst pattern (microseconds) for the given 8-bit
    // address + command. NEC sends address, ~address, command, ~command LSB
    // first, framed by a 9ms/4.5ms leader and a final stop bit.
    private fun necPattern(address: Int, command: Int): IntArray {
        val pulses = ArrayList<Int>()
        pulses.add(9000); pulses.add(4500) // leader
        fun byteBits(b: Int) {
            for (i in 0 until 8) {
                pulses.add(560) // mark
                pulses.add(if ((b shr i) and 1 == 1) 1690 else 560) // space
            }
        }
        byteBits(address)
        byteBits(address.inv() and 0xFF)
        byteBits(command)
        byteBits(command.inv() and 0xFF)
        pulses.add(560) // stop bit
        return pulses.toIntArray()
    }
}
