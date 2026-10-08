/// Platform-agnostic equalizer engine contract.
///
/// UI + state never talk to platform channels directly — only to this.
/// Native engines (Android Equalizer API, Linux PipeWire, later
/// macOS AudioUnit / Windows APO) implement it.
abstract class EqEngine {
  /// Overall gain range every engine must support (dB).
  static const double minPreampDb = -24;
  static const double maxPreampDb = 12;

  /// Center frequencies currently exposed by the engine.
  List<double> get frequenciesHz;

  Future<void> init();
  Future<void> setEnabled(bool enabled);

  /// Gain in dB, expected range [-12, +12].
  Future<void> setBandGain(int bandIndex, double gainDb);

  /// Overall preamp gain in dB, range [minPreampDb, maxPreampDb].
  /// Prevents digital clipping on boosted presets (AutoEQ relies on this).
  Future<void> setPreamp(double preampDb);

  Future<void> dispose();
}
