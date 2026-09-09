import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';
import 'l10n_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Nailify'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookAppointment;

  /// No description provided for @myBooking.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get myBooking;

  /// No description provided for @myStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get myStudio;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @selectSalon.
  ///
  /// In en, this message translates to:
  /// **'Select Salon'**
  String get selectSalon;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Select Service'**
  String get selectService;

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get totalPrice;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

  /// No description provided for @perfectMatch.
  ///
  /// In en, this message translates to:
  /// **'Perfect Match'**
  String get perfectMatch;

  /// No description provided for @newNotification.
  ///
  /// In en, this message translates to:
  /// **'You have 1 new notification'**
  String get newNotification;

  /// No description provided for @nailRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Best matching nail design'**
  String get nailRecommendation;

  /// No description provided for @viewDetail.
  ///
  /// In en, this message translates to:
  /// **'View Detail'**
  String get viewDetail;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Your Notifications'**
  String get notifications;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Profile'**
  String get profileTitle;

  /// No description provided for @styleProfileSetup.
  ///
  /// In en, this message translates to:
  /// **'Personal Style Settings'**
  String get styleProfileSetup;

  /// No description provided for @logoutSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logged out successfully!'**
  String get logoutSuccess;

  /// No description provided for @updateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateProfile;

  /// No description provided for @pointsLabel.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get pointsLabel;

  /// No description provided for @tierLabel.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get tierLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @updateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully updated style profile and generated nail template!'**
  String get updateSuccess;

  /// No description provided for @updateFailure.
  ///
  /// In en, this message translates to:
  /// **'Error creating nail profile: {error}'**
  String updateFailure(Object error);

  /// No description provided for @loadFailure.
  ///
  /// In en, this message translates to:
  /// **'Cannot load information: {error}'**
  String loadFailure(Object error);

  /// No description provided for @updateProfileError.
  ///
  /// In en, this message translates to:
  /// **'Update error: {error}'**
  String updateProfileError(Object error);

  /// No description provided for @homeBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Beauty on your\nfingertips'**
  String get homeBannerTitle;

  /// No description provided for @homeBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover natural elegance through every touch'**
  String get homeBannerSubtitle;

  /// No description provided for @bookNowButton.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNowButton;

  /// No description provided for @homeQuizTitle.
  ///
  /// In en, this message translates to:
  /// **'Nailify Match AI'**
  String get homeQuizTitle;

  /// No description provided for @homeQuizHeading.
  ///
  /// In en, this message translates to:
  /// **'Find your perfect nail design'**
  String get homeQuizHeading;

  /// No description provided for @homeQuizSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a quick Style Quiz to find the best nail design for your personal style.'**
  String get homeQuizSubtitle;

  /// No description provided for @doQuizButton.
  ///
  /// In en, this message translates to:
  /// **'TAKE STYLE QUIZ NOW'**
  String get doQuizButton;

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured Services'**
  String get servicesTitle;

  /// No description provided for @servicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Premium salon-quality nail care experience'**
  String get servicesSubtitle;

  /// No description provided for @nailGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Nail Gallery'**
  String get nailGalleryTitle;

  /// No description provided for @nailGallerySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover the latest nail design trends'**
  String get nailGallerySubtitle;

  /// No description provided for @exploreGalleryButton.
  ///
  /// In en, this message translates to:
  /// **'Explore Gallery'**
  String get exploreGalleryButton;

  /// No description provided for @ourPromiseTitle.
  ///
  /// In en, this message translates to:
  /// **'OUR PROMISE'**
  String get ourPromiseTitle;

  /// No description provided for @ourPromiseHeading.
  ///
  /// In en, this message translates to:
  /// **'Why Choose Us'**
  String get ourPromiseHeading;

  /// No description provided for @ourPromiseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At Nailify, we understand that you have many choices. Here is why we stand out:'**
  String get ourPromiseSubtitle;

  /// No description provided for @ourPromiseExpTitle.
  ///
  /// In en, this message translates to:
  /// **'Years of Experience'**
  String get ourPromiseExpTitle;

  /// No description provided for @ourPromiseExpDesc.
  ///
  /// In en, this message translates to:
  /// **'We bring a wealth of experience and artistry to the world of nail design.'**
  String get ourPromiseExpDesc;

  /// No description provided for @ourPromiseTechTitle.
  ///
  /// In en, this message translates to:
  /// **'Professional Technicians'**
  String get ourPromiseTechTitle;

  /// No description provided for @ourPromiseTechDesc.
  ///
  /// In en, this message translates to:
  /// **'Our technicians are certified and trained to provide the most detailed nail care.'**
  String get ourPromiseTechDesc;

  /// No description provided for @ourPromiseQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Best Quality'**
  String get ourPromiseQualityTitle;

  /// No description provided for @ourPromiseQualityDesc.
  ///
  /// In en, this message translates to:
  /// **'Only premium, non-toxic products are used to ensure your safety and satisfaction.'**
  String get ourPromiseQualityDesc;

  /// No description provided for @ourPromiseTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Always Trendy'**
  String get ourPromiseTrendTitle;

  /// No description provided for @ourPromiseTrendDesc.
  ///
  /// In en, this message translates to:
  /// **'We constantly update our collection with the latest techniques and global trends.'**
  String get ourPromiseTrendDesc;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'WHAT CLIENTS SAY'**
  String get reviewsTitle;

  /// No description provided for @reviewsHeading.
  ///
  /// In en, this message translates to:
  /// **'Our Lovely Customers'**
  String get reviewsHeading;

  /// No description provided for @serviceCare.
  ///
  /// In en, this message translates to:
  /// **'Nail Care & Cuticle'**
  String get serviceCare;

  /// No description provided for @serviceGel.
  ///
  /// In en, this message translates to:
  /// **'Gel Polish'**
  String get serviceGel;

  /// No description provided for @serviceArt.
  ///
  /// In en, this message translates to:
  /// **'Nail Art'**
  String get serviceArt;

  /// No description provided for @serviceAcrylic.
  ///
  /// In en, this message translates to:
  /// **'Acrylic Extension'**
  String get serviceAcrylic;

  /// No description provided for @homeCtaTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Appointment Now!'**
  String get homeCtaTitle;

  /// No description provided for @homeCtaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book an appointment with Nailify — join us on the journey of exquisite nail art.'**
  String get homeCtaSubtitle;

  /// No description provided for @homeCtaButton.
  ///
  /// In en, this message translates to:
  /// **'BOOK APPOINTMENT NOW'**
  String get homeCtaButton;

  /// No description provided for @loyalCustomer.
  ///
  /// In en, this message translates to:
  /// **'Loyal Customer'**
  String get loyalCustomer;

  /// No description provided for @newCustomer.
  ///
  /// In en, this message translates to:
  /// **'New Customer'**
  String get newCustomer;

  /// No description provided for @vipCustomer.
  ///
  /// In en, this message translates to:
  /// **'VIP Customer'**
  String get vipCustomer;

  /// No description provided for @reviewLinhMai.
  ///
  /// In en, this message translates to:
  /// **'\"I absolutely love my nails! The staff here is very talented and the designs are gorgeous. I will definitely be back!\"'**
  String get reviewLinhMai;

  /// No description provided for @reviewThuNga.
  ///
  /// In en, this message translates to:
  /// **'\"The mirror (chrome) polish looks beautiful and the staff is extremely friendly.\"'**
  String get reviewThuNga;

  /// No description provided for @reviewHoangAnh.
  ///
  /// In en, this message translates to:
  /// **'\"The best nail salon in the area. The attention to detail is incomparable, and my nails stayed on for weeks without chipping!\"'**
  String get reviewHoangAnh;

  /// No description provided for @myBookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Bookings'**
  String get myBookingsTitle;

  /// No description provided for @bookingDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking Details'**
  String get bookingDetailsTitle;

  /// No description provided for @rateService.
  ///
  /// In en, this message translates to:
  /// **'Rate Service'**
  String get rateService;

  /// No description provided for @editRating.
  ///
  /// In en, this message translates to:
  /// **'Edit Rating'**
  String get editRating;

  /// No description provided for @bookAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Appointment'**
  String get bookAppointmentTitle;

  /// No description provided for @bookServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Service'**
  String get bookServiceTitle;

  /// No description provided for @perfectMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Nailify Match'**
  String get perfectMatchTitle;

  /// No description provided for @nailDesignTitle.
  ///
  /// In en, this message translates to:
  /// **'Nail Design'**
  String get nailDesignTitle;

  /// No description provided for @selectTryOnMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Try-on Method'**
  String get selectTryOnMethodTitle;

  /// No description provided for @quizDiscoverDesign.
  ///
  /// In en, this message translates to:
  /// **'Discover the design made for you'**
  String get quizDiscoverDesign;

  /// No description provided for @quizSelectMultiple.
  ///
  /// In en, this message translates to:
  /// **'Select multiple answers'**
  String get quizSelectMultiple;

  /// No description provided for @quizAnalyzingStyle.
  ///
  /// In en, this message translates to:
  /// **'Analyzing style...'**
  String get quizAnalyzingStyle;

  /// No description provided for @quizFindingColors.
  ///
  /// In en, this message translates to:
  /// **'Finding matching colors...'**
  String get quizFindingColors;

  /// No description provided for @quizMatchingCollections.
  ///
  /// In en, this message translates to:
  /// **'Matching with nail collection...'**
  String get quizMatchingCollections;

  /// No description provided for @quizAlmostDone.
  ///
  /// In en, this message translates to:
  /// **'Almost done...'**
  String get quizAlmostDone;

  /// No description provided for @quizBannerFound.
  ///
  /// In en, this message translates to:
  /// **'Nailify has found the perfect matching nail designs just for you!'**
  String get quizBannerFound;

  /// No description provided for @quizBannerNotFound.
  ///
  /// In en, this message translates to:
  /// **'If you haven\'t found the right design, Nailify can help.'**
  String get quizBannerNotFound;

  /// No description provided for @quizBannerViewResults.
  ///
  /// In en, this message translates to:
  /// **'VIEW PERFECT MATCH RESULTS'**
  String get quizBannerViewResults;

  /// No description provided for @quizBannerRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake Quiz'**
  String get quizBannerRetake;

  /// No description provided for @quizBannerDesign.
  ///
  /// In en, this message translates to:
  /// **'Design Your Own'**
  String get quizBannerDesign;

  /// No description provided for @quizBannerTake.
  ///
  /// In en, this message translates to:
  /// **'Take Quiz'**
  String get quizBannerTake;

  /// No description provided for @nailDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Design Details'**
  String get nailDetailsTitle;

  /// No description provided for @nailVariantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Nail Variants'**
  String get nailVariantsLabel;

  /// No description provided for @nailDetailsError.
  ///
  /// In en, this message translates to:
  /// **'Cannot load design details.'**
  String get nailDetailsError;

  /// No description provided for @colorMatchReason.
  ///
  /// In en, this message translates to:
  /// **'Color tone {color} matches your preferred color.'**
  String colorMatchReason(Object color);

  /// No description provided for @forYouTitle.
  ///
  /// In en, this message translates to:
  /// **'EXCLUSIVE FOR YOU'**
  String get forYouTitle;

  /// No description provided for @styleRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Style Recommendation'**
  String get styleRecommendation;

  /// No description provided for @yourPersonalStyle.
  ///
  /// In en, this message translates to:
  /// **'Your personal style: '**
  String get yourPersonalStyle;

  /// No description provided for @designYourOwnNail.
  ///
  /// In en, this message translates to:
  /// **'DESIGN YOUR OWN NAIL'**
  String get designYourOwnNail;

  /// No description provided for @premiumNailDesign.
  ///
  /// In en, this message translates to:
  /// **'Premium nail design'**
  String get premiumNailDesign;

  /// No description provided for @styleFitReasons.
  ///
  /// In en, this message translates to:
  /// **'Why it fits your style'**
  String get styleFitReasons;

  /// No description provided for @youMayAlsoLike.
  ///
  /// In en, this message translates to:
  /// **'You may also like'**
  String get youMayAlsoLike;

  /// No description provided for @otherStyleFits.
  ///
  /// In en, this message translates to:
  /// **'Other designs matching your style'**
  String get otherStyleFits;

  /// No description provided for @tryAnotherDesign.
  ///
  /// In en, this message translates to:
  /// **'Try another design'**
  String get tryAnotherDesign;

  /// No description provided for @noMatchingFound.
  ///
  /// In en, this message translates to:
  /// **'No matching designs found'**
  String get noMatchingFound;

  /// No description provided for @noMatchingDesc.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find any nail designs matching your attributes. Please try retaking the style quiz.'**
  String get noMatchingDesc;

  /// No description provided for @monthHint.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthHint;

  /// No description provided for @yearHint.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get yearHint;

  /// No description provided for @allMonths.
  ///
  /// In en, this message translates to:
  /// **'All Months'**
  String get allMonths;

  /// No description provided for @allYears.
  ///
  /// In en, this message translates to:
  /// **'All Years'**
  String get allYears;

  /// No description provided for @monthFormat.
  ///
  /// In en, this message translates to:
  /// **'Month {m}'**
  String monthFormat(Object m);

  /// No description provided for @yearFormat.
  ///
  /// In en, this message translates to:
  /// **'Year {y}'**
  String yearFormat(Object y);

  /// No description provided for @allStatus.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allStatus;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Ready to Book'**
  String get statusApproved;

  /// No description provided for @statusAssigned.
  ///
  /// In en, this message translates to:
  /// **'Artist Assigned'**
  String get statusAssigned;

  /// No description provided for @statusCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked In'**
  String get statusCheckedIn;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusReviewed.
  ///
  /// In en, this message translates to:
  /// **'Artist Reviewed'**
  String get statusReviewed;

  /// No description provided for @statusRepaired.
  ///
  /// In en, this message translates to:
  /// **'Repaired'**
  String get statusRepaired;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @bookingTabScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get bookingTabScheduled;

  /// No description provided for @bookingTabWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get bookingTabWaitlist;

  /// No description provided for @bookingTabReschedule.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get bookingTabReschedule;

  /// No description provided for @warrantyButton.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get warrantyButton;

  /// No description provided for @servicesLabel.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesLabel;

  /// No description provided for @completedLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedLabel;

  /// No description provided for @viewAllServices.
  ///
  /// In en, this message translates to:
  /// **'View All Services'**
  String get viewAllServices;

  /// No description provided for @findNearbySalons.
  ///
  /// In en, this message translates to:
  /// **'Find Nearby Salons (View Map)'**
  String get findNearbySalons;

  /// No description provided for @bookThisDesign.
  ///
  /// In en, this message translates to:
  /// **'Book This Design'**
  String get bookThisDesign;

  /// No description provided for @takeAnotherAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Take Another Analysis'**
  String get takeAnotherAnalysis;

  /// No description provided for @tryOnTabShape.
  ///
  /// In en, this message translates to:
  /// **'Nail Shape'**
  String get tryOnTabShape;

  /// No description provided for @tryOnTabSurface.
  ///
  /// In en, this message translates to:
  /// **'Nail Surface'**
  String get tryOnTabSurface;

  /// No description provided for @tryOnTabColor.
  ///
  /// In en, this message translates to:
  /// **'Nail Color'**
  String get tryOnTabColor;

  /// No description provided for @tryOnTabAccessories.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get tryOnTabAccessories;

  /// No description provided for @designPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Nail Design'**
  String get designPageTitle;

  /// No description provided for @automaticFitDesign.
  ///
  /// In en, this message translates to:
  /// **'AUTOMATIC FIT DESIGN'**
  String get automaticFitDesign;

  /// No description provided for @automaticFitDesignDesc.
  ///
  /// In en, this message translates to:
  /// **'Bloom will automatically analyze your skin tone, hand shape, occupation, and preferences from your personality quiz to create a perfect 5-layer nail design.'**
  String get automaticFitDesignDesc;

  /// No description provided for @designFeatureShape.
  ///
  /// In en, this message translates to:
  /// **'Suggest nail shapes matching your hand structure'**
  String get designFeatureShape;

  /// No description provided for @designFeatureColor.
  ///
  /// In en, this message translates to:
  /// **'Match skin-toning colors based on Warm/Cool tone'**
  String get designFeatureColor;

  /// No description provided for @designFeatureAccessories.
  ///
  /// In en, this message translates to:
  /// **'Auto-select exquisite patterns & accessories'**
  String get designFeatureAccessories;

  /// No description provided for @generateDesignButton.
  ///
  /// In en, this message translates to:
  /// **'GENERATE DESIGN'**
  String get generateDesignButton;

  /// No description provided for @tryOnHintText.
  ///
  /// In en, this message translates to:
  /// **'Tap the arrow button on the right to show the design panel'**
  String get tryOnHintText;

  /// No description provided for @reGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get reGenerateButton;

  /// No description provided for @saveDesignButton.
  ///
  /// In en, this message translates to:
  /// **'Save Design'**
  String get saveDesignButton;

  /// No description provided for @saveDesignSuccess.
  ///
  /// In en, this message translates to:
  /// **'Try-on setup saved successfully.'**
  String get saveDesignSuccess;

  /// No description provided for @selectNailShapeWarn.
  ///
  /// In en, this message translates to:
  /// **'Please select a nail shape.'**
  String get selectNailShapeWarn;

  /// No description provided for @applyToAllSuccess.
  ///
  /// In en, this message translates to:
  /// **'Applied this finger\'s design to all fingers!'**
  String get applyToAllSuccess;

  /// No description provided for @reGenSuccess.
  ///
  /// In en, this message translates to:
  /// **'New matching nail design generated!'**
  String get reGenSuccess;

  /// No description provided for @reGenError.
  ///
  /// In en, this message translates to:
  /// **'Error regenerating design: {error}'**
  String reGenError(Object error);

  /// No description provided for @systemModels.
  ///
  /// In en, this message translates to:
  /// **'System Models'**
  String get systemModels;

  /// No description provided for @myComponents.
  ///
  /// In en, this message translates to:
  /// **'My Components'**
  String get myComponents;

  /// No description provided for @noAccessorySelected.
  ///
  /// In en, this message translates to:
  /// **'No accessory selected on nail'**
  String get noAccessorySelected;

  /// No description provided for @addToNail.
  ///
  /// In en, this message translates to:
  /// **'Add to nail'**
  String get addToNail;

  /// No description provided for @generatingPersonalizedDesign.
  ///
  /// In en, this message translates to:
  /// **'GENERATING PERSONALIZED DESIGN'**
  String get generatingPersonalizedDesign;

  /// No description provided for @failedGenerateDesign.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate design'**
  String get failedGenerateDesign;

  /// No description provided for @failedGenerateDesignDesc.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while fetching recommended nail design based on your preferences.'**
  String get failedGenerateDesignDesc;

  /// No description provided for @tryChangeFilter.
  ///
  /// In en, this message translates to:
  /// **'Try changing the month, year, or status filter.'**
  String get tryChangeFilter;

  /// No description provided for @bookNowHint.
  ///
  /// In en, this message translates to:
  /// **'Book a nail appointment now to get started!'**
  String get bookNowHint;

  /// No description provided for @exploreServices.
  ///
  /// In en, this message translates to:
  /// **'Explore Services'**
  String get exploreServices;

  /// No description provided for @nailServiceDefault.
  ///
  /// In en, this message translates to:
  /// **'Nail Service'**
  String get nailServiceDefault;

  /// No description provided for @anyArtist.
  ///
  /// In en, this message translates to:
  /// **'Any Artist'**
  String get anyArtist;

  /// No description provided for @bookingMissingId.
  ///
  /// In en, this message translates to:
  /// **'Error: This booking is missing an ID from the system.'**
  String get bookingMissingId;

  /// No description provided for @warrantyServiceDefault.
  ///
  /// In en, this message translates to:
  /// **'Warranty Service'**
  String get warrantyServiceDefault;

  /// No description provided for @warrantyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Warranty'**
  String get warrantyPrefix;

  /// No description provided for @waitlistCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Waitlist cancelled successfully.'**
  String get waitlistCancelSuccess;

  /// No description provided for @waitlistCancelError.
  ///
  /// In en, this message translates to:
  /// **'Error cancelling waitlist: {error}'**
  String waitlistCancelError(Object error);

  /// No description provided for @waitlistConfirmSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed successfully!'**
  String get waitlistConfirmSuccess;

  /// No description provided for @waitlistConfirmError.
  ///
  /// In en, this message translates to:
  /// **'Confirm error: {error}'**
  String waitlistConfirmError(Object error);

  /// No description provided for @waitlistLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load waitlist'**
  String get waitlistLoadError;

  /// No description provided for @waitlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'No waitlists'**
  String get waitlistEmpty;

  /// No description provided for @waitlistEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'When a slot opens for your registered time,\nthe record will appear here.'**
  String get waitlistEmptyDesc;

  /// No description provided for @waitlistStatusPending.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get waitlistStatusPending;

  /// No description provided for @waitlistStatusOpened.
  ///
  /// In en, this message translates to:
  /// **'SLOT AVAILABLE'**
  String get waitlistStatusOpened;

  /// No description provided for @waitlistHoldExpired.
  ///
  /// In en, this message translates to:
  /// **'Hold time has expired'**
  String get waitlistHoldExpired;

  /// No description provided for @waitlistHoldEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Hold ends in: '**
  String get waitlistHoldEndsIn;

  /// No description provided for @waitlistRegisteredAt.
  ///
  /// In en, this message translates to:
  /// **'Registered: '**
  String get waitlistRegisteredAt;

  /// No description provided for @waitlistMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} minutes ago'**
  String waitlistMinutesAgo(Object n);

  /// No description provided for @waitlistHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} hours ago'**
  String waitlistHoursAgo(Object n);

  /// No description provided for @waitlistDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String waitlistDaysAgo(Object n);

  /// No description provided for @waitlistCancelBtn.
  ///
  /// In en, this message translates to:
  /// **'Cancel Wait'**
  String get waitlistCancelBtn;

  /// No description provided for @waitlistDeclineBtn.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get waitlistDeclineBtn;

  /// No description provided for @waitlistConfirmBookBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Booking'**
  String get waitlistConfirmBookBtn;

  /// No description provided for @waitlistCancelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Cancel Wait'**
  String get waitlistCancelDialogTitle;

  /// No description provided for @waitlistCancelDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave the waitlist at {time}?\nYou will lose your position in the queue.'**
  String waitlistCancelDialogContent(Object time);

  /// No description provided for @waitlistKeepBtn.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get waitlistKeepBtn;

  /// No description provided for @rescheduleAcceptSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reschedule accepted successfully'**
  String get rescheduleAcceptSuccess;

  /// No description provided for @rescheduleAcceptFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept reschedule'**
  String get rescheduleAcceptFail;

  /// No description provided for @rescheduleDeclineSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reschedule declined successfully'**
  String get rescheduleDeclineSuccess;

  /// No description provided for @rescheduleDeclineFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to decline reschedule'**
  String get rescheduleDeclineFail;

  /// No description provided for @rescheduleProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get rescheduleProcessing;

  /// No description provided for @rescheduleFilterByDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by date'**
  String get rescheduleFilterByDate;

  /// No description provided for @rescheduleFilterDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String rescheduleFilterDate(Object date);

  /// No description provided for @rescheduleClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear date filter'**
  String get rescheduleClearFilter;

  /// No description provided for @rescheduleEmptyFiltered.
  ///
  /// In en, this message translates to:
  /// **'No reschedule requests on this day'**
  String get rescheduleEmptyFiltered;

  /// No description provided for @rescheduleEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No reschedule requests'**
  String get rescheduleEmptyAll;

  /// No description provided for @rescheduleEmptyFilteredDesc.
  ///
  /// In en, this message translates to:
  /// **'Try selecting a different date or clear the filter.'**
  String get rescheduleEmptyFilteredDesc;

  /// No description provided for @rescheduleEmptyAllDesc.
  ///
  /// In en, this message translates to:
  /// **'When a reschedule request from the Salon or\nyour reschedule request is being processed,\nthe record will appear here.'**
  String get rescheduleEmptyAllDesc;

  /// No description provided for @rescheduleNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get rescheduleNew;

  /// No description provided for @rescheduleSuggestedTime.
  ///
  /// In en, this message translates to:
  /// **'New suggested time from salon:'**
  String get rescheduleSuggestedTime;

  /// No description provided for @rescheduleRequestedTime.
  ///
  /// In en, this message translates to:
  /// **'Time you requested to reschedule:'**
  String get rescheduleRequestedTime;

  /// No description provided for @rescheduleOldSchedule.
  ///
  /// In en, this message translates to:
  /// **'Old schedule: '**
  String get rescheduleOldSchedule;

  /// No description provided for @rescheduleReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: '**
  String get rescheduleReason;

  /// No description provided for @reschedulePendingMsg.
  ///
  /// In en, this message translates to:
  /// **'Waiting for salon to respond to your reschedule request'**
  String get reschedulePendingMsg;

  /// No description provided for @rescheduleDeclineBtn.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get rescheduleDeclineBtn;

  /// No description provided for @rescheduleAcceptBtn.
  ///
  /// In en, this message translates to:
  /// **'Accept Reschedule'**
  String get rescheduleAcceptBtn;

  /// No description provided for @myStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'My Studio'**
  String get myStudioTitle;

  /// No description provided for @myNailsTab.
  ///
  /// In en, this message translates to:
  /// **'My Nails'**
  String get myNailsTab;

  /// No description provided for @accessoriesTab.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessoriesTab;

  /// No description provided for @requestsTab.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requestsTab;

  /// No description provided for @studioAllTab.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get studioAllTab;

  /// No description provided for @studioProcessingTab.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get studioProcessingTab;

  /// No description provided for @studioApprovedTab.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get studioApprovedTab;

  /// No description provided for @studioRejectedTab.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get studioRejectedTab;

  /// No description provided for @studioNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No approval requests yet.'**
  String get studioNoRequests;

  /// No description provided for @studioCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get studioCreateNew;

  /// No description provided for @bookingSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking Successful!'**
  String get bookingSuccessTitle;

  /// No description provided for @bookingSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thank you for trusting Nailify. Here are the details of your appointment.'**
  String get bookingSuccessSubtitle;

  /// No description provided for @bookingInfoService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get bookingInfoService;

  /// No description provided for @bookingInfoDate.
  ///
  /// In en, this message translates to:
  /// **'Appointment Date'**
  String get bookingInfoDate;

  /// No description provided for @bookingInfoTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get bookingInfoTime;

  /// No description provided for @bookingInfoStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get bookingInfoStaff;

  /// No description provided for @bookingInfoOriginalPrice.
  ///
  /// In en, this message translates to:
  /// **'Original Price'**
  String get bookingInfoOriginalPrice;

  /// No description provided for @bookingInfoTotal.
  ///
  /// In en, this message translates to:
  /// **'Total Payment'**
  String get bookingInfoTotal;

  /// No description provided for @bookingPayBtn.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get bookingPayBtn;

  /// No description provided for @bookingViewBtn.
  ///
  /// In en, this message translates to:
  /// **'View Booking'**
  String get bookingViewBtn;

  /// No description provided for @bookingGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Home'**
  String get bookingGoHome;

  /// No description provided for @bookingPaymentError.
  ///
  /// In en, this message translates to:
  /// **'Unable to create payment: {error}'**
  String bookingPaymentError(Object error);

  /// No description provided for @bookingDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get bookingDiscount;

  /// No description provided for @cancelBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get cancelBookingTitle;

  /// No description provided for @cancelBookingConfirmMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this booking?'**
  String get cancelBookingConfirmMsg;

  /// No description provided for @cancelBookingReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Enter reason for cancellation (max 50 words)'**
  String get cancelBookingReasonHint;

  /// No description provided for @cancelBookingReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a reason'**
  String get cancelBookingReasonRequired;

  /// No description provided for @cancelBookingReasonTooLong.
  ///
  /// In en, this message translates to:
  /// **'Reason cannot exceed 50 words'**
  String get cancelBookingReasonTooLong;

  /// No description provided for @cancelBtn.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelBtn;

  /// No description provided for @confirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmBtn;

  /// No description provided for @searchNailHint.
  ///
  /// In en, this message translates to:
  /// **'Search nail designs...'**
  String get searchNailHint;

  /// No description provided for @searchComponentHint.
  ///
  /// In en, this message translates to:
  /// **'Search components...'**
  String get searchComponentHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get filterPublic;

  /// No description provided for @filterPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get filterPrivate;

  /// No description provided for @filterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get filterType;

  /// No description provided for @createNewBtn.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createNewBtn;

  /// No description provided for @deleteNailTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Nail Design'**
  String get deleteNailTitle;

  /// No description provided for @deleteNailConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteNailConfirm(Object name);

  /// No description provided for @deleteComponentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Component'**
  String get deleteComponentTitle;

  /// No description provided for @deleteComponentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteComponentConfirm(Object name);

  /// No description provided for @deleteBtn.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteBtn;

  /// No description provided for @retryBtn.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryBtn;

  /// No description provided for @noNailDesigns.
  ///
  /// In en, this message translates to:
  /// **'No nail designs yet'**
  String get noNailDesigns;

  /// No description provided for @createNewNailBtn.
  ///
  /// In en, this message translates to:
  /// **'Create New Nail Design'**
  String get createNewNailBtn;

  /// No description provided for @noComponents.
  ///
  /// In en, this message translates to:
  /// **'No components yet'**
  String get noComponents;

  /// No description provided for @filterAllStatus.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get filterAllStatus;

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests yet.'**
  String get noRequests;

  /// No description provided for @sendRequestBtn.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequestBtn;

  /// No description provided for @sendRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Design Request'**
  String get sendRequestTitle;

  /// No description provided for @selectNailLabel.
  ///
  /// In en, this message translates to:
  /// **'Nail Design *'**
  String get selectNailLabel;

  /// No description provided for @selectNailHint.
  ///
  /// In en, this message translates to:
  /// **'Select nail design...'**
  String get selectNailHint;

  /// No description provided for @selectSalonHint.
  ///
  /// In en, this message translates to:
  /// **'Select Salon branch...'**
  String get selectSalonHint;

  /// No description provided for @sendBtn.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendBtn;

  /// No description provided for @sendRequestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request sent successfully.'**
  String get sendRequestSuccess;

  /// No description provided for @sendRequestFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send request: {error}'**
  String sendRequestFail(Object error);

  /// No description provided for @loadFormFail.
  ///
  /// In en, this message translates to:
  /// **'Unable to load form: {error}'**
  String loadFormFail(Object error);

  /// No description provided for @selectNailTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Nail Design'**
  String get selectNailTitle;

  /// No description provided for @noNailFound.
  ///
  /// In en, this message translates to:
  /// **'No nail designs found'**
  String get noNailFound;

  /// No description provided for @selectSalonTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Salon Branch'**
  String get selectSalonTitle;

  /// No description provided for @noSalonFound.
  ///
  /// In en, this message translates to:
  /// **'No salons found'**
  String get noSalonFound;

  /// No description provided for @addressUpdating.
  ///
  /// In en, this message translates to:
  /// **'Address updating'**
  String get addressUpdating;

  /// No description provided for @statusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get statusPendingReview;

  /// No description provided for @statusReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get statusReview;

  /// No description provided for @statusQuoted.
  ///
  /// In en, this message translates to:
  /// **'Quoted'**
  String get statusQuoted;

  /// No description provided for @bookingStepSelectSalon.
  ///
  /// In en, this message translates to:
  /// **'Select Salon'**
  String get bookingStepSelectSalon;

  /// No description provided for @bookingStepServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get bookingStepServices;

  /// No description provided for @bookingStepBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookingStepBook;

  /// No description provided for @bookingStepCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingStepCompleted;

  /// No description provided for @bookingValidateSalon.
  ///
  /// In en, this message translates to:
  /// **'Please select a salon branch.'**
  String get bookingValidateSalon;

  /// No description provided for @bookingValidateService.
  ///
  /// In en, this message translates to:
  /// **'Please select or remove the empty service.'**
  String get bookingValidateService;

  /// No description provided for @bookingValidateServiceMin.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one service.'**
  String get bookingValidateServiceMin;

  /// No description provided for @bookingValidateDateTime.
  ///
  /// In en, this message translates to:
  /// **'Please fill in date, artist and time slot.'**
  String get bookingValidateDateTime;

  /// No description provided for @bookingSummaryBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get bookingSummaryBranch;

  /// No description provided for @bookingSummaryDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get bookingSummaryDate;

  /// No description provided for @bookingSummaryTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get bookingSummaryTime;

  /// No description provided for @bookingSummaryArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get bookingSummaryArtist;

  /// No description provided for @bookingAutoAssign.
  ///
  /// In en, this message translates to:
  /// **'Auto-assign'**
  String get bookingAutoAssign;

  /// No description provided for @bookingPaymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get bookingPaymentDetails;

  /// No description provided for @bookingExtraService.
  ///
  /// In en, this message translates to:
  /// **'Add-on: {name}'**
  String bookingExtraService(String name);

  /// No description provided for @bookingTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get bookingTotal;

  /// No description provided for @bookingNailVariantDefault.
  ///
  /// In en, this message translates to:
  /// **'Nail Variant'**
  String get bookingNailVariantDefault;

  /// No description provided for @bookingComponentDefault.
  ///
  /// In en, this message translates to:
  /// **'Nail Component'**
  String get bookingComponentDefault;

  /// No description provided for @bookingPromotion.
  ///
  /// In en, this message translates to:
  /// **'Promotion'**
  String get bookingPromotion;

  /// No description provided for @bookingNoPromotion.
  ///
  /// In en, this message translates to:
  /// **'No promotion applied'**
  String get bookingNoPromotion;

  /// No description provided for @bookingNoPromotionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No promotions available.'**
  String get bookingNoPromotionAvailable;

  /// No description provided for @bookingApplyPromotion.
  ///
  /// In en, this message translates to:
  /// **'Apply ({count})'**
  String bookingApplyPromotion(String count);

  /// No description provided for @bookingNoApply.
  ///
  /// In en, this message translates to:
  /// **'No promotion'**
  String get bookingNoApply;

  /// No description provided for @bookingBackBtn.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get bookingBackBtn;

  /// No description provided for @bookingContinueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get bookingContinueBtn;

  /// No description provided for @bookingConfirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm Booking'**
  String get bookingConfirmBtn;

  /// No description provided for @bookingSelectDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get bookingSelectDateTitle;

  /// No description provided for @bookingMonthYear.
  ///
  /// In en, this message translates to:
  /// **'{month}/{year}'**
  String bookingMonthYear(String month, String year);

  /// No description provided for @bookingNoBranch.
  ///
  /// In en, this message translates to:
  /// **'No branches available.'**
  String get bookingNoBranch;

  /// No description provided for @bookingFindNearby.
  ///
  /// In en, this message translates to:
  /// **'Find Nearby Salons (View Map)'**
  String get bookingFindNearby;

  /// No description provided for @bookingMainService.
  ///
  /// In en, this message translates to:
  /// **'Main Service'**
  String get bookingMainService;

  /// No description provided for @bookingWarrantyService.
  ///
  /// In en, this message translates to:
  /// **'Select warranty service'**
  String get bookingWarrantyService;

  /// No description provided for @bookingWarrantyDefault.
  ///
  /// In en, this message translates to:
  /// **'Warranty Service'**
  String get bookingWarrantyDefault;

  /// No description provided for @bookingWarrantyFree.
  ///
  /// In en, this message translates to:
  /// **'Free warranty • Qty: {qty}'**
  String bookingWarrantyFree(String qty);

  /// No description provided for @bookingAddonServices.
  ///
  /// In en, this message translates to:
  /// **'Add-on Services'**
  String get bookingAddonServices;

  /// No description provided for @bookingSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String bookingSelectedCount(String count);

  /// No description provided for @bookingNoAddon.
  ///
  /// In en, this message translates to:
  /// **'No add-on services available.'**
  String get bookingNoAddon;

  /// No description provided for @bookingQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get bookingQtyLabel;

  /// No description provided for @bookingAddService.
  ///
  /// In en, this message translates to:
  /// **'Add Service'**
  String get bookingAddService;

  /// No description provided for @bookingAddServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Add-on Service'**
  String get bookingAddServiceTitle;

  /// No description provided for @bookingSelectArtistTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Artist'**
  String get bookingSelectArtistTitle;

  /// No description provided for @bookingArtistNoDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a date first'**
  String get bookingArtistNoDate;

  /// No description provided for @bookingNoArtistAvailable.
  ///
  /// In en, this message translates to:
  /// **'No artists available on this date.'**
  String get bookingNoArtistAvailable;

  /// No description provided for @bookingArtistTab.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get bookingArtistTab;

  /// No description provided for @bookingNoArtistTab.
  ///
  /// In en, this message translates to:
  /// **'No preference'**
  String get bookingNoArtistTab;

  /// No description provided for @bookingAvailableSlots.
  ///
  /// In en, this message translates to:
  /// **'Available Slots'**
  String get bookingAvailableSlots;

  /// No description provided for @bookingSelectArtistFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select an artist (or \"No preference\") to see available slots.'**
  String get bookingSelectArtistFirst;

  /// No description provided for @bookingNoSchedule.
  ///
  /// In en, this message translates to:
  /// **'This artist has no schedule on this date.'**
  String get bookingNoSchedule;

  /// No description provided for @bookingSlotPast.
  ///
  /// In en, this message translates to:
  /// **'This time has passed, please choose another.'**
  String get bookingSlotPast;

  /// No description provided for @bookingWaitlistJoined.
  ///
  /// In en, this message translates to:
  /// **'You have joined the waitlist for {time}'**
  String bookingWaitlistJoined(String time);

  /// No description provided for @bookingSelectPromotion.
  ///
  /// In en, this message translates to:
  /// **'Select Promotion'**
  String get bookingSelectPromotion;

  /// No description provided for @bookingClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get bookingClearAll;

  /// No description provided for @bookingDiscountPercent.
  ///
  /// In en, this message translates to:
  /// **'{value}% off'**
  String bookingDiscountPercent(String value);

  /// No description provided for @bookingDiscountFixed.
  ///
  /// In en, this message translates to:
  /// **'{value} off'**
  String bookingDiscountFixed(String value);

  /// No description provided for @bookingNoPromotions.
  ///
  /// In en, this message translates to:
  /// **'No promotions available'**
  String get bookingNoPromotions;

  /// No description provided for @bookingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get bookingRetry;

  /// No description provided for @bookingWaitlistError.
  ///
  /// In en, this message translates to:
  /// **'Error joining waitlist: {error}'**
  String bookingWaitlistError(String error);

  /// No description provided for @bookingUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} / piece'**
  String bookingUnitPrice(String price);

  /// No description provided for @transactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// No description provided for @refundInfo.
  ///
  /// In en, this message translates to:
  /// **'Refund Information'**
  String get refundInfo;

  /// No description provided for @paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTitle;

  /// No description provided for @bookCustomNailTitle.
  ///
  /// In en, this message translates to:
  /// **'Book Custom Nail'**
  String get bookCustomNailTitle;

  /// No description provided for @requestDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Detail'**
  String get requestDetailTitle;

  /// No description provided for @loginRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Authentication Required'**
  String get loginRequiredTitle;

  /// No description provided for @loginRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Please sign in or register an account to use this feature.'**
  String get loginRequiredMessage;

  /// No description provided for @pleaseLoginToViewProfile.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view your personal profile'**
  String get pleaseLoginToViewProfile;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @registerNow.
  ///
  /// In en, this message translates to:
  /// **'Register now'**
  String get registerNow;

  /// No description provided for @loginRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please enter both Email and Password'**
  String get loginRequiredFields;

  /// No description provided for @loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Logged in successfully'**
  String get loginSuccess;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @registerRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get registerRequiredFields;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Confirm password does not match'**
  String get passwordMismatch;

  /// No description provided for @agreeToTermsError.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the terms of service to continue'**
  String get agreeToTermsError;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account registered successfully'**
  String get registerSuccess;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Account'**
  String get registerTitle;

  /// No description provided for @firstNameHint.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstNameHint;

  /// No description provided for @lastNameHint.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastNameHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordHint;

  /// No description provided for @agreeToTermsText.
  ///
  /// In en, this message translates to:
  /// **'I agree to the terms of service'**
  String get agreeToTermsText;

  /// No description provided for @bookingArtistDefault.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get bookingArtistDefault;

  /// No description provided for @bookingLoadingArtists.
  ///
  /// In en, this message translates to:
  /// **'Loading artist list...'**
  String get bookingLoadingArtists;

  /// No description provided for @bookingClickToSelectArtist.
  ///
  /// In en, this message translates to:
  /// **'Click to choose performing artist'**
  String get bookingClickToSelectArtist;

  /// No description provided for @bookingAutoAssignTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-assignment by system'**
  String get bookingAutoAssignTitle;

  /// No description provided for @bookingAutoAssignDesc.
  ///
  /// In en, this message translates to:
  /// **'Time displayed based on salon schedule. Artist will be auto-assigned.'**
  String get bookingAutoAssignDesc;

  /// No description provided for @bookingGeneralInfo.
  ///
  /// In en, this message translates to:
  /// **'General Information'**
  String get bookingGeneralInfo;

  /// No description provided for @bookingBranchLabel.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get bookingBranchLabel;

  /// No description provided for @bookingStylistLabel.
  ///
  /// In en, this message translates to:
  /// **'Stylist'**
  String get bookingStylistLabel;

  /// No description provided for @bookingDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get bookingDateLabel;

  /// No description provided for @bookingStartTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get bookingStartTimeLabel;

  /// No description provided for @bookingDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get bookingDurationLabel;

  /// No description provided for @bookingDurationValue.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String bookingDurationValue(String minutes);

  /// No description provided for @bookingServicesBooked.
  ///
  /// In en, this message translates to:
  /// **'Services Booked'**
  String get bookingServicesBooked;

  /// No description provided for @bookingQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String bookingQuantityLabel(String qty);

  /// No description provided for @bookingOriginalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Original Price:'**
  String get bookingOriginalPriceLabel;

  /// No description provided for @bookingDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount:'**
  String get bookingDiscountLabel;

  /// No description provided for @bookingTotalPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Payment:'**
  String get bookingTotalPaymentLabel;

  /// No description provided for @bookingReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get bookingReviewTitle;

  /// No description provided for @bookingRatingDetails.
  ///
  /// In en, this message translates to:
  /// **'Rating Details'**
  String get bookingRatingDetails;

  /// No description provided for @ratingOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get ratingOverall;

  /// No description provided for @ratingServiceQuality.
  ///
  /// In en, this message translates to:
  /// **'Service Quality'**
  String get ratingServiceQuality;

  /// No description provided for @ratingPunctuality.
  ///
  /// In en, this message translates to:
  /// **'Punctuality'**
  String get ratingPunctuality;

  /// No description provided for @ratingCleanliness.
  ///
  /// In en, this message translates to:
  /// **'Cleanliness'**
  String get ratingCleanliness;

  /// No description provided for @ratingLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load rating information.'**
  String get ratingLoadError;

  /// No description provided for @bookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking information not found.'**
  String get bookingNotFound;

  /// No description provided for @bookingPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid:'**
  String get bookingPaidAmount;

  /// No description provided for @bookingRemainingAmount.
  ///
  /// In en, this message translates to:
  /// **'Remaining:'**
  String get bookingRemainingAmount;

  /// No description provided for @bookingYourRating.
  ///
  /// In en, this message translates to:
  /// **'Your Rating'**
  String get bookingYourRating;

  /// No description provided for @bookingCheckInCode.
  ///
  /// In en, this message translates to:
  /// **'Check-in Code'**
  String get bookingCheckInCode;

  /// No description provided for @bookingCheckInInstruction.
  ///
  /// In en, this message translates to:
  /// **'Show this code to the receptionist'**
  String get bookingCheckInInstruction;

  /// No description provided for @bookingRescheduleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reschedule request sent successfully'**
  String get bookingRescheduleSuccess;

  /// No description provided for @bookingRescheduleFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reschedule request'**
  String get bookingRescheduleFail;

  /// No description provided for @bookingCancelSuccess.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled successfully'**
  String get bookingCancelSuccess;

  /// No description provided for @bookingCancelFail.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel booking'**
  String get bookingCancelFail;

  /// No description provided for @bookingCancelBtnLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Booking'**
  String get bookingCancelBtnLabel;

  /// No description provided for @bookingRescheduleBtnLabel.
  ///
  /// In en, this message translates to:
  /// **'Reschedule Appointment'**
  String get bookingRescheduleBtnLabel;

  /// No description provided for @bookingQrError.
  ///
  /// In en, this message translates to:
  /// **'Error displaying QR code'**
  String get bookingQrError;

  /// No description provided for @bookingFingersLabel.
  ///
  /// In en, this message translates to:
  /// **'fingers'**
  String get bookingFingersLabel;

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clearFilter;

  /// No description provided for @nailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Cannot load nail designs.'**
  String get nailLoadError;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommended;

  /// No description provided for @nailDesignFallback.
  ///
  /// In en, this message translates to:
  /// **'Nail design'**
  String get nailDesignFallback;

  /// No description provided for @introduction.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get introduction;

  /// No description provided for @nailDescriptionDefault.
  ///
  /// In en, this message translates to:
  /// **'Premium artistic nail designs meticulously crafted by top nail artists, bringing a glamorous, attractive, and personal look for women.'**
  String get nailDescriptionDefault;

  /// No description provided for @availableVariants.
  ///
  /// In en, this message translates to:
  /// **'Available variants'**
  String get availableVariants;

  /// No description provided for @noVariantsAvailable.
  ///
  /// In en, this message translates to:
  /// **'There are currently no variants available for this design.'**
  String get noVariantsAvailable;

  /// No description provided for @bookBtn.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookBtn;

  /// No description provided for @nailShapeLabel.
  ///
  /// In en, this message translates to:
  /// **'Shape'**
  String get nailShapeLabel;

  /// No description provided for @nailSurfaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get nailSurfaceLabel;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @priceFromTo.
  ///
  /// In en, this message translates to:
  /// **'Price from {min} - {max}'**
  String priceFromTo(String min, String max);

  /// No description provided for @variantsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} variants'**
  String variantsCount(String count);

  /// No description provided for @availableForTryOn.
  ///
  /// In en, this message translates to:
  /// **'Available for try-on'**
  String get availableForTryOn;

  /// No description provided for @loadDataError.
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String loadDataError(String error);

  /// No description provided for @variantDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Variant Details'**
  String get variantDetailsTitle;

  /// No description provided for @collectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Collection: {name}'**
  String collectionLabel(String name);

  /// No description provided for @nailFormLabel.
  ///
  /// In en, this message translates to:
  /// **'Nail form'**
  String get nailFormLabel;

  /// No description provided for @minutesLabel.
  ///
  /// In en, this message translates to:
  /// **'{minutes} mins'**
  String minutesLabel(String minutes);

  /// No description provided for @colorLabel.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get colorLabel;

  /// No description provided for @designComponentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Design components'**
  String get designComponentsLabel;

  /// No description provided for @sharedLabel.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get sharedLabel;

  /// No description provided for @bookAppointmentNow.
  ///
  /// In en, this message translates to:
  /// **'Book now'**
  String get bookAppointmentNow;

  /// No description provided for @shapeMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Form shaping method'**
  String get shapeMethodLabel;

  /// No description provided for @ratingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get ratingsTitle;

  /// No description provided for @nailNotRatedMessage.
  ///
  /// In en, this message translates to:
  /// **'This nail hasn\'t been rated.'**
  String get nailNotRatedMessage;

  /// No description provided for @decorationLabel.
  ///
  /// In en, this message translates to:
  /// **'Decoration'**
  String get decorationLabel;

  /// No description provided for @componentNameFallback.
  ///
  /// In en, this message translates to:
  /// **'Component {id}'**
  String componentNameFallback(String id);

  /// No description provided for @fingerThumb.
  ///
  /// In en, this message translates to:
  /// **'Thumb'**
  String get fingerThumb;

  /// No description provided for @fingerIndex.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get fingerIndex;

  /// No description provided for @fingerMiddle.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get fingerMiddle;

  /// No description provided for @fingerRing.
  ///
  /// In en, this message translates to:
  /// **'Ring'**
  String get fingerRing;

  /// No description provided for @fingerPinky.
  ///
  /// In en, this message translates to:
  /// **'Pinky'**
  String get fingerPinky;

  /// No description provided for @fingerOther.
  ///
  /// In en, this message translates to:
  /// **'Finger {index}'**
  String fingerOther(String index);

  /// No description provided for @seasonalTitle.
  ///
  /// In en, this message translates to:
  /// **'Seasonal'**
  String get seasonalTitle;

  /// No description provided for @profileTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get profileTransactions;

  /// No description provided for @profileFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get profileFavorites;

  /// No description provided for @statusApprovedFeasible.
  ///
  /// In en, this message translates to:
  /// **'Approved feasible!'**
  String get statusApprovedFeasible;

  /// No description provided for @estimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'Estimated price:'**
  String get estimatedPrice;

  /// No description provided for @estimatedDuration.
  ///
  /// In en, this message translates to:
  /// **'Estimated duration:'**
  String get estimatedDuration;

  /// No description provided for @assignedArtist.
  ///
  /// In en, this message translates to:
  /// **'Assigned artist:'**
  String get assignedArtist;

  /// No description provided for @technicalDetails.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get technicalDetails;

  /// No description provided for @nailShape.
  ///
  /// In en, this message translates to:
  /// **'Nail shape'**
  String get nailShape;

  /// No description provided for @nailSurface.
  ///
  /// In en, this message translates to:
  /// **'Nail surface'**
  String get nailSurface;

  /// No description provided for @accessories.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessories;

  /// No description provided for @rejectReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection:'**
  String get rejectReasonLabel;

  /// No description provided for @processingLabel.
  ///
  /// In en, this message translates to:
  /// **'Processing:'**
  String get processingLabel;

  /// No description provided for @processingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your design request is being evaluated and quoted by our specialist.'**
  String get processingDesc;

  /// No description provided for @noneValue.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneValue;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'My Wallet'**
  String get walletTitle;

  /// No description provided for @walletEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your points & vouchers'**
  String get walletEntrySubtitle;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Available points'**
  String get walletBalance;

  /// No description provided for @walletLifetimePoints.
  ///
  /// In en, this message translates to:
  /// **'Lifetime points'**
  String get walletLifetimePoints;

  /// No description provided for @walletTierProgress.
  ///
  /// In en, this message translates to:
  /// **'Tier progress'**
  String get walletTierProgress;

  /// No description provided for @walletTierNone.
  ///
  /// In en, this message translates to:
  /// **'No tier yet'**
  String get walletTierNone;

  /// No description provided for @walletTierMax.
  ///
  /// In en, this message translates to:
  /// **'Highest tier reached'**
  String get walletTierMax;

  /// No description provided for @walletPointsToNext.
  ///
  /// In en, this message translates to:
  /// **'{remaining} points to next tier'**
  String walletPointsToNext(int remaining);

  /// No description provided for @walletMyVouchers.
  ///
  /// In en, this message translates to:
  /// **'My Vouchers'**
  String get walletMyVouchers;

  /// No description provided for @walletRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem Points'**
  String get walletRedeem;

  /// No description provided for @walletVoucherCount.
  ///
  /// In en, this message translates to:
  /// **'{count} vouchers available'**
  String walletVoucherCount(int count);

  /// No description provided for @walletVoucherAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get walletVoucherAll;

  /// No description provided for @walletVoucherUsable.
  ///
  /// In en, this message translates to:
  /// **'Usable'**
  String get walletVoucherUsable;

  /// No description provided for @walletVoucherUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get walletVoucherUsed;

  /// No description provided for @walletVoucherExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get walletVoucherExpired;

  /// No description provided for @walletExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get walletExpiringSoon;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @voucherDetail.
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get voucherDetail;

  /// No description provided for @pointsShort.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get pointsShort;

  /// No description provided for @pointsRequired.
  ///
  /// In en, this message translates to:
  /// **'{points} pts'**
  String pointsRequired(int points);

  /// No description provided for @pointsRequiredTba.
  ///
  /// In en, this message translates to:
  /// **'TBA'**
  String get pointsRequiredTba;

  /// No description provided for @expiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiredOn(String date);

  /// No description provided for @expiringIn.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String expiringIn(String time);

  /// No description provided for @pointsHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Points history'**
  String get pointsHistoryTitle;

  /// No description provided for @pointsHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Points overview'**
  String get pointsHistorySubtitle;

  /// No description provided for @pointsHistoryEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get pointsHistoryEarned;

  /// No description provided for @pointsHistorySpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get pointsHistorySpent;

  /// No description provided for @pointsHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No points history yet'**
  String get pointsHistoryEmpty;

  /// No description provided for @pointsHistoryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your points changes will be recorded here.'**
  String get pointsHistoryEmptyHint;

  /// No description provided for @pointsHistoryLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load points history.'**
  String get pointsHistoryLoadError;

  /// No description provided for @pointsHistoryBookingRef.
  ///
  /// In en, this message translates to:
  /// **'Booking: #{ref}...'**
  String pointsHistoryBookingRef(String ref);

  /// No description provided for @voucherDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Voucher detail'**
  String get voucherDetailTitle;

  /// No description provided for @voucherUseNow.
  ///
  /// In en, this message translates to:
  /// **'Use now'**
  String get voucherUseNow;

  /// No description provided for @voucherDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get voucherDescription;

  /// No description provided for @voucherConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get voucherConditions;

  /// No description provided for @voucherValidity.
  ///
  /// In en, this message translates to:
  /// **'Validity'**
  String get voucherValidity;

  /// No description provided for @voucherStatusUsable.
  ///
  /// In en, this message translates to:
  /// **'Usable'**
  String get voucherStatusUsable;

  /// No description provided for @voucherStatusUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get voucherStatusUsed;

  /// No description provided for @voucherStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get voucherStatusExpired;

  /// No description provided for @voucherStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get voucherStatusUpcoming;

  /// No description provided for @redeemConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm redeem'**
  String get redeemConfirmTitle;

  /// No description provided for @redeemConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'You will spend {points} points for this voucher. {remaining} points will remain.'**
  String redeemConfirmDesc(int points, int remaining);

  /// No description provided for @redeemConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get redeemConfirmCta;

  /// No description provided for @redeemConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get redeemConfirmCancel;

  /// No description provided for @redeemConfirmTerms.
  ///
  /// In en, this message translates to:
  /// **'Redeemed vouchers cannot be refunded. Validity follows the program rules.'**
  String get redeemConfirmTerms;

  /// No description provided for @redeemSuccess.
  ///
  /// In en, this message translates to:
  /// **'Voucher redeemed successfully'**
  String get redeemSuccess;

  /// No description provided for @redeemFailed.
  ///
  /// In en, this message translates to:
  /// **'Redeem failed'**
  String get redeemFailed;

  /// No description provided for @redeemInsufficientPoints.
  ///
  /// In en, this message translates to:
  /// **'Not enough points'**
  String get redeemInsufficientPoints;

  /// No description provided for @redeemSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Voucher is sold out'**
  String get redeemSoldOut;

  /// No description provided for @redeemViewWallet.
  ///
  /// In en, this message translates to:
  /// **'View in wallet'**
  String get redeemViewWallet;

  /// No description provided for @voucherUserLimit.
  ///
  /// In en, this message translates to:
  /// **'Max {limit} redemptions per user'**
  String voucherUserLimit(int limit);

  /// No description provided for @voucherStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get voucherStartLabel;

  /// No description provided for @voucherEndLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get voucherEndLabel;

  /// No description provided for @emptyWalletVouchers.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any vouchers yet'**
  String get emptyWalletVouchers;

  /// No description provided for @emptyWalletVouchersHint.
  ///
  /// In en, this message translates to:
  /// **'Redeem your points to unlock attractive offers.'**
  String get emptyWalletVouchersHint;

  /// No description provided for @emptyRedeemable.
  ///
  /// In en, this message translates to:
  /// **'No vouchers to redeem right now'**
  String get emptyRedeemable;

  /// No description provided for @emptyRedeemableHint.
  ///
  /// In en, this message translates to:
  /// **'Please come back later. We will add more offers soon.'**
  String get emptyRedeemableHint;

  /// No description provided for @filterPercentage.
  ///
  /// In en, this message translates to:
  /// **'% off'**
  String get filterPercentage;

  /// No description provided for @filterFixedAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount off'**
  String get filterFixedAmount;

  /// No description provided for @walletOverviewLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load wallet. Please try again.'**
  String get walletOverviewLoadError;

  /// No description provided for @walletVoucherRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String walletVoucherRemaining(int count);

  /// No description provided for @walletVoucherUsedCount.
  ///
  /// In en, this message translates to:
  /// **'Used {used}/{total}'**
  String walletVoucherUsedCount(int used, int total);

  /// No description provided for @walletQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get walletQuickActions;

  /// No description provided for @balanceHint.
  ///
  /// In en, this message translates to:
  /// **'You have {points} points to redeem'**
  String balanceHint(int points);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'vi':
      return SVi();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
