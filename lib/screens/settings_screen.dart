import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'device_scan_screen.dart';
import 'fingerprint_screen.dart';

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
}
