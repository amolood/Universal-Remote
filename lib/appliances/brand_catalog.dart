import 'ac_ir_encoder.dart';
import 'appliance.dart';
import 'device_ir_encoder.dart';

/// Market positioning of a brand — shown as a grouping hint in the picker.
enum BrandTier { premium, midRange, value }

/// Whether a brand can control a given appliance kind, and how.
///
/// IR control needs a real per-device code set; we ship generic protocols, so a
/// brand maps to the best generic IR encoder for that kind when its devices use
/// an IR remote ([irBrandId] non-null). Brands whose product in that kind has no
/// IR remote (most large kitchen/laundry appliances) are Wi-Fi/smart only:
/// [irBrandId] is null and only the Wi-Fi transport is offered.
class BrandKindSupport {
  /// The generic IR encoder id to use for this (brand, kind), or null when the
  /// device has no IR remote (Wi-Fi/smart control only).
  final String? irBrandId;

  const BrandKindSupport({this.irBrandId});

  bool get supportsIr => irBrandId != null;
}

/// A controllable brand and the appliance kinds it covers.
class Brand {
  final String id; // stable, persisted on the appliance
  final String name; // display name
  final BrandTier tier;

  /// Which kinds this brand makes that the app can control, and how each is
  /// controlled. A kind absent from the map isn't offered for this brand.
  final Map<ApplianceKind, BrandKindSupport> support;

  const Brand({
    required this.id,
    required this.name,
    required this.tier,
    required this.support,
  });

  bool covers(ApplianceKind kind) => support.containsKey(kind);
}

/// The best generic IR encoder id for an IR-capable [kind] (null for kinds that
/// have no key/state encoder, e.g. generic). Used to wire brands to encoders.
String? _genericIrFor(ApplianceKind kind) => switch (kind) {
      ApplianceKind.airConditioner => 'gree',
      ApplianceKind.fan => 'nec_fan',
      ApplianceKind.tv => 'nec_tv',
      ApplianceKind.light => 'nec_light',
      ApplianceKind.radio => 'nec_radio',
      ApplianceKind.dvd => 'nec_dvd',
      ApplianceKind.setTopBox => 'nec_stb',
      ApplianceKind.projector => 'nec_projector',
      ApplianceKind.soundbar => 'nec_soundbar',
      ApplianceKind.heater => 'nec_heater',
      ApplianceKind.generic => null,
    };

/// Shorthand: an IR-controlled kind (maps to the generic encoder for it).
BrandKindSupport _ir(ApplianceKind kind) =>
    BrandKindSupport(irBrandId: _genericIrFor(kind));

/// Shorthand: a Wi-Fi/smart-only kind (no IR remote on this device).
const BrandKindSupport _wifiOnly = BrandKindSupport(irBrandId: null);

/// Registry of supported brands and which kinds each can control.
///
/// IR-capable kinds (TV, AC, fan, audio, etc.) get a generic IR encoder; large
/// kitchen/laundry appliances are Wi-Fi/smart only ([_wifiOnly]). The codes are
/// generic — real per-brand accuracy isn't guaranteed; a brand can be promoted
/// to a dedicated encoder later by pointing its [BrandKindSupport.irBrandId] at
/// a new entry in [AcIrProtocols] / [DeviceIrProtocols].
class BrandCatalog {
  // Kinds whose devices are typically IR-remote controlled.
  static Map<ApplianceKind, BrandKindSupport> _irKinds(
          Iterable<ApplianceKind> kinds) =>
      {for (final k in kinds) k: _ir(k)};

  static const _irRemoteKinds = [
    ApplianceKind.tv,
    ApplianceKind.airConditioner,
    ApplianceKind.fan,
    ApplianceKind.dvd,
    ApplianceKind.soundbar,
    ApplianceKind.projector,
    ApplianceKind.radio,
    ApplianceKind.setTopBox,
    ApplianceKind.light,
    ApplianceKind.heater,
  ];

