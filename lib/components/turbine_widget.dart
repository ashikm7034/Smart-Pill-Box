import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class TurbineController {
  _TurbineWidgetState? _state;

  void _bind(_TurbineWidgetState state) {
    _state = state;
  }

  /// Animates the wheel to position the given slot index [1-15] at the top.
  Future<void> animateToSlot(int slotIndex) async {
    if (_state != null) {
      await _state!._animateToSlot(slotIndex);
    }
  }
}

class TurbineWidget extends StatefulWidget {
  final List<Map<String, String>> slots;
  final Function(int)? onSlotTap;
  final TurbineController? controller;

  const TurbineWidget({
    super.key,
    required this.slots,
    this.onSlotTap,
    this.controller,
  });

  @override
  State<TurbineWidget> createState() => _TurbineWidgetState();
}

class _TurbineWidgetState extends State<TurbineWidget>
    with TickerProviderStateMixin {
  double _rotationAngle = 0.0;
  int _lastFeedbackIndex = -1;
  late AnimationController _animController;
  late Animation<double> _animation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    widget.controller?._bind(this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animController.addListener(() {
      setState(() {
        _rotationAngle = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _animateToSlot(int slotIndex) async {
    // 0-indexed internal, but input is 1-15
    int targetIndex = slotIndex - 1;

    final int totalSlots = 15;
    final double anglePerSlot = 2 * pi / totalSlots;
    final double halfSlot = anglePerSlot / 2;

    // Formula: rotation = -(targetIndex * anglePerSlot + halfSlot)
    // This aligns the Center of the slot to 0 radians (Right) relative to "rotation".
    // But we want it at -pi/2 (Top).
    // Wait, let's re-derive based on Painter logic:
    // Painter: startAngle = i*angle + rotation - pi/2
    // CenterAngle = startAngle + halfSlot = i*angle + rotation - pi/2 + halfSlot
    // We want CenterAngle to be -pi/2 (Top visual)
    // -pi/2 = i*angle + rotation - pi/2 + halfSlot
    // 0 = i*angle + rotation + halfSlot
    // rotation = -(i*angle + halfSlot)

    double targetRot = -(targetIndex * anglePerSlot + halfSlot);

    // Ensure we spin in one direction (Clockwise? Decreasing rotation?).
    // Make targetRot strictly smaller than currentRot to spin "back" or "forward".
    // Let's add full rotations to make it look active.

    double currentRot = _rotationAngle;

    // Adjust targetRot to be the closest equivalent less than currentRot
    while (targetRot > currentRot) {
      targetRot -= 2 * pi;
    }
    // Now targetRot <= currentRot.
    // If it's too close, add a full spin for effect.
    if ((currentRot - targetRot).abs() < 0.1) {
      targetRot -= 2 * pi;
    }

    // Add intentional full spin? User said "rotate 1 direction".
    // Let's just ensure it goes to the target.
    // If it's too far (e.g. > 2 spins), maybe clamp?
    // No, "Save & Next" implies small steps. "Slot 1" from "Slot 14" is a big spin.

    _animation = Tween<double>(begin: currentRot, end: targetRot).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    await _animController.forward(from: 0.0);

    setState(() {
      _rotationAngle = targetRot;
    });
  }

  int _calculateActiveIndex() {
    final int totalSlots = widget.slots.length; // Should be 15
    final double anglePerSlot = 2 * pi / totalSlots;
    final double halfSlot = anglePerSlot / 2;

    int closestIndex = 0;
    double minDistance = 1000.0;

    for (int i = 0; i < totalSlots; i++) {
      // Center of the slot in visual terms
      double slotCenterAngle =
          i * anglePerSlot + _rotationAngle - pi / 2 + halfSlot;

      // Normalize angle difference to [-pi, pi] relative to Top (-pi/2)
      // Actually, standardizing checking diff to -pi/2 is tricky with mod.
      // Easier: Check diff to -pi/2

      double diff = (slotCenterAngle - (-pi / 2));
      // Normalize diff to -pi..pi
      while (diff > pi) diff -= 2 * pi;
      while (diff < -pi) diff += 2 * pi;

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

                    // Haptic & Sound Feedback Logic
                    int newIndex = _calculateActiveIndex();
                    if (newIndex != _lastFeedbackIndex) {
                      HapticFeedback.mediumImpact();
                      // Play Click Sound Rapidly
                      _audioPlayer.stop();
                      _audioPlayer.play(AssetSource('sounds/click.mp3'),
                          mode: PlayerMode.lowLatency);

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
                  // DISABLE click for Slot 15 (Index 14) -> Door
                  if (activeIndex == 14) return;

                  if (widget.onSlotTap != null) {
                    widget.onSlotTap!(activeIndex + 1);
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
    // SPECIAL CASE: Slot 15 is the Door/Opening
    if (index == 14) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.door_sliding_rounded, size: 32, color: Colors.grey[400]),
          const SizedBox(height: 4),
          Text(
            "DOOR",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            "OPENING SIDE",
            style: GoogleFonts.poppins(
              fontSize: 8,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Get Data for the active slot
    // Safety check just in case
    if (index < 0 || index >= widget.slots.length) return SizedBox();

    final slot = widget.slots[index];
    final slotNum = slot['slot'] ?? "${index + 1}";
    String dateText = slot['date'] ?? ""; // e.g. "JAN 14"
    String timeText = slot['time'] ?? "NO TIME";

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
    int closestIndex = -1;
    double minDistance = 1000.0;

    for (int i = 0; i < totalSlots; i++) {
      double slotCenterAngle = i * anglePerSlot + rotation - pi / 2;
      double diff = (slotCenterAngle - (-pi / 2)) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      if (diff < -pi) diff += 2 * pi;

      if (diff.abs() < minDistance) {
        minDistance = diff.abs();
        closestIndex = i;
      }
    }

    for (int i = 0; i < totalSlots; i++) {
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

    // Color Logic (Premium / Vibrant Palette)
    Color colorStart = Colors.white;
    Color colorEnd = const Color(0xFFF5F7FA); // Soft Silver
    String timeText = "";
    String slotNumber = "${i + 1}";
    String dateText = "";
    bool isDoor = (i == 14); // Index 14 is Slot 15

    if (isDoor) {
      // Door: Premium Matte Gunmetal
      colorStart = const Color(0xFF232526);
      colorEnd = const Color(0xFF414345);
    } else {
      var slotData = slots.firstWhere(
        (element) => element['slot'] == "${i + 1}",
        orElse: () => {},
      );
      if (slotData.isNotEmpty) {
        String status = slotData['status']?.toLowerCase() ?? "empty";
        if (status == 'taken') {
          // Success/Done: Metallic Gray (History)
          colorStart = const Color(0xFF757F9A);
          colorEnd = const Color(0xFFD7DDE8);
        } else if (status == 'missed') {
          // Alert: Coral -> Orange
          colorStart = const Color(0xFFFF5F6D);
          colorEnd = const Color(0xFFFFC371);
        } else if (status == 'scheduled') {
          // Future: Cyan -> Royal Blue
          colorStart = const Color(0xFF36D1DC);
          colorEnd = const Color(0xFF5B86E5);
        } else if (status == 'timeup') {
          // Time Up: Green (Actionable)
          colorStart = const Color(0xFF00B09B);
          colorEnd = const Color(0xFF96C93D);
        } else {
          // Empty: Light Gray
          colorStart = Colors.grey[300]!;
          colorEnd = Colors.grey[400]!;
        }
        timeText = slotData['time'] ?? "";
        if (slotData['date'] != null) {
          dateText = slotData['date']!.toUpperCase();
        }
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

    if (isActive) {
      canvas.drawShadow(slotPath, Colors.black.withOpacity(0.4), 8.0, true);
    }

    canvas.drawPath(slotPath, slotPaint);

    // Draw Text
    _drawText(
      canvas,
      center,
      outerR,
      innerR,
      startAngle + anglePerSlot / 2,
      slotNumber,
      dateText,
      timeText,
      !isDoor && (timeText.isEmpty),
      isActive,
      isDoor,
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
    bool isDoor,
  ) {
    // 1. SLOT NUMBER / DOOR LABEL (Outer Edge)
    // Shifted slightly closer to edge for cleaner look
    double slotRadius = outerRadius - (isActive ? 22 : 15);
    Offset slotPos =
        center + Offset(slotRadius * cos(angle), slotRadius * sin(angle));

    canvas.save();
    canvas.translate(slotPos.dx, slotPos.dy);
    canvas.rotate(angle + pi / 2);

    // Shows just "4" instead of "SLOT 4" to match image style
    final slotText = isDoor ? "DOOR" : slotNo;
    final slotColor = isDoor
        ? Colors.grey[400]!.withOpacity(0.8)
        : (isEmpty ? const Color(0xFF2D3436) : Colors.white);

    final slotPainter = TextPainter(
      text: TextSpan(
        text: slotText,
        style: GoogleFonts.poppins(
          color: slotColor,
          fontSize: (isActive || isDoor) ? 10 : 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
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

    if (isDoor) return; // Skip Date/Time for Door

    // 2. PARSE DATE (Day vs Month)
    String day = "";
    String month = "";
    if (dateText.contains(" ")) {
      var parts = dateText.split(" ");
      // Assuming format "MMM d" (Jan 14)
      if (parts.length > 1) {
        month = parts[0];
        day = parts[1];
      } else {
        day = dateText;
      }
    } else {
      day = dateText;
    }

    // 3. CENTRAL HERO: DAY & MONTH
    final textColor = isEmpty
        ? const Color(0xFF2D3436) // Dark Text for Gray Background
        : Colors.white;

    // Shift center slightly up to accommodate month below day
    double dateRadius = (outerRadius + innerRadius) / 2 + 5;
    if (isActive) dateRadius += 2;

    Offset datePos =
        center + Offset(dateRadius * cos(angle), dateRadius * sin(angle));

    canvas.save();
    canvas.translate(datePos.dx, datePos.dy);
    canvas.rotate(angle + pi / 2);

    final dateSpan = TextSpan(
      children: [
        // BIG DAY NUMBER (e.g. "17")
        TextSpan(
          text: "$day\n",
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: isActive ? 28 : 22, // Huge Hero Size
            fontWeight: FontWeight.w900, // Extra Bold
            height: 0.9,
          ),
        ),
        // Month Name (e.g. "JAN")
        TextSpan(
          text: month.toUpperCase(),
          style: GoogleFonts.poppins(
            color: textColor.withOpacity(0.9),
            fontSize: isActive ? 12 : 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
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
      Offset(-datePainter.width / 2, -datePainter.height / 2),
    );
    canvas.restore();

    // 4. TIME (Inner Edge - Small)
    if (time.isNotEmpty) {
      double timeRadius = innerRadius + (isActive ? 18 : 18);
      Offset timePos =
          center + Offset(timeRadius * cos(angle), timeRadius * sin(angle));

      canvas.save();
      canvas.translate(timePos.dx, timePos.dy);
      canvas.rotate(angle + pi / 2);

      final timePainter = TextPainter(
        text: TextSpan(
          text: time.replaceAll(' ', '\n'), // Wraps 08:00 \n AM
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
