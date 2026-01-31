#ifndef EASYBLE_H
#define EASYBLE_H

#include <Arduino.h>
#include <ArduinoBLE.h>

// EasyBLE for Uno R4 WiFi (Uses ArduinoBLE)
// Same simple API as the ESP32 version!

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
    
    // Internal polling (Must be called in loop if not using interrupts, but we wrap it)
    void poll(); 

  private:
    BLEService* pService;
    BLEStringCharacteristic* pCharacteristic;
    String incomingBuffer;
    bool hasNewMessage;
    // We cache the characteristic to avoid lookups
};

#endif
