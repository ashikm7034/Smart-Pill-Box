#ifndef EASYBLE_H
#define EASYBLE_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// This library makes BLE as simple as Serial!
// Usage:
// EasyBLE ble;
// ble.begin("My Device");
// if (ble.available()) { String msg = ble.readString(); }
// ble.print("Hello");

class EasyBLE {
  public:
    EasyBLE();
    void begin(String localName);
    bool isConnected();
    
    // Receiving
    bool available();
    String readString();
    
    // Sending
    void print(String message);
    void println(String message);

    // Internal (don't touch)
    void _handleWrite(String value);
    void _handleConnect();
    void _handleDisconnect();

  private:
    BLEServer *pServer;
    BLECharacteristic *pCharacteristic;
    bool deviceConnected;
    String incomingBuffer; // Simple buffer for the last message
    bool hasNewMessage;
};

#endif
