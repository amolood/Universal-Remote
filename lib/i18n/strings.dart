import 'package:flutter/widgets.dart';

/// Supported app languages.
enum AppLang { en, ar }

extension AppLangInfo on AppLang {
  String get code => switch (this) { AppLang.en => 'en', AppLang.ar => 'ar' };
  String get nativeName =>
      switch (this) { AppLang.en => 'English', AppLang.ar => 'العربية' };
  TextDirection get direction =>
      this == AppLang.ar ? TextDirection.rtl : TextDirection.ltr;
  Locale get locale => Locale(code);
}

/// Lightweight hand-rolled localization. Keyed strings with EN + AR tables —
/// no build-time codegen, consistent with the rest of the project.
class S {
  final AppLang lang;
  const S(this.lang);

  /// Resolve the active strings from context (provided by [Localized]).
  static S of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_LocalizedScope>();
    return scope?.strings ?? const S(AppLang.en);
  }

  String _t(String key) => (_ar.containsKey(key) && lang == AppLang.ar)
      ? _ar[key]!
      : (_en[key] ?? key);

  // --- Discovery / pairing ---
  String get findYourTv => _t('find_your_tv');
  String get scanning => _t('scanning');
  String get devicesFound => _t('devices_found'); // takes count via format
  String devicesFoundN(int n) =>
      lang == AppLang.ar ? _arCount(n) : '$n device${n == 1 ? '' : 's'} found';
  String get saved => _t('saved');
  String get available => _t('available');
  String get otherTvs => _t('other_tvs');
  String get noTvs => _t('no_tvs');
  String get lookingNearby => _t('looking_nearby');
  String get sameWifiHint => _t('same_wifi_hint');
  String get enterIpManually => _t('enter_ip_manually');
  String get tvIpAddress => _t('tv_ip');
  String get connectAndroidTv => _t('connect_android');
  String get connectSmartBoard => _t('connect_smartboard');
  String get smartBoardPin => _t('smartboard_pin');
  String get or => _t('or');
  String get paired => _t('paired');
  String get androidTv => _t('android_tv');
  String get smartBoard => _t('smart_board');
  String get infrared => _t('infrared');

  // --- Code entry ---
  String get enterPairingCode => _t('enter_code');
  String get codeShowingOnTv => _t('code_on_tv');
  String get pair => _t('pair');
  String get cancel => _t('cancel');
  String get save => _t('save');
  String get rename => _t('rename');
  String get addAnotherTv => _t('add_another_tv');
  String get tvNameHint => _t('tv_name_hint');

  // --- Appliances ---
  String get appliances => _t('appliances');
  String get addAppliance => _t('add_appliance');
  String get noAppliances => _t('no_appliances');
  String get on => _t('on');
  String get off => _t('off');
  String get connection => _t('connection');
  String get brand => _t('brand');
  String get ipAddress => _t('ip_address');
  String get tokenOptional => _t('token_optional');
  String get name => _t('name');
  String get builtinIr => _t('builtin_ir');
  String get irHub => _t('ir_hub');
  String get wifiAppliance => _t('wifi_appliance');
  String get noIrEmitter => _t('no_ir_emitter');
  String get airConditioner => _t('air_conditioner');
  String get mode => _t('mode');
  String get fanSpeed => _t('fan_speed');
  String get modeCool => _t('mode_cool');
  String get modeHeat => _t('mode_heat');
  String get modeDry => _t('mode_dry');
  String get modeFan => _t('mode_fan');
  String get modeAuto => _t('mode_auto');
  String get fanAuto => _t('fan_auto');
  String get fanLow => _t('fan_low');
  String get fanMedium => _t('fan_medium');
  String get fanHigh => _t('fan_high');
  String get swing => _t('swing');
  String get searchingDevices => _t('searching_devices');
  String get foundDevices => _t('found_devices');
  String get noDevicesFound => _t('no_devices_found');
  String get rescan => _t('rescan');
  String get enterManually => _t('enter_manually');
  String get delete => _t('delete');
  String get deviceType => _t('device_type');
  String get fan => _t('fan');
  String get television => _t('television');
  String get light => _t('light');
  String get genericDevice => _t('generic_device');
  String get speed => _t('speed');
  String get oscillate => _t('oscillate');
  String get brightness => _t('brightness');
  String get device => _t('device');
  String get radio => _t('radio');
  String get dvd => _t('dvd');
  String get setTopBox => _t('set_top_box');
  String get projector => _t('projector');
  String get soundbar => _t('soundbar');
  String get heater => _t('heater');
  String get level => _t('level');
  String get preset => _t('preset');
  String get tuning => _t('tuning');
  String get bass => _t('bass');
  String get sourceInput => _t('source_input');
  String get focus => _t('focus');
  String get eject => _t('eject');
  String get searchBrand => _t('search_brand');
  String get noBrandsForType => _t('no_brands_for_type');
  String get smartOnlyBrand => _t('smart_only_brand');

  // --- Remote ---
  String get connected => _t('connected');
  String get connecting => _t('connecting');
  String get disconnected => _t('disconnected');
  String get switchTv => _t('switch_tv');
  String get unpairTv => _t('unpair_tv');
  String get unpairConfirmTitle => _t('unpair_title');
  String unpairConfirmBody(String name) => lang == AppLang.ar
      ? 'سيؤدي هذا إلى إزالة الاقتران مع "$name". يمكنك إعادة الاتصال من قائمة الأجهزة في أي وقت.'
      : 'This removes the pairing with "$name". You can reconnect from the device list anytime.';
  String get unpair => _t('unpair');
  String get listening => _t('listening');
  String get apps => _t('apps');
  String get typeOnTv => _t('type_on_tv');
  String get searchOrType => _t('search_or_type');
  String get done => _t('done');

  // --- Settings ---
  String get settings => _t('settings');
  String get remoteLayout => _t('remote_layout');
  String get feedback => _t('feedback');
  String get hapticFeedback => _t('haptic_feedback');
  String get airMouseSpeed => _t('air_mouse_speed');
  String get about => _t('about');
  String get language => _t('language');
  String get appTagline => _t('app_tagline');
  String get obDiscoverTitle => _t('ob_discover_title');
  String get obDiscoverBody => _t('ob_discover_body');
  String get obPairTitle => _t('ob_pair_title');
  String get obPairBody => _t('ob_pair_body');
  String get obControlTitle => _t('ob_control_title');
  String get obControlBody => _t('ob_control_body');
  String get next => _t('next');
  String get getStarted => _t('get_started');
  String get skip => _t('skip');
  String get layoutBalanced => _t('layout_balanced');
  String get layoutMinimal => _t('layout_minimal');
  String get layoutTouchpad => _t('layout_touchpad');
  String get layoutClassic => _t('layout_classic');
  String get layoutBalancedDesc => _t('layout_balanced_desc');
  String get layoutMinimalDesc => _t('layout_minimal_desc');
  String get layoutTouchpadDesc => _t('layout_touchpad_desc');
  String get layoutClassicDesc => _t('layout_classic_desc');
  String get guide => _t('guide');
  String get input => _t('input');
  String get menu => _t('menu');
  String get exit => _t('exit');

  // --- Buttons (a11y) ---
  String get power => _t('power');
  String get source => _t('source');
  String get back => _t('back');
  String get home => _t('home');
  String get numbers => _t('numbers');
  String get keyboard => _t('keyboard');
  String get assistant => _t('assistant');
  String get mic => _t('mic');
  String get ok => _t('ok');
  String get up => _t('up');
  String get down => _t('down');
  String get left => _t('left');
  String get right => _t('right');
  String get mute => _t('mute');
  String get volume => _t('volume');
  String get channel => _t('channel');
  String get volShort => _t('vol_short');
  String get chShort => _t('ch_short');
  String get playPause => _t('play_pause');
  String get touchpad => _t('touchpad');
  String get touchpadHint => _t('touchpad_hint');
  String get info => _t('info');
  String get approvalTitle => _t('approval_title');
  String get approvalBody => _t('approval_body');
  String get dpad => _t('dpad');
  String get reconnect => _t('reconnect');

  String _arCount(int n) {
    if (n == 0) return 'لا توجد أجهزة';
    if (n == 1) return 'جهاز واحد';
    if (n == 2) return 'جهازان';
    if (n <= 10) return '$n أجهزة';
    return '$n جهازًا';
  }
}

