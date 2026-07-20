import 'package:flutter/material.dart';

import 'keyboard_aware_header.dart';

void main() => runApp(const KeyboardAwareLoginApp());

class KeyboardAwareLoginApp extends StatelessWidget {
  const KeyboardAwareLoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keyboard-aware login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFE53935),
      ),
      home: const LoginPage(),
    );
  }
}

/// A login screen that stays usable while the keyboard is open:
///
/// * the hero shrinks by the keyboard's height, in sync with its motion
///   ([KeyboardAwareHeader]),
/// * the button is parked directly above the keyboard
///   ([KeyboardAwarePadding]),
/// * the form scrolls if it still doesn't fit (`Expanded` + scroll view).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const int _phoneLength = 10;

  final TextEditingController _phone = TextEditingController();
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phone
      ..removeListener(_onPhoneChanged)
      ..dispose();
    super.dispose();
  }

  bool get _canSubmit => _agreed && _phone.text.length == _phoneLength;

  void _onPhoneChanged() {
    // An iPhone number pad has no return key, so there's no "Done" to tap.
    // The last digit of a fixed-length number is the done signal.
    if (_phone.text.length == _phoneLength) {
      FocusScope.of(context).unfocus();
    }
    setState(() {}); // refresh the button's enabled state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We position the content ourselves — see KeyboardAwarePadding. Leaving
      // this on would lift everything a second time.
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: KeyboardAwarePadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── everything above the button scrolls ────────────────────
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const KeyboardAwareHeader(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: FlutterLogo(size: 220)), // your hero art
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Login with',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Phone number'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: _phoneLength,
                        decoration: const InputDecoration(
                          prefixText: '+91  ',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (v) =>
                                setState(() => _agreed = v ?? false),
                          ),
                          const Expanded(
                            child: Text('I agree with Terms & Privacy Policy'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── the button never scrolls: it rides the keyboard ────────
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _canSubmit ? () {} : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Get OTP'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
