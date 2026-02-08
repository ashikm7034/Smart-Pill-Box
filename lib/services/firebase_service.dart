import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class FirebaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Singleton pattern-ish or just static/provider based. Let's keep it simple.
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // --- STREAMS ---

  /// Listen to all changes in 'pill_slots'
  Stream<DatabaseEvent> get slotsStream {
    return _db.child('pill_slots').onValue;
  }

  /// Listen to sensor updates (BPM, Alert)
  Stream<DatabaseEvent> get sensorStream {
    return _db.child('sensor').onValue;
  }

  // --- WRITES (App -> Cloud) ---

  /// Update a specific slot's data (e.g. from the Edit Dialog)
  Future<void> updateSlot(int slotId, Map<String, dynamic> data) async {
    // Determine path. Since our array 0-14 maps to Slot 1-15, let's stick to 1-based ID in DB or 0-based?
    // User requirement said "14 slot data". Let's assume database keys are "slot_1", "slot_2" etc. or simply "1", "2".
    // Let's use simple numeric keys "1" to "15".
    await _db.child('pill_slots').child(slotId.toString()).update(data);
  }

  /// Optional: Create initial mock data if empty
  Future<void> initializeMockData() async {
    final snapshot = await _db.child('pill_slots').get();
    if (!snapshot.exists) {
      Map<String, dynamic> initialData = {};
      for (int i = 1; i <= 15; i++) {
        initialData[i.toString()] = {
          'slot': i.toString(),
          'time': '08:00 AM',
          'date': 'Jan ${i}',
          'status': 'empty',
          'medicine': 'Vitamin C',
        };
      }
      await _db.child('pill_slots').set(initialData);
    }
  }
}
