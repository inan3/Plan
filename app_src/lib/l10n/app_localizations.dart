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
      ,'my_plans': 'Mis Planes'
      ,'subscribed_plans': 'Planes Suscritos'
      ,'favourites': 'Favoritos'
      ,'logout': 'Cerrar Sesión'
      ,'created_plans_list': 'Mi lista de planes creados'
      ,'subscribed_plans_list': 'Mi lista de planes suscritos'
      ,'favourite_plans_list': 'Mi lista de planes favoritos'
      ,'select_plans': 'Seleccionar Planes'
      ,'my_plans_tab': 'Mis Planes'
      ,'subscribed_tab': 'Suscritos'
      ,'go_to_my_plans': 'Dirígete a la sección de "Mis Planes" para compartirlo con quien quieras.'
      ,'private_plans_info': 'Los planes privados son visibles solo por aquellos a quienes se lo compartas. Dirígete a la sección de "Mis Planes" para compartirlo con quien quieras.'
      ,'public_plans_info': 'Los planes públicos son visibles a todo el mundo y cualquiera puede unirse a él'
      ,'invite_plan_label': 'Invitar a un Plan'
      ,'invite_plan_title': 'Invítale a un plan'
      ,'existing': 'Existente'
      ,'new': 'Nuevo'
      ,'select_one_of_your_plans': 'Selecciona uno de tus planes'
      ,'created_on': 'Creado el: {date}'
      ,'confirm_invitation': 'Confirmar invitación'
      ,'new_private_plan_label': 'Nuevo Plan Privado'
      ,'private_plan_invite_title': '¡Crea tu Plan Privado e Invita!'
      ,'all_day': 'Todo el día'
      ,'include_end_date': 'Incluir fecha final'
      ,'start_date': 'Fecha de inicio'
      ,'end_date': 'Fecha final'
      ,'error': 'Error'
      ,'attention': 'Atención'
      ,'preview': 'Vista previa'
      ,'check_in_for_attendees': 'Check-in para asistentes'
      ,'plan_does_not_exist': 'Plan no existe'
      ,'check_in_not_active': 'El check-in no está activo.\nPresiona atrás para iniciar.'
      ,'generating_code': 'Generando código...'
      ,'finalize_check_in': 'Finalizar Check-in'
      ,'confirm_attendance': 'Confirmar asistencia'
      ,'enter_code_manually': 'Si no puedes escanear el código QR,\ningrésalo manualmente:'
      ,'alphanumeric_code': 'Código alfanumérico'
      ,'validate_code': 'Validar código'
      ,'invalid_code': 'El código es incorrecto o el check-in no está activo.'
      ,'attendance_confirmed': 'Tu asistencia se ha confirmado con éxito.\n¡Disfruta del evento!'
      ,'start_check_in': 'Iniciar Check-in'
      ,'view_check_in': 'Ver Check-in (QR)'
      ,'plan_detail': 'Detalle del Plan'
      ,'delete': 'Eliminar'
      ,'plan_deleted': 'Plan {plan} eliminado.'
      ,'no_memories_day': 'No hay memorias para este día.'
      ,'close': 'Cerrar'
      ,'followers': 'Mis seguidores'
      ,'following': 'A quienes sigo'
      ,'search_user_hint': 'Buscar usuario...'
      ,'report_user_title': 'Reportar Usuario'
      ,'report_reasons_prompt': 'Selecciona los motivos por los que deseas reportar este perfil'
      ,'reason_inappropriate_content': 'Contenido inapropiado'
      ,'reason_impersonation': 'Suplantación de identidad'
      ,'reason_spam': 'Spam o publicitario'
      ,'reason_abusive_behavior': 'Lenguaje o comportamiento abusivo'
      ,'reason_inappropriate_images': 'Imágenes inapropiadas'
      ,'reason_other_specify': 'Otro (especificar)'
      ,'why_report_question': '¿Por qué quieres reportar este perfil? (opcional)'
      ,'describe_briefly': 'Describe brevemente...'
      ,'back': 'Volver'
      ,'report_success': 'Reporte enviado con éxito'
      ,'report_error': 'Ocurrió un error al enviar reporte.'
      ,'report_profile': 'Reportar Perfil'
      ,'block_profile': 'Bloquear Perfil'
      ,'unblock_profile': 'Desbloquear Perfil'
      ,'profile_blocked': 'Perfil Bloqueado'
      ,'profile_unblocked': 'Perfil Desbloqueado'
      ,'profile_blocked_msg': 'Este perfil ha sido bloqueado, ya no podrá interactuar contigo.'
      ,'profile_unblocked_msg': 'Has desbloqueado a este usuario.'
      ,'ok': 'OK'
      ,'pick_day': 'Elige Día'
      ,'pick_time': 'Elige Hora'
      ,'not_chosen': 'Sin elegir'
      ,'invite_confirmation_question': '¿Confirmas invitarle a este plan?'
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
      ,'my_plans': 'My Plans'
      ,'subscribed_plans': 'Subscribed Plans'
      ,'favourites': 'Favourites'
      ,'logout': 'Log out'
      ,'created_plans_list': 'My created plans list'
      ,'subscribed_plans_list': 'My subscribed plans list'
      ,'favourite_plans_list': 'My favorite plans list'
      ,'select_plans': 'Select Plans'
      ,'my_plans_tab': 'My Plans'
      ,'subscribed_tab': 'Subscribed'
      ,'go_to_my_plans': 'Go to the "My Plans" section to share it with anyone you want.'
      ,'private_plans_info': 'Private plans are visible only to those you share them with. Go to the "My Plans" section to share it with anyone you want.'
      ,'public_plans_info': 'Public plans are visible to everyone and anyone can join'
      ,'invite_plan_label': 'Invite to a Plan'
      ,'invite_plan_title': 'Invite them to a plan'
      ,'existing': 'Existing'
      ,'new': 'New'
      ,'select_one_of_your_plans': 'Select one of your plans'
      ,'created_on': 'Created on: {date}'
      ,'confirm_invitation': 'Confirm invitation'
      ,'new_private_plan_label': 'New Private Plan'
      ,'private_plan_invite_title': 'Create your Private Plan and Invite!'
      ,'all_day': 'All day'
      ,'include_end_date': 'Include end date'
      ,'start_date': 'Start date'
      ,'end_date': 'End date'
      ,'error': 'Error'
      ,'attention': 'Attention'
      ,'preview': 'Preview'
      ,'check_in_for_attendees': 'Check-in for attendees'
      ,'plan_does_not_exist': 'Plan does not exist'
      ,'check_in_not_active': 'Check-in is not active.\nPress back to start.'
      ,'generating_code': 'Generating code...'
      ,'finalize_check_in': 'Finalize Check-in'
      ,'confirm_attendance': 'Confirm attendance'
      ,'enter_code_manually': 'If you cannot scan the QR code,\nenter it manually:'
      ,'alphanumeric_code': 'Alphanumeric code'
      ,'validate_code': 'Validate code'
      ,'invalid_code': 'Invalid code or check-in inactive.'
      ,'attendance_confirmed': 'Your attendance has been confirmed.\nEnjoy the event!'
      ,'start_check_in': 'Start Check-in'
      ,'view_check_in': 'View Check-in (QR)'
      ,'plan_detail': 'Plan Detail'
      ,'delete': 'Delete'
      ,'plan_deleted': 'Plan {plan} deleted.'
      ,'no_memories_day': 'No memories for this day.'
      ,'close': 'Close'
      ,'followers': 'My followers'
      ,'following': 'Following'
      ,'search_user_hint': 'Search user...'
      ,'report_user_title': 'Report User'
      ,'report_reasons_prompt': 'Select the reasons you want to report this profile'
      ,'reason_inappropriate_content': 'Inappropriate content'
      ,'reason_impersonation': 'Impersonation'
      ,'reason_spam': 'Spam or advertising'
      ,'reason_abusive_behavior': 'Abusive language or behavior'
      ,'reason_inappropriate_images': 'Inappropriate images'
      ,'reason_other_specify': 'Other (specify)'
      ,'why_report_question': 'Why do you want to report this profile? (optional)'
      ,'describe_briefly': 'Describe briefly...'
      ,'back': 'Back'
      ,'report_success': 'Report sent successfully'
      ,'report_error': 'An error occurred while sending the report.'
      ,'report_profile': 'Report Profile'
      ,'block_profile': 'Block Profile'
      ,'unblock_profile': 'Unblock Profile'
      ,'profile_blocked': 'Profile Blocked'
      ,'profile_unblocked': 'Profile Unblocked'
      ,'profile_blocked_msg': 'This profile has been blocked and can no longer interact with you.'
      ,'profile_unblocked_msg': 'You have unblocked this user.'
      ,'ok': 'OK'
      ,'pick_day': 'Pick Day'
      ,'pick_time': 'Pick Time'
      ,'not_chosen': 'Not chosen'
      ,'invite_confirmation_question': 'Do you confirm inviting them to this plan?'
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
  String get myPlans => _t('my_plans');
  String get subscribedPlans => _t('subscribed_plans');
  String get favourites => _t('favourites');
  String get logout => _t('logout');
  String get createdPlansList => _t('created_plans_list');
  String get subscribedPlansList => _t('subscribed_plans_list');
  String get favouritePlansList => _t('favourite_plans_list');
  String get selectPlans => _t('select_plans');
  String get myPlansTab => _t('my_plans_tab');
  String get subscribedTab => _t('subscribed_tab');
  String get goToMyPlans => _t('go_to_my_plans');
  String get privatePlansInfo => _t('private_plans_info');
  String get publicPlansInfo => _t('public_plans_info');
  String get invitePlanLabel => _t('invite_plan_label');
  String get invitePlanTitle => _t('invite_plan_title');
  String get existing => _t('existing');
  String get newLabel => _t('new');
  String get selectOneOfYourPlans => _t('select_one_of_your_plans');
  String createdOn(String date) => _t('created_on').replaceAll('{date}', date);
  String get confirmInvitation => _t('confirm_invitation');
  String get newPrivatePlanLabel => _t('new_private_plan_label');
  String get privatePlanInviteTitle => _t('private_plan_invite_title');
  String get allDay => _t('all_day');
  String get includeEndDate => _t('include_end_date');
  String get startDate => _t('start_date');
  String get endDate => _t('end_date');
  String get error => _t('error');
  String get attention => _t('attention');
  String get preview => _t('preview');
  String get checkInForAttendees => _t('check_in_for_attendees');
  String get planDoesNotExist => _t('plan_does_not_exist');
  String get checkInNotActive => _t('check_in_not_active');
  String get generatingCode => _t('generating_code');
  String get finalizeCheckIn => _t('finalize_check_in');
  String get confirmAttendance => _t('confirm_attendance');
  String get enterCodeManually => _t('enter_code_manually');
  String get alphanumericCode => _t('alphanumeric_code');
  String get validateCode => _t('validate_code');
  String get invalidCode => _t('invalid_code');
  String get attendanceConfirmed => _t('attendance_confirmed');
  String get startCheckIn => _t('start_check_in');
  String get viewCheckIn => _t('view_check_in');
  String get planDetail => _t('plan_detail');
  String get delete => _t('delete');
  String planDeleted(String plan) => _t('plan_deleted').replaceAll('{plan}', plan);
  String get noMemoriesDay => _t('no_memories_day');
  String get close => _t('close');
  String get followers => _t('followers');
  String get following => _t('following');
  String get searchUserHint => _t('search_user_hint');
  String get reportUserTitle => _t('report_user_title');
  String get reportReasonsPrompt => _t('report_reasons_prompt');
  String get reasonInappropriateContent => _t('reason_inappropriate_content');
  String get reasonImpersonation => _t('reason_impersonation');
  String get reasonSpam => _t('reason_spam');
  String get reasonAbusiveBehavior => _t('reason_abusive_behavior');
  String get reasonInappropriateImages => _t('reason_inappropriate_images');
  String get reasonOtherSpecify => _t('reason_other_specify');
  String get whyReportQuestion => _t('why_report_question');
  String get describeBriefly => _t('describe_briefly');
  String get back => _t('back');
  String get reportSuccess => _t('report_success');
  String get reportError => _t('report_error');
  String get reportProfile => _t('report_profile');
  String get blockProfile => _t('block_profile');
  String get unblockProfile => _t('unblock_profile');
  String get profileBlocked => _t('profile_blocked');
  String get profileUnblocked => _t('profile_unblocked');
  String get profileBlockedMsg => _t('profile_blocked_msg');
  String get profileUnblockedMsg => _t('profile_unblocked_msg');
  String get ok => _t('ok');
  String get pickDay => _t('pick_day');
  String get pickTime => _t('pick_time');
  String get notChosen => _t('not_chosen');
  String get inviteConfirmationQuestion => _t('invite_confirmation_question');

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
