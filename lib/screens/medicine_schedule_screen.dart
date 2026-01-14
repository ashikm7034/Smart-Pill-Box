import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/turbine_widget.dart';

class MedicineScheduleScreen extends StatefulWidget {
  const MedicineScheduleScreen({super.key});

  @override
  State<MedicineScheduleScreen> createState() => _MedicineScheduleScreenState();
}

class _MedicineScheduleScreenState extends State<MedicineScheduleScreen> {
  // Mock Data for 15 slots
  final List<Map<String, String>> _slotData = [
    {"slot": "1", "time": "08:00 AM", "status": "taken"},
    {"slot": "2", "time": "12:00 PM", "status": "missed"},
    {"slot": "3", "time": "06:00 PM", "status": "scheduled"},
    {"slot": "4", "time": "09:00 PM", "status": "empty"},
    // ... we can fill others dynamically or leave empty
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Pill Box Schedule",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem("Taken", const Color(0xFF66BB6A)),
                const SizedBox(width: 8),
                _buildLegendItem("Scheduled", const Color(0xFF42A5F5)),
                const SizedBox(width: 8),
                _buildLegendItem("Missed", const Color(0xFFEF5350)),
                const SizedBox(width: 8),
                _buildLegendItem("Empty", Colors.grey[300]!),
              ],
            ),
            const SizedBox(height: 30),

            // Turbine UI
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: TurbineWidget(slots: _slotData),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Instructions / Info
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "This visual representation shows the configuration of your 15-slot Smart Pill Box.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ],
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
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    );
  }
}
