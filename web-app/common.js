
const BACKEND_BASE_URL = "http://192.168.55.109:8080";
const BACKEND_URL_KEY = "usage_backend_url";
const LANGUAGE_KEY = "usage_ui_language";
const PAGE_SIZE = 50;
const DEFAULT_LANGUAGE = "tk";
const LANGUAGE_LABELS = {
  tk: "Türkmençe",
  en: "English",
  ru: "Русский",
};

const UI_STRINGS = {
  tk: {
    appName: "Ulanyş",
    pageTitleDashboard: "Dolandyryş paneli",
    pageTitleCategories: "Kategoriýalar",
    pageTitleDevices: "Enjamlar",
    pageTitleExport: "Eksport",
    pageTitleAdmin: "Admin",
    navDashboard: "Dolandyryş paneli",
    navCategories: "Kategoriýalar",
    navDevices: "Enjamlar",
    navExport: "Eksport",
    loginTitle: "Giriş",
    adminLoginTitle: "Admin girişi",
    username: "Ulanyjy ady",
    password: "Açar söz",
    loginButton: "Giriş",
    logout: "Çykmak",
    loggingIn: "Girilýär...",
    loginSuccess: "Üstünlikli girildi",
    loginFailed: "Giriş şowsuz boldy: {message}",
    adminCheckingCredentials: "Admin maglumatlary barlanýar...",
    adminLoginFailed: "Admin girişi şowsuz boldy: {message}",
    language: "Dil",
    currentLanguage: "Häzirki dil",
    languageDialogTitle: "Dili saýlaň",
    confirm: "Tassykla",
    cancel: "Ýatyr",
    all: "Ählisi",
    never: "Hiç haçan",
    connected: "Birikdirilen",
    notConnected: "Birikdirilmedik",
    logOutConfirm: "Çykmak isleýärsiňizmi?",
    unauthorized: "Rugsat ýok",
    notFound: "Tapylmady",
    backendInternalError: "Näsazlyk: {detail}",
    backendDbError: "Maglumat bazasy näsazlygy: {detail}",
    genericHttpError: "Serwer näsazlygy {status}",
    categoryMainNotFound: "Esasy kategoriýa tapylmady",
    categorySubNotFound: "Kurs tapylmady",
    categoryMismatch: "Kurs saýlanan fakultete degişli däl",
    selectedCategoryNotFound: "Saýlanan fakultet ýa-da kurs tapylmady",
    deviceIdExists: "Enjam ID-si eýýäm bar",
    deviceNotFound: "Enjam tapylmady",
    deviceInactive: "Enjam işjeň däl",
    unknownOrInactiveDeviceId: "Enjam ID-si näbelli ýa-da işjeň däl",
    blockedDeviceInstallation: "Bu enjam üçin gurnama bloklanan",
    deviceLinkedAnotherPhysical: "Enjam ID-si başga fiziki enjama baglanan",
    deviceNotLinkedThisPhysical: "Enjam ID-si bu fiziki enjama baglanmadyk",
    invalidCredentials: "Nädogry maglumatlar",
    userAlreadyExists: "Ulanyjy eýýäm bar",
    userNotFound: "Ulanyjy tapylmady",
    missingUsernamePassword: "Gerekli meýdanlar doldurylmadyk: ulanyjy ady, açar söz",
    missingName: "Gerekli meýdan doldurylmadyk: at",
    missingNameMain: "Gerekli meýdanlar doldurylmadyk: at, esasy kategoriýa",
    missingDeviceCategoryFields: "Gerekli meýdanlar doldurylmadyk: enjam ID-si, fakultet, kurs",
    missingDeviceClientFields: "Gerekli meýdanlar doldurylmadyk: enjam ID-si, müşderi nusgasy ID-si",
    missingDeviceIdField: "Gerekli meýdan doldurylmadyk: enjam ID-si",
    missingRangeParams: "'Başlangyç' we 'Soňky' wagtlary hökmany",
    invalidRangeOrder: "Soňky wagt başlangyç wagtdan soň bolmaly",
    maxRange: "Iň köp aralyk 62 gün",
    invalidArraysPayload: "'apps' we 'usage_sessions' sanaw görnüşinde bolmaly",
    usageSessionMissingPackage: "Her ulanyş ýazgysynda package_name bolmaly",
    negativeForegroundMs: "foreground_ms otrisatel bolup bilmez",
    appMissingPackageAndName: "Her programma package_name we app_name bilen gelmeli",
    loadFailed: "Ýüklemek şowsuz boldy: {message}",
    failed: "Şowsuz: {message}",
    saveFailed: "Ýatda saklamak şowsuz boldy: {message}",
    deleteFailed: "Pozmak şowsuz boldy: {message}",
    createFailed: "Döretmek şowsuz boldy: {message}",
    updateFailed: "Täzelemek şowsuz boldy: {message}",
    saving: "Ýatda saklanýar...",
    saved: "Ýatda saklandy",
    creating: "Döredilýär...",
    deleting: "Pozulýar...",
    deleted: "Pozuldy.",
    dashboardDevicesTitle: "Enjamlar",
    devicesCount: "Jemi {total} enjamdan {shown} sanysy görkezilýär",
    appsCount: "Jemi {total} programmadan {shown} sanysy görkezilýär",
    deviceSelectionCount: "{count} enjam saýlandy",
    searchDeviceId: "Enjam ID boýunça gözleg",
    searchDeviceIdPlaceholder: "mysal: 202020",
    searchApp: "Programma boýunça gözleg",
    searchAppPlaceholder: "mysal: Sports Stream",
    faculty: "Fakultet",
    yearIntake: "Kursy",
    deviceId: "Enjam ID",
    ownerName: "Enjam eýesi",
    year: "Kurs",
    lastSeen: "Soňky gezek görüldi",
    connection: "Baglanyşyk",
    deviceDetails: "Enjam maglumatlary",
    from: "Başlangyç",
    to: "Soňky",
    screenTime: "Ekran wagty",
    appUsage: "Programma ulanylyşy",
    noAppUsageYet: "Entäk programma ulanylyşy ýok.",
    dailyUsage: "Gündelik ulanyş",
    date: "Sene",
    app: "Programma",
    package: "Paket",
    icon: "Nyşan",
    includeSystemApps: "Ulgam programmalaryny hem goş",
    selectDevicePrompt: "Sanawdan bir enjam saýlaň.",
    noDevicesFound: "Enjam tapylmady.",
    noAppsFound: "Programma tapylmady.",
    noDailyUsage: "Ulanyş maglumatlary ýok.",
    loadingDetails: "Jikme-jiklikler ýüklenýär...",
    todayRange: "Şu gün",
    rangeLabel: "{from} - {to}",
    systemAppBadge: "ulgam programmasy",
    createEditDevice: "Enjam döret / üýtget",
    addDevice: "Enjam goş",
    deviceCreated: "Enjam döredildi",
    actions: "Hereketler",
    edit: "Üýtget",
    delete: "Poz",
    editDevice: "Enjamy üýtget",
    editSelectedDevices: "Saýlanan enjamlary üýtget",
    selectedDevicesCount: "{count} enjam saýlandy.",
    save: "Ýatda sakla",
    deleteDeviceConfirm: "{deviceId} enjamyny pozmalymy?",
    deleteSelectedDevicesConfirm: "Saýlanan {count} enjam pozulsynmy?",
    editSelectedDevicesAction: "{count} enjamy üýtget",
    deleteSelectedDevicesAction: "{count} enjamy poz",
    deletedWithFailures: "Pozuldy, ýöne {count} sany şowsuzlyk boldy.",
    savedWithFailures: "Ýatda saklandy, ýöne {count} sany şowsuzlyk boldy.",
    mainCategoryTitle: "Esasy kategoriýa (fakultet)",
    subCategoryTitle: "Goşmaça kategoriýa (kursy)",
    name: "Kategoriýa",
    addMainCategory: "Esasy kategoriýa goş",
    addSubCategory: "Kursyny goş",
    noMainCategories: "Esasy kategoriýa ýok.",
    noSubCategories: "Goşmaça kategoriýa ýok.",
    main: "Esasy",
    sub: "Goşmaça",
    deleteMainCategoryConfirm: "{name} esasy kategoriýasyny pozmalymy?",
    deleteSubCategoryConfirm: "{label} goşmaça kategoriýasyny pozmalymy?",
    editMainCategory: "Esasy kategoriýany üýtget",
    editSubCategory: "Goşmaça kategoriýany üýtget",
    exportUsageData: "Ulanyş maglumatlaryny eksport etmek",
    exportHelp: "Fakultet we kursy boýunça ulanyş maglumatlaryny Excel faýly görnüşinde göçürip alyň.",
    export: "Eksport",
    chooseFacultyYear: "Fakultet we kursy saýlaň.",
    chooseValidDateRange: "Dogry seneler aralygyny saýlaň.",
    preparingExport: "Eksport taýýarlanýar...",
    exportedDevices: "{count} enjam eksport edildi.",
    exportFailed: "Eksport şowsuz boldy: {message}",
    adminBackendUrl: "Backend URL",
    adminBackendUrlHelp: "Bu brauzerde web-app tarapyndan ulanylýan backend salgysyny dolandyryň.",
    backendUrlSaved: "Backend URL ýatda saklandy.",
    users: "Ulanyjylar",
    createUser: "Ulanyjy döret",
    creatingUser: "Ulanyjy döredilýär...",
    userCreated: "Ulanyjy döredildi.",
    loadingUsers: "Ulanyjylar ýüklenýär...",
    noUsersFound: "Ulanyjy tapylmady.",
    updated: "Täzelendi",
    newPassword: "Täze açar söz",
    savePassword: "Açar sözi ýatda sakla",
    enterNewPasswordFirst: "Ilki täze açar söz giriziň.",
    updatingUser: "{username} täzelenýär...",
    passwordUpdatedForUser: "{username} üçin açar söz täzelendi.",
    passwordUpdateFailed: "Açar söz täzelenmedi: {message}",
    adminAuthenticationRequired: "Admin tassyklamasy zerur",
    saveUserChangesConfirm: "{username} üçin täze açar söz ýatda saklansynmy?",
    userDeleted: "{username} ulanyjy pozuldy.",
    userDeleteFailed: "Ulanyjy pozulmady: {message}",
    deleteUserConfirm: "{username} ulanyjyny pozmalymy?",
  },
  en: {
    appName: "Ulanyş",
    pageTitleDashboard: "Dashboard",
    pageTitleCategories: "Categories",
    pageTitleDevices: "Devices",
    pageTitleExport: "Export",
    pageTitleAdmin: "Admin",
    navDashboard: "Dashboard",
    navCategories: "Categories",
    navDevices: "Devices",
    navExport: "Export",
    loginTitle: "Login",
    adminLoginTitle: "Admin Login",
    username: "Username",
    password: "Password",
    loginButton: "Login",
    logout: "Logout",
    loggingIn: "Logging in...",
    loginSuccess: "Login successful",
    loginFailed: "Login failed: {message}",
    adminCheckingCredentials: "Checking admin credentials...",
    adminLoginFailed: "Admin login failed: {message}",
    language: "Language",
    currentLanguage: "Current language",
    languageDialogTitle: "Choose language",
    confirm: "Confirm",
    cancel: "Cancel",
    all: "All",
    never: "Never",
    connected: "Connected",
    notConnected: "Not Connected",
    logOutConfirm: "Log out?",
    unauthorized: "Unauthorized",
    notFound: "Not found",
    backendInternalError: "Internal error: {detail}",
    backendDbError: "DB error: {detail}",
    genericHttpError: "Server error {status}",
    categoryMainNotFound: "Main category not found",
    categorySubNotFound: "Sub category not found",
    categoryMismatch: "Sub category does not belong to selected main category",
    selectedCategoryNotFound: "Selected faculty or year intake was not found",
    deviceIdExists: "Device ID already exists",
    deviceNotFound: "Device not found",
    deviceInactive: "Device is not active",
    unknownOrInactiveDeviceId: "Unknown or inactive device ID",
    blockedDeviceInstallation: "This device installation is blocked for this device ID",
    deviceLinkedAnotherPhysical: "Device ID already linked to another physical device",
    deviceNotLinkedThisPhysical: "Device ID is not linked to this physical device",
    invalidCredentials: "Invalid credentials",
    userAlreadyExists: "User already exists",
    userNotFound: "User not found",
    missingUsernamePassword: "Missing required fields: username, password",
    missingName: "Missing required field: name",
    missingNameMain: "Missing required fields: name, main_category_id",
    missingDeviceCategoryFields: "Missing required fields: device_id, main_category_id, sub_category_id",
    missingDeviceClientFields: "Missing required fields: device_id, client_instance_id",
    missingDeviceIdField: "Missing required fields: device_id",
    missingRangeParams: "Query params 'from' and 'to' are required",
    invalidRangeOrder: "'to' must be later than 'from'",
    maxRange: "Maximum range is 62 days",
    invalidArraysPayload: "'apps' and 'usage_sessions' must be arrays",
    usageSessionMissingPackage: "Each usage session must include package_name",
    negativeForegroundMs: "foreground_ms cannot be negative",
    appMissingPackageAndName: "Each app must include package_name and app_name",
    loadFailed: "Load failed: {message}",
    failed: "Failed: {message}",
    saveFailed: "Save failed: {message}",
    deleteFailed: "Delete failed: {message}",
    createFailed: "Create failed: {message}",
    updateFailed: "Update failed: {message}",
    saving: "Saving...",
    saved: "Saved",
    creating: "Creating...",
    deleting: "Deleting...",
    deleted: "Deleted.",
    dashboardDevicesTitle: "Devices",
    devicesCount: "Showing {shown} of {total} devices",
    appsCount: "Showing {shown} of {total} apps",
    deviceSelectionCount: "{count} devices selected",
    searchDeviceId: "Search Device ID",
    searchDeviceIdPlaceholder: "e.g. TAB001",
    searchApp: "Search App",
    searchAppPlaceholder: "e.g. Sports Stream",
    faculty: "Faculty",
    yearIntake: "Year Intake",
    deviceId: "Device ID",
    ownerName: "Owner Name",
    year: "Year",
    lastSeen: "Last Seen",
    connection: "Connection",
    deviceDetails: "Device Details",
    from: "From",
    to: "To",
    screenTime: "Screen Time",
    appUsage: "App Usage",
    noAppUsageYet: "No app usage yet.",
    dailyUsage: "Daily Usage",
    date: "Date",
    app: "App",
    package: "Package",
    icon: "Icon",
    includeSystemApps: "Include system apps too",
    selectDevicePrompt: "Select a device from the list.",
    noDevicesFound: "No devices found.",
    noAppsFound: "No apps found.",
    noDailyUsage: "No usage data.",
    loadingDetails: "Loading details...",
    todayRange: "Today",
    rangeLabel: "{from} - {to}",
    systemAppBadge: "system app",
    createEditDevice: "Create / Edit Device",
    addDevice: "Add Device",
    deviceCreated: "Device created",
    actions: "Actions",
    edit: "Edit",
    delete: "Delete",
    editDevice: "Edit Device",
    editSelectedDevices: "Edit Selected Devices",
    selectedDevicesCount: "{count} devices selected.",
    save: "Save",
    deleteDeviceConfirm: "Delete device {deviceId}?",
    deleteSelectedDevicesConfirm: "Delete {count} selected devices?",
    editSelectedDevicesAction: "Edit {count} devices",
    deleteSelectedDevicesAction: "Delete {count} devices",
    deletedWithFailures: "Deleted with {count} failure(s).",
    savedWithFailures: "Saved with {count} failure(s).",
    mainCategoryTitle: "Main Category (Faculty)",
    subCategoryTitle: "Sub Category (Year Intake)",
    name: "Name",
    addMainCategory: "Add Main Category",
    addSubCategory: "Add Sub Category",
    noMainCategories: "No main categories.",
    noSubCategories: "No sub categories.",
    main: "Main",
    sub: "Sub",
    deleteMainCategoryConfirm: "Delete main category {name}?",
    deleteSubCategoryConfirm: "Delete sub category {label}?",
    editMainCategory: "Edit Main Category",
    editSubCategory: "Edit Sub Category",
    exportUsageData: "Export Usage Data",
    exportHelp: "Export usage data by faculty and year intake as an Excel file.",
    export: "Export",
    chooseFacultyYear: "Choose faculty and year intake.",
    chooseValidDateRange: "Choose a valid date range.",
    preparingExport: "Preparing export...",
    exportedDevices: "Exported {count} devices.",
    exportFailed: "Export failed: {message}",
    adminBackendUrl: "Backend URL",
    adminBackendUrlHelp: "Manage the backend address used by this web app on this browser.",
    backendUrlSaved: "Backend URL saved.",
    users: "Users",
    createUser: "Create User",
    creatingUser: "Creating user...",
    userCreated: "User created.",
    loadingUsers: "Loading users...",
    noUsersFound: "No users found.",
    updated: "Updated",
    newPassword: "New Password",
    savePassword: "Save Password",
    enterNewPasswordFirst: "Enter a new password first.",
    updatingUser: "Updating {username}...",
    passwordUpdatedForUser: "Password updated for {username}.",
    passwordUpdateFailed: "Password update failed: {message}",
    adminAuthenticationRequired: "Admin authentication required",
    saveUserChangesConfirm: "Save the new password for {username}?",
    userDeleted: "User {username} deleted.",
    userDeleteFailed: "User delete failed: {message}",
    deleteUserConfirm: "Delete user {username}?",
  },
  ru: {
    appName: "Ulanyş",
    pageTitleDashboard: "Панель",
    pageTitleCategories: "Категории",
    pageTitleDevices: "Устройства",
    pageTitleExport: "Экспорт",
    pageTitleAdmin: "Админ",
    navDashboard: "Панель",
    navCategories: "Категории",
    navDevices: "Устройства",
    navExport: "Экспорт",
    loginTitle: "Вход",
    adminLoginTitle: "Вход администратора",
    username: "Имя пользователя",
    password: "Пароль",
    loginButton: "Войти",
    logout: "Выйти",
    loggingIn: "Выполняется вход...",
    loginSuccess: "Вход выполнен",
    loginFailed: "Ошибка входа: {message}",
    adminCheckingCredentials: "Проверка данных администратора...",
    adminLoginFailed: "Ошибка входа администратора: {message}",
    language: "Язык",
    currentLanguage: "Текущий язык",
    languageDialogTitle: "Выберите язык",
    confirm: "Подтвердить",
    cancel: "Отмена",
    all: "Все",
    never: "Никогда",
    connected: "Подключено",
    notConnected: "Не подключено",
    logOutConfirm: "Выйти из системы?",
    unauthorized: "Нет доступа",
    notFound: "Не найдено",
    backendInternalError: "Внутренняя ошибка: {detail}",
    backendDbError: "Ошибка базы данных: {detail}",
    genericHttpError: "Ошибка сервера {status}",
    categoryMainNotFound: "Основная категория не найдена",
    categorySubNotFound: "Подкатегория не найдена",
    categoryMismatch: "Подкатегория не относится к выбранной основной категории",
    selectedCategoryNotFound: "Выбранный факультет или курс не найден",
    deviceIdExists: "ID устройства уже существует",
    deviceNotFound: "Устройство не найдено",
    deviceInactive: "Устройство неактивно",
    unknownOrInactiveDeviceId: "Неизвестный или неактивный ID устройства",
    blockedDeviceInstallation: "Установка на это устройство заблокирована для данного ID",
    deviceLinkedAnotherPhysical: "ID устройства уже связан с другим физическим устройством",
    deviceNotLinkedThisPhysical: "ID устройства не связан с этим физическим устройством",
    invalidCredentials: "Неверные учетные данные",
    userAlreadyExists: "Пользователь уже существует",
    userNotFound: "Пользователь не найден",
    missingUsernamePassword: "Отсутствуют обязательные поля: username, password",
    missingName: "Отсутствует обязательное поле: name",
    missingNameMain: "Отсутствуют обязательные поля: name, main_category_id",
    missingDeviceCategoryFields: "Отсутствуют обязательные поля: device_id, main_category_id, sub_category_id",
    missingDeviceClientFields: "Отсутствуют обязательные поля: device_id, client_instance_id",
    missingDeviceIdField: "Отсутствует обязательное поле: device_id",
    missingRangeParams: "Параметры 'from' и 'to' обязательны",
    invalidRangeOrder: "'to' должно быть позже 'from'",
    maxRange: "Максимальный диапазон — 62 дня",
    invalidArraysPayload: "'apps' и 'usage_sessions' должны быть массивами",
    usageSessionMissingPackage: "Каждая сессия должна содержать package_name",
    negativeForegroundMs: "foreground_ms не может быть отрицательным",
    appMissingPackageAndName: "Каждое приложение должно содержать package_name и app_name",
    loadFailed: "Ошибка загрузки: {message}",
    failed: "Ошибка: {message}",
    saveFailed: "Ошибка сохранения: {message}",
    deleteFailed: "Ошибка удаления: {message}",
    createFailed: "Ошибка создания: {message}",
    updateFailed: "Ошибка обновления: {message}",
    saving: "Сохранение...",
    saved: "Сохранено",
    creating: "Создание...",
    deleting: "Удаление...",
    deleted: "Удалено.",
    dashboardDevicesTitle: "Устройства",
    devicesCount: "Показано {shown} из {total} устройств",
    appsCount: "Показано {shown} из {total} приложений",
    deviceSelectionCount: "Выбрано устройств: {count}",
    searchDeviceId: "Поиск по ID устройства",
    searchDeviceIdPlaceholder: "например, TAB001",
    searchApp: "Поиск приложения",
    searchAppPlaceholder: "например, Sports Stream",
    faculty: "Факультет",
    yearIntake: "Год набора",
    deviceId: "ID устройства",
    ownerName: "Владелец",
    year: "Год",
    lastSeen: "Последняя активность",
    connection: "Подключение",
    deviceDetails: "Данные устройства",
    from: "С",
    to: "По",
    screenTime: "Экранное время",
    appUsage: "Использование приложений",
    noAppUsageYet: "Пока нет данных по приложениям.",
    dailyUsage: "Дневное использование",
    date: "Дата",
    app: "Приложение",
    package: "Пакет",
    icon: "Иконка",
    includeSystemApps: "Показывать системные приложения",
    selectDevicePrompt: "Выберите устройство из списка.",
    noDevicesFound: "Устройства не найдены.",
    noAppsFound: "Приложения не найдены.",
    noDailyUsage: "Нет данных об использовании.",
    loadingDetails: "Загрузка данных...",
    todayRange: "Сегодня",
    rangeLabel: "{from} - {to}",
    systemAppBadge: "системное приложение",
    createEditDevice: "Создать / Изменить устройство",
    addDevice: "Добавить устройство",
    deviceCreated: "Устройство создано",
    actions: "Действия",
    edit: "Изменить",
    delete: "Удалить",
    editDevice: "Изменить устройство",
    editSelectedDevices: "Изменить выбранные устройства",
    selectedDevicesCount: "Выбрано устройств: {count}.",
    save: "Сохранить",
    deleteDeviceConfirm: "Удалить устройство {deviceId}?",
    deleteSelectedDevicesConfirm: "Удалить выбранные устройства: {count}?",
    editSelectedDevicesAction: "Изменить {count} устройств",
    deleteSelectedDevicesAction: "Удалить {count} устройств",
    deletedWithFailures: "Удалено, ошибок: {count}.",
    savedWithFailures: "Сохранено, ошибок: {count}.",
    mainCategoryTitle: "Основная категория (факультет)",
    subCategoryTitle: "Подкатегория (год набора)",
    name: "Название",
    addMainCategory: "Добавить основную категорию",
    addSubCategory: "Добавить подкатегорию",
    noMainCategories: "Нет основных категорий.",
    noSubCategories: "Нет подкатегорий.",
    main: "Основная",
    sub: "Подкатегория",
    deleteMainCategoryConfirm: "Удалить основную категорию {name}?",
    deleteSubCategoryConfirm: "Удалить подкатегорию {label}?",
    editMainCategory: "Изменить основную категорию",
    editSubCategory: "Изменить подкатегорию",
    exportUsageData: "Экспорт данных использования",
    exportHelp: "Экспортируйте данные использования по факультету и году набора в файл Excel.",
    export: "Экспорт",
    chooseFacultyYear: "Выберите факультет и год набора.",
    chooseValidDateRange: "Выберите корректный диапазон дат.",
    preparingExport: "Подготовка экспорта...",
    exportedDevices: "Экспортировано устройств: {count}.",
    exportFailed: "Ошибка экспорта: {message}",
    adminBackendUrl: "Backend URL",
    adminBackendUrlHelp: "Управляйте адресом backend, который использует это веб-приложение в данном браузере.",
    backendUrlSaved: "Backend URL сохранен.",
    users: "Пользователи",
    createUser: "Создать пользователя",
    creatingUser: "Создание пользователя...",
    userCreated: "Пользователь создан.",
    loadingUsers: "Загрузка пользователей...",
    noUsersFound: "Пользователи не найдены.",
    updated: "Обновлено",
    newPassword: "Новый пароль",
    savePassword: "Сохранить пароль",
    enterNewPasswordFirst: "Сначала введите новый пароль.",
    updatingUser: "Обновление {username}...",
    passwordUpdatedForUser: "Пароль обновлен для {username}.",
    passwordUpdateFailed: "Ошибка обновления пароля: {message}",
    adminAuthenticationRequired: "Требуется аутентификация администратора",
    saveUserChangesConfirm: "Сохранить новый пароль для {username}?",
    userDeleted: "Пользователь {username} удален.",
    userDeleteFailed: "Не удалось удалить пользователя: {message}",
    deleteUserConfirm: "Удалить пользователя {username}?",
  },
};

