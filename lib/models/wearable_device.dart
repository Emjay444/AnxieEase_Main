/// Model for wearable device information and user linking
class WearableDevice {
  /// Unique device identifier (e.g., "AE-HR001")
  final String deviceId;

  /// Device name/model for display
  final String deviceName;

  /// User ID who owns this device (linked to user_profiles)
  final String? userId;

  /// User's resting heart rate baseline (calculated during setup)
  final double? baselineHR;

  /// When the device was first linked to the user
  final DateTime? linkedAt;

  /// When baseline HR was last updated
  final DateTime? baselineUpdatedAt;

  /// Whether device is currently active/connected
  final bool isActive;

  /// Device firmware version
  final String? firmwareVersion;

  /// Battery level percentage (0-100)
  final double? batteryLevel;

  /// Last time device was seen online
  final DateTime? lastSeenAt;

  const WearableDevice({
    required this.deviceId,
    required this.deviceName,
    this.userId,
    this.baselineHR,
    this.linkedAt,
    this.baselineUpdatedAt,
    this.isActive = false,
    this.firmwareVersion,
    this.batteryLevel,
    this.lastSeenAt,
  });

  /// Create from Supabase database record
  factory WearableDevice.fromSupabase(Map<String, dynamic> data) {
    return WearableDevice(
      deviceId: data['device_id'] as String,
      deviceName: data['device_name'] as String,
      userId: data['user_id'] as String?,
      baselineHR: data['baseline_hr']?.toDouble(),
      linkedAt: data['linked_at'] != null
          ? DateTime.parse(data['linked_at'] as String)
          : null,
      baselineUpdatedAt: data['baseline_updated_at'] != null
          ? DateTime.parse(data['baseline_updated_at'] as String)
          : null,
      isActive: data['is_active'] as bool? ?? false,
      firmwareVersion: data['firmware_version'] as String?,
      batteryLevel: data['battery_level']?.toDouble(),
      lastSeenAt: data['last_seen_at'] != null
          ? DateTime.parse(data['last_seen_at'] as String)
          : null,
    );
  }

  /// Convert to Supabase format for insert/update
  Map<String, dynamic> toSupabase() => {
        'device_id': deviceId,
        'device_name': deviceName,
        if (userId != null) 'user_id': userId,
        if (baselineHR != null) 'baseline_hr': baselineHR,
        if (linkedAt != null) 'linked_at': linkedAt!.toIso8601String(),
        if (baselineUpdatedAt != null)
          'baseline_updated_at': baselineUpdatedAt!.toIso8601String(),
        'is_active': isActive,
        if (firmwareVersion != null) 'firmware_version': firmwareVersion,
        if (batteryLevel != null) 'battery_level': batteryLevel,
        if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
      };

  /// Check if device needs baseline HR setup
  bool get needsBaselineSetup => baselineHR == null;

  /// Check if device is linked to a user
  bool get isLinked => userId != null;

  /// Check if baseline is stale (older than 30 days)
  bool get isBaselineStale {
    if (baselineUpdatedAt == null) return true;
    final daysSinceUpdate =
        DateTime.now().difference(baselineUpdatedAt!).inDays;
    return daysSinceUpdate > 30;
  }

  /// Create a copy with updated values
  WearableDevice copyWith({
    String? deviceId,
    String? deviceName,
    String? userId,
    double? baselineHR,
    DateTime? linkedAt,
    DateTime? baselineUpdatedAt,
    bool? isActive,
    String? firmwareVersion,
    double? batteryLevel,
    DateTime? lastSeenAt,
  }) {
    return WearableDevice(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      userId: userId ?? this.userId,
      baselineHR: baselineHR ?? this.baselineHR,
      linkedAt: linkedAt ?? this.linkedAt,
      baselineUpdatedAt: baselineUpdatedAt ?? this.baselineUpdatedAt,
      isActive: isActive ?? this.isActive,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return 'WearableDevice(deviceId: $deviceId, userId: $userId, '
        'baselineHR: $baselineHR, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WearableDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}
