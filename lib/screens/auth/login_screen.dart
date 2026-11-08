import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/ios_ui.dart';
import '../../widgets/logo_tasklog.dart';
import 'register_screen.dart';

/// Inicio de sesión: logo, campos agrupados en una tarjeta (como Ajustes),
/// «¿Olvidaste tu contraseña?» y los botones abajo, al alcance del pulgar.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ver = false;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _correo.addListener(() => setState(() {}));
    _clave.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  bool get _listo => _correo.text.contains('@') && _clave.text.isNotEmpty;

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() => _cargando = true);
    try {
      await AuthService.instance
          .signIn(email: _correo.text, password: _clave.text);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvide() async {
    final ctrl = TextEditingController(text: _correo.text.trim());
    final correo = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            const Text('Te enviaremos un enlace para crear una nueva.'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              placeholder: 'Correo',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (correo == null || !correo.contains('@') || !mounted) return;
    try {
      await AuthService.instance.enviarRecuperacion(correo);
      if (mounted) {
        showSuccessSnackBar(
          context,
          'Listo. Revisa tu correo (y la carpeta de spam).',
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    const SizedBox(height: 56),
                    const LogoTaskLog(tamano: 72),
                    const SizedBox(height: 20),
                    Text(
                      'Inicia sesión',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: p.texto,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tus tareas, notas y apuntes del semestre en un solo '
                      'lugar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: p.texto2),
                    ),
                    const SizedBox(height: 28),
                    GrupoIOS(
                      children: [
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
                          hint: 'Requerida',
                          oculto: !_ver,
                          autofill: const [AutofillHints.password],
                          alEnviar: _listo ? _entrar : null,
                          sufijo: IconButton(
                            tooltip: _ver
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                            icon: Icon(
                              _ver
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: p.texto2,
                            ),
                            onPressed: () => setState(() => _ver = !_ver),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _olvide,
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    BotonPrincipal(
                      texto: 'Continuar',
                      cargando: _cargando,
                      onPressed: _listo ? _entrar : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¿No tienes cuenta?',
                          style: TextStyle(fontSize: 15, color: p.texto2),
                        ),
                        TextButton(
                          onPressed: _cargando
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                          child: const Text(
                            'Crear cuenta',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Campo dentro de un grupo con la etiqueta a la izquierda (como Ajustes →
/// Cuentas).
class CampoEtiquetado extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controller;
  final String hint;
  final bool oculto;
  final TextInputType teclado;
  final Widget? sufijo;
  final Iterable<String>? autofill;
  final VoidCallback? alEnviar;
  final TextCapitalization mayusculas;

  const CampoEtiquetado({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.hint,
    this.oculto = false,
    this.teclado = TextInputType.text,
    this.sufijo,
    this.autofill,
    this.alEnviar,
    this.mayusculas = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final p = TaskLogPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(left: 16, right: sufijo == null ? 16 : 4),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 17, color: p.texto),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: oculto,
              keyboardType: teclado,
              autocorrect: false,
              enableSuggestions: !oculto,
              textCapitalization: mayusculas,
              autofillHints: autofill,
              textInputAction:
                  alEnviar == null ? TextInputAction.next : TextInputAction.go,
              onSubmitted: alEnviar == null ? null : (_) => alEnviar!(),
              style: TextStyle(fontSize: 17, color: p.texto),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: p.texto2),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
          ?sufijo,
        ],
      ),
    );
  }
}
