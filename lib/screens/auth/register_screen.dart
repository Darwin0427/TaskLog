import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/ios_ui.dart';
import 'login_screen.dart';

/// Crear cuenta: nombre, correo, contraseña y confirmación en un grupo.
/// Los requisitos de la contraseña se van marcando mientras escribes y el
/// botón se activa cuando todo se cumple.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _confirmar = TextEditingController();
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_nombre, _correo, _clave, _confirmar]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  bool get _largo => _clave.text.length >= 8;
  bool get _letraYNumero =>
      RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(_clave.text) &&
      RegExp(r'\d').hasMatch(_clave.text);
  bool get _coinciden =>
      _clave.text.isNotEmpty && _clave.text == _confirmar.text;
  bool get _listo =>
      _nombre.text.trim().isNotEmpty &&
      _correo.text.contains('@') &&
      _largo &&
      _letraYNumero &&
      _coinciden;

  Future<void> _crear() async {
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      await AuthService.instance.register(
        email: _correo.text,
        password: _clave.text,
        nombre: _nombre.text,
      );
      // AuthGate cambia a la app; cerramos esta pantalla.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BotonCirculo(
                icono: Icons.chevron_left_rounded,
                tooltip: 'Volver',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Crea tu cuenta',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: p.texto,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Solo te tomará un minuto.',
              style: TextStyle(fontSize: 16, color: p.texto2),
            ),
            const SizedBox(height: 24),
            GrupoIOS(
              children: [
                CampoEtiquetado(
                  etiqueta: 'Nombre',
                  controller: _nombre,
                  hint: 'Nombre y apellido',
                  autofill: const [AutofillHints.name],
                  mayusculas: TextCapitalization.words,
                ),
                CampoEtiquetado(
                  etiqueta: 'Correo',
                  controller: _correo,
                  hint: 'tu@correo.com',
                  teclado: TextInputType.emailAddress,
                  autofill: const [AutofillHints.email],
                ),
                CampoEtiquetado(
                  etiqueta: 'Contraseña',
                  controller: _clave,
                  hint: 'Mínimo 8 caracteres',
                  oculto: true,
                  autofill: const [AutofillHints.newPassword],
                ),
                CampoEtiquetado(
                  etiqueta: 'Confirmar',
                  controller: _confirmar,
                  hint: 'Repítela',
                  oculto: true,
                  autofill: const [AutofillHints.newPassword],
                  alEnviar: _listo ? _crear : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Requisito('Al menos 8 caracteres', _largo),
            _Requisito('Una letra y un número', _letraYNumero),
            _Requisito('Las contraseñas coinciden', _coinciden),
            const SizedBox(height: 32),
            BotonPrincipal(
              texto: 'Crear cuenta',
              cargando: _cargando,
              onPressed: _listo ? _crear : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Requisito extends StatelessWidget {
  final String texto;
  final bool cumple;
  const _Requisito(this.texto, this.cumple);

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      child: Row(
        children: [
          Icon(
            cumple ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: cumple ? AppColors.lowPriority : p.texto2,
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              color: cumple ? p.texto : p.texto2,
            ),
          ),
        ],
      ),
    );
  }
}
