import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';
import '../../models/subject.dart';
import '../../models/task_item.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/ios_ui.dart';

/// Editor de apuntes. Crear y ver son la misma pantalla: el contenido se
/// lee con las casillas tocables y, si tocas el texto, pasas a editarlo.
///
/// Las listas de verificación se guardan como texto («- [ ] » y
/// «- [x] » al inicio de la línea), así funcionan con los apuntes que ya
/// existían.
class CrearNotaScreen extends StatefulWidget {
  final Note? existing;
  final String? defaultSubjectId;
  final String? taskId;

  const CrearNotaScreen({
    super.key,
    this.existing,
    this.defaultSubjectId,
    this.taskId,
  });

  bool get isEditing => existing != null;

  @override
  State<CrearNotaScreen> createState() => _CrearNotaScreenState();
}

const String _casillaVacia = '- [ ] ';
const String _casillaMarcada = '- [x] ';

bool _esCasilla(String l) =>
    l.startsWith(_casillaVacia) ||
    l.startsWith(_casillaMarcada) ||
    l.startsWith('- [X] ');

class _CrearNotaScreenState extends State<CrearNotaScreen> {
  late final TextEditingController _titulo;
  late final TextEditingController _contenido;
  final FocusNode _focoContenido = FocusNode();

  String? _materiaId;
  String? _tareaId;
  String? _idGuardado;
  late bool _editando;
  bool _guardando = false;
  bool _sinCambios = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titulo = TextEditingController(text: e?.titulo ?? '');
    _contenido = TextEditingController(text: e?.contenido ?? '');
    _materiaId = e?.subjectId ?? widget.defaultSubjectId;
    _tareaId = e?.taskId ?? widget.taskId;
    _idGuardado = e?.id;
    // Un apunte nuevo abre escribiendo; uno existente abre para leer.
    _editando = e == null;
    _titulo.addListener(_marcarCambio);
    _contenido.addListener(_marcarCambio);
  }

  void _marcarCambio() {
    if (_sinCambios) setState(() => _sinCambios = false);
  }

  @override
  void dispose() {
    _titulo.dispose();
    _contenido.dispose();
    _focoContenido.dispose();
    super.dispose();
  }

  bool get _vacio =>
      _titulo.text.trim().isEmpty && _contenido.text.trim().isEmpty;

  /// Guarda si hubo cambios. Devuelve false si no se pudo guardar.
  Future<bool> _guardar() async {
    if (_sinCambios || _vacio) return true;
    if (_materiaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige una materia para el apunte.')),
      );
      return false;
    }
    setState(() => _guardando = true);
    try {
      var titulo = _titulo.text.trim();
      if (titulo.isEmpty) {
        titulo = _contenido.text
            .split('\n')
            .map((l) => _esCasilla(l) ? l.substring(6) : l)
            .map((l) => l.trim())
            .firstWhere((l) => l.isNotEmpty, orElse: () => 'Sin título');
        if (titulo.length > 60) titulo = '${titulo.substring(0, 60)}…';
      }
      final nota = Note(
        id: _idGuardado ?? '',
        titulo: titulo,
        contenido: _contenido.text.trimRight(),
        subjectId: _materiaId!,
        importancia: widget.existing?.importancia ?? 'Media',
        taskId: _tareaId,
      );
      if (_idGuardado != null) {
        await FirestoreService.instance.updateNote(_idGuardado!, nota);
      } else {
        _idGuardado = await FirestoreService.instance.addNote(nota);
      }
      if (mounted) {
        setState(() {
          _sinCambios = true;
          _guardando = false;
        });
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        showErrorSnackBar(context, e);
      }
      return false;
    }
  }

  Future<void> _cerrar() async {
    final ok = await _guardar();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _eliminar() async {
    final ok = await confirmarIOS(
      context,
      titulo: '¿Eliminar apunte?',
      mensaje: 'Esto no se puede deshacer.',
    );
    if (!ok) return;
    try {
      if (_idGuardado != null) {
        await FirestoreService.instance.deleteNote(_idGuardado!);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  // ───────────── casillas ─────────────

  void _alternarCasilla(int indiceLinea) {
    final lineas = _contenido.text.split('\n');
    final l = lineas[indiceLinea];
    lineas[indiceLinea] = l.startsWith(_casillaVacia)
        ? _casillaMarcada + l.substring(6)
        : _casillaVacia + l.substring(6);
    _contenido.text = lineas.join('\n');
    _guardar();
  }

  /// Convierte la línea donde está el cursor en casilla (o la vuelve
  /// texto normal si ya lo era).
  void _insertarCasilla() {
    final texto = _contenido.text;
    final sel = _contenido.selection;
    final pos = sel.isValid ? sel.baseOffset.clamp(0, texto.length) : texto.length;
    final inicio = texto.lastIndexOf('\n', pos == 0 ? 0 : pos - 1) + 1;
    final linea = texto.substring(inicio);
    String nuevo;
    int nuevoCursor;
    if (_esCasilla(linea)) {
      nuevo = texto.replaceRange(inicio, inicio + 6, '');
      nuevoCursor = (pos - 6).clamp(inicio, nuevo.length);
    } else {
      nuevo = texto.replaceRange(inicio, inicio, _casillaVacia);
      nuevoCursor = pos + 6;
    }
    _contenido.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: nuevoCursor),
    );
  }

  /// Al pulsar Enter en una casilla, la línea nueva también es casilla
  /// (y una casilla vacía + Enter la quita), como en Notas de iOS.
  void _alCambiarContenido(String valor) {
    final sel = _contenido.selection;
    if (!sel.isValid || sel.baseOffset == 0) return;
    final pos = sel.baseOffset;
    if (pos > valor.length || valor[pos - 1] != '\n') return;
    final inicioAnterior =
        pos - 2 < 0 ? 0 : valor.lastIndexOf('\n', pos - 2) + 1;
    final anterior = valor.substring(inicioAnterior, pos - 1);
    if (!_esCasilla(anterior)) return;
    if (anterior.trim() == '- [ ]' || anterior.length <= 6) {
      // Casilla vacía: se quita y se sale de la lista.
      final nuevo = valor.replaceRange(inicioAnterior, pos, '');
      _contenido.value = TextEditingValue(
        text: nuevo,
        selection: TextSelection.collapsed(offset: inicioAnterior),
      );
      return;
    }
    final nuevo = valor.replaceRange(pos, pos, _casillaVacia);
    _contenido.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: pos + 6),
    );
  }

  // ───────────── selección de materia / tarea ─────────────

  Future<void> _elegirMateria(List<Subject> materias) async {
    final elegido = await abrirHojaMedia<String>(
      context,
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EncabezadoHoja(titulo: 'Materia'),
              GrupoIOS(
                sangriaSeparador: 58,
                children: [
                  for (final m in materias)
                    FilaIOS(
                      leading: IconoCuadrado(icono: m.icon, color: m.color),
                      titulo: m.nombre,
                      trailing: m.id == _materiaId
                          ? Icon(Icons.check_rounded,
                              color: TaskLogPalette.of(context).acento)
                          : null,
                      onTap: () => Navigator.of(context).pop(m.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido != null && elegido != _materiaId) {
      setState(() {
        _materiaId = elegido;
        _tareaId = null;
        _sinCambios = false;
      });
      if (!_editando) _guardar();
    }
  }

  Future<void> _elegirTarea() async {
    if (_materiaId == null) return;
    final tareas = await FirestoreService.instance
        .watchTasksBySubject(_materiaId!)
        .first;
    if (!mounted) return;
    final elegido = await abrirHojaMedia<String>(
      context,
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EncabezadoHoja(titulo: 'Vincular a una tarea'),
              GrupoIOS(
                children: [
                  FilaIOS(
                    titulo: 'Ninguna',
                    trailing: _tareaId == null
                        ? Icon(Icons.check_rounded,
                            color: TaskLogPalette.of(context).acento)
                        : null,
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                  for (final t in tareas)
                    FilaIOS(
                      titulo: t.titulo,
                      subtitulo:
                          'Vence ${DateFormat('d MMM', 'es').format(t.fechaLimite)}',
                      trailing: t.id == _tareaId
                          ? Icon(Icons.check_rounded,
                              color: TaskLogPalette.of(context).acento)
                          : null,
                      onTap: () => Navigator.of(context).pop(t.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (elegido == null) return;
    setState(() {
      _tareaId = elegido.isEmpty ? null : elegido;
      _sinCambios = false;
    });
    if (!_editando) _guardar();
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final fecha = widget.existing?.creadoEn ?? DateTime.now();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cerrar();
      },
      child: Scaffold(
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
                  _barra(p),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        Center(
                          child: Text(
                            DateFormat("d 'de' MMMM 'de' y, HH:mm", 'es')
                                .format(fecha),
                            style: TextStyle(fontSize: 12, color: p.texto2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titulo,
                          readOnly: !_editando,
                          onTap: () {
                            if (!_editando) setState(() => _editando = true);
                          },
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: null,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: p.texto,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Título',
                            hintStyle: TextStyle(color: p.texto2),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Pildora(
                              texto: materia?.nombre ??
                                  (materias.isEmpty
                                      ? 'Crea una materia primero'
                                      : 'Elegir materia'),
                              colorPunto: materia?.color,
                              onTap: materias.isEmpty
                                  ? null
                                  : () => _elegirMateria(materias),
                            ),
                            _PildoraTarea(
                              tareaId: _tareaId,
                              onTap: _elegirTarea,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_editando)
                          TextField(
                            controller: _contenido,
                            focusNode: _focoContenido,
                            autofocus: widget.existing != null,
                            maxLines: null,
                            minLines: 8,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: _alCambiarContenido,
                            style: TextStyle(
                              fontSize: 17,
                              height: 1.4,
                              color: p.texto,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Escribe aquí…',
                              hintStyle: TextStyle(color: p.texto2),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                        else
                          _Lectura(
                            texto: _contenido.text,
                            onAlternar: _alternarCasilla,
                            onEditar: () {
                              setState(() => _editando = true);
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => _focoContenido.requestFocus(),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  if (_editando) _barraFormato(p),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _barra(TaskLogPalette p) {
    final estado = _guardando
        ? 'Guardando…'
        : (_sinCambios && _idGuardado != null)
            ? 'Guardado'
            : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          BotonCirculo(
            icono: widget.isEditing
                ? Icons.chevron_left_rounded
                : Icons.close_rounded,
            tooltip: 'Cerrar',
            onTap: _cerrar,
          ),
          Expanded(
            child: estado == null
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PuntoMateria(
                        _guardando ? p.texto2 : AppColors.lowPriority,
                        tamano: 7,
                      ),
                      const SizedBox(width: 6),
                      Text(estado,
                          style: TextStyle(fontSize: 13, color: p.texto2)),
                    ],
                  ),
          ),
          if (_idGuardado != null) ...[
            BotonCirculo(
              icono: Icons.delete_outline_rounded,
              tooltip: 'Eliminar apunte',
              onTap: _eliminar,
            ),
            const SizedBox(width: 10),
          ],
          BotonCirculo(
            icono: Icons.check_rounded,
            tooltip: 'Listo',
            activo: true,
            onTap: () async {
              FocusScope.of(context).unfocus();
              final ok = await _guardar();
              if (!ok || !mounted) return;
              if (widget.isEditing || _idGuardado != null) {
                setState(() => _editando = false);
                if (!widget.isEditing) Navigator.of(context).pop(true);
              } else {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _barraFormato(TaskLogPalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.grupo,
        border: Border(top: BorderSide(color: p.separador, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Lista de verificación',
            icon: Icon(Icons.checklist_rounded, color: p.acento),
            onPressed: _insertarCasilla,
          ),
          IconButton(
            tooltip: 'Viñeta',
            icon: Icon(Icons.format_list_bulleted_rounded, color: p.acento),
            onPressed: () {
              final t = _contenido.text;
              final sel = _contenido.selection;
              final pos =
                  sel.isValid ? sel.baseOffset.clamp(0, t.length) : t.length;
              final inicio = t.lastIndexOf('\n', pos == 0 ? 0 : pos - 1) + 1;
              _contenido.value = TextEditingValue(
                text: t.replaceRange(inicio, inicio, '• '),
                selection: TextSelection.collapsed(offset: pos + 2),
              );
            },
          ),
          const Spacer(),
          TextButton(
            onPressed: () => FocusScope.of(context).unfocus(),
            child: const Text('Ocultar teclado'),
          ),
        ],
      ),
    );
  }
}

/// Píldora de la tarea vinculada (muestra su título).
class _PildoraTarea extends StatelessWidget {
  final String? tareaId;
  final VoidCallback onTap;
  const _PildoraTarea({required this.tareaId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (tareaId == null) {
      return Pildora(
        texto: 'Vincular tarea',
        icono: Icons.link_rounded,
        onTap: onTap,
      );
    }
    return StreamBuilder<TaskItem?>(
      stream: FirestoreService.instance.watchTask(tareaId!),
      builder: (context, snap) => Pildora(
        texto: snap.data?.titulo ?? 'Tarea',
        icono: Icons.link_rounded,
        onTap: onTap,
      ),
    );
  }
}

/// Contenido en modo lectura: las casillas se pueden marcar con un toque;
/// tocar el resto pasa a editar.
class _Lectura extends StatelessWidget {
  final String texto;
  final ValueChanged<int> onAlternar;
  final VoidCallback onEditar;

  const _Lectura({
    required this.texto,
    required this.onAlternar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final lineas = texto.split('\n');
    final estilo = TextStyle(fontSize: 17, height: 1.4, color: p.texto);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEditar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 240),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (texto.trim().isEmpty)
              Text('Toca para escribir…',
                  style: estilo.copyWith(color: p.texto2)),
            for (var i = 0; i < lineas.length; i++)
              if (_esCasilla(lineas[i]))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CirculoCompletar(
                        completada: !lineas[i].startsWith(_casillaVacia),
                        onTap: () => onAlternar(i),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lineas[i].substring(6),
                          style: lineas[i].startsWith(_casillaVacia)
                              ? estilo
                              : estilo.copyWith(
                                  color: p.texto2,
                                  decoration: TextDecoration.lineThrough,
                                ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(lineas[i], style: estilo),
          ],
        ),
      ),
    );
  }
}
