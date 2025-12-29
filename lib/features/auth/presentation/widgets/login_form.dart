// lib/features/auth/presentation/widgets/login_form.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/shared_widgets/custom_button.dart';
import '../../../../core/shared_widgets/custom_text_field.dart';

class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final FocusNode phoneFocusNode;
  final FocusNode passwordFocusNode;
  final bool isPasswordVisible;
  final bool rememberMe;
  final Map<String, String>? fieldErrors;
  final VoidCallback onTogglePasswordVisibility;
  final ValueChanged<bool> onToggleRememberMe;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.phoneController,
    required this.passwordController,
    required this.phoneFocusNode,
    required this.passwordFocusNode,
    required this.isPasswordVisible,
    required this.rememberMe,
    this.fieldErrors,
    required this.onTogglePasswordVisibility,
    required this.onToggleRememberMe,
    required this.onLogin,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phone Field
          _buildPhoneField(),
          const SizedBox(height: 20),

          // Password Field
          _buildPasswordField(),
          const SizedBox(height: 16),

          // Remember Me & Forgot Password Row
          _buildOptionsRow(),
          const SizedBox(height: 32),

          // Login Button
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return CustomTextField(
      controller: phoneController,
      focusNode: phoneFocusNode,
      label: 'Phone Number',
      hint: 'Enter your phone number',
      prefixIcon: Icons.phone_android,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      errorText: fieldErrors?['phone'],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
        _PhoneNumberFormatter(),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Phone number is required';
        }
        final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
        if (cleanPhone.length < 9) {
          return 'Enter a valid phone number';
        }
        return null;
      },
      onSubmitted: (_) {
        FocusScope.of(phoneFocusNode.context!).requestFocus(passwordFocusNode);
      },
    );
  }

  Widget _buildPasswordField() {
    return CustomTextField(
      controller: passwordController,
      focusNode: passwordFocusNode,
      label: 'Password',
      hint: 'Enter your password',
      prefixIcon: Icons.lock_outline,
      obscureText: !isPasswordVisible,
      textInputAction: TextInputAction.done,
      errorText: fieldErrors?['password'],
      suffix: IconButton(
        icon: Icon(
          isPasswordVisible ? Icons.visibility_off : Icons.visibility,
          color: AppColors.textSecondary,
        ),
        onPressed: onTogglePasswordVisibility,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password is required';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      onSubmitted: (_) => onLogin(),
    );
  }

  Widget _buildOptionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Remember Me Checkbox
        InkWell(
          onTap: () => onToggleRememberMe(!rememberMe),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: rememberMe,
                    onChanged: (value) => onToggleRememberMe(value ?? false),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Remember me',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Forgot Password
        TextButton(
          onPressed: onForgotPassword,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: Text(
            'Forgot Password?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return CustomButton(
      label: 'Sign In',
      onPressed: onLogin,
      icon: Icons.login,
      height: 56,
    );
  }
}

/// Phone number formatter for display (e.g., 071 234 5678)
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 3 || i == 6) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
