import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'business_onboarding_screen.dart';

class LoginDialog extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginDialog({super.key, this.onLoginSuccess});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _isRegister = false;
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String _selectedAccountType = 'User';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();

    Map<String, dynamic> result;
    if (_isRegister) {
      result = await ApiService.register(
        username,
        password,
        fullName,
        role: _selectedAccountType,
      );
    } else {
      result = await ApiService.login(username, password);
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Thành công!'),
            backgroundColor: AppTheme.pitchBlack,
          ),
        );
        widget.onLoginSuccess?.call();
        if (_isRegister && _selectedAccountType == 'Business') {
          final navigator = Navigator.of(context, rootNavigator: true);
          navigator.pop(true);
          navigator.push(
            MaterialPageRoute(builder: (_) => const BusinessOnboardingScreen()),
          );
        } else {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Đã xảy ra lỗi!';
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: isDark ? AppTheme.pitchBlack : AppTheme.lightCardBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: isDark ? AppTheme.darkCardBg : AppTheme.pureWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.fireCoral.withValues(alpha: isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: AppTheme.fireCoral),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRegister ? 'Tạo tài khoản' : 'Chào mừng trở lại',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRegister ? 'Khám phá và chia sẻ những quán ăn hay.' : 'Đăng nhập để tiếp tục hành trình ẩm thực.',
                            style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.pitchBlack : AppTheme.lightCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppTheme.darkGrayBorder : AppTheme.grayBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (_isRegister) {
                              setState(() {
                                _isRegister = false;
                                _errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isRegister
                                  ? AppTheme.fireCoral
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Đăng Nhập',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: !_isRegister
                                    ? AppTheme.pureWhite
                                    : (isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!_isRegister) {
                              setState(() {
                                _isRegister = true;
                                _errorMessage = null;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isRegister
                                  ? AppTheme.fireCoral
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Đăng Ký',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _isRegister
                                    ? AppTheme.pureWhite
                                    : (isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Error alert box
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.fireCoral.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.fireCoral),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.fireCoral, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.fireCoral,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_isRegister) ...[
                  TextFormField(
                    controller: _fullNameController,
                    decoration: _inputDecoration(label: 'Tên hiển thị', icon: Icons.person_outline_rounded, isDark: isDark),
                    validator: (v) {
                      if (_isRegister && (v == null || v.trim().isEmpty)) {
                        return 'Vui lòng nhập họ tên của bạn';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Text('Bạn đăng ký với vai trò nào?', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ChoiceChip(
                      selected: _selectedAccountType == 'User',
                      showCheckmark: false,
                      avatar: Icon(Icons.person_outline_rounded, size: 18, color: _selectedAccountType == 'User' ? Colors.white : AppTheme.fireCoral),
                      label: const Text('Cá nhân'),
                      selectedColor: AppTheme.fireCoral,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _selectedAccountType == 'User' ? Colors.white : (isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)),
                      onSelected: (_) => setState(() => _selectedAccountType = 'User'),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ChoiceChip(
                      selected: _selectedAccountType == 'Business',
                      showCheckmark: false,
                      avatar: Icon(Icons.storefront_outlined, size: 18, color: _selectedAccountType == 'Business' ? Colors.white : AppTheme.fireCoral),
                      label: const Text('Doanh nghiệp'),
                      selectedColor: AppTheme.fireCoral,
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: _selectedAccountType == 'Business' ? Colors.white : (isDark ? AppTheme.pureWhite : AppTheme.pitchBlack)),
                      onSelected: (_) => setState(() => _selectedAccountType = 'Business'),
                    )),
                  ]),
                  const SizedBox(height: 14),
                  if (_selectedAccountType == 'Business')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Bạn sẽ nhập thông tin quán ở bước tiếp theo.',
                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textMutedDark : AppTheme.textMutedLight),
                      ),
                    ),
                  const SizedBox(height: 14),
                ],

                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration(label: 'Tên đăng nhập', icon: Icons.account_circle_outlined, isDark: isDark),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập tên đăng nhập';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(label: 'Mật khẩu', icon: Icons.lock_outline_rounded, isDark: isDark).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (_isRegister && v.length < 6) {
                      return 'Mật khẩu phải từ 6 ký tự trở lên';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.fireCoral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.pureWhite,
                          ),
                        )
                      : Text(
                          _isRegister ? 'TẠO TÀI KHOẢN' : 'ĐĂNG NHẬP',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
