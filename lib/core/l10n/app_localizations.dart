// Simple inline localization (no codegen required)
class AppLocalizations {
  final String language;

  const AppLocalizations(this.language);

  bool get isArabic => language == 'ar';

  String get appName => _t('Delni App', 'تطبيق دلني');
  String get tagline =>
      _t('Navigate Hospitals with Ease', 'التنقل في المستشفيات بسهولة');
  String get home => _t('Home', 'الرئيسية');
  String get search => _t('Search', 'البحث');
  String get visitor => _t('Visitor Mode', 'وضع الزائر');
  String get appointments => _t('My Appointments', 'مواعيدي');
  String get emergency => _t('Emergency', 'الطوارئ');
  String get elevator => _t('Elevator', 'المصعد');
  String get takingElevator => _t('Taking Elevator...', 'جاري استخدام المصعد...');
  String get accessibility => _t('Accessibility Mode', 'وضع إمكانية الوصول');
  String get language_ => _t('Language', 'اللغة');
  String get selectHospital => _t('Select Hospital', 'اختر المستشفى');
  String get searchDestination =>
      _t('Search clinics, departments, or rooms...', 'ابحث عن عيادات أو أقسام أو غرف...');
  String get floor => _t('Floor', 'طابق');
  String get groundFloor => _t('Ground Floor', 'الطابق الأرضي');
  String get firstFloor => _t('First Floor', 'الطابق الأول');
  String get secondFloor => _t('Second Floor', 'الطابق الثاني');
  String get navigateTo => _t('Navigate to', 'انتقل إلى');
  String get navigateToClinic => _t('Navigate to my clinic', 'انتقل إلى عيادتي');
  String get enterRoomNumber => _t('Enter Room Number', 'أدخل رقم الغرفة');
  String get findRoom => _t('Find Room', 'ابحث عن الغرفة');
  String get roomNumber => _t('Room #', 'غرفة #');
  String get viewRoute => _t('View Route', 'عرض المسار');
  String get createAppointment => _t('Create Appointment', 'إنشاء موعد');
  String get createAppointmentDescription =>
      _t('Schedule your hospital appointment with date and time',
          'جدول موعدك في المستشفى مع التاريخ والوقت');
  String get appointmentDetails => _t('Appointment Details', 'تفاصيل الموعد');
  String get selectClinic => _t('Select Clinic', 'اختر العيادة');
  String get selectDate => _t('Select Date', 'اختر التاريخ');
  String get selectTime => _t('Select Time', 'اختر الوقت');
  String get save => _t('Save', 'حفظ');
  String get cancel => _t('Cancel', 'إلغاء');
  String get delete => _t('Delete', 'حذف');
  String get noAppointments => _t('No appointments scheduled', 'لا توجد مواعيد مجدولة');
  String get visitorModeTitle => _t('Visit a Patient', 'زيارة مريض');
  String get visitorModeDesc =>
      _t('Enter the room number to navigate to your patient',
          'أدخل رقم الغرفة للانتقال إلى المريض');
  String get emergencyTitle => _t('Emergency Navigation', 'الملاحة في حالات الطوارئ');
  String get emergencyDesc =>
      _t('Showing fastest route to Emergency Department',
          'عرض أسرع طريق إلى قسم الطوارئ');
  String get accessibilityEnabled =>
      _t('Accessibility mode enabled - showing routes avoiding stairs',
          'تم تفعيل وضع إمكانية الوصول - عرض المسارات التي تتجنب السلالم');
  String get clinic => _t('Clinic', 'عيادة');
  String get department => _t('Department', 'قسم');
  String get room => _t('Room', 'غرفة');
  String get entrance => _t('Entrance', 'المدخل');
  String get youAreHere => _t('You are here', 'أنت هنا');
  String get destination => _t('Destination', 'الوجهة');
  String get route => _t('Route', 'المسار');
  String get features => _t('Features', 'الميزات');
  String get searchClinics => _t('Search Clinics', 'البحث عن العيادات');
  String get visitPatient => _t('Visit Patient', 'زيارة مريض');
  String get myAppointments => _t('My Appointments', 'مواعيدي');
  String get emergencyNav => _t('Emergency Navigation', 'الملاحة في حالات الطوارئ');
  String get startNavigation => _t('Start Navigation', 'بدء الملاحة');
  String get endNavigation => _t('End Navigation', 'إنهاء الملاحة');
  String get getStarted => _t('Get Started', 'ابدأ');
  String get back => _t('Back', 'رجوع');
  String get settings => _t('Settings', 'الإعدادات');
  String get darkMode => _t('Dark Mode', 'الوضع الداكن');
  String get notifications => _t('Notifications', 'الإشعارات');
  String get about => _t('About', 'عن التطبيق');
  String get version => _t('Version', 'الإصدار');
  String get distance => _t('Distance', 'المسافة');
  String get walkingTime => _t('Walking Time', 'وقت المشي');
  String get meters => _t('meters', 'متر');
  String get minWalk => _t('min walk', 'دقيقة مشي');
  String get accessibilityModeEnabled =>
      _t('Accessibility Mode Enabled', 'تم تفعيل وضع إمكانية الوصول');
  String get elevatorRoute => _t('Elevator Route', 'مسار المصعد');
  String get startsIn => _t('Starts in', 'يبدأ في');
  String get searchAgain => _t('Search Again', 'بحث جديد');
  String get followPath =>
      _t('Follow the highlighted path on the map', 'اتبع المسار المميز على الخريطة');
  String get roomNotFound =>
      _t('Room not found. Please check the room number.',
          'الغرفة غير موجودة. يرجى التحقق من رقم الغرفة.');
  String get quickAccess => _t('Quick access:', 'وصول سريع:');
  String get manageAppointments =>
      _t('Manage your hospital appointments', 'إدارة مواعيد المستشفى الخاصة بك');
  String get navigatingToAppointment =>
      _t('Navigating to your appointment', 'الملاحة إلى موعدك');
  String get noSlotsForDate =>
      _t('No available appointments for this date. Please try another date.',
          'لا توجد مواعيد متاحة لهذا التاريخ. يرجى تجربة تاريخ آخر.');
  String get selectClinicAndDate =>
      _t('Please select a clinic and date first',
          'الرجاء اختيار العيادة والتاريخ أولاً');
  String get available => _t('Available', 'متاح');
  String get limited => _t('Limited', 'محدود');
  String get full => _t('Full', 'ممتلئ');
  String get left_ => _t('left', 'متبقي');
  String get started => _t('Started', 'بدأ');
  String get emergencyMode => _t('EMERGENCY MODE', 'وضع الطوارئ');
  String get emergencyContact => _t('Emergency Contact', 'اتصال الطوارئ');
  String get call997 =>
      _t('Call 997 for immediate medical assistance',
          'اتصل على ٩٩٧ للحصول على المساعدة الطبية الفورية');
  String get howToReachER =>
      _t('How to reach Emergency Department:', 'كيفية الوصول إلى قسم الطوارئ:');
  String get followRedPath =>
      _t('Follow the red highlighted path on the map below',
          'اتبع المسار الأحمر المميز على الخريطة أدناه');
  String get lookForSigns =>
      _t('Look for emergency signs with red cross symbols',
          'ابحث عن لافتات الطوارئ مع رموز الصليب الأحمر');
  String get askStaff =>
      _t('Ask hospital staff for immediate assistance',
          'اطلب من موظفي المستشفى المساعدة الفورية');
  String get emergencyWarning =>
      _t('In case of life-threatening emergency, call 997 immediately. This navigation is for guidance only.',
          'في حالة الطوارئ المهددة للحياة، اتصل على ٩٩٧ فورًا. هذه الملاحة للإرشاد فقط.');
  String get appearance => _t('Appearance', 'المظهر');
  String get enableDarkTheme => _t('Enable dark theme', 'تفعيل المظهر الداكن');
  String get languageAndRegion => _t('Language & Region', 'اللغة والمنطقة');
  String get chooseLanguage =>
      _t('Choose your preferred language', 'اختر لغتك المفضلة');
  String get accessibilitySection => _t('Accessibility', 'إمكانية الوصول');
  String get enableAccessibility =>
      _t('Enable accessibility features', 'تفعيل ميزات إمكانية الوصول');
  String get manageNotifications =>
      _t('Manage notification preferences', 'إدارة تفضيلات الإشعارات');
  String get aboutDescription =>
      _t('Delni App is a hospital indoor navigation system that helps patients and visitors navigate hospital facilities with ease.',
          'تطبيق دلني هو نظام ملاحة داخلي للمستشفيات يساعد المرضى والزوار على التنقل في مرافق المستشفى بسهولة.');
  String get madeWithLove =>
      _t('Made with love for better hospital navigation',
          'صنع بحب لتحسين التنقل في المستشفيات');
  String get findClinics =>
      _t('Find clinics, departments, and rooms', 'ابحث عن العيادات والأقسام والغرف');
  String get navigateToRooms =>
      _t('Navigate to patient rooms easily', 'انتقل إلى غرف المرضى بسهولة');
  String get manageAndNavigate =>
      _t('Manage and navigate to appointments', 'إدارة المواعيد والانتقال إليها');
  String get quickRouteToER =>
      _t('Quick route to emergency department', 'طريق سريع إلى قسم الطوارئ');
  String get pilotReady =>
      _t('Pilot-ready navigation system for hospitals',
          'نظام ملاحة جاهز للتجربة في المستشفيات');
  String get customizeExperience =>
      _t('Customize your Delni App experience', 'خصص تجربة تطبيق دلني الخاصة بك');
  String get appointmentPassed => _t('Passed', 'انتهى');

