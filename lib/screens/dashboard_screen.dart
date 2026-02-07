import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../components/turbine_widget.dart';
import 'device_scan_screen.dart';
import 'settings_screen.dart';
import '../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _isConnected = false;
  int _heartRate = 72;

  // Initialize with 15 empty slots (User Requirement)
  List<Map<String, String>> _slotData = List.generate(15, (index) {
    return {
      "slot": "${index + 1}",
      "time": "", // Empty on start
      "date": "", // Empty on start
      "status": "empty",
      "medicine": "",
    };
  });

  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  @override
  void initState() {
    super.initState();
    // Load local data
    _loadLocalSlots();

    // Force 15 slots if they don't exist
    if (_slotData.isEmpty) {
      _slotData = List.generate(
        15,
        (index) => {
          "slot": (index + 1).toString(),
          "time": "",
          "date": "",
          "status": "empty",
          "medicine": "",
        },
      );
    }

    // Initialize Local Notifications
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Listen to Firebase Realtime Database
    _initializeFirebaseListeners();

    // Setup Notifications
    _setupNotifications();

    // Auto-connect timer
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected && !FlutterBluePlus.isScanningNow) {
        _checkAutoConnect();
      }
    });

    // Initial check
    _checkAutoConnect();
  }

  Future<void> _setupNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Request Permission
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Subscribe to Topic
    await messaging.subscribeToTopic('pillbox_users');
    print("Subscribed to pillbox_users");

    // 3. Handle Foreground Messages (HEADS UP!)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('Got a message whilst in the foreground!');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        // Define Channel
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          channelDescription: 'Used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          color: Color(0xFF4A90E2),
        );

        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        // SHOW NOTIFICATION (Heads-up)
        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          platformChannelSpecifics,
        );
      }
    });
  }

  // --- LOCAL PERSISTENCE HELPERS ---

  Future<void> _loadLocalSlots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr = prefs.getString('cached_slots');
      if (jsonStr != null) {
        List<dynamic> decoded = jsonDecode(jsonStr);
        if (mounted) {
          setState(() {
            _slotData =
                decoded.map((e) => Map<String, String>.from(e)).toList();
          });
        }
      }
    } catch (e) {
      print("Error loading local slots: $e");
    }
  }

  Future<void> _saveLocalSlots(List<Map<String, String>> slots) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String jsonStr = jsonEncode(slots);
      await prefs.setString('cached_slots', jsonStr);
    } catch (e) {
      print("Error saving local slots: $e");
    }
  }

  void _initializeFirebaseListeners() {
    // 1. Listen to Slots
    FirebaseService().slotsStream.listen((DatabaseEvent event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        // Create a copy of current fixed list
        List<Map<String, String>> updatedSlots = List.from(_slotData);

        if (data is List) {
          for (var i = 0; i < data.length && i < 15; i++) {
            if (data[i] == null) continue;
            var item = Map<String, dynamic>.from(data[i]);
            // Lists are usually 0-indexed, but our slots are 1-15.
            // Assuming data[i] corresponds to slot i+1
            updatedSlots[i] = {
              "slot": "${i + 1}",
              "time": item['time']?.toString() ?? "",
              "date": item['date']?.toString() ?? "",
              "status": item['status']?.toString() ?? "empty",
              "medicine": item['medicine']?.toString() ?? "",
            };
          }
        } else {
          // Map: Loop through 1 to 15
          for (int i = 1; i <= 15; i++) {
            var key = i.toString();
            if (data.containsKey(key)) {
              var item = Map<String, dynamic>.from(data[key]);
              updatedSlots[i - 1] = {
                "slot": key,
                "time": item['time']?.toString() ?? "",
                "date": item['date']?.toString() ?? "",
                "status": item['status']?.toString() ?? "empty",
                "medicine": item['medicine']?.toString() ?? "",
              };
            }
          }
        }

        // SAVE LOCALLY (Cache for offline/startup)
        _saveLocalSlots(updatedSlots);

        if (mounted) {
          setState(() {
            _slotData = updatedSlots;
          });
        }
      } else {
        // No databse data? Keep default empty slots.
        // Optional: FirebaseService().initializeMockData();
      }
    });

    // 2. Listen to Heart Rate
    FirebaseService().heartRateStream.listen((event) {
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            _heartRate = data['bpm'] ?? 0;
          });
        }
      }
    });
  }

  // Auto-connect removed from init to separate method call
  // Mock data generation removed

  Future<void> _checkAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final String? deviceId = prefs.getString('device_id');

    // If already connected (e.g. from Scan Screen), just sync
    if (FlutterBluePlus.connectedDevices.isNotEmpty) {
      if (mounted)
        setState(() {
          _isConnected = true;
        });
      await _startBLEListening(FlutterBluePlus.connectedDevices.first);
      await _requestDataFromESP();
      return;
    }

    if (deviceId != null) {
      print("Found saved device: $deviceId. Attempting auto-connect...");
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 5),
        );

        FlutterBluePlus.scanResults.listen((results) async {
          for (ScanResult r in results) {
            if (r.device.remoteId.toString() == deviceId) {
              print("Found saved device! Connecting...");
              await FlutterBluePlus.stopScan();
              try {
                await r.device.connect();
                if (mounted) {
                  setState(() {
                    _isConnected = true;
                  });
                }
                print("Auto-connected!");
                await _startBLEListening(r.device);
                await _requestDataFromESP();
              } catch (e) {
                print("Auto-connect failed: $e");
              }
            }
          }
        });
      } catch (e) {
        print("Error during auto-connect scan: $e");
      }
    }
  }

  Future<void> _startBLEListening(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        // Our Service
        if (s.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var c in s.characteristics) {
            // Our Characteristic
            if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              await c.setNotifyValue(true);
              c.lastValueStream.listen((value) {
                String data = String.fromCharCodes(value);
                print("BLE Received: $data");

                if (data.startsWith("SLOT_DATA:")) {
                  // Format: SLOT_DATA:1:08:00 AM:Jan 14:scheduled
                  // Split by ':' -> [SLOT_DATA, 1, 08, 00 AM, Jan 14, scheduled]
                  var parts = data.split(':');
                  if (parts.length >= 6) {
                    int id = int.parse(parts[1]);
                    // Reconstruct Time "08" + ":" + "00 AM"
                    String t = "${parts[2]}:${parts[3]}";
                    String d = parts[4];
                    String st = parts[5];

                    // Update correct slot
                    _updateSlotFromBLE(id, t, d, st);
                  }
                }
              });
            }
          }
        }
      }
    } catch (e) {
      print("BLE Listen Error: $e");
    }
  }

  void _updateSlotFromBLE(int id, String time, String date, String status) {
    if (mounted) {
      setState(() {
        // _slotData is 0-indexed
        if (id > 0 && id <= 15) {
          _slotData[id - 1] = {
            "slot": id.toString(),
            "time": time,
            "date": date,
            "status": status,
            "medicine": _slotData[id - 1]['medicine'] ??
                "", // Preserve medicine if BLE doesn't send it
          };
        }
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    String period = time.hour >= 12 ? "PM" : "AM";
    int hour = time.hour > 12 ? time.hour - 12 : time.hour;
    hour = hour == 0 ? 12 : hour;
    return "${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period";
  }

  String _formatDate(DateTime time) {
    return DateFormat('EEE, MMM d').format(time);
  }

  Future<void> _handleConnect() async {
    // Navigate to Scan Screen
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeviceScanScreen()),
    ).then((_) {
      // Re-check connection and sync when returning
      _checkAutoConnect();
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      // Refresh connection status when returning from settings (in case user disconnected)
      _checkAutoConnect();
      // Also check if list is empty explicitly if they clicked Forget
      if (FlutterBluePlus.connectedDevices.isEmpty) {
        if (mounted) {
          setState(() {
            _isConnected = false;
          });
        }
      }
    });
  }

  // Generic Command Sender
  Future<void> _sendCommand(String cmd) async {
    if (FlutterBluePlus.connectedDevices.isEmpty) return;
    try {
      final device = FlutterBluePlus.connectedDevices.first;
      final services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var c in s.characteristics) {
            if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              await c.write(cmd.codeUnits);
              print("Sent to BLE: $cmd");
              break;
            }
          }
        }
      }
    } catch (e) {
      print("BLE Command Error: $e");
    }
  }

  final TurbineController _turbineController = TurbineController();

  void _handleSlotTap(int slotIndex) {
    // Send "edit" signal to ESP32 as requested
    _sendCommand("edit");

    // User requested to ALWAYS start editing from Slot 1
    _startEditFlow(1);
  }

  Future<void> _startEditFlow(int slotIndex) async {
    // 1. Animate to the slot
    await _turbineController.animateToSlot(slotIndex);

    // 2. Find data
    if (!mounted) return;

    // Logic: Look for existing data. If empty, calculate "Suggested" default.
    Map<String, String> currentData = _slotData.firstWhere(
      (element) => element['slot'] == slotIndex.toString(),
      orElse: () => {},
    );

    // Create a copy to edit effectively, populating defaults if missing
    Map<String, String> editData = Map.from(currentData);
    if (editData.isEmpty) {
      editData = {
        "slot": slotIndex.toString(),
        "time": "",
        "date": "",
        "status": "empty",
        "medicine": ""
      };
    }

    // Auto-fill defaults for the DIALOG if empty
    if (editData['date'] == null || editData['date']!.isEmpty) {
      DateTime d = DateTime.now().add(Duration(days: slotIndex - 1));
      editData['date'] = DateFormat('MMM d').format(d);
    }
    if (editData['time'] == null || editData['time']!.isEmpty) {
      editData['time'] = "08:00 AM";
    }

    // 3. Show Dialog
    _showEditSlotDialog(editData, slotIndex);
  }

  // Method to send Slot Data to BLE
  Future<void> _sendSlotToBLE(int slotId, String time, String date) async {
    // Reuse generic command
    String cmd = "SLOT:$slotId:$time:$date";
    await _sendCommand(cmd);
  }

  // Send request for data sync
  Future<void> _requestDataFromESP() async {
    await _sendCommand("give_data");
  }

  Future<void> _showEditSlotDialog(
      Map<String, String> data, int currentSlotIndex) async {
    String time = data['time']!;
    String medicine = data['medicine'] ?? "";

    // Default to 'scheduled' since we removed the dropdown
    String status = "scheduled";

    // Use data['date'] (which we ensured is populated in startEditFlow)
    String dateStr = data['date']!;

    // Parse time
    TimeOfDay initialTime = TimeOfDay.now();
    try {
      final parts = time.split(" ");
      final hm = parts[0].split(":");
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      if (parts[1] == "PM" && h != 12) h += 12;
      if (parts[1] == "AM" && h == 12) h = 0;
      initialTime = TimeOfDay(hour: h, minute: m);
    } catch (e) {
      // use default
    }

    await showDialog(
      context: context,
      barrierDismissible: false, // Force user to choose action
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                "Edit Slot ${data['slot']}",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Medicine Name Input
                    TextFormField(
                      initialValue: medicine,
                      decoration: InputDecoration(
                        labelText: "Medicine Name",
                        labelStyle: GoogleFonts.poppins(),
                        prefixIcon: const Icon(Icons.medication),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (val) {
                        medicine = val;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Time Picker
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final TimeOfDay? picked = await showTimePicker(
                            context: context,
                            initialTime: initialTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              initialTime = picked;
                              String period = picked.hour >= 12 ? "PM" : "AM";
                              int h = picked.hour > 12
                                  ? picked.hour - 12
                                  : picked.hour;
                              h = h == 0 ? 12 : h;
                              time =
                                  "${h.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')} $period";
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time),
                              const SizedBox(width: 16),
                              Text("Time", style: GoogleFonts.poppins()),
                              const Spacer(),
                              Text(
                                time,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Date Picker
                    // Date Picker
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              dateStr = DateFormat('MMM d').format(picked);
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 16),
                              Text("Date", style: GoogleFonts.poppins()),
                              const Spacer(),
                              Text(
                                dateStr,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _sendCommand("cancel");
                    Navigator.pop(context);
                  },
                  child: Text("Cancel", style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Logic: Save & NEXT

                    // 1. Send to BLE (ID, Time, Date)
                    _sendSlotToBLE(int.parse(data['slot']!), time, dateStr);

                    // 2. Save to Firebase (Force status = scheduled)
                    final newData = {
                      "slot": data['slot']!,
                      "time": time,
                      "date": dateStr,
                      "status": "scheduled",
                      "medicine": medicine,
                    };
                    FirebaseService().updateSlot(
                      int.parse(data['slot']!),
                      newData,
                    );

                    Navigator.pop(context);

                    // 3. Next?
                    int nextIndex = currentSlotIndex + 1;
                    if (nextIndex <= 14) {
                      Future.delayed(const Duration(milliseconds: 200), () {
                        _startEditFlow(nextIndex);
                      });
                    }
                  },
                  child: Text(
                      (currentSlotIndex < 14) ? "Save & Next" : "Save & Finish",
                      style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Good Morning,",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "Ashik",
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2D3436),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Settings Button
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.grey),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Time & Date Container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(_now),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A90E2),
                          ),
                        ),
                        Text(
                          _formatDate(_now),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Settings Button
                  GestureDetector(
                    onTap: _openSettings,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.settings_rounded,
                        color: Colors.grey[700],
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Connect / Status Button
              GestureDetector(
                onTap: _handleConnect,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isConnected
                          ? [const Color(0xFF66BB6A), const Color(0xFF43A047)]
                          : [const Color(0xFF4A90E2), const Color(0xFF002F6C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (_isConnected ? Colors.green : Colors.blue)
                            .withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth_searching,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isConnected ? "Smart Pill Box" : "Connect Device",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _isConnected ? "Online" : "Tap to sync or scan",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (_isConnected)
                        GestureDetector(
                          onTap: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Syncing data..."),
                                  duration: Duration(milliseconds: 500)),
                            );
                            await _requestDataFromESP();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child:
                                const Icon(Icons.refresh, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Turbine UI in Dashboard
              Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: TurbineWidget(
                    slots: _slotData,
                    onSlotTap: _handleSlotTap,
                    controller: _turbineController,
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // Legend for Turbine
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem("Taken", const Color(0xFF66BB6A)),
                  const SizedBox(width: 8),
                  _buildLegendItem("Scheduled", const Color(0xFF42A5F5)),
                  const SizedBox(width: 8),
                  _buildLegendItem("Missed", const Color(0xFFEF5350)),
                ],
              ),

              const SizedBox(height: 30),
              // Heart Rate Monitor (Bottom)
              _buildHeartRateCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildHeartRateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE), // Light Red
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFEF5350), // Red
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Heart Rate",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$_heartRate",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3436),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      "BPM",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Spacer(),
          // Interactive Graph / Waveform placeholder
          Container(
            height: 40,
            width: 80,
            child: CustomPaint(painter: HeartWavePainter()),
          ),
        ],
      ),
    );
  }
}

class HeartWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEF5350).withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height / 2);

    // Simple mock EKG wave
    path.lineTo(size.width * 0.2, size.height / 2);
    path.lineTo(size.width * 0.3, size.height * 0.2);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.1);
    path.lineTo(size.width * 0.6, size.height * 0.9);
    path.lineTo(size.width * 0.7, size.height / 2); // Corrected this line
    path.lineTo(size.width, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
