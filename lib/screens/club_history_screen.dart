import 'package:flutter/material.dart';
import '../api_client.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time_field.dart';
import '../widgets/pressable.dart';
import '../widgets/synced_text_field.dart';

const _milestoneCategories = [
  'Milestones',
  'Leadership',
  'Projects',
  'Awards',
  'Events',
  'Partnerships',
];

/// The club's history timeline — open to every member; only the
/// President, Immediate Past President, and Secretary can add or remove
/// entries.
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
                  _CharterBanner(state: state),
                  const SizedBox(height: 16),
                  RCSectionHeader(
                    title: 'Milestones',
                    actionLabel:
                        state.canEditClubHistory ? '+ Add entry' : null,
                    onAction: state.canEditClubHistory
                        ? state.openMilestoneEditor
                        : null,
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
                    for (var i = 0; i < state.visibleMilestones.length; i++)
                      _TimelineEntry(
                        milestone: state.visibleMilestones[i],
                        isLast: i == state.visibleMilestones.length - 1,
                        canDelete: state.canEditClubHistory,
                        onDelete: () =>
                            state.deleteMilestone(state.visibleMilestones[i].id),
                      ),
                  const SizedBox(height: 24),
                  RCSectionHeader(
                    title: 'Past presidents & secretaries',
                    actionLabel:
                        state.canEditClubHistory ? '+ Add' : null,
                    onAction: state.canEditClubHistory
                        ? state.openPastLeaderEditor
                        : null,
                  ),
                  const SizedBox(height: 10),
                  if (state.pastLeaders.isEmpty)
                    const RCCard(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No past leaders recorded yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: RCColors.textMuted),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: RCColors.chipBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < state.pastLeaders.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                  height: 1, color: RCColors.divider2),
                            _PastLeaderRow(
                              term: state.pastLeaders[i],
                              canDelete: state.canEditClubHistory,
                              onDelete: () => state
                                  .deletePastLeader(state.pastLeaders[i].id),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (state.milestoneEditor != null) _MilestoneEditorSheet(state: state),
        if (state.pastLeaderEditor != null)
          _PastLeaderEditorSheet(state: state),
        if (state.charterInfoEditorOpen) _CharterInfoEditorSheet(state: state),
      ],
    );
  }
}

// A distinct (background, text) pair per category, matching the reference
// design's own pill colors exactly rather than deriving a background by
// blending the text color's alpha — falls back to the brand blue on the
// standard chip background for any custom/legacy category text.
const Map<String, (Color, Color)> _categoryColors = {
  'Milestones': (Color(0xFFEEF2F9), Color(0xFF17458F)),
  'Leadership': (Color(0xFFF3EEFC), Color(0xFF6D3FC0)),
  'Projects': (Color(0xFFE7F7EE), Color(0xFF1F9D55)),
  'Awards': (Color(0xFFFFF5E0), Color(0xFFB57708)),
  'Events': (Color(0xFFFDEEF5), Color(0xFFC2417E)),
  'Partnerships': (Color(0xFFE8F4FA), Color(0xFF1C7CA8)),
};

(Color, Color) _categoryColor(String category) =>
    _categoryColors[category] ?? (RCColors.chipBg, RCColors.blue);

/// One entry in the club history timeline: a year badge on a connecting
/// vertical line, its title and category pill, and description.
class _TimelineEntry extends StatelessWidget {
  final MilestoneInfo milestone;
  final bool isLast;
  final bool canDelete;
  final VoidCallback onDelete;
  const _TimelineEntry(
      {required this.milestone,
      required this.isLast,
      required this.canDelete,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final (catBg, catColor) = _categoryColor(milestone.category);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                    color: RCColors.chipBg,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(milestone.year,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: RCColors.blue)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: RCColors.divider2,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(milestone.title,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: RCColors.textDark)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                  color: catBg,
                                  borderRadius: BorderRadius.circular(999)),
                              child: Text(milestone.category.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .5,
                                      color: catColor)),
                            ),
                          ],
                        ),
                        if (milestone.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(milestone.text,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: RCColors.textMuted,
                                  height: 1.4)),
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
                              style: TextStyle(
                                  fontSize: 12, color: RCColors.textMuted)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The blue "CHARTERED" banner — date, district, founding members, charter
/// president, sponsor club. District comes from the system admin; every
/// other field is self-set in-app by the President/Secretary/IPP, who tap
/// the banner to open [_CharterInfoEditorSheet]. Read-only for anyone else.
class _CharterBanner extends StatelessWidget {
  final AppState state;
  const _CharterBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final canEdit = state.canEditClubHistory;
    final date = state.clubCharterDate;
    final district = state.clubDistrict.trim();
    final dateLine = [
      if (date != null) formatDateDayMonYear(date) else 'Charter date not set',
      if (district.isNotEmpty && district != '—') 'District $district',
    ].join(' · ');
    final detailParts = [
      if (state.clubCharterFoundingMembers != null)
        '${state.clubCharterFoundingMembers} founding members',
      if (state.clubCharterPresident.trim().isNotEmpty)
        'Charter President: ${state.clubCharterPresident.trim()}',
      if (state.clubCharterSponsorClub.trim().isNotEmpty)
        'Sponsored by ${state.clubCharterSponsorClub.trim()}',
    ];
    final detailLine = detailParts.isNotEmpty
        ? detailParts.join(' · ')
        : (canEdit ? 'Tap to add founding members, charter president & sponsor club' : '');
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: RCColors.blue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CHARTERED',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: RCColors.gold)),
          const SizedBox(height: 2),
          Text(dateLine,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          if (detailLine.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(detailLine,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: .8))),
          ],
        ],
      ),
    );
    if (!canEdit) return banner;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: state.openCharterInfoEditor,
      child: banner,
    );
  }
}

