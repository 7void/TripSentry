import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_assistant_service.dart';

/// A small draggable overlay panel that displays the latest
/// voice assistant event + partial/final transcripts to avoid
/// needing to watch the console.
class VoiceDebugOverlay extends StatefulWidget {
  final VoiceAssistantService service;
  final bool initiallyVisible;
  const VoiceDebugOverlay({
    super.key,
    required this.service,
    this.initiallyVisible = true,
  });

  @override
  State<VoiceDebugOverlay> createState() => _VoiceDebugOverlayState();
}

class _VoiceDebugOverlayState extends State<VoiceDebugOverlay> {
  late StreamSubscription _sub;
  VoiceAssistantEvent? _lastEvent;
  String? _partial;
  String? _final;
  bool _expanded = true;
  bool _visible = true;
  Offset _offset = const Offset(12, 120);

  @override
  void initState() {
    super.initState();
    _visible = widget.initiallyVisible;
    _sub = widget.service.events.listen((e) {
      setState(() {
        _lastEvent = e;
        switch (e.type) {
          case VoiceAssistantEventType.partialResult:
            _partial = e.data;
            break;
          case VoiceAssistantEventType.finalResult:
            _final = e.data;
            _partial = null; // clear partial once final arrives
            break;
          default:
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Color _statusColor(VoiceAssistantEventType? t) {
    switch (t) {
      case VoiceAssistantEventType.wakeListening:
      case VoiceAssistantEventType.resumedWake:
        return Colors.deepPurple;
      case VoiceAssistantEventType.wakeDetected:
        return Colors.orange;
      case VoiceAssistantEventType.sttListening:
        return Colors.blue;
      case VoiceAssistantEventType.partialResult:
        return Colors.teal;
      case VoiceAssistantEventType.finalResult:
        return Colors.green;
      case VoiceAssistantEventType.error:
        return Colors.red;
      case VoiceAssistantEventType.ready:
        return Colors.indigo;
      case VoiceAssistantEventType.debug:
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final event = _lastEvent;
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _offset += d.delta),
        child: Opacity(
          opacity: 0.93,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: 280,
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _statusColor(event?.type).withOpacity(0.85),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            event != null ? event.type.name : 'voice (idle)',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 28, height: 28),
                          icon: Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              color: Colors.white,
                              size: 18),
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 28, height: 28),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                          onPressed: () => setState(() => _visible = false),
                        ),
                      ],
                    ),
                  ),
                  if (_expanded)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event?.data != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('info: ${event!.data!}'),
                              ),
                            if (_partial != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('partial: $_partial'),
                              ),
                            if (_final != null)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('final: $_final',
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ),
                            if (_final == null &&
                                _partial == null &&
                                event != null)
                              const Text('waiting...'),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _chipButton(
                                    label: 'Hide',
                                    icon: Icons.visibility_off,
                                    onTap: () =>
                                        setState(() => _visible = false)),
                                _chipButton(
                                    label: 'Clear',
                                    icon: Icons.clear,
                                    onTap: () => setState(() {
                                          _partial = null;
                                          _final = null;
                                        })),
                                _chipButton(
                                    label: 'Sim ON/OFF',
                                    icon: Icons.science,
                                    onTap: () =>
                                        widget.service.toggleSimulation()),
                                _chipButton(
                                    label: 'Sim Wake',
                                    icon: Icons.flash_on,
                                    onTap: () => widget.service.simulateWake()),
                                _chipButton(
                                    label: 'Sens 0.80',
                                    icon: Icons.tune,
                                    onTap: () =>
                                        widget.service.setSensitivity(0.80)),
                                _chipButton(
                                    label: 'Sens 0.90',
                                    icon: Icons.tune,
                                    onTap: () =>
                                        widget.service.setSensitivity(0.90)),
                                _chipButton(
                                    label: 'Sens 0.97',
                                    icon: Icons.tune,
                                    onTap: () =>
                                        widget.service.setSensitivity(0.97)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipButton(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
