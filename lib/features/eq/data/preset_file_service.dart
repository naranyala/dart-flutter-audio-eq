import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'apo_preset.dart';

/// Import/export of presets as Equalizer APO `.txt` files.
///
/// Thin platform wrapper: picking via `file_picker`, sharing via
/// `share_plus` (+ `path_provider` temp dir). Parsing/serializing lives in
/// `apo_preset.dart` and is fully unit-tested; this class is intentionally
/// too boring to test (would need plugin mocks).
class PresetFileService {
  /// Pick an APO `.txt` file and parse it. Returns null on cancel.
  /// Throws [FormatException] on unparsable content.
  Future<ApoPreset?> importApoPreset() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final text = await file.xFile.readAsString();
    final name =
        file.name.replaceAll(RegExp(r'\.txt$', caseSensitive: false), '');
    return parseApoPreset(text, name: name.isEmpty ? 'Imported' : name);
  }

  /// Write current gains as APO `.txt` and open the system share sheet.
  Future<void> exportPreset({
    required String name,
    required List<double> bandFreqs,
    required List<double> gainsDb,
    double preampDb = 0,
  }) async {
    final text = ApoPreset(name: name, preampDb: preampDb)
        .toApoText(bandFreqs, gainsDb);
    final dir = await getTemporaryDirectory();
    final safeName = name.replaceAll(RegExp('[^\\w\\- ]+'), '').trim();
    final fileName = '${safeName.isEmpty ? 'eq-preset' : safeName}.txt';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(text);
    await SharePlus.instance.share(
      ShareParams(
        text: 'EQ preset: $name (Equalizer APO format)',
        subject: 'EQ preset: $name',
        files: [XFile(file.path, mimeType: 'text/plain')],
        fileNameOverrides: [fileName],
      ),
    );
    debugPrint('[PresetFileService] exported $name -> ${file.path}');
  }
}
