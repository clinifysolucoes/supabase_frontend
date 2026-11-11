/// Relatorios (ad.report_get): faltas e desmarcacoes, aniversariantes,
/// procedimentos executados e pagamentos e comissoes.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../l10n/strings.dart';
import '../../../shared/formatters/dates.dart';
import '../../../shared/formatters/masks.dart';

enum ReportKind {
  noShow('no_show', Strings.reportNoShow),
  birthdays('birthdays', Strings.reportBirthdays),
  procedures('procedures', Strings.reportProcedures),
  commissions('commissions', Strings.reportCommissions);

  const ReportKind(this.code, this.label);

  final String code;
  final String label;

  /// Aniversariantes nao filtram por profissional.
  bool get byProfessional => this != birthdays;

  /// Comissoes exigem tambem ler o Financeiro.
  bool get needsFinance => this == commissions;
}

/// Uma coluna do relatorio: titulo, texto da celula e se e valor (alinha a direita).
class ReportColumn {
  const ReportColumn(this.title, this.text, {this.numeric = false});

  final String title;
  final String Function(Map<String, dynamic> row) text;
  final bool numeric;
}

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
int _int(Object? v) => (v as num?)?.toInt() ?? 0;
String _s(Object? v) => v?.toString() ?? '';
DateTime? _date(Object? v) => DateTime.tryParse(v as String? ?? '');
String _phone(Object? v) {
  final s = _s(v);
  return s.isEmpty ? '' : Masks.format(MaskType.phone, s);
}

String _money(Object? v) => _num(v).toStringAsFixed(2).replaceAll('.', ',');

String _dateTime(Object? v) {
  final d = _date(v)?.toLocal();
  return d == null ? '' : '${Dates.format(d)} ${Dates.formatTime(d)}';
}

String _apptStatus(Object? v) => switch (_int(v)) {
  7 => Strings.statusNoShow,
  90 => Strings.statusCancelled,
  _ => '',
};

String _finStatus(Object? v) =>
    _int(v) == 2 ? Strings.reportPaid : Strings.reportOpen;

/// Colunas de cada relatorio (tela e CSV usam as mesmas).
List<ReportColumn> reportColumns(ReportKind kind) => switch (kind) {
  ReportKind.noShow => [
    ReportColumn(Strings.reportColDate, (r) => _dateTime(r['dh_start'])),
    ReportColumn(Strings.reportColPatient, (r) => _s(r['vc_patient'])),
    ReportColumn(Strings.reportColPhone, (r) => _phone(r['vc_mobile'])),
    ReportColumn(
      Strings.reportColProfessional,
      (r) => _s(r['vc_professional']),
    ),
    ReportColumn(Strings.reportColStatus, (r) => _apptStatus(r['it_status'])),
  ],
  ReportKind.birthdays => [
    ReportColumn(
      Strings.reportColBirthday,
      (r) => Dates.format(_date(r['dt_birthday'])),
    ),
    ReportColumn(Strings.reportColPatient, (r) => _s(r['vc_patient'])),
    ReportColumn(Strings.reportColAge, (r) => _s(r['qt_age']), numeric: true),
    ReportColumn(Strings.reportColPhone, (r) => _phone(r['vc_mobile'])),
    ReportColumn(Strings.reportColEmail, (r) => _s(r['vc_email'])),
  ],
  ReportKind.procedures => [
    ReportColumn(Strings.reportColDate, (r) => _dateTime(r['dh_evolution'])),
    ReportColumn(Strings.reportColPatient, (r) => _s(r['vc_patient'])),
    ReportColumn(Strings.reportColProcedure, (r) => _s(r['vc_procedure'])),
    ReportColumn(Strings.reportColTooth, (r) => _s(r['vc_tooth'])),
    ReportColumn(
      Strings.reportColProfessional,
      (r) => _s(r['vc_professional']),
    ),
    ReportColumn(
      Strings.reportColValue,
      (r) => r['vl_total'] == null ? '' : _money(r['vl_total']),
      numeric: true,
    ),
  ],
  ReportKind.commissions => [
    ReportColumn(
      Strings.reportColCompetence,
      (r) => Dates.format(_date(r['dt_competence'])),
    ),
    ReportColumn(
      Strings.reportColProfessional,
      (r) => _s(r['vc_professional']),
    ),
    ReportColumn(Strings.reportColDescription, (r) => _s(r['vc_description'])),
    ReportColumn(Strings.reportColDue, (r) => Dates.format(_date(r['dt_due']))),
    ReportColumn(
      Strings.reportColValue,
      (r) => _money(r['vl_amount']),
      numeric: true,
    ),
    ReportColumn(Strings.reportColStatus, (r) => _finStatus(r['it_status'])),
    ReportColumn(
      Strings.reportColPaidOn,
      (r) => r['dt_paid'] == null ? '' : Dates.format(_date(r['dt_paid'])),
    ),
  ],
};

class ReportResult {
  const ReportResult({
    required this.kind,
    this.rows = const [],
    this.summary = const {},
    this.byProfessional = const [],
    this.qtRows = 0,
    this.idTruncated = false,
  });

  factory ReportResult.fromJson(ReportKind kind, Map<String, dynamic> j) =>
      ReportResult(
        kind: kind,
        rows: ((j['rows'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        summary: ((j['summary'] as Map?) ?? const {}).cast<String, dynamic>(),
        byProfessional: ((j['by_professional'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        qtRows: _int(j['qt_rows']),
        idTruncated: j['id_truncated'] as bool? ?? false,
      );

  final ReportKind kind;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> byProfessional;
  final int qtRows;
  final bool idTruncated;

  int qt(String key) => _int(summary[key]);
  double vl(String key) => _num(summary[key]);

  /// CSV com ";" e BOM (abre direto no Excel em portugues).
  Uint8List toCsv() {
    String cell(String v) {
      final s = v.replaceAll('"', '""');
      return s.contains(';') || s.contains('"') || s.contains('\n')
          ? '"$s"'
          : s;
    }

    final cols = reportColumns(kind);
    final b = StringBuffer()..writeln(cols.map((c) => cell(c.title)).join(';'));
    for (final r in rows) {
      b.writeln(cols.map((c) => cell(c.text(r))).join(';'));
    }
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$b')]);
  }
}
