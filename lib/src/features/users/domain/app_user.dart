import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String displayName,
    required String email,
    @Default('') String phone,
    required String role,           // admin|store|designer|engineer|accounts
    @Default('active') String status, // active|suspended
    required String createdAt,      // ISO UTC
    required String createdBy,      // uid
    String? updatedAt,              // ISO UTC
    String? updatedBy,              // uid
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);

  factory AppUser.fromFirestore(String id, Map<String, dynamic> data) =>
      AppUser.fromJson({'id': id, ...data});

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}

