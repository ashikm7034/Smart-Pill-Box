#include "EasyBLE.h"

// UUIDs must match the App
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

EasyBLE::EasyBLE() {
  hasNewMessage = false;
  incomingBuffer = "";
  pService = NULL;
  pCharacteristic = NULL;
}

void EasyBLE::begin(String localName) {
  if (!BLE.begin()) {
    while (1); // Halt if BLE failed
  }

  BLE.setLocalName(localName.c_str());
  
  // Create Service and Characteristic
  pService = new BLEService(SERVICE_UUID);
  
  // BLENotify | BLEWrite
  pCharacteristic = new BLEStringCharacteristic(CHARACTERISTIC_UUID, BLERead | BLEWrite | BLENotify, 512);

  pService->addCharacteristic(*pCharacteristic);
  BLE.addService(*pService);
  
  // Start advertising
  BLE.setAdvertisedService(*pService);
  BLE.advertise();
}

bool EasyBLE::isConnected() {
  BLEDevice central = BLE.central();
  return central && central.connected();
}

void EasyBLE::poll() {
  // Uno R4 / ArduinoBLE needs polling explicitly if not in loop
  BLE.poll();

  if (isConnected()) {
    if (pCharacteristic->written()) {
      incomingBuffer = pCharacteristic->value();
      hasNewMessage = true;
    }
  }
}

// --- RECEIVING ---

bool EasyBLE::available() {
  poll(); // Check for new data
  return hasNewMessage;
}

String EasyBLE::readString() {
  hasNewMessage = false;
  String temp = incomingBuffer;
  incomingBuffer = "";
  return temp;
}

// --- SENDING ---

void EasyBLE::print(String message) {
  if (isConnected()) {
    pCharacteristic->writeValue(message);
  }
}

void EasyBLE::println(String message) {
  print(message); 
}
