#ifndef PILLFCM_H
#define PILLFCM_H

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

class PillFCM {
public:
    PillFCM();
    void begin(const char* ssid, const char* password);
    void loop(); // Handle WiFi maintenance
    
    // Core Function
    bool sendNotification(String title, String body);

private:
    const char* _ssid;
    const char* _password;
    bool _wifiConnected = false;
    
    // JWT Generation Helpers
    String _getJwt();
    String _base64UrlEncode(String input);
};

#endif
