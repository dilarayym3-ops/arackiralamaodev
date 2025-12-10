import 'role.dart';

class SessionUser {
  final int calisanId;
  final int subeId;
  final String subeAdi;
  final String email;
  final String ad;
  final String soyad;
  final String? pozisyon;
  final AppRole role;
  final Set<Permission> perms;

  SessionUser({
    required this.calisanId,
    required this.subeId,
    required this.subeAdi,
    required this.email,
    required this.ad,
    required this.soyad,
    this.pozisyon,
    required this.role,
    required this.perms,
  });
}

class Session {
  static final Session _i = Session._internal();
  factory Session() => _i;
  Session._internal();

  SessionUser? current;

  bool get isLoggedIn => current != null;
  void logout() => current = null;
}