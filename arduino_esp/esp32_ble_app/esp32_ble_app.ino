

#include "EasyBLE.h"

EasyBLE ble;

#include <EEPROM.h>
#include "PillEEPROM.h"
#include "PillFCM.h"

// ... (Existing Include) ...

PillEEPROM pillMemory; 
PillFCM fcm;

void setup() {
  Serial.begin(115200);
  pillMemory.begin(); // Init EEPROM via Library
  
  // Start Bluetooth query
  ble.begin("ashik");
  
  // Connect to WiFi for Notifications
  // REPLACE WITH YOUR WIFI CREDENTIALS IN PRODUCTION
  // For demo, we assume user will edit this line.
  fcm.begin("FTTHZ", "qazplm007");
  
  Serial.println("Bluetooth started! Waiting for app...");
}

void loop() {
  // Maintain WiFi
  fcm.loop();
  
  // Check if data is available (just like Serial.available())
  if (ble.available()) {
    
    String data = ble.readString();
    
    Serial.print("Received: ");
    Serial.println(data);
    
    // --- YOUR LOGIC HERE ---
    
    // 0. Save Slot Data (Command: "SLOT:ID:TIME:DATE")
    if (data.startsWith("SLOT:")) {
       // Format: SLOT:1:08:00 AM:Jan 14
       int firstColon = data.indexOf(':');
       int secondColon = data.indexOf(':', firstColon + 1);
       int thirdColon = data.indexOf(':', secondColon + 1);
       
       if (firstColon > 0 && secondColon > 0) {
           String idStr = data.substring(firstColon + 1, secondColon);
           int id = idStr.toInt();
           
           if (id > 0) {
                String timeStr;
                String dateStr;
                
                if (thirdColon > 0) {
                    timeStr = data.substring(secondColon + 1, thirdColon);
                    dateStr = data.substring(thirdColon + 1);
                } else {
                    timeStr = data.substring(secondColon + 1);
                    dateStr = "";
                }
                
                // Use Library (default status = "scheduled")
                pillMemory.saveSlot(id, timeStr, dateStr);
           }
       }
    }
    
    // Command: give_data
    else if (data == "give_data") {
        Serial.println("Command: give_data -> Syncing...");
        for (int i = 1; i <= 15; i++) {
            String val = pillMemory.readSlot(i); // "08:00 AM|Jan 14|scheduled"
            if (val.length() > 0) {
                // Parse Time|Date|Status
                int firstPipe = val.indexOf('|');
                int secondPipe = val.indexOf('|', firstPipe + 1);
                
                String t = "";
                String d = "";
                String st = "scheduled"; // default
                
                if (firstPipe > 0) {
                    t = val.substring(0, firstPipe);
                    if (secondPipe > 0) {
                        d = val.substring(firstPipe + 1, secondPipe);
                        st = val.substring(secondPipe + 1);
                    } else {
                        d = val.substring(firstPipe + 1);
                    }
                }
                
                // Send to App: "SLOT_DATA:ID:TIME:DATE:STATUS"
                String resp = "SLOT_DATA:" + String(i) + ":" + t + ":" + d + ":" + st;
                ble.print(resp);
                Serial.println("Sent: " + resp);
                delay(50); // Throttle
            }
        }
        ble.print("SYNC_DONE");
    }

    // 1. Handshake & Wait for ID
    else if (data == "fingerprint") {
       Serial.println("Handshake -> Sending 'ok'");
       ble.print("ok");
       
       // WAIT FOR ID
       long startTime = millis();
       while(!ble.available()) {
         delay(10);
         if (millis() - startTime > 10000) break; // 10s timeout
       }
       
       if (ble.available()) {
         String idStr = ble.readString();
         int idToEnroll = idStr.toInt();
         
         Serial.print("Received ID: ");
         Serial.println(idToEnroll);
         
         // Save to variable (User Request)
         // int currentEnrollId = idToEnroll; 
         
         ble.print("o   ");
       }
    }
    
    // 2. Add Fingerprint
    else if (data.startsWith("add_fp:")) {
       // data is like "add_fp:1:mom"
       // You can parse it here
       Serial.println("Command: Add Fingerprint");
       // enrollFingerprint(...);
    }
    
    // 3. Delete Fingerprint
    else if (data.startsWith("FP_DEL:")) {
       Serial.println("Command: Delete Fingerprint");
       // deleteFingerprint(...);
    }
  }
  
  //optional eth ninakk mavuvaly conrol cheyyan vendi ann
  // 2. Send from Serial -> Send to Phone (Bridge Mode)
  if (Serial.available()) {
    String txValue = Serial.readStringUntil('\n');
    txValue.trim(); // Clean up whitespace
    
    // Clear Command
    if (txValue == "clear") {
        pillMemory.clear();
        return;
    }

    // Print EEPROM Command
    if (txValue == "eeprom") {
        pillMemory.printAll();
        return;
    }
    
    // --- EXAMPLE: Hardware Trigger Simulation ---
    // If you type "taken:1", it marks Slot 1 as Taken
    if (txValue.startsWith("taken:")) {
        int id = txValue.substring(6).toInt();
        if (id > 0) {
            pillMemory.updateStatus(id, "taken");
            // Notify App immediately too?
            // ble.print("SLOT_UPDATE:" + String(id) + ":taken"); 
        }
        return;
    }
    
    if (txValue.startsWith("missed:")) {
        int id = txValue.substring(7).toInt();
        if (id > 0) {
            pillMemory.updateStatus(id, "missed");
            
            // --- TRIGGER NOTIFICATION (Demo) ---
            fcm.sendNotification("MISSED PILL!", "Slot " + String(id) + " was missed! Take it now.");
        }
        return;
    }
    // --------------------------------------------
    
    if (txValue.length() > 0) {
       ble.print(txValue);
       Serial.print("Sent to App: ");
       Serial.println(txValue);
    }
  }
  
  delay(10); // Small delay for stability
}
