import '../models/role.dart';
import '../models/session.dart';

void assertPerm(Permission perm) {
  final sess = Session().current;
  if (sess == null) throw Exception('Oturum yok');
  if (!sess.perms.contains(perm)) {
    throw Exception('Yetkisiz işlem: ${perm.name}');
  }
}

void assertSameBranch(int recordSubeId) {
  final sess = Session().current;
  if (sess == null) throw Exception('Oturum yok');
  if (sess.subeId != recordSubeId) {
    throw Exception('Bu kayıt farklı bir şubeye ait (Şube izolasyonu)');
  }
}