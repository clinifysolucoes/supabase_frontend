/// Fotos e exames do prontuario (ad.patient_file_list / Edge Function
/// patient-file).
library;

/// Foto ou exame.
enum PatientFileType {
  photo(1),
  exam(2);

  const PatientFileType(this.code);
  final int code;

  static PatientFileType of(int? code) => code == 2 ? exam : photo;

  /// Categorias validas para o tipo (o banco recusa as do outro tipo).
  List<FileCategory> get categories => [
    for (final c in FileCategory.values)
      if (c.type == null || c.type == this) c,
  ];

  List<String> get extensions => [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'pdf',
    if (this == exam) 'dcm',
  ];
}

enum FileCategory {
  intraoral(1, 'Intraoral', PatientFileType.photo),
  extraoral(2, 'Extraoral', PatientFileType.photo),
  before(3, 'Antes', PatientFileType.photo),
  after(4, 'Depois', PatientFileType.photo),
  periapical(10, 'Radiografia periapical', PatientFileType.exam),
  panoramic(11, 'Radiografia panorâmica', PatientFileType.exam),
  tomography(12, 'Tomografia', PatientFileType.exam),
  laboratory(13, 'Exame laboratorial', PatientFileType.exam),
  report(14, 'Laudo', PatientFileType.exam),
  other(99, 'Outro', null);

  const FileCategory(this.code, this.label, this.type);
  final int code;
  final String label;
  final PatientFileType? type;

  static FileCategory of(int? code) =>
      values.firstWhere((c) => c.code == code, orElse: () => other);
}

abstract final class PatientFiles {
  /// Limite do banco e do bucket (20 MB).
  static const maxBytes = 20 * 1024 * 1024;

  static String? mimeOf(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'dcm' => 'application/dicom',
      _ => null,
    };
  }

  static String size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB'
      : '${(bytes / 1024).ceil()} KB';
}

class PatientFile {
  const PatientFile({
    required this.nrFile,
    required this.type,
    this.category = FileCategory.other,
    required this.vcName,
    required this.vcMime,
    this.qtBytes = 0,
    this.dtFile,
    this.vcTooth,
    this.vcDescription,
    this.vcUser,
  });

  factory PatientFile.fromJson(Map<String, dynamic> j) => PatientFile(
    nrFile: (j['nr_file'] as num).toInt(),
    type: PatientFileType.of((j['it_type'] as num?)?.toInt()),
    category: FileCategory.of((j['it_category'] as num?)?.toInt()),
    vcName: j['vc_name'] as String? ?? '',
    vcMime: j['vc_mime'] as String? ?? '',
    qtBytes: (j['qt_bytes'] as num?)?.toInt() ?? 0,
    dtFile: DateTime.tryParse(j['dt_file'] as String? ?? ''),
    vcTooth: j['vc_tooth'] as String?,
    vcDescription: j['vc_description'] as String?,
    vcUser: j['vc_user'] as String?,
  );

  final int nrFile;
  final PatientFileType type;
  final FileCategory category;
  final String vcName;
  final String vcMime;
  final int qtBytes;
  final DateTime? dtFile;
  final String? vcTooth;
  final String? vcDescription;
  final String? vcUser;

  /// O navegador mostra (HEIC e DICOM so baixando).
  bool get isViewableImage =>
      const {'image/jpeg', 'image/png', 'image/webp'}.contains(vcMime);
  bool get isPdf => vcMime == 'application/pdf';
}

class PatientFileList {
  const PatientFileList({
    this.files = const [],
    this.canCreate = false,
    this.canUpdate = false,
  });

  factory PatientFileList.fromJson(Map<String, dynamic> j) {
    final perm = (j['permission'] as Map?) ?? const {};
    return PatientFileList(
      files: ((j['files'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PatientFile.fromJson)
          .toList(),
      canCreate: perm['id_create'] as bool? ?? false,
      canUpdate: perm['id_update'] as bool? ?? false,
    );
  }

  final List<PatientFile> files;
  final bool canCreate;
  final bool canUpdate;
}
