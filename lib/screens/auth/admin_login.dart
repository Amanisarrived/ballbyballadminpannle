import 'package:cricket_admin/provider/admin_auth_provider.dart';
import '../dashboard/dash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;

  // Shake animation for error
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _emailFocus.addListener(() {
      setState(() => _emailHasFocus = _emailFocus.hasFocus);
    });
    _passwordFocus.addListener(() {
      setState(() => _passwordHasFocus = _passwordFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authProvider = context.read<AdminAuthProvider>();
    if (authProvider.isLoading) return;
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _shakeController.forward(from: 0);
      return;
    }

    FocusScope.of(context).unfocus();

    await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    final provider = context.read<AdminAuthProvider>();

    if (provider.isAdmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashScreen()),
      );
    } else if (provider.errorMessage != null) {
      // Shake on error
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AdminAuthProvider>();
    final hasError = authProvider.errorMessage != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Background subtle grid pattern
          CustomPaint(
            painter: _GridPainter(),
            size: Size.infinite,
          ),

          // Glow accent top left
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.redAccent.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final offset = _shakeController.isAnimating
                      ? 8 *
                          (0.5 -
                              (_shakeAnimation.value % 0.2 < 0.1
                                  ? _shakeAnimation.value % 0.1 / 0.1
                                  : 1 - (_shakeAnimation.value % 0.1) / 0.1))
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Logo area ──
                      _buildLogoSection(),
                      const SizedBox(height: 40),

                      // ── Card ──
                      Container(
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasError
                                ? Colors.redAccent.withOpacity(0.3)
                                : Colors.white.withOpacity(0.06),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                            if (hasError)
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.08),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Heading
                            const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Admin access only',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── Email field ──
                            _buildLabel('Email address'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailController,
                              focusNode: _emailFocus,
                              hasFocus: _emailHasFocus,
                              hasError: hasError,
                              hint: 'admin@example.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context)
                                  .requestFocus(_passwordFocus),
                            ),
                            const SizedBox(height: 20),

                            // ── Password field ──
                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              hasFocus: _passwordHasFocus,
                              hasError: hasError,
                              hint: '••••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              suffix: GestureDetector(
                                onTap: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    key: ValueKey(_obscurePassword),
                                    color: const Color(0xFF555555),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),

                            // ── Error message ──
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              child: hasError
                                  ? _buildErrorBanner(
                                      authProvider.errorMessage!)
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 28),

                            // ── Login button ──
                            _buildLoginButton(authProvider),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.sports_cricket_rounded,
            color: Colors.redAccent,
            size: 30,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cricket Admin',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF888888),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required bool hasError,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscureText = false,
    Widget? suffix,
    Function(String)? onSubmitted,
  }) {
    Color borderColor;
    if (hasError) {
      borderColor = Colors.redAccent.withOpacity(0.6);
    } else if (hasFocus) {
      borderColor = Colors.redAccent.withOpacity(0.7);
    } else {
      borderColor = Colors.white.withOpacity(0.08);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        color: hasFocus ? const Color(0xFF1C1C1C) : const Color(0xFF181818),
        boxShadow: hasFocus
            ? [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF3D3D3D), fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xFF555555), size: 18),
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    // Parse Firebase error codes into human-friendly messages
    String friendlyMessage = message;
    if (message.contains('user-not-found') ||
        message.contains('wrong-password') ||
        message.contains('invalid-credential')) {
      friendlyMessage = 'Incorrect email or password. Please try again.';
    } else if (message.contains('too-many-requests')) {
      friendlyMessage = 'Too many attempts. Please wait a moment.';
    } else if (message.contains('network-request-failed')) {
      friendlyMessage = 'No internet connection. Check your network.';
    } else if (message.contains('not authorized')) {
      friendlyMessage = 'This account does not have admin access.';
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: Colors.redAccent,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              friendlyMessage,
              style: const TextStyle(
                color: Color(0xFFFF8A80),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(AdminAuthProvider authProvider) {
    return SizedBox(
      height: 50,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: authProvider.isLoading
            ? Container(
                key: const ValueKey('loading'),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.redAccent,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            : ElevatedButton(
                key: const ValueKey('button'),
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ).copyWith(
                  overlayColor: WidgetStateProperty.all(
                    Colors.white.withOpacity(0.08),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
      ),
    );
  }
}

// Subtle background grid
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}
