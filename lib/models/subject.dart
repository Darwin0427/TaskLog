import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Subject {
  final String id;
  final String nombre;
  final String colorHex;
  final String iconName;
  final DateTime? creadoEn;

  Subject({
    required this.id,
    required this.nombre,
    required this.colorHex,
    required this.iconName,
    this.creadoEn,
  });

  Color get color => AppColors.fromHex(colorHex);
  IconData get icon => AppIcons.byName(iconName);

  factory Subject.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Subject(
      id: doc.id,
      nombre: (data['nombre'] ?? '') as String,
      colorHex: (data['color'] ?? '#534AB7') as String,
      iconName: (data['iconName'] ?? 'book') as String,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'nombre': nombre,
        'color': colorHex,
        'iconName': iconName,
        'creadoEn': FieldValue.serverTimestamp(),
      };
}
