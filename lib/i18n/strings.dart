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
