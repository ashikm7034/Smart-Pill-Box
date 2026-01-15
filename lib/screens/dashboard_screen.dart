import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/turbine_widget.dart';
import 'device_scan_screen.dart';
import 'settings_screen.dart';

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
  final Random _random = Random();

  // Initialize in initState to get fresh dates
  List<Map<String, String>> _slotData = [];

  @override
  void initState() {
    super.initState();
    _generateMockData();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
          if (timer.tick % 3 == 0) {
            // Randomize heart rate every 3 seconds
            _heartRate = 60 + _random.nextInt(40); // 60-100 BPM
          }
        });
      }
    });

    _checkAutoConnect();
  }

  void _generateMockData() {
    // Generate next 15 days/slots mock
    DateTime base = DateTime.now();
    _slotData = List.generate(15, (index) {
      DateTime d = base.add(Duration(days: index));
      return {
        "slot": "${index + 1}",
        "time": "08:00 AM",
        "date": DateFormat('MMM d').format(d), // e.g. "Jan 14"
        "status": index == 0
            ? "taken"
            : (index < 4 ? "scheduled" : "empty"), // random statuses
      };
    });
  }

  Future<void> _checkAutoConnect() async {
    // 1. Check if we already have a connected device (e.g. from hot reload or previous)
    if (FlutterBluePlus.connectedDevices.isNotEmpty) {
      setState(() {
        _isConnected = true;
      });
      return;
    }

    // 2. Check SharedPreferences for last device
    final prefs = await SharedPreferences.getInstance();
    final String? deviceId = prefs.getString('device_id');

    if (deviceId != null) {
      print("Found saved device: $deviceId. Attempting auto-connect...");
      // Attempt to scan and find this specific device
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 5),
          withServices: [], // Optional: filter by service UUIDs if known
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
    );
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

  void _handleSlotTap(int slotIndex) {
    // Find existing data or create default
    Map<String, String> currentData = _slotData.firstWhere(
      (element) => element['slot'] == slotIndex.toString(),
      orElse: () {
        DateTime d = DateTime.now().add(Duration(days: slotIndex - 1));
        return {
          "slot": slotIndex.toString(),
          "time": "08:00 AM",
          "date": DateFormat('MMM d').format(d),
          "status": "empty",
        };
      },
    );

    _showEditSlotDialog(currentData);
  }

  Future<void> _showEditSlotDialog(Map<String, String> data) async {
    String time = data['time']!;
    String status = data['status']!;
    String dateStr = data['date'] ?? DateFormat('MMM d').format(DateTime.now());

    // Parse time
    TimeOfDay initialTime = TimeOfDay.now();
    // ... parse logic same ...

    try {
      final parts = time.split(" ");
      final hm = parts[0].split(":");
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      if (parts[1] == "PM" && h != 12) h += 12;
      if (parts[1] == "AM" && h == 12) h = 0;
      initialTime = TimeOfDay(hour: h, minute: m);
    } catch (e) {
      // Keep default
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                "Edit Slot ${data['slot']}",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Time Picker
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text("Time", style: GoogleFonts.poppins()),
                    trailing: Text(
                      time,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
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
                  ),
                  // Date Picker (Basic String Edit or DatePicker? Let's use DatePicker)
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text("Date", style: GoogleFonts.poppins()),
                    trailing: Text(
                      dateStr,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
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
                  ),

                  const SizedBox(height: 10),
                  // Status Dropdown
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(
                      labelText: "Status",
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: ["empty", "scheduled", "taken", "missed"].map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(
                          s[0].toUpperCase() + s.substring(1),
                          style: GoogleFonts.poppins(),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          status = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Save Changes
                    setState(() {
                      // Remove old entry if exists to avoid duplicates (though logic shouldn't allow duplicates of same slot key usually, but list might have them)
                      _slotData.removeWhere(
                        (element) => element['slot'] == data['slot'],
                      );
                      _slotData.add({
                        "slot": data['slot']!,
                        "time": time,
                        "date": dateStr,
                        "status": status,
                      });
                      // Sort by slot number just in case
                      _slotData.sort(
                        (a, b) => int.parse(
                          a['slot']!,
                        ).compareTo(int.parse(b['slot']!)),
                      );
                    });
                    Navigator.pop(context);
                  },
                  child: Text("Save", style: GoogleFonts.poppins()),
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
