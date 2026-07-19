import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({required this.isLogin, super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  File? _idFile;
  File? _selfieFile;
  String? _error;

  Future<void> _pickImage(bool isId) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => isId ? _idFile = File(picked.path) : _selfieFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      if (widget.isLogin) {
        await ApiService.login(_email.text.trim(), _password.text);
        if (mounted) context.go('/home');
      } else {
        if (_idFile == null || _selfieFile == null) {
          setState(() { _error = 'Please upload your ID and selfie'; _loading = false; });
          return;
        }
        await ApiService.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          idDocument: _idFile!,
          selfie: _selfieFile!,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Account created! Our team will verify your ID within 24 hours.'),
            backgroundColor: Color(0xFF16A34A),
          ));
          context.go('/login');
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.isLogin;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Text('🚲', style: TextStyle(fontSize: 48), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(
                  isLogin ? 'Welcome back' : 'Create account',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isLogin ? 'Log in to continue riding' : 'Start renting and earning today',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                if (!isLogin) ...[
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v?.contains('@') ?? false) ? null : 'Enter a valid email',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) => (v?.length ?? 0) >= 8 ? null : 'Min. 8 characters',
                ),

                if (!isLogin) ...[
                  const SizedBox(height: 20),
                  _UploadTile(
                    label: 'Government-issued ID',
                    hint: 'Passport, driver\'s licence, national ID',
                    file: _idFile,
                    onTap: () => _pickImage(true),
                  ),
                  const SizedBox(height: 12),
                  _UploadTile(
                    label: 'Selfie photo',
                    hint: 'Clear photo of your face',
                    file: _selfieFile,
                    onTap: () => _pickImage(false),
                  ),
                ],

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13)),
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isLogin ? 'Log in' : 'Create account'),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go(isLogin ? '/register' : '/login'),
                  child: Text(isLogin ? "Don't have an account? Sign up" : 'Already have an account? Log in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  final String label;
  final String hint;
  final File? file;
  final VoidCallback onTap;
  const _UploadTile({required this.label, required this.hint, required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: file != null ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB), width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: file != null ? const Color(0xFFDCFCE7) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              file != null ? Icons.check_circle : Icons.upload_file,
              color: file != null ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                    file != null ? file!.path.split('/').last : hint,
                    style: TextStyle(fontSize: 12, color: file != null ? const Color(0xFF166534) : const Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
