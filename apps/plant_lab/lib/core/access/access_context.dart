class AccessSite {
  const AccessSite({
    required this.id,
    required this.siteCode,
    required this.siteName,
    required this.siteType,
    required this.companyId,
  });

  final String id;
  final String siteCode;
  final String siteName;
  final String siteType;
  final int companyId;

  factory AccessSite.fromJson(Map<String, dynamic> json) {
    return AccessSite(
      id: _requiredString(json, 'id'),
      siteCode: _requiredString(json, 'site_code'),
      siteName: _requiredString(json, 'site_name'),
      siteType: _requiredString(json, 'site_type'),
      companyId: _requiredInt(json, 'company_id'),
    );
  }
}

class AccessRole {
  const AccessRole({
    required this.moduleCode,
    required this.roleCode,
    required this.roleName,
    this.siteId,
    this.companyId,
  });

  final String moduleCode;
  final String roleCode;
  final String roleName;
  final String? siteId;
  final int? companyId;

  factory AccessRole.fromJson(Map<String, dynamic> json) {
    return AccessRole(
      moduleCode: _requiredString(json, 'module_code'),
      roleCode: _requiredString(json, 'role_code'),
      roleName: _requiredString(json, 'role_name'),
      siteId: _optionalString(json['site_id']),
      companyId: _optionalInt(json['company_id']),
    );
  }
}

class AccessContext {
  const AccessContext({
    required this.userId,
    required this.primaryRoleName,
    required this.modules,
    required this.roles,
    required this.sites,
    required this.canAccessPlant,
    required this.canAccessLab,
    required this.canManageUsers,
  });

  final String userId;
  final String primaryRoleName;
  final List<String> modules;
  final List<AccessRole> roles;
  final List<AccessSite> sites;
  final bool canAccessPlant;
  final bool canAccessLab;
  final bool canManageUsers;

  bool get hasApplicationAccess =>
      canAccessPlant || canAccessLab || canManageUsers;

  String get siteSummary {
    if (sites.isEmpty) return 'No active site assignment';
    return sites.map((site) => site.siteName).join(', ');
  }

  factory AccessContext.fromJson(Map<String, dynamic> json) {
    return AccessContext(
      userId: _requiredString(json, 'user_id'),
      primaryRoleName: _requiredString(json, 'primary_role_name'),
      modules: _mapList(json, 'modules', (value) => value.toString()),
      roles: _mapList(
        json,
        'roles',
        (value) => AccessRole.fromJson(_asMap(value, 'roles')),
      ),
      sites: _mapList(
        json,
        'sites',
        (value) => AccessSite.fromJson(_asMap(value, 'sites')),
      ),
      canAccessPlant: _requiredBool(json, 'can_access_plant'),
      canAccessLab: _requiredBool(json, 'can_access_lab'),
      canManageUsers: _requiredBool(json, 'can_manage_users'),
    );
  }
}

Map<String, dynamic> _asMap(Object? value, String fieldName) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('$fieldName must contain JSON objects.');
}

List<T> _mapList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Object? value) mapper,
) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a JSON array.');
  return List<T>.unmodifiable(value.map(mapper));
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  return value.toString();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _optionalInt(json[key]);
  if (value == null) throw FormatException('$key must be an integer.');
  return value;
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean.');
}
