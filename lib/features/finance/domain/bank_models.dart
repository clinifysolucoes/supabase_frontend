import '../../../shared/formatters/dates.dart';

/// Situacao da linha do extrato (od.fin_bank_line.it_status).
abstract final class BankLineStatus {
  static const pending = 1;
  static const matched = 2;
  static const ignored = 90;
}

/// Sugestao de conciliacao (lancamento = 1, transferencia = 2).
class BankCandidate {
  const BankCandidate({
    required this.itSource,
    required this.nrRef,
    required this.dtRef,
    required this.vlValue,
    this.vcDescription = '',
    this.qtDays = 0,
  });

  factory BankCandidate.fromJson(Map<String, dynamic> j) => BankCandidate(
    itSource: _int(j['it_source'] ?? 1),
    nrRef: _int(j['nr_ref']),
    dtRef: _date(j['dt_ref']) ?? DateTime(2000),
    vlValue: _double(j['vl_value']),
    vcDescription: j['vc_description']?.toString() ?? '',
    qtDays: _int(j['qt_days'] ?? 0),
  );

  final int itSource;
  final int nrRef;
  final DateTime dtRef;
  final double vlValue;
  final String vcDescription;
  final int qtDays;

  bool get isTransfer => itSource == 2;

  /// Campo do fin_bank_reconcile (MATCH).
  Map<String, dynamic> get matchKey =>
      isTransfer ? {'nr_transfer': nrRef} : {'nr_entry': nrRef};
}

class BankLine {
  const BankLine({
    required this.nrLine,
    required this.dtPosted,
    required this.vlAmount,
    this.vcFitid = '',
    this.vcMemo,
    this.itStatus = BankLineStatus.pending,
    this.vcMatched,
    this.candidates = const [],
  });

  factory BankLine.fromJson(Map<String, dynamic> j) => BankLine(
    nrLine: _int(j['nr_line']),
    vcFitid: j['vc_fitid']?.toString() ?? '',
    dtPosted: _date(j['dt_posted']) ?? DateTime(2000),
    vlAmount: _double(j['vl_amount']),
    vcMemo: j['vc_memo']?.toString(),
    itStatus: _int(j['it_status'] ?? 1),
    vcMatched: j['vc_matched']?.toString(),
    candidates: [
      for (final c in (j['candidates'] as List? ?? const []))
        BankCandidate.fromJson((c as Map).cast<String, dynamic>()),
    ],
  );

  final int nrLine;
  final String vcFitid;
  final DateTime dtPosted;
  final double vlAmount;
  final String? vcMemo;
  final int itStatus;
  final String? vcMatched;
  final List<BankCandidate> candidates;

  bool get isPending => itStatus == BankLineStatus.pending;
  bool get isMatched => itStatus == BankLineStatus.matched;
}

class BankList {
  const BankList({
    this.lines = const [],
    this.unmatched = const [],
    this.vlBank = 0,
    this.qtPending = 0,
    this.qtMatched = 0,
    this.qtIgnored = 0,
    this.vlSystemUnmatched = 0,
  });

  factory BankList.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map? ?? const {}).cast<String, dynamic>();
    return BankList(
      lines: [
        for (final l in (j['lines'] as List? ?? const []))
          BankLine.fromJson((l as Map).cast<String, dynamic>()),
      ],
      unmatched: [
        for (final u in (j['unmatched'] as List? ?? const []))
          BankCandidate.fromJson((u as Map).cast<String, dynamic>()),
      ],
      vlBank: _double(t['vl_bank']),
      qtPending: _int(t['qt_pending'] ?? 0),
      qtMatched: _int(t['qt_matched'] ?? 0),
      qtIgnored: _int(t['qt_ignored'] ?? 0),
      vlSystemUnmatched: _double(t['vl_system_unmatched']),
    );
  }

  final List<BankLine> lines;
  final List<BankCandidate> unmatched;
  final double vlBank;
  final int qtPending;
  final int qtMatched;
  final int qtIgnored;
  final double vlSystemUnmatched;
}

/// Transacao lida do arquivo OFX (pronta para ad.fin_bank_import).
class OfxTransaction {
  const OfxTransaction({
    required this.fitid,
    required this.posted,
    required this.amount,
    this.memo,
  });

  final String fitid;
  final DateTime posted;
  final double amount;
  final String? memo;

  Map<String, dynamic> toJson() => {
    'vc_fitid': fitid,
    'dt_posted': Dates.toIso(posted),
    'vl_amount': amount,
    'vc_memo': memo,
  };
}

/// Leitor de OFX (1.x SGML e 2.x XML): pega os blocos STMTTRN com FITID,
/// DTPOSTED, TRNAMT e MEMO/NAME. Tags sem fechamento (SGML) e com fechamento
/// (XML) funcionam; valor aceita virgula ou ponto.
abstract final class OfxParser {
  static List<OfxTransaction> parse(String text) {
    final out = <OfxTransaction>[];
    final block = RegExp(
      r'<STMTTRN>(.*?)(</STMTTRN>|(?=<STMTTRN>)|(?=</BANKTRANLIST>))',
      caseSensitive: false,
      dotAll: true,
    );
    for (final m in block.allMatches(text)) {
      final b = m.group(1) ?? '';
      String? tag(String name) {
        final r = RegExp(
          '<$name>([^<\\r\\n]*)',
          caseSensitive: false,
        ).firstMatch(b);
        final v = r?.group(1)?.trim();
        return v == null || v.isEmpty ? null : v;
      }

      final fitid = tag('FITID');
      final posted = _ofxDate(tag('DTPOSTED'));
      final amount = double.tryParse(
        (tag('TRNAMT') ?? '').replaceAll(',', '.'),
      );
      if (fitid == null || posted == null || amount == null || amount == 0) {
        continue;
      }
      final memo = [
        tag('NAME'),
        tag('MEMO'),
      ].whereType<String>().toSet().join(' · ');
      out.add(
        OfxTransaction(
          fitid: fitid,
          posted: posted,
          amount: amount,
          memo: memo.isEmpty ? null : _unescape(memo),
        ),
      );
    }
    return out;
  }

  /// `20261201` ou `20261201120000[-3:BRT]` -> data.
  static DateTime? _ofxDate(String? v) {
    if (v == null || v.length < 8) return null;
    final y = int.tryParse(v.substring(0, 4));
    final m = int.tryParse(v.substring(4, 6));
    final d = int.tryParse(v.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}

int _int(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic v) {
  final p = DateTime.tryParse(v?.toString() ?? '');
  return p == null ? null : DateTime(p.year, p.month, p.day);
}
