import 'package:flutter/material.dart';
import 'services/auth_service.dart';
import 'profile/profile_entry.dart';
import 'l10n/app_language.dart';

void main() {
  runApp(const MedCompanionApp());
}

const Color backgroundColor = Color(0xFF050608);
const Color fieldColor = Color(0xFF031725);
const Color neonBlue = Color(0xFF00BFFF);
const Color neonCyan = Color(0xFF32DFFF);
const Color mutedText = Color(0xFF9DB8CB);

class MedCompanionApp extends StatelessWidget {
  const MedCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, language, child) {
        final isEnglish = language == 'en';

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Med Companion',
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: backgroundColor,
            useMaterial3: true,
          ),
          builder: (context, child) {
            return Directionality(
              textDirection:
                  isEnglish ? TextDirection.ltr : TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const LoginScreen(),
        );
      },
    );
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _rememberMe = true;

@override
void initState() {
  super.initState();
  appLanguage.addListener(_onLanguageChanged);
}

void _onLanguageChanged() {
  if (mounted) {
    setState(() {});
  }
}

  @override
void dispose() {
  appLanguage.removeListener(_onLanguageChanged);
  _emailController.dispose();
  _passwordController.dispose();
  super.dispose();
}

Future<void> _login() async {
  FocusScope.of(context).unfocus();

  if (!_formKey.currentState!.validate()) return;

  try {
    await AuthService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProfileEntry(
          loginBuilder: () => const LoginScreen(),
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }
}

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: mutedText,
        fontSize: 15,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF83DFFF),
        size: 25,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fieldColor.withValues(alpha: 0.78),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(36),
        borderSide: const BorderSide(
          color: neonBlue,
          width: 1.1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(36),
        borderSide: const BorderSide(
          color: neonCyan,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020914),
              backgroundColor,
              Color(0xFF010306),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
  // Language switch
  Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton.icon(
      onPressed: () {
        changeAppLanguage(isEnglish ? 'ar' : 'en');
      },
      icon: const Icon(
        Icons.language,
        color: neonCyan,
      ),
      label: Text(
        isEnglish ? 'العربية' : 'English',
        style: const TextStyle(
          color: neonCyan,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ),

  // Glowing heart logo with soft fading edges

Container(
  height: 220,
  width: double.infinity,
  decoration: BoxDecoration(
    gradient: RadialGradient(
      colors: [
        neonBlue.withValues(alpha: 0.20),
        Colors.transparent,
      ],
      radius: 0.75,
    ),
  ),
  child: Center(
    child: ShaderMask(
      shaderCallback: (Rect bounds) {
        return const RadialGradient(
          center: Alignment.center,
          radius: 0.75,
          colors: [
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.55, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Image.asset(
        'assets/heart.png',
        height: 210,
        fit: BoxFit.contain,
      ),
    ),
  ),
),

                      const SizedBox(height: 8),

                      const Text(
                        'Med Companion',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 35,
                          fontWeight: FontWeight.w600,
                          color: neonCyan,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              color: neonBlue,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'Your health, our priority',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFFB9D4E4),
                        ),
                      ),

                      const SizedBox(height: 42),

                      // University email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        cursorColor: neonCyan,
                        decoration: _inputDecoration(
hint: tr('البريد الإلكتروني الجامعي', 'University email'),                          icon: Icons.person_outline,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
return tr('يرجى إدخال البريد الإلكتروني', 'Please enter your email');                          }

                          if (!RegExp(
                            r'^[^@]+@[^@]+\.[^@]+$',
                          ).hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        cursorColor: neonCyan,
                        decoration: _inputDecoration(
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            tooltip: 'Show or hide password',
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: mutedText,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      // Remember me and Forgot password
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: neonBlue,
                            checkColor: Colors.white,
                            side: const BorderSide(color: neonCyan),
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Remember me',
                              style: TextStyle(
                                color: Color(0xFFB9D4E4),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Password recovery will be added later.',
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: neonCyan,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Login button
                      SizedBox(
                        height: 58,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF079ACB),
                                Color(0xFF08A9C7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: neonBlue.withValues(alpha: 0.20),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: const Text(
                              'Log in',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Divider
                      const Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Color(0xFF07536B),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              'or',
                              style: TextStyle(color: neonCyan),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Color(0xFF07536B),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      // Google button
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Google sign-in will be connected later.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.g_mobiledata,
                          size: 36,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          side: const BorderSide(color: neonBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Navigate to Create Account
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'Don’t have an account? ',
                            style: TextStyle(
                              color: Color(0xFFB9D4E4),
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CreateAccountScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign up',
                              style: TextStyle(
                                color: neonCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
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
}




class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator ?? _requiredValidator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: neonCyan,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: mutedText, fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF83DFFF), size: 25),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fieldColor.withValues(alpha: 0.78),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(36),
          borderSide: const BorderSide(color: neonBlue, width: 1.1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(36),
          borderSide: const BorderSide(color: neonCyan, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
  FocusScope.of(context).unfocus();

  if (!_formKey.currentState!.validate()) return;

  if (_passwordController.text != _confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Passwords do not match')),
    );
    return;
  }

  if (_passwordController.text.length < 15 ||
      _passwordController.text.length > 128) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password must be between 15 and 128 characters'),
      ),
    );
    return;
  }

  if (!_acceptedTerms) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please accept the Terms of Service'),
      ),
    );
    return;
  }

  try {
    final result = await AuthService.signup(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Account created successfully for ${result['email']}',
        ),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020914),
              backgroundColor,
              Color(0xFF010306),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShaderMask(
  shaderCallback: (rect) {
    return const RadialGradient(
      center: Alignment.center,
      radius: 0.75,
      colors: [Colors.white, Colors.transparent],
      stops: [0.55, 1.0],
    ).createShader(rect);
  },
  blendMode: BlendMode.dstIn,
  child: Image.asset(
    'assets/heart.png',
    height: 230,
    fit: BoxFit.contain,
  ),
),
                      const SizedBox(height: 12),
                      const Text(
                        'Create account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 37,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          foreground: null,
                          color: neonCyan,
                          shadows: [
                            Shadow(color: neonBlue, blurRadius: 20),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Join us and be part of something great!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                      const SizedBox(height: 30),

                      _buildField(
                        controller: _nameController,
                        hint: 'Full name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _emailController,
                        hint: 'University email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                              .hasMatch(value.trim())) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _passwordController,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        obscureText: _hidePassword,
                        suffixIcon: IconButton(
                          tooltip: 'Show or hide password',
                          onPressed: () {
                            setState(() => _hidePassword = !_hidePassword);
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _confirmPasswordController,
                        hint: 'Confirm password',
                        icon: Icons.lock_outline,
                        obscureText: _hideConfirmPassword,
                        suffixIcon: IconButton(
                          tooltip: 'Show or hide password',
                          onPressed: () {
                            setState(() {
                              _hideConfirmPassword = !_hideConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _hideConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: mutedText,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            activeColor: neonBlue,
                            checkColor: Colors.white,
                            side: const BorderSide(color: neonCyan),
                            onChanged: (value) {
                              setState(() {
                                _acceptedTerms = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Wrap(
                              children: [
                                Text(
                                  'I agree to the ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Terms of Service',
                                  style: TextStyle(
                                    color: neonCyan,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  ' and ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Privacy Policy',
                                  style: TextStyle(
                                    color: neonCyan,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      SizedBox(
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF079ACB),
                                Color(0xFF08A9C7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: neonBlue.withValues(alpha: 0.18),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: const Text(
                              'Sign up',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFF07536B))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 18),
                            child: Text(
                              'or',
                              style: TextStyle(color: neonCyan),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFF07536B))),
                        ],
                      ),
                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Google sign-in will be connected later.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.g_mobiledata,
                          size: 34,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          side: const BorderSide(color: neonBlue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(
                              color: Color(0xFFB9D4E4),
                              fontSize: 13,
                            ),
                          ),
                         GestureDetector(
  onTap: () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  },
  child: const Text(
    'Log in here',
    style: TextStyle(
      color: neonCyan,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  ),
),
                        ],
                      ),
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
}
