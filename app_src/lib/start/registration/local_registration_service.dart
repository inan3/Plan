import 'package:shared_preferences/shared_preferences.dart';
import 'verification_provider.dart';

class LocalRegistrationService {
  static const _providerKey = 'pending_reg_provider';
  static const _emailKey = 'pending_reg_email';
  static const _passwordKey = 'pending_reg_password';

  static Future<void> saveEmailPassword({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, VerificationProvider.password.name);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_passwordKey, password);
  }

  static Future<void> saveGoogle({String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, VerificationProvider.google.name);
    if (email != null) await prefs.setString(_emailKey, email);
  }

  static Future<(VerificationProvider?, String?, String?)> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final providerName = prefs.getString(_providerKey);
    if (providerName == null) return (null, null, null);
    final provider = VerificationProvider.values
        .firstWhere((e) => e.name == providerName);
    final email = prefs.getString(_emailKey);
    final password = prefs.getString(_passwordKey);
    return (provider, email, password);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
  }
}