const BACKEND_ERROR_KEYS = {
  Unauthorized: "unauthorized",
  "Not found": "notFound",
  "Invalid credentials": "invalidCredentials",
  "Missing required field: name": "missingName",
  "Missing required fields: name, main_category_id": "missingNameMain",
  "Main category not found": "categoryMainNotFound",
  "Sub category not found": "categorySubNotFound",
  "Sub category does not belong to selected main category": "categoryMismatch",
  "Missing required fields: device_id, main_category_id, sub_category_id": "missingDeviceCategoryFields",
  "Device ID already exists": "deviceIdExists",
  "Device not found": "deviceNotFound",
  "Device is not active": "deviceInactive",
  "Query params 'main_category_id' and 'sub_category_id' are required": "chooseFacultyYear",
  "Selected faculty or year intake was not found": "selectedCategoryNotFound",
  "Missing required fields: device_id, client_instance_id": "missingDeviceClientFields",
  "Unknown or inactive device ID": "unknownOrInactiveDeviceId",
  "This device installation is blocked for this device ID": "blockedDeviceInstallation",
  "Device ID already linked to another physical device": "deviceLinkedAnotherPhysical",
  "Missing required fields: device_id": "missingDeviceIdField",
  "Device ID is not linked to this physical device": "deviceNotLinkedThisPhysical",
  "Each usage session must include package_name": "usageSessionMissingPackage",
  "foreground_ms cannot be negative": "negativeForegroundMs",
  "Each app must include package_name and app_name": "appMissingPackageAndName",
  "Query params 'from' and 'to' are required": "missingRangeParams",
  "'to' must be later than 'from'": "invalidRangeOrder",
  "Maximum range is 62 days": "maxRange",
  "'apps' and 'usage_sessions' must be arrays": "invalidArraysPayload",
  "Missing required fields: username, password": "missingUsernamePassword",
  "User already exists": "userAlreadyExists",
  "User not found": "userNotFound",
};
function normalizeBackendUrl(value) {
  const trimmed = String(value || "").trim();
  if (!trimmed) {
    return "";
  }
  return trimmed.replace(/\/+$/, "");
}

