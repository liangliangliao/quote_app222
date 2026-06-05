import 'package:flutter/material.dart';

import 'ai_assistant_dao.dart';
import 'ai_assistant_page.dart';

class AiAssistantFloatingBubble extends StatefulWidget {
  const AiAssistantFloatingBubble({
    super.key,
    required this.moduleKey,
  });

  final String moduleKey;

  @override
  State<AiAssistantFloatingBubble> createState() => _AiAssistantFloatingBubbleState();
}

class _AiAssistantFloatingBubbleState extends State<AiAssistantFloatingBubble> {
  final AiAssistantDao _dao = AiAssistantDao();
  double _dx = 0;
  double _dy = 0;
  bool _loaded = false;
  bool _dragging = false;

  static const double _size = 58;
  static const double _margin = 12;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    try {
      final pos = await _dao.getBubblePosition(widget.moduleKey);
      if (!mounted) return;
      setState(() {
        _dx = pos?.dx ?? -1;
        _dy = pos?.dy ?? -1;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dx = -1;
        _dy = -1;
        _loaded = true;
      });
    }
  }

  Future<void> _savePosition() async {
    try {
      await _dao.saveBubblePosition(widget.moduleKey, _dx, _dy);
    } catch (_) {}
  }

  void _openAssistant() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiAssistantPage()));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    // The bubble is normally placed inside a page Stack.  Using the full
    // MediaQuery screen height can push it behind the app's bottom navigation
    // bar or below the visible tab body.  Use the actual Stack constraints so
    // the default and clamped position are always visible on the current page.
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;
          final height = constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : MediaQuery.of(context).size.height;

          final maxX = (width - _size - _margin).clamp(_margin, double.infinity).toDouble();
          final maxY = (height - _size - _margin).clamp(_margin, double.infinity).toDouble();

          if (_dx < 0 || _dy < 0) {
            _dx = maxX;
            // Default to the right side, a little above the lower cards/bottom
            // navigation. This makes the first-run entry easy to notice.
            _dy = (height * 0.62).clamp(_margin, maxY).toDouble();
          }
          _dx = _dx.clamp(_margin, maxX).toDouble();
          _dy = _dy.clamp(_margin, maxY).toDouble();

          return Stack(
            children: [
              Positioned(
                left: _dx,
                top: _dy,
                child: GestureDetector(
                  onTap: _dragging ? null : _openAssistant,
                  onPanStart: (_) => setState(() => _dragging = true),
                  onPanUpdate: (details) {
                    setState(() {
                      _dx = (_dx + details.delta.dx).clamp(_margin, maxX).toDouble();
                      _dy = (_dy + details.delta.dy).clamp(_margin, maxY).toDouble();
                    });
                  },
                  onPanEnd: (_) async {
                    await _savePosition();
                    if (!mounted) return;
                    setState(() => _dragging = false);
                  },
                  child: Material(
                    elevation: 10,
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34D399),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
