import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time_field.dart';
import '../widgets/pressable.dart';
import '../widgets/synced_text_field.dart';

class ProjectsScreen extends StatelessWidget {
  final AppState state;
  const ProjectsScreen({super.key, required this.state});

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
                  20, 18 + MediaQuery.of(context).padding.top, 20, 16),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: state.goHome,
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                            child: Text('‹',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Club projects',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (state.canManageClub)
                    PressableScale(
                      child: ElevatedButton(
                        onPressed: state.openAddProject,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RCColors.gold,
                          foregroundColor: RCColors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('＋ Add',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12.5)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < state.projects.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _ProjectCard(project: state.projects[i], state: state),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (state.projectEditor != null) _ProjectEditorSheet(state: state),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final AppState state;
  const _ProjectCard({required this.project, required this.state});

  @override
  Widget build(BuildContext context) {
    return RCCard(
      padding: const EdgeInsets.all(16),
      onTap: () => state.openEditProject(project),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (project.photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(project.photo!,
                  height: 90, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: RCColors.chipBg,
                    borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(project.icon,
                    style: TextStyle(
                        color: RCColors.blue,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: RCColors.textDark)),
                    Text(project.area,
                        style: const TextStyle(
                            fontSize: 11.5, color: RCColors.textMuted)),
                  ],
                ),
              ),
              Text(project.pctLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: RCColors.blue)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: project.pct / 100,
              minHeight: 6,
              backgroundColor: RCColors.divider,
              valueColor: AlwaysStoppedAnimation(
                  project.isDone ? RCColors.green : RCColors.blue),
            ),
          ),
          const SizedBox(height: 10),
          Text(project.desc,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF4A5670), height: 1.5)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🗓 ${project.deadline}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF8B96A8))),
              if (project.isDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('✓ DONE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: RCColors.green)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectEditorSheet extends StatelessWidget {
  final AppState state;
  const _ProjectEditorSheet({required this.state});

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 1920);
    if (file == null) return;
    state.setProjectPhoto(await file.readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    final ed = state.projectEditor!;
    final isNew = !state.canDeleteProject;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeProjectEditor,
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
                        Text(isNew ? 'New project' : 'Edit project',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeProjectEditor,
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
                    if (ed.pendingPhotoBytes == null && ed.photo == null)
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickPhoto,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: const Color(0xFFB9C4D6), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text('＋',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: RCColors.blue,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Add project photo',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: RCColors.blue)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ed.pendingPhotoBytes != null
                            ? Image.memory(ed.pendingPhotoBytes!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover)
                            : Image.network(ed.photo!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: PressableScale(
                              child: OutlinedButton(
                                onPressed: _pickPhoto,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: RCColors.blue,
                                  side: const BorderSide(
                                      color: Color(0xFFD4DBE8), width: 1.5),
                                  padding: const EdgeInsets.all(9),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Change photo',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PressableScale(
                              child: ElevatedButton(
                                onPressed: state.removeProjectPhoto,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFDECEA),
                                  foregroundColor: RCColors.red,
                                  padding: const EdgeInsets.all(9),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text('Remove',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    const _FieldLabel('PROJECT NAME'),
                    const SizedBox(height: 6),
                    _EditorInput(
                      hint: 'e.g. Solar Lights for Mbalwa Market',
                      value: ed.name,
                      onChanged: state.setProjectName,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('FOCUS AREA & LOCATION'),
                    const SizedBox(height: 6),
                    _EditorInput(
                      hint: 'e.g. Water & sanitation · Mbalwa Village',
                      value: ed.area,
                      onChanged: state.setProjectArea,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('DESCRIPTION'),
                    const SizedBox(height: 6),
                    _EditorInput(
                      hint: 'What is this project doing?',
                      value: ed.desc,
                      onChanged: state.setProjectDesc,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('ESTIMATED DEADLINE'),
                    const SizedBox(height: 6),
                    _EditorInput(
                      hint: 'e.g. Sep 2026',
                      value: ed.deadline,
                      onChanged: state.setProjectDeadline,
                      readOnly: true,
                      icon: Icons.calendar_today_outlined,
                      onTap: () async {
                        final picked = await pickRCDate(
                          context,
                          initialDate: tryParseMonthYear(ed.deadline) ??
                              DateTime.now(),
                          lastDate: DateTime(DateTime.now().year + 20),
                        );
                        if (picked != null) {
                          state.setProjectDeadline(formatMonthYear(picked));
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(
                        'PROGRESS · ${ed.pct}%${ed.pct >= 100 ? ' · Done' : ''}'),
                    Slider(
                      value: ed.pct.toDouble(),
                      min: 0,
                      max: 100,
                      activeColor: RCColors.blue,
                      onChanged: (v) => state.setProjectPct(v.round()),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (state.canDeleteProject) ...[
                          PressableScale(
                            child: ElevatedButton(
                              onPressed: state.deleteProject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDECEA),
                                foregroundColor: RCColors.red,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Delete',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: PressableScale(
                            child: ElevatedButton(
                              onPressed: state.saveProject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: RCColors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text(
                                  isNew ? 'Add project' : 'Save changes',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                          ),
                        ),
                      ],
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
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? icon;
  const _EditorInput(
      {required this.hint,
      required this.value,
      required this.onChanged,
      this.maxLines = 1,
      this.readOnly = false,
      this.onTap,
      this.icon});

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return SyncedTextField(
      value: value,
      builder: (context, controller) => TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: RCColors.textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF8B96A8)),
          suffixIcon: icon == null
              ? null
              : Icon(icon, size: 18, color: RCColors.blue),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: border(const Color(0xFFD4DBE8)),
          enabledBorder: border(const Color(0xFFD4DBE8)),
          focusedBorder: border(RCColors.blue),
        ),
    ),
           );
  }
}
