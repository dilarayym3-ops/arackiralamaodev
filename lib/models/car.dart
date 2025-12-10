class Car {
  final String saseNo;
  final String plaka;
  final String durum;
  final int km;
  final String? renk;
  final int modelId;
  final String marka;
  final String model;
  final int yil;
  final double gunlukKira;
  final double depozito;
  final int subeId;
  final String subeAdi;

  Car({
    required this.saseNo,
    required this.plaka,
    required this.durum,
    required this.km,
    required this.renk,
    required this.modelId,
    required this.marka,
    required this.model,
    required this.yil,
    required this.gunlukKira,
    required this.depozito,
    required this.subeId,
    required this.subeAdi,
  });

  factory Car.fromMap(Map<String, dynamic> m) => Car(
        saseNo: m['SASE_NO'] ?? '',
        plaka: m['PLAKA'] ?? '',
        durum: m['DURUM'] ?? '',
        km: (m['KM'] ?? 0) as int,
        renk: m['RENK'],
        modelId: (m['MODEL_ID'] ?? 0) as int,
        marka: m['Marka'] ?? '',
        model: m['Model'] ?? '',
        yil: (m['Yil'] ?? 0) as int,
        gunlukKira: (m['GUNLUK_KIRA_BEDELI'] as num).toDouble(),
        depozito: (m['DEPOZITO_UCRETI'] as num).toDouble(),
        subeId: (m['GUNCEL_SUBE_ID'] ?? 0) as int,
        subeAdi: m['GUNCEL_SUBE_ADI'] ?? '',
      );
}