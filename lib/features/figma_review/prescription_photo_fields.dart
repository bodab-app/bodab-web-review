/// Copies literal, same-line label/value pairs into the editable draft for ONE
/// medicine. Do not infer directions from tables, nearby numbers or prose.
class PrescriptionPhotoFields {
  const PrescriptionPhotoFields(
      {this.name = '', this.frequency = '', this.period = ''});

  final String name;
  final String frequency;
  final String period;

  static const _name = r'(?:약\s*이\s*름|약\s*품\s*명|의\s*약\s*품\s*명|약\s*명)';
  static const _frequency =
      r'(?:(?:1\s*일\s*)?(?:복\s*용|투\s*약|투\s*여)\s*횟\s*수|하루에\s*먹는\s*횟수)';
  static const _period =
      r'(?:(?:총\s*)?(?:투\s*약|투\s*여|복\s*용)\s*(?:일\s*수|기\s*간)|먹는\s*기간)';
  static final _line =
      RegExp('^($_name|$_frequency|$_period)' r'(?:\s*[:：]\s*|\s+)(.+)$');
  static final _looksLikeLabel =
      RegExp('($_name|$_frequency|$_period)' r'(?:\s*[:：]|\s+)');
  static final _nameLabel = RegExp('^$_name' r'$');
  static final _frequencyLabel = RegExp('^$_frequency' r'$');
  static final _frequencyValue =
      RegExp(r'^(?:(?:하루|1\s*일)\s*)?[1-9][0-9]?\s*(?:회|번)$');
  static final _periodValue =
      RegExp(r'^[1-9][0-9]{0,3}\s*(?:일(?:간)?|주(?:간|일)?|개월)$');

  static PrescriptionPhotoFields parse(String text) {
    final names = <String>[];
    final frequencies = <String>[];
    final periods = <String>[];
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final match = _line.firstMatch(line.trim());
      if (match == null) continue;
      final label = match.group(1)!;
      final value = match.group(2)!.trim();
      if (_looksLikeLabel.hasMatch(value)) {
        return const PrescriptionPhotoFields();
      }
      if (_nameLabel.hasMatch(label)) {
        names.add(value);
      } else if (_frequencyLabel.hasMatch(label)) {
        frequencies.add(value);
      } else {
        periods.add(value);
      }
    }
    if (names.length != 1 ||
        names.single.length > 80 ||
        !RegExp(r'[가-힣A-Za-z]').hasMatch(names.single) ||
        RegExp(r'[,/:：;|•+<>{}=]|\s(?:및|또는|외)\s|\d+\s*(회|일|주|개월|번)(?:\s|$)')
            .hasMatch(names.single)) {
      return const PrescriptionPhotoFields();
    }
    return PrescriptionPhotoFields(
      name: names.single,
      frequency: frequencies.length == 1 &&
              _frequencyValue.hasMatch(frequencies.single)
          ? frequencies.single
          : '',
      period: periods.length == 1 && _periodValue.hasMatch(periods.single)
          ? periods.single
          : '',
    );
  }
}