  // Multi-floor navigation
  String goToFloor(String floorName) =>
      _t('Go to $floorName', 'اذهب إلى $floorName');
  String get viaElevatorStairs =>
      _t('via elevator / stairs', 'عبر المصعد / الدرج');
  String get showFloorMap => _t('Show Floor Map', 'عرض خريطة الطابق');
  String get pathToStairs =>
      _t('Follow path to stairs/elevator', 'اتبع المسار إلى الدرج/المصعد');
  String get whichFloorAreYouOn =>
      _t('Which floor are you on?', 'في أي طابق أنت؟');
  String destinationOnFloor(String floorName) =>
      _t('Destination is on $floorName', 'الوجهة في $floorName');

  // Home screen
  String get appTitle => _t('Delni', 'دلني');
  String get appTagline =>
      _t('Navigate Hospitals with Ease', 'التنقل في المستشفيات بسهولة');
  String get searchClinicsDesc =>
      _t('Find clinics, departments, and rooms', 'ابحث عن العيادات والأقسام والغرف');
  String get visitPatientDesc =>
      _t('Navigate to patient rooms easily', 'انتقل إلى غرف المرضى بسهولة');
  String get myAppointmentsDesc =>
      _t('Manage and navigate to appointments', 'إدارة المواعيد والانتقال إليها');

