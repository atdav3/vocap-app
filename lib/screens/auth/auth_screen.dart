import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _fillDemo(String username, String password) {
    setState(() {
      _register = false;
      _email.text = username;
      _password.text = password;
    });
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Brand Header
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryIndigo,
                                    AppTheme.primaryCyan,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryIndigo.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                size: 34,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'VOCAP',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppTheme.primaryIndigo,
                                        AppTheme.primaryCyan,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'PRO MAX',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Học từ vựng thông minh theo phương pháp Spaced Repetition',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Segmented Tab Switch (Login / Register)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurfaceHigh
                              : AppTheme.lightSurfaceHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _register = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_register
                                        ? (isDark
                                              ? AppTheme.darkSurface
                                              : AppTheme.lightSurface)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: !_register
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    'Đăng nhập',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: !_register
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: !_register
                                          ? AppTheme.primaryIndigo
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _register = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _register
                                        ? (isDark
                                              ? AppTheme.darkSurface
                                              : AppTheme.lightSurface)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: _register
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 4,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    'Tạo tài khoản',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: _register
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _register
                                          ? AppTheme.primaryIndigo
                                          : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Input Fields
                      if (_register) ...[
                        _field(_name, 'Họ và tên', icon: Icons.badge_outlined),
                        _field(
                          _email,
                          'Email',
                          icon: Icons.alternate_email_rounded,
                          keyboard: TextInputType.emailAddress,
                        ),
                        _field(
                          _username,
                          'Email Firebase',
                          icon: Icons.account_circle_outlined,
                        ),
                      ] else
                        _field(
                          _email,
                          FirebaseBootstrap.isConfigured
                              ? 'Email'
                              : 'Email Firebase',
                          icon: FirebaseBootstrap.isConfigured
                              ? Icons.alternate_email_rounded
                              : Icons.account_circle_outlined,
                        ),
                      _field(
                        _password,
                        'Mật khẩu',
                        icon: Icons.lock_outline_rounded,
                        secret: true,
                      ),
                      if (_register)
                        _field(
                          _confirm,
                          'Nhập lại mật khẩu',
                          icon: Icons.shield_outlined,
                          secret: true,
                          validator: (value) => value != _password.text
                              ? 'Mật khẩu chưa khớp.'
                              : null,
                        ),

                      if (context.watch<AuthProvider>().error
                          case final String error)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.error.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: theme.colorScheme.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    error,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Submit Button
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          backgroundColor: AppTheme.primaryIndigo,
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _register
                                    ? 'Tạo tài khoản & Bắt đầu học'
                                    : 'Đăng nhập vào Vocap',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),

                      if (!_register)
                        Center(
                          child: TextButton(
                            onPressed: _showForgotPassword,
                            child: Text(
                              'Quên mật khẩu?',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                      // Fast 1-Tap Demo Credentials for Web and Android Testers
                      if (!_register && !FirebaseBootstrap.isConfigured) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: AppTheme.accentAmber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Đăng nhập nhanh thử nghiệm (1-Tap):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _fillDemo('learner', 'password123'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Học viên (learner)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _fillDemo('admin', 'adminpass123'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Quản trị (admin)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    IconData? icon,
    TextInputType? keyboard,
    bool secret = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: secret && _obscure,
      validator:
          validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Vui lòng nhập $label.';
            }
            if (_register &&
                controller == _email &&
                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
              return 'Email không hợp lệ.';
            }
            if (controller == _username && value.trim().length < 3) {
              return 'Tên đăng nhập cần ít nhất 3 ký tự.';
            }
            if (controller == _password && _register && value.length < 10) {
              return 'Mật khẩu cần ít nhất 10 ký tự.';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: secret
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
              )
            : null,
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final repository = context.read<AuthRepository>();
    try {
      if (_register) {
        await auth.run(
          () => repository.register(
            name: _name.text,
            email: _email.text,
            username: _username.text,
            password: _password.text,
          ),
        );
      } else {
        await auth.run(
          () => repository.signIn(
            emailOrUsername: _email.text,
            password: _password.text,
          ),
        );
      }
    } catch (_) {
      // Localized error handled by AuthProvider
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showForgotPassword() {
    if (FirebaseBootstrap.isConfigured) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đặt lại mật khẩu'),
          content: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final repository = dialogContext.read<AuthRepository>();
                final messenger = ScaffoldMessenger.of(dialogContext);
                try {
                  await repository.sendPasswordResetEmail(_email.text);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Đã gửi liên kết đặt lại mật khẩu.'),
                    ),
                  );
                } catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              },
              child: const Text('Gửi liên kết'),
            ),
          ],
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quên mật khẩu?'),
        content: const Text(
          'Chức năng đặt lại mật khẩu có thể thực hiện qua quản trị viên hoặc kết nối API Cloud. Bạn cũng có thể dùng nút Đăng nhập nhanh để trải nghiệm ứng dụng ngay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
}
