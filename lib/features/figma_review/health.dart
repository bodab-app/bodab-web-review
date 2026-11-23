import 'dart:async';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import 'core.dart';
import 'photo_reader_stub.dart'
    if (dart.library.js_interop) 'photo_reader_web.dart' as photo_reader;
import 'prescription_photo_fields.dart';
import 'health_photo_fields.dart';
import 'local_pdf_preview_stub.dart'
    if (dart.library.js_interop) 'local_pdf_preview_web.dart';
import 'daily.dart' show openSavedCheckin, startTodayCheckin;

String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';

class MedicationPlan {
  const MedicationPlan(this.id, this.name, this.frequency, this.period);
  final String id, name, frequency, period;
  Map<String, Object?> toJson() =>
      {'name': name, 'frequency': frequency, 'period': period};
  static MedicationPlan? read(String id, Object? raw) {
    if (id.isEmpty ||
        raw is! Map ||
        raw['name'] is! String ||
        (raw['name'] as String).trim().isEmpty) {
      return null;
    }
    return MedicationPlan(
        id,
        raw['name'] as String,
        raw['frequency'] is String ? raw['frequency'] as String : '',
        raw['period'] is String ? raw['period'] as String : '');
  }
}

class HealthModel implements ReviewSavedModel {
  HealthModel(
      {Future<String> Function(Uint8List)? photoReader,
      this.readingTimeout = const Duration(seconds: 90)})
      : _photoReader = photoReader ?? photo_reader.recognizePhoto,
        canReadPhotos =
            photoReader != null || photo_reader.supportsPhotoReading;
  final Future<String> Function(Uint8List) _photoReader;
  final Duration readingTimeout;
  final bool canReadPhotos;
  bool readingPhoto = false;
  final measuredFields = <HealthPhotoField>[];
  String recognizedText = '',
      reviewedText = '',
      readingError = '',
      enteredPeriod = '';
  bool includePeriod = true, includeTranscript = false;
  int _readEpoch = 0;
  bool get isPrescriptionUpload => uploadReturnTo == 'prescription';

  void cancelPhotoReading() {
    _readEpoch++;
    readingPhoto = false;
  }

  Future<void> readPhoto() async {
    final bytes = previewBytes;
    if (bytes == null ||
        !canReadPhotos ||
        readingPhoto ||
        recognizedText.isNotEmpty) {
      return;
    }
    final epoch = ++_readEpoch;
    readingPhoto = true;
    readingError = '';
    try {
      final text = (await _photoReader(bytes).timeout(readingTimeout))
          .replaceAll('\u0000', '')
          .trim();
      if (epoch != _readEpoch) return;
      if (!RegExp(r'[가-힣A-Za-z0-9].*[가-힣A-Za-z0-9]', dotAll: true)
          .hasMatch(text)) {
        readingError = '읽을 수 있는 글자를 찾지 못했어요. 밝고 선명한 사진을 다시 고르거나 직접 입력해 주세요.';
        return;
      }
      if (text.length > 20000) {
        readingError = '사진의 글자가 너무 많아요. 필요한 부분을 나눠 촬영하거나 직접 입력해 주세요.';
        return;
      }
      recognizedText = text;
      if (isPrescriptionUpload) {
        final fields = PrescriptionPhotoFields.parse(text);
        enteredName = fields.name;
        enteredFrequency = fields.frequency;
        enteredPeriod = fields.period;
      } else {
        reviewedText = text;
        measuredFields
          ..clear()
          ..addAll(parseHealthPhotoFields(text));
      }
    } on TimeoutException {
      if (epoch == _readEpoch) {
        readingError = '글자를 읽는 데 시간이 오래 걸려요. 다시 시도하거나 직접 입력해 주세요.';
      }
    } catch (_) {
      if (epoch == _readEpoch) {
        readingError = '사진에서 글자를 읽지 못했어요. 다시 시도하거나 원문을 보고 입력해 주세요.';
      }
    } finally {
      if (epoch == _readEpoch) readingPhoto = false;
    }
  }

  final medications = <String, MedicationPlan>{};
  String? selectedMedication, editingMedication, lastDoseId;
  String medication = '', frequency = '', period = '';
  String prescriptionSourceName = '';
  Uint8List? prescriptionSourceBytes;
  Uint8List? _prescriptionPdfBytes;
  final _pdf = LocalPdfPreview();

