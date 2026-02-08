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

    // 2. Format Current Time: "08:00 AM"
    char timeStr[12];
    strftime(timeStr, sizeof(timeStr), "%I:%M %p", &timeinfo);
    String currentTime = String(timeStr);
    
    // 2b. Format Current Date: "Jan 8"
    char dateStr[12];
    strftime(dateStr, sizeof(dateStr), "%b %e", &timeinfo);
    String currentDate = String(dateStr);
    // Fix "Jan  8" -> "Jan 8"
    currentDate.replace("  ", " ");
    currentDate.trim();

    Serial.print("Current: "); Serial.print(currentTime); Serial.print(" | "); Serial.println(currentDate);

    // 3. Fetch Data
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure();

    String url = "https://smart-pill-box-by-techiedo-default-rtdb.firebaseio.com/pill_slots.json";

    if (http.begin(client, url)) {
      int httpResponseCode = http.GET();

      if (httpResponseCode > 0) {
        String payload = http.getString();

        Serial.println("\n--- MEDICINE SCHEDULE ---");

        int timeIndex = 0;
        bool alertTriggered = false;
        String alertMedicine = "";

        while (true) {
          timeIndex = payload.indexOf("\"time\":", timeIndex);
          if (timeIndex == -1) break;

          // Extract Time
          int valStart = payload.indexOf("\"", timeIndex + 7) + 1;
          int valEnd = payload.indexOf("\"", valStart);
          String slotTime = payload.substring(valStart, valEnd);

          // Extract Object Context (to find Date & Medicine)
          int objStart = payload.lastIndexOf("{", timeIndex);
          int objEnd = payload.indexOf("}", timeIndex);
          String objStr = payload.substring(objStart, objEnd);

          // Extract Date
          String slotDate = "";
          int dateKey = objStr.indexOf("\"date\":");
          if (dateKey != -1) {
             int dStart = objStr.indexOf("\"", dateKey + 7) + 1;
             int dEnd = objStr.indexOf("\"", dStart);
             slotDate = objStr.substring(dStart, dEnd);
          }

          // Extract Medicine
          String slotMedicine = "Medicine";
          int medKey = objStr.indexOf("\"medicine\":");
          if (medKey != -1) {
              int mStart = objStr.indexOf("\"", medKey + 11) + 1;
              int mEnd = objStr.indexOf("\"", mStart);
              slotMedicine = objStr.substring(mStart, mEnd);
          }

          Serial.print("Slot: "); Serial.print(slotTime); 
          Serial.print(" | "); Serial.print(slotDate);
          Serial.print(" - "); Serial.print(slotMedicine);

          // CHECK FOR MATCH (Time AND Date)
          if (slotTime == currentTime && slotDate == currentDate) {
            alertTriggered = true;
            alertMedicine = slotMedicine;
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

void resetAlert() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure();
    String url = "https://smart-pill-box-by-techiedo-default-rtdb.firebaseio.com/sensor/alert.json";

    if (http.begin(client, url)) {
      int httpResponseCode = http.PUT("\"0\""); // Set alert to "0"
      if (httpResponseCode > 0) {
        Serial.print("Alert Reset Success: "); Serial.println(httpResponseCode);
      } else {
        Serial.print("Alert Reset Failed: "); Serial.println(httpResponseCode);
      }
      http.end();
    }
  }
}

bool fetchSensorData() {
  bool alertDetected = false;
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    WiFiClientSecure client;
    client.setInsecure();

    String url = "https://smart-pill-box-by-techiedo-default-rtdb.firebaseio.com/sensor.json";

    if (http.begin(client, url)) {
      int httpResponseCode = http.GET();

      if (httpResponseCode > 0) {
        String payload = http.getString();
        
        // Parse avg_bpm
        int keyIndex = payload.indexOf("\"avg_bpm\":");
        int avgBpm = 0;
        if (keyIndex != -1) {
           int valStart = payload.indexOf(":", keyIndex) + 1;
           int valEnd = payload.indexOf(",", valStart);
           if (valEnd == -1) valEnd = payload.indexOf("}", valStart);
           String bpmStr = payload.substring(valStart, valEnd);
           avgBpm = bpmStr.toInt();
           Serial.print("Avg BPM: ");
           Serial.println(avgBpm);
        }

        // Parse 'alert'
        int alertStart = payload.indexOf("\"alert\":");
        String alertVal = "0";

        if (alertStart != -1) {
           int valStart = payload.indexOf(":", alertStart);
           if (valStart != -1) {
              valStart++; 
              while(payload[valStart] == ' ' && valStart < payload.length()) valStart++;
              if (payload[valStart] == '"') {
                 valStart++; 
                 int valEnd = payload.indexOf("\"", valStart);
                 alertVal = payload.substring(valStart, valEnd);
              } else {
                 int valEnd = payload.indexOf(",", valStart);
                 if (valEnd == -1) valEnd = payload.indexOf("}", valStart);
                 alertVal = payload.substring(valStart, valEnd);
                 alertVal.trim();
              }
           }
          
          Serial.print("Alert Value: ");
          Serial.println(alertVal);

          if (alertVal == "1") {
             alertDetected = true;
          }
        }
        
        // CHECK ABNORMALITY (BPM > 100 or < 50)
        // We handle immediate feedback here (Blink) but not the full reset/main alert loop
        if (avgBpm > 0 && (avgBpm < 50 || avgBpm > 100)) {
           // Short Blink for BPM Warning
            digitalWrite(10, 1);
            delay(200);
            digitalWrite(10, 0);
        }

      } else {
        Serial.print("Sensor HTTP Error: ");
        Serial.println(httpResponseCode);
      }
      http.end(); // Close connection
    }
  }
  return alertDetected;
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
      
      bool alertActive = fetchSensorData();  // Check for Alert Status
      if (alertActive) {
           Serial.println(">>> TRIGGERING VIBRATION PATTERN <<<");
           
           // Vibration Pattern
           digitalWrite(10, 1); delay(500);
           digitalWrite(10, 0); delay(200);
           digitalWrite(10, 1); delay(500);
           digitalWrite(10, 0); delay(200);
           digitalWrite(10, 1); delay(500);
           digitalWrite(10, 0); 
           
           // Reset Alert in Firebase (Safe to call now)
           resetAlert();
      }
    }
  }

  delay(100);
}
