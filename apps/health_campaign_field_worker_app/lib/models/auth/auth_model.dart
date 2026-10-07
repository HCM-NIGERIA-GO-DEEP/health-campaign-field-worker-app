import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_model.freezed.dart';
part 'auth_model.g.dart';

@freezed
class AuthModel with _$AuthModel {
  const factory AuthModel({
    @JsonKey(name: 'access_token') required String accessToken,
    @JsonKey(name: 'token_type') required String tokenType,
    @JsonKey(name: 'refresh_token') required String refreshToken,
    @JsonKey(name: 'expires_in') required int expiresIn,
    @JsonKey(name: 'UserRequest') required UserRequestModel userRequestModel,
  }) = _AuthModel;

  factory AuthModel.fromJson(Map<String, dynamic> json) =>
      _$AuthModelFromJson(json);
}

@freezed
class ValidateResponseModel with _$ValidateResponseModel {
  const factory ValidateResponseModel({
    @JsonKey(name: 'isDuplicateLogin') required bool isDuplicateLogin,
    @JsonKey(name: 'existingDeviceToken') required String? existingDeviceToken,
  }) = _ValidateResponseModel;

  factory ValidateResponseModel.fromJson(Map<String, dynamic> json) =>
      _$ValidateResponseModelFromJson(json);
}

@freezed
class LoginModel with _$LoginModel {
  const factory LoginModel({
    required String username,
    required String password,
    @Default('EMPLOYEE') String userType,
    required String tenantId,
    @Default('read') String scope,
    @JsonKey(name: 'grant_type') @Default('password') String grantType,
  }) = _LoginModel;

  factory LoginModel.fromJson(Map<String, dynamic> json) =>
      _$LoginModelFromJson(json);
}

/// Form posted to the DIGIT token endpoint for an SSO login (`jwt_exchange`
/// grant). [assertion] is the raw Azure ID token; the backend validates it,
/// resolves the DIGIT employee from its claims and responds with the same
/// OAuth token payload as the password grant, parsed by [AuthModel].
@freezed
class SsoExchangeRequestModel with _$SsoExchangeRequestModel {
  const factory SsoExchangeRequestModel({
    required String assertion,
    required String tenantId,
    @Default('EMPLOYEE') String userType,
    @Default('read') String scope,
    @JsonKey(name: 'grant_type') @Default('jwt_exchange') String grantType,
  }) = _SsoExchangeRequestModel;

  factory SsoExchangeRequestModel.fromJson(Map<String, dynamic> json) =>
      _$SsoExchangeRequestModelFromJson(json);
}

@freezed
class UserRequestModel with _$UserRequestModel {
  const factory UserRequestModel({
    int? id,
    required String uuid,
    String? userName,
    String? name,
    String? mobileNumber,
    String? emailId,
    String? locale,
    bool? active,
    String? tenantId,
    String? permanentCity,
    String? gender,
    @Default([]) List<UserRoleModel> roles,
  }) = _UserRequestModel;

  factory UserRequestModel.fromJson(Map<String, dynamic> json) =>
      _$UserRequestModelFromJson(json);
}

@freezed
class UserRoleModel with _$UserRoleModel {
  const factory UserRoleModel({
    @Default('') String? name,
    required String code,
    String? tenantId,
  }) = _UserRoleModel;

  factory UserRoleModel.fromJson(Map<String, dynamic> json) =>
      _$UserRoleModelFromJson(json);
}
