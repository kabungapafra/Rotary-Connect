import 'dart:convert';

import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/pressable.dart';

/// The visited club's dashboard for a walk-in visitor — what the splash
/// guest button opens once this device has checked in somewhere, and where
/// every visitor check-in lands. Shows only the club's public profile
/// (branding + events); scanning a different club's QR replaces it.
class VisitorHomeScreen extends StatelessWidget {
  final AppState state;
  const VisitorHomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RCColors.scanBg,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 18 + MediaQuery.of(context).padding.top, 20, 8),
            child: Row(
              children: [
                PressableScale(
                  child: Material(
                    color: RCColors.scanCard,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: state.goBack,
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Text('‹',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.visitorClubName ?? 'Visiting club',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                          state.visitorClubType == 'rotaract'
                              ? 'Rotaract club · visitor view'
                              : 'Rotary club · visitor view',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12.5)),
                    ],
                  ),
                ),
                _ClubLogo(logo: state.visitorClubLogo),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                if (state.visitorJustCheckedIn) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: RCColors.green.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: RCColors.green.withValues(alpha: .5)),
                    ),
                    child: const Row(
                      children: [
                        Text('✓',
                            style: TextStyle(
                                color: RCColors.green,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              "You're checked in — a thank-you text is on "
                              'its way to your phone.',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Meetings & events',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (state.visitorClubLoading && state.visitorEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white70),
                      ),
                    ),
                  )
                else if (state.visitorClubError != null &&
                    state.visitorEvents.isEmpty) ...[
                  Text(state.visitorClubError!,
                      style: const TextStyle(
                          color: Color(0xFFFF9D9D), fontSize: 12.5)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: state.loadVisitorClub,
                    child: Text('Try again',
                        style: TextStyle(
                            color: RCColors.scanAccent, fontSize: 12.5)),
                  ),
                ] else if (state.visitorEvents.isEmpty)
                  const Text('No events published yet.',
                      style:
                          TextStyle(color: RCColors.scanMuted, fontSize: 12.5))
                else
                  for (final e in state.visitorEvents) _EventTile(event: e),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, 16 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              child: PressableScale(
                child: ElevatedButton(
                  onPressed: state.visitorScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RCColors.scanAccent,
                    foregroundColor: RCColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Scan to check in',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubLogo extends StatelessWidget {
  final String? logo;
  const _ClubLogo({required this.logo});

  @override
  Widget build(BuildContext context) {
    const size = 40.0;
    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
              color: RCColors.scanCard, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Text('R',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        );
    final l = logo;
    if (l != null && l.startsWith('http')) {
      return ClipOval(
        child: Image.network(l,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => fallback()),
      );
    }
    if (l != null && l.contains(',')) {
      return ClipOval(
        child: Image.memory(base64Decode(l.split(',').last),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => fallback()),
      );
    }
    return fallback();
  }
}

class _EventTile extends StatelessWidget {
  final ClubEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RCColors.scanCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RCColors.scanBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: RCColors.scanAccent.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(event.dow,
                style: TextStyle(
                    color: RCColors.scanAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                if (event.meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(event.meta,
                      style: const TextStyle(
                          color: RCColors.scanMuted, fontSize: 11.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
