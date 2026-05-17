import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Subject {
  final String id;
  final String nombre;
  final String colorHex;
  final String iconName;
  final String? profesor;
  final String? aula;
  final String? classLinkUrl;
  final DateTime? creadoEn;

  Subject({
    required this.id,
    required this.nombre,
    required this.colorHex,
    required this.iconName,
    this.profesor,
    this.aula,
    this.classLinkUrl,
    this.creadoEn,
  });

  Color get color => AppColors.fromHex(colorHex);
  IconData get icon => AppIcons.byName(iconName);

  bool get hasExtraInfo =>
      (profesor != null && profesor!.isNotEmpty) ||
      (aula != null && aula!.isNotEmpty) ||
      (classLinkUrl != null && classLinkUrl!.isNotEmpty);

  factory Subject.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Subject(
      id: doc.id,
      nombre: (data['nombre'] ?? '') as String,
      colorHex: (data['color'] ?? '#534AB7') as String,
      iconName: (data['iconName'] ?? 'book') as String,
      profesor: data['profesor'] as String?,
      aula: data['aula'] as String?,
      classLinkUrl: data['classLinkUrl'] as String?,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'nombre': nombre,
        'color': colorHex,
        'iconName': iconName,
        if (profesor != null && profesor!.isNotEmpty) 'profesor': profesor,
        if (aula != null && aula!.isNotEmpty) 'aula': aula,
        if (classLinkUrl != null && classLinkUrl!.isNotEmpty)
          'classLinkUrl': classLinkUrl,
        'creadoEn': FieldValue.serverTimestamp(),
      };
}
