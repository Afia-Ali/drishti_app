enum UserRole {
  visionUser,
  caregiver,
  unknown;

  // String conversion for Firestore storage
  String toFirestoreString() {
    switch (this) {
      case UserRole.visionUser:
        return 'vision_user';
      case UserRole.caregiver:
        return 'caregiver';
      case UserRole.unknown:
        return 'unknown';
    }
  }

  // Parse from Firestore
  static UserRole fromFirestoreString(String? value) {
    switch (value) {
      case 'vision_user':
        return UserRole.visionUser;
      case 'caregiver':
        return UserRole.caregiver;
      default:
        return UserRole.unknown;
    }
  }

  // Display helpers
  String get displayName {
    switch (this) {
      case UserRole.visionUser:
        return 'Vision User';
      case UserRole.caregiver:
        return 'Caregiver';
      case UserRole.unknown:
        return 'Unknown';
    }
  }

  String get description {
    switch (this) {
      case UserRole.visionUser:
        return 'For visually impaired users who use the camera and voice features';
      case UserRole.caregiver:
        return 'For family members or friends supporting a vision user';
      case UserRole.unknown:
        return '';
    }
  }
}
