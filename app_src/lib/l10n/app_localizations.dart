import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static const _localizedValues = <String, Map<String, String>>{
    'es': {
      'settings': 'Ajustes',
      'general': 'Configuración general',
      'account': 'Cuenta',
      'privacy': 'Privacidad',
      'notifications': 'Notificaciones',
      'languages': 'Idiomas',
      'support': 'Soporte',
      'help_center': 'Centro de ayuda',
      'about_plan': 'Acerca de Plan',
      'rate_plan': 'Valora Plan',
      'report_failures': 'Reportar fallos de la aplicación',
      'send': 'Enviar',
      'search': 'Buscar',
      'edit_profile': 'Editar perfil',
      'change_account_password': 'Cambiar la contraseña de tu cuenta',
      'delete_profile': 'Eliminar mi perfil',
      'delete_confirmation': 'Confirmar eliminación',
      'delete_question': '¿Estás seguro de que quieres eliminar tu perfil?',
      'cancel': 'Cancelar',
      'accept': 'Aceptar',
      'delete_success': 'Tu cuenta se ha eliminado correctamente.',
      'reauth_required': 'Reautenticación requerida',
      'reauth_explanation': 'Por cuestiones de seguridad debes introducir tus credenciales de inicio de sesión para eliminar tu cuenta definitivamente',
      'reauth_failed': 'No ha sido posible autenticarte. Credenciales incorrectas.',
      'email_or_phone': 'Correo electrónico o teléfono',
      'password': 'Contraseña',
      'continue_delete': 'Continuar con la eliminación',
      'name': 'Nombre',
      'username': 'Nombre de usuario',
      'age': 'Edad',
      'save': 'Guardar',
      'change_password': 'Cambiar contraseña',
      'current_password': 'Contraseña actual',
      'new_password': 'Nueva contraseña',
      'confirm_password': 'Confirmar contraseña',
      'update': 'Actualizar',
      'invalid_fields': 'Campos inválidos',
      'profile_updated': 'Perfil actualizado',
      'check_fields': 'Revisa los campos',
      'password_updated': 'Contraseña actualizada',
      'visibility': 'Visibilidad',
      'public': 'Público',
      'private': 'Privado',
      'control_profile_visibility': 'Controla quién puede ver tu perfil.',
      'activity_privacy_desc': 'Permite que otros vean si estás en línea o tu última conexión.',
      'activity_status': 'Estado de actividad',
      'notifications_desc': 'Activa o desactiva las notificaciones globales de Plan.',
      'enable_notifications': 'Habilitar notificaciones',
      'enabled': 'Habilitado',
      'disabled': 'Deshabilitado',
      'my_plans': 'Mis Planes',
      'subscribed_plans': 'Planes Suscritos',
      'favourites': 'Favoritos',
      'close_session': 'Cerrar Sesión',
      'follow_us_also_on': 'Síguenos también en:',
      'how_help': '¿En qué te puedo ayudar?',
      'search_questions_hint': 'Buscar en preguntas...',
      'frequent_questions': 'Preguntas más frecuentes',
      'describe_failure_hint': 'Describe aquí el fallo...',
      'no_plans_yet': 'No tienes planes aún.',
      'no_joined_plans_yet': 'No te has unido a ningún plan aún...',
      'no_favourite_plans_yet': 'No tienes planes favoritos aún.',
      'location_permission_title': 'Permiso de ubicación',
      'location_permission_message':
          'El permiso de ubicación ha sido denegado permanentemente. Ve a la configuración de la app para habilitarlo.',
      'configuration': 'Configuración',
      'filter_plans': 'Filtrar Planes',
      'what_to_show': '¿Qué deseas ver?',
      'only_plans': 'Solo planes',
      'everything': 'Todo',
      'plans': 'Planes',
      'only_followed': 'Solo de personas que sigo',
      'or_separator': '- o -',
      'search_by_name_hint': 'Busca por nombre...',
      'search_region': '¿En qué región buscas planes?',
      'region_hint': 'Ciudad, país...',
      'current_location': 'Tu ubicación actual',
      'plan_date_question': '¿Para qué fecha buscas planes?',
      'select_date': 'Selecciona una fecha',
      'what_age_range': '¿Qué rango de edad?',
      'clear_filter': 'Limpiar Filtro',
    },
    'en': {
      'settings': 'Settings',
      'general': 'General settings',
      'account': 'Account',
      'privacy': 'Privacy',
      'notifications': 'Notifications',
      'languages': 'Languages',
      'support': 'Support',
      'help_center': 'Help center',
      'about_plan': 'About Plan',
      'rate_plan': 'Rate Plan',
      'report_failures': 'Report app failures',
      'send': 'Send',
      'search': 'Search',
      'edit_profile': 'Edit profile',
      'change_account_password': 'Change your account password',
      'delete_profile': 'Delete my profile',
      'delete_confirmation': 'Confirm deletion',
      'delete_question': 'Are you sure you want to delete your profile?',
      'cancel': 'Cancel',
      'accept': 'Accept',
      'delete_success': 'Your account has been deleted successfully.',
      'reauth_required': 'Reauthentication required',
      'reauth_explanation': 'For security reasons you must enter your login credentials to permanently delete your account',
      'reauth_failed': 'Unable to authenticate. Wrong credentials.',
      'email_or_phone': 'Email or phone',
      'password': 'Password',
      'continue_delete': 'Continue with deletion',
      'name': 'Name',
      'username': 'Username',
      'age': 'Age',
      'save': 'Save',
      'change_password': 'Change password',
      'current_password': 'Current password',
      'new_password': 'New password',
      'confirm_password': 'Confirm password',
      'update': 'Update',
      'invalid_fields': 'Invalid fields',
      'profile_updated': 'Profile updated',
      'check_fields': 'Check the fields',
      'password_updated': 'Password updated',
      'visibility': 'Visibility',
      'public': 'Public',
      'private': 'Private',
      'control_profile_visibility': 'Control who can see your profile.',
      'activity_privacy_desc': "Allow others to see if you're online or your last connection.",
      'activity_status': 'Activity status',
      'notifications_desc': 'Enable or disable Plan global notifications.',
      'enable_notifications': 'Enable notifications',
      'enabled': 'Enabled',
      'disabled': 'Disabled',
      'my_plans': 'My Plans',
      'subscribed_plans': 'Subscribed Plans',
      'favourites': 'Favourites',
      'close_session': 'Close Session',
      'follow_us_also_on': 'Follow us also on:',
      'how_help': 'How can I help you?',
      'search_questions_hint': 'Search in questions...',
      'frequent_questions': 'Frequently asked questions',
      'describe_failure_hint': 'Describe the issue here...',
      'no_plans_yet': "You don't have any plans yet.",
      'no_joined_plans_yet': "You haven't joined any plan yet...",
      'no_favourite_plans_yet': "You don't have any favourite plans yet.",
      'location_permission_title': 'Location permission',
      'location_permission_message':
          'Location permission has been permanently denied. Go to app settings to enable it.',
      'configuration': 'Settings',
      'filter_plans': 'Filter Plans',
      'what_to_show': 'What do you want to see?',
      'only_plans': 'Only plans',
      'everything': 'Everything',
      'plans': 'Plans',
      'only_followed': 'Only from people I follow',
      'or_separator': '- or -',
      'search_by_name_hint': 'Search by name...',
      'search_region': 'In which region are you looking for plans?',
      'region_hint': 'City, country...',
      'current_location': 'Your current location',
      'plan_date_question': 'For what date are you looking for plans?',
      'select_date': 'Select a date',
      'what_age_range': 'What age range?',
      'clear_filter': 'Clear Filter',
    },
  };

  String _t(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['es']![key] ??
        key;
  }

  String get settings => _t('settings');
  String get general => _t('general');
  String get account => _t('account');
  String get privacy => _t('privacy');
  String get notifications => _t('notifications');
  String get languages => _t('languages');
  String get support => _t('support');
  String get helpCenter => _t('help_center');
  String get aboutPlan => _t('about_plan');
  String get ratePlan => _t('rate_plan');
  String get reportFailures => _t('report_failures');
  String get send => _t('send');
  String get search => _t('search');
  String get editProfile => _t('edit_profile');
  String get changeAccountPassword => _t('change_account_password');
  String get deleteProfile => _t('delete_profile');
  String get deleteConfirmation => _t('delete_confirmation');
  String get deleteQuestion => _t('delete_question');
  String get cancel => _t('cancel');
  String get accept => _t('accept');
  String get deleteSuccess => _t('delete_success');
  String get reauthRequired => _t('reauth_required');
  String get reauthExplanation => _t('reauth_explanation');
  String get reauthFailed => _t('reauth_failed');
  String get emailOrPhone => _t('email_or_phone');
  String get password => _t('password');
  String get continueDelete => _t('continue_delete');
  String get name => _t('name');
  String get username => _t('username');
  String get age => _t('age');
  String get save => _t('save');
  String get changePassword => _t('change_password');
  String get currentPassword => _t('current_password');
  String get newPassword => _t('new_password');
  String get confirmPassword => _t('confirm_password');
  String get update => _t('update');
  String get invalidFields => _t('invalid_fields');
  String get profileUpdated => _t('profile_updated');
  String get checkFields => _t('check_fields');
  String get passwordUpdated => _t('password_updated');
  String get visibility => _t('visibility');
  String get public => _t('public');
  String get private => _t('private');
  String get controlProfileVisibility => _t('control_profile_visibility');
  String get activityPrivacyDesc => _t('activity_privacy_desc');
  String get activityStatus => _t('activity_status');
  String get notificationsDesc => _t('notifications_desc');
  String get enableNotifications => _t('enable_notifications');
  String get enabled => _t('enabled');
  String get disabled => _t('disabled');
  String get myPlans => _t('my_plans');
  String get subscribedPlans => _t('subscribed_plans');
  String get favourites => _t('favourites');
  String get closeSession => _t('close_session');
  String get followUsAlsoOn => _t('follow_us_also_on');
  String get howHelp => _t('how_help');
  String get searchQuestionsHint => _t('search_questions_hint');
  String get frequentQuestions => _t('frequent_questions');
  String get describeFailureHint => _t('describe_failure_hint');
  String get noPlansYet => _t('no_plans_yet');
  String get noJoinedPlansYet => _t('no_joined_plans_yet');
  String get noFavouritePlansYet => _t('no_favourite_plans_yet');
  String get locationPermissionTitle => _t('location_permission_title');
  String get locationPermissionMessage => _t('location_permission_message');
  String get configuration => _t('configuration');
  String get filterPlans => _t('filter_plans');
  String get whatToShow => _t('what_to_show');
  String get onlyPlans => _t('only_plans');
  String get everything => _t('everything');
  String get plans => _t('plans');
  String get onlyFollowed => _t('only_followed');
  String get orSeparator => _t('or_separator');
  String get searchByNameHint => _t('search_by_name_hint');
  String get searchRegion => _t('search_region');
  String get regionHint => _t('region_hint');
  String get currentLocation => _t('current_location');
  String get planDateQuestion => _t('plan_date_question');
  String get selectDate => _t('select_date');
  String get whatAgeRange => _t('what_age_range');
  String get clearFilter => _t('clear_filter');

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
