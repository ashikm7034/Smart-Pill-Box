import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen>
    with SingleTickerProviderStateMixin {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    var status = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (status[Permission.bluetoothScan]!.isGranted &&
        status[Permission.bluetoothConnect]!.isGranted) {
      _startScan();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth permissions are required.')),
        );
      }
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
    });

    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          // FILTER: Only show devices starting with "Smart Pill"
          _scanResults = results
              .where(
                (r) =>
                    r.device.platformName.startsWith("Smart Pill") ||
                    r.device.localName.startsWith("Smart Pill"),
              )
              .toList();
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      print("Error starting scan: $e");
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  void _skipScan() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  bool _isConnecting = false;

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
    });

    await FlutterBluePlus.stopScan();

    try {
      await device.connect();

      // Discover services & Send "givedata"
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              await characteristic.write(utf8.encode("givedata"));
            }
          }
        }
      }

      // Save Device ID
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_id', device.remoteId.toString());
      } catch (e) {
        print("Error saving device ID: $e");
      }

      if (mounted) {
        // FORCE NAVIGATION: Clear stack and go to Dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Scan Device",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2D3436),
                            ),
                          ),
                          Text(
                            "Find your Smart Pill Box",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _skipScan,
                        child: Text(
                          "SKIP",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isScanning ? _stopScan : _startScan,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isScanning ? _pulseAnimation.value : 1.0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isScanning
                                      ? Colors.redAccent.withOpacity(0.1)
                                      : const Color(
                                          0xFF4A90E2,
                                        ).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isScanning
                                      ? Icons.stop_rounded
                                      : Icons.search_rounded,
                                  color: _isScanning
                                      ? Colors.redAccent
                                      : const Color(0xFF4A90E2),
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Scan Animation / Empty State
                if (_isScanning && _scanResults.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(
                                      0xFF4A90E2,
                                    ).withOpacity(0.1),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.bluetooth_searching_rounded,
                                size: 60,
                                color: Color(0xFF4A90E2),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Searching for devices...",
                            style: GoogleFonts.poppins(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!_isScanning && _scanResults.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_other_rounded,
                            size: 60,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No smart pill device found",
                            style: GoogleFonts.poppins(color: Colors.grey[500]),
                          ),
                          TextButton(
                            onPressed: _startScan,
                            child: Text(
                              "Try Again",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF4A90E2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // Device List
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        final result = _scanResults[index];
                        final name = result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : result.device.localName;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _connectToDevice(result.device),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE3F2FD),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: const Icon(
                                        Icons.medication_liquid_rounded,
                                        color: Color(0xFF1565C0),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name.isNotEmpty
                                                ? name
                                                : "Unknown Device",
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: const Color(0xFF2D3436),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            result.device.remoteId.toString(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A90E2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "Connect",
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isConnecting)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        "Connecting...",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
