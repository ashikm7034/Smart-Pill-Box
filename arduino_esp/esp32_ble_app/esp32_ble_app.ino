/*
    Smart Pill Box - ESP32 BLE Server
    
    Features:
    - Creates a BLE Server
    - Advertises a Service
    - Listen for incoming messages on a Characteristic
    - Prints received messages to Serial Monitor

    Service UUID:        4fafc201-1fb5-459e-8fcc-c5c9c331914b
    Characteristic UUID: beb5483e-36e1-4688-b7f5-ea07361b26a8
*/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// See the following for generating UUIDs:
// https://www.uuidgenerator.net/

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;
String receivedMessage = "";

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();

      if (value.length() > 0) {
        receivedMessage = "";
        Serial.print("Received Value: ");
        for (int i = 0; i < value.length(); i++)
        {
          Serial.print(value[i]);
          receivedMessage += value[i];
        }
        Serial.println();
        Serial.println("Saved to variable: " + receivedMessage);
        
        // You can process the 'receivedMessage' here
        // e.g., if (receivedMessage == "TAKE_MED") { rotateMotor(); }
      }
    }
};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      Serial.println("Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      Serial.println("Device Disconnected");
      // Restart advertising so others can connect
      pServer->getAdvertising()->start();
      Serial.println("Advertising restarted");
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("Starting BLE work!");

  BLEDevice::init("Smart Pill Box (ESP32)");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ |
                                         BLECharacteristic::PROPERTY_WRITE
                                       );

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->setValue("Hello World"); // Initial value

  pService->start();
  // BLEAdvertising *pAdvertising = pServer->getAdvertising();  // this still is working for backward compatibility
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("Characteristic defined! Now you can read it in your phone!");
}

void loop() {
  // Main loop logic here
  delay(2000);
}