/// A single sheet editing every self-service charter field together
/// (date, founding members, charter president, sponsor club) — local form
/// state since it's a one-shot combined save, not something another part
/// of the app needs to watch mid-edit like the milestone/vote drafts.
class _CharterInfoEditorSheet extends StatefulWidget {
  final AppState state;
  const _CharterInfoEditorSheet({required this.state});

  @override
  State<_CharterInfoEditorSheet> createState() =>
      _CharterInfoEditorSheetState();
}

class _CharterInfoEditorSheetState extends State<_CharterInfoEditorSheet> {
  late DateTime? _date;
  late final TextEditingController _foundingMembers;
  late final TextEditingController _president;
  late final TextEditingController _sponsorClub;

  @override
  void initState() {
    super.initState();
    final state = widget.state;
    _date = state.clubCharterDate;
    _foundingMembers = TextEditingController(
        text: state.clubCharterFoundingMembers?.toString() ?? '');
    _president = TextEditingController(text: state.clubCharterPresident);
    _sponsorClub = TextEditingController(text: state.clubCharterSponsorClub);
  }

  @override
  void dispose() {
    _foundingMembers.dispose();
    _president.dispose();
    _sponsorClub.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = widget.state;
    await state.setCharterDate(_date);
    if (state.charterInfoError != null) return;
    await state.setCharterInfo(
      foundingMembers: int.tryParse(_foundingMembers.text.trim()),
      charterPresident: _president.text.trim(),
      sponsorClub: _sponsorClub.text.trim(),
    );
    if (state.charterInfoError != null) return;
    state.closeCharterInfoEditor();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final saving = state.savingCharterDate || state.savingCharterInfo;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeCharterInfoEditor,
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
                        const Text('Charter details',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeCharterInfoEditor,
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
                    _fieldLabel('CHARTER DATE'),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final picked = await pickRCDate(context,
                            initialDate: _date ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now());
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: const Color(0xFFD4DBE8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                  _date != null
                                      ? formatDateDayMonYear(_date!)
                                      : 'Tap to choose a date',
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: _date != null
                                          ? RCColors.textDark
                                          : const Color(0xFF8B96A8))),
                            ),
                            Icon(Icons.calendar_today,
                                size: 16, color: RCColors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('FOUNDING MEMBERS'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _foundingMembers,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RCColors.textDark),
                      decoration: _fieldDecoration('e.g. 28'),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('CHARTER PRESIDENT'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _president,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RCColors.textDark),
                      decoration: _fieldDecoration('e.g. Rtn. Charles Mubiru'),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('SPONSOR CLUB'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _sponsorClub,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RCColors.textDark),
                      decoration:
                          _fieldDecoration('e.g. Rotary Club of Naalya'),
                    ),
                    if (state.charterInfoError != null) ...[
                      const SizedBox(height: 10),
                      Text(state.charterInfoError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, color: RCColors.red)),
                    ],
                    const SizedBox(height: 14),
                    PressableScale(
                      child: ElevatedButton(
                        onPressed: saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(saving ? 'Saving…' : 'Save',
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

/// One row in the "Past presidents & secretaries" list.
class _PastLeaderRow extends StatelessWidget {
  final PastLeaderInfo term;
  final bool canDelete;
  final VoidCallback onDelete;
  const _PastLeaderRow(
      {required this.term, required this.canDelete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: RCColors.chipBg, borderRadius: BorderRadius.circular(8)),
            child: Text(term.years,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: RCColors.blue)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(term.president,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: RCColors.textDark)),
                if (term.secretary.isNotEmpty)
                  Text('Secretary: ${term.secretary}',
                      style: const TextStyle(
                          fontSize: 11, color: RCColors.textMuted)),
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

class _PastLeaderEditorSheet extends StatelessWidget {
  final AppState state;
  const _PastLeaderEditorSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final draft = state.pastLeaderEditor!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closePastLeaderEditor,
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
                        const Text('Add past leader',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closePastLeaderEditor,
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
                    _fieldLabel('YEARS'),
                    const SizedBox(height: 6),
                    SyncedTextField(
                      value: draft.years,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setPastLeaderYears,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: _fieldDecoration('e.g. 2018/19'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('PRESIDENT'),
                    const SizedBox(height: 6),
                    SyncedTextField(
                      value: draft.president,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setPastLeaderPresident,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: _fieldDecoration('e.g. Rtn. Charles Mubiru'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('SECRETARY'),
                    const SizedBox(height: 6),
                    SyncedTextField(
                      value: draft.secretary,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setPastLeaderSecretary,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: _fieldDecoration('e.g. Rtn. Annet Nansubuga'),
                      ),
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
                            draft.saving ? null : state.savePastLeaderEditor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(draft.saving ? 'Saving…' : 'Save',
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
                    SyncedTextField(
                      value: draft.year,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setMilestoneYear,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: _fieldDecoration('e.g. 2026'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('TITLE'),
                    const SizedBox(height: 6),
                    SyncedTextField(
                      value: draft.title,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setMilestoneTitle,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: _fieldDecoration('e.g. Club chartered'),
                      ),
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
                    SyncedTextField(
                      value: draft.text,
                      builder: (context, controller) => TextField(
                        controller: controller,
                        onChanged: state.setMilestoneText,
                        minLines: 2,
                        maxLines: 4,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: RCColors.textDark),
                        decoration: _fieldDecoration('What happened?'),
                      ),
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
