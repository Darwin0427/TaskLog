import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/grade_item.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../models/task_reminder.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/hoja_recordatorios.dart';
import '../../widgets/ios_ui.dart';
import '../../widgets/selectores_ios.dart';
import 'crear_materia_screen.dart';

/// Recordatorios de fábrica según la prioridad (a las 9:00): Alta 7, 3,
/// 1 y 0 días antes; Media 3 y 1; Baja solo el día.
List<TaskReminder> recordatoriosPorDefecto(String importancia) {
  final dias = switch (importancia) {
    'Alta' => const <int>[7, 3, 1, 0],
    'Baja' => const <int>[0],
    _ => const <int>[3, 1],
  };
  return [
    for (final d in dias) TaskReminder(diasAntes: d, hora: 9, minuto: 0),
  ];
}

/// Nueva / editar tarea, como hoja: título y notas arriba; fecha con
/// atajos (Hoy, Mañana, Lunes, Otra…) y hora opcional; materia, prioridad,
/// recordatorios y evaluación en filas que abren menús u hojas.
class CrearTareaScreen extends StatefulWidget {
  final TaskItem? existing;
  final String? defaultSubjectId;

  /// Fecha con la que arranca una tarea nueva (ej. el día elegido en el
  /// calendario).
  final DateTime? fechaInicial;

  const CrearTareaScreen({
    super.key,
    this.existing,
    this.defaultSubjectId,
    this.fechaInicial,
  });

  bool get isEditing => existing != null;

  @override
  State<CrearTareaScreen> createState() => _CrearTareaScreenState();
}

class _CrearTareaScreenState extends State<CrearTareaScreen> {
  late final TextEditingController _titulo;
  late final TextEditingController _notas;
  late final TextEditingController _nota;

  String? _materiaId;
  String? _evaluacionId;
  String _importancia = 'Media';
  late DateTime _dia;
  TimeOfDay? _hora;
  late List<TaskReminder> _recordatorios;

