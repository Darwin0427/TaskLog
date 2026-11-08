import 'package:flutter/material.dart';

import '../../models/subject.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/ios_ui.dart';

/// Nueva / editar materia, como hoja: arriba una vista previa grande que
/// cambia en vivo (ícono y nombre en el color elegido), debajo los 12
/// colores y 12 íconos, y al final los datos opcionales en filas.
class CrearMateriaScreen extends StatefulWidget {
  final Subject? existing;
  const CrearMateriaScreen({super.key, this.existing});

  bool get isEditing => existing != null;

  @override
  State<CrearMateriaScreen> createState() => _CrearMateriaScreenState();
}

class _CrearMateriaScreenState extends State<CrearMateriaScreen> {
  late final TextEditingController _nombre;
  late final TextEditingController _profesor;
  late final TextEditingController _aula;
  late final TextEditingController _link;
  late final TextEditingController _horario;
  late Color _color;
  late String _icono;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombre = TextEditingController(text: e?.nombre ?? '');
    _profesor = TextEditingController(text: e?.profesor ?? '');
    _aula = TextEditingController(text: e?.aula ?? '');
    _link = TextEditingController(text: e?.classLinkUrl ?? '');
    _horario = TextEditingController(text: e?.horario ?? '');
    _color = e?.color ?? AppColors.subjectPalette[6];
    _icono = e?.iconName ?? AppIcons.all.keys.first;
    _nombre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _profesor.dispose();
    _aula.dispose();
    _link.dispose();
    _horario.dispose();
    super.dispose();
  }

  String? _opcional(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre de la materia.')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final materia = Subject(
        id: widget.existing?.id ?? '',
        nombre: _nombre.text.trim(),
        colorHex: AppColors.toHex(_color),
        iconName: _icono,
        profesor: _opcional(_profesor),
        aula: _opcional(_aula),
        classLinkUrl: _opcional(_link),
        horario: _opcional(_horario),
        meta: widget.existing?.meta,
      );
      if (widget.isEditing) {
        await FirestoreService.instance
            .updateSubject(widget.existing!.id, materia);
      } else {
        await FirestoreService.instance.addSubject(materia);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final nombre = _nombre.text.trim();
    final icono = AppIcons.byName(_icono);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EncabezadoHoja(
              titulo: widget.isEditing ? 'Editar materia' : 'Nueva materia',
              onConfirmar: _guardar,
              guardando: _guardando,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // Vista previa + nombre.
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    decoration: BoxDecoration(
                      color: p.grupo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _color,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _color.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(icono, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: p.grupo2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _nombre,
                            autofocus: !widget.isEditing,
                            textAlign: TextAlign.center,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: nombre.isEmpty ? p.texto : _color,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Nombre de la materia',
                              hintStyle: TextStyle(
                                color: p.texto2,
                                fontWeight: FontWeight.w500,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Colores.
                  _Cuadricula(
                    children: [
                      for (final c in AppColors.subjectPalette)
                        _Circulo(
                          seleccionado: c.toARGB32() == _color.toARGB32(),
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Íconos.
                  _Cuadricula(
                    children: [
                      for (final e in AppIcons.all.entries)
                        _Circulo(
                          seleccionado: e.key == _icono,
                          onTap: () => setState(() => _icono = e.key),
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.grupo2,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(e.value, size: 20, color: p.texto),
                          ),
                        ),
                    ],
                  ),
                  const EtiquetaGrupo('Información adicional'),
                  GrupoIOS(
                    children: [
                      _FilaCampo(
                        etiqueta: 'Profesor',
                        controller: _profesor,
                        hint: 'Nombre',
                      ),
                      _FilaCampo(
                        etiqueta: 'Aula',
                        controller: _aula,
                        hint: 'Ej. 118',
                      ),
                      _FilaCampo(
                        etiqueta: 'Clase virtual',
                        controller: _link,
                        hint: 'Enlace',
                        teclado: TextInputType.url,
                      ),
                      _FilaCampo(
                        etiqueta: 'Horario',
                        controller: _horario,
                        hint: 'Ej. Lun y Mié 6–8 p. m.',
                      ),
                    ],
                  ),
                  const PieGrupo('Todo esto es opcional.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seis por fila, dentro de un grupo.
class _Cuadricula extends StatelessWidget {
  final List<Widget> children;
  const _Cuadricula({required this.children});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.grupo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: GridView.count(
        crossAxisCount: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: children,
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  final bool seleccionado;
  final VoidCallback onTap;
  final Widget child;

  const _Circulo({
    required this.seleccionado,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: seleccionado ? p.texto2 : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Fila «Etiqueta ......... valor» con el campo de texto a la derecha.
class _FilaCampo extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controller;
  final String hint;
  final TextInputType teclado;

  const _FilaCampo({
    required this.etiqueta,
    required this.controller,
    required this.hint,
    this.teclado = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 17, color: p.texto),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: teclado,
              textAlign: TextAlign.right,
              textCapitalization: teclado == TextInputType.url
                  ? TextCapitalization.none
                  : TextCapitalization.words,
              autocorrect: teclado != TextInputType.url,
              style: TextStyle(fontSize: 17, color: p.texto),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: p.texto2),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
