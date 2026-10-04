import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Sube la foto de un reporte a Firebase Storage y regresa la URL
/// pública para guardarla en el documento de Firestore.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> subirFotoReporte(File archivo) async {
    final nombre = '${_uuid.v4()}.jpg';
    final ref = _storage.ref().child('reportes/$nombre');
    final tarea = await ref.putFile(archivo);
    return tarea.ref.getDownloadURL();
  }
}
