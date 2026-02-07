#include <WiFi.h>
#include <EEPROM.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// BLE UUIDs for "Smart Band"
#define SERVICE_UUID "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "abcdef01-1234-5678-1234-567890abcdef"

// Global Variables
String ssid = "";
String pass = "";

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Helper to read String from EEPROM
String readString(int add) {
  char data[100];  //Max 100 Bytes
  int len = 0;
  unsigned char k;

  // Read first byte
  k = EEPROM.read(add);

  // DEBUG: Print what we read
  // Serial.printf("DEBUG: ReadAddr %d Val %02X\n", add, k);

  // If uninitialized (0xFF from factory), treat as empty string
  if (k == 0xFF) return "";

  while (k != '\0' && len < 95)  //Safe margin < 100
  {
    k = EEPROM.read(add + len);
    if (k == 0xFF) break;  // If we hit uninitialized memory, stop
    data[len] = k;
    len++;
  }
  data[len] = '\0';
  return String(data);
}

// Helper to write String to EEPROM
void writeString(int add, String data) {
  int _size = data.length();
  int i;
  for (i = 0; i < _size; i++) {
    EEPROM.write(add + i, data[i]);
  }
  EEPROM.write(add + _size, '\0');  //Add termination null character for String Data
}

void connectToWiFi() {
  ssid = readString(0);
  pass = readString(100);

  // Clean strings (sometimes \0 issues occur)
  if (ssid.length() > 0) {
    Serial.print("Connecting to WiFi: ");
    Serial.println(ssid);
    Serial.print("Password: ");
    Serial.println(pass);

    WiFi.begin(ssid.c_str(), pass.c_str());

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(500);
      Serial.print(".");
      attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("");
      Serial.println("WiFi Connected!");
      Serial.print("IP Address: ");
      Serial.println(WiFi.localIP());
    } else {
      Serial.println("");
      Serial.println("WiFi Connection Failed.");
    }
  } else {
    Serial.println("No WiFi Credentials in EEPROM.");
  }
}

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Device Connected");
  };

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Device Disconnected");
  }
};

class MyCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) {
    String value = pCharacteristic->getValue();

    if (value.length() > 0) {
      // Handle WiFi Config
      if (value.startsWith("WIFI:")) {
        // value format: WIFI:SSID:PASS
        int firstColon = value.indexOf(':');
        int secondColon = value.indexOf(':', firstColon + 1);

        if (secondColon != -1) {
          String ssid = value.substring(firstColon + 1, secondColon);
          String pass = value.substring(secondColon + 1);

          Serial.println("--- NEW WIFI CREDENTIALS ---");
          Serial.print("SSID: ");
          Serial.println(ssid);
          Serial.print("PASS: ");
          Serial.println(pass);

          // Save to EEPROM
          writeString(0, ssid);
          writeString(100, pass);
          if (EEPROM.commit()) {
            Serial.println("Saved to EEPROM!");
            delay(500);  // Give flash time to settle
          } else {
            Serial.println("EEPROM Commit Failed!");
          }

          // Try connecting immediately
          connectToWiFi();
        }
      }
    }
  }
};

#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include "time.h"

// Firebase Data
unsigned long lastFetchTime = 0;
String lastAlertTime = ""; // Track last alert to prevent repeats in the same minute
const unsigned long FETCH_INTERVAL = 3000;  // Check every 3 seconds for responsiveness
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 19800;  // IST +5:30
const int daylightOffset_sec = 0;

void printLocalTime() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }
  Serial.println(&timeinfo, "%A, %B %d %Y %H:%M:%S");  // Debug print
}

