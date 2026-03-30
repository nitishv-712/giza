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
              SnackBar(content: Text(authProvider.errorMessage!)),
            );
            authProvider.clearError();
          });
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF080810), Color(0xFF18182A)],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Giza 🎵',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFECECFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Underground music streaming',
                        style: TextStyle(fontSize: 16, color: Color(0xFF9999AA)),
                      ),
                      const SizedBox(height: 80),
                      
                      // Google Sign In
                      ElevatedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => authProvider.signInWithGoogle(),
                        icon: authProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black87,
                                ),
                              )
                            : const Icon(Icons.g_mobiledata, size: 32),
                        label: const Text('Continue with Google'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Facebook Sign In
                      ElevatedButton.icon(
                        onPressed: authProvider.isLoading
                            ? null
                            : () => authProvider.signInWithFacebook(),
                        icon: authProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.facebook, size: 28),
                        label: const Text('Continue with Facebook'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1877F2),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
