import 'package:liblanis/liblanis.dart';
import 'package:lanis/fork_identity.dart';

/// ISO date of the latest published privacy policy.
///
/// Bump this string when the policy is republished so users are prompted again.
const privacyPolicyPublishedAt = '2026-10-14'; // Fork: eigene PRIVACY.md

/// Canonical privacy policy URL (About + login + gate screen).
const privacyPolicyUrl = forkPrivacyPolicyUrl;

/// [shared_settings] key for the last accepted [privacyPolicyPublishedAt].
const privacyPolicyAcceptedVersionKey = 'privacy-policy-accepted-version';

bool isPrivacyPolicyAccepted(TypedSettings shared) {
  return shared.getString(privacyPolicyAcceptedVersionKey) ==
      privacyPolicyPublishedAt;
}

void acceptPrivacyPolicy(TypedSettings shared) {
  shared.setString(
    privacyPolicyAcceptedVersionKey,
    privacyPolicyPublishedAt,
  );
}

/// Whether background fetch may authenticate (same gate as cold-start auth).
bool shouldRunBackgroundFetch(TypedSettings shared) {
  return isPrivacyPolicyAccepted(shared);
}
