#ifndef SIMPLEBLE_H
#define SIMPLEBLE_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

class SimpleBLE {
  public:
    SimpleBLE();
    void begin(String localName);
    bool isConnected();
    void onMessage(void (*callback)(String));
    void send(String message);
    
    // Internal use (must be public for callbacks to reach)
    void _handleWrite(std::string value);
    void _handleConnect();
    void _handleDisconnect();

  private:
    BLEServer *pServer;
    BLECharacteristic *pCharacteristic;
    void (*messageCallback)(String);
    bool deviceConnected;
};

#endif
