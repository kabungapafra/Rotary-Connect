import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import 'pressable.dart';

/// Full-screen photo viewer overlay — tap anywhere to close, matching the
/// design's absolute-positioned dark scrim. Swipes between the rest of the
/// album's photos when the open photo came from a gallery grid.
class PhotoViewerOverlay extends StatelessWidget {
  final AppState state;
  const PhotoViewerOverlay({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final photo = state.photo!;
    final album = state.photoAlbum;
    final albumPhotos = album == null ? const [] : state.uploadsFor(album);
    final currentIndex = albumPhotos.isEmpty
        ? -1
        : albumPhotos.indexWhere((p) => p.id == photo.id);

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
                child: photo.imageUrl == null
                    ? Container(
                        decoration: BoxDecoration(
                            color: const Color(0xFF1C2740),
                            borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.center,
                        child: Text(photo.label,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFF8FA0C0))),
                      )
                    : currentIndex < 0
                        ? CachedNetworkImage(
                            imageUrl: photo.imageUrl!, fit: BoxFit.contain)
                        : GestureDetector(
                            // Swallow taps on the page view itself so only
                            // the surrounding scrim closes the viewer.
                            onTap: () {},
                            child: PageView.builder(
                              key: ValueKey(album),
                              controller:
                                  PageController(initialPage: currentIndex),
                              itemCount: albumPhotos.length,
                              onPageChanged: state.showAlbumPhotoAt,
                              // The grid's thumbnail is already on disk, so
                              // it shows instantly while the full photo
                              // downloads over it.
                              itemBuilder: (context, i) => CachedNetworkImage(
                                  imageUrl: albumPhotos[i].image,
                                  fit: BoxFit.contain,
                                  placeholder: albumPhotos[i].thumb == null
                                      ? null
                                      : (context, _) => CachedNetworkImage(
                                          imageUrl: albumPhotos[i].thumb!,
                                          fit: BoxFit.contain)),
                            ),
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
              if (photo.imageUrl != null) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PressableScale(
                      child: Material(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: state.downloadPhoto,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 18, vertical: 11),
                            child: Text('⬇ Download',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ),
                    if (photo.id != null) ...[
                      const SizedBox(width: 10),
                      PressableScale(
                        child: Material(
                          color: const Color(0xFFB3261E).withValues(alpha: .22),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: state.deletePhoto,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 11),
                              child: Text('Delete',
                                  style: TextStyle(
                                      color: Color(0xFFFF8A80),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (state.downloadToast != null) ...[
                  const SizedBox(height: 10),
                  Text(state.downloadToast!,
                      style: const TextStyle(
                          color: Color(0xFF8FA0C0), fontSize: 11)),
                ],
              ],
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