function normalizeLanguage(value) {
  const code = String(value || "").trim().toLowerCase();
  if (code === "tm" || code === "tr") {
    return "tk";
  }
  if (code === "en" || code === "ru" || code === "tk") {
    return code;
  }
  return DEFAULT_LANGUAGE;
}

const storedBackendUrl = normalizeBackendUrl(localStorage.getItem(BACKEND_URL_KEY));
const hasStoredLanguage = localStorage.getItem(LANGUAGE_KEY) != null;
const storedLanguage = normalizeLanguage(localStorage.getItem(LANGUAGE_KEY));
if (!hasStoredLanguage) {
  localStorage.setItem(LANGUAGE_KEY, DEFAULT_LANGUAGE);
}
const resolvedBackendUrl = storedBackendUrl || normalizeBackendUrl(BACKEND_BASE_URL);

const appState = {
  backendUrl: resolvedBackendUrl,
  adminToken: localStorage.getItem("usage_admin_token") || "",
  language: storedLanguage || DEFAULT_LANGUAGE,
  mainCategories: [],
  subCategories: [],
};

function t(key, vars = {}) {
  const bundle = UI_STRINGS[appState.language] || UI_STRINGS[DEFAULT_LANGUAGE];
  const fallback = UI_STRINGS.en || {};
  const template = bundle[key] ?? fallback[key] ?? key;
  return String(template).replace(/\{(\w+)\}/g, (_, token) => String(vars[token] ?? ""));
}

