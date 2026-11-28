/// Validación de formato; no confirma la existencia del buzón.
class EmailValidation {
  EmailValidation._();

  static final _local = RegExp(r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~.-]+$");
  static final _label = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$');

  static bool isValid(String value) {
    final email = value.trim();
    final parts = email.split('@');
    if (email.length > 254 || parts.length != 2) return false;
    final local = parts.first;
    final domain = parts.last;
    if (local.isEmpty ||
        local.length > 64 ||
        !_local.hasMatch(local) ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..')) {
      return false;
    }
    final labels = domain.split('.');
    return labels.length >= 2 &&
        labels.every((label) => label.length <= 63 && _label.hasMatch(label)) &&
        RegExp(r'^[A-Za-z]{2,63}$').hasMatch(labels.last);
  }

  // Solo errores frecuentes conocidos; nunca se modifica el correo solo.
  static String? suggestion(String value) {
    final email = value.trim();
    if (!isValid(email)) return null;
    final parts = email.split('@');
    const corrections = {
      'gmai.com': 'gmail.com',
      'gmial.com': 'gmail.com',
      'gmail.con': 'gmail.com',
      'gmail.cl': 'gmail.com',
      'hotmial.com': 'hotmail.com',
      'hotmail.con': 'hotmail.com',
      'outlok.com': 'outlook.com',
      'outlook.con': 'outlook.com',
    };
    final corrected = corrections[parts.last.toLowerCase()];
    return corrected == null ? null : '${parts.first}@$corrected';
  }
}
