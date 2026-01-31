#include "PillEEPROM.h"

PillEEPROM::PillEEPROM() {
}

void PillEEPROM::begin() {
    EEPROM.begin(1024); // Increased size to accomodate larger slots
}

int PillEEPROM::_getAddr(int id) {
    if (id < 1 || id > 15) return -1;
    return (id - 1) * 64; // Increased from 20 to 64 to prevent overwrite
}

void PillEEPROM::saveSlot(int id, String time, String date, String status) {
    int addr = _getAddr(id);
    if (addr == -1) return;
    
    // Format: "08:00 AM|Jan 14|scheduled"
    // Max length should now fit within 64 bytes
    String payload = time + "|" + date + "|" + status;
    EEPROM.writeString(addr, payload);
    EEPROM.commit();
    
    Serial.print("PillEEPROM: Saved Slot ");
    Serial.print(id);
    Serial.print(" -> ");
    Serial.println(payload);
}

void PillEEPROM::updateStatus(int id, String status) {
    int addr = _getAddr(id);
    if (addr == -1) return;
    
    String current = readSlot(id);
    if (current.length() == 0) return; // No slot exists
    
    // Parse existing to keep Time and Date
    // Format: time|date|oldStatus
    int firstPipe = current.indexOf('|');
    int secondPipe = current.indexOf('|', firstPipe + 1);
    
    String newPayload = "";
    
    if (firstPipe > 0) {
        String time = current.substring(0, firstPipe);
        String date = "";
        
        if (secondPipe > 0) {
            date = current.substring(firstPipe + 1, secondPipe);
        } else {
            date = current.substring(firstPipe + 1);
        }
        
        newPayload = time + "|" + date + "|" + status;
        EEPROM.writeString(addr, newPayload);
        EEPROM.commit();
        
        Serial.print("PillEEPROM: Updated Status Slot ");
        Serial.print(id);
        Serial.print(" -> ");
        Serial.println(status);
    }
}

String PillEEPROM::readSlot(int id) {
    int addr = _getAddr(id);
    if (addr == -1) return "";
    return EEPROM.readString(addr);
}

void PillEEPROM::clear() {
    Serial.println("PillEEPROM: Clearing...");
    for (int i = 0; i < 1024; i++) { // Clear full 1KB
        EEPROM.write(i, 0);
    }
    EEPROM.commit();
    Serial.println("PillEEPROM: Cleared!");
}

void PillEEPROM::printAll() {
    Serial.println("--- PILLEEPROM DUMP ---");
    for (int i = 1; i <= 15; i++) {
        String val = readSlot(i);
        Serial.print("Slot ");
        Serial.print(i);
        Serial.print(": ");
        if (val.length() == 0) {
            Serial.println("(empty)");
        } else {
            Serial.println(val);
        }
    }
    Serial.println("-----------------------");
}