function tRich(key, vars = {}, boldKeys = []) {
  const bundle = UI_STRINGS[appState.language] || UI_STRINGS[DEFAULT_LANGUAGE];
  const fallback = UI_STRINGS.en || {};
  const template = bundle[key] ?? fallback[key] ?? key;
  const emphasized = new Set(boldKeys);
  return String(template).replace(/\{(\w+)\}/g, (_, token) => {
    const safeValue = escapeHtml(vars[token] ?? "");
    return emphasized.has(token) ? `<strong>${safeValue}</strong>` : safeValue;
  });
}

function setLanguage(nextLanguage) {
  const normalized = normalizeLanguage(nextLanguage);
  appState.language = normalized;
  localStorage.setItem(LANGUAGE_KEY, normalized);
  document.documentElement.lang = normalized;
  applySharedTranslations();
  document.dispatchEvent(new CustomEvent("usage-language-changed", { detail: { language: normalized } }));
}

function translateBackendError(message) {
  const raw = String(message || "").trim();
  if (!raw) {
    return raw;
  }
  if (BACKEND_ERROR_KEYS[raw]) {
    return t(BACKEND_ERROR_KEYS[raw]);
  }
  if (raw.startsWith("Internal error:")) {
    return t("backendInternalError", { detail: raw.slice("Internal error:".length).trim() });
  }
  if (raw.startsWith("DB error:")) {
    return t("backendDbError", { detail: raw.slice("DB error:".length).trim() });
  }
  if (/^HTTP\s+\d+$/i.test(raw)) {
    return t("genericHttpError", { status: raw.replace(/\D+/g, "") });
  }
  return raw;
}