  MedicationPlan? get selected => medications[selectedMedication];
  @override
  String get storageKey => 'health';
  @override
  Map<String, Object?> exportSavedState() =>
      {for (final p in medications.values) 'med:${p.id}': p.toJson()};
  @override
  void restoreSavedState(Map<String, Object?> data) {
    medications.clear();
    for (final item in data.entries.where((e) => e.key.startsWith('med:'))) {
      final plan = MedicationPlan.read(item.key.substring(4), item.value);
      if (plan != null) medications[plan.id] = plan;
    }
  }

  void startPrescriptionReview([MedicationPlan? p]) {
    editingMedication = p?.id;
    medication = p?.name ?? '';
    frequency = p?.frequency ?? '';
    period = p?.period ?? '';
    prescriptionSourceName = '';
    prescriptionSourceBytes = null;
    _prescriptionPdfBytes = null;
    _pdf.clear();
  }

  bool commitPrescription() {
    if (medication.trim().isEmpty ||
        (editingMedication != null &&
            !medications.containsKey(editingMedication))) {
      return false;
    }
    final id = editingMedication ?? _newId();
    medications[id] =
        MedicationPlan(id, medication.trim(), frequency.trim(), period.trim());
    selectedMedication = id;
    startPrescriptionReview();
    return true;
  }

  String activity = '가볍게 걷기';
  bool afterActivity = false;
  String recordFilter = '전체';
  String fileName = '';
  String enteredName = '';
  String enteredFrequency = '';
  bool includeName = true;
  bool includeFrequency = true;
  Uint8List? previewBytes;
  Uint8List? _pdfBytes;

  bool hasPdf({bool prescription = false}) =>
      (prescription ? _prescriptionPdfBytes : _pdfBytes) != null;
  bool openPdf({bool prescription = false}) {
    final bytes = prescription ? _prescriptionPdfBytes : _pdfBytes;
    return bytes != null && _pdf.open(bytes);
  }

  String uploadError = '';
  String uploadReturnTo = 'records';
  int pickEpoch = 0;

  bool get hasEntry =>
      (includeName && enteredName.trim().isNotEmpty) ||
      (includeFrequency && enteredFrequency.trim().isNotEmpty) ||
      (isPrescriptionUpload &&
          includePeriod &&
          enteredPeriod.trim().isNotEmpty) ||
      (!isPrescriptionUpload &&
          measuredFields.any((f) => f.included && f.value.trim().isNotEmpty)) ||
      (!isPrescriptionUpload &&
          includeTranscript &&
          reviewedText.trim().isNotEmpty);

  void clearUpload() {
    ++pickEpoch;
    cancelPhotoReading();
    recognizedText = '';
    measuredFields.clear();
    reviewedText = '';
    readingError = '';
    enteredPeriod = '';
    includePeriod = true;
    includeTranscript = false;
    fileName = '';
    enteredName = '';
    enteredFrequency = '';
    includeName = true;
    includeFrequency = true;
    previewBytes = null;
    _pdfBytes = null;
    _pdf.clear();
    uploadError = '';
  }

  Future<void> loadFile(XFile selected) async {
    final size = await selected.length();
    final ext = selected.name.split('.').last.toLowerCase();
    const images = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    if (size <= 0 ||
        size > 12 * 1024 * 1024 ||
        (ext != 'pdf' && !images.contains(ext))) {
      throw const FormatException('12MB 이하의 PDF 또는 사진 파일을 선택해 주세요.');
    }
    final header = await selected
        .openRead(0, size < 12 ? size : 12)
        .fold<List<int>>(<int>[], (all, part) => all..addAll(part));
    bool starts(List<int> signature, [int offset = 0]) =>
        header.length >= offset + signature.length &&
        signature.indexed
            .every((entry) => header[offset + entry.$1] == entry.$2);
    final valid = switch (ext) {
      'pdf' => starts('%PDF-'.codeUnits),
      'png' => starts([137, 80, 78, 71, 13, 10, 26, 10]),
      'jpg' || 'jpeg' => starts([255, 216, 255]),
      'webp' => starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8),
      'heic' || 'heif' => starts('ftyp'.codeUnits, 4),
      _ => false,
    };
    if (!valid) {
      throw const FormatException('선택한 자료의 형식을 확인할 수 없어요.');
    }
    final bytes = images.contains(ext) || LocalPdfPreview.supported
        ? await selected.readAsBytes()
        : null;
    if (bytes != null && (bytes.isEmpty || bytes.length > 12 * 1024 * 1024)) {
      throw const FormatException('파일을 읽을 수 없어요. 다른 파일을 골라 주세요.');
    }
    final name = selected.name.split(RegExp(r'[/\\]')).last;
    clearUpload();
    fileName = name;
    enteredName = '';
    enteredFrequency = '';
    includeName = true;
    includeFrequency = true;
    _pdf.clear();
    _pdfBytes = ext == 'pdf' ? bytes : null;
    previewBytes = ext == 'pdf' ? null : bytes;
    uploadError = '';
  }
}

