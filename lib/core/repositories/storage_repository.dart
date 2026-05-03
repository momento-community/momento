import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageRepository {
  StorageRepository(this._storage);

  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  /// Upload a Momento cover photo. Path:
  ///   `momentos/{organizerUid}/{momentoId}/{uuid}.{ext}`
  ///
  /// Returns the public download URL.
  Future<String> uploadMomentoImage({
    required String organizerUid,
    required String momentoId,
    required XFile file,
  }) async {
    final ext = _extensionFor(file.path, fallback: 'jpg');
    final filename = '${_uuid.v4()}.$ext';
    final ref = _storage
        .ref()
        .child('momentos/$organizerUid/$momentoId/$filename');

    final metadata = SettableMetadata(
      contentType: file.mimeType ?? 'image/$ext',
    );

    final UploadTask task;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      task = ref.putData(bytes, metadata);
    } else {
      task = ref.putFile(File(file.path), metadata);
    }
    final snap = await task;
    return snap.ref.getDownloadURL();
  }

  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref().child('users/$uid/avatar.jpg');
    final snap =
        await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return snap.ref.getDownloadURL();
  }

  String _extensionFor(String path, {required String fallback}) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return fallback;
    return path.substring(dot + 1).toLowerCase().replaceAll(
        RegExp('[^a-z0-9]'), '');
  }
}
