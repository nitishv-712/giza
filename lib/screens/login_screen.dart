import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(authProvider.errorMessage!),
                backgroundColor: const Color(0xFF1E1E2E),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            authProvider.clearError();
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0C0C14),
          body: Stack(
            children: [
              // ── Background ambient blobs ────────────────────────────────
              Positioned(
                top: -100,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF8C42).withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 100,
                left: -60,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFB06AFF).withOpacity(0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Main content ───────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 56),

                      // Logo mark
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF8C42), Color(0xFFFF5F6D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF8C42).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: Colors.white, size: 28),
                      ),

                      const SizedBox(height: 40),

                      // Headline
                      const Text(
                        'Giza',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF0EFFF),
                          letterSpacing: -2.0,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Underground ',
                              style: TextStyle(
                                fontSize: 17,
                                color: Color(0xFF6E6E8A),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: 'music streaming',
                              style: TextStyle(
                                fontSize: 17,
                                color: Color(0xFFFF8C42),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // ── Waveform decoration ──────────────────────────
                      _WaveformBar(),
                      const SizedBox(height: 56),

                      // ── Sign in options ──────────────────────────────
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6E6E8A),
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Google button
                      _AuthButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => authProvider.signInWithGoogle(),
                        isLoading: authProvider.isLoading,
                        label: 'Continue with Google',
                        icon: Icons.g_mobiledata,
                        iconSize: 30,
                        backgroundColor: const Color(0xFFF0EFFF),
                        foregroundColor: const Color(0xFF0C0C14),
                        glowColor: Colors.transparent,
                      ),

                      // const SizedBox(height: 12),

                      // Facebook button
                      // _AuthButton(
                      //   onPressed: authProvider.isLoading
                      //       ? null
                      //       : () => authProvider.signInWithFacebook(),
                      //   isLoading: authProvider.isLoading,
                      //   label: 'Continue with Facebook',
                      //   icon: Icons.facebook_rounded,
                      //   iconSize: 24,
                      //   backgroundColor: const Color(0xFF1A1A2E),
                      //   foregroundColor: const Color(0xFFF0EFFF),
                      //   borderColor: const Color(0xFF2A2A3E),
                      //   glowColor: Colors.transparent,
                      // ),

                      const SizedBox(height: 40),

                      // Terms note
                      Center(
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF6E6E8A).withOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Waveform decoration widget ─────────────────────────────────────────────

class _WaveformBar extends StatelessWidget {
  final List<double> _heights = const [
    18, 32, 48, 28, 52, 38, 20, 44, 30, 56,
    34, 24, 46, 36, 18, 50, 28, 40, 22, 52,
    30, 44, 26, 38, 16,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_heights.length, (i) {
          final opacity = 0.15 + (i / _heights.length) * 0.5;
          return Container(
            width: 3,
            height: _heights[i],
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFFFF8C42).withOpacity(opacity),
                  const Color(0xFFFF5F6D).withOpacity(opacity * 0.6),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Reusable auth button ───────────────────────────────────────────────────

class _AuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final IconData icon;
  final double iconSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color glowColor;
  final Color? borderColor;

  const _AuthButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.iconSize,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.glowColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
          boxShadow: glowColor != Colors.transparent
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            else
              Icon(icon, size: iconSize, color: foregroundColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}