void openAllHealthRecords(ReviewController c) {
  c.model(HealthModel.new).recordFilter = '전체';
  c.go('records');
}

void openHealthUpload(ReviewController c, {String returnTo = 'records'}) {
  final m = c.model(HealthModel.new);
  c.update(() {
    m.clearUpload();
    m.uploadReturnTo = returnTo;
  });
  c.go('upload');
}

Widget buildHealthScreen(String key, ReviewController c) {
  final m = c.model(() => HealthModel());
  return Builder(builder: (context) => _HealthViews(context, c, m).page(key));
}

class _HealthViews {
  _HealthViews(this.context, this.c, this.m);
  final BuildContext context;
  final ReviewController c;
  final HealthModel m;

  void go(String key) => c.go(key);

  Widget badge(String text, {bool warm = false}) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(text,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: warm ? const Color(0xff805539) : reviewGreen)),
        ),
      );

  Widget facts(List<(String, String)> rows) => ReviewCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: Caption(row.$1)),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: SectionLabel(row.$2)),
            ]),
          ],
        ]),
      );

  void beginUpload(String returnTo) => openHealthUpload(c, returnTo: returnTo);

  Future<void> choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      sheetAnimationStyle: AnimationStyle.noAnimation,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('사진에서 선택'),
            onTap: () => Navigator.pop(sheet, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('카메라로 촬영'),
            onTap: () => Navigator.pop(sheet, ImageSource.camera),
          ),
          ListTile(title: const Text('취소'), onTap: () => Navigator.pop(sheet)),
        ]),
      ),
    );
    if (source != null && context.mounted) await pick(source: source);
  }

  Future<void> pick({ImageSource? source}) async {
    final route = c.current;
    final epoch = ++m.pickEpoch;
    bool stillHere() => c.current == route && m.pickEpoch == epoch;
    const formats = XTypeGroup(
      label: '건강 자료',
      extensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
      mimeTypes: [
        'application/pdf',
        'image/png',
        'image/jpeg',
        'image/webp',
        'image/heic',
        'image/heif'
      ],
      uniformTypeIdentifiers: ['com.adobe.pdf', 'public.image'],
      webWildCards: ['application/pdf', 'image/*'],
    );
    try {
      final file = source == null
          ? await openFile(acceptedTypeGroups: const [formats])
          : await ImagePicker().pickImage(source: source);
      if (file == null || !stillHere()) return;
      // Read into a temporary in-memory model. A cancelled or superseded choice
      // cannot overwrite a newer selection after the file read completes.
      final selection = HealthModel();
      await selection.loadFile(file);
      if (!stillHere()) return;
      c.update(() {
        m.clearUpload();
        m.fileName = selection.fileName;
        m.previewBytes = selection.previewBytes;
        m._pdfBytes = selection._pdfBytes;
      });
      go('upload_loading');
    } on PlatformException catch (e) {
      if (!stillHere()) return;
      if (RegExp('denied|restricted|permission', caseSensitive: false)
          .hasMatch(e.code)) {
        go('permission');
      } else {
        uploadFailed('파일을 열 수 없어요. 다시 선택해 주세요.');
      }
    } on FormatException catch (e) {
      if (stillHere()) uploadFailed(e.message);
    } catch (_) {
      if (stillHere()) uploadFailed('선택한 파일을 읽을 수 없어요.');
    }
  }

  void uploadFailed(String reason) {
    c.update(() => m.uploadError = reason);
    go('upload_error');
  }

  void cancelUpload() {
    final target = m.uploadReturnTo;
    c.update(m.clearUpload);
    go(target);
  }

  Future<void> showSource({bool prescription = false}) async {
    // Open synchronously within the user's tap (in particular, on iOS Safari).
    if (m.openPdf(prescription: prescription)) return;
    final bytes = prescription ? m.prescriptionSourceBytes : m.previewBytes;
    final name = prescription ? m.prescriptionSourceName : m.fileName;
    await showDialog<void>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (d) => AlertDialog(
              title: Text(name.isEmpty ? '자료 원문' : name),
              content: bytes == null
                  ? Text(m.hasPdf(prescription: prescription)
                      ? '브라우저에서 PDF를 열지 못했어요. 새 탭 열기를 허용하거나 기기의 파일 앱에서 원본을 열어 주세요.'
                      : '기기의 파일 앱에서 PDF 원본을 열고 항목을 확인해 주세요.')
                  : SingleChildScrollView(
                      child: Image.memory(bytes,
                          errorBuilder: (_, __, ___) => const Text(
                              '이 형식은 미리보기를 지원하지 않아요. 원본을 보며 직접 입력해 주세요.'))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d), child: const Text('닫기'))
              ],
            ));
  }

  Future<void> editRecord(
      String id, String title, String detail, String category) async {
    var value = detail;
    final result = await showDialog<String>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (dialog) => AlertDialog(
                title: Text(title),
                content: TextFormField(
                    initialValue: detail,
                    maxLength:
                        max(detail.length, category == '등록 자료' ? 20000 : 500),
                    onChanged: (v) => value = v,
                    decoration: const InputDecoration(labelText: '기록 내용')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, 'remove'),
                      child: const Text('기록 삭제')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('취소')),
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, 'save'),
                      child: const Text('저장')),
                ]));
    if (!context.mounted || !c.records.any((r) => r.id == id)) return;
    if (result == 'remove' &&
        await confirmDelete('이 기록을 삭제할까요?') &&
        context.mounted) {
      m.recordFilter = '전체';
      c.removeRecord(id);
    }
    if (result == 'save' && value.trim().isNotEmpty) {
      c.addRecord(title, value.trim(), category: category, id: id);
    }
  }

  void saveSource() {
    if (!m.hasEntry) return;
    final target = m.uploadReturnTo;
    if (m.isPrescriptionUpload) {
      c.update(() {
        m.prescriptionSourceName = m.fileName;
        m.prescriptionSourceBytes = m.previewBytes;
        m._prescriptionPdfBytes = m._pdfBytes;
        m.medication = m.includeName ? m.enteredName.trim() : '';
        m.frequency = m.includeFrequency ? m.enteredFrequency.trim() : '';
        m.period = m.includePeriod ? m.enteredPeriod.trim() : '';
      });
    } else {
      final detail = [
        if (m.includeName && m.enteredName.trim().isNotEmpty)
          m.enteredName.trim(),
        if (m.includeFrequency && m.enteredFrequency.trim().isNotEmpty)
          m.enteredFrequency.trim(),
        for (final field in m.measuredFields)
          if (field.included && field.value.trim().isNotEmpty)
            '${field.label}: ${field.value.trim()}',
        if (m.includeTranscript && m.reviewedText.trim().isNotEmpty)
          m.reviewedText.trim(),
      ].join(' · ');
      c.addRecord(m.fileName, detail, category: '등록 자료');
    }
    c.update(() {
      m.recordFilter = '전체';
      m.clearUpload();
    });
    go(target == 'prescription' ? 'prescription' : 'records');
  }

  Future<void> readPhoto() async {
    final pending = m.readPhoto();
    c.update(() {});
    await pending;
    if (!c.isDisposed) c.update(() {});
  }

  void reviewSelection() {
    m.cancelPhotoReading();
    go('review');
  }

  Widget reviewField(String label, String value, bool include,
          void Function(String) change, void Function(bool) toggle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (include)
            ReviewField(
                label: label,
                value: value,
                onChanged: change,
                hint: '원문을 보고 입력하세요'),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('$label 포함'),
            value: include,
            onChanged: (v) => c.update(() => toggle(v ?? true)),
          ),
        ],
      );

  int doseCountToday(MedicationPlan p) => c.records
      .where((r) =>
          r.id.startsWith('dose:${p.id}:') &&
          DateUtils.isSameDay(r.createdAt.toLocal(), DateTime.now()))
      .length;
  Future<bool> confirmDelete(String title, {String? detail}) async =>
      await showDialog<bool>(
          context: context,
          animationStyle: AnimationStyle.noAnimation,
          builder: (d) => AlertDialog(
                  title: Text(title),
                  content: detail == null ? null : Text(detail),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('취소')),
                    TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('삭제')),
                  ])) ??
      false;

  Widget page(String key) {
    if ((key == 'review' || key == 'upload_loading') && m.fileName.isEmpty) {
      return page('upload');
    }
    switch (key) {
      case 'prescription':
        return ReviewPage(
            title: m.editingMedication == null ? '약 등록' : '등록한 약 수정',
            backTo: 'medications',
            actions: [
              ReviewButton(
                  '이 내용으로 저장하기',
                  m.medication.trim().isEmpty
                      ? null
                      : () {
                          if (m.commitPrescription()) {
                            go('medications');
                          }
                        }),
              ReviewButton('취소하기', () => go('medications'), secondary: true),
              if (m.editingMedication != null)
                ReviewButton('등록한 약 삭제', () async {
                  final id = m.editingMedication;
                  if (await confirmDelete('등록한 약을 삭제할까요?',
                          detail: '이전에 남긴 복용 기록은 내 기록에 남아요.') &&
                      context.mounted) {
                    c.update(() => m.medications.remove(id));
                    go('medications');
                  }
                }, secondary: true),
            ],
            children: [
              const Lead('내가 복용하는 약'),
              const Caption('처방전 또는 약 봉투에서 확인한 정보를 입력해 주세요.'),
              ReviewField(
                  label: '약 이름',
                  value: m.medication,
                  onChanged: (v) => c.update(() => m.medication = v)),
              ReviewField(
                  label: '복용 횟수 (선택)',
                  value: m.frequency,
                  onChanged: (v) => m.frequency = v),
              ReviewField(
                  label: '먹는 기간 (선택)',
                  value: m.period,
                  onChanged: (v) => m.period = v),
              if (m.prescriptionSourceName.isNotEmpty)
                ReviewRow(
                    title: m.prescriptionSourceName,
                    detail: m.hasPdf(prescription: true)
                        ? 'PDF 원문 보기 · 새 탭'
                        : m.prescriptionSourceBytes == null
                            ? 'PDF 파일 정보'
                            : '원본 미리보기',
                    icon: 'document',
                    onTap: () => showSource(prescription: true)),
              ReviewButton('처방전 사진 또는 파일 선택', () => beginUpload('prescription'),
                  secondary: true),
            ]);
      case 'medications':
        return ReviewPage(title: '나의 복약', backTo: 'home', actions: [
          ReviewButton('약 등록하기', () {
            m.startPrescriptionReview();
            go('prescription');
          }),
          ReviewButton('오늘로 돌아가기', () => c.resetTo('home'), secondary: true),
        ], children: [
          const Lead('등록한 약'),
          if (m.medications.isEmpty) const Caption('아직 등록한 약이 없어요'),
          for (final p in m.medications.values)
            ReviewRow(
                title: p.name,
                detail: [
                  if (p.frequency.isNotEmpty) p.frequency,
                  '오늘 복용 기록 ${doseCountToday(p)}건'
                ].join(' · '),
                icon: 'pill',
                onTap: () {
                  m.selectedMedication = p.id;
                  go('med_detail');
                }),
        ]);
      case 'med_detail':
        final p = m.selected;
        if (p == null) return page('medications');
        return ReviewPage(title: '복약 내용 확인', backTo: 'medications', actions: [
          ReviewButton(doseCountToday(p) == 0 ? '복용했다고 기록하기' : '추가 복용 기록하기',
              () async {
            if (doseCountToday(p) > 0) {
              final ok = await showDialog<bool>(
                  context: context,
                  animationStyle: AnimationStyle.noAnimation,
                  builder: (dialog) => AlertDialog(
                          title: const Text('이번 복용을 추가로 기록할까요?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(dialog, false),
                                child: const Text('취소')),
                            TextButton(
                                onPressed: () => Navigator.pop(dialog, true),
                                child: const Text('기록하기')),
                          ]));
              if (ok != true || !context.mounted) return;
            }
            if (!m.medications.containsKey(p.id) || c.current != 'med_detail') {
              return;
            }
            final id = 'dose:${p.id}:${_newId()}';
            m.lastDoseId = id;
            c.addRecord('복용 기록', '${p.name} · 직접 남긴 기록',
                category: '복약', id: id);
            go('med_done');
          }),
          ReviewButton('등록 정보 수정', () {
            m.startPrescriptionReview(p);
            go('prescription');
          }, secondary: true),
          ReviewButton('복약 목록으로', () => go('medications'), secondary: true),
        ], children: [
          Lead(p.name),
          facts([
            ('복용 횟수', p.frequency.isEmpty ? '입력하지 않음' : p.frequency),
            ('등록 기간', p.period.isEmpty ? '입력하지 않음' : p.period),
            ('오늘 복용 기록', '${doseCountToday(p)}건')
          ]),
        ]);
      case 'med_done':
        final last = c.records.where((r) => r.id == m.lastDoseId).firstOrNull;
        if (last == null) return page('medications');
        return ReviewPage(title: '복약 기록', backTo: 'medications', actions: [
          ReviewButton('내 기록 확인하기', () => openAllHealthRecords(c)),
          ReviewButton('복약 목록으로', () => go('medications'), secondary: true),
        ], children: [
          const Lead('복용 기록을 남겼어요'),
          facts([('내용', last.detail), ('기록 일시', _moment(last.createdAt))])
        ]);
      case 'records':
        return recordList();
      case 'upload':
        return ReviewPage(
            title: '건강 자료 등록',
            backTo: m.uploadReturnTo,
            children: [
              const Lead('어떤 자료를\n가져올까요?',
                  detail: '파일을 고른 뒤 내용을 확인하고 기록에 넣어요.'),
              ReviewRow(
                  title: '사진 촬영·선택',
                  icon: 'upload',
                  detail: '기기에 있는 사진에서 가져오기',
                  onTap: choosePhoto),
              ReviewRow(
                  title: '파일에서 선택',
                  icon: 'document',
                  detail: '건강 관련 문서나 이미지',
                  onTap: pick),
              const Caption('원본 파일은 전송하거나 저장하지 않아요. 내용을 확인한 뒤 선택한 항목만 기록해요.'),
            ]);
      case 'upload_loading':
        final photo = m.previewBytes != null;
        final read = m.recognizedText.isNotEmpty;
        return ReviewPage(title: '건강 자료 등록', backTo: 'upload', actions: [
          if (photo && m.canReadPhotos && !read)
            ReviewButton(m.readingError.isEmpty ? '사진에서 글자 읽기' : '글자 읽기 다시 시도',
                m.readingPhoto ? null : readPhoto),
          ReviewButton(
              read
                  ? '읽은 내용 확인하기'
                  : photo && m.canReadPhotos
                      ? '직접 입력하기'
                      : '내용 입력하기',
              reviewSelection,
              secondary: photo && m.canReadPhotos && !read),
          ReviewButton('등록 취소하기', cancelUpload, secondary: true),
        ], children: [
          Lead(
              m.readingPhoto
                  ? '사진의 글자를 읽고 있어요'
                  : read
                      ? '글자를 읽었어요'
                      : '자료를 열었어요',
              detail: m.readingPhoto
                  ? '이 기기에서 사진을 처리하고 있어요.'
                  : read
                      ? '원본과 대조한 뒤 필요한 내용만 기록해요.'
                      : photo && m.canReadPhotos
                          ? '이 기기에서 사진 속 글자를 읽거나 직접 입력할 수 있어요.'
                          : '원문을 보며 필요한 내용을 직접 입력해 주세요.'),
          if (m.readingPhoto)
            const LinearProgressIndicator(semanticsLabel: '사진 글자 인식 중'),
          if (m.readingError.isNotEmpty) Caption(m.readingError),
          ReviewRow(
              title: m.fileName,
              detail: m.hasPdf()
                  ? 'PDF 원문 보기 · 새 탭'
                  : photo
                      ? '사진 원본 보기'
                      : '파일 정보',
              icon: 'document',
              onTap: showSource),
          const Caption('확인 전에는 내 기록에 반영되지 않아요.'),
        ]);
      case 'review':
        final read = m.recognizedText.isNotEmpty;
        return ReviewPage(title: '내 기록에 넣기 전에', backTo: 'upload', actions: [
          ReviewButton(m.isPrescriptionUpload ? '확인한 내용 적용하기' : '확인한 내용 저장하기',
              m.hasEntry ? saveSource : null),
          ReviewButton('등록 취소하기', cancelUpload, secondary: true),
        ], children: [
          const Caption('자료 선택  ·  내용 확인  ·  저장'),
          ReviewRow(
              title: m.fileName,
              detail: m.hasPdf()
                  ? 'PDF 원문 보기 · 새 탭'
                  : m.previewBytes == null
                      ? 'PDF 파일 정보'
                      : '원본 미리보기',
              onTap: showSource),
          if (read &&
              m.measuredFields.isNotEmpty &&
              !m.isPrescriptionUpload) ...[
            const SectionLabel('읽은 건강 항목'),
            const Caption('사진에 적힌 날짜와 수치, 단위를 대조하고 기록에 포함할 항목을 선택해 주세요.'),
            for (final field in m.measuredFields)
              reviewField(
                  field.label,
                  field.value,
                  field.included,
                  (v) => c.update(() => field.value = v),
                  (v) => field.included = v),
          ],
          if (read) ...[
            const SectionLabel('인식한 글자'),
            if (m.isPrescriptionUpload)
              ReviewCard(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: SingleChildScrollView(
                          child: SelectableText(m.recognizedText))))
            else ...[
              TextFormField(
                  key: ValueKey(m.pickEpoch),
                  initialValue: m.reviewedText,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 20000,
                  decoration: const InputDecoration(labelText: '확인할 내용'),
                  onChanged: (v) => c.update(() => m.reviewedText = v)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('확인한 글자를 기록에 포함'),
                  value: m.includeTranscript,
                  onChanged: (v) =>
                      c.update(() => m.includeTranscript = v ?? false)),
            ],
          ],
          SectionLabel(
              read && m.isPrescriptionUpload ? '약 정보 후보' : '직접 입력할 항목'),
          Caption(m.isPrescriptionUpload
              ? '사진에 이름·횟수·기간이 분명하게 적힌 한 가지 약을 확인해 주세요. 빈칸은 원문을 보고 직접 입력할 수 있어요.'
              : '원문과 다른 글자를 수정하고 기록할 항목만 선택해 주세요.'),
          reviewField(
              m.isPrescriptionUpload ? '약 이름' : '기록 항목',
              m.enteredName,
              m.includeName,
              (v) => c.update(() => m.enteredName = v),
              (v) => m.includeName = v),
          reviewField(
              m.isPrescriptionUpload ? '복용 횟수' : '메모',
              m.enteredFrequency,
              m.includeFrequency,
              (v) => c.update(() => m.enteredFrequency = v),
              (v) => m.includeFrequency = v),
          if (m.isPrescriptionUpload)
            reviewField(
                '먹는 기간',
                m.enteredPeriod,
                m.includePeriod,
                (v) => c.update(() => m.enteredPeriod = v),
                (v) => m.includePeriod = v),
        ]);
      case 'empty':
        return ReviewPage(title: '건강 자료 등록', backTo: 'records', actions: [
          ReviewButton('첫 자료 등록하기', () => beginUpload('records')),
          ReviewButton('몸 상태 남기기', () => startTodayCheckin(c), secondary: true)
        ], children: const [
          Lead('아직 기록이 없어요', detail: '건강 체크를 하거나 자료를 등록하면 여기에 모여요.')
        ]);
      case 'permission':
        return ReviewPage(title: '건강 자료 등록', backTo: 'upload', actions: [
          ReviewButton('권한 확인 후 다시 선택', choosePhoto),
          ReviewButton('파일로 등록하기', pick, secondary: true)
        ], children: [
          const Lead('사진 접근을 허용해 주세요',
              detail: '선택한 사진을 가져오려면 기기의 접근 권한이 필요해요.'),
          facts([('선택 가능', '필요한 사진만 허용'), ('다른 방법', '파일에서 직접 선택')])
        ]);
      case 'upload_error':
        return ReviewPage(title: '건강 자료 등록', backTo: 'upload', actions: [
          ReviewButton('다시 등록하기', () => go('upload')),
          ReviewButton('취소하기', cancelUpload, secondary: true)
        ], children: [
          Lead('자료를 등록하지 못했어요',
              detail:
                  m.uploadError.isEmpty ? '선택한 자료를 다시 올려 주세요.' : m.uploadError),
          facts([('등록 상태', '기록에 반영되지 않음'), ('다음 행동', '다시 시도 또는 취소')]),
        ]);
      case 'activities':
        return ReviewPage(
            title: '보답',
            tab: 'activities',
            branded: true,
            children: [
              const Lead('오늘은 가볍게', detail: '내 몸 상태에 맞춰 선택해요.'),
              ReviewCard(
                  tinted: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        badge('10분 · 가볍게'),
                        const SizedBox(height: 12),
                        const Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                SectionLabel('가볍게 걷기'),
                                SizedBox(height: 4),
                                Caption('내가 정한 속도로'),
                              ])),
                          SizedBox(width: 8),
                          ReviewIcon('activity', size: 34)
                        ]),
                        const SizedBox(height: 14),
                        ReviewButton('활동 살펴보기', () => startActivity('가볍게 걷기')),
                      ])),
              const SectionLabel('편안하게 움직여요'),
              ReviewRow(
                  title: '앉아서 몸 풀기',
                  icon: 'heart',
                  detail: '편안한 범위에서 천천히',
                  onTap: () => startActivity('앉아서 몸 풀기')),
              ReviewRow(
                  title: '지금 몸 상태 남기기',
                  icon: 'smile',
                  detail: '활동 전후의 상태 확인',
                  onTap: () {
                    c.update(() => m.afterActivity = false);
                    go('body_status');
                  }),
            ]);
      case 'activity_detail':
        return ReviewPage(title: m.activity, backTo: 'activities', actions: [
          ReviewButton('활동을 마쳤어요', () {
            c.update(() => m.afterActivity = true);
            go('body_status');
          }),
          ReviewButton('활동 목록으로', () => go('activities'), secondary: true)
        ], children: [
          Lead(m.activity == '가볍게 걷기'
              ? '편안한 속도로\n함께 걸어볼까요?'
              : '편안한 범위에서\n몸을 풀어볼까요?'),
          facts([
            ('오늘 목표', '10분'),
            ('활동 강도', '나에게 맞게 조절'),
            ('쉬어가기', '힘들면 언제든 잠깐')
          ]),
          const Caption('불편함이 느껴지면 멈추고 안전한 곳에서 쉬어 주세요.'),
        ]);
      case 'body_status':
        return ReviewPage(title: '활동 후 몸 상태', backTo: 'activities', actions: [
          ReviewButton('오늘로 돌아가기', () => c.resetTo('home'), secondary: true)
        ], children: [
          const Lead('활동 후 어떠세요?'),
          ReviewRow(
              title: '편안해요',
              icon: 'smile',
              detail: '오늘의 상태로 남기기',
              onTap: () => saveBodyStatus('편안해요')),
          ReviewRow(
              title: '쉬고 싶어요',
              icon: 'heart',
              detail: '느껴지는 상태를 남기기',
              onTap: () => saveBodyStatus('쉬고 싶어요')),
          if (c.records.where((r) => r.category == '활동').firstOrNull
              case final previous?)
            Caption(
                '최근 기록 · ${_moment(previous.createdAt)} · ${previous.detail}'),
          const Caption('몸이 불편하면 활동을 멈추고 쉬어 주세요. 증상이 지속되면 의료진에게 상담하세요.'),
        ]);
      default:
        throw ArgumentError.value(key, 'key', 'Unknown health review screen');
    }
  }

  void startActivity(String title) {
    c.update(() => m.activity = title);
    go('activity_detail');
  }

  void saveBodyStatus(String value) {
    c.addRecord(m.afterActivity ? '활동 후 몸 상태' : '몸 상태',
        m.afterActivity ? '${m.activity} · $value' : value,
        category: '활동');
    openAllHealthRecords(c);
  }

  String _moment(DateTime date) {
    final d = date.toLocal();
    return '${d.year}. ${d.month}. ${d.day}. ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  Map<String, List<ReviewRecord>> _byDay(Iterable<ReviewRecord> records) {
    DateTime dateOf(ReviewRecord r) =>
        r is ReviewHealthCheck ? r.day : r.createdAt.toLocal();
    final sorted = records.toList()
      ..sort((a, b) {
        final byDay = DateUtils.dateOnly(dateOf(b))
            .compareTo(DateUtils.dateOnly(dateOf(a)));
        return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
      });
    final groups = <String, List<ReviewRecord>>{};
    for (final r in sorted) {
      final d = dateOf(r);
      groups.putIfAbsent('${d.year}년 ${d.month}월 ${d.day}일', () => []).add(r);
    }
    return groups;
  }

  Widget recordList() {
    final selected = m.recordFilter;
    final visible = c.records.where((r) =>
        selected == '전체' ||
        (selected == '건강 체크'
            ? r is ReviewHealthCheck
            : r.category == selected));
    return ReviewPage(title: '보답', branded: true, tab: 'records', children: [
      const Lead('내 건강 기록', detail: '나의 하루와 자료를 한곳에'),
      Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            '전체',
            '건강 체크',
            '등록 자료',
            if (c.records.any((r) => r.category == '복약')) '복약',
            if (c.records.any((r) => r.category == '활동')) '활동'
          ]
              .map((v) => ChoiceChip(
                  label: Text(v),
                  selected: selected == v,
                  onSelected: (_) => c.update(() => m.recordFilter = v)))
              .toList()),
      if (visible.isEmpty)
        Caption(c.records.isEmpty ? '아직 기록이 없어요' : '이 종류의 기록이 없어요.'),
      if (visible.isEmpty && selected != '등록 자료')
        ReviewButton('몸 상태 남기기', () => startTodayCheckin(c), secondary: true),
      for (final group in _byDay(visible).entries) ...[
        SectionLabel(group.key),
        for (final record in group.value)
          ReviewRow(
              title: record is ReviewHealthCheck &&
                      !DateUtils.isSameDay(record.day, DateTime.now())
                  ? '건강 체크'
                  : record.title,
              detail: record.detail,
              onTap: () => record is ReviewHealthCheck
                  ? openSavedCheckin(c, record)
                  : editRecord(
                      record.id, record.title, record.detail, record.category)),
      ],
      ReviewButton('건강 자료 등록하기', () => beginUpload('records')),
    ]);
  }
}
