enum AppRole {
  admin,       // Yönetici / Şube Müdürü
  satici,      // Satıcı
  operasyon,   // Operasyon
  muhasebe,    // Muhasebe
  diger,       // Tanımsız/diğer
}

enum Permission {
  viewVehicles, editVehicles,
  viewModels, editModels,
  viewBranches, editBranches,
  viewEmployees, editEmployees,
  viewCustomers, editCustomers,
  viewCampaigns, editCampaigns,
  viewServices, editServices,
  viewReservations, editReservations,
  viewRentals, editRentals,
  viewPayments, editPayments,
  viewFines, editFines,
  viewInsurance, editInsurance,
  viewMaintenance, editMaintenance,
  viewLogs,
}

class Acl {
  static AppRole roleFromPozisyon(String? poz) {
    final p = (poz ?? '').toLowerCase().trim();
    if (p.contains('müdür') || p.contains('şube müdürü')) return AppRole.admin;
    if (p.contains('yönetici') || p.contains('admin')) return AppRole.admin;
    if (p.contains('operasyon')) return AppRole.operasyon;
    if (p.contains('muhasebe')) return AppRole.muhasebe;
    if (p.contains('satıcı') || p.contains('satis') || p.contains('satış')) return AppRole.satici;
    return AppRole.diger;
  }

  static Set<Permission> permissions(AppRole r) {
    switch (r) {
      case AppRole.admin:
        return Permission.values.toSet();
      case AppRole.operasyon:
        return {
          Permission.viewVehicles, Permission.editVehicles,
          Permission.viewModels,
          Permission.viewReservations, Permission.editReservations,
          Permission.viewRentals, Permission.editRentals,
          Permission.viewInsurance, Permission.editInsurance,
          Permission.viewMaintenance, Permission.editMaintenance,
          Permission.viewCustomers, Permission.editCustomers,
          Permission.viewServices,
          Permission.viewCampaigns,
          Permission.viewLogs,
        };
      case AppRole.muhasebe:
        return {
          Permission.viewVehicles,
          Permission.viewRentals,
          Permission.viewPayments, Permission.editPayments,
          Permission.viewFines, Permission.editFines,
          Permission.viewReservations, // finans için görünür
          Permission.viewCustomers,
          Permission.viewLogs,
        };
      case AppRole.satici:
        return {
          Permission.viewVehicles,
          Permission.viewModels,
          Permission.viewReservations, Permission.editReservations,
          Permission.viewCustomers, Permission.editCustomers,
          Permission.viewCampaigns,
          Permission.viewServices,
          Permission.viewLogs,
        };
      case AppRole.diger:
        return { Permission.viewVehicles, Permission.viewModels };
    }
  }
}