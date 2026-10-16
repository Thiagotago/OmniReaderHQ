class AccessDecision {
  const AccessDecision.allowed()
      : allowed = true,
        reason = null;

  const AccessDecision.denied(String message)
      : allowed = false,
        reason = message;

  final bool allowed;
  final String? reason;
}

/// Centralizes the future download gate.
///
/// The first milestone intentionally has no download implementation. Any
/// future file transfer must call this policy with explicit user authorization.
class AccessPolicy {
  const AccessPolicy();

  AccessDecision evaluate({required bool userAuthorized}) {
    if (!userAuthorized) {
      return const AccessDecision.denied(
        'Download bloqueado: autorização explícita é obrigatória.',
      );
    }
    return const AccessDecision.allowed();
  }
}