const Map<String, String> _en = {
  'find_your_tv': 'Find your TV',
  'scanning': 'Scanning your network…',
  'saved': 'Saved',
  'available': 'Available',
  'other_tvs': 'Other TVs',
  'no_tvs': 'No TVs found',
  'looking_nearby': 'Looking for TVs nearby',
  'same_wifi_hint':
      'Make sure your phone and TV are on the same Wi-Fi network.',
  'enter_ip_manually': 'Enter IP manually',
  'tv_ip': 'TV IP address',
  'connect_android': 'Connect (Android TV)',
  'connect_smartboard': 'Connect (Smart Board)',
  'smartboard_pin': 'Smart Board PIN',
  'or': 'or',
  'paired': 'Paired',
  'android_tv': 'Android TV',
  'smart_board': 'Smart Board',
  'infrared': 'Infrared',
  'enter_code': 'Enter pairing code',
  'code_on_tv': 'A 6-character code is showing on your TV.',
  'pair': 'Pair',
  'cancel': 'Cancel',
  'save': 'Save',
  'rename': 'Rename',
  'add_another_tv': 'Add another TV',
  'tv_name_hint': 'TV name',
  'appliances': 'Appliances',
  'add_appliance': 'Add appliance',
  'no_appliances': 'No appliances yet',
  'on': 'On',
  'off': 'Off',
  'connection': 'Connection',
  'brand': 'Brand',
  'ip_address': 'IP address',
  'token_optional': 'Token (optional)',
  'name': 'Name',
  'builtin_ir': 'Phone IR blaster',
  'ir_hub': 'Wi-Fi IR hub',
  'wifi_appliance': 'Smart (Wi-Fi)',
  'no_ir_emitter': 'This phone has no IR blaster. Use a Wi-Fi IR hub or a smart appliance instead.',
  'air_conditioner': 'Air Conditioner',
  'mode': 'Mode',
  'fan_speed': 'Fan speed',
  'mode_cool': 'Cool',
  'mode_heat': 'Heat',
  'mode_dry': 'Dry',
  'mode_fan': 'Fan',
  'mode_auto': 'Auto',
  'fan_auto': 'Auto',
  'fan_low': 'Low',
  'fan_medium': 'Mid',
  'fan_high': 'High',
  'swing': 'Swing',
  'searching_devices': 'Searching for devices…',
  'found_devices': 'Found devices',
  'no_devices_found': 'No devices found on the network. Enter the address manually below.',
  'rescan': 'Scan again',
  'enter_manually': 'Enter address manually',
  'delete': 'Delete',
  'device_type': 'Device type',
  'fan': 'Fan',
  'television': 'TV',
  'light': 'Light',
  'generic_device': 'Other',
  'speed': 'Speed',
  'oscillate': 'Oscillate',
  'brightness': 'Brightness',
  'device': 'Device',
  'radio': 'Radio',
  'dvd': 'DVD / Blu-ray',
  'set_top_box': 'Set-top box',
  'projector': 'Projector',
  'soundbar': 'Soundbar',
  'heater': 'Heater',
  'level': 'Level',
  'preset': 'Preset',
  'tuning': 'Tuning',
  'bass': 'Bass',
  'source_input': 'Source',
  'focus': 'Focus',
  'eject': 'Eject',
  'search_brand': 'Search brand…',
  'no_brands_for_type': 'No brands listed for this device type yet.',
  'smart_only_brand':
      'This brand is controlled over Wi-Fi (no IR remote) — pick Smart (Wi-Fi).',
  'connected': 'Connected',
  'connecting': 'Connecting…',
  'disconnected': 'Disconnected',
  'switch_tv': 'Switch TV',
  'unpair_tv': 'Unpair TV',
  'unpair_title': 'Unpair TV?',
  'unpair': 'Unpair',
  'listening': 'Listening…',
  'apps': 'Apps',
  'type_on_tv': 'Type on TV',
  'search_or_type': 'Search or type…',
  'done': 'Done',
  'settings': 'Settings',
  'remote_layout': 'Remote layout',
  'feedback': 'Feedback',
  'haptic_feedback': 'Haptic feedback',
  'air_mouse_speed': 'Air mouse speed',
  'about': 'About',
  'language': 'Language',
  'app_tagline': 'Universal — Android TV & Smart Board',
  'ob_discover_title': 'Auto-discovery',
  'ob_discover_body':
      'The app finds your TV automatically on the same Wi-Fi — no setup.',
  'ob_pair_title': 'Easy pairing',
  'ob_pair_body':
      'Pick your TV and enter the code shown on screen. It stays paired next time.',
  'ob_control_title': 'Full control + voice',
  'ob_control_body':
      'D-pad, touchpad, media, keyboard, and voice search — everything you need.',
  'next': 'Next',
  'get_started': 'Get started',
  'skip': 'Skip',
  'layout_balanced': 'Balanced',
  'layout_minimal': 'Minimal',
  'layout_touchpad': 'Touchpad',
  'layout_classic': 'Classic',
  'layout_balanced_desc': 'Full controls: D-pad, media, volume & channels',
  'layout_minimal_desc': 'Just the essentials — big D-pad & volume',
  'layout_touchpad_desc': 'Large swipe pad with a compact button row',
  'layout_classic_desc': 'TV-style: D-pad with corner keys, side VOL & CH',
  'guide': 'Guide',
  'input': 'Input',
  'menu': 'Menu',
  'exit': 'Exit',
  'power': 'Power',
  'source': 'Source',
  'back': 'Back',
  'home': 'Home',
  'numbers': 'Numbers',
  'keyboard': 'Keyboard',
  'assistant': 'Assistant',
  'mic': 'Voice search',
  'ok': 'OK / Select',
  'up': 'Up',
  'down': 'Down',
  'left': 'Left',
  'right': 'Right',
  'mute': 'Mute',
  'volume': 'Volume',
  'channel': 'Channel',
  'vol_short': 'VOL',
  'ch_short': 'CH',
  'play_pause': 'Play / Pause',
  'touchpad': 'Touchpad',
  'touchpad_hint': 'Swipe to move, tap to select',
  'info': 'Info',
  'approval_title': 'Check your TV',
  'approval_body':
      'Accept the connection prompt shown on your TV screen to finish pairing.',
  'dpad': 'D-Pad',
  'reconnect': 'Reconnect',
};

