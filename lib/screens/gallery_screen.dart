import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GalleryScreen extends StatelessWidget {
  final AppState state;
  const GalleryScreen({super.key, required this.state});

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Club gallery',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        Text('Photos from fellowships, projects & events',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: state.openUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RCColors.gold,
                      foregroundColor: RCColors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('＋ Upload',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Builder(builder: (context) {
                // Real albums only: group whatever has been uploaded by
                // album name; no seeded placeholder albums.
                final albumNames = <String>[];
                for (final up in state.galleryUploads) {
                  if (!albumNames.contains(up.album)) albumNames.add(up.album);
                }
                if (albumNames.isEmpty) {
                  return const RCCard(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'No photos yet.\nUse ＋ Upload to start the club\'s first album.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: RCColors.textMuted,
                          height: 1.5),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var a = 0; a < albumNames.length; a++) ...[
                      if (a > 0) const SizedBox(height: 18),
                      _Album(name: albumNames[a], state: state),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
        if (state.uploadSheet != null) _UploadSheet(state: state),
      ],
    );
  }
}

class _Album extends StatelessWidget {
  final String name;
  final AppState state;
  const _Album({required this.name, required this.state});

  @override
  Widget build(BuildContext context) {
    final uploads = state.uploadsFor(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: RCColors.textDark)),
            Text('${uploads.length} photo${uploads.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(fontSize: 11, color: RCColors.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
          children: [
            for (final up in uploads)
              GestureDetector(
                onTap: () =>
                    state.openPhoto(PhotoInfo('', name, '', src: up.src)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(up.src, height: 100, fit: BoxFit.cover),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _UploadSheet extends StatelessWidget {
  final AppState state;
  const _UploadSheet({required this.state});

  Future<void> _pickPhotos() async {
    final files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    final bytes = <Uint8List>[];
    for (final f in files) {
      bytes.add(await f.readAsBytes());
    }
    state.addUploadPhotos(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final sheet = state.uploadSheet!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: state.closeUpload,
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
                        const Text('Upload photos',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: RCColors.textDark)),
                        Material(
                          color: RCColors.chipBg,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: state.closeUpload,
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
                    const Text('ALBUM NAME',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: Color(0xFF8B96A8))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: sheet.album)
                        ..selection = TextSelection.collapsed(
                            offset: sheet.album.length),
                      onChanged: state.pickUploadAlbum,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: RCColors.textDark),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'e.g. Community Health Camp',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF8B96A8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFD4DBE8))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFFD4DBE8))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: RCColors.blue)),
                      ),
                    ),
                    if (sheet.srcs.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final src in sheet.srcs)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(src, fit: BoxFit.cover),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickPhotos,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFB9C4D6), width: 1.5),
                        ),
                        child: const Column(
                          children: [
                            Text('＋',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: RCColors.blue,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 4),
                            Text('Choose photos',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: RCColors.blue)),
                            SizedBox(height: 4),
                            Text('You can select several at once',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF8B96A8))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: state.saveUpload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RCColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Add to gallery',
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

