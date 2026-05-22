import 'package:flutter/material.dart';
import '../../core/bento_colors.dart';
import '../../screens/ai/ai_assistant_screen.dart';

class AiFloatingAssistant extends StatefulWidget {
  final String page;

  const AiFloatingAssistant({super.key, required this.page});

  @override
  State<AiFloatingAssistant> createState() => _AiFloatingAssistantState();
}

class _AiFloatingAssistantState extends State<AiFloatingAssistant> {
  Offset? _offset;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colors = context.colors;
    final current = _offset ?? Offset(size.width - 78, size.height - 178);

    return Positioned(
      left: current.dx.clamp(12, size.width - 72).toDouble(),
      top: current.dy.clamp(80, size.height - 150).toDouble(),
      child: GestureDetector(
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (details) {
          final next = current + details.delta;
          setState(() {
            _offset = Offset(
              next.dx.clamp(12, size.width - 72).toDouble(),
              next.dy.clamp(80, size.height - 150).toDouble(),
            );
          });
        },
        onPanEnd: (_) => setState(() => _dragging = false),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AiAssistantScreen(page: widget.page),
            ),
          );
        },
        child: AnimatedScale(
          scale: _dragging ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 62,
            height: 74,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  child: Container(
                    width: 54,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFDBEAFE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: colors.primary.withValues(alpha: 0.45),
                          width: 2),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AiEye(),
                        SizedBox(width: 10),
                        _AiEye(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 42,
                  child: Container(
                    width: 42,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [colors.primary, colors.success]),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                        bottom: Radius.circular(18),
                      ),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 9,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
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
  }
}

class _AiEye extends StatelessWidget {
  const _AiEye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 10,
      decoration: BoxDecoration(
        color: context.colors.primaryVariant,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}
