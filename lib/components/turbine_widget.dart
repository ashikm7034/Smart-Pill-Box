import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class TurbineWidget extends StatefulWidget {
  final List<Map<String, String>> slots;
  final Function(int)? onSlotTap;

  const TurbineWidget({super.key, required this.slots, this.onSlotTap});

  @override
  State<TurbineWidget> createState() => _TurbineWidgetState();
}

class _TurbineWidgetState extends State<TurbineWidget>
    with SingleTickerProviderStateMixin {
  double _rotationAngle = 0.0;
  int _lastFeedbackIndex = -1;

  // Snap/magnetism effect could be added here later.

  int _calculateActiveIndex() {
    final int totalSlots = widget.slots.length; // Should be 15
    final double anglePerSlot = 2 * pi / totalSlots;

    int closestIndex = 0;
    double minDistance = 1000.0;

    for (int i = 0; i < totalSlots; i++) {
      double slotCenterAngle = i * anglePerSlot + _rotationAngle - pi / 2;
      // Normalize angle difference to [-pi, pi]
      double diff = (slotCenterAngle - (-pi / 2)) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      if (diff < -pi) diff += 2 * pi;

      if (diff.abs() < minDistance) {
        minDistance = diff.abs();
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  @override
  Widget build(BuildContext context) {
    int activeIndex = _calculateActiveIndex();

    return LayoutBuilder(
      builder: (context, constraints) {
        double size = min(constraints.maxWidth, constraints.maxHeight);
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none, // Allow arrow to float outside
            alignment: Alignment.center,
            children: [
              // The Spinning Wheel
              GestureDetector(
                onPanUpdate: (details) {
                  // Calculate angular delta for rotation
                  final center = Offset(size / 2, size / 2);
                  final touch = details.localPosition;
                  final prevTouch = touch - details.delta;

                  final angle = atan2(
                    touch.dy - center.dy,
                    touch.dx - center.dx,
                  );
                  final prevAngle = atan2(
                    prevTouch.dy - center.dy,
                    prevTouch.dx - center.dx,
                  );

                  setState(() {
                    _rotationAngle += (angle - prevAngle);

                    // Haptic Feedback Logic
                    int newIndex = _calculateActiveIndex();
                    if (newIndex != _lastFeedbackIndex) {
                      HapticFeedback.mediumImpact();
                      _lastFeedbackIndex = newIndex;
                    }
                  });
                },
                onTapUp: (details) {
                  // Optional: Tap logic on wheel itself
                },
                child: CustomPaint(
                  size: Size(size, size),
                  painter: TurbinePainter(
                    slots: widget.slots,
                    rotation: _rotationAngle,
                  ),
                ),
              ),

              // Fixed Premium Arrow Indicator
              Positioned(
                top: -45,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.grey.shade200],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 28,
                      color: Color(0xFF002F6C), // Deep Blue to match brand
                    ),
                  ),
                ),
              ),

              // Fixed Center Hub (Clickable)
              GestureDetector(
                onTap: () {
                  if (widget.onSlotTap != null) {
                    widget.onSlotTap!(activeIndex);
                  }
                },
                child: Container(
                  width: size * 0.35,
                  height: size * 0.35,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Center(child: _buildCenterText(activeIndex)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCenterText(int index) {
    // Get Data for the active slot
    // Safety check just in case
    if (index < 0 || index >= widget.slots.length) return SizedBox();

    final slot = widget.slots[index];
    final slotNum = slot['slot'] ?? "${index + 1}";
    String dateText = slot['date'] ?? ""; // e.g. "JAN 14"
    String timeText = slot['time'] ?? "NO TIME";

    // Formatting Date: "JAN 14" -> "JAN\n14" or just "JAN 14"
    // User wants: "arrow selected date and time also slot"

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Slot Label
        Text(
          "SLOT $slotNum",
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),

        // Time (HERO - Highlighted as requested)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            timeText,
            style: GoogleFonts.poppins(
              fontSize: 20, // Slightly smaller base
              color: const Color(0xFF002F6C),
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),

        SizedBox(height: 2),

        // Date (Secondary)
        Text(
          dateText.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF4A90E2),
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(height: 6),

        // Edit Hint
        Icon(Icons.edit_rounded, size: 12, color: Colors.grey[400]),
      ],
    );
  }
}

class TurbinePainter extends CustomPainter {
  final List<Map<String, String>> slots;
  final int totalSlots = 15;
  final double rotation;

  TurbinePainter({required this.slots, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    // Dimensions
    final bezelWidth = 12.0;
    final innerRadius = radius * 0.35;
    final wheelRadius = radius - bezelWidth;

    // 1. Draw Outer Bezel Base Shadow
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Colors.black.withOpacity(0.3),
      10.0,
      true,
    );

    // 2. Draw Bezel
    final bezelPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.grey[200]!, Colors.grey[400]!],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bezelPaint);

    final innerBezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 1, innerBezelPaint);

    final anglePerSlot = 2 * pi / totalSlots;
    final dividerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // 3. Draw Slots
    // First pass: Draw all normal slots
    // We also need to identify the active one (closest to top -pi/2) to skip or redraw.
    int closestIndex = -1;
    double minDistance = 1000.0;

    for (int i = 0; i < totalSlots; i++) {
      double slotCenterAngle = i * anglePerSlot + rotation - pi / 2;
      // Normalize angle difference to [-pi, pi]
      double diff = (slotCenterAngle - (-pi / 2)) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      if (diff < -pi) diff += 2 * pi;

      if (diff.abs() < minDistance) {
        minDistance = diff.abs();
        closestIndex = i;
      }
    }

    for (int i = 0; i < totalSlots; i++) {
      // Draw normal slots. If it's active, we draw it later OR we draw it here and overlay?
      // Let's draw it here normally first.
      _drawSlot(
        canvas,
        center,
        wheelRadius,
        innerRadius,
        anglePerSlot,
        i,
        false,
      );
    }

    // Draw Dividers
    for (int i = 0; i < totalSlots; i++) {
      double startAngle = i * anglePerSlot + rotation - pi / 2;
      final p1 = Offset(
        center.dx + innerRadius * cos(startAngle),
        center.dy + innerRadius * sin(startAngle),
      );
      final p2 = Offset(
        center.dx + wheelRadius * cos(startAngle),
        center.dy + wheelRadius * sin(startAngle),
      );
      canvas.drawLine(p1, p2, dividerPaint);
    }

    // 4. Draw ACTIVE Slot Magnified (Pop-out effect)
    if (closestIndex != -1 && minDistance < anglePerSlot / 1.2) {
      // Pop out radius!
      // We expand outward beyond the wheel radius slightly
      // and inward into the hub slightly for max text space.
      _drawSlot(
        canvas,
        center,
        wheelRadius + 12,
        innerRadius - 8,
        anglePerSlot,
        closestIndex,
        true,
      );

      // Highlight Border for Active Slot
      double startAngle = closestIndex * anglePerSlot + rotation - pi / 2;
      final activeBorderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;

      final slotPath = Path();
      slotPath.arcTo(
        Rect.fromCircle(center: center, radius: wheelRadius + 12),
        startAngle,
        anglePerSlot,
        false,
      );
      slotPath.arcTo(
        Rect.fromCircle(center: center, radius: innerRadius - 8),
        startAngle + anglePerSlot,
        -anglePerSlot,
        false,
      );
      slotPath.close();
      canvas.drawPath(slotPath, activeBorderPaint);
    }
  }

  void _drawSlot(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
    double anglePerSlot,
    int i,
    bool isActive,
  ) {
    double startAngle = i * anglePerSlot + rotation - pi / 2;

    // Color Logic
    Color colorStart = Colors.grey[200]!;
    Color colorEnd = Colors.grey[400]!;
    String timeText = "";
    String slotNumber = "${i + 1}";
    String dateText = "";

    var slotData = slots.firstWhere(
      (element) => element['slot'] == "${i + 1}",
      orElse: () => {},
    );
    if (slotData.isNotEmpty) {
      String status = slotData['status']?.toLowerCase() ?? "empty";
      if (status == 'taken') {
        colorStart = const Color(0xFF81C784);
        colorEnd = const Color(0xFF2E7D32);
      } else if (status == 'missed') {
        colorStart = const Color(0xFFE57373);
        colorEnd = const Color(0xFFC62828);
      } else if (status == 'scheduled') {
        colorStart = const Color(0xFF64B5F6);
        colorEnd = const Color(0xFF1565C0);
      } else {
        colorStart = const Color(0xFFF5F5F5);
        colorEnd = const Color(0xFFBDBDBD);
      }
      timeText = slotData['time'] ?? "";
      if (slotData['date'] != null) {
        dateText = slotData['date']!.toUpperCase();
      }
    }

    final slotPath = Path();
    slotPath.arcTo(
      Rect.fromCircle(center: center, radius: outerR),
      startAngle,
      anglePerSlot,
      true,
    );
    slotPath.arcTo(
      Rect.fromCircle(center: center, radius: innerR),
      startAngle + anglePerSlot,
      -anglePerSlot,
      false,
    );
    slotPath.close();

    final slotPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [colorStart, colorEnd],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));

    // Draw Shadow for active slot to make it pop?
    if (isActive) {
      canvas.drawShadow(slotPath, Colors.black.withOpacity(0.4), 8.0, true);
    }

    canvas.drawPath(slotPath, slotPaint);

    // Draw Text
    // Calculate center angle for text placement
    _drawText(
      canvas,
      center,
      outerR,
      innerR,
      startAngle + anglePerSlot / 2,
      slotNumber,
      dateText,
      timeText,
      slotData.isEmpty || slotData['status'] == 'empty',
      isActive,
    );
  }

  void _drawText(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double innerRadius,
    double angle,
    String slotNo,
    String dateText,
    String time,
    bool isEmpty,
    bool isActive,
  ) {
    final textColor = isEmpty
        ? (Colors.grey[600] ?? Colors.grey)
        : Colors.white;

    // 1. SLOT NUMBER (Outer Edge)
    // Move it slightly inwards if active to avoid arrow overlap
    double slotRadius = outerRadius - (isActive ? 28 : 18);
    Offset slotPos =
        center + Offset(slotRadius * cos(angle), slotRadius * sin(angle));

    canvas.save();
    canvas.translate(slotPos.dx, slotPos.dy);
    canvas.rotate(angle + pi / 2);

    final slotPainter = TextPainter(
      text: TextSpan(
        text: isActive ? "SLOT $slotNo" : slotNo,
        style: GoogleFonts.poppins(
          color: textColor.withOpacity(isActive ? 1.0 : 0.7),
          fontSize: isActive
              ? 9
              : 12, // Smaller when active to make room for date
          fontWeight: isActive ? FontWeight.w600 : FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    slotPainter.layout();
    slotPainter.paint(
      canvas,
      Offset(-slotPainter.width / 2, -slotPainter.height / 2),
    );
    canvas.restore();

    // 2. DATE (Center Body)
    // WE STACK IT TO FIT BETTER!
    // "14" (Big)
    // "JAN" (Small)
    double dateRadius = (outerRadius + innerRadius) / 2;
    // slightly adjust active date position upwards (towards outer) to clear time
    if (isActive) dateRadius += 2;

    Offset datePos =
        center + Offset(dateRadius * cos(angle), dateRadius * sin(angle));

    canvas.save();
    canvas.translate(datePos.dx, datePos.dy);
    canvas.rotate(angle + pi / 2);

    // active: Stacked Big Day, Small Month
    // inactive: Stacked Small Day, Small Month

    // Parse Date: "JAN 14" -> ["JAN", "14"]
    String day = "";
    String month = "";
    if (dateText.contains(" ")) {
      var parts = dateText.split(" ");
      if (parts.length > 1) {
        month = parts[0]; // JAN
        day = parts[1]; // 14
      } else {
        day = dateText;
      }
    } else {
      day = dateText;
    }

    final dateSpan = TextSpan(
      children: [
        TextSpan(
          text: "$day\n",
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: isActive ? 24 : 14, // Big Day
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            height: 1.0,
          ),
        ),
        TextSpan(
          text: month,
          style: GoogleFonts.poppins(
            color: textColor.withOpacity(0.9),
            fontSize: isActive ? 10 : 8, // Small Month
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );

    final datePainter = TextPainter(
      text: dateSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    datePainter.layout();
    datePainter.paint(
      canvas,
      Offset(-datePainter.width / 2, -datePainter.height / 2), // centered
    );
    canvas.restore();

    // 3. TIME (Inner Edge)
    if (time.isNotEmpty) {
      // Push time closer to hub if active to separate from Date
      double timeRadius = innerRadius + (isActive ? 22 : 22);
      Offset timePos =
          center + Offset(timeRadius * cos(angle), timeRadius * sin(angle));

      canvas.save();
      canvas.translate(timePos.dx, timePos.dy);
      canvas.rotate(angle + pi / 2);

      final timePainter = TextPainter(
        text: TextSpan(
          text: time.replaceAll(' ', '\n'),
          style: GoogleFonts.poppins(
            color: textColor.withOpacity(0.8),
            fontSize: isActive ? 9 : 8,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      timePainter.layout();
      timePainter.paint(
        canvas,
        Offset(-timePainter.width / 2, -timePainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
