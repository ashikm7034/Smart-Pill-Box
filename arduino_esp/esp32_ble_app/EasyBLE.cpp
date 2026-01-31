#include "EasyBLE.h"

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

EasyBLE* globalEasyBLE = NULL;

// --- HIDDEN CALLBACKS (The Ugly Stuff) ---

class InternalCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      if (globalEasyBLE) {
        String value = pCharacteristic->getValue();
        globalEasyBLE->_handleWrite(value);
      }
    }
};

class InternalServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
       if (globalEasyBLE) globalEasyBLE->_handleConnect();
    };
    void onDisconnect(BLEServer* pServer) {
       if (globalEasyBLE) globalEasyBLE->_handleDisconnect();
    }
};

// --- SIMPLE LIBRARY IMPLEMENTATION ---

EasyBLE::EasyBLE() {
  deviceConnected = false;
  incomingBuffer = "";
  hasNewMessage = false;
  globalEasyBLE = this;
}

void EasyBLE::begin(String localName) {
  BLEDevice::init(localName.c_str());
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new InternalServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ |
                                         BLECharacteristic::PROPERTY_WRITE |
                                         BLECharacteristic::PROPERTY_NOTIFY
                                       );

  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new InternalCallbacks());
  pCharacteristic->setValue("Ready");

  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
}

bool EasyBLE::isConnected() {
  return deviceConnected;
}

// --- RECEIVING ---

bool EasyBLE::available() {
  return hasNewMessage;
}

String EasyBLE::readString() {
  hasNewMessage = false;
  String temp = incomingBuffer;
  incomingBuffer = ""; // Clear after reading
  return temp;
}

// --- SENDING ---

void EasyBLE::print(String message) {
  if (deviceConnected && pCharacteristic) {
    pCharacteristic->setValue(message.c_str());
    pCharacteristic->notify();
  }
}

void EasyBLE::println(String message) {
  print(message); // BLE doesn't really need newlines, but works the same
}

// --- INTERNAL HANDLERS ---

void EasyBLE::_handleWrite(String value) {
  incomingBuffer = value;
  hasNewMessage = true;
}

void EasyBLE::_handleConnect() {
  deviceConnected = true;
}

void EasyBLE::_handleDisconnect() {
  deviceConnected = false;
  pServer->getAdvertising()->start();
}
