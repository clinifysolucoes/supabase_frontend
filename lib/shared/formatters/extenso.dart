/// Valor por extenso em portugues (recibos): `1250.5` ->
/// `mil, duzentos e cinquenta reais e cinquenta centavos`.
abstract final class Extenso {
  static const _units = [
    '', 'um', 'dois', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', //
    'nove', 'dez', 'onze', 'doze', 'treze', 'quatorze', 'quinze', //
    'dezesseis', 'dezessete', 'dezoito', 'dezenove',
  ];
  static const _tens = [
    '', '', 'vinte', 'trinta', 'quarenta', 'cinquenta', 'sessenta', //
    'setenta', 'oitenta', 'noventa',
  ];
  static const _hundreds = [
    '', 'cento', 'duzentos', 'trezentos', 'quatrocentos', 'quinhentos', //
    'seiscentos', 'setecentos', 'oitocentos', 'novecentos',
  ];

  /// 0..999 por extenso.
  static String _upTo999(int n) {
    if (n == 0) return '';
    if (n == 100) return 'cem';
    final parts = <String>[];
    final h = n ~/ 100;
    final rest = n % 100;
    if (h > 0) parts.add(_hundreds[h]);
    if (rest > 0) {
      if (rest < 20) {
        parts.add(_units[rest]);
      } else {
        final t = rest ~/ 10;
        final u = rest % 10;
        parts.add(u == 0 ? _tens[t] : '${_tens[t]} e ${_units[u]}');
      }
    }
    return parts.join(' e ');
  }

  /// Inteiro por extenso (ate 999 bilhoes).
  static String number(int n) {
    if (n == 0) return 'zero';
    const scales = [
      ('', ''),
      ('mil', 'mil'),
      ('milhão', 'milhões'),
      ('bilhão', 'bilhões'),
    ];
    final groups = <int>[];
    var v = n;
    while (v > 0) {
      groups.add(v % 1000);
      v ~/= 1000;
    }
    final words = <String>[];
    for (var i = groups.length - 1; i >= 0; i--) {
      final g = groups[i];
      if (g == 0) continue;
      final (one, many) = scales[i];
      final text = i == 1 && g == 1 ? 'mil' : _upTo999(g);
      if (i == 0) {
        words.add(text);
      } else if (i == 1) {
        words.add(g == 1 ? 'mil' : '$text mil');
      } else {
        words.add('$text ${g == 1 ? one : many}');
      }
    }
    // "e" antes do ultimo grupo quando ele e menor que 100 ou centena exata
    if (words.length > 1) {
      final last = groups.first;
      if (last > 0 && (last < 100 || last % 100 == 0)) {
        final tail = words.removeLast();
        return '${words.join(', ')} e $tail';
      }
    }
    return words.join(', ');
  }

  /// Valor em reais por extenso.
  static String money(num value) {
    final cents = (value * 100).round().abs();
    final reais = cents ~/ 100;
    final c = cents % 100;
    final parts = <String>[];
    if (reais > 0) {
      final millionsExact = reais >= 1000000 && reais % 1000000 == 0;
      parts.add(
        '${number(reais)}${millionsExact ? ' de' : ''} '
        '${reais == 1 ? 'real' : 'reais'}',
      );
    }
    if (c > 0) {
      parts.add('${number(c)} ${c == 1 ? 'centavo' : 'centavos'}');
    }
    if (parts.isEmpty) return 'zero real';
    return parts.join(' e ');
  }
}
