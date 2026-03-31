// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// Login always shows before a theme is selected, so it keeps its own fixed
// dark palette. The amber/coral pair is core brand identity on this screen.
const _loginBg      = Color(0xFF0C0C14);
const _loginAccent  = Color(0xFFFF8C42);
const _loginAccent2 = Color(0xFFFF5F6D);
const _loginTextPri = Color(0xFFF0EFFF);
const _loginTextSec = Color(0xFF6E6E8A);
const _loginSurface = Color(0xFF1A1A2E);

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
                backgroundColor: _loginSurface,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
            authProvider.clearError();
          });
        }

        return Scaffold(
          backgroundColor: _loginBg,
          body: Stack(
            children: [
              // ── Ambient blobs ──────────────────────────────────────────
              Positioned(
                top: -100, right: -80,
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _loginAccent.withOpacity(0.18),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: 100, left: -60,
                child: Container(
                  width: 250, height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFB06AFF).withOpacity(0.14),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 56),

                      // Logo mark
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_loginAccent, _loginAccent2],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _loginAccent.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: Colors.white, size: 28),
                      ),

                      const SizedBox(height: 40),

                      const Text(
                        'Giza',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: _loginTextPri,
                          letterSpacing: -2.0,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: const TextSpan(children: [
                          TextSpan(
                            text: 'Underground ',
                            style: TextStyle(
                              fontSize: 17,
                              color: _loginTextSec,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: 'music streaming',
                            style: TextStyle(
                              fontSize: 17,
                              color: _loginAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]),
                      ),

                      const Spacer(),

                      const _WaveformBar(),
                      const SizedBox(height: 56),

                      const Text(
                        'Sign in to continue',
                        style: TextStyle(
                          fontSize: 13,
                          color: _loginTextSec,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Google
                      _AuthButton(
                        onPressed: authProvider.isLoading
                            ? null
                            : authProvider.signInWithGoogle,
                        isLoading: authProvider.isLoading,
                        label: 'Continue with Google',
                        icon: Icons.g_mobiledata,
                        iconSize: 30,
                        backgroundColor: _loginTextPri,
                        foregroundColor: _loginBg,
                        glowColor: Colors.transparent,
                      ),

                      // Uncomment to re-enable Facebook:
                      // const SizedBox(height: 12),
                      // _AuthButton(
                      //   onPressed: authProvider.isLoading
                      //       ? null
                      //       : authProvider.signInWithFacebook,
                      //   isLoading: authProvider.isLoading,
                      //   label: 'Continue with Facebook',
                      //   icon: Icons.facebook_rounded,
                      //   iconSize: 24,
                      //   backgroundColor: _loginSurface,
                      //   foregroundColor: _loginTextPri,
                      //   borderColor: const Color(0xFF2A2A3E),
                      //   glowColor: Colors.transparent,
                      // ),

                      const SizedBox(height: 40),

                      Center(
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: _loginTextSec.withOpacity(0.7),
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

// ── Waveform ───────────────────────────────────────────────────────────────

class _WaveformBar extends StatelessWidget {
  static const _h = [
    18.0, 32.0, 48.0, 28.0, 52.0, 38.0, 20.0, 44.0, 30.0, 56.0,
    34.0, 24.0, 46.0, 36.0, 18.0, 50.0, 28.0, 40.0, 22.0, 52.0,
    30.0, 44.0, 26.0, 38.0, 16.0,
  ];

  const _WaveformBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_h.length, (i) {
          final opacity = 0.15 + (i / _h.length) * 0.5;
          return Container(
            width: 3,
            height: _h[i],
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  _loginAccent.withOpacity(opacity),
                  _loginAccent2.withOpacity(opacity * 0.6),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Auth button ────────────────────────────────────────────────────────────

class _AuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final IconData icon;
  final double iconSize;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color glowColor;

  const _AuthButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.iconSize,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.glowColor,
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
          boxShadow: glowColor != Colors.transparent
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: foregroundColor),
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