import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/providers.dart';
import '../../../shared/widgets/industrial_button.dart';
import '../../../shared/motion/staggered_entrance.dart';
import '../../../shared/motion/pulsing_beacon.dart';
import '../../../shared/backgrounds/ambient_depth_canvas.dart';
import '../../../shared/backgrounds/naadyantra_animated_background.dart';
import '../../../shared/widgets/sahai_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    await ref.read(authStateProvider.notifier).login(username, password);

    if (mounted && ref.read(authStateProvider).isAuthenticated) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NaadyantraAnimatedBackground(
        kind: NaadyantraBackgroundKind.login,
        lightScrimOpacity: 0.58,
        darkScrimOpacity: 0.52,
        child: SafeArea(
          child: Stack(
            children: [
              // Top-right quick theme mode switch
              Positioned(
                top: 12,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xDD181716)
                        : AppColors.pureWhite.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF383531)
                          : AppColors.warmStone,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          size: 18,
                          color: AppColors.burntOrange,
                        ),
                        tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
                        onPressed: () {
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(
                                isDark ? ThemeMode.light : ThemeMode.dark,
                              );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Terminal Header Badge
                        StaggeredEntrance(
                          index: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xDD181716)
                                    : AppColors.pureWhite.withValues(
                                        alpha: 0.9,
                                      ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.burntOrange.withValues(
                                    alpha: isDark ? 0.35 : 0.5,
                                  ),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.burntOrange.withValues(
                                      alpha: 0.12,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const PulsingBeacon(
                                    size: 8,
                                    color: AppColors.burntOrange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'DIAGNOSTIC WORKSTATION // V1.0',
                                    style: AppTypography.mono(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.carbon,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Brand Emblem & Heading
                        StaggeredEntrance(
                          index: 1,
                          child: Column(
                            children: [
                              const SahaiLogo(size: 82),
                              const SizedBox(height: 16),
                              Text(
                                'HAZEGUARD',
                                style: AppTypography.spaceGrotesk(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.pureWhite
                                      : AppColors.carbon,
                                  letterSpacing: 3.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'INSTRUMENT STUDIO // VOCATIONAL SENSING PLATFORM',
                                style: AppTypography.mono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.burntOrange,
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Login Container Card with Ambient Reticles
                        StaggeredEntrance(
                          index: 2,
                          child: AmbientDepthCanvas(
                            showReticles: true,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xF21C1E20)
                                    : AppColors.pureWhite.withValues(
                                        alpha: 0.95,
                                      ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3A3D40)
                                      : const Color(0xFFD8D2C7),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.55)
                                        : Colors.black.withValues(alpha: 0.08),
                                    blurRadius: isDark ? 32 : 20,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: AppColors.burntOrange.withValues(
                                      alpha: isDark ? 0.06 : 0.04,
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Operator Credentials',
                                          style: AppTypography.spaceGrotesk(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.darkTextPrimary
                                                : AppColors.carbon,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.darkBurntOrange
                                                .withValues(alpha: 0.25),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: AppColors.burntOrange
                                                  .withValues(alpha: 0.45),
                                              width: 0.9,
                                            ),
                                          ),
                                          child: Text(
                                            'SECURE ENTRY',
                                            style: AppTypography.mono(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                              color: AppColors.burntOrange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),

                                    // Username Field
                                    TextFormField(
                                      controller: _usernameController,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.carbon,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      cursorColor: AppColors.burntOrange,
                                      decoration: InputDecoration(
                                        labelText: 'Operator Username',
                                        labelStyle: TextStyle(
                                          color: isDark
                                              ? AppColors.subtleGray
                                              : AppColors.warmGraphite,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        floatingLabelStyle: const TextStyle(
                                          color: AppColors.burntOrange,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        hintText: 'e.g. operator or trainer',
                                        hintStyle: TextStyle(
                                          color: isDark
                                              ? AppColors.subtleGray
                                                  .withValues(alpha: 0.5)
                                              : AppColors.warmGraphite
                                                  .withValues(alpha: 0.6),
                                          fontSize: 13,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.badge_outlined,
                                          size: 20,
                                          color: isDark
                                              ? AppColors.softSand
                                              : AppColors.warmGraphite,
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF252729)
                                            : const Color(0xFFF7F5F0),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF3A3D40)
                                                : const Color(0xFFD4CEC5),
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.burntOrange,
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.alertDanger,
                                            width: 1,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.alertDanger,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      textInputAction: TextInputAction.next,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter your username';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Password Field
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.carbon,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      cursorColor: AppColors.burntOrange,
                                      decoration: InputDecoration(
                                        labelText: 'Workstation Access Key',
                                        labelStyle: TextStyle(
                                          color: isDark
                                              ? AppColors.subtleGray
                                              : AppColors.warmGraphite,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        floatingLabelStyle: const TextStyle(
                                          color: AppColors.burntOrange,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        hintText: 'Enter password',
                                        hintStyle: TextStyle(
                                          color: isDark
                                              ? AppColors.subtleGray
                                                  .withValues(alpha: 0.5)
                                              : AppColors.warmGraphite
                                                  .withValues(alpha: 0.6),
                                          fontSize: 13,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 20,
                                          color: isDark
                                              ? AppColors.softSand
                                              : AppColors.warmGraphite,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 20,
                                            color: isDark
                                                ? AppColors.softSand
                                                : AppColors.warmGraphite,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color(0xFF252729)
                                            : const Color(0xFFF7F5F0),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? const Color(0xFF3A3D40)
                                                : const Color(0xFFD4CEC5),
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.burntOrange,
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.alertDanger,
                                            width: 1,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.alertDanger,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your password';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),

                                    // Error Display Callout
                                    if (authState.error != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.alertDanger
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: AppColors.alertDanger
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              size: 18,
                                              color: AppColors.alertDanger,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                authState.error!,
                                                style: const TextStyle(
                                                  color: Color(0xFFFF8B7D),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                    ],

                                    // Submit Button
                                    IndustrialButton(
                                      label: 'Authenticate Workstation',
                                      icon: Icons.key_rounded,
                                      isLoading: authState.isLoading,
                                      onPressed: _handleLogin,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Industrial Compliance Badge
                        StaggeredEntrance(
                          index: 3,
                          child: Center(
                            child: Text(
                              'COMPLIANT WITH ISO-9001 / OSHA INDUSTRIAL TELEMETRY DIRECTIVES',
                              style: AppTypography.mono(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.7,
                                color: isDark
                                    ? AppColors.subtleGray.withValues(
                                        alpha: 0.75,
                                      )
                                    : AppColors.carbon.withValues(
                                        alpha: 0.75,
                                      ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
