import 'package:flutter/material.dart';

import '../../../l10n/strings.dart';

/// Item da lixeira (ad.trash_list).
class TrashItem {
  const TrashItem({
    required this.vcKind,
    required this.nrKey,
    this.nrParent,
    this.vcTitle = '',
    this.vcDetail = '',
    this.dhDeleted,
    this.vcUser,
    this.idRestore = false,
  });

  factory TrashItem.fromJson(Map<String, dynamic> j) => TrashItem(
    vcKind: '${j['vc_kind']}',
    nrKey: (j['nr_key'] as num).toInt(),
    nrParent: (j['nr_parent'] as num?)?.toInt(),
    vcTitle: j['vc_title']?.toString() ?? '',
    vcDetail: j['vc_detail']?.toString() ?? '',
    dhDeleted: DateTime.tryParse('${j['dh_deleted']}'),
    vcUser: j['vc_user']?.toString(),
    idRestore: j['id_restore'] == true,
  );

  final String vcKind;
  final int nrKey;
  final int? nrParent;
  final String vcTitle;
  final String vcDetail;
  final DateTime? dhDeleted;
  final String? vcUser;
  final bool idRestore;
}

class TrashData {
  const TrashData({this.items = const [], this.kinds = const []});

  factory TrashData.fromJson(Map<String, dynamic> j) => TrashData(
    items: [
      for (final i in (j['items'] as List? ?? const []))
        TrashItem.fromJson((i as Map).cast<String, dynamic>()),
    ],
    kinds: [for (final k in (j['kinds'] as List? ?? const [])) '$k'],
  );

  final List<TrashItem> items;

  /// Tipos que o usuario pode ver.
  final List<String> kinds;
}

/// Rotulo e icone de cada tipo da lixeira.
abstract final class TrashKind {
  static String label(String kind) => switch (kind) {
    'patient' => Strings.trashPatient,
    'patient_note' => Strings.trashPatientNote,
    'appointment' => Strings.trashAppointment,
    'fin_entry' => Strings.trashFinEntry,
    'procedure' => Strings.trashProcedure,
    'material' => Strings.trashMaterial,
    'professional' => Strings.trashProfessional,
    _ => kind,
  };

  static IconData icon(String kind) => switch (kind) {
    'patient' => Icons.person_outline_rounded,
    'patient_note' => Icons.sticky_note_2_outlined,
    'appointment' => Icons.event_busy_outlined,
    'fin_entry' => Icons.receipt_long_outlined,
    'procedure' => Icons.medical_services_outlined,
    'material' => Icons.inventory_2_outlined,
    'professional' => Icons.badge_outlined,
    _ => Icons.delete_outline_rounded,
  };
}
