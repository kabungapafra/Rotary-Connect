import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pressable.dart';

const _milestoneCategories = [
  'Milestones',
  'Leadership',
  'Projects',
  'Awards',
  'Events',
  'Partnerships',
];

/// The club's history timeline — open to every member; only the
/// Secretary can add or remove entries.
class ClubHistoryScreen extends StatelessWidget {
  final AppState state;
  const ClubHistoryScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: RCColors.blue,
              padding: EdgeInsets.fromLTRB(
                  20, 18 + MediaQuery.of(context).padding.top, 20, 20),
              child: RCHeader(
                onBack: state.goHome,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Club history',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800)),
                    Text(state.displayClubName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RCSectionHeader(
                    title: 'Milestones',
                    actionLabel: state.isSecretary ? '+ Add entry' : null,
                    onAction:
                        state.isSecretary ? state.openMilestoneEditor : null,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final cat in const [
                          'All',
                          ..._milestoneCategories
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: cat,
                              active: state.milestoneFilter == cat,
                              onTap: () => state.pickMilestoneFilter(cat),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (state.visibleMilestones.isEmpty)
                    const RCCard(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No history recorded yet — the club\'s story starts here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: RCColors.textMuted),
                      ),
                    )
                  else
                    for (final m in state.visibleMilestones)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MilestoneCard(
                          milestone: m,
                          canDelete: state.isSecretary,
                          onDelete: () => state.deleteMilestone(m.id),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
        if (state.milestoneEditor != null) _MilestoneEditorSheet(state: state),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final MilestoneInfo milestone;
  final bool canDelete;
  final VoidCallback onDelete;
  const _MilestoneCard(
      {required this.milestone,
      required this.canDelete,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return RCCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(milestone.year,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: RCColors.blue)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: RCColors.chipBg,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(milestone.category,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: RCColors.blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(milestone.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: RCColors.textDark)),
                if (milestone.text.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(milestone.text,
                      style: const TextStyle(
                          fontSize: 11.5, color: RCColors.textMuted)),
                ],
              ],
            ),
          ),
          if (canDelete)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('✕',
                      style:
                          TextStyle(fontSize: 12, color: RCColors.textMuted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RCColors.blue : RCColors.chipBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : const Color(0xFF5A6A85))),
        ),
      ),
    );
  }
}

class _MilestoneEditorSheet extends StatelessWidget {
  final AppState state;
  const _MilestoneEditorSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final draft = state.milestoneEditor!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeMilestoneEditor,
            child: Container(color: const Color(0x8C0A1223)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * .86),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4DBE8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add history entry',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeMilestoneEditor,
                            child: const SizedBox(
                              width: 30,
                              height: 30,
                              child: Center(
                                  child: Text('✕',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF5A6A85)))),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('YEAR'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: draft.year)
                        ..selection =
                            TextSelection.collapsed(offset: draft.year.length),
                      onChanged: state.setMilestoneYear,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RCColors.textDark),
                      decoration: _fieldDecoration('e.g. 2026'),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('TITLE'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: draft.title)
                        ..selection =
                            TextSelection.collapsed(offset: draft.title.length),
                      onChanged: state.setMilestoneTitle,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RCColors.textDark),
                      decoration: _fieldDecoration('e.g. Club chartered'),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('CATEGORY'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in _milestoneCategories)
                          _FilterChip(
                            label: cat,
                            active: draft.category == cat,
                            onTap: () => state.setMilestoneCategory(cat),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('DETAILS (OPTIONAL)'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: draft.text)
                        ..selection =
                            TextSelection.collapsed(offset: draft.text.length),
                      onChanged: state.setMilestoneText,
                      minLines: 2,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RCColors.textDark),
                      decoration: _fieldDecoration('What happened?'),
                    ),
                    if (draft.error != null) ...[
                      const SizedBox(height: 10),
                      Text(draft.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: RCColors.red)),
                    ],
                    const SizedBox(height: 14),
                    PressableScale(
                      child: ElevatedButton(
                        onPressed:
                            draft.saving ? null : state.saveMilestoneEditor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(draft.saving ? 'Saving…' : 'Save entry',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _fieldLabel(String text) => Text(text,
    style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Color(0xFF8B96A8)));

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8B96A8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD4DBE8))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD4DBE8))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: RCColors.blue)),
    );
