import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Sube la foto de un reporte a Firebase Storage y regresa la URL
/// pública para guardarla en el documento de Firestore.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  StorageService() {
    // Por defecto Storage reintenta durante varios minutos (sobre todo en
    // web si el servicio no está habilitado); se acorta para fallar rápido.
    _storage.setMaxUploadRetryTime(const Duration(seconds: 15));
    _storage.setMaxOperationRetryTime(const Duration(seconds: 15));
  }

  Future<String> subirFotoReporte(Uint8List bytes) async {
    final nombre = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('reportes/$nombre');
    final tarea = await ref
        .putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        )
        .timeout(const Duration(seconds: 20));
    return tarea.ref
        .getDownloadURL()
        .timeout(const Duration(seconds: 20));
  }
}
