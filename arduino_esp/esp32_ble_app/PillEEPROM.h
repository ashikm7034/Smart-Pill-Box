#ifndef PILLEEPROM_H
#define PILLEEPROM_H

#include <Arduino.h>
#include <EEPROM.h>

class PillEEPROM {
public:
    PillEEPROM();
    void begin();
    
    // Core Functions
    void saveSlot(int id, String time, String date, String status = "scheduled");
    void updateStatus(int id, String status);
    String readSlot(int id);
    void clear();
    void printAll(); // For debugging
    
private:
    int _getAddr(int id);
};

#endif
