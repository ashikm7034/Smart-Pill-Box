/*
   Smart Pill Box - Uno R4 WiFi
   PURE SERIAL BRIDGE
   - Receiving: Prints App messages to Serial Monitor
   - Sending: Sends Serial Monitor text to App
*/

#include "EasyBLE.h"

EasyBLE ble;

void setup() {
  Serial.begin(115200);
  
  // Start Bluetooth
  ble.begin("Smart Pill Box");
  
  Serial.println("Bluetooth started!");
  Serial.println("Type on Serial Monitor to send to Phone.");
}

void loop() {
  
  // 1. Receive from Phone -> Print to Serial
  if (ble.available()) {
    String rxValue = ble.readString();
    Serial.print("APP Says: ");
    Serial.println(rxValue);
  }
  
  // 2. Send from Serial -> Send to Phone
  if (Serial.available()) {
    String txValue = Serial.readStringUntil('\n');
    txValue.trim(); // Clean up whitespace
    
    if (txValue.length() > 0) {
       // Send it!
       ble.print(txValue);
       Serial.print("Sent: ");
       Serial.println(txValue);
    }
  }
  
  // Short delay for stability
  delay(10);
}