import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/student_profile.dart';
import '../providers/chat_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_branding.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  final Future<void> Function() onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;
  bool _isBusy = false;
  bool _showVerificationState = false;
  bool _isCheckingVerification = false;
  Timer? _verificationTimer;

  StudentProfile? get _previewProfile {
    final String email = _emailController.text.trim().toLowerCase();
    if (!StudentProfile.isValidEwuEmail(email)) {
      return null;
    }
    return StudentProfile.fromEmail(email: email);
  }

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user != null && !user.emailVerified) {
      _showVerificationPending();
    }
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showVerificationPending() {
    setState(() {
      _showVerificationState = true;
    });
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkVerification(),
    );
  }

  Future<void> _checkVerification() async {
    if (_isCheckingVerification) {
      return;
    }

    _isCheckingVerification = true;
    try {
      final bool verified = await AuthService.checkEmailVerified();
      if (!verified || !mounted) {
        return;
      }
      _verificationTimer?.cancel();
      await context.read<ChatProvider>().refreshProfile();
      await widget.onLoginSuccess();
    } catch (_) {
      // The verification view already explains what the user should do next.
    } finally {
      _isCheckingVerification = false;
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;

    try {
      final user = _isLoginMode
          ? await AuthService.signIn(email, password)
          : await AuthService.register(email, password);

      if (!mounted) {
        return;
      }

      if (user != null && user.emailVerified) {
        await context.read<ChatProvider>().refreshProfile();
        await widget.onLoginSuccess();
      } else {
        _showVerificationPending();
        _showMessage(
          _isLoginMode
              ? 'Please verify your email before continuing.'
              : 'Account created. Please verify your email to continue.',
        );
      }
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isBusy = true;
    });

    try {
      final user = await AuthService.signInWithGoogle();
      if (!mounted || user == null) {
        return;
      }
      if (user.emailVerified) {
        await context.read<ChatProvider>().refreshProfile();
        await widget.onLoginSuccess();
      } else {
        _showVerificationPending();
        _showMessage('Please verify your email before continuing.');
      }
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _ForgotPasswordDialog(
          initialEmail: _emailController.text.trim(),
          onMessage: _showMessage,
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.glassCard,
                  child: _showVerificationState
                      ? _buildVerificationState()
                      : _buildAuthForm(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    final StudentProfile? preview = _previewProfile;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppBrandLockup(
            markSize: 72,
            wordmarkHeight: 34,
            subtitle:
                'Sign in with your EWU student email or the approved access email to use the voice assistant and campus platform.',
          ),
          const SizedBox(height: 18),
          Text(
            _isLoginMode ? 'Welcome back' : 'Create your account',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F3F8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _ModeButton(
                    label: 'Login',
                    selected: _isLoginMode,
                    onTap: () {
                      setState(() {
                        _isLoginMode = true;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _ModeButton(
                    label: 'Register',
                    selected: !_isLoginMode,
                    onTap: () {
                      setState(() {
                        _isLoginMode = false;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[
              AutofillHints.username,
              AutofillHints.email,
            ],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Student or approved email',
              hintText: '2022-1-60-001@std.ewubd.edu',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (String? value) {
              final String email = value?.trim().toLowerCase() ?? '';
              if (email.isEmpty) {
                return 'Please enter your email address.';
              }
              if (!AuthService.isAllowedSignInEmail(email)) {
                return 'Use your EWU student email or the approved access email.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const <String>[AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (String? value) {
              final String password = value ?? '';
              if (password.isEmpty) {
                return 'Please enter your password.';
              }
              if (!_isLoginMode && password.length < 6) {
                return 'Use at least 6 characters.';
              }
              return null;
            },
          ),
          if (preview != null) ...<Widget>[
            const SizedBox(height: 18),
            _StudentPreviewCard(profile: preview),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBusy ? null : _submit,
              child: Text(_isLoginMode ? 'Login' : 'Create Account'),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'or continue with',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _handleGoogleSignIn,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Google Sign-In'),
            ),
          ),
          if (_isBusy) ...<Widget>[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const AppLogoMark(size: 88),
        const SizedBox(height: 24),
        Text(
          'Verify Your Email',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          'We sent a verification link to your email. Open it, then come back here.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isCheckingVerification ? null : _checkVerification,
            child: Text(
              _isCheckingVerification ? 'Checking...' : 'I Have Verified',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isCheckingVerification
                ? null
                : () async {
                    try {
                      await AuthService.resendVerificationEmail();
                      _showMessage('Verification email sent again.');
                    } catch (error) {
                      _showMessage(
                        error.toString().replaceFirst('Exception: ', ''),
                      );
                    }
                  },
            child: const Text('Resend Email'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () async {
            _verificationTimer?.cancel();
            _isCheckingVerification = false;
            await AuthService.signOut();
            if (!mounted) {
              return;
            }
            setState(() {
              _showVerificationState = false;
            });
          },
          child: const Text('Use another account'),
        ),
      ],
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onMessage,
  });

  final String initialEmail;
  final ValueChanged<String> onMessage;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _resetController = TextEditingController(
    text: widget.initialEmail,
  );
  bool _isSending = false;

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await AuthService.sendPasswordReset(_resetController.text);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      widget.onMessage('Password reset email sent.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      widget.onMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(
        controller: _resetController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const <String>[AutofillHints.email],
        decoration: const InputDecoration(hintText: 'Email address'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendResetEmail,
          child: Text(_isSending ? 'Sending...' : 'Send'),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryDark : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: selected ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentPreviewCard extends StatelessWidget {
  const _StudentPreviewCard({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.botBubble,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.badge_outlined, color: AppTheme.primaryDark),
              const SizedBox(width: 8),
              Text(
                'Student Preview',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Student ID: ${profile.studentId}'),
          const SizedBox(height: 6),
          Text('Department: ${profile.department}'),
          const SizedBox(height: 6),
          Text('Batch: ${profile.batchYear}'),
        ],
      ),
    );
  }
}