  // Settings screen
  String get darkModeDesc =>
      _t('Enable dark theme', 'تفعيل المظهر الداكن');
  String get languageRegion => _t('Language & Region', 'اللغة والمنطقة');
  String get english => _t('English', 'English');
  String get arabic => _t('العربية', 'العربية');
  String get accessibilityMode =>
      _t('Accessibility Mode', 'وضع إمكانية الوصول');
  String get accessibilityModeDesc =>
      _t('Enable accessibility features', 'تفعيل ميزات إمكانية الوصول');
  String get notificationsDesc =>
      _t('Manage notification preferences', 'إدارة تفضيلات الإشعارات');
  String get aboutDesc =>
      _t('Delni App is a hospital indoor navigation system that helps patients and visitors navigate hospital facilities with ease.',
          'تطبيق دلني هو نظام ملاحة داخلي للمستشفيات يساعد المرضى والزوار على التنقل في مرافق المستشفى بسهولة.');
  String get madeWith =>
      _t('Made with love for better hospital navigation',
          'صنع بحب لتحسين التنقل في المستشفيات');

  // Appointments screen
  String get minutes => _t('min walk', 'دقيقة مشي');
  String get noAppointmentsDesc =>
      _t('Tap + to add your first appointment reminder',
          'اضغط + لإضافة أول تذكير موعد');