function ensureLanguageButton(container) {
  if (!container || container.querySelector(".language-btn")) {
    return;
  }
  const button = document.createElement("button");
  button.type = "button";
  button.className = "language-btn";
  button.addEventListener("click", () => openLanguageDialog());
  container.prepend(button);
}

function updateLanguageButtons() {
  document.querySelectorAll(".language-btn").forEach((button) => {
    button.textContent = `${t("language")}: ${LANGUAGE_LABELS[appState.language]}`;
  });
}

function getPageTitleKey(activePage) {
  switch (activePage) {
    case "dashboard":
      return "pageTitleDashboard";
    case "categories":
      return "pageTitleCategories";
    case "devices":
      return "pageTitleDevices";
    case "export":
      return "pageTitleExport";
    case "admin":
      return "pageTitleAdmin";
    default:
      return "appName";
  }
}

function setDocumentTitle(activePage) {
  const titleKey = getPageTitleKey(activePage);
  document.title = `${t("appName")} - ${t(titleKey)}`;
}

function applyDataTranslations(root = document) {
  root.querySelectorAll("[data-i18n]").forEach((el) => {
    el.textContent = t(el.dataset.i18n);
  });
  root.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
    el.setAttribute("placeholder", t(el.dataset.i18nPlaceholder));
  });
  root.querySelectorAll("[data-i18n-title]").forEach((el) => {
    el.setAttribute("title", t(el.dataset.i18nTitle));
  });
}

