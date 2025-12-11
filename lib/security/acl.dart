// Basit Rol/İzin sistemi ve izin kontrol yardımcıları.
// Tüm ekranlar ve repository'ler Permission enumunu kullanarak kontrol yapabilir.

import '../models/role.dart';
import '../models/session.dart';

enum Permission {
  viewVehicles,
  editVehicles,
  viewReservations,
  editReservations,
  viewBranches,
  editBranches,
  viewEmployees,
  editEmployees,
  viewLogs,
  editPayments,
}

class Acl {
  // Pozisyondan role dönüştür
  static Role roleFromPozisyon(String? pozisyon) {
    final p = (pozisyon ?? '').trim().toLowerCase();
    if (p.isEmpty) return Role.user;
    if (p.contains('yönetici') || p.contains('mudur') || p.contains('müdür') || p.contains('admin')) {
      return Role.admin;
    }
    if (p.contains('super') || p.contains('supervisor')) {
      return Role.supervisor;
    }
    return Role.user;
  }

  // Role göre izin seti
  static Set<Permission> permissions(Role role) {
    switch (role) {
      case Role.admin:
        return {
          Permission.viewVehicles, Permission.editVehicles,
          Permission.viewReservations, Permission.editReservations,
          Permission.viewBranches, Permission.editBranches,
          Permission.viewEmployees, Permission.editEmployees,
          Permission.viewLogs, Permission.editPayments,
        };
      case Role.supervisor:
        return {
          Permission.viewVehicles, Permission.editVehicles,
          Permission.viewReservations, Permission.editReservations,
          Permission.viewBranches,
          Permission.viewEmployees,
          Permission.viewLogs, Permission.editPayments,
        };
      case Role.user:
      default:
        return {
          Permission.viewVehicles,
          Permission.viewReservations,
          Permission.viewBranches,
          Permission.viewEmployees,
          Permission.viewLogs,
        };
    }
  }
}

// Aktif oturumdan izin kontrolü
void assertPerm(Permission p) {
  final sess = Session().current;
  if (sess == null) {
    throw Exception('Oturum bulunamadı. Lütfen giriş yapınız.');
  }
  if (!sess.perms.contains(p)) {
    throw Exception('Bu işlem için yetkiniz yok: $p');
  }
}