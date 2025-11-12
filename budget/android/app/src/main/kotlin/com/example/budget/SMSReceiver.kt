package com.budget.tracker_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.telephony.SmsMessage
import android.util.Log
import io.flutter.plugin.common.EventChannel

class SMSReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SMSReceiver"
        var eventSink: EventChannel.EventSink? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle: Bundle? = intent.extras
            if (bundle != null) {
                try {
                    val pdus = bundle.get("pdus") as Array<*>
                    val messages = arrayOfNulls<SmsMessage>(pdus.size)

                    for (i in pdus.indices) {
                        messages[i] = SmsMessage.createFromPdu(pdus[i] as ByteArray)
                    }

                    if (messages.isNotEmpty()) {
                        val sender = messages[0]?.originatingAddress ?: ""
                        val messageBody = StringBuilder()
                        val timestamp = messages[0]?.timestampMillis ?: System.currentTimeMillis()

                        for (message in messages) {
                            message?.messageBody?.let { messageBody.append(it) }
                        }

                        Log.d(TAG, "SMS received from: $sender")
                        Log.d(TAG, "Message: $messageBody")

                        // Send SMS data to Flutter
                        val smsData = HashMap<String, Any>()
                        smsData["sender"] = sender
                        smsData["body"] = messageBody.toString()
                        smsData["timestamp"] = timestamp

                        eventSink?.success(smsData)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing SMS: ${e.message}")
                    e.printStackTrace()
                }
            }
        }
    }
}