function applySharedTranslations() {
  applyDataTranslations(document);
  updateLanguageButtons();
  const activePage = document.body?.dataset?.activePage || "";
  if (activePage) {
    renderTopNav(activePage);
    setDocumentTitle(activePage);
  }
  if (confirmModal) {
    confirmModal.title.textContent = t("confirm");
    confirmModal.cancel.textContent = t("cancel");
    confirmModal.confirm.textContent = t("confirm");
  }
  if (languageModal) {
    languageModal.title.textContent = t("languageDialogTitle");
    languageModal.label.textContent = t("currentLanguage");
    languageModal.cancel.textContent = t("cancel");
    languageModal.save.textContent = t("save");
    languageModal.select.innerHTML = Object.entries(LANGUAGE_LABELS)
      .map(([code, label]) => `<option value="${escapeHtml(code)}">${escapeHtml(label)}</option>`)
      .join("");
    languageModal.select.value = appState.language;
  }
}

function renderTopNav(activePage) {
  const nav = document.getElementById("topNav");
  if (!nav) {
    return;
  }
  nav.innerHTML = `
    <a class="nav-link ${activePage === "dashboard" ? "active" : ""}" href="./index.html">${escapeHtml(t("navDashboard"))}</a>
    <a class="nav-link ${activePage === "categories" ? "active" : ""}" href="./categories.html">${escapeHtml(t("navCategories"))}</a>
    <a class="nav-link ${activePage === "devices" ? "active" : ""}" href="./devices.html">${escapeHtml(t("navDevices"))}</a>
    <a class="nav-link ${activePage === "export" ? "active" : ""}" href="./export.html">${escapeHtml(t("navExport"))}</a>
  `;
}

function initSharedLayout(activePage) {
  document.body.dataset.activePage = activePage;
  document.documentElement.lang = appState.language;
  setDocumentTitle(activePage);
  renderTopNav(activePage);
  ensureLanguageButton(document.querySelector(".topbar-actions"));
  applySharedTranslations();

  const logoutBtn = document.getElementById("logoutBtn");
  if (logoutBtn && !logoutBtn.dataset.bound) {
    logoutBtn.dataset.bound = "1";
    logoutBtn.addEventListener("click", async () => {
      const ok = await confirmDialog(t("logOutConfirm"), t("confirm"), t("cancel"));
      if (!ok) {
        return;
      }
      appState.adminToken = "";
      localStorage.removeItem("usage_admin_token");
      refreshAuthState();
    });
  }
}