  /// Mientras el usuario no toque los recordatorios de una tarea nueva,
  /// se ajustan solos al cambiar la prioridad.
  bool _recordatoriosTocados = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titulo = TextEditingController(text: e?.titulo ?? '');
    _notas = TextEditingController(text: e?.descripcion ?? '');
    _nota = TextEditingController(text: e?.nota?.toStringAsFixed(1) ?? '');
    _materiaId = e?.subjectId ?? widget.defaultSubjectId;
    _evaluacionId = e?.gradeItemId;
    _importancia = e?.importancia ?? 'Media';
    final base = e?.fechaLimite ?? widget.fechaInicial ?? DateTime.now();
    _dia = soloDia(base);
    _hora = e != null && tieneHora(e.fechaLimite)
        ? TimeOfDay(hour: e.fechaLimite.hour, minute: e.fechaLimite.minute)
        : null;
    _recordatorios = e != null
        ? List<TaskReminder>.from(e.recordatorios)
        : recordatoriosPorDefecto(_importancia);
    _recordatoriosTocados = e != null;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _notas.dispose();
    _nota.dispose();
    super.dispose();
  }

  DateTime get _fechaLimite => _hora == null
      ? _dia
      : DateTime(_dia.year, _dia.month, _dia.day, _hora!.hour, _hora!.minute);

  void _cambiarImportancia(String v) {
    setState(() {
      _importancia = v;
      if (!_recordatoriosTocados) {
        _recordatorios = recordatoriosPorDefecto(v);
      }
    });
  }

  Future<void> _guardar() async {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) {
      _aviso('Escribe un título para la tarea.');
      return;
    }
    if (_materiaId == null) {
      _aviso('Elige una materia.');
      return;
    }
    double? nota;
    if (_evaluacionId != null && _nota.text.trim().isNotEmpty) {
      nota = double.tryParse(_nota.text.replaceAll(',', '.').trim());
      if (nota == null || nota < 0 || nota > 5) {
        _aviso('La nota debe estar entre 0.0 y 5.0.');
        return;
      }
    }
    setState(() => _guardando = true);
    try {
      final tarea = TaskItem(
        id: widget.existing?.id ?? '',
        titulo: titulo,
        descripcion: _notas.text.trim(),
        subjectId: _materiaId!,
        importancia: _importancia,
        fechaLimite: _fechaLimite,
        completada: widget.existing?.completada ?? false,
        completadaEn: widget.existing?.completadaEn,
        gradeItemId: _evaluacionId,
        nota: _evaluacionId == null ? null : nota,
        recordatorios: _recordatorios,
      );
      if (widget.isEditing) {
        await FirestoreService.instance.updateTask(widget.existing!.id, tarea);
      } else {
        await FirestoreService.instance.addTask(tarea);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _otraFecha() async {
    final hoy = soloDia(DateTime.now());
    final f = await elegirFecha(
      context,
      inicial: _dia,
      primera: DateTime(hoy.year - 1),
      ultima: DateTime(hoy.year + 5, 12, 31),
      titulo: 'Fecha límite',
    );
    if (f != null) setState(() => _dia = f);
  }

  Future<void> _elegirHora() async {
    final h = await elegirHora(
      context,
      inicial: _hora ?? const TimeOfDay(hour: 18, minute: 0),
      titulo: 'Hora límite',
    );
    if (h != null) setState(() => _hora = h);
  }

  Future<void> _elegirEvaluacion() async {
    if (_materiaId == null) {
      _aviso('Primero elige la materia.');
      return;
    }
    final items = await FirestoreService.instance
        .watchGradeItemsBySubject(_materiaId!)
        .first;
    if (!mounted) return;
    final p = TaskLogPalette.of(context);
    final elegido = await abrirHojaMedia<String>(
      context,
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EncabezadoHoja(titulo: 'Vincular a una evaluación'),
              GrupoIOS(
                children: [
                  FilaIOS(
                    titulo: 'Ninguna',
                    trailing: _evaluacionId == null
                        ? Icon(Icons.check_rounded, color: p.acento)
                        : null,
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                  for (final g in items)
                    FilaIOS(
                      titulo: g.nombre,
                      subtitulo: '${g.porcentaje.toStringAsFixed(0)} % de la '
                          'materia',
                      trailing: g.id == _evaluacionId
                          ? Icon(Icons.check_rounded, color: p.acento)
                          : null,
                      onTap: () => Navigator.of(context).pop(g.id),
                    ),
                ],
              ),
              if (items.isEmpty)
                const PieGrupo(
                  'Esta materia no tiene evaluaciones. Créalas desde '
                  'Materias.',
                ),
            ],
          ),
        ),
      ),
    );
    if (elegido == null) return;
    setState(() {
      _evaluacionId = elegido.isEmpty ? null : elegido;
      if (_evaluacionId == null) _nota.clear();
    });
  }

  /// Próximo lunes (si hoy es lunes, el de la otra semana).
  static DateTime _proximoLunes(DateTime hoy) {
    var dias = (DateTime.monday - hoy.weekday) % 7;
    if (dias == 0) dias = 7;
    return hoy.add(Duration(days: dias));
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final hoy = soloDia(DateTime.now());
    final manana = hoy.add(const Duration(days: 1));
    final lunes = _proximoLunes(hoy);
    final esOtra = _dia != hoy && _dia != manana && _dia != lunes;

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Subject>>(
          stream: FirestoreService.instance.watchSubjects(),
          builder: (context, sSnap) {
            final materias = sSnap.data ?? const <Subject>[];
            if (_materiaId == null && materias.isNotEmpty) {
              _materiaId = materias.first.id;
            }
            Subject? materia;
            for (final m in materias) {
              if (m.id == _materiaId) materia = m;
            }
            return Column(
              children: [
                EncabezadoHoja(
                  titulo: widget.isEditing ? 'Editar tarea' : 'Nueva tarea',
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
                          _CampoTexto(
                            controller: _titulo,
                            hint: 'Título',
                            autofocus: !widget.isEditing,
                          ),
                          _CampoTexto(
                            controller: _notas,
                            hint: 'Notas',
                            lineas: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      GrupoIOS(
                        sangriaSeparador: 58,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              children: [
                                FilaIOS(
                                  leading: const IconoCuadrado(
                                    icono: Icons.calendar_today_rounded,
                                    color: Color(0xFFFF3B30),
                                  ),
                                  titulo: 'Fecha',
                                  subtituloWidget: Text(
                                    _textoDia(_dia),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.acento,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(58, 0, 16, 0),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _Atajo('Hoy', _dia == hoy,
                                            () => setState(() => _dia = hoy)),
                                        _Atajo(
                                          'Mañana',
                                          _dia == manana,
                                          () => setState(() => _dia = manana),
                                        ),
                                        _Atajo(
                                          'Lunes',
                                          _dia == lunes,
                                          () => setState(() => _dia = lunes),
                                        ),
                                        _Atajo(
                                          esOtra
                                              ? DateFormat('d MMM', 'es')
                                                  .format(_dia)
                                              : 'Otra…',
                                          esOtra,
                                          _otraFecha,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilaIOS(
                            leading: const IconoCuadrado(
                              icono: Icons.schedule_rounded,
                              color: Color(0xFF0A84FF),
                            ),
                            titulo: 'Hora',
                            subtituloWidget: _hora == null
                                ? null
                                : GestureDetector(
                                    onTap: _elegirHora,
                                    child: Text(
                                      formatearHora(
                                        context,
                                        DateTime(2000, 1, 1, _hora!.hour,
                                            _hora!.minute),
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: p.acento,
                                      ),
                                    ),
                                  ),
                            trailing: InterruptorIOS(
                              valor: _hora != null,
                              onChanged: (v) {
                                if (v) {
                                  _elegirHora();
                                } else {
                                  setState(() => _hora = null);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (materias.isEmpty)
                        GrupoIOS(
                          children: [
                            FilaIOS(
                              leading: Icon(
                                Icons.add_circle_rounded,
                                color: p.acento,
                              ),
                              tituloWidget: Text(
                                'Crea una materia para continuar',
                                style:
                                    TextStyle(fontSize: 17, color: p.acento),
                              ),
                              onTap: () => abrirFormulario(
                                context,
                                const CrearMateriaScreen(),
                              ),
                            ),
                          ],
                        )
                      else
                        GrupoIOS(
                          sangriaSeparador: 58,
                          children: [
                            FilaIOS(
                              leading: const IconoCuadrado(
                                icono: Icons.school_rounded,
                                color: Color(0xFF5E5CE6),
                              ),
                              titulo: 'Materia',
                              trailing: PopupMenuButton<String>(
                                initialValue: _materiaId,
                                onSelected: (id) => setState(() {
                                  if (id != _materiaId) {
                                    _materiaId = id;
                                    _evaluacionId = null;
                                    _nota.clear();
                                  }
                                }),
                                itemBuilder: (_) => [
                                  for (final m in materias)
                                    PopupMenuItem(
                                      value: m.id,
                                      child: Row(
                                        children: [
                                          PuntoMateria(m.color),
                                          const SizedBox(width: 8),
                                          Text(m.nombre),
                                        ],
                                      ),
                                    ),
                                ],
                                child: _ValorMenu(
                                  materia?.nombre ?? 'Elegir',
                                ),
                              ),
                            ),
                            FilaIOS(
                              leading: const IconoCuadrado(
                                icono: Icons.flag_rounded,
                                color: Color(0xFFFF9500),
                              ),
                              titulo: 'Prioridad',
                              trailing: PopupMenuButton<String>(
                                initialValue: _importancia,
                                onSelected: _cambiarImportancia,
                                itemBuilder: (_) => [
                                  for (final v in const [
                                    'Alta',
                                    'Media',
                                    'Baja',
                                  ])
                                    PopupMenuItem(
                                      value: v,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 30,
                                            child: MarcaPrioridad(
                                              v,
                                              tamano: 15,
                                            ),
                                          ),
                                          Text(v),
                                        ],
                                      ),
                                    ),
                                ],
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    MarcaPrioridad(_importancia, tamano: 15),
                                    const SizedBox(width: 4),
                                    _ValorMenu(
                                      _importancia,
                                      color: AppColors.forImportancia(
                                        _importancia,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            FilaIOS(
                              leading: const IconoCuadrado(
                                icono: Icons.notifications_rounded,
                                color: Color(0xFFAF52DE),
                              ),
                              titulo: 'Recordatorios',
                              valor: _recordatorios.isEmpty
                                  ? 'Ninguno'
                                  : '${_recordatorios.length}',
                              chevron: true,
                              onTap: () async {
                                final nueva = await mostrarHojaRecordatorios(
                                  context,
                                  fechaLimite: _fechaLimite,
                                  actuales: _recordatorios,
                                );
                                if (nueva != null) {
                                  setState(() {
                                    _recordatorios = nueva;
                                    _recordatoriosTocados = true;
                                  });
                                }
                              },
                            ),
                            _FilaEvaluacion(
                              materiaId: _materiaId,
                              evaluacionId: _evaluacionId,
                              onTap: _elegirEvaluacion,
                            ),
                            if (_evaluacionId != null)
                              FilaIOS(
                                titulo: 'Nota obtenida',
                                trailing: SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _nota,
                                    textAlign: TextAlign.right,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: p.texto,
                                    ),
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
                      if (_evaluacionId != null)
                        const PieGrupo(
                          'Déjala vacía si aún no tienes la nota. No cuenta en '
                          'el promedio hasta que la pongas.',
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _textoDia(DateTime d) {
    final s = DateFormat("EEEE d 'de' MMMM", 'es').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// Campo de texto sin borde dentro de un grupo.
class _CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int lineas;
  final bool autofocus;

  const _CampoTexto({
    required this.controller,
    required this.hint,
    this.lineas = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: lineas,
        maxLines: lineas == 1 ? 1 : 6,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 17, color: p.texto),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.texto2),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _Atajo extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback onTap;
  const _Atajo(this.texto, this.activo, this.onTap);

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : p.grupo2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: activo ? Colors.white : p.texto,
          ),
        ),
      ),
    );
  }
}

/// Valor de una fila con menú (texto gris + flechas ⇅).
class _ValorMenu extends StatelessWidget {
  final String texto;
  final Color? color;
  const _ValorMenu(this.texto, {this.color});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, color: color ?? p.texto2),
          ),
        ),
        Icon(Icons.unfold_more_rounded, size: 18, color: p.texto2),
      ],
    );
  }
}

/// Fila «Evaluación» con el nombre de la evaluación vinculada.
class _FilaEvaluacion extends StatelessWidget {
  final String? materiaId;
  final String? evaluacionId;
  final VoidCallback onTap;

  const _FilaEvaluacion({
    required this.materiaId,
    required this.evaluacionId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const icono = IconoCuadrado(
      icono: Icons.link_rounded,
      color: Color(0xFF8E8E93),
    );
    if (materiaId == null || evaluacionId == null) {
      return FilaIOS(
        leading: icono,
        titulo: 'Evaluación',
        valor: 'Ninguna',
        chevron: true,
        onTap: onTap,
      );
    }
    return StreamBuilder<List<GradeItem>>(
      stream: FirestoreService.instance.watchGradeItemsBySubject(materiaId!),
      builder: (context, snap) {
        var nombre = '…';
        for (final g in snap.data ?? const <GradeItem>[]) {
          if (g.id == evaluacionId) nombre = g.nombre;
        }
        return FilaIOS(
          leading: icono,
          titulo: 'Evaluación',
          valor: nombre,
          chevron: true,
          onTap: onTap,
        );
      },
    );
  }
}