  // Emergency screen
  String get emergencyRouteInfo =>
      _t('Showing fastest route to Emergency Department',
          'عرض أسرع طريق إلى قسم الطوارئ');
  String get emergencyInstructions =>
      _t('How to reach Emergency Department:', 'كيفية الوصول إلى قسم الطوارئ:');
  String get instruction1 =>
      _t('Follow the red highlighted path on the map below',
          'اتبع المسار الأحمر المميز على الخريطة أدناه');
  String get instruction2 =>
      _t('Look for emergency signs with red cross symbols',
          'ابحث عن لافتات الطوارئ مع رموز الصليب الأحمر');
  String get instruction3 =>
      _t('Ask hospital staff for immediate assistance',
          'اطلب من موظفي المستشفى المساعدة الفورية');

  // Create appointment sheet
  String get noResults =>
      _t('No available appointments for this date. Please try another date.',
          'لا توجد مواعيد متاحة لهذا التاريخ. يرجى تجربة تاريخ آخر.');
  String remaining(int count) =>
      _t('$count left', '$count متبقي');

  // Visitor screen
  String get howItWorks => _t('How it works', 'كيف يعمل');
  String get visitorTip =>
      _t('Ask hospital staff if you need help finding the room. Room numbers are displayed above each door.',
          'اسأل موظفي المستشفى إذا كنت بحاجة للمساعدة في العثور على الغرفة. أرقام الغرف معروضة فوق كل باب.');
  String get visitorStep1 =>
      _t('Enter the patient\'s room number', 'أدخل رقم غرفة المريض');
  String get visitorStep2 =>
      _t('Review visiting hours and rules', 'راجع أوقات الزيارة والقواعد');
  String get visitorStep3 =>
      _t('Navigate to the room using the map', 'انتقل إلى الغرفة باستخدام الخريطة');

  // Visitor result screen
  String get visitingHours => _t('Visiting Hours', 'أوقات الزيارة');
  String get morningVisit => _t('Morning', 'صباحاً');
  String get eveningVisit => _t('Evening', 'مساءً');
  String get morningHours => _t('10:00 AM – 12:00 PM', '١٠:٠٠ ص – ١٢:٠٠ م');
  String get eveningHours => _t('4:00 PM – 9:00 PM', '٤:٠٠ م – ٩:٠٠ م');
  String get visitingRules => _t('Visiting Rules', 'قواعد الزيارة');
  String get visitRule1 =>
      _t('No strong perfumes or fragrances', 'يمنع استخدام العطور القوية');
  String get visitRule2 =>
      _t('Maximum 2 visitors at a time', 'حد أقصى زائرَين في وقت واحد');
  String get visitRule3 =>
      _t('Keep noise to a minimum', 'حافظ على الهدوء');
  String get visitRule4 =>
      _t('Bring a valid ID for check-in', 'أحضر هوية صالحة للتسجيل');
  String get visitRule5 =>
      _t('No food unless approved by the nurse', 'لا طعام إلا بموافقة الممرض/ة');
  String get visitRule6 =>
      _t('Children under 12 must be accompanied', 'الأطفال دون ١٢ سنة يجب أن يكونوا برفقة بالغ');
  String get navigateToRoom => _t('Navigate to Room', 'الانتقال إلى الغرفة');

  // Appointments enhanced
  String get upcomingAppointments =>
      _t('Upcoming Appointments', 'المواعيد القادمة');
  String get appointmentTip =>
      _t('This is a reminder for your existing hospital appointment. Arrive 15 minutes early.',
          'هذا تذكير لموعدك الحالي في المستشفى. احضر قبل ١٥ دقيقة.');

