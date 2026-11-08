import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/ios_ui.dart';
import '../../widgets/selectores_ios.dart';
import 'crear_tarea_screen.dart';

/// Nueva / editar evaluación de una materia, como hoja: nombre, peso con
/// deslizador (avisa en vivo si la materia pasa del 100 %), nota opcional,
/// fecha y «Crear también la tarea» para no repetir el formulario.
class CrearGradeItemScreen extends StatefulWidget {
  final Subject subject;
  final GradeItem? existing;

  const CrearGradeItemScreen({
    super.key,
    required this.subject,
    this.existing,
  });

  bool get isEditing => existing != null;

  @override
  State<CrearGradeItemScreen> createState() => _CrearGradeItemScreenState();
}

class _CrearGradeItemScreenState extends State<CrearGradeItemScreen> {
  late final TextEditingController _nombre;
  late final TextEditingController _nota;
  late double _peso;
  DateTime? _fecha;
  bool _crearTarea = false;

  /// Porcentaje que ya ocupan las OTRAS evaluaciones de la materia.
  double _usado = 0;
  List<TaskItem> _vinculadas = const <TaskItem>[];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nombre = TextEditingController(text: e?.nombre ?? '');
    _nota = TextEditingController(text: e?.nota?.toStringAsFixed(1) ?? '');
    _peso = e?.porcentaje ?? 20;
    _fecha = e?.fecha;
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final items = await FirestoreService.instance
          .getGradeItemsBySubject(widget.subject.id);
      var suma = 0.0;
      for (final it in items) {
        if (it.id == widget.existing?.id) continue;
        suma += it.porcentaje;
      }
      List<TaskItem> vinculadas = const <TaskItem>[];
      if (widget.existing != null) {
        vinculadas = await FirestoreService.instance
            .watchTasksByGradeItem(widget.existing!.id)
            .first;
      }
      if (!mounted) return;
      setState(() {
        _usado = suma;
        _vinculadas = vinculadas;
        // Una evaluación nueva arranca con lo que queda disponible (si
        // queda menos del 20 %).
        if (widget.existing == null) {
          final libre = (100 - suma).clamp(0, 100).toDouble();
          if (libre > 0 && libre < _peso) _peso = libre.roundToDouble();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nombre.dispose();
    _nota.dispose();
    super.dispose();
  }

  double get _total => _usado + _peso;
  bool get _seVincula => _vinculadas.isNotEmpty;

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      _aviso('Escribe el nombre de la evaluación.');
      return;
    }
    if (_peso <= 0) {
      _aviso('El peso debe ser mayor a 0 %.');
      return;
    }
    if (_total > 100.0001) {
      _aviso('La materia pasaría del 100 %. Baja el peso.');
      return;
    }
    double? nota;
    if (!_seVincula && _nota.text.trim().isNotEmpty) {
      nota = double.tryParse(_nota.text.replaceAll(',', '.').trim());
      if (nota == null || nota < 0 || nota > 5) {
        _aviso('La nota debe estar entre 0.0 y 5.0.');
        return;
      }
    }
    if (_crearTarea && _fecha == null) {
      _aviso('Elige la fecha para crear la tarea.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final item = GradeItem(
        id: widget.existing?.id ?? '',
        subjectId: widget.subject.id,
        nombre: nombre,
        porcentaje: _peso,
        nota: _seVincula ? widget.existing?.nota : nota,
        fecha: _fecha,
      );
      if (widget.isEditing) {
        await FirestoreService.instance
            .updateGradeItem(widget.existing!.id, item);
      } else {
        final id = await FirestoreService.instance.addGradeItem(item);
        if (_crearTarea) {
          await FirestoreService.instance.addTask(
            TaskItem(
              id: '',
              titulo: nombre,
              descripcion: '',
              subjectId: widget.subject.id,
              importancia: _peso >= 25 ? 'Alta' : 'Media',
              fechaLimite: _fecha!,
              gradeItemId: id,
              recordatorios: recordatoriosPorDefecto(
                _peso >= 25 ? 'Alta' : 'Media',
              ),
            ),
          );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _eliminar() async {
    final ok = await confirmarIOS(
      context,
      titulo: '¿Eliminar evaluación?',
      mensaje: 'Se eliminará «${widget.existing!.nombre}». Las tareas '
          'vinculadas se conservan, pero sin vínculo.',
    );
    if (!ok) return;
    try {
      await FirestoreService.instance.deleteGradeItem(widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  void _aviso(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _elegirFecha() async {
    final hoy = soloDia(DateTime.now());
    final f = await elegirFecha(
      context,
      inicial: _fecha ?? hoy,
      primera: DateTime(hoy.year - 1),
      ultima: DateTime(hoy.year + 2, 12, 31),
      titulo: 'Fecha de la evaluación',
    );
    if (f != null) setState(() => _fecha = f);
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final excede = _total > 100.0001;
    final df = DateFormat('d MMM y', 'es');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            EncabezadoHoja(
              titulo:
                  widget.isEditing ? 'Editar evaluación' : 'Nueva evaluación',
              subtitulo: widget.subject.nombre,
              onConfirmar: _guardar,
              guardando: _guardando,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  GrupoIOS(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _nombre,
                          autofocus: !widget.isEditing,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(fontSize: 17, color: p.texto),
                          decoration: InputDecoration(
                            hintText: 'Ej. Parcial 1, Proyecto final',
                            hintStyle: TextStyle(color: p.texto2),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const EtiquetaGrupo('Peso en la materia'),
                  GrupoIOS(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Peso',
                                  style:
                                      TextStyle(fontSize: 17, color: p.texto),
                                ),
                                const Spacer(),
                                Text(
                                  '${_peso.round()} %',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: excede
                                        ? AppColors.highPriority
                                        : p.acento,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _peso.clamp(0, 100).toDouble(),
                              min: 0,
                              max: 100,
                              divisions: 100,
                              activeColor: excede
                                  ? AppColors.highPriority
                                  : AppColors.primary,
                              onChanged: (v) => setState(() => _peso = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  PieGrupo(
                    excede
                        ? 'Con esta, la materia suma ${_total.round()} %: pasa '
                            'del 100 %.'
                        : 'Con esta, la materia suma ${_total.round()} %.',
                    icono: excede
                        ? Icons.error_rounded
                        : Icons.check_circle_rounded,
                    color: excede
                        ? AppColors.highPriority
                        : (_total.round() == 100
                            ? AppColors.lowPriority
                            : null),
                  ),
                  const EtiquetaGrupo('Nota'),
                  GrupoIOS(
                    children: [
                      FilaIOS(
                        titulo: 'Nota obtenida',
                        trailing: _seVincula
                            ? Text(
                                widget.existing?.nota?.toStringAsFixed(1) ??
                                    'Sin nota',
                                style:
                                    TextStyle(fontSize: 17, color: p.texto2),
                              )
                            : SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: _nota,
                                  textAlign: TextAlign.right,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style:
                                      TextStyle(fontSize: 17, color: p.texto),
                                  decoration: InputDecoration(
                                    hintText: '0.0 – 5.0',
                                    hintStyle: TextStyle(color: p.texto2),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                  PieGrupo(
                    _seVincula
                        ? 'La nota viene de la tarea «${_vinculadas.first.titulo}». '
                            'Cámbiala desde la tarea.'
                        : 'Déjala vacía si aún no la tienes. No contará en el '
                            'promedio.',
                  ),
                  const SizedBox(height: 22),
                  GrupoIOS(
                    sangriaSeparador: 58,
                    children: [
                      FilaIOS(
                        leading: const IconoCuadrado(
                          icono: Icons.calendar_today_rounded,
                          color: Color(0xFFFF3B30),
                        ),
                        titulo: 'Fecha',
                        trailing: GestureDetector(
                          onTap: _elegirFecha,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: p.grupo2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _fecha == null ? 'Elegir' : df.format(_fecha!),
                              style: TextStyle(fontSize: 15, color: p.texto),
                            ),
                          ),
                        ),
                      ),
                      if (!widget.isEditing)
                        FilaIOS(
                          leading: const IconoCuadrado(
                            icono: Icons.task_alt_rounded,
                            color: Color(0xFF34C759),
                          ),
                          titulo: 'Crear también la tarea',
                          subtitulo: _fecha == null
                              ? 'Elige la fecha arriba'
                              : 'Para el ${DateFormat('d MMM', 'es').format(_fecha!)}, '
                                  'en ${widget.subject.nombre}',
                          trailing: InterruptorIOS(
                            valor: _crearTarea,
                            onChanged: (v) {
                              setState(() => _crearTarea = v);
                              if (v && _fecha == null) _elegirFecha();
                            },
                          ),
                        ),
                    ],
                  ),
                  if (widget.isEditing) ...[
                    const SizedBox(height: 28),
                    GrupoIOS(
                      children: [
                        FilaIOS(
                          tituloWidget: Center(
                            child: Text(
                              'Eliminar evaluación',
                              style: TextStyle(
                                fontSize: 17,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          onTap: _eliminar,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
