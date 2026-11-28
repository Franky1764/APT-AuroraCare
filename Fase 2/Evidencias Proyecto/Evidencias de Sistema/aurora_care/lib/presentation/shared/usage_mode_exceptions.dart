/// El modo ya se confirmó; solo falta preparar el seguimiento del dispositivo.
class UsageModeProfilePending implements Exception {
  const UsageModeProfilePending(this.mode);
  final int mode;
}

/// La revocación se confirmó, pero no el cambio de modo.
class UsageModeSaveAfterRevocationFailed implements Exception {
  const UsageModeSaveAfterRevocationFailed();
}
