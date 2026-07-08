import 'package:flutter/material.dart';
import '../app_state.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';

class MembersScreen extends StatelessWidget {
  final AppState state;
  const MembersScreen({super.key, required this.state});

  bool _matches(Member m) {
    final q = state.search.trim().toLowerCase();
    return q.isEmpty ||
        m.name.toLowerCase().contains(q) ||
        m.role.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    // Avatar colors follow each member's index in the full list, as designed.
    final all = state.allMembers;
    final indexed =
        all.asMap().entries.where((e) => _matches(e.value)).toList();
    final board = indexed.where((e) => e.value.isBoard).toList();
    final gen = indexed.where((e) => !e.value.isBoard).toList();
    final mf = state.memberFilter;
    final showBoard = (mf == 'all' || mf == 'board') && board.isNotEmpty;
    final showGen = (mf == 'all' || mf == 'gen') && gen.isNotEmpty;
    final visibleCount =
        (mf != 'gen' ? board.length : 0) + (mf != 'board' ? gen.length : 0);

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: RCColors.blue,
              padding: EdgeInsets.fromLTRB(
                  20, 18 + MediaQuery.of(context).padding.top, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Members',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      // Only the Club President can add and manage members.
                      if (state.isPresident)
                        ElevatedButton(
                          onPressed: state.openAddMember,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RCColors.gold,
                            foregroundColor: RCColors.blue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('＋ Add',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${all.length} active · RY 2026/27',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .8),
                          fontSize: 12)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: state.search)
                      ..selection =
                          TextSelection.collapsed(offset: state.search.length),
                    onChanged: state.setSearch,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Search name or role…',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: .7)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: .14),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: .25)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: .25)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: .25)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _FilterChip(
                          label: 'All',
                          active: mf == 'all',
                          onTap: () => state.setMemberFilter('all')),
                      const SizedBox(width: 6),
                      _FilterChip(
                          label: 'Board & officers',
                          active: mf == 'board',
                          onTap: () => state.setMemberFilter('board')),
                      const SizedBox(width: 6),
                      _FilterChip(
                          label: 'Members',
                          active: mf == 'gen',
                          onTap: () => state.setMemberFilter('gen')),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.clubMembersLoading && !state.clubMembersLoaded)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: RCColors.blue, strokeWidth: 2.5)),
                    )
                  else if (state.clubMembersError != null &&
                      !state.clubMembersLoaded)
                    RCCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            state.clubMembersError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: RCColors.red),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: state.loadClubMembers,
                            child: const Text('Retry',
                                style:
                                    TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (showBoard) ...[
                      _SectionLabel('BOARD & OFFICERS · ${board.length}'),
                      const SizedBox(height: 8),
                      _MemberList(
                          entries: board, showBadge: true, state: state),
                    ],
                    if (showBoard && showGen) const SizedBox(height: 16),
                    if (showGen) ...[
                      _SectionLabel('MEMBERS · ${gen.length}'),
                      const SizedBox(height: 8),
                      _MemberList(
                          entries: gen, showBadge: false, state: state),
                    ],
                    if (visibleCount == 0)
                      const RCCard(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No members match your search',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: RCColors.textMuted),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (state.memberEditor != null) _MemberEditorSheet(state: state),
        if (state.memberProfile != null) _MemberProfileSheet(state: state),
      ],
    );
  }
}

class _MemberProfileSheet extends StatelessWidget {
  final AppState state;
  const _MemberProfileSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final m = state.memberProfile!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeMemberProfile,
            child: Container(color: const Color(0x8C0A1223)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * .8),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
              child: SingleChildScrollView(
                child: Column(
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                              color: RCColors.blue, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text(m.initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.name,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: RCColors.textDark)),
                              Text(m.role,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: RCColors.textMuted)),
                            ],
                          ),
                        ),
                        if (m.isBoard)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                                color: RCColors.amberBg,
                                borderRadius: BorderRadius.circular(999)),
                            child: const Text('BOARD',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: RCColors.amber)),
                          ),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeMemberProfile,
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
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _ProfileRow(
                              icon: '✉️',
                              label: 'EMAIL',
                              value: m.email,
                              isLast: false),
                          _ProfileRow(
                              icon: '📞',
                              label: 'PHONE',
                              value: m.phone,
                              isLast: false),
                          _ProfileRow(
                              icon: '🎂',
                              label: 'DATE OF BIRTH',
                              value: m.dob,
                              isLast: true),
                        ],
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

