import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('tr'), Locale('en'), Locale('ru')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return instance ?? const AppLocalizations(Locale('tr'));
  }

  static AppLocalizations lookup(String? languageCode) {
    final normalized = switch (languageCode?.toLowerCase()) {
      'en' => 'en',
      'ru' => 'ru',
      'tk' => 'tr',
      _ => 'tr',
    };
    return AppLocalizations(Locale(normalized));
  }

  static const Map<String, String> _turkmen = {
    'appName': 'Ulanyş',
    'booting': 'Ýüklenýär...',
    'permissionsTitle': 'Rugsatlar',
    'requiredPermissions': 'Gerekli rugsatlar',
    'permissionsIntro':
        'Ulanyşa fonda ekran wagtyny ygtybarly ýygnamagy üçin şu rugsatlar gerek.',
    'usageAccess': 'Ulanyş rugsady',
    'usageAccessDesc':
        'Ulanyşa ulgamdan programmalaryň ekran wagtyny okamaga rugsat berýär.',
    'batteryOptimization': 'Batareýa optimizasiýasy',
    'batteryOptimizationDesc':
        'Ulgamyň fondaky ýygnamany togtatmagynyň öňüni alýar.',
    'exactAlarm': 'Takyk duýduryş',
    'exactAlarmDesc': 'Takyk duýduryşlar arkaly hyzmaty işjeň saklaýar.',
    'deviceAdmin': 'Enjam administratory',
    'deviceAdminDesc':
        'Programmanyň tötänden togtadylmazdan işlemegine kömek edýär.',
    'grant': 'Bermek',
    'allow': 'Rugsat bermek',
    'enable': 'Işletmek',
    'granted': 'Berildi',
    'required': 'Gerekli',
    'statusLabel': 'Ýagdaý',
    'allPermissionsGranted': 'Ähli rugsatlar berildi. Fondaky ýygnama işleýär.',
    'usageAccessGrantedRemaining':
        'Ulanyş rugsady berildi. Fondaky ýygnama işleýär; galan rugsatlary beriň.',
    'grantRequiredPrefix': 'Gerekli rugsatlar',
    'waitingUsageAccess': 'Ulanyş rugsadyna garaşylýar.',
    'checkTimedOut': '{name} barlagy wagtyndan geçdi',
    'deviceAdminUnavailable':
        'Bu enjamda, Enjam administratory sazlamalary elýeterli däl.',
    'homeTitle': 'Ulanyş',
    'settings': 'Sazlamalar',
    'changeLanguage': 'Dili üýtgetmek',
    'selectLanguage': 'Dili saýlaň',
    'currentLanguage': 'Häzirki dil',
    'english': 'English',
    'russian': 'Русский',
    'turkmen': 'Türkmençe',
    'deviceStatus': 'Enjamyň ýagdaýy',
    'deviceNotSet': 'Enjam sazlanmady!',
    'setNow': 'Häzir sazla',
    'allSet': 'Ählisi saz',
    'deviceIdLabel': 'Enjam ID-si',
    'displayNameLabel': 'Görkezilýän at',
    'backendUrlLabel': 'Backend salgysy',
    'saved': 'Ýatda saklandy',
    'configurationReset': 'Sazlamalar täzelendi. {message}',
    'settingsPassword': 'Sazlamalar paroly',
    'setPassword': 'Parol goý',
    'changePassword': 'Paroly üýtget',
    'removePassword': 'Paroly aýyr',
    'unhide': 'Görkez',
    'hide': 'Gizle',
    'currentPassword': 'Häzirki parol',
    'newPassword': 'Täze parol',
    'confirmPassword': 'Paroly tassykla',
    'cancel': 'Ýatyr',
    'save': 'Ýatda sakla',
    'edit': 'Üýtget',
    'remove': 'Aýyr',
    'dangerZone': 'Howply bölüm',
    'dangerZoneDesc':
        'Sazlamalary täzeden düzmek baglanan Enjam ID-sini we görkezilýän ady arassalaýar.',
    'resetConfig': 'Sazlamalary täzele',
    'statusPrefix': 'Ýagdaý',
    'enterPassword': 'Paroly giriziň.',
    'wrongPassword': 'Nädogry parol.',
    'checking': 'Barlanýar...',
    'enter': 'Girmek',
    'setDeviceId': 'Enjam ID-sini sazla',
    'deviceIdEmpty': 'Enjam ID meýdany boş.',
    'allSetDialog': 'Ählisi sazlanan',
    'deviceIdRequired': 'Enjam ID-si zerur.',
    'noNetworkTryAgain':
        'Serwera baglanmadyk. Serwera birikdirip täzeden synanyşyň.',
    'noSuchId': 'Şeýle ID ýok.',
    'idAlreadyInUse': 'Bu ID başga enjamda ulanylýar.',
    'somethingWentWrong': 'Bir zat nädogry boldy.',
    'missingSettings': 'Sazlamalar ýetmeýär: enjam sazlamasyny okap bolmady',
    'missingDeviceId': 'Sazlamalar ýetmeýär: enjam ID-si',
    'noNetworkKeepingLocal':
        'Serwera baglanmadyk, maglumatlar enjamda saklanýar',
    'registrationFailed': 'Hasaba alyş başa barmady',
    'appSyncFailed': 'Programma sinhronlamasy başa barmady',
    'deviceIdDisabled':
        'Enjam ID-si serwer tarapyndan öçürildi. Dogry ID belläň.',
    'syncFailedHttp': 'Sinhronlama başa barmady: HTTP {code}',
    'heartbeatFailedHttp': 'Enjam sinhronlamasy başa barmady: HTTP {code}',
    'heartbeatOk': 'Enjam sinhronlandy',
    'noDataToSync': 'Sinhronlamak üçin maglumat ýok',
    'appsSynced': 'Programmalar sinhronlandy',
    'syncedUsageRows': '{count} ulanyş ýazgysy sinhronlandy',
    'noDeviceLinked': 'Baglanan enjam ýok',
    'noNetworkUnlinkSkipped': 'Serwera baglanmadyk, aýyrmak goýbolsun edildi',
    'unlinkFailedHttp': 'Aýyrmak başa barmady: HTTP {code}',
    'deviceUnlinked': 'Enjam aýryldy',
    'passwordSet': 'Sazlamalar paroly goýuldy.',
    'enterAndConfirmPassword': 'Paroly giriziň we tassyklaň.',
    'passwordsDoNotMatch': 'Parollar gabat gelmeýär.',
    'enterCurrentPassword': 'Häzirki paroly giriziň.',
    'currentPasswordWrong': 'Häzirki parol nädogry.',
    'enterNewAndConfirm': 'Täze paroly giriziň we tassyklaň.',
    'passwordChanged': 'Sazlamalar paroly üýtgedildi.',
    'passwordRemoved': 'Sazlamalar paroly aýryldy.',
    'set': 'Bagla',
    'permissionSettingsTitle': 'Gerekli rugsatlar',
    'openLanguageDialogTooltip': 'Dili üýtgetmek',
    'openSettingsTooltip': 'Sazlamalar',
    'password': 'Parol',
    'backgroundMonitoringActive': 'Ulanyş maglumatlary ýygnalýar',
    'serviceChannelName': 'Ulanyş hyzmaty',
    'deviceAdminExplanation':
        'Institutyň enjamlarynyň fonda has durnukly işlemegi üçin zerur.',
  };

  static const Map<String, String> _english = {
    'appName': 'Ulanyş',
    'booting': 'Booting...',
    'permissionsTitle': 'Permissions',
    'requiredPermissions': 'Required Permissions',
    'permissionsIntro':
        'Ulanyş needs these permissions to collect screen time reliably in the background.',
    'usageAccess': 'Usage Access',
    'usageAccessDesc': 'Lets Ulanyş read app screen time data from the system.',
    'batteryOptimization': 'Battery Optimization',
    'batteryOptimizationDesc':
        'Prevents the system from stopping background collection.',
    'exactAlarm': 'Exact Alarm',
    'exactAlarmDesc': 'Keeps the service alive with precise keep-alive alarms.',
    'deviceAdmin': 'Device Admin',
    'deviceAdminDesc': 'Helps keep the app running without accidental stops.',
    'grant': 'Grant',
    'allow': 'Allow',
    'enable': 'Enable',
    'granted': 'Granted',
    'required': 'Required',
    'statusLabel': 'Status',
    'allPermissionsGranted':
        'All permissions granted. Background collection is running.',
    'usageAccessGrantedRemaining':
        'Usage access granted. Background collection running; grant remaining permissions.',
    'grantRequiredPrefix': 'Grant required',
    'waitingUsageAccess': 'Waiting for usage access permission.',
    'checkTimedOut': '{name} check timed out',
    'deviceAdminUnavailable':
        'Device Admin settings are not available on this device.',
    'homeTitle': 'Ulanyş',
    'settings': 'Settings',
    'changeLanguage': 'Change language',
    'selectLanguage': 'Select language',
    'currentLanguage': 'Current language',
    'english': 'English',
    'russian': 'Русский',
    'turkmen': 'Türkmençe',
    'deviceStatus': 'Device Status',
    'deviceNotSet': 'Device is not set!',
    'setNow': 'Set now',
    'allSet': 'All is set',
    'deviceIdLabel': 'Device ID',
    'displayNameLabel': 'Display Name',
    'backendUrlLabel': 'Backend URL',
    'saved': 'Saved',
    'configurationReset': 'Configuration reset. {message}',
    'settingsPassword': 'Settings Password',
    'setPassword': 'Set password',
    'changePassword': 'Change password',
    'removePassword': 'Remove password',
    'unhide': 'Unhide',
    'hide': 'Hide',
    'currentPassword': 'Current password',
    'newPassword': 'New password',
    'confirmPassword': 'Confirm password',
    'cancel': 'Cancel',
    'save': 'Save',
    'edit': 'Edit',
    'remove': 'Remove',
    'dangerZone': 'Danger Zone',
    'dangerZoneDesc': 'Reset config clears linked Device ID and display name.',
    'resetConfig': 'Reset Config',
    'statusPrefix': 'Status',
    'enterPassword': 'Enter password.',
    'wrongPassword': 'Wrong password.',
    'checking': 'Checking...',
    'enter': 'Enter',
    'setDeviceId': 'Set Device ID',
    'deviceIdEmpty': 'Device ID field is empty.',
    'allSetDialog': 'All set',
    'deviceIdRequired': 'Device ID is required.',
    'noNetworkTryAgain': 'No network. Connect to network and try again.',
    'noSuchId': 'No such ID.',
    'idAlreadyInUse': 'This ID is already in use on another device.',
    'somethingWentWrong': 'Something went wrong.',
    'missingSettings': 'Missing settings: unable to read device config',
    'missingDeviceId': 'Missing settings: device ID',
    'noNetworkKeepingLocal': 'No network, keeping data locally',
    'registrationFailed': 'Registration failed',
    'appSyncFailed': 'App sync failed',
    'deviceIdDisabled': 'Device ID disabled by server. Please set a valid ID.',
    'syncFailedHttp': 'Sync failed: HTTP {code}',
    'heartbeatFailedHttp': 'Heartbeat failed: HTTP {code}',
    'heartbeatOk': 'Heartbeat ok',
    'noDataToSync': 'No data to sync',
    'appsSynced': 'Apps synced',
    'syncedUsageRows': 'Synced {count} usage rows',
    'noDeviceLinked': 'No device linked',
    'noNetworkUnlinkSkipped': 'No network, unlink skipped',
    'unlinkFailedHttp': 'Unlink failed: HTTP {code}',
    'deviceUnlinked': 'Device unlinked',
    'passwordSet': 'Settings password set.',
    'enterAndConfirmPassword': 'Enter and confirm password.',
    'passwordsDoNotMatch': 'Passwords do not match.',
    'enterCurrentPassword': 'Enter current password.',
    'currentPasswordWrong': 'Current password is wrong.',
    'enterNewAndConfirm': 'Enter new password and confirm it.',
    'passwordChanged': 'Settings password changed.',
    'passwordRemoved': 'Settings password removed.',
    'set': 'Set',
    'permissionSettingsTitle': 'Required Permissions',
    'openLanguageDialogTooltip': 'Change language',
    'openSettingsTooltip': 'Settings',
    'password': 'Password',
    'backgroundMonitoringActive': 'Background monitoring is active',
    'serviceChannelName': 'Ulanyş Service',
    'deviceAdminExplanation':
        'Required for stronger background persistence on institution devices.',
  };

  static const Map<String, String> _russian = {
    'appName': 'Ulanyş',
    'booting': 'Запуск...',
    'permissionsTitle': 'Разрешения',
    'requiredPermissions': 'Обязательные разрешения',
    'permissionsIntro':
        'Ulanyş нужны эти разрешения, чтобы надежно собирать экранное время в фоне.',
    'usageAccess': 'Доступ к использованию',
    'usageAccessDesc':
        'Позволяет Ulanyş читать данные об экранном времени приложений из системы.',
    'batteryOptimization': 'Оптимизация батареи',
    'batteryOptimizationDesc':
        'Не дает системе останавливать фоновый сбор данных.',
    'exactAlarm': 'Точный будильник',
    'exactAlarmDesc': 'Поддерживает работу сервиса с помощью точных сигналов.',
    'deviceAdmin': 'Администратор устройства',
    'deviceAdminDesc': 'Помогает приложению работать без случайных остановок.',
    'grant': 'Выдать',
    'allow': 'Разрешить',
    'enable': 'Включить',
    'granted': 'Выдано',
    'required': 'Требуется',
    'statusLabel': 'Статус',
    'allPermissionsGranted': 'Все разрешения выданы. Фоновый сбор работает.',
    'usageAccessGrantedRemaining':
        'Доступ к использованию выдан. Фоновый сбор работает; выдайте остальные разрешения.',
    'grantRequiredPrefix': 'Требуется выдать',
    'waitingUsageAccess': 'Ожидание разрешения на доступ к использованию.',
    'checkTimedOut': 'Проверка "{name}" превысила время ожидания',
    'deviceAdminUnavailable':
        'Настройки администратора устройства недоступны на этом устройстве.',
    'homeTitle': 'Ulanyş',
    'settings': 'Настройки',
    'changeLanguage': 'Сменить язык',
    'selectLanguage': 'Выберите язык',
    'currentLanguage': 'Текущий язык',
    'english': 'English',
    'russian': 'Русский',
    'turkmen': 'Türkmençe',
    'deviceStatus': 'Статус устройства',
    'deviceNotSet': 'Устройство не настроено!',
    'setNow': 'Настроить',
    'allSet': 'Все настроено',
    'deviceIdLabel': 'ID устройства',
    'displayNameLabel': 'Отображаемое имя',
    'backendUrlLabel': 'URL backend',
    'saved': 'Сохранено',
    'configurationReset': 'Конфигурация сброшена. {message}',
    'settingsPassword': 'Пароль настроек',
    'setPassword': 'Установить пароль',
    'changePassword': 'Изменить пароль',
    'removePassword': 'Удалить пароль',
    'unhide': 'Показать',
    'hide': 'Скрыть',
    'currentPassword': 'Текущий пароль',
    'newPassword': 'Новый пароль',
    'confirmPassword': 'Подтвердите пароль',
    'cancel': 'Отмена',
    'save': 'Сохранить',
    'edit': 'Изменить',
    'remove': 'Удалить',
    'dangerZone': 'Опасная зона',
    'dangerZoneDesc':
        'Сброс конфигурации очищает привязанный ID устройства и отображаемое имя.',
    'resetConfig': 'Сбросить конфигурацию',
    'statusPrefix': 'Статус',
    'enterPassword': 'Введите пароль.',
    'wrongPassword': 'Неверный пароль.',
    'checking': 'Проверка...',
    'enter': 'Войти',
    'setDeviceId': 'Установить ID устройства',
    'deviceIdEmpty': 'Поле ID устройства пустое.',
    'allSetDialog': 'Все готово',
    'deviceIdRequired': 'Требуется ID устройства.',
    'noNetworkTryAgain': 'Нет сети. Подключитесь к сети и попробуйте снова.',
    'noSuchId': 'Такого ID нет.',
    'idAlreadyInUse': 'Этот ID уже используется на другом устройстве.',
    'somethingWentWrong': 'Что-то пошло не так.',
    'missingSettings':
        'Отсутствуют настройки: не удалось прочитать конфигурацию устройства',
    'missingDeviceId': 'Отсутствуют настройки: ID устройства',
    'noNetworkKeepingLocal': 'Нет сети, данные остаются локально',
    'registrationFailed': 'Регистрация не удалась',
    'appSyncFailed': 'Синхронизация приложений не удалась',
    'deviceIdDisabled':
        'ID устройства отключен сервером. Укажите действительный ID.',
    'syncFailedHttp': 'Синхронизация не удалась: HTTP {code}',
    'heartbeatFailedHttp': 'Heartbeat не удался: HTTP {code}',
    'heartbeatOk': 'Heartbeat успешен',
    'noDataToSync': 'Нет данных для синхронизации',
    'appsSynced': 'Приложения синхронизированы',
    'syncedUsageRows': 'Синхронизировано записей использования: {count}',
    'noDeviceLinked': 'Нет привязанного устройства',
    'noNetworkUnlinkSkipped': 'Нет сети, отвязка пропущена',
    'unlinkFailedHttp': 'Отвязка не удалась: HTTP {code}',
    'deviceUnlinked': 'Устройство отвязано',
    'passwordSet': 'Пароль настроек установлен.',
    'enterAndConfirmPassword': 'Введите пароль и подтвердите его.',
    'passwordsDoNotMatch': 'Пароли не совпадают.',
    'enterCurrentPassword': 'Введите текущий пароль.',
    'currentPasswordWrong': 'Текущий пароль неверный.',
    'enterNewAndConfirm': 'Введите новый пароль и подтвердите его.',
    'passwordChanged': 'Пароль настроек изменен.',
    'passwordRemoved': 'Пароль настроек удален.',
    'set': 'Установить',
    'permissionSettingsTitle': 'Обязательные разрешения',
    'openLanguageDialogTooltip': 'Сменить язык',
    'openSettingsTooltip': 'Настройки',
    'password': 'Пароль',
    'backgroundMonitoringActive': 'Фоновый мониторинг активен',
    'serviceChannelName': 'Сервис Ulanyş',
    'deviceAdminExplanation':
        'Требуется для более устойчивой фоновой работы на устройствах института.',
  };

  Map<String, String> get _values => switch (locale.languageCode) {
    'en' => _english,
    'ru' => _russian,
    _ => _turkmen,
  };

  String _value(String key) => _values[key] ?? _turkmen[key] ?? key;

  String call(String key, [Map<String, String> params = const {}]) {
    var value = _value(key);
    params.forEach((paramKey, paramValue) {
      value = value.replaceAll('{$paramKey}', paramValue);
    });
    return value;
  }

  String languageName(String code) => switch (code) {
    'en' => english,
    'ru' => russian,
    _ => turkmen,
  };

  String get appName => _value('appName');
  String get booting => _value('booting');
  String get permissionsTitle => _value('permissionsTitle');
  String get requiredPermissions => _value('requiredPermissions');
  String get permissionsIntro => _value('permissionsIntro');
  String get usageAccess => _value('usageAccess');
  String get usageAccessDesc => _value('usageAccessDesc');
  String get batteryOptimization => _value('batteryOptimization');
  String get batteryOptimizationDesc => _value('batteryOptimizationDesc');
  String get exactAlarm => _value('exactAlarm');
  String get exactAlarmDesc => _value('exactAlarmDesc');
  String get deviceAdmin => _value('deviceAdmin');
  String get deviceAdminDesc => _value('deviceAdminDesc');
  String get grant => _value('grant');
  String get allow => _value('allow');
  String get enable => _value('enable');
  String get granted => _value('granted');
  String get requiredText => _value('required');
  String get statusLabel => _value('statusLabel');
  String get allPermissionsGranted => _value('allPermissionsGranted');
  String get usageAccessGrantedRemaining =>
      _value('usageAccessGrantedRemaining');
  String get grantRequiredPrefix => _value('grantRequiredPrefix');
  String get waitingUsageAccess => _value('waitingUsageAccess');
  String get deviceAdminUnavailable => _value('deviceAdminUnavailable');
  String get homeTitle => _value('homeTitle');
  String get settings => _value('settings');
  String get changeLanguage => _value('changeLanguage');
  String get selectLanguage => _value('selectLanguage');
  String get currentLanguage => _value('currentLanguage');
  String get english => _value('english');
  String get russian => _value('russian');
  String get turkmen => _value('turkmen');
  String get deviceStatus => _value('deviceStatus');
  String get deviceNotSet => _value('deviceNotSet');
  String get setNow => _value('setNow');
  String get allSet => _value('allSet');
  String get deviceIdLabel => _value('deviceIdLabel');
  String get displayNameLabel => _value('displayNameLabel');
  String get backendUrlLabel => _value('backendUrlLabel');
  String get saved => _value('saved');
  String get settingsPassword => _value('settingsPassword');
  String get setPassword => _value('setPassword');
  String get changePassword => _value('changePassword');
  String get removePassword => _value('removePassword');
  String get unhide => _value('unhide');
  String get hide => _value('hide');
  String get currentPassword => _value('currentPassword');
  String get newPassword => _value('newPassword');
  String get confirmPassword => _value('confirmPassword');
  String get cancel => _value('cancel');
  String get save => _value('save');
  String get edit => _value('edit');
  String get remove => _value('remove');
  String get dangerZone => _value('dangerZone');
  String get dangerZoneDesc => _value('dangerZoneDesc');
  String get resetConfig => _value('resetConfig');
  String get statusPrefix => _value('statusPrefix');
  String get enterPassword => _value('enterPassword');
  String get wrongPassword => _value('wrongPassword');
  String get checking => _value('checking');
  String get enter => _value('enter');
  String get setDeviceId => _value('setDeviceId');
  String get deviceIdEmpty => _value('deviceIdEmpty');
  String get allSetDialog => _value('allSetDialog');
  String get passwordSet => _value('passwordSet');
  String get enterAndConfirmPassword => _value('enterAndConfirmPassword');
  String get passwordsDoNotMatch => _value('passwordsDoNotMatch');
  String get enterCurrentPassword => _value('enterCurrentPassword');
  String get currentPasswordWrong => _value('currentPasswordWrong');
  String get enterNewAndConfirm => _value('enterNewAndConfirm');
  String get passwordChanged => _value('passwordChanged');
  String get passwordRemoved => _value('passwordRemoved');
  String get set => _value('set');
  String get openLanguageDialogTooltip => _value('openLanguageDialogTooltip');
  String get openSettingsTooltip => _value('openSettingsTooltip');
  String get password => _value('password');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations.lookup(locale.languageCode);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