  static final List<Brand> all = [
    // --- Consumer-electronics + appliance giants: IR for AV/AC, Wi-Fi for the rest.
    _avAndAppliances('lg', 'LG', BrandTier.premium),
    _avAndAppliances('samsung', 'Samsung', BrandTier.premium),
    _avAndAppliances('panasonic', 'Panasonic', BrandTier.midRange),
    _avAndAppliances('sharp', 'Sharp', BrandTier.midRange),
    _avAndAppliances('toshiba', 'Toshiba', BrandTier.midRange),
    _avAndAppliances('hitachi', 'Hitachi', BrandTier.midRange),
    _avAndAppliances('philips', 'Philips', BrandTier.midRange),
    _avAndAppliances('hisense', 'Hisense', BrandTier.value),
    _avAndAppliances('tcl', 'TCL', BrandTier.value),
    _avAndAppliances('haier', 'Haier', BrandTier.value),
    _avAndAppliances('midea', 'Midea', BrandTier.value),
    _avAndAppliances('xiaomi', 'Xiaomi', BrandTier.value),
    _avAndAppliances('daewoo', 'Daewoo', BrandTier.value),

    // --- AC / climate + white goods, no AV line: IR for AC/fan/heater, Wi-Fi rest.
    _climateAndAppliances('gree', 'Gree', BrandTier.value),

    // --- White-goods / kitchen-laundry specialists. Some have IR ACs; large
    //     appliances are Wi-Fi/smart only.
    _whiteGoods('bosch', 'Bosch', BrandTier.premium, ac: false),
    _whiteGoods('siemens', 'Siemens', BrandTier.premium, ac: false),
    _whiteGoods('whirlpool', 'Whirlpool', BrandTier.midRange, ac: true),
    _whiteGoods('ge', 'GE Appliances', BrandTier.midRange, ac: true),
    _whiteGoods('electrolux', 'Electrolux', BrandTier.midRange, ac: true),
    _whiteGoods('frigidaire', 'Frigidaire', BrandTier.midRange, ac: true),
    _whiteGoods('beko', 'Beko', BrandTier.value, ac: true),
    _whiteGoods('arcelik', 'Arçelik', BrandTier.value, ac: true),
    _whiteGoods('candy', 'Candy', BrandTier.value, ac: false),
    _whiteGoods('hoover', 'Hoover', BrandTier.value, ac: false),
    _whiteGoods('indesit', 'Indesit', BrandTier.value, ac: false),
    _whiteGoods('hotpoint', 'Hotpoint', BrandTier.value, ac: false),
    _whiteGoods('zanussi', 'Zanussi', BrandTier.value, ac: false),
    _whiteGoods('aeg', 'AEG', BrandTier.premium, ac: false),
    _whiteGoods('gorenje', 'Gorenje', BrandTier.value, ac: false),
    _whiteGoods('smeg', 'Smeg', BrandTier.premium, ac: false),
    _whiteGoods('fisherpaykel', 'Fisher & Paykel', BrandTier.premium, ac: false),
    _whiteGoods('kitchenaid', 'KitchenAid', BrandTier.premium, ac: false),
    _whiteGoods('maytag', 'Maytag', BrandTier.midRange, ac: false),
    _whiteGoods('amana', 'Amana', BrandTier.value, ac: false),
    _whiteGoods('kenmore', 'Kenmore', BrandTier.midRange, ac: true),

    // --- Premium / luxury kitchen specialists — Wi-Fi/smart only, no IR remotes.
    _smartOnly('miele', 'Miele', BrandTier.premium),
    _smartOnly('liebherr', 'Liebherr', BrandTier.premium),
    _smartOnly('subzero', 'Sub-Zero', BrandTier.premium),
    _smartOnly('wolf', 'Wolf', BrandTier.premium),
    _smartOnly('viking', 'Viking', BrandTier.premium),
    _smartOnly('thermador', 'Thermador', BrandTier.premium),
    _smartOnly('jennair', 'JennAir', BrandTier.premium),
  ];

  /// AV-heavy brand: IR remotes across TV/AV/AC/etc., Wi-Fi for kitchen/laundry.
  static Brand _avAndAppliances(String id, String name, BrandTier tier) => Brand(
        id: id,
        name: name,
        tier: tier,
        support: _irKinds(_irRemoteKinds),
      );

