#include "PillFCM.h"
#include <mbedtls/base64.h>

// WE WILL USE A SIMPLER APPROACH: 
// Since full JWT signing on basic ESP32 code is huge and complex for a beginner,
// and the user provided credentials. 
// However, the "Service Account" method MUST sign a JWT.
// For this specific turn, I will implement a placeholder "sendNotification" 
// that connects to WiFi. authenticating directly to FCM HTTP v1 from scratch 
// is 500 lines of crypto code. 
//
// STRATEGY: Use a hardcoded "Legacy-like" approach if possible, OR
// rely on the fact that Google sometimes allows API Keys for simple projects?
// NO, V1 is strict.
//
// AUTO-CORRECTION: The only "Easy" way for a user without library management
// is to use a pre-made library. I will write the code assuming they CAN install
// "FirebaseClient" or similar. But I can't guarantee they will.
//
// ALTERNATIVE: Use an Open Proxy? No.
//
// I will implement the connection logic. The actual "Send" might fail without
// the complex JWT signer. I will structure it so the user can add the signer later
// or I will try to include a minimal one.

PillFCM::PillFCM() {}

void PillFCM::begin(const char* ssid, const char* password) {
    _ssid = ssid;
    _password = password;
    
    WiFi.mode(WIFI_STA);
    WiFi.begin(_ssid, _password);
    Serial.print("Connecting to WiFi");
    
    int retries = 0;
    while (WiFi.status() != WL_CONNECTED && retries < 20) {
        delay(500);
        Serial.print(".");
        retries++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nWiFi Connected!");
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        _wifiConnected = true;
    } else {
        Serial.println("\nWiFi Failed to connect.");
        _wifiConnected = false;
    }
}

void PillFCM::loop() {
    if (_wifiConnected && WiFi.status() != WL_CONNECTED) {
        Serial.println("WiFi Lost. Reconnecting...");
        WiFi.disconnect();
        WiFi.begin(_ssid, _password);
        _wifiConnected = false;
    }
    
    if (!_wifiConnected && WiFi.status() == WL_CONNECTED) {
         Serial.println("WiFi Reconnected.");
         _wifiConnected = true;
    }
}

// NOTE: Implementing full RSA-SHA256 JWT signing from scratch here 
// is extremely risky and large.
// I will provide a method that ATTEMPTS to send, but allows for 
// easy integration of a library if this fails.
// 
// For now, I will use a dummy "Send" that prints what SHOULD happen,
// because implementing the full JWT stack in one file is dangerously complex.

bool PillFCM::sendNotification(String title, String body) {
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("FCM Skip: WiFi not connected");
        return false;
    }

    HTTPClient http;
    
    // User Provided Script URL
    String scriptUrl = "https://script.google.com/macros/s/AKfycbzXiDNcMpn0yc_aRYz1zM4Kaa15ijjFuhog6Yz-lETuBkYkjJzT-HDGPFFswQDjl_FJ-w/exec";
    
    Serial.println("FCM: Sending to Script...");
    
    // Begin connection (Secure 443)
    http.begin(scriptUrl);
    http.addHeader("Content-Type", "application/json");
    
    // Google Scripts redirect (302) to a content server
    // We MUST follow redirects for this to work
    http.setFollowRedirects(HTTPC_FORCE_FOLLOW_REDIRECTS);
    
    // Construct JSON Payload
    // Format: {"title":"...", "body":"...", "topic":"pillbox_users"}
    String payload = "{";
    payload += "\"title\":\"" + title + "\",";
    payload += "\"body\":\"" + body + "\",";
    payload += "\"topic\":\"pillbox_users\""; // Must match App subscription
    payload += "}";
    
    int httpResponseCode = http.POST(payload);
    
    if (httpResponseCode > 0) {
        String response = http.getString();
        Serial.print("FCM Success: ");
        Serial.println(httpResponseCode);
        Serial.println(response);
        http.end();
        return true;
    } else {
        Serial.print("FCM Error: ");
        Serial.println(httpResponseCode);
        http.end();
        return false;
    }
}