void fetchSlotData() {
  if (WiFi.status() == WL_CONNECTED) {
    // 1. Sync Time if needed (first run or periodic)
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) {
      Serial.println("Synchronizing Time...");
      configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
      if (!getLocalTime(&timeinfo)) {
        Serial.println("Time Sync Failed. Retrying later.");
        return;
      }
    }

    // 2. Format Current Time to match Firebase: "08:00 AM" -> "%I:%M %p"
    char timeStr[12];
    strftime(timeStr, sizeof(timeStr), "%I:%M %p", &timeinfo);
    String currentTime = String(timeStr);

    // Serial.print("Current Time: "); Serial.println(currentTime);

    // 3. Fetch Data
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure();

    String url = "https://smart-pill-box-by-techiedo-default-rtdb.firebaseio.com/pill_slots.json";

    if (http.begin(client, url)) {
      int httpResponseCode = http.GET();

      if (httpResponseCode > 0) {
        String payload = http.getString();

        // 4. Parse JSON (Simple String Manipulation)
        // Format: "time": "08:00 AM", "medicine": "Medicine Name"
        // We iterate through the payload string to find all occurrences
        Serial.println("currentTime");
        Serial.println(currentTime);
        Serial.println("\n--- MEDICINE SCHEDULE ---");

        int timeIndex = 0;
        bool alertTriggered = false;
        String alertMedicine = "";

        while (true) {
          timeIndex = payload.indexOf("\"time\":", timeIndex);
          if (timeIndex == -1) break;

          // Extract Time
          int valStart = payload.indexOf("\"", timeIndex + 7) + 1;  // +7 skips "time":"
          int valEnd = payload.indexOf("\"", valStart);
          String slotTime = payload.substring(valStart, valEnd);

          // Extract Medicine (search backwards or forwards locally, usually nearby)
          // Let's find the closing brace of this object to bound search?
          // Better: Find "medicine" relative to this time position.
          // In typical Firebase JSON, keys are unordered, but usually grouped in object.
          // We'll search for "medicine" closest to this time key.
          // Since we scan forward, let's find the object bounds.
          // Simplified: Just find "medicine" key after the current time key?
          // Dangerous if order varies.
          // Better Approach: Iterate objects by ID "1", "2" etc? No keys are dynamic.

          // Robust-ish String Search:
          // Find "medicine" key.
          // This is tricky without a parser.
          // Let's assume standard order or just print formatted string.

          // Actually, let's just search for "medicine" value nearby.
          // Simple approach for "Schedule List":
          // Print raw found times for now?
          // User wants "print time to take medicine".

          Serial.print("Slot Time: ");
          Serial.print(slotTime);

          // CHECK FOR MATCH
          if (slotTime == currentTime) {
            alertTriggered = true;
            // Try to find medicine name for this slot
            // We'll look for "medicine" BEFORE or AFTER.
            // Let's grab a chunk of string around the timeIndex to look for medicine.
            int objStart = payload.lastIndexOf("{", timeIndex);
            int objEnd = payload.indexOf("}", timeIndex);
            String objStr = payload.substring(objStart, objEnd);

            int medKey = objStr.indexOf("\"medicine\":");
            if (medKey != -1) {
              int mStart = objStr.indexOf("\"", medKey + 11) + 1;
              int mEnd = objStr.indexOf("\"", mStart);
              alertMedicine = objStr.substring(mStart, mEnd);
              Serial.print(" - " + alertMedicine);
            }
            Serial.println(" [MATCH!]");
          } else {
            Serial.println("");
          }

          timeIndex = valEnd;  // Continue search
        }
        Serial.println("-------------------------");

        // 5. Trigger Alert
        if (alertTriggered && currentTime != lastAlertTime) {
             Serial.println("\n*********************************");
             Serial.println("*    TIME TO TAKE MEDICINE!     *");
             Serial.print  ("*    "); Serial.print(alertMedicine); Serial.println("    *");
             Serial.println("*********************************\n");
             
             // Blink Sequence (HIGH-LOW-HIGH-LOW-HIGH-LOW) 1s each
             digitalWrite(10, 1); delay(1000);
             digitalWrite(10, 0); delay(1000);
             digitalWrite(10, 1); delay(1000);
             digitalWrite(10, 0); delay(1000);
             digitalWrite(10, 1); delay(1000);
             digitalWrite(10, 0);
             
             lastAlertTime = currentTime; // Prevent repeating for this minute
        }

      } else {
        Serial.print("Error code: ");
        Serial.println(httpResponseCode);
      }
      http.end();
    } else {
      Serial.println("[HTTP] Unable to connect");
    }
  }
}
void fetchSensorData() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure();

    String url = "https://smart-pill-box-by-techiedo-default-rtdb.firebaseio.com/sensor.json";

    if (http.begin(client, url)) {
      int httpResponseCode = http.GET();

      if (httpResponseCode > 0) {
        String payload = http.getString();
        // Serial.println("Sensor Payload: " + payload);

        // Parse avg_bpm
        // Payload format: {"avg_bpm": 120, "bpm": ...}
        int keyIndex = payload.indexOf("\"avg_bpm\":");
        if (keyIndex != -1) {
          int valStart = payload.indexOf(":", keyIndex) + 1;
          int valEnd = payload.indexOf(",", valStart);
          if (valEnd == -1) valEnd = payload.indexOf("}", valStart);  // Handle last item case

          String bpmStr = payload.substring(valStart, valEnd);
          int avgBpm = bpmStr.toInt();

          Serial.print("Avg BPM: ");
          Serial.println(avgBpm);

          // CHECK ABNORMALITY
          // Normal Range: 60-100?
          // Alert if < 50 or > 100 (excluding 0)
          if (avgBpm > 0 && (avgBpm < 50 || avgBpm > 100)) {
            Serial.println("\n*********************************");
            Serial.println("*    HEART RATE ALERT! 💓       *");
            Serial.print("*    BPM: ");
            Serial.print(avgBpm);
            Serial.println(" (Abnormal)      *");
            Serial.println("*********************************\n");
            digitalWrite(10, 1);
            delay(1000);  // Alert Duration
            digitalWrite(10, 0);
            delay(1000);
            digitalWrite(10, 1);
            delay(1000);  // Alert Duration
            digitalWrite(10, 0);
            delay(1000);
            digitalWrite(10, 1);
            delay(1000);  // Alert Duration
            digitalWrite(10, 0);
              
          }
        }
      } else {
        Serial.print("Sensor HTTP Error: ");
        Serial.println(httpResponseCode);
      }
      http.end();
    }
  }
}


void setup() {
  Serial.begin(115200);
  Serial.println("Starting BLE Watch...");
  pinMode(10, OUTPUT);
  digitalWrite(10, 0);
  EEPROM.begin(512);

  BLEDevice::init("Smart Pill Band");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_INDICATE);

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);  // ENABLE SCAN RESPONSE for Name Visibility
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();
  Serial.println("Waiting a client connection to notify...");

  // Try connecting on startup
  connectToWiFi();

  // Init Time
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
}

void loop() {

  // BLE Logic
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("start advertising");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    // do stuff here on connecting
    oldDeviceConnected = deviceConnected;
  }

  // Firebase Fetch Logic
  if (WiFi.status() == WL_CONNECTED) {
    unsigned long currentMillis = millis();
    if (currentMillis - lastFetchTime >= FETCH_INTERVAL) {
      lastFetchTime = currentMillis;
      fetchSlotData();
      fetchSensorData();  // Also fetch sensor data
    }
  }

  delay(100);
}
