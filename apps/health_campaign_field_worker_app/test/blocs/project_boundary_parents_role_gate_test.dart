import 'package:flutter_test/flutter_test.dart';
import 'package:health_campaign_field_worker_app/models/auth/auth_model.dart';
import 'package:health_campaign_field_worker_app/models/entities/roles_type.dart';

/// Mirrors the `needsBoundaryParents` role-gating predicate in
/// `ProjectBloc._handleProjectSelection` (lib/blocs/project/project.dart).
/// That predicate decides whether a registrar/distributor's boundary fetch
/// should be widened (unfiltered boundaryType + includeParents: true) so the
/// boundary selection page can offer "Health Facility" and "Distribution
/// Point" levels. This test exercises the predicate logic directly against
/// `UserRoleModel`, since the real call site reads roles off a `BuildContext`
/// extension that isn't easily unit-testable in isolation.
bool needsBoundaryParents(List<UserRoleModel> roles) {
  return roles.any(
    (role) =>
        role.code == RolesType.registrar.toValue() ||
        role.code == RolesType.distributor.toValue(),
  );
}

void main() {
  group('needsBoundaryParents role gate', () {
    test('is true for a registrar', () {
      final roles = [
        UserRoleModel(code: RolesType.registrar.toValue()),
      ];
      expect(needsBoundaryParents(roles), isTrue);
    });

    test('is true for a distributor', () {
      final roles = [
        UserRoleModel(code: RolesType.distributor.toValue()),
      ];
      expect(needsBoundaryParents(roles), isTrue);
    });

    test('is true when the user holds a registrar role alongside others', () {
      final roles = [
        UserRoleModel(code: RolesType.fieldSupervisor.toValue()),
        UserRoleModel(code: RolesType.registrar.toValue()),
      ];
      expect(needsBoundaryParents(roles), isTrue);
    });

    test('is false for roles outside registrar/distributor', () {
      final roles = [
        UserRoleModel(code: RolesType.warehouseManager.toValue()),
        UserRoleModel(code: RolesType.healthFacilityWorker.toValue()),
        UserRoleModel(code: RolesType.districtSupervisor.toValue()),
        UserRoleModel(code: RolesType.fieldSupervisor.toValue()),
        UserRoleModel(code: RolesType.superuser.toValue()),
        UserRoleModel(code: RolesType.teamSupervisor.toValue()),
        UserRoleModel(code: RolesType.communityDistributor.toValue()),
        UserRoleModel(code: RolesType.communitySupervisor.toValue()),
        UserRoleModel(code: RolesType.healthFacilitySupervisor.toValue()),
      ];
      expect(needsBoundaryParents(roles), isFalse);
    });

    test('is false when the user has no roles', () {
      expect(needsBoundaryParents(const []), isFalse);
    });
  });
}