function initAuth(onReady) {
  const loginOverlay = document.getElementById("loginOverlay");
  const loginForm = document.getElementById("loginForm");
  const loginStatus = document.getElementById("loginStatus");
  const loginUsernameInput = document.getElementById("loginUsernameInput");
  const loginPasswordInput = document.getElementById("loginPasswordInput");

  if (!loginForm || !loginOverlay) {
    onReady();
    return;
  }

  applySharedTranslations();

  if (!loginForm.dataset.bound) {
    loginForm.dataset.bound = "1";
    loginForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      loginStatus.textContent = t("loggingIn");
      try {
        const payload = await apiPost("/api/v1/login", { username: loginUsernameInput.value.trim(), password: loginPasswordInput.value.trim() }, false);
        appState.adminToken = payload.token;
        localStorage.setItem("usage_admin_token", payload.token);
        loginPasswordInput.value = "";
        loginStatus.textContent = t("loginSuccess");
        refreshAuthState();
        await onReady();
      } catch (err) {
        loginStatus.textContent = t("loginFailed", { message: err.message });
      }
    });
  }

  refreshAuthState();
  if (appState.adminToken) {
    onReady();
  }
}
function refreshAuthState() {
  const loginOverlay = document.getElementById("loginOverlay");
  if (loginOverlay) {
    loginOverlay.classList.toggle("hidden", !!appState.adminToken);
  }
  const authContent = document.getElementById("authContent");
  if (authContent) {
    authContent.classList.toggle("hidden", !appState.adminToken);
  }
}

async function loadCategories() {
  const [mainResp, subResp] = await Promise.all([apiGet("/api/v1/main-categories"), apiGet("/api/v1/sub-categories")]);
  appState.mainCategories = mainResp.main_categories || [];
  appState.subCategories = subResp.sub_categories || [];
}

function renderMainCategorySelect(selectEl, includeAll = false) {
  if (!selectEl) {
    return;
  }
  const current = selectEl.value;
  const options = [];
  if (includeAll) {
    options.push(`<option value="">${escapeHtml(t("all"))}</option>`);
  }
  appState.mainCategories.forEach((cat) => {
    options.push(`<option value="${cat.id}">${escapeHtml(cat.name)}</option>`);
  });
  selectEl.innerHTML = options.join("");
  if (current && [...selectEl.options].some((o) => o.value === current)) {
    selectEl.value = current;
  }
}

function renderSubCategorySelect(selectEl, mainCategoryId, includeAll = false) {
  if (!selectEl) {
    return;
  }
  const current = selectEl.value;
  const options = [];
  if (includeAll) {
    options.push(`<option value="">${escapeHtml(t("all"))}</option>`);
  }
  const filtered = mainCategoryId ? appState.subCategories.filter((s) => s.main_category_id === Number(mainCategoryId)) : appState.subCategories;
  filtered.forEach((sub) => {
    options.push(`<option value="${sub.id}">${escapeHtml(sub.name)}</option>`);
  });
  selectEl.innerHTML = options.join("");
  if (current && [...selectEl.options].some((o) => o.value === current)) {
    selectEl.value = current;
  }
}

function paginate(items, page, pageSize = PAGE_SIZE) {
  const totalPages = Math.max(1, Math.ceil(items.length / pageSize));
  const clampedPage = Math.min(Math.max(1, page), totalPages);
  const from = (clampedPage - 1) * pageSize;
  return { page: clampedPage, totalPages, items: items.slice(from, from + pageSize) };
}

function renderPagination(containerEl, page, totalPages, onPageChange) {
  if (!containerEl) {
    return;
  }
  if (totalPages <= 1) {
    containerEl.innerHTML = "";
    return;
  }
  const buttons = [];
  for (let i = 1; i <= totalPages; i += 1) {
    buttons.push(`<button type="button" class="page-btn ${i === page ? "active" : ""}" data-page="${i}">${i}</button>`);
  }
  containerEl.innerHTML = `<div class="pagination">${buttons.join("")}</div>`;
  containerEl.querySelectorAll(".page-btn").forEach((btn) => {
    btn.addEventListener("click", () => onPageChange(Number(btn.dataset.page)));
  });
}

function formatDuration(ms) {
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  return `${hours}h ${minutes}m`;
}

function formatTurkmenTime(isoValue) {
  if (!isoValue) {
    return t("never");
  }
  const dt = new Date(isoValue);
  if (Number.isNaN(dt.getTime())) {
    return String(isoValue);
  }
  return new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Ashgabat", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false }).format(dt);
}

function getConnectionStatus(isConnected) {
  return isConnected ? { label: t("connected"), className: "status-connected" } : { label: t("notConnected"), className: "status-disconnected" };
}

function renderConnectionIcon(isConnected) {
  const src = isConnected ? "./assets/check.png" : "./assets/remove.png";
  const alt = isConnected ? t("connected") : t("notConnected");
  return `<img class="conn-icon" src="${src}" alt="${escapeHtml(alt)}" />`;
}

function escapeHtml(value) {
  return String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}

function authHeaders(requireAuth = true) {
  const headers = { "Content-Type": "application/json" };
  if (requireAuth && appState.adminToken) {
    headers.Authorization = `Bearer ${appState.adminToken}`;
  }
  return headers;
}

async function handleApiResponse(response) {
  const payload = await safeJson(response);
  if (response.status === 401) {
    onUnauthorized();
    throw new Error(t("unauthorized"));
  }
  if (!response.ok) {
    throw new Error(translateBackendError(payload.error || `HTTP ${response.status}`));
  }
  return payload;
}

