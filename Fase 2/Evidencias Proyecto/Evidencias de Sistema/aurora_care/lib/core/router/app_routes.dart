/// Rutas de navegación: nunca incluyen nombres, emails ni UUID cognitivos.
abstract final class AppRoutes {
  static const privacy = '/privacy';
  static const startup = '/';
  static const welcome = '/welcome';
  static const roleSelection = '/role';
  static const elderRegister = '/auth/elder/register';
  static const elderLogin = '/auth/elder/login';
  static const forgotPassword = '/auth/elder/password';
  static const caregiverForgotPassword = '/auth/caregiver/password';
  static const disclaimer = '/onboarding/disclaimer';
  static const modeSelection = '/onboarding/mode';
  static const home = '/home';
  static const caregiverLink = '/home/caregiver-link';
  static const progressReport = '/home/report';
  static const caregiverRegister = '/auth/caregiver/register';
  static const caregiverLogin = '/auth/caregiver/login';
  static const caregiverHome = '/caregiver/home';
}
