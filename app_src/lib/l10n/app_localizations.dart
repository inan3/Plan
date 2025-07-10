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
      'search_address_plans_hint': 'Buscar dirección o planes...',
      'search_region': '¿En qué región buscas planes?',
      'region_hint': 'Ciudad, país...',
      'current_location': 'Tu ubicación actual',
      'plan_date_question': '¿Para qué fecha buscas planes?',
      'select_date': 'Selecciona una fecha',
      'what_age_range': '¿Qué rango de edad?',
      'clear_filter': 'Limpiar Filtro',
      'new_plan': 'Nuevo Plan',
      'select_media': 'Selecciona medio',
      'what_to_upload': '¿Qué deseas subir?',
      'image_gallery': 'Imagen (galería)',
      'image_camera': 'Imagen (cámara)',
      'only_one_image': 'Solo se permite subir una imagen.',
      'attention': 'Atención',
      'ok': 'OK',
      'meeting_point': 'Punto de encuentro para el Plan',
      'meeting_location': 'Ubicación',
      'plan_date_time': 'Fecha y hora del plan',
      'edit_media': 'Editar contenido multimedia',
      'media_content': 'Contenido multimedia',
      'edit_plan_title': 'Edita tu plan como desees',
      'share_plan_title': '¡Hazle saber a la gente el plan que deseas compartir!',
      'choose_a_plan': 'Elige un plan',
      'write_plan_hint': 'Escribe tu plan...',
      'age_restriction': 'Restricción de edad para el plan',
      'max_participants': 'Máximo número de participantes',
      'enter_number': 'Ingresa un número...',
      'plan_description': 'Breve descripción del plan',
      'describe_plan': 'Describe brevemente tu plan...',
      'this_plan_is': 'Este plan es:',
      'public_plan_desc': 'Los planes públicos son visibles a todo el mundo y cualquiera puede unirse a él',
      'private_plan_desc': 'Los planes privados son visibles solo por aquellos a quienes se lo compartas. Dirígete a la sección de "Mis Planes" para compartirlo con quien quieras.',
      'followers_plan_desc': 'Estos planes solo serán visibles para las personas que te siguen.',
      'only_followers': 'Solo para mis seguidores',
      'update_plan': 'Actualizar Plan',
      'create_plan': 'Crear Plan',
      'visibility_info': 'Info Visibilidad',
      'plan_process_error': 'Ocurrió un error al procesar el plan.',
      'include_end_date': 'Incluir fecha final',
      'start_date': 'Fecha de inicio',
      'choose_date': 'Elige Fecha',
      'choose_time': 'Elige Hora',
      'end_date': 'Fecha final',
      'choose_day': 'Elige Día',
      'not_selected': 'Sin elegir',
      'preview': 'Vista previa',
      'error': 'Error',
      'must_select_start': 'Debes elegir la fecha y hora de inicio.',
      'end_after_start_error': 'La fecha final debe ser posterior a la fecha/hora de inicio.',
      'until': 'Hasta',
      'online': 'En línea',
      'offline': 'Desconectado',
      'write_message': 'Escribe un mensaje...',
      'share_location': 'Ubicación',
      'share_plan': 'Plan',
      'share_photo': 'Foto',
      'user_no_plans': 'Este usuario no ha creado planes aún...',
      'invite_to_plan': 'Invítale a un Plan',
      'join': 'Unirse',
      'join_requested': 'Unión solicitada',
      'full_capacity': 'Cupo completo',
      'participants': 'participantes',
      'participants_title': 'Participantes',
      'attends': 'ASISTE',
      'join_now': 'Únete ahora',
      'plan_chat': 'Chat del Plan',
      'location_unavailable': 'Ubicación no disponible',
      'additional_info': 'Información adicional',
      'plan_id_copied': 'ID copiado al portapapeles',
      'start_checkin': 'Iniciar Check-in',
      'view_checkin': 'Ver Check-in (QR)',
      'end_checkin': 'Finalizar Check-in',
      'checkin_instructions_creator':
          'Inicia el registro de asistencia para que los participantes escaneen el código QR o introduzcan el código de seis dígitos y confirmen su presencia en tu plan. Con cada check-in tu nivel de privilegio aumentará, lo que te permitirá aprovechar al máximo la app y, por ejemplo, crear planes de pago. Para ver tu progreso, abre tu perfil y toca la INSIGNIA situada justo debajo de tu nombre.',
      'checkin_instructions_participant':
          'Para confirmar tu asistencia, pulsa «Confirmar asistencia» y utiliza la cámara para escanear el código QR o introduce el código de seis dígitos facilitado por el organizador.',
      'checkin_not_started_title': 'Check-in no iniciado',
      'checkin_not_started_msg':
          'El organizador del plan aún no ha iniciado el Check-in. Se te notificará una vez que se haya iniciado.',
      'confirm_attendance': 'Confirmar asistencia',
      'attendance_confirmed':
          'Tu asistencia se ha confirmado con éxito.\n¡Disfruta del evento!',
      'checkin_not_active': 'El check-in no está activo.\nPresiona atrás para iniciar.',
      'generating_code': 'Generando código...',
      'alphanumeric_code': 'Código alfanumérico',
      'validate_code': 'Validar código',
      'invalid_code': 'El código es incorrecto o el check-in no está activo.',
      'no_logged_user': 'No se encontró un usuario logueado.',
      'plan_not_exists': 'Plan no existe',
      'manual_entry': 'Si no puedes escanear el código QR,\ningrésalo manualmente:',
      'error_loading_messages': 'Error al cargar mensajes',
      'no_messages_yet': 'No hay mensajes todavía',
      'disable_notifications': 'Deshabilitar notificaciones',
      'report_profile': 'Reportar perfil',
      'block_profile': 'Bloquear perfil',
      'unblock_profile': 'Desbloquear perfil',
      'profile_blocked_title': 'Perfil Bloqueado',
      'profile_unblocked_title': 'Perfil Desbloqueado',
      'profile_blocked_message':
          'Este perfil ha sido bloqueado, ya no podrá interactuar contigo.',
      'profile_unblocked_message': 'Has desbloqueado a este usuario.',
      'future_plans': 'planes futuros',
      'followers': 'seguidores',
      'following': 'seguidos',
      'send_message': 'Enviar Mensaje',
      'follow': 'Seguir',
      'following_status': 'Siguiendo',
      'requested': 'Solicitado',
      'memories': 'Memorias',
      'private_user':
          'Este usuario es privado. Debes enviar solicitud.',
      'private_profile_memories':
          'Este perfil es privado. Debes seguirle y ser aceptado para ver sus memorias.',
      'plan_and_memories': 'Plan y Memorias',
      'no_memories_day': 'No hay memorias para este día.',
      'plan_id_label': 'ID del Plan',
      'age_restriction_label': 'Restricción de edad',
      'ends_at_label': 'Finaliza',
      'future_plans': 'Planes futuros',
      'followers': 'Seguidores',
      'following': 'Seguidos',
      'memories': 'Memorias',
      'close': 'Cerrar',
      'level_basic': 'Nivel Básico',
      'level_premium': 'Nivel Premium',
      'level_golden': 'Nivel Golden',
      'level_vip': 'Nivel VIP',
      'next_hint_basic':
          'Crea 5 planes, logra 5 participantes en un solo plan y reúne 20 participantes en total para pasar al nivel de privilegio Premium.',
      'next_hint_premium':
          'Crea 50 planes, logra 50 participantes en un solo plan y reúne 2000 participantes en total para pasar al nivel de privilegio Golden.',
      'next_hint_golden':
          'Crea 500 planes, logra 500 participantes en un solo plan y reúne 10000 participantes en total para pasar al nivel de privilegio VIP.',
      'next_hint_vip': 'Estás disfrutando del nivel de privilegio VIP.',
      'info_basic': 'El nivel Básico es el más bajo. Para pasar a Premium:\n- Crear 5 planes.\n- Alcanzar 5 participantes en un plan.\n- 20 participantes en total.',
      'info_premium': 'El nivel Premium es el segundo nivel. Para pasar al siguiente nivel de Golden:\n- Crear 50 planes.\n- Máximo de 50 participantes en un plan.\n- 2000 participantes en total.',
      'info_golden': 'El nivel Golden es el penúltimo nivel. Para pasar a VIP:\n- Crear 500 planes.\n- Alcanzar 500 participantes en un plan.\n- 10000 participantes en total.',
      'info_vip': 'Este es el nivel más alto, sin límites.',
      'created_plans': 'Planes creados',
      'max_participants': 'Máx. participantes',
      'in_a_plan': 'en un plan',
      'total_participants': 'Total de participantes',
      'gathered_so_far': 'reunidos hasta ahora',
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
      'search_address_plans_hint': 'Search address or plans...',
      'search_region': 'In which region are you looking for plans?',
      'region_hint': 'City, country...',
      'current_location': 'Your current location',
      'plan_date_question': 'For what date are you looking for plans?',
      'select_date': 'Select a date',
      'what_age_range': 'What age range?',
      'clear_filter': 'Clear Filter',
      'new_plan': 'New Plan',
      'select_media': 'Select media',
      'what_to_upload': 'What would you like to upload?',
      'image_gallery': 'Image (gallery)',
      'image_camera': 'Image (camera)',
      'only_one_image': 'Only one image is allowed.',
      'attention': 'Attention',
      'ok': 'OK',
      'meeting_point': 'Meeting point for the Plan',
      'meeting_location': 'Location',
      'plan_date_time': 'Plan date and time',
      'edit_media': 'Edit media content',
      'media_content': 'Media content',
      'edit_plan_title': 'Edit your plan as you wish',
      'share_plan_title': 'Let people know the plan you want to share!',
      'choose_a_plan': 'Choose a plan',
      'write_plan_hint': 'Type your plan...',
      'age_restriction': 'Age restriction for the plan',
      'max_participants': 'Maximum number of participants',
      'enter_number': 'Enter a number...',
      'plan_description': 'Brief description of the plan',
      'describe_plan': 'Briefly describe your plan...',
      'this_plan_is': 'This plan is:',
      'public_plan_desc': 'Public plans are visible to everyone and anyone can join.',
      'private_plan_desc': 'Private plans are only visible to those you share them with. Go to "My Plans" to share it with whoever you want.',
      'followers_plan_desc': 'These plans will only be visible to people who follow you.',
      'only_followers': 'Only for my followers',
      'update_plan': 'Update Plan',
      'create_plan': 'Create Plan',
      'visibility_info': 'Visibility Info',
      'plan_process_error': 'An error occurred while processing the plan.',
      'include_end_date': 'Include end date',
      'start_date': 'Start date',
      'choose_date': 'Choose Date',
      'choose_time': 'Choose Time',
      'end_date': 'End date',
      'choose_day': 'Choose Day',
      'not_selected': 'Not selected',
      'preview': 'Preview',
      'error': 'Error',
      'must_select_start': 'You must choose a start date and time.',
      'end_after_start_error': 'The end date must be after the start date/time.',
      'until': 'Until',
      'online': 'Online',
      'offline': 'Offline',
      'write_message': 'Type a message...',
      'share_location': 'Location',
      'share_plan': 'Plan',
      'share_photo': 'Photo',
      'user_no_plans': "This user hasn't created any plans yet...",
      'invite_to_plan': 'Invite to a Plan',
      'join': 'Join',
      'join_requested': 'Join requested',
      'full_capacity': 'Full capacity',
      'participants': 'participants',
      'participants_title': 'Participants',
      'attends': 'ATTENDS',
      'join_now': 'Join now',
      'plan_chat': 'Plan Chat',
      'location_unavailable': 'Location unavailable',
      'additional_info': 'Additional information',
      'plan_id_copied': 'ID copied to clipboard',
      'start_checkin': 'Start Check-in',
      'view_checkin': 'View Check-in (QR)',
      'end_checkin': 'End Check-in',
      'checkin_instructions_creator':
          'Start attendance registration so participants can scan the QR code or enter the six-digit code and confirm their presence at your plan. With each check-in your privilege level will increase, allowing you to get the most out of the app and, for example, create paid plans. To see your progress, open your profile and tap the BADGE just below your name.',
      'checkin_instructions_participant':
          'To confirm your attendance, tap "Confirm attendance" and use the camera to scan the QR code or enter the six-digit code provided by the organizer.',
      'checkin_not_started_title': 'Check-in not started',
      'checkin_not_started_msg':
          "The organizer hasn't started Check-in yet. You'll be notified once it has started.",
      'confirm_attendance': 'Confirm attendance',
      'attendance_confirmed':
          'Your attendance has been successfully confirmed.\nEnjoy the event!',
      'checkin_not_active': 'Check-in is not active.\nPress back to start.',
      'generating_code': 'Generating code...',
      'alphanumeric_code': 'Alphanumeric code',
      'validate_code': 'Validate code',
      'invalid_code': 'The code is incorrect or check-in is not active.',
      'no_logged_user': 'No logged user found.',
      'plan_not_exists': 'Plan does not exist',
      'manual_entry': "If you can't scan the QR code,\nenter it manually:",
      'error_loading_messages': 'Error loading messages',
      'no_messages_yet': 'No messages yet',
      'disable_notifications': 'Disable notifications',
      'report_profile': 'Report profile',
      'block_profile': 'Block profile',
      'unblock_profile': 'Unblock profile',
      'profile_blocked_title': 'Profile Blocked',
      'profile_unblocked_title': 'Profile Unblocked',
      'profile_blocked_message':
          'This profile has been blocked and will no longer interact with you.',
      'profile_unblocked_message': 'You have unblocked this user.',
      'future_plans': 'Future plans',
      'followers': 'Followers',
      'following': 'Following',
      'send_message': 'Send Message',
      'follow': 'Follow',
      'following_status': 'Following',
      'requested': 'Requested',
      'memories': 'Memories',
      'private_user':
          'This account is private. You must send a request.',
      'private_profile_memories':
          'This profile is private. You must follow and be accepted to view their memories.',
      'plan_and_memories': 'Plan and Memories',
      'no_memories_day': 'No memories for this day.',
      'plan_id_label': 'Plan ID',
      'age_restriction_label': 'Age restriction',
      'ends_at_label': 'Ends',
      'future_plans': 'Future plans',
      'followers': 'Followers',
      'following': 'Following',
      'memories': 'Memories',
      'close': 'Close',
      'level_basic': 'Basic Level',
      'level_premium': 'Premium Level',
      'level_golden': 'Golden Level',
      'level_vip': 'VIP Level',
      'next_hint_basic':
          'Create 5 plans, get 5 participants in one plan and gather 20 participants in total to reach the Premium privilege level.',
      'next_hint_premium':
          'Create 50 plans, get 50 participants in one plan and gather 2000 participants in total to reach the Golden privilege level.',
      'next_hint_golden':
          'Create 500 plans, get 500 participants in one plan and gather 10000 participants in total to reach the VIP privilege level.',
      'next_hint_vip': 'You are enjoying the VIP privilege level.',
      'info_basic': 'The Basic level is the lowest. To move to Premium:\n- Create 5 plans.\n- Reach 5 participants in a plan.\n- 20 participants in total.',
      'info_premium': 'The Premium level is the second level. To move to Golden:\n- Create 50 plans.\n- Maximum of 50 participants in a plan.\n- 2000 participants in total.',
      'info_golden': 'The Golden level is the penultimate level. To move to VIP:\n- Create 500 plans.\n- Reach 500 participants in a plan.\n- 10000 participants in total.',
      'info_vip': 'This is the highest level, with no limits.',
      'created_plans': 'Created plans',
      'max_participants': 'Max. participants',
      'in_a_plan': 'in one plan',
      'total_participants': 'Total participants',
      'gathered_so_far': 'gathered so far',
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
  String get searchAddressPlansHint => _t('search_address_plans_hint');
  String get searchRegion => _t('search_region');
  String get regionHint => _t('region_hint');
  String get currentLocation => _t('current_location');
  String get planDateQuestion => _t('plan_date_question');
  String get selectDate => _t('select_date');
  String get whatAgeRange => _t('what_age_range');
  String get clearFilter => _t('clear_filter');
  String get newPlan => _t('new_plan');
  String get selectMedia => _t('select_media');
  String get whatToUpload => _t('what_to_upload');
  String get imageGallery => _t('image_gallery');
  String get imageCamera => _t('image_camera');
  String get onlyOneImage => _t('only_one_image');
  String get attention => _t('attention');
  String get ok => _t('ok');
  String get meetingPoint => _t('meeting_point');
  String get meetingLocation => _t('meeting_location');
  String get planDateTime => _t('plan_date_time');
  String get editMedia => _t('edit_media');
  String get mediaContent => _t('media_content');
  String get editPlanTitle => _t('edit_plan_title');
  String get sharePlanTitle => _t('share_plan_title');
  String get chooseAPlan => _t('choose_a_plan');
  String get writePlanHint => _t('write_plan_hint');
  String get ageRestriction => _t('age_restriction');
  String get maxParticipants => _t('max_participants');
  String get enterNumber => _t('enter_number');
  String get planDescription => _t('plan_description');
  String get describePlan => _t('describe_plan');
  String get thisPlanIs => _t('this_plan_is');
  String get publicPlanDesc => _t('public_plan_desc');
  String get privatePlanDesc => _t('private_plan_desc');
  String get followersPlanDesc => _t('followers_plan_desc');
  String get onlyFollowers => _t('only_followers');
  String get updatePlan => _t('update_plan');
  String get createPlan => _t('create_plan');
  String get visibilityInfo => _t('visibility_info');
  String get planProcessError => _t('plan_process_error');
  String get includeEndDate => _t('include_end_date');
  String get startDate => _t('start_date');
  String get chooseDate => _t('choose_date');
  String get chooseTime => _t('choose_time');
  String get endDate => _t('end_date');
  String get chooseDay => _t('choose_day');
  String get notSelected => _t('not_selected');
  String get preview => _t('preview');
  String get error => _t('error');
  String get mustSelectStart => _t('must_select_start');
  String get endAfterStartError => _t('end_after_start_error');
  String get until => _t('until');
  String get online => _t('online');
  String get offline => _t('offline');
  String get writeMessage => _t('write_message');
  String get shareLocation => _t('share_location');
  String get sharePlan => _t('share_plan');
  String get sharePhoto => _t('share_photo');
  String get userNoPlans => _t('user_no_plans');
  String get inviteToPlan => _t('invite_to_plan');
  String get join => _t('join');
  String get joinRequested => _t('join_requested');
  String get fullCapacity => _t('full_capacity');
  String get participants => _t('participants');
  String get participantsTitle => _t('participants_title');
  String get attends => _t('attends');
  String get joinNow => _t('join_now');
  String get planChat => _t('plan_chat');
  String get locationUnavailable => _t('location_unavailable');
  String get additionalInfo => _t('additional_info');
  String get planIdCopied => _t('plan_id_copied');
  String get startCheckin => _t('start_checkin');
  String get viewCheckin => _t('view_checkin');
  String get endCheckin => _t('end_checkin');
  String get checkinInstructionsCreator => _t('checkin_instructions_creator');
  String get checkinInstructionsParticipant =>
      _t('checkin_instructions_participant');
  String get checkinNotStartedTitle => _t('checkin_not_started_title');
  String get checkinNotStartedMsg => _t('checkin_not_started_msg');
  String get confirmAttendance => _t('confirm_attendance');
  String get attendanceConfirmed => _t('attendance_confirmed');
  String get checkinNotActive => _t('checkin_not_active');
  String get generatingCode => _t('generating_code');
  String get alphanumericCode => _t('alphanumeric_code');
  String get validateCode => _t('validate_code');
  String get invalidCode => _t('invalid_code');
  String get noLoggedUser => _t('no_logged_user');
  String get planNotExists => _t('plan_not_exists');
  String get manualEntry => _t('manual_entry');
  String get errorLoadingMessages => _t('error_loading_messages');
  String get noMessagesYet => _t('no_messages_yet');
  String get disableNotifications => _t('disable_notifications');
  String get reportProfile => _t('report_profile');
  String get blockProfile => _t('block_profile');
  String get unblockProfile => _t('unblock_profile');
  String get profileBlockedTitle => _t('profile_blocked_title');
  String get profileUnblockedTitle => _t('profile_unblocked_title');
  String get profileBlockedMessage => _t('profile_blocked_message');
  String get profileUnblockedMessage => _t('profile_unblocked_message');
  String get planIdLabel => _t('plan_id_label');
  String get ageRestrictionLabel => _t('age_restriction_label');
  String get endsAt => _t('ends_at_label');
  String get futurePlans => _t('future_plans');
  String get followers => _t('followers');
  String get following => _t('following');
  String get memories => _t('memories');
  String get close => _t('close');
  String get levelBasic => _t('level_basic');
  String get levelPremium => _t('level_premium');
  String get levelGolden => _t('level_golden');
  String get levelVip => _t('level_vip');
  String get nextHintBasic => _t('next_hint_basic');
  String get nextHintPremium => _t('next_hint_premium');
  String get nextHintGolden => _t('next_hint_golden');
  String get nextHintVip => _t('next_hint_vip');
  String get infoBasic => _t('info_basic');
  String get infoPremium => _t('info_premium');
  String get infoGolden => _t('info_golden');
  String get infoVip => _t('info_vip');
  String get createdPlans => _t('created_plans');
  String get maxParticipantsText => _t('max_participants');
  String get inAPlan => _t('in_a_plan');
  String get totalParticipantsText => _t('total_participants');
  String get gatheredSoFar => _t('gathered_so_far');
  String get sendMessage => _t('send_message');
  String get follow => _t('follow');
  String get followingStatus => _t('following_status');
  String get requested => _t('requested');
  String get memories => _t('memories');
  String get privateUser => _t('private_user');
  String get privateProfileMemories => _t('private_profile_memories');
  String get planAndMemories => _t('plan_and_memories');
  String get noMemoriesDay => _t('no_memories_day');

  String planAgeRange(int start, int end) {
    return locale.languageCode == 'en'
        ? 'Participants from $start to $end years old'
        : 'Participan edades de $start a $end años';
  }

  String ageRestrictionRange(int start, int end) {
    return locale.languageCode == 'en'
        ? 'Age restriction: $start - $end years'
        : 'Restricción de edad: $start - $end años';
  }

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
