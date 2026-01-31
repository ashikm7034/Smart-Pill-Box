import 'dart:convert';
import 'dart:async'; // Added missing import
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_scan_screen.dart';

class FingerprintScreen extends StatefulWidget {
  const FingerprintScreen({super.key});

  @override
  State<FingerprintScreen> createState() => _FingerprintScreenState();
}

class _FingerprintScreenState extends State<FingerprintScreen> {
  // Mock data for now, ideally this should be synced from device or local storage
  // Each slot: { 'id': 1, 'name': 'Ashik', 'active': true }
  // Each slot: { 'id': 1, 'name': 'Ashik', 'active': true }
  List<Map<String, dynamic>> _slots = [
    {'id': 1, 'name': null, 'active': false},
    {'id': 2, 'name': null, 'active': false},
    {'id': 3, 'name': null, 'active': false},
  ];

  BluetoothCharacteristic? _writeCharacteristic;
  bool _isConnecting = true;

  @override
  void initState() {
    super.initState();
    _loadSlots(); // Load saved data
    _findWriteCharacteristic();
  }

  // Save slots to SharedPreferences
  Future<void> _saveSlots() async {
    final prefs = await SharedPreferences.getInstance();
    String encoded = jsonEncode(_slots);
    await prefs.setString('fingerprint_slots', encoded);
  }

