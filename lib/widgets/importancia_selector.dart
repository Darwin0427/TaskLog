import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ImportanciaSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const ImportanciaSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'Alta', label: Text('Alta')),
        ButtonSegment(value: 'Media', label: Text('Media')),
        ButtonSegment(value: 'Baja', label: Text('Baja')),
      ],
      selected: <String>{value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.forImportancia(value).withValues(alpha: 0.18);
          }
          return null;
        }),
      ),
    );
  }
}
