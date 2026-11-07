import 'package:flutter_test/flutter_test.dart';
import 'package:odonto_app/features/patient_files/domain/patient_file_models.dart';

void main() {
  test('Categorias por tipo seguem a regra do banco', () {
    final photo = PatientFileType.photo.categories.map((c) => c.code);
    final exam = PatientFileType.exam.categories.map((c) => c.code);
    expect(photo, [1, 2, 3, 4, 99]);
    expect(exam, [10, 11, 12, 13, 14, 99]);
    expect(PatientFileType.photo.extensions, isNot(contains('dcm')));
    expect(PatientFileType.exam.extensions, contains('dcm'));
  });

  test('Tipo do arquivo pela extensao e tamanho legivel', () {
    expect(PatientFiles.mimeOf('Sorriso.JPG'), 'image/jpeg');
    expect(PatientFiles.mimeOf('pano.dcm'), 'application/dicom');
    expect(PatientFiles.mimeOf('a.gif'), isNull);
    expect(PatientFiles.size(2048), '2 KB');
    expect(PatientFiles.size(15 * 1024 * 1024), '15,0 MB');
  });

  test('Lista le arquivos e permissoes', () {
    final l = PatientFileList.fromJson({
      'files': [
        {
          'nr_file': 1,
          'it_type': 1,
          'it_category': 3,
          'vc_name': 'antes.jpg',
          'vc_mime': 'image/jpeg',
          'qt_bytes': 1000,
          'dt_file': '2026-11-07',
          'vc_tooth': '11',
        },
        {
          'nr_file': 2,
          'it_type': 2,
          'it_category': 11,
          'vc_name': 'pano.dcm',
          'vc_mime': 'application/dicom',
        },
      ],
      'permission': {'id_create': true, 'id_update': false},
    });
    expect(l.files.first.category, FileCategory.before);
    expect(l.files.first.isViewableImage, isTrue);
    expect(l.files[1].type, PatientFileType.exam);
    expect(l.files[1].isViewableImage, isFalse);
    expect(l.canCreate, isTrue);
    expect(l.canUpdate, isFalse);
  });
}
