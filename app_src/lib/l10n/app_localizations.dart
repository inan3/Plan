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
      'account_title': 'Cuenta',
      'edit_profile': 'Editar perfil',
      'change_password': 'Cambiar la contraseña de tu cuenta',
      'delete_profile': 'Eliminar mi perfil',
      'delete_confirmation': 'Confirmar eliminación',
      'delete_question': '¿Estás seguro de que quieres eliminar tu perfil?',
      'cancel': 'Cancelar',
      'accept': 'Aceptar',
      'account_deleted': 'Tu cuenta se ha eliminado correctamente.',
      'no_plans_title': 'No tienes planes creados aún...',
      'create_new_question': '¿Creamos uno nuevo?',
      'plan_invited': 'Has invitado a tu plan: {plan}',
      'choose_plan_type_missing': 'Falta elegir tipo de plan.',
      'choose_date_missing': 'Falta elegir la fecha/hora del plan.',
      'choose_location_missing': 'Falta elegir ubicación del plan.',
      'choose_description_missing': 'Falta la breve descripción del plan.',
      'plan_created_invited_user': '¡Plan creado! Has invitado al usuario.',
      'plan_creation_error': 'Error al crear el plan: {error}',
      'location_permission_denied': 'Permiso de ubicación denegado',
      'location_permission_denied_forever':
          'El permiso de ubicación está denegado permanentemente, no se puede solicitar',
      'address_not_found': 'Dirección no encontrada',
      'address_not_available': 'Dirección no disponible',
      'error_getting_location': 'Error al obtener la ubicación',
      'select_location_prompt': 'Por favor, selecciona una ubicación.',
      'describe_plan_hint': 'Describe brevemente tu plan...'
      ,'profile_updated': 'Perfil actualizado'
      ,'verify_email_title': 'Verifica tu correo'
      ,'verify_email_body': 'Se ha enviado un correo de verificación a {email}. Sigue el enlace recibido para continuar.'
      ,'error_register': 'Error al registrarte: {error}'
      ,'create_account': 'Crea tu cuenta'
      ,'continue_with_google': 'Continuar con Google'
      ,'or': '- o -'
      ,'email_hint': 'Correo electrónico'
      ,'password_hint': 'Contraseña'
      ,'register_button': 'Registrarse'
      ,'have_account': '¿Ya tienes una cuenta? Inicia sesión'
      ,'login_title': 'Inicio de sesión'
      ,'login_button': 'Iniciar sesión'
      ,'forgot_password': '¿Olvidaste tu contraseña?'
      ,'google_login_error': 'Error de inicio de sesión con Google.'
      ,'no_profile_title': 'No estás registrado'
      ,'no_profile_body': 'No hay ningún perfil en la base de datos para este usuario. Debes registrarte primero.'
      ,'login_error_title': 'Error de inicio de sesión'
      ,'invalid_credentials': 'Correo o contraseña incorrectos.'
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
      'account_title': 'Account',
      'edit_profile': 'Edit profile',
      'change_password': 'Change account password',
      'delete_profile': 'Delete my profile',
      'delete_confirmation': 'Confirm deletion',
      'delete_question': 'Are you sure you want to delete your profile?',
      'cancel': 'Cancel',
      'accept': 'Accept',
      'account_deleted': 'Your account has been successfully deleted.',
      'no_plans_title': 'You have no plans created yet...',
      'create_new_question': 'Create a new one?',
      'plan_invited': 'You have invited to your plan: {plan}',
      'choose_plan_type_missing': 'Please choose a plan type.',
      'choose_date_missing': 'Please choose a plan date/time.',
      'choose_location_missing': 'Please choose a plan location.',
      'choose_description_missing': 'Please provide a brief plan description.',
      'plan_created_invited_user': 'Plan created! You have invited the user.',
      'plan_creation_error': 'Error creating plan: {error}',
      'location_permission_denied': 'Location permission denied',
      'location_permission_denied_forever':
          'Location permission is permanently denied, cannot request it',
      'address_not_found': 'Address not found',
      'address_not_available': 'Address not available',
      'error_getting_location': 'Error getting location',
      'select_location_prompt': 'Please select a location.',
      'describe_plan_hint': 'Briefly describe your plan...'
      ,'profile_updated': 'Profile updated'
      ,'verify_email_title': 'Verify your email'
      ,'verify_email_body': 'A verification email has been sent to {email}. Follow the link to continue.'
      ,'error_register': 'Error registering: {error}'
      ,'create_account': 'Create your account'
      ,'continue_with_google': 'Continue with Google'
      ,'or': '- or -'
      ,'email_hint': 'Email'
      ,'password_hint': 'Password'
      ,'register_button': 'Sign up'
      ,'have_account': 'Already have an account? Log in'
      ,'login_title': 'Log in'
      ,'login_button': 'Log in'
      ,'forgot_password': 'Forgot your password?'
      ,'google_login_error': 'Google sign-in error.'
      ,'no_profile_title': 'Not registered'
      ,'no_profile_body': 'No profile found for this user. Please register first.'
      ,'login_error_title': 'Login error'
      ,'invalid_credentials': 'Incorrect email or password.'
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
  String get accountTitle => _t('account_title');
  String get editProfile => _t('edit_profile');
  String get changePassword => _t('change_password');
  String get deleteProfile => _t('delete_profile');
  String get deleteConfirmation => _t('delete_confirmation');
  String get deleteQuestion => _t('delete_question');
  String get cancel => _t('cancel');
  String get accept => _t('accept');
  String get accountDeleted => _t('account_deleted');
  String get noPlansTitle => _t('no_plans_title');
  String get createNewQuestion => _t('create_new_question');
  String get planInvited => _t('plan_invited');
  String get choosePlanTypeMissing => _t('choose_plan_type_missing');
  String get chooseDateMissing => _t('choose_date_missing');
  String get chooseLocationMissing => _t('choose_location_missing');
  String get chooseDescriptionMissing => _t('choose_description_missing');
  String get planCreatedInvitedUser => _t('plan_created_invited_user');
  String get planCreationError => _t('plan_creation_error');
  String get locationPermissionDenied => _t('location_permission_denied');
  String get locationPermissionDeniedForever =>
      _t('location_permission_denied_forever');
  String get addressNotFound => _t('address_not_found');
  String get addressNotAvailable => _t('address_not_available');
  String get errorGettingLocation => _t('error_getting_location');
  String get selectLocationPrompt => _t('select_location_prompt');
  String get describePlanHint => _t('describe_plan_hint');
  String get profileUpdated => _t('profile_updated');
  String get verifyEmailTitle => _t('verify_email_title');
  String verifyEmailBody(String email) =>
      _t('verify_email_body').replaceAll('{email}', email);
  String errorRegister(String error) =>
      _t('error_register').replaceAll('{error}', error);
  String get createAccount => _t('create_account');
  String get continueWithGoogle => _t('continue_with_google');
  String get or => _t('or');
  String get emailHint => _t('email_hint');
  String get passwordHint => _t('password_hint');
  String get registerButton => _t('register_button');
  String get haveAccount => _t('have_account');
  String get loginTitle => _t('login_title');
  String get loginButton => _t('login_button');
  String get forgotPassword => _t('forgot_password');
  String get googleLoginError => _t('google_login_error');
  String get noProfileTitle => _t('no_profile_title');
  String get noProfileBody => _t('no_profile_body');
  String get loginErrorTitle => _t('login_error_title');
  String get invalidCredentials => _t('invalid_credentials');

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
