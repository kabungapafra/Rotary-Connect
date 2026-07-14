import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class PhotoInfo {
  final String label;
  final String activity;
  final String date;
  // Public R2 URL — gallery photos are fetched over the network, not held
  // as local bytes.
  final String? imageUrl;
  // Backend gallery photo id — set only when this photo came from the
  // club gallery, which is what lets the viewer offer to delete it.
  final int? id;
  const PhotoInfo(this.label, this.activity, this.date,
      {this.imageUrl, this.id});
}

/// A photo in a gallery album, fetched from the backend. `image` is the
/// public R2 URL the app displays directly with Image.network.
class GalleryUpload {
  final int id;
  final String album;
  final String image;
  // Small WebP URL for grid tiles; null on rows without a generated
  // thumbnail, where the grid falls back to the full image.
  final String? thumb;
  const GalleryUpload(this.id, this.album, this.image, this.thumb);
}

/// State of the gallery "Upload photos" bottom sheet while it is open.
class UploadSheet {
  String album;
  final List<Uint8List> srcs = [];
  bool saving = false;
  String? error;
  UploadSheet(this.album);
}

/// The club gallery's data and logic — the photo grid, the upload sheet,
/// and the full-screen viewer (open only from this gallery, never
/// anywhere else in the app) — split out of AppState. Depends only on
/// [ApiClient] and a token provider, not on AppState.
class GalleryController extends ChangeNotifier {
  final ApiClient _api;
  final String? Function() _getToken;
  GalleryController(this._api, this._getToken);

  UploadSheet? uploadSheet;
  final List<GalleryUpload> uploads = [];
  bool loaded = false;
  bool loading = false;
  String? downloadToast;
  Timer? _downloadToastTimer;

  /// The full-screen photo viewer's currently-open photo, and which album
  /// it belongs to (lets the viewer swipe between the rest of that
  /// album's photos).
  PhotoInfo? photo;
  String? photoAlbum;

  void _update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Drops every cached value so a member of a different club signing in
  /// on the same device never sees a stale gallery.
  void reset() {
    uploads.clear();
    loaded = false;
    photo = null;
    photoAlbum = null;
  }

  Future<void> load() async {
    final token = _getToken();
    if (token == null) return;
    _update(() => loading = true);
    try {
      final list = await _api.fetchGalleryPhotos(token);
      _update(() {
        uploads
          ..clear()
          ..addAll([
            for (final p in list)
              GalleryUpload(p.id, p.album, p.image, p.thumb),
          ]);
        loaded = true;
        loading = false;
      });
    } on ApiException {
      _update(() => loading = false);
    }
  }

  void openUpload() => _update(() => uploadSheet = UploadSheet('Club album'));
  void closeUpload() => _update(() => uploadSheet = null);
  void pickUploadAlbum(String album) =>
      _update(() => uploadSheet?.album = album);
  void addUploadPhotos(List<Uint8List> photos) =>
      _update(() => uploadSheet?.srcs.addAll(photos));

  Future<void> saveUpload() async {
    final u = uploadSheet;
    final token = _getToken();
    if (u == null || u.srcs.isEmpty || token == null) return;
    _update(() {
      u.saving = true;
      u.error = null;
    });
    try {
      final dataUrls = [
        for (final src in u.srcs) 'data:image/jpeg;base64,${base64Encode(src)}',
      ];
      final uploaded = await _api.uploadGalleryPhotos(token, u.album, dataUrls);
      _update(() {
        uploads.insertAll(0, [
          for (final p in uploaded)
            GalleryUpload(p.id, p.album, p.image, p.thumb),
        ]);
        uploadSheet = null;
      });
    } on ApiException catch (e) {
      _update(() {
        u.saving = false;
        u.error = e.message;
      });
    }
  }

  List<GalleryUpload> uploadsFor(String album) =>
      uploads.where((g) => g.album == album).toList();

  void openPhoto(PhotoInfo p, {String? album}) => _update(() {
        photo = p;
        photoAlbum = album;
      });
  void closePhoto() => _update(() {
        photo = null;
        photoAlbum = null;
      });

  /// Swiping the full-screen viewer to a different photo in the same
  /// album — keeps download/delete pointed at whatever's on screen.
  void showAlbumPhotoAt(int index) {
    final album = photoAlbum;
    if (album == null) return;
    final photos = uploadsFor(album);
    if (index < 0 || index >= photos.length) return;
    final p = photos[index];
    _update(
        () => photo = PhotoInfo('', album, '', imageUrl: p.image, id: p.id));
  }

  /// Saves the currently-open full-screen photo to the device's own photo
  /// gallery (separate from the club's in-app gallery).
  Future<void> downloadPhoto() async {
    final url = photo?.imageUrl;
    if (url == null) return;
    String message;
    try {
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (res.statusCode >= 400) throw ApiException('Download failed');
      await Gal.putImageBytes(res.bodyBytes,
          name: 'rotary_connect_${DateTime.now().millisecondsSinceEpoch}');
      message = 'Saved to your photos';
    } catch (_) {
      message = 'Could not save photo';
    }
    _downloadToastTimer?.cancel();
    _update(() => downloadToast = message);
    _downloadToastTimer = Timer(const Duration(seconds: 2), () {
      _update(() => downloadToast = null);
    });
  }

  /// Removes the currently-open photo from the club gallery (backend +
  /// local list) and closes the viewer.
  Future<void> deletePhoto() async {
    final id = photo?.id;
    final token = _getToken();
    if (id == null || token == null) return;
    try {
      await _api.deleteGalleryPhoto(token, id);
      _update(() {
        uploads.removeWhere((g) => g.id == id);
        photo = null;
      });
    } on ApiException {
      _downloadToastTimer?.cancel();
      _update(() => downloadToast = 'Could not delete photo');
      _downloadToastTimer = Timer(const Duration(seconds: 2), () {
        _update(() => downloadToast = null);
      });
    }
  }

  @override
  void dispose() {
    _downloadToastTimer?.cancel();
    super.dispose();
  }
}
