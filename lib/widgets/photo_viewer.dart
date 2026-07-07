import 'package:flutter/material.dart';
import '../app_state.dart';

/// Full-screen photo viewer overlay — tap anywhere to close, matching the
/// design's absolute-positioned dark scrim.
class PhotoViewerOverlay extends StatelessWidget {
  final AppState state;
  const PhotoViewerOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final photo = state.photo!;
    return Positioned.fill(
      child: GestureDetector(
        onTap: state.closePhoto,
        child: Container(
          color: const Color(0xE60A1223),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                height: 340,
                child: photo.src != null
                    ? Image.memory(photo.src!, fit: BoxFit.contain)
                    : Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFF1C2740),
                            borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: Text(photo.label,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFF8FA0C0))),
                      ),
              ),
              const SizedBox(height: 14),
              Text(photo.activity,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(photo.date,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 14),
              const Text('Tap anywhere to close',
                  style: TextStyle(color: Color(0xFF8FA0C0), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
