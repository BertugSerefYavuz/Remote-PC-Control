/*
 * Remote PC Control - Mobile Client
 * * Copyright (c) 2026 Bertug Seref Yavuz
 * * This application serves as the client-side interface for the Remote PC Control system.
 * It utilizes Firebase Realtime Database for command transmission and heartbeat monitoring.
 * Features include biometric authentication, real-time status updates, and a cyberpunk UI theme.
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

/// Defines the color palette used throughout the application to maintain the "Cyberpunk" aesthetic.
class CyberColors {
  static const Color background = Color(0xFF0D0D15);
  static const Color surface = Color(0xFF1A1A24);
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color warm = Color(0xFFFFB74D);
  static const Color danger = Color(0xFFFF3860);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFA0A0B0);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RemotePcControlApp());
}

class RemotePcControlApp extends StatelessWidget {
  const RemotePcControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PC Control V2',
      debugShowCheckedModeBanner: false,
      theme: _buildThemeData(),
      home: const AuthWrapper(),
    );
  }

  ThemeData _buildThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CyberColors.background,
      primaryColor: CyberColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: CyberColors.primary,
        secondary: CyberColors.secondary,
        surface: CyberColors.surface,
        background: CyberColors.background,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: CyberColors.textPrimary),
        iconTheme: IconThemeData(color: CyberColors.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CyberColors.surface,
        contentTextStyle: const TextStyle(color: CyberColors.textPrimary),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: CyberColors.primary.withOpacity(0.5))
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ==========================================
// CUSTOM UI WIDGETS
// ==========================================

/// A widget that visualizes the connection status based on the last heartbeat timestamp.
/// Automatically updates every 5 seconds to reflect offline status if heartbeat is lost.
class StatusIndicator extends StatefulWidget {
  final int? lastHeartbeat;
  const StatusIndicator({super.key, required this.lastHeartbeat});

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator> {
  Timer? _timer;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lastHeartbeat != widget.lastHeartbeat) {
      _checkStatus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkStatus() {
    if (widget.lastHeartbeat == null) {
      if (mounted && _isOnline) setState(() => _isOnline = false);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = now - widget.lastHeartbeat!;

    // Threshold for offline status is 35 seconds
    final bool newStatus = diff < 35;

    if (_isOnline != newStatus && mounted) {
      setState(() => _isOnline = newStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _isOnline ? CyberColors.secondary : CyberColors.danger;
    return Container(
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)
          ]
      ),
      child: Icon(Icons.circle, color: color, size: 14),
    );
  }
}

/// A custom text field with a neon glow effect and specific styling.
class NeonTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const NeonTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: CyberColors.primary.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ]
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: CyberColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: CyberColors.textSecondary),
          prefixIcon: Icon(icon, color: CyberColors.primary),
          filled: true,
          fillColor: CyberColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: CyberColors.primary.withOpacity(0.3), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: CyberColors.secondary, width: 2),
          ),
        ),
      ),
    );
  }
}

/// A primary button component with gradient background and shadow effects.
class CyberButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const CyberButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [CyberColors.primary, CyberColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: CyberColors.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 5)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
        ),
      ),
    );
  }
}

/// A generic card container with customizable accent color and tap handling.
class CyberCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const CyberCard({
    super.key,
    required this.child,
    this.accentColor,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = accentColor ?? CyberColors.primary;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: CyberColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
          if (accentColor != null) BoxShadow(color: accentColor!.withOpacity(0.15), blurRadius: 20, spreadRadius: 1)
        ],
        border: Border.all(color: glowColor.withOpacity(0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          splashColor: glowColor.withOpacity(0.2),
          highlightColor: glowColor.withOpacity(0.1),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// CORE LOGIC & SCREENS
// ==========================================

/// Handles the authentication state flow.
/// Checks for existing sessions and "Remember Me" preferences.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isChecking = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final bool rememberMe = prefs.getBool('remember_me') ?? false;
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (rememberMe) {
        if (mounted) setState(() { _isAuthenticated = true; _isChecking = false; });
      } else {
        if (mounted) setState(() { _isAuthenticated = false; _isChecking = false; });
      }
    } else {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: CyberColors.secondary)));
    }

    if (FirebaseAuth.instance.currentUser != null && _isAuthenticated) {
      return ControlPanel(user: FirebaseAuth.instance.currentUser!);
    }

    return const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _emailController.text = prefs.getString('saved_email') ?? "";
      }
    });
  }

  Future<void> _loginWithBiometrics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Biometric verification required',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );

        if (didAuthenticate && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => ControlPanel(user: user)),
          );
        }
      } catch (e) {
        _showError('Biometric Error: $e');
      }
    } else {
      _showError('Please sign in with password first.');
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_successful_login', true);
      await prefs.setBool('remember_me', _rememberMe);

      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
      } else {
        await prefs.remove('saved_email');
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => ControlPanel(user: FirebaseAuth.instance.currentUser!)),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Authentication failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: CyberColors.surface)
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canShowBiometric = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 20),
              NeonTextField(
                controller: _emailController,
                label: "Email",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              NeonTextField(
                controller: _passwordController,
                label: "Password",
                icon: Icons.lock_outlined,
                obscureText: true,
              ),
              const SizedBox(height: 15),
              _buildRememberMeCheckbox(),
              const SizedBox(height: 30),
              CyberButton(
                text: "LOGIN",
                onPressed: _isLoading ? null : _login,
                isLoading: _isLoading,
              ),
              if (canShowBiometric) ...[
                const SizedBox(height: 50),
                GestureDetector(
                  onTap: _loginWithBiometrics,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: CyberColors.secondary.withOpacity(0.5), width: 2),
                            boxShadow: [BoxShadow(color: CyberColors.secondary.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)]
                        ),
                        child: const Icon(Icons.fingerprint, size: 40, color: CyberColors.secondary),
                      ),
                      const SizedBox(height: 10),
                      Text("Biometric Login", style: TextStyle(color: CyberColors.secondary.withOpacity(0.8))),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 120, width: 120,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CyberColors.primary.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(color: CyberColors.primary.withOpacity(0.3), blurRadius: 50, spreadRadius: 10),
                    BoxShadow(color: CyberColors.secondary.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                  ]
              ),
            ),
            const Icon(Icons.android_rounded, size: 80, color: CyberColors.secondary),
          ],
        ),
        const SizedBox(height: 20),
        Text("PC CONTROL V2", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: CyberColors.textPrimary, letterSpacing: 1.5, shadows: [Shadow(color: CyberColors.primary.withOpacity(0.5), blurRadius: 10)])),
        const SizedBox(height: 10),
        const Text("System Access Interface", style: TextStyle(color: CyberColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          activeColor: CyberColors.secondary,
          checkColor: CyberColors.background,
          side: const BorderSide(color: CyberColors.textSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          onChanged: (val) => setState(() => _rememberMe = val!),
        ),
        const Text("Remember Me", style: TextStyle(color: CyberColors.textSecondary)),
      ],
    );
  }
}

/// The main interface for sending commands and viewing system status.
class ControlPanel extends StatefulWidget {
  final User user;
  const ControlPanel({super.key, required this.user});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Pushes a command to the Firebase Realtime Database with a timestamp.
  void sendCommand(String command, dynamic value) {
    _dbRef.child('users/${widget.user.uid}/command/$command').set({
      "val": value,
      "ts": ServerValue.timestamp,
    });
  }

  @override
  Widget build(BuildContext context) {
    String myUid = widget.user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("CONTROL PANEL"),
        leading: IconButton(
          icon: const Icon(Icons.power_settings_new_rounded),
          color: CyberColors.danger,
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if(mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                      (route) => false
              );
            }
          },
          tooltip: "Logout",
        ),
        actions: [
          StreamBuilder(
            stream: _dbRef.child('users/$myUid/status/heartbeat').onValue,
            builder: (context, snapshot) {
              int? timestamp;
              if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                final val = snapshot.data!.snapshot.value;
                if (val is int) timestamp = val;
                else if (val is double) timestamp = val.toInt();
              }
              return StatusIndicator(lastHeartbeat: timestamp);
            },
          )
        ],
      ),
      body: StreamBuilder(
        stream: _dbRef.child('users/$myUid/status').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: CyberColors.secondary));
          }

          Map<dynamic, dynamic>? statusData;
          try {
            statusData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
          } catch (e) { statusData = null; }

          String pcName = statusData?['pc_name'] ?? "Connecting...";
          String activeWindow = statusData?['active_window'] ?? "Unknown";

          List<dynamic> appList = [];
          if (statusData != null && statusData['app_list'] != null) {
            if (statusData['app_list'] is List) appList = statusData['app_list'];
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildPcInfoCard(pcName, activeWindow),
                _buildControlGrid(),
                if (statusData?['last_screenshot'] != null)
                  _buildScreenshotCard(statusData!['last_screenshot']['url']),
                _buildAppListHeader(),
                _buildAppList(appList),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPcInfoCard(String name, String window) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
            colors: [CyberColors.primary.withOpacity(0.2), CyberColors.secondary.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
        ),
        border: Border.all(color: CyberColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.desktop_windows_rounded, size: 50, color: Colors.white),
          const SizedBox(height: 15),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: CyberColors.textPrimary, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(color: CyberColors.background.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: CyberColors.secondary.withOpacity(0.3))),
            child: Text(window, textAlign: TextAlign.center, style: const TextStyle(color: CyberColors.secondary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildControlGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.5,
        children: [
          _buildCyberBtn(Icons.lock_outline_rounded, "Lock", CyberColors.warm, () => sendCommand('lock', true)),
          _buildCyberBtn(Icons.power_settings_new_rounded, "Shutdown", CyberColors.danger, () => sendCommand('shutdown', true)),
          _buildCyberBtn(Icons.camera_alt_outlined, "Screenshot", CyberColors.primary, () => sendCommand('screenshot', true)),
          _buildCyberBtn(Icons.message_outlined, "Message", CyberColors.secondary, () => _showPopupDialog()),
          _buildCyberBtn(Icons.public, "Open URL", Colors.pinkAccent, () => _showUrlDialog()),
        ],
      ),
    );
  }

  Widget _buildCyberBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return CyberCard(
      accentColor: color,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildScreenshotCard(String? imageUrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: CyberCard(
        accentColor: CyberColors.secondary,
        onTap: () {
          if (imageUrl != null) _showImageDialog(imageUrl);
        },
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search_rounded, color: CyberColors.secondary),
            SizedBox(width: 10),
            Text("View Last Screenshot", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Running Apps", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CyberColors.textPrimary)),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CyberColors.secondary),
            onPressed: () => sendCommand('get_apps', true),
            tooltip: "Refresh List",
          ),
        ],
      ),
    );
  }

  Widget _buildAppList(List<dynamic> appList) {
    if (appList.isEmpty) {
      return const CyberCard(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: EdgeInsets.all(30),
        child: Center(child: Text("No data. Tap refresh.", style: TextStyle(color: CyberColors.textSecondary))),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: appList.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        String appName = appList[index].toString();
        return CyberCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.zero,
          accentColor: CyberColors.primary,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            leading: const Icon(Icons.apps_rounded, color: CyberColors.primary),
            title: Text(appName, style: const TextStyle(color: CyberColors.textPrimary, fontWeight: FontWeight.w500)),
            trailing: IconButton(
              icon: Icon(Icons.close_rounded, color: CyberColors.danger.withOpacity(0.8)),
              onPressed: () => sendCommand('kill', appName),
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: CyberColors.secondary, width: 2),
                borderRadius: BorderRadius.circular(10),
                color: CyberColors.surface,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 10),
            CyberButton(text: "Close", onPressed: () => Navigator.pop(ctx))
          ],
        ),
      ),
    );
  }

  void _showPopupDialog() {
    TextEditingController msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: BorderSide(color: CyberColors.primary.withOpacity(0.3))),
        title: const Text("Send Message to PC"),
        content: NeonTextField(controller: msgController, label: "Message...", icon: Icons.message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CyberColors.secondary),
            onPressed: () {
              if (msgController.text.isNotEmpty) {
                sendCommand('popup', msgController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Send"),
          )
        ],
      ),
    );
  }

  void _showUrlDialog() {
    TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CyberColors.surface,
        title: const Text("Open Website"),
        content: NeonTextField(controller: urlController, label: "youtube.com", icon: Icons.public, keyboardType: TextInputType.url),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                String url = urlController.text;
                if(!url.startsWith("http")) url = "https://$url";
                sendCommand('open_url', url);
                Navigator.pop(context);
              }
            },
            child: const Text("Open"),
          )
        ],
      ),
    );
  }
}