  // Load slots from SharedPreferences
  Future<void> _loadSlots() async {
    final prefs = await SharedPreferences.getInstance();
    String? encoded = prefs.getString('fingerprint_slots');
    try {
      if (encoded == null) return;
      List<dynamic> decoded = jsonDecode(encoded);
      if (mounted) {
        setState(() {
          _slots = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      print("Error loading slots: $e");
    }
  }

  Future<void> _findWriteCharacteristic() async {
    if (FlutterBluePlus.connectedDevices.isEmpty) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No Device Connected')));
      }
      return;
    }

    try {
      BluetoothDevice device = FlutterBluePlus.connectedDevices.first;
      // Discover specific service
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              _writeCharacteristic = characteristic;
              if (characteristic.properties.notify &&
                  !_writeCharacteristic!.isNotifying) {
                await _writeCharacteristic!.setNotifyValue(true);
              }
              break;
            }
          }
        }
        if (_writeCharacteristic != null) break;
      }
    } catch (e) {
      print("Error finding characteristic: $e");
    }

    if (mounted) {
      setState(() => _isConnecting = false);
    }
  }

  Future<bool> _checkConnectionAndProceed() async {
    // 1. Check if already connected
    if (FlutterBluePlus.connectedDevices.isNotEmpty) {
      if (_writeCharacteristic == null) {
        await _findWriteCharacteristic();
      }
      return _writeCharacteristic != null;
    }

    setState(() => _isConnecting = true);

    // 2. Try Auto-Reconnect
    final prefs = await SharedPreferences.getInstance();
    final String? deviceId = prefs.getString('device_id');

    bool reconnected = false;
    if (deviceId != null) {
      try {
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 5),
          withServices: [],
        );

        // Wait for specific device to appear in scan results
        ScanResult r = await FlutterBluePlus.scanResults
            .expand((results) => results)
            .where((r) => r.device.remoteId.toString() == deviceId)
            .first
            .timeout(const Duration(seconds: 5));

        await FlutterBluePlus.stopScan();
        await r.device.connect();

        // Brief delay to allow services to discover
        await Future.delayed(const Duration(milliseconds: 500));
        reconnected = true;
      } catch (e) {
        print("Auto-connect logic error: $e");
      }
    }

    if (reconnected) {
      await _findWriteCharacteristic();
      setState(() => _isConnecting = false);
      return _writeCharacteristic != null;
    }

    setState(() => _isConnecting = false);

    // 3. Show Failure Dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            "Connection Failed",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Unable to connect to Smart Pill Box.",
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Text(
                "Remedies:\n• Ensure device is powered ON.\n• Move closer to the device.\n• Restart Bluetooth on phone.",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Try Again"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceScanScreen(),
                  ),
                );
              },
              child: const Text("Scan for Device"),
            ),
          ],
        ),
      );
    }
    return false;
  }

  Future<void> _sendCommand(String cmd) async {
    if (_writeCharacteristic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device not connected or ready')),
      );
      return;
    }

    try {
      await _writeCharacteristic!.write(utf8.encode(cmd));
      print("Sent: $cmd");
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  void _promptNameAndEnroll(int id) {
    TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Enroll Fingerprint",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Step 1: Name this fingerprint",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Name (e.g. 'Mom', 'Dad')",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context); // Close Name Dialog
                _startBleEnrollment(id, nameController.text.trim());
              }
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  void _startBleEnrollment(int id, String name) async {
    // 1. Connection Check
    bool isConnected = await _checkConnectionAndProceed();
    if (!isConnected || _writeCharacteristic == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected. Try scanning again.')),
        );
      }
      return;
    }

    if (!mounted) return;

    // UI Notifiers
    ValueNotifier<String> statusMessage = ValueNotifier(
      "Initializing System...",
    );
    ValueNotifier<double> progress = ValueNotifier(0.0);
    ValueNotifier<bool> showFingerprintUI = ValueNotifier(false);

    // Cancellation Flag
    bool isCancelled = false;
    StreamSubscription? subscription;

    // Show Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          elevation: 10,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Icon
                ValueListenableBuilder<bool>(
                  valueListenable: showFingerprintUI,
                  builder: (_, show, __) {
                    return SizedBox(
                      height: 100,
                      child: show
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: ValueListenableBuilder<double>(
                                    valueListenable: progress,
                                    builder: (_, p, __) =>
                                        CircularProgressIndicator(
                                      value: p,
                                      strokeWidth: 8,
                                      backgroundColor: const Color(
                                        0xFFF0F0F0,
                                      ),
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFF4A90E2),
                                      ),
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 48,
                                  color: Color(0xFF4A90E2),
                                ),
                              ],
                            )
                          : const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation(
                                  Color(0xFF4A90E2),
                                ),
                              ),
                            ),
                    );
                  },
                ),

                const SizedBox(height: 24),
                Text(
                  "Enrolling: $name",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions
                ValueListenableBuilder<String>(
                  valueListenable: statusMessage,
                  builder: (_, msg, __) => Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2D3436), // Professional Dark Grey
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      isCancelled = true;
                      try {
                        if (_writeCharacteristic != null) {
                          await _writeCharacteristic!.write(
                            utf8.encode("cancel_fp"),
                          );
                          print("Sent: cancel_fp");
                        }
                      } catch (e) {
                        print("Error sending cancel: $e");
                      }
                      subscription?.cancel();
                      if (mounted) Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      Completer<String> _responseCompleter = Completer();

      subscription = _writeCharacteristic!.lastValueStream.listen((value) {
        String msg = utf8.decode(value).trim();
        print("Stream received: $msg");
        if (!_responseCompleter.isCompleted && msg == "ok") {
          _responseCompleter.complete(msg);
        }
      });

      Future<void> sendAndWait(
        String cmd,
        String stepName,
        double progressVal,
      ) async {
        if (isCancelled) return;

        print("--- Step: $stepName ---");
        if (mounted) progress.value = progressVal;

        _responseCompleter = Completer();

        if (cmd.isNotEmpty) {
          await _writeCharacteristic!.write(utf8.encode(cmd));
          print("Sent: $cmd");
        }

        await _responseCompleter.future.timeout(const Duration(seconds: 45));

        if (isCancelled) throw "Cancelled by User";
        print("Step $stepName: Success");
      }

      // 1. Handshake
      statusMessage.value = "Connecting...";
      await sendAndWait("fingerprint", "Handshake", 0.0);
      if (isCancelled) return;

      // 2. Index
      statusMessage.value = "Initializing Sensor...";
      await sendAndWait(id.toString(), "Send ID", 0.1);
      if (isCancelled) return;

      // Show UI
      if (mounted) showFingerprintUI.value = true;

      // 3. Place 1
      statusMessage.value = "Place your finger on the sensor";
      await sendAndWait("", "Place Finger 1", 0.4);
      if (isCancelled) return;

      // 4. Remove
      statusMessage.value = "Remove your finger";
      await sendAndWait("", "Remove Finger", 0.7);
      if (isCancelled) return;

      // 5. Confirm
      statusMessage.value = "Place the same finger again";
      await sendAndWait("", "Place Finger 2", 0.9);
      if (isCancelled) return;

      // Success
      if (mounted) {
        statusMessage.value = "Fingerprint Enrolled Successfully";
        progress.value = 1.0;

        // SAVE LOCALLY HERE
        setState(() {
          var slot = _slots.firstWhere((s) => s['id'] == id);
          slot['name'] = name;
          slot['active'] = true;
        });
        _saveSlots();
        _sendCommand("add_fp:$id:$name"); // Optional sync to device if needed
      }
      await Future.delayed(const Duration(milliseconds: 1000));

      await subscription.cancel();
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      print("Flow Error: $e");
      subscription?.cancel();

      if (!isCancelled && mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Enrollment Failed: $e')));
      }
    }
  }

  void _handleRemove(int id) async {
    bool isConnected = await _checkConnectionAndProceed();
    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not connected. Please scan for device.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Remove Fingerprint?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete this fingerprint?",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              setState(() {
                var slot = _slots.firstWhere((s) => s['id'] == id);
                slot['name'] = null;
                slot['active'] = false;
              });
              _saveSlots(); // Save changes
              _sendCommand("FP_DEL:$id"); // Tell ESP32 to delete ID
              Navigator.pop(context);
            },
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Manage Fingerprints",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D3436),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3436)),
      ),
      body: _isConnecting
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final bool isActive = slot['active'];
                final int id = slot['id'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fingerprint_rounded,
                          color: isActive ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isActive
                                  ? (slot['name'] ?? "User $id")
                                  : "Empty Slot $id",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isActive
                                    ? const Color(0xFF2D3436)
                                    : Colors.grey[400],
                              ),
                            ),
                            Text(
                              isActive ? "Active" : "Available",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isActive ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isActive)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                          onPressed: () => _handleRemove(id),
                        )
                      else
                        ElevatedButton(
                          onPressed: () => _promptNameAndEnroll(id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Add"),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
