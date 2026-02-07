import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_scan_screen.dart';
import 'fingerprint_screen.dart';
import 'dart:convert';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _savedDeviceId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedDeviceId = prefs.getString('device_id');
      _isLoading = false;
    });
  }

  Future<void> _disconnectDevice({bool showSnackBar = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('device_id');

    // Disconnect if currently connected
    if (FlutterBluePlus.connectedDevices.isNotEmpty) {
      for (var device in FlutterBluePlus.connectedDevices) {
        await device.disconnect();
      }
    }

    setState(() {
      _savedDeviceId = null;
    });

    if (showSnackBar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device Disconnected & Forgotten')),
      );
    }
  }

  void _connectDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeviceScanScreen()),
    ).then((_) => _loadSettings());
  }

  Future<void> _changeDevice() async {
    await _disconnectDevice(showSnackBar: false);
    if (mounted) {
      _connectDevice();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Settings",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D3436),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3436)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle("Device Connection"),
                const SizedBox(height: 10),
                Container(
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
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _savedDeviceId != null
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _savedDeviceId != null
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth_disabled,
                              color: _savedDeviceId != null
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _savedDeviceId != null
                                      ? "Paired Device"
                                      : "No Device Paired",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_savedDeviceId != null)
                                  Text(
                                    "ID: $_savedDeviceId",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_savedDeviceId != null) ...[
                        const Divider(height: 30),
                        // Reconnect / Connect
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _connectDevice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Reconnect",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Change Device
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _changeDevice,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4A90E2),
                              side: const BorderSide(color: Color(0xFF4A90E2)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Change Device",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Forget Device
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => _disconnectDevice(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              "Forget Device",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const Divider(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _connectDevice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "Connect Device",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Security Section
                const SizedBox(height: 20),
                _buildSectionTitle("Security"),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
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
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8EAF6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: Color(0xFF3F51B5),
                      ),
                    ),
                    title: Text(
                      "Manage Fingerprints",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      "Add or remove users",
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FingerprintScreen(),
                        ),
                      );
                    },
                  ),
                ),

                // Smart Bands Section
                const SizedBox(height: 20),
                _buildSectionTitle("Smart Bands"),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
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
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFEBEE), // Red tint
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                        title: Text(
                          "Connect Patient Band",
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "Pair with the Patient's Watch",
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () => _connectToBand("Patient Band"),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9), // Green tint
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.people_rounded,
                            color: Colors.green,
                          ),
                        ),
                        title: Text(
                          "Connect Bystander Band",
                          style:
                              GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "Pair with the Bystander's Watch",
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () => _connectToBand("Bystander Band"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 1.0,
      ),
    );
  }

  Future<void> _connectToBand(String bandType) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const DeviceScanScreen(targetName: "Smart Pill Band"),
      ),
    );

    if (result != null && result is BluetoothDevice) {
      if (mounted) {
        _showWiFiConfigDialog(bandType, result);
      }
    }
  }

  Future<void> _showWiFiConfigDialog(
      String bandType, BluetoothDevice device) async {
    final TextEditingController ssidController = TextEditingController();
    final TextEditingController passController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Connect $bandType to WiFi",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssidController,
                decoration: InputDecoration(
                  labelText: "WiFi Name (SSID)",
                  labelStyle: GoogleFonts.poppins(),
                  prefixIcon: const Icon(Icons.wifi),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passController,
                decoration: InputDecoration(
                  labelText: "WiFi Password",
                  labelStyle: GoogleFonts.poppins(),
                  prefixIcon: const Icon(Icons.lock),
                ),
                obscureText: true,
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
                String ssid = ssidController.text.trim();
                String pass = passController.text.trim();

                if (ssid.isNotEmpty && pass.isNotEmpty) {
                  Navigator.pop(context);
                  _sendWiFiToDevice(device, ssid, pass);
                }
              },
              child: Text("Connect", style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendWiFiToDevice(
      BluetoothDevice device, String ssid, String pass) async {
    try {
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      bool sent = false;

      // Look for our specific characteristic or write to ANY writable characteristic for now
      // Since we controlled the firmware, we know the UUIDs in esp32_watch.ino:
      // SERVICE: 12345678-1234-1234-1234-1234567890ab
      // CHAR: abcdef01-1234-5678-1234-567890abcdef

      // Targeted UUIDs from esp32_watch.ino
      const String SERVICE_UUID = "12345678-1234-1234-1234-1234567890ab";
      const String CHAR_UUID = "abcdef01-1234-5678-1234-567890abcdef";

      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == CHAR_UUID) {
              print("Found Watch Characteristic: $CHAR_UUID");
              String cmd = "WIFI:$ssid:$pass";
              await characteristic.write(utf8.encode(cmd));
              sent = true;
              break;
            }
          }
        }
        if (sent) break;
      }

      if (!sent) {
        // Fallback: Try any writable if specific not found (unlikely but safe)
        print("Specific UUID not found, trying generic fallback...");
        for (var service in services) {
          for (var characteristic in service.characteristics) {
            if (characteristic.properties.write) {
              String cmd = "WIFI:$ssid:$pass";
              await characteristic.write(utf8.encode(cmd));
              sent = true;
              break;
            }
          }
          if (sent) break;
        }
      }

      if (sent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("WiFi Credentials Sent!")),
          );
        }

        // Add delay to ensure packet flushing before disconnect
        await Future.delayed(const Duration(milliseconds: 1000));

        // Disconnect immediately as requested
        await device.disconnect();
        print("Device disconnected after sending WiFi config.");
      } else {
        throw "No writable characteristic found";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending data: $e")),
        );
      }
    }
  }
}
