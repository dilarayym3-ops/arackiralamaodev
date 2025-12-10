class Customer {
  final int musteriId;
  final String tcNo;
  final String ehliyetId;
  final String ad;
  final String soyad;
  final String telefon;
  final String email;
  final String? adres;
  final String durum;

  Customer({
    required this.musteriId,
    required this.tcNo,
    required this.ehliyetId,
    required this.ad,
    required this.soyad,
    required this.telefon,
    required this.email,
    this.adres,
    required this.durum,
  });

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        musteriId: m['MUSTERI_ID'] as int,
        tcNo: m['TC_NO'] ?? '',
        ehliyetId: m['EHLIYET_ID'] ?? '',
        ad: m['AD'] ?? '',
        soyad: m['SOYAD'] ?? '',
        telefon: m['TELEFON'] ?? '',
        email: m['E-MAIL'] ?? m['E_MAIL'] ?? '',
        adres: m['ADRES'],
        durum: m['DURUM'] ?? '',
      );
}