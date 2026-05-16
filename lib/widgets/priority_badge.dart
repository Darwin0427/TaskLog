import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PriorityBadge extends StatelessWidget {
  final String importancia;
  final bool small;
  const PriorityBadge({super.key, required this.importancia, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forImportancia(importancia);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        importancia,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: small ? 11 : 12,
        ),
      ),
    );
  }
}

class SubjectBadge extends StatelessWidget {
  final String nombre;
  final Color color;
  const SubjectBadge({super.key, required this.nombre, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        nombre,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
