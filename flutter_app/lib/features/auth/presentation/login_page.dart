import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

import '../../../l10n/l10n.dart';
import 'auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final success = await widget.authController.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    final error =
        widget.authController.errorMessage ?? context.l10n.loginFailed;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoading = widget.authController.isLoading;

    return Scaffold(
      appBar: GFAppBar(title: Text(l10n.loginTitle), centerTitle: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.loginDescription,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: l10n.loginEmailLabel,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty || !text.contains('@')) {
                      return l10n.loginEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: l10n.loginPasswordLabel,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return l10n.loginPasswordRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                GFButton(
                  onPressed: isLoading ? null : _submit,
                  text: isLoading ? l10n.loginSigningIn : l10n.signIn,
                  fullWidthButton: true,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.loginNativeOnlyNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
