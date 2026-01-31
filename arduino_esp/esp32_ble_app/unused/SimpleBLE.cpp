#include "SimpleBLE.h"

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Global pointer to instance for callbacks
SimpleBLE* globalSimpleBLE = NULL;

// --- INTERNAL CALLBACKS ---
class InternalCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      if (globalSimpleBLE) {
        std::string value = pCharacteristic->getValue();
        globalSimpleBLE->_handleWrite(value);
      }
    }
};

class InternalServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
       if (globalSimpleBLE) globalSimpleBLE->_handleConnect();
    };
    void onDisconnect(BLEServer* pServer) {
       if (globalSimpleBLE) globalSimpleBLE->_handleDisconnect();
    }
};

// --- CLASS IMPLEMENTATION ---

SimpleBLE::SimpleBLE() {
  deviceConnected = false;
  messageCallback = NULL;
  globalSimpleBLE = this;
}

void SimpleBLE::begin(String localName) {
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

bool SimpleBLE::isConnected() {
  return deviceConnected;
}

void SimpleBLE::onMessage(void (*callback)(String)) {
  messageCallback = callback;
}

void SimpleBLE::send(String message) {
  if (deviceConnected && pCharacteristic) {
    pCharacteristic->setValue(message.c_str());
    pCharacteristic->notify();
  }
}

// Internal handlers
void SimpleBLE::_handleWrite(std::string value) {
  if (value.length() > 0) {
    String msg = "";
    for (int i = 0; i < value.length(); i++) msg += value[i];
    if (messageCallback) {
      messageCallback(msg);
    }
  }
}

void SimpleBLE::_handleConnect() {
  deviceConnected = true;
}

void SimpleBLE::_handleDisconnect() {
  deviceConnected = false;
  pServer->getAdvertising()->start();
}