class _ProfileRow extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool isLast;
  const _ProfileRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFEAEEF5))),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: Color(0xFF8B96A8))),
              Text(value.isEmpty ? 'Not on file' : value,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: RCColors.textDark)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberEditorSheet extends StatelessWidget {
  final AppState state;
  const _MemberEditorSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    final ed = state.memberEditor!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeMemberEditor,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: SingleChildScrollView(
                child: Column(
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
                        const Text('Add member',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeMemberEditor,
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
                    const _FieldLabel('FULL NAME'),
                    const SizedBox(height: 6),
                    _EditorInput(
                        hint: 'e.g. Fiona Nassaka',
                        value: ed.name,
                        onChanged: state.setMemberName),
                    const SizedBox(height: 14),
                    const _FieldLabel('ROLE'),
                    const SizedBox(height: 6),
                    _EditorInput(
                        hint: 'e.g. Member',
                        value: ed.role,
                        onChanged: state.setMemberRole),
                    const SizedBox(height: 14),
                    const _FieldLabel('EMAIL'),
                    const SizedBox(height: 6),
                    _EditorInput(
                        hint: 'e.g. fiona@mbalwarotary.org',
                        value: ed.email,
                        onChanged: state.setMemberEmail),
                    const SizedBox(height: 14),
                    const _FieldLabel('PHONE NUMBER'),
                    const SizedBox(height: 6),
                    _EditorInput(
                        hint: 'e.g. 0772 000 000',
                        value: ed.phone,
                        onChanged: state.setMemberPhone),
                    const SizedBox(height: 14),
                    const _FieldLabel('DATE OF BIRTH'),
                    const SizedBox(height: 6),
                    _EditorInput(
                        hint: 'e.g. 14 Mar 1990',
                        value: ed.dob,
                        onChanged: state.setMemberDob),
                    const SizedBox(height: 14),
                    const _FieldLabel('CATEGORY'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _CategoryChip(
                            label: 'Member',
                            active: !ed.isBoard,
                            onTap: () => state.setMemberIsBoard(false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CategoryChip(
                            label: 'Board & officers',
                            active: ed.isBoard,
                            onTap: () => state.setMemberIsBoard(true),
                          ),
                        ),
                      ],
                    ),
                    if (ed.error != null) ...[
                      const SizedBox(height: 12),
                      Text(ed.error!,
                          style: const TextStyle(
                              color: RCColors.red,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: ed.saving
                          ? null
                          : () async {
                              final added = await state.saveMember();
                              if (added != null && context.mounted) {
                                // One-time credentials for the new member —
                                // the president hands these over.
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 8),
                                    content: Text(
                                        '${added.name} added — member no. '
                                        '${added.memberNumber}, PIN ${added.pin}'),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RCColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: ed.saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Add member',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? RCColors.blue : RCColors.chipBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : const Color(0xFF5A6A85),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Color(0xFF8B96A8)),
    );
  }
}

class _EditorInput extends StatelessWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  const _EditorInput(
      {required this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      style: const TextStyle(color: RCColors.textDark, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8B96A8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: border(const Color(0xFFD4DBE8)),
        enabledBorder: border(const Color(0xFFD4DBE8)),
        focusedBorder: border(RCColors.blue),
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
      color: active ? RCColors.gold : Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? RCColors.blue : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: Color(0xFF8B96A8)),
    );
  }
}

class _MemberList extends StatelessWidget {
  final List<MapEntry<int, Member>> entries;
  final bool showBadge;
  final AppState state;
  const _MemberList(
      {required this.entries, required this.showBadge, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: RCColors.cardShadow, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(16) : Radius.zero,
                bottom: i == entries.length - 1
                    ? const Radius.circular(16)
                    : Radius.zero,
              ),
              onTap: () => state.openMemberProfile(entries[i].value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: i == entries.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: RCColors.divider)),
                ),
                child: Row(
                  children: [
                    RCAvatar(
                        initials: entries[i].value.initials,
                        color: RCColors.avatarColor(entries[i].key),
                        size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entries[i].value.name,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: RCColors.textDark)),
                          Text(entries[i].value.role,
                              style: const TextStyle(
                                  fontSize: 11.5, color: RCColors.textMuted)),
                          if (entries[i].value.contact.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(entries[i].value.contact,
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF9AA5B8))),
                            ),
                        ],
                      ),
                    ),
                    if (showBadge)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: RCColors.amberBg,
                            borderRadius: BorderRadius.circular(999)),
                        child: const Text('BOARD',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: RCColors.amber)),
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