async function apiGet(path, requireAuth = true) {
  const response = await fetch(`${appState.backendUrl}${path}`, { headers: authHeaders(requireAuth) });
  return handleApiResponse(response);
}

async function apiPost(path, body, requireAuth = true) {
  const response = await fetch(`${appState.backendUrl}${path}`, { method: "POST", headers: authHeaders(requireAuth), body: JSON.stringify(body) });
  return handleApiResponse(response);
}

async function apiPut(path, body, requireAuth = true) {
  const response = await fetch(`${appState.backendUrl}${path}`, { method: "PUT", headers: authHeaders(requireAuth), body: JSON.stringify(body) });
  return handleApiResponse(response);
}

async function apiDelete(path, requireAuth = true) {
  const response = await fetch(`${appState.backendUrl}${path}`, { method: "DELETE", headers: authHeaders(requireAuth) });
  return handleApiResponse(response);
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch (_) {
    const text = await response.text();
    return { error: text || `HTTP ${response.status}` };
  }
}

function onUnauthorized() {
  appState.adminToken = "";
  localStorage.removeItem("usage_admin_token");
  refreshAuthState();
}

const confirmModal = createConfirmModal();
const languageModal = createLanguageModal();

function confirmDialog(message, confirmText = t("confirm"), cancelText = t("cancel")) {
  return new Promise((resolve) => {
    confirmModal.title.textContent = t("confirm");
    confirmModal.message.textContent = message;
    confirmModal.confirm.textContent = confirmText;
    confirmModal.cancel.textContent = cancelText;
    confirmModal.overlay.classList.remove("hidden");
    const cleanup = (value) => {
      confirmModal.overlay.classList.add("hidden");
      confirmModal.confirm.removeEventListener("click", onConfirm);
      confirmModal.cancel.removeEventListener("click", onCancel);
      confirmModal.overlay.removeEventListener("click", onOverlay);
      resolve(value);
    };
    const onConfirm = () => cleanup(true);
    const onCancel = () => cleanup(false);
    const onOverlay = (event) => { if (event.target === confirmModal.overlay) { cleanup(false); } };
    confirmModal.confirm.addEventListener("click", onConfirm);
    confirmModal.cancel.addEventListener("click", onCancel);
    confirmModal.overlay.addEventListener("click", onOverlay);
  });
}

function createConfirmModal() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay hidden";
  overlay.innerHTML = '<div class="modal-card"><h3 class="modal-title"></h3><p class="status modal-message"></p><div class="modal-actions"><button type="button" class="modal-cancel"></button><button type="button" class="danger modal-confirm"></button></div></div>';
  document.body.appendChild(overlay);
  return { overlay, title: overlay.querySelector(".modal-title"), message: overlay.querySelector(".modal-message"), confirm: overlay.querySelector(".modal-confirm"), cancel: overlay.querySelector(".modal-cancel") };
}

function createLanguageModal() {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay hidden";
  overlay.innerHTML = '<div class="modal-card language-modal-card"><h3 class="modal-title"></h3><label class="field language-modal-field"><span class="language-modal-label"></span><select class="language-modal-select"></select></label><div class="modal-actions"><button type="button" class="modal-cancel"></button><button type="button" class="modal-confirm"></button></div></div>';
  document.body.appendChild(overlay);
  const title = overlay.querySelector(".modal-title");
  const label = overlay.querySelector(".language-modal-label");
  const select = overlay.querySelector(".language-modal-select");
  const cancel = overlay.querySelector(".modal-cancel");
  const save = overlay.querySelector(".modal-confirm");
  const close = () => overlay.classList.add("hidden");
  cancel.addEventListener("click", close);
  save.addEventListener("click", () => {
    setLanguage(select.value);
    close();
  });
  overlay.addEventListener("click", (event) => { if (event.target === overlay) { close(); } });
  select.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      save.click();
    }
  });
  return { overlay, title, label, select, cancel, save };
}

function openLanguageDialog() {
  applySharedTranslations();
  languageModal.select.value = appState.language;
  languageModal.overlay.classList.remove("hidden");
  languageModal.select.focus();
}

const contextMenu = createContextMenu();

function showContextMenu(x, y, items) {
  if (!contextMenu) {
    return;
  }
  contextMenu.items = items || [];
  contextMenu.list.innerHTML = contextMenu.items.map((item, idx) => `<button type="button" class="context-item" data-index="${idx}" ${item.disabled ? "disabled" : ""}>${escapeHtml(item.label)}</button>`).join("");
  contextMenu.list.querySelectorAll(".context-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      const index = Number(btn.dataset.index);
      const item = contextMenu.items[index];
      hideContextMenu();
      if (item && !item.disabled && typeof item.onClick === "function") { item.onClick(); }
    });
  });
  contextMenu.overlay.style.left = `${x}px`;
  contextMenu.overlay.style.top = `${y}px`;
  contextMenu.overlay.classList.remove("hidden");
}

function hideContextMenu() {
  if (contextMenu) {
    contextMenu.overlay.classList.add("hidden");
  }
}

function createContextMenu() {
  const overlay = document.createElement("div");
  overlay.className = "context-menu hidden";
  overlay.innerHTML = '<div class="context-list"></div>';
  document.body.appendChild(overlay);
  const list = overlay.querySelector(".context-list");
  document.addEventListener("click", (event) => { if (!overlay.contains(event.target)) { hideContextMenu(); } });
  document.addEventListener("contextmenu", (event) => { if (!overlay.contains(event.target)) { hideContextMenu(); } });
  document.addEventListener("keydown", (event) => { if (event.key === "Escape") { hideContextMenu(); } });
  window.addEventListener("resize", hideContextMenu);
  window.addEventListener("scroll", hideContextMenu, true);
  return { overlay, list, items: [] };
}

applySharedTranslations();
