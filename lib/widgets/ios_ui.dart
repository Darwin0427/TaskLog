import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Piezas visuales estilo iOS compartidas por todas las pantallas del
/// rediseño (Turno 5): encabezados grandes, listas agrupadas, filas con
/// ícono en cuadrado de color, segmentados, hojas, etc.

// ─────────────────────────── Encabezado ───────────────────────────

/// Encabezado de una pestaña: botones redondos arriba a la derecha, una
/// línea pequeña opcional (fecha, semestre) y el título grande.
///
/// Va como primer sliver de un `CustomScrollView`.
class EncabezadoGrande extends StatelessWidget {
  final String titulo;
  final String? antetitulo;
  final List<Widget> acciones;
  final Widget? accionIzquierda;

  const EncabezadoGrande({
    super.key,
    required this.titulo,
    this.antetitulo,
    this.acciones = const <Widget>[],
    this.accionIzquierda,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    if (accionIzquierda != null) accionIzquierda!,
                    const Spacer(),
                    for (var i = 0; i < acciones.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      acciones[i],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (antetitulo != null)
                Text(
                  antetitulo!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: p.texto2,
                  ),
                ),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1.15,
                  color: p.texto,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón redondo de 36 px con fondo gris (los de arriba a la derecha y
/// los de volver/editar en los detalles).
class BotonCirculo extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final String tooltip;
  final bool activo;

  const BotonCirculo({
    super.key,
    required this.icono,
    required this.onTap,
    required this.tooltip,
    this.activo = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: activo ? AppColors.primary : p.grupo2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icono,
              size: 20,
              color: activo ? Colors.white : p.texto,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón tipo cápsula con texto (ej. «Hoy», «Editar»).
class BotonCapsula extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  final IconData? icono;

  const BotonCapsula({
    super.key,
    required this.texto,
    required this.onTap,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: p.grupo2,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 16, color: p.texto),
              const SizedBox(width: 4),
            ],
            Text(
              texto,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: p.texto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Círculo morado con la inicial del usuario. Abre Perfil y ajustes.
class AvatarUsuario extends StatelessWidget {
  final VoidCallback? onTap;
  final double tamano;

  const AvatarUsuario({super.key, this.onTap, this.tamano = 36});

  static String iniciales(User? user) {
    final nombre = (user?.displayName ?? '').trim();
    if (nombre.isNotEmpty) {
      final partes =
          nombre.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      final a = partes.first.characters.first.toUpperCase();
      final b = partes.length > 1
          ? partes.last.characters.first.toUpperCase()
          : '';
      return '$a$b';
    }
    final correo = (user?.email ?? '').trim();
    return correo.isEmpty ? '?' : correo.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final texto = iniciales(FirebaseAuth.instance.currentUser);
    return Semantics(
      button: true,
      label: 'Perfil y ajustes',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: tamano,
          height: tamano,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: tamano * (texto.length > 1 ? 0.38 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Listas agrupadas ───────────────────────────

/// Lista agrupada de iOS: tarjeta redondeada con filas separadas por
/// líneas finas que no llegan al borde izquierdo.
class GrupoIOS extends StatelessWidget {
  final List<Widget> children;
  final double sangriaSeparador;
  final EdgeInsetsGeometry margin;

  const GrupoIOS({
    super.key,
    required this.children,
    this.sangriaSeparador = 16,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: p.grupo,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: sangriaSeparador,
                    color: p.separador,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de una lista agrupada.
class FilaIOS extends StatelessWidget {
  final Widget? leading;
  final String titulo;
  final Widget? tituloWidget;
  final String? subtitulo;
  final Widget? subtituloWidget;
  final String? valor;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;
  final Color? colorTitulo;

  const FilaIOS({
    super.key,
    this.leading,
    this.titulo = '',
    this.tituloWidget,
    this.subtitulo,
    this.subtituloWidget,
    this.valor,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.colorTitulo,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                tituloWidget ??
                    Text(
                      titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        color: colorTitulo ?? p.texto,
                      ),
                    ),
                if (subtituloWidget != null) ...[
                  const SizedBox(height: 2),
                  subtituloWidget!,
                ] else if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.texto2),
                  ),
                ],
              ],
            ),
          ),
          if (valor != null) ...[
            const SizedBox(width: 8),
            Text(valor!, style: TextStyle(fontSize: 17, color: p.texto2)),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (chevron) ...[
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 22, color: p.grupo3),
          ],
        ],
      ),
    );
    if (onTap == null) return contenido;
    return InkWell(onTap: onTap, child: contenido);
  }
}

/// Ícono blanco dentro de un cuadrado redondeado de color (estilo Ajustes).
class IconoCuadrado extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double tamano;

  const IconoCuadrado({
    super.key,
    required this.icono,
    required this.color,
    this.tamano = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tamano * 0.24),
      ),
      child: Icon(icono, color: Colors.white, size: tamano * 0.62),
    );
  }
}

/// Título de sección de una lista (ej. «Hoy», «Atrasadas»).
class TituloSeccion extends StatelessWidget {
  final String texto;
  final Color? color;
  final Widget? trailing;

  const TituloSeccion(this.texto, {super.key, this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color ?? p.texto,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Etiqueta gris en mayúsculas sobre un grupo (estilo formularios iOS).
class EtiquetaGrupo extends StatelessWidget {
  final String texto;
  const EtiquetaGrupo(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          letterSpacing: 0.3,
          color: p.texto2,
        ),
      ),
    );
  }
}

/// Texto gris pequeño debajo de un grupo.
class PieGrupo extends StatelessWidget {
  final String texto;
  final Color? color;
  final IconData? icono;
  const PieGrupo(this.texto, {super.key, this.color, this.icono});

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final c = color ?? p.texto2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: c),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 13, color: c)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Marcas pequeñas ───────────────────────────

/// Prioridad al estilo Recordatorios de iOS: «!!!» Alta, «!!» Media,
/// «!» Baja, en su color.
class MarcaPrioridad extends StatelessWidget {
  final String importancia;
  final double tamano;
  const MarcaPrioridad(this.importancia, {super.key, this.tamano = 17});

