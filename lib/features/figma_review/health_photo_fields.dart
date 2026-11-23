/// An editable transcription of one explicit label/value pair, not an
/// interpretation of the person's health. A unit printed in the heading stays
/// in the heading and a unit printed with the value stays with the value.
class HealthPhotoField {
  HealthPhotoField(this.label, this.value);
  final String label;
  String value;
  bool included = true;
}

final _row = RegExp(
  r'^((?:측\s*정|검\s*사|기\s*록)\s*일(?:\s*자)?|혈\s*압|맥\s*박(?:\s*수)?|심\s*박\s*수|체\s*중|몸\s*무\s*게|(?:(?:공\s*복|식\s*후)\s*)?혈\s*당)'
  r'(?:\s*[(（]([^()（）]{1,15})[)）])?(?:\s*[:：]\s*|\s+)(.+)$',
);

class _Quantity {
  _Quantity(String number, String unit)
      : numberOnly = RegExp('^(?:$number)' r'$'),
        unitOnly = RegExp('^(?:$unit)' r'$', caseSensitive: false),
        together = RegExp('^(?:$number)' r'\s*' '(?:$unit)' r'$',
            caseSensitive: false);
  final RegExp numberOnly, unitOnly, together;
}

final _pressure = _Quantity(r'\d{1,3}\s*/\s*\d{1,3}', r'mm\s*Hg|㎜\s*Hg');
final _pulse = _Quantity(r'\d{1,3}', r'bpm|회\s*/\s*분|회\s*/\s*min');
final _weight = _Quantity(r'\d{1,3}(?:\.\d{1,3})?', r'kg|㎏|lb|lbs');
final _glucose =
    _Quantity(r'\d{1,3}(?:\.\d{1,2})?', r'mg\s*/\s*dL|mmol\s*/\s*L|㎎\s*/\s*㎗');

bool _validDate(String value) {
  final iso = RegExp(r'^(\d{4})([-./])\s*(\d{1,2})\s*\2\s*(\d{1,2})\.?$')
      .firstMatch(value);
  final korean = RegExp(r'^(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일$')
      .firstMatch(value);
  if (iso == null && korean == null) return false;
  final y = int.parse((iso ?? korean)!.group(1)!);
  final month = int.parse(iso?.group(3) ?? korean!.group(2)!);
  final day = int.parse(iso?.group(4) ?? korean!.group(3)!);
  final date = DateTime(y, month, day);
  return date.year == y && date.month == month && date.day == day;
}

List<HealthPhotoField> parseHealthPhotoFields(String text) {
  final fields = <HealthPhotoField>[];
  final seen = <String>{};
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    final match = _row.firstMatch(line.trim());
    if (match == null) continue;
    final label = match.group(1)!.trim();
    final compact = label.replaceAll(RegExp(r'\s+'), '');
    final printedUnit = match.group(2)?.trim();
    final value = match.group(3)!.trim();
    final quantity = switch (compact) {
      '혈압' => _pressure,
      '맥박' || '맥박수' || '심박수' => _pulse,
      '체중' || '몸무게' => _weight,
      '혈당' || '공복혈당' || '식후혈당' => _glucose,
      _ => null,
    };
    // A repeated measurement can be another date or person. The original
    // transcription is still available for manual review instead of merging rows.
    final key = quantity == null
        ? 'date'
        : quantity == _pulse
            ? 'pulse'
            : quantity == _weight
                ? 'weight'
                : compact;
    if (!seen.add(key)) return [];
    final valid = quantity == null
        ? printedUnit == null && _validDate(value)
        : printedUnit == null
            ? quantity.together.hasMatch(value)
            : quantity.unitOnly.hasMatch(printedUnit) &&
                quantity.numberOnly.hasMatch(value);
    if (valid) {
      fields.add(HealthPhotoField(
          printedUnit == null ? compact : '$compact ($printedUnit)', value));
    }
  }
  return fields;
}