const Map<String, String> _ar = {
  'find_your_tv': 'ابحث عن تلفزيونك',
  'scanning': 'جارٍ البحث في الشبكة…',
  'saved': 'محفوظة',
  'available': 'متاحة',
  'other_tvs': 'تلفزيونات أخرى',
  'no_tvs': 'لا توجد تلفزيونات',
  'looking_nearby': 'جارٍ البحث عن تلفزيونات قريبة',
  'same_wifi_hint': 'تأكد أن الهاتف والتلفزيون على نفس شبكة الواي فاي.',
  'enter_ip_manually': 'إدخال العنوان يدويًا',
  'tv_ip': 'عنوان IP للتلفزيون',
  'connect_android': 'اتصال (Android TV)',
  'connect_smartboard': 'اتصال (السبورة الذكية)',
  'smartboard_pin': 'رمز السبورة الذكية',
  'or': 'أو',
  'paired': 'مقترن',
  'android_tv': 'Android TV',
  'smart_board': 'سبورة ذكية',
  'infrared': 'أشعة تحت حمراء',
  'enter_code': 'أدخل رمز الاقتران',
  'code_on_tv': 'يظهر رمز من 6 خانات على تلفزيونك.',
  'pair': 'اقتران',
  'cancel': 'إلغاء',
  'save': 'حفظ',
  'rename': 'إعادة تسمية',
  'add_another_tv': 'إضافة تلفزيون آخر',
  'tv_name_hint': 'اسم التلفزيون',
  'appliances': 'الأجهزة',
  'add_appliance': 'إضافة جهاز',
  'no_appliances': 'لا توجد أجهزة بعد',
  'on': 'تشغيل',
  'off': 'إيقاف',
  'connection': 'الاتصال',
  'brand': 'العلامة التجارية',
  'ip_address': 'عنوان IP',
  'token_optional': 'الرمز (اختياري)',
  'name': 'الاسم',
  'builtin_ir': 'أشعة الهاتف',
  'ir_hub': 'موزّع IR عبر الواي فاي',
  'wifi_appliance': 'ذكي (واي فاي)',
  'no_ir_emitter': 'هذا الهاتف لا يملك مُرسل أشعة. استخدم موزّع IR عبر الواي فاي أو جهازاً ذكياً.',
  'air_conditioner': 'مكيّف',
  'mode': 'الوضع',
  'fan_speed': 'سرعة المروحة',
  'mode_cool': 'تبريد',
  'mode_heat': 'تدفئة',
  'mode_dry': 'تجفيف',
  'mode_fan': 'مروحة',
  'mode_auto': 'تلقائي',
  'fan_auto': 'تلقائي',
  'fan_low': 'منخفض',
  'fan_medium': 'متوسط',
  'fan_high': 'عالٍ',
  'swing': 'تأرجح',
  'searching_devices': 'جارٍ البحث عن الأجهزة…',
  'found_devices': 'أجهزة موجودة',
  'no_devices_found': 'لم يُعثر على أجهزة في الشبكة. أدخل العنوان يدويًا بالأسفل.',
  'rescan': 'إعادة البحث',
  'enter_manually': 'إدخال العنوان يدويًا',
  'delete': 'حذف',
  'device_type': 'نوع الجهاز',
  'fan': 'مروحة',
  'television': 'تلفزيون',
  'light': 'إضاءة',
  'generic_device': 'أخرى',
  'speed': 'السرعة',
  'oscillate': 'التأرجح',
  'brightness': 'السطوع',
  'device': 'جهاز',
  'radio': 'راديو',
  'dvd': 'DVD / بلوراي',
  'set_top_box': 'جهاز استقبال',
  'projector': 'بروجكتر',
  'soundbar': 'مكبر صوت',
  'heater': 'مدفأة',
  'level': 'المستوى',
  'preset': 'محطة محفوظة',
  'tuning': 'الضبط',
  'bass': 'الجهير',
  'source_input': 'المصدر',
  'focus': 'التركيز',
  'eject': 'إخراج',
  'search_brand': 'ابحث عن علامة…',
  'no_brands_for_type': 'لا توجد علامات تجارية لهذا النوع بعد.',
  'smart_only_brand':
      'يتم التحكم بهذه العلامة عبر الواي فاي (بدون ريموت أشعة) — اختر «ذكي (واي فاي)».',
  'connected': 'متصل',
  'connecting': 'جارٍ الاتصال…',
  'disconnected': 'غير متصل',
  'switch_tv': 'تبديل التلفزيون',
  'unpair_tv': 'إلغاء الاقتران',
  'unpair_title': 'إلغاء اقتران التلفزيون؟',
  'unpair': 'إلغاء الاقتران',
  'listening': 'يستمع…',
  'apps': 'التطبيقات',
  'type_on_tv': 'الكتابة على التلفزيون',
  'search_or_type': 'ابحث أو اكتب…',
  'done': 'تم',
  'settings': 'الإعدادات',
  'remote_layout': 'تخطيط الريموت',
  'feedback': 'الاستجابة',
  'haptic_feedback': 'الاهتزاز عند اللمس',
  'air_mouse_speed': 'سرعة ماوس الجو',
  'about': 'حول التطبيق',
  'language': 'اللغة',
  'app_tagline': 'ريموت عالمي — Android TV والسبورة الذكية',
  'ob_discover_title': 'اكتشاف تلقائي',
  'ob_discover_body':
      'يعثر التطبيق على تلفزيونك تلقائيًا على نفس شبكة الواي فاي — بدون إعداد.',
  'ob_pair_title': 'اقتران سهل',
  'ob_pair_body':
      'اختر تلفزيونك وأدخل الرمز الظاهر على الشاشة. يبقى مقترنًا للمرات القادمة.',
  'ob_control_title': 'تحكّم كامل + صوت',
  'ob_control_body':
      'لوحة اتجاهات، لوحة لمس، وسائط، كيبورد، وبحث صوتي — كل ما تحتاجه.',
  'next': 'التالي',
  'get_started': 'ابدأ',
  'skip': 'تخطّي',
  'layout_balanced': 'متوازن',
  'layout_minimal': 'مبسّط',
  'layout_touchpad': 'لوحة لمس',
  'layout_classic': 'كلاسيكي',
  'layout_balanced_desc': 'تحكم كامل: لوحة اتجاهات، وسائط، صوت وقنوات',
  'layout_minimal_desc': 'الأساسيات فقط — لوحة اتجاهات كبيرة وصوت',
  'layout_touchpad_desc': 'لوحة لمس كبيرة مع صف أزرار مدمج',
  'layout_classic_desc': 'نمط التلفزيون: لوحة اتجاهات بأزرار جانبية وصوت وقنوات',
  'guide': 'الدليل',
  'input': 'المصدر',
  'menu': 'القائمة',
  'exit': 'خروج',
  'power': 'الطاقة',
  'source': 'المصدر',
  'back': 'رجوع',
  'home': 'الرئيسية',
  'numbers': 'الأرقام',
  'keyboard': 'لوحة المفاتيح',
  'assistant': 'المساعد',
  'mic': 'البحث الصوتي',
  'ok': 'موافق / اختيار',
  'up': 'أعلى',
  'down': 'أسفل',
  'left': 'يسار',
  'right': 'يمين',
  'mute': 'كتم',
  'volume': 'الصوت',
  'channel': 'القناة',
  'vol_short': 'الصوت',
  'ch_short': 'القناة',
  'play_pause': 'تشغيل / إيقاف',
  'touchpad': 'لوحة لمس',
  'touchpad_hint': 'اسحب للتحريك، انقر للاختيار',
  'info': 'معلومات',
  'approval_title': 'تحقق من تلفزيونك',
  'approval_body':
      'اقبل طلب الاتصال الظاهر على شاشة التلفزيون لإكمال الاقتران.',
  'dpad': 'لوحة اتجاهات',
  'reconnect': 'إعادة الاتصال',
};

/// InheritedWidget that exposes the active [S] to the tree and applies the
/// matching text direction. Wrap the app in this and rebuild on language change.
class Localized extends StatelessWidget {
  final AppLang lang;
  final Widget child;
  const Localized({super.key, required this.lang, required this.child});

  @override
  Widget build(BuildContext context) {
    return _LocalizedScope(
      strings: S(lang),
      child: Directionality(
        textDirection: lang.direction,
        child: child,
      ),
    );
  }
}

class _LocalizedScope extends InheritedWidget {
  final S strings;
  const _LocalizedScope({required this.strings, required super.child});

  @override
  bool updateShouldNotify(_LocalizedScope old) =>
      old.strings.lang != strings.lang;
}