  static String signos(String importancia) => switch (importancia) {
        'Alta' => '!!!',
        'Media' => '!!',
        'Baja' => '!',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    return Text(
      signos(importancia),
      style: TextStyle(
        fontSize: tamano,
        fontWeight: FontWeight.w700,
        color: AppColors.forImportancia(importancia),
      ),
    );
  }
}

/// Punto de color de una materia.
class PuntoMateria extends StatelessWidget {
  final Color color;
  final double tamano;
  const PuntoMateria(this.color, {super.key, this.tamano = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Círculo para marcar una tarea como hecha (como en Recordatorios).
class CirculoCompletar extends StatelessWidget {
  final bool completada;
  final VoidCallback? onTap;
  final Color? color;

  const CirculoCompletar({
    super.key,
    required this.completada,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final c = color ?? p.acento;
    return Semantics(
      button: true,
      checked: completada,
      label: completada ? 'Marcar como pendiente' : 'Marcar como completada',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completada ? c : Colors.transparent,
              border: Border.all(
                color: completada ? c : p.grupo3,
                width: 1.6,
              ),
            ),
            child: completada
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Píldora pequeña (ej. materia o evaluación vinculada).
class Pildora extends StatelessWidget {
  final String texto;
  final Color? colorPunto;
  final IconData? icono;
  final bool seleccionada;
  final VoidCallback? onTap;

  const Pildora({
    super.key,
    required this.texto,
    this.colorPunto,
    this.icono,
    this.seleccionada = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final fondo = seleccionada ? p.texto : p.grupo2;
    final colorTexto = seleccionada ? p.fondo : p.texto;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (colorPunto != null) ...[
              PuntoMateria(colorPunto!, tamano: 7),
              const SizedBox(width: 6),
            ],
            if (icono != null) ...[
              Icon(icono, size: 13, color: colorTexto),
              const SizedBox(width: 4),
            ],
            Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Controles ───────────────────────────

/// Control segmentado de iOS con los colores de TaskLog.
class SegmentadoIOS<T extends Object> extends StatelessWidget {
  final Map<T, String> opciones;
  final T valor;
  final ValueChanged<T> onChanged;

  const SegmentadoIOS({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: valor,
        backgroundColor: p.grupo2,
        thumbColor: dark ? const Color(0xFF636366) : Colors.white,
        padding: const EdgeInsets.all(2),
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
        children: <T, Widget>{
          for (final e in opciones.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      e.key == valor ? FontWeight.w600 : FontWeight.w500,
                  color: p.texto,
                ),
              ),
            ),
        },
      ),
    );
  }
}

/// Interruptor de iOS (verde) con el estilo del sistema.
class InterruptorIOS extends StatelessWidget {
  final bool valor;
  final ValueChanged<bool> onChanged;
  const InterruptorIOS({
    super.key,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
        value: valor,
        activeTrackColor: const Color(0xFF34C759),
        onChanged: onChanged,
      );
}

/// Botón principal ancho (morado, en cápsula).
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool cargando;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: cargando ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          shape: const StadiumBorder(),
        ),
        child: cargando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(texto),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────── Hojas ───────────────────────────

/// Encabezado de hoja: «X» a la izquierda, título al centro y «✓» morado a
/// la derecha (o un texto de acción).
class EncabezadoHoja extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onConfirmar;
  final VoidCallback? onCerrar;
  final Widget? izquierda;
  final bool guardando;

  const EncabezadoHoja({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.onConfirmar,
    this.onCerrar,
    this.izquierda,
    this.guardando = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Align(
              alignment: Alignment.centerLeft,
              child: izquierda ??
                  BotonCirculo(
                    icono: Icons.close_rounded,
                    tooltip: 'Cerrar',
                    onTap: onCerrar ?? () => Navigator.of(context).maybePop(),
                  ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: p.texto,
                  ),
                ),
                if (subtitulo != null)
                  Text(
                    subtitulo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.texto2),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Align(
              alignment: Alignment.centerRight,
              child: onConfirmar == null
                  ? const SizedBox.shrink()
                  : guardando
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : BotonCirculo(
                          icono: Icons.check_rounded,
                          tooltip: 'Guardar',
                          activo: true,
                          onTap: onConfirmar,
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abre una hoja de altura completa (formularios). La pantalla anterior
/// queda visible detrás, como en iOS.
Future<T?> abrirHoja<T>(BuildContext context, Widget hoja) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => hoja,
  );
}

/// Abre una hoja de media altura que se ajusta a su contenido.
Future<T?> abrirHojaMedia<T>(BuildContext context, Widget hoja) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: hoja,
    ),
  );
}

/// Diálogo de confirmación estilo iOS (ej. eliminar). Devuelve true si el
/// usuario confirmó.
Future<bool> confirmarIOS(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String accion = 'Eliminar',
  bool destructiva = true,
}) async {
  final r = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructiva,
          isDefaultAction: !destructiva,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return r ?? false;
}

// ─────────────────────────── Utilidades ───────────────────────────

/// Fecha sin hora (medianoche).
DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

/// True si la fecha tiene una hora puesta (distinta de 00:00).
bool tieneHora(DateTime d) => d.hour != 0 || d.minute != 0;

/// Formatea una hora según el ajuste 12/24 h del teléfono.
String formatearHora(BuildContext context, DateTime d) {
  final t = TimeOfDay(hour: d.hour, minute: d.minute);
  return MaterialLocalizations.of(context).formatTimeOfDay(
    t,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
