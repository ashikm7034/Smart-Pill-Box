/*
    Smart Pill Box - Arduino Uno R4 WiFi BLE Server
    
    Features:
    - Creates a BLE Server
    - Advertises a Service
    - Listen for incoming messages on a Characteristic
    - Prints received messages to Serial Monitor

    Service UUID:        4fafc201-1fb5-459e-8fcc-c5c9c331914b
    Characteristic UUID: beb5483e-36e1-4688-b7f5-ea07361b26a8
*/

#include <ArduinoBLE.h>

// UUIDs
const char* serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const char* charUUID =    "beb5483e-36e1-4688-b7f5-ea07361b26a8";

BLEService pillBoxService(serviceUUID); 
BLEStringCharacteristic messageCharacteristic(charUUID, BLERead | BLEWrite, 512); // Max 512 bytes

String receivedMessage = "";

void setup() {
  Serial.begin(115200);
  while (!Serial);

  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");
    while (1);
  }

  BLE.setLocalName("Smart Pill Box (Uno R4)");
  BLE.setAdvertisedService(pillBoxService);

  // Add characteristic to the service
  pillBoxService.addCharacteristic(messageCharacteristic);

  // Add service
  BLE.addService(pillBoxService);

  // Set initial value
  messageCharacteristic.writeValue("Hello from Uno R4");

  // Start advertising
  BLE.advertise();

  Serial.println("Bluetooth device active, waiting for connections...");
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    while (central.connected()) {
      if (messageCharacteristic.written()) {
        receivedMessage = messageCharacteristic.value();
        Serial.print("Received Value: ");
        Serial.println(receivedMessage);
        Serial.println("Saved to variable: " + receivedMessage);
        
        // Process message
        // if (receivedMessage == "TAKE_MED") { ... }
      }
    }

    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}