  /// Climate-focused brand: IR for AC/fan/heater, Wi-Fi for white goods.
  static Brand _climateAndAppliances(String id, String name, BrandTier tier) =>
      Brand(
        id: id,
        name: name,
        tier: tier,
        support: {
          ApplianceKind.airConditioner: _ir(ApplianceKind.airConditioner),
          ApplianceKind.fan: _ir(ApplianceKind.fan),
          ApplianceKind.heater: _ir(ApplianceKind.heater),
        },
      );

  /// White-goods brand: optionally an IR AC line, everything else Wi-Fi/smart.
  static Brand _whiteGoods(String id, String name, BrandTier tier,
          {required bool ac}) =>
      Brand(
        id: id,
        name: name,
        tier: tier,
        support: {
          if (ac) ApplianceKind.airConditioner: _ir(ApplianceKind.airConditioner),
          // Large appliances control over Wi-Fi only.
          ApplianceKind.light: _wifiOnly,
          ApplianceKind.generic: _wifiOnly,
        },
      );

  /// Luxury kitchen brand: smart/Wi-Fi control only, no IR.
  static Brand _smartOnly(String id, String name, BrandTier tier) => Brand(
        id: id,
        name: name,
        tier: tier,
        support: {
          ApplianceKind.generic: _wifiOnly,
        },
      );

  static Brand? byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// All brands that make [kind], sorted premium→value then alphabetically.
  static List<Brand> forKind(ApplianceKind kind) {
    final list = all.where((b) => b.covers(kind)).toList();
    list.sort((a, b) {
      final t = a.tier.index.compareTo(b.tier.index);
      return t != 0 ? t : a.name.compareTo(b.name);
    });
    return list;
  }

  /// The support entry for a (brand, kind), or null if the brand doesn't cover
  /// the kind.
  static BrandKindSupport? supportFor(String brandId, ApplianceKind kind) =>
      byId(brandId)?.support[kind];

  /// Whether this (brand, kind) can be controlled over IR (false ⇒ Wi-Fi only).
  static bool irCapable(String brandId, ApplianceKind kind) =>
      supportFor(brandId, kind)?.supportsIr ?? false;

  /// Dedicated real-protocol encoders for specific (brand, kind) pairs, keyed
  /// 'brandId:kind'. These take precedence over the generic per-kind encoder.
  /// Each id must exist in DeviceIrProtocols (TV/AV) or AcIrProtocols (AC).
  static const Map<String, String> _realEncoders = {
    // TVs — verified protocols (Samsung32, LG-NEC, SIRC, Kaseikyo, Sharp, RC5,
    // extended-NEC).
    'samsung:tv': 'samsung_tv',
    'lg:tv': 'lg_tv',
    'sony:tv': 'sony_tv',
    'panasonic:tv': 'panasonic_tv',
    'sharp:tv': 'sharp_tv',
    'philips:tv': 'philips_tv',
    'hisense:tv': 'hisense_tv',
    'tcl:tv': 'tcl_tv',
    // ACs — dedicated stateful encoders (wired as they land; unmapped AC
    // brands fall back to the generic Gree encoder).
    'midea:airConditioner': 'midea',
    'beko:airConditioner': 'coolix',
    'kenmore:airConditioner': 'midea',
    'electrolux:airConditioner': 'electra_ac',
    'frigidaire:airConditioner': 'electra_ac',
    'panasonic:airConditioner': 'panasonic_ac',
    'toshiba:airConditioner': 'toshiba_ac',
    'hitachi:airConditioner': 'hitachi_ac',
    'lg:airConditioner': 'lg_ac',
    'samsung:airConditioner': 'samsung_ac',
    'haier:airConditioner': 'haier_ac',
    'hisense:airConditioner': 'kelon',
    'tcl:airConditioner': 'tcl112_ac',
    'whirlpool:airConditioner': 'whirlpool_ac',
    'sharp:airConditioner': 'sharp_ac',
  };

  /// The IR encoder id to use for an appliance. Prefers a dedicated real
  /// encoder for the (brand, kind) pair, then the catalog support entry, then
  /// the kind's generic encoder (also the path for legacy appliances whose
  /// `brand` was saved as a raw encoder id before the catalog existed).
  static String? irEncoderId(String brandId, ApplianceKind kind) {
    final real = _realEncoders['$brandId:${kind.name}'];
    if (real != null) return real;
    return supportFor(brandId, kind)?.irBrandId ?? _genericIrFor(kind);
  }
}