  // Add Appointment (reminder system)
  String get addAppointment => _t('Add Appointment', 'إضافة موعد');
  String get patientName => _t('Patient Name', 'اسم المريض');
  String get patientNameHint => _t('Enter your name', 'أدخل اسمك');
  String get clinicName => _t('Clinic / Department', 'العيادة / القسم');
  String get clinicNameHint =>
      _t('e.g. Cardiology, Room 201...', 'مثل: قسم القلب، غرفة ٢٠١...');

  // Add Hospital (AI generation)
  String get addHospital => _t('Add Hospital', 'إضافة مستشفى');
  String get addHospitalWithAI =>
      _t('Add Hospital with AI', 'إضافة مستشفى بالذكاء الاصطناعي');
  String get uploadFloorPlans =>
      _t('Upload floor plan images', 'ارفع صور مخططات الطوابق');
  String get hospitalName => _t('Hospital Name', 'اسم المستشفى');
  String get hospitalNameHint =>
      _t('Enter hospital name', 'أدخل اسم المستشفى');
  String get addFloor => _t('Add Floor', 'إضافة طابق');
  String get floorName => _t('Floor Name', 'اسم الطابق');
  String get generateMap => _t('Generate Map', 'إنشاء الخريطة');
  String get analyzingFloorPlans =>
      _t('Analyzing floor plans with AI...', 'جاري تحليل المخططات بالذكاء الاصطناعي...');
  String analyzingFloor(String name, int current, int total) =>
      _t('Analyzing $name ($current/$total)', 'جاري تحليل $name ($current/$total)');
  String get generationSuccess =>
      _t('Hospital map generated successfully!', 'تم إنشاء خريطة المستشفى بنجاح!');
  String get generationFailed =>
      _t('Failed to generate map. Please try again.', 'فشل إنشاء الخريطة. حاول مرة أخرى.');
  String get retry => _t('Retry', 'إعادة المحاولة');
  String get tapToUpload =>
      _t('Tap to upload floor plan image', 'اضغط لرفع صورة مخطط الطابق');
  String get removeFloor => _t('Remove', 'إزالة');

  // Voice command
  String get voiceAssistant => _t('Voice Assistant', 'المساعد الصوتي');
  String get tapToSpeak => _t('Tap the mic and speak', 'اضغط على الميكروفون وتكلم');
  String get listening => _t('Listening...', 'جاري الاستماع...');
  String get understanding => _t('Understanding your request...', 'جاري فهم طلبك...');
  String get voiceTip => _t(
    'Say things like "Take me to the pharmacy" or "I want to visit room 201"',
    'قل مثلاً "خذني للصيدلية" أو "أريد زيارة غرفة ٢٠١"',
  );
  String get tryAgain => _t('Try Again', 'حاول مرة أخرى');
  String get openVisitorMode => _t('Open Visitor Mode', 'فتح وضع الزائر');
  String get openEmergency => _t('Open Emergency', 'فتح الطوارئ');
  String get openAppointments => _t('Open Appointments', 'فتح المواعيد');
  String get showOnMap => _t('Show on Map', 'عرض على الخريطة');
  String get voiceError => _t(
    'Could not understand. Please try again.',
    'لم أتمكن من الفهم. يرجى المحاولة مرة أخرى.',
  );
  String get micPermissionDenied => _t(
    'Microphone access is needed for voice commands.',
    'يلزم الوصول إلى الميكروفون لاستخدام الأوامر الصوتية.',
  );

  String _t(String en, String ar) => language == 'ar' ? ar : en;
}

String toArabicNumerals(String input) {
  const arabicNumerals = '٠١٢٣٤٥٦٧٨٩';
  return input.split('').map((c) {
    final d = int.tryParse(c);
    return d != null ? arabicNumerals[d] : c;
  }).join();
}
