// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Nailify`
  String get appName {
    return Intl.message('Nailify', name: 'appName', desc: '', args: []);
  }

  /// `Home`
  String get home {
    return Intl.message('Home', name: 'home', desc: '', args: []);
  }

  /// `Book`
  String get bookAppointment {
    return Intl.message('Book', name: 'bookAppointment', desc: '', args: []);
  }

  /// `Bookings`
  String get myBooking {
    return Intl.message('Bookings', name: 'myBooking', desc: '', args: []);
  }

  /// `My Studio`
  String get myStudio {
    return Intl.message('My Studio', name: 'myStudio', desc: '', args: []);
  }

  /// `Account`
  String get account {
    return Intl.message('Account', name: 'account', desc: '', args: []);
  }

  /// `Login`
  String get login {
    return Intl.message('Login', name: 'login', desc: '', args: []);
  }

  /// `Logout`
  String get logout {
    return Intl.message('Logout', name: 'logout', desc: '', args: []);
  }

  /// `Register`
  String get register {
    return Intl.message('Register', name: 'register', desc: '', args: []);
  }

  /// `Email`
  String get email {
    return Intl.message('Email', name: 'email', desc: '', args: []);
  }

  /// `Password`
  String get password {
    return Intl.message('Password', name: 'password', desc: '', args: []);
  }

  /// `Full Name`
  String get fullName {
    return Intl.message('Full Name', name: 'fullName', desc: '', args: []);
  }

  /// `Phone Number`
  String get phoneNumber {
    return Intl.message(
      'Phone Number',
      name: 'phoneNumber',
      desc: '',
      args: [],
    );
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `Confirm`
  String get confirm {
    return Intl.message('Confirm', name: 'confirm', desc: '', args: []);
  }

  /// `Back`
  String get back {
    return Intl.message('Back', name: 'back', desc: '', args: []);
  }

  /// `Next`
  String get next {
    return Intl.message('Next', name: 'next', desc: '', args: []);
  }

  /// `Done`
  String get done {
    return Intl.message('Done', name: 'done', desc: '', args: []);
  }

  /// `Loading...`
  String get loading {
    return Intl.message('Loading...', name: 'loading', desc: '', args: []);
  }

  /// `An error occurred`
  String get error {
    return Intl.message('An error occurred', name: 'error', desc: '', args: []);
  }

  /// `Retry`
  String get retry {
    return Intl.message('Retry', name: 'retry', desc: '', args: []);
  }

  /// `No data available`
  String get noData {
    return Intl.message(
      'No data available',
      name: 'noData',
      desc: '',
      args: [],
    );
  }

  /// `Select Date`
  String get selectDate {
    return Intl.message('Select Date', name: 'selectDate', desc: '', args: []);
  }

  /// `Select Time`
  String get selectTime {
    return Intl.message('Select Time', name: 'selectTime', desc: '', args: []);
  }

  /// `Select Salon`
  String get selectSalon {
    return Intl.message(
      'Select Salon',
      name: 'selectSalon',
      desc: '',
      args: [],
    );
  }

  /// `Select Service`
  String get selectService {
    return Intl.message(
      'Select Service',
      name: 'selectService',
      desc: '',
      args: [],
    );
  }

  /// `Total Price`
  String get totalPrice {
    return Intl.message('Total Price', name: 'totalPrice', desc: '', args: []);
  }

  /// `Book Now`
  String get bookNow {
    return Intl.message('Book Now', name: 'bookNow', desc: '', args: []);
  }

  /// `Perfect Match`
  String get perfectMatch {
    return Intl.message(
      'Perfect Match',
      name: 'perfectMatch',
      desc: '',
      args: [],
    );
  }

  /// `You have 1 new notification`
  String get newNotification {
    return Intl.message(
      'You have 1 new notification',
      name: 'newNotification',
      desc: '',
      args: [],
    );
  }

  /// `Best matching nail design`
  String get nailRecommendation {
    return Intl.message(
      'Best matching nail design',
      name: 'nailRecommendation',
      desc: '',
      args: [],
    );
  }

  /// `View Detail`
  String get viewDetail {
    return Intl.message('View Detail', name: 'viewDetail', desc: '', args: []);
  }

  /// `Your Notifications`
  String get notifications {
    return Intl.message(
      'Your Notifications',
      name: 'notifications',
      desc: '',
      args: [],
    );
  }

  /// `Personal Profile`
  String get profileTitle {
    return Intl.message(
      'Personal Profile',
      name: 'profileTitle',
      desc: '',
      args: [],
    );
  }

  /// `Personal Style Settings`
  String get styleProfileSetup {
    return Intl.message(
      'Personal Style Settings',
      name: 'styleProfileSetup',
      desc: '',
      args: [],
    );
  }

  /// `Logged out successfully!`
  String get logoutSuccess {
    return Intl.message(
      'Logged out successfully!',
      name: 'logoutSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Update`
  String get updateProfile {
    return Intl.message('Update', name: 'updateProfile', desc: '', args: []);
  }

  /// `points`
  String get pointsLabel {
    return Intl.message('points', name: 'pointsLabel', desc: '', args: []);
  }

  /// `Tier`
  String get tierLabel {
    return Intl.message('Tier', name: 'tierLabel', desc: '', args: []);
  }

  /// `Status`
  String get statusLabel {
    return Intl.message('Status', name: 'statusLabel', desc: '', args: []);
  }

  /// `Successfully updated style profile and generated nail template!`
  String get updateSuccess {
    return Intl.message(
      'Successfully updated style profile and generated nail template!',
      name: 'updateSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Error creating nail profile: {error}`
  String updateFailure(Object error) {
    return Intl.message(
      'Error creating nail profile: $error',
      name: 'updateFailure',
      desc: '',
      args: [error],
    );
  }

  /// `Cannot load information: {error}`
  String loadFailure(Object error) {
    return Intl.message(
      'Cannot load information: $error',
      name: 'loadFailure',
      desc: '',
      args: [error],
    );
  }

  /// `Update error: {error}`
  String updateProfileError(Object error) {
    return Intl.message(
      'Update error: $error',
      name: 'updateProfileError',
      desc: '',
      args: [error],
    );
  }

  /// `Beauty on your\nfingertips`
  String get homeBannerTitle {
    return Intl.message(
      'Beauty on your\nfingertips',
      name: 'homeBannerTitle',
      desc: '',
      args: [],
    );
  }

  /// `Discover natural elegance through every touch`
  String get homeBannerSubtitle {
    return Intl.message(
      'Discover natural elegance through every touch',
      name: 'homeBannerSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Book Now`
  String get bookNowButton {
    return Intl.message('Book Now', name: 'bookNowButton', desc: '', args: []);
  }

  /// `Nailify Match AI`
  String get homeQuizTitle {
    return Intl.message(
      'Nailify Match AI',
      name: 'homeQuizTitle',
      desc: '',
      args: [],
    );
  }

  /// `Find your perfect nail design`
  String get homeQuizHeading {
    return Intl.message(
      'Find your perfect nail design',
      name: 'homeQuizHeading',
      desc: '',
      args: [],
    );
  }

  /// `Take a quick Style Quiz to find the best nail design for your personal style.`
  String get homeQuizSubtitle {
    return Intl.message(
      'Take a quick Style Quiz to find the best nail design for your personal style.',
      name: 'homeQuizSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `TAKE STYLE QUIZ NOW`
  String get doQuizButton {
    return Intl.message(
      'TAKE STYLE QUIZ NOW',
      name: 'doQuizButton',
      desc: '',
      args: [],
    );
  }

  /// `Featured Services`
  String get servicesTitle {
    return Intl.message(
      'Featured Services',
      name: 'servicesTitle',
      desc: '',
      args: [],
    );
  }

  /// `Premium salon-quality nail care experience`
  String get servicesSubtitle {
    return Intl.message(
      'Premium salon-quality nail care experience',
      name: 'servicesSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Nail Gallery`
  String get nailGalleryTitle {
    return Intl.message(
      'Nail Gallery',
      name: 'nailGalleryTitle',
      desc: '',
      args: [],
    );
  }

  /// `Discover the latest nail design trends`
  String get nailGallerySubtitle {
    return Intl.message(
      'Discover the latest nail design trends',
      name: 'nailGallerySubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Explore Gallery`
  String get exploreGalleryButton {
    return Intl.message(
      'Explore Gallery',
      name: 'exploreGalleryButton',
      desc: '',
      args: [],
    );
  }

  /// `OUR PROMISE`
  String get ourPromiseTitle {
    return Intl.message(
      'OUR PROMISE',
      name: 'ourPromiseTitle',
      desc: '',
      args: [],
    );
  }

  /// `Why Choose Us`
  String get ourPromiseHeading {
    return Intl.message(
      'Why Choose Us',
      name: 'ourPromiseHeading',
      desc: '',
      args: [],
    );
  }

  /// `At Nailify, we understand that you have many choices. Here is why we stand out:`
  String get ourPromiseSubtitle {
    return Intl.message(
      'At Nailify, we understand that you have many choices. Here is why we stand out:',
      name: 'ourPromiseSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Years of Experience`
  String get ourPromiseExpTitle {
    return Intl.message(
      'Years of Experience',
      name: 'ourPromiseExpTitle',
      desc: '',
      args: [],
    );
  }

  /// `We bring a wealth of experience and artistry to the world of nail design.`
  String get ourPromiseExpDesc {
    return Intl.message(
      'We bring a wealth of experience and artistry to the world of nail design.',
      name: 'ourPromiseExpDesc',
      desc: '',
      args: [],
    );
  }

  /// `Professional Technicians`
  String get ourPromiseTechTitle {
    return Intl.message(
      'Professional Technicians',
      name: 'ourPromiseTechTitle',
      desc: '',
      args: [],
    );
  }

  /// `Our technicians are certified and trained to provide the most detailed nail care.`
  String get ourPromiseTechDesc {
    return Intl.message(
      'Our technicians are certified and trained to provide the most detailed nail care.',
      name: 'ourPromiseTechDesc',
      desc: '',
      args: [],
    );
  }

  /// `Best Quality`
  String get ourPromiseQualityTitle {
    return Intl.message(
      'Best Quality',
      name: 'ourPromiseQualityTitle',
      desc: '',
      args: [],
    );
  }

  /// `Only premium, non-toxic products are used to ensure your safety and satisfaction.`
  String get ourPromiseQualityDesc {
    return Intl.message(
      'Only premium, non-toxic products are used to ensure your safety and satisfaction.',
      name: 'ourPromiseQualityDesc',
      desc: '',
      args: [],
    );
  }

  /// `Always Trendy`
  String get ourPromiseTrendTitle {
    return Intl.message(
      'Always Trendy',
      name: 'ourPromiseTrendTitle',
      desc: '',
      args: [],
    );
  }

  /// `We constantly update our collection with the latest techniques and global trends.`
  String get ourPromiseTrendDesc {
    return Intl.message(
      'We constantly update our collection with the latest techniques and global trends.',
      name: 'ourPromiseTrendDesc',
      desc: '',
      args: [],
    );
  }

  /// `WHAT CLIENTS SAY`
  String get reviewsTitle {
    return Intl.message(
      'WHAT CLIENTS SAY',
      name: 'reviewsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Our Lovely Customers`
  String get reviewsHeading {
    return Intl.message(
      'Our Lovely Customers',
      name: 'reviewsHeading',
      desc: '',
      args: [],
    );
  }

  /// `Nail Care & Cuticle`
  String get serviceCare {
    return Intl.message(
      'Nail Care & Cuticle',
      name: 'serviceCare',
      desc: '',
      args: [],
    );
  }

  /// `Gel Polish`
  String get serviceGel {
    return Intl.message('Gel Polish', name: 'serviceGel', desc: '', args: []);
  }

  /// `Nail Art`
  String get serviceArt {
    return Intl.message('Nail Art', name: 'serviceArt', desc: '', args: []);
  }

  /// `Acrylic Extension`
  String get serviceAcrylic {
    return Intl.message(
      'Acrylic Extension',
      name: 'serviceAcrylic',
      desc: '',
      args: [],
    );
  }

  /// `Book Appointment Now!`
  String get homeCtaTitle {
    return Intl.message(
      'Book Appointment Now!',
      name: 'homeCtaTitle',
      desc: '',
      args: [],
    );
  }

  /// `Book an appointment with Nailify — join us on the journey of exquisite nail art.`
  String get homeCtaSubtitle {
    return Intl.message(
      'Book an appointment with Nailify — join us on the journey of exquisite nail art.',
      name: 'homeCtaSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `BOOK APPOINTMENT NOW`
  String get homeCtaButton {
    return Intl.message(
      'BOOK APPOINTMENT NOW',
      name: 'homeCtaButton',
      desc: '',
      args: [],
    );
  }

  /// `Loyal Customer`
  String get loyalCustomer {
    return Intl.message(
      'Loyal Customer',
      name: 'loyalCustomer',
      desc: '',
      args: [],
    );
  }

  /// `New Customer`
  String get newCustomer {
    return Intl.message(
      'New Customer',
      name: 'newCustomer',
      desc: '',
      args: [],
    );
  }

  /// `VIP Customer`
  String get vipCustomer {
    return Intl.message(
      'VIP Customer',
      name: 'vipCustomer',
      desc: '',
      args: [],
    );
  }

  /// `"I absolutely love my nails! The staff here is very talented and the designs are gorgeous. I will definitely be back!"`
  String get reviewLinhMai {
    return Intl.message(
      '"I absolutely love my nails! The staff here is very talented and the designs are gorgeous. I will definitely be back!"',
      name: 'reviewLinhMai',
      desc: '',
      args: [],
    );
  }

  /// `"The mirror (chrome) polish looks beautiful and the staff is extremely friendly."`
  String get reviewThuNga {
    return Intl.message(
      '"The mirror (chrome) polish looks beautiful and the staff is extremely friendly."',
      name: 'reviewThuNga',
      desc: '',
      args: [],
    );
  }

  /// `"The best nail salon in the area. The attention to detail is incomparable, and my nails stayed on for weeks without chipping!"`
  String get reviewHoangAnh {
    return Intl.message(
      '"The best nail salon in the area. The attention to detail is incomparable, and my nails stayed on for weeks without chipping!"',
      name: 'reviewHoangAnh',
      desc: '',
      args: [],
    );
  }

  /// `My Bookings`
  String get myBookingsTitle {
    return Intl.message(
      'My Bookings',
      name: 'myBookingsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Booking Details`
  String get bookingDetailsTitle {
    return Intl.message(
      'Booking Details',
      name: 'bookingDetailsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Rate Service`
  String get rateService {
    return Intl.message(
      'Rate Service',
      name: 'rateService',
      desc: '',
      args: [],
    );
  }

  /// `Edit Rating`
  String get editRating {
    return Intl.message('Edit Rating', name: 'editRating', desc: '', args: []);
  }

  /// `Book Appointment`
  String get bookAppointmentTitle {
    return Intl.message(
      'Book Appointment',
      name: 'bookAppointmentTitle',
      desc: '',
      args: [],
    );
  }

  /// `Book Service`
  String get bookServiceTitle {
    return Intl.message(
      'Book Service',
      name: 'bookServiceTitle',
      desc: '',
      args: [],
    );
  }

  /// `Nailify Match`
  String get perfectMatchTitle {
    return Intl.message(
      'Nailify Match',
      name: 'perfectMatchTitle',
      desc: '',
      args: [],
    );
  }

  /// `Nail Design`
  String get nailDesignTitle {
    return Intl.message(
      'Nail Design',
      name: 'nailDesignTitle',
      desc: '',
      args: [],
    );
  }

  /// `Select Try-on Method`
  String get selectTryOnMethodTitle {
    return Intl.message(
      'Select Try-on Method',
      name: 'selectTryOnMethodTitle',
      desc: '',
      args: [],
    );
  }

  /// `Discover the design made for you`
  String get quizDiscoverDesign {
    return Intl.message(
      'Discover the design made for you',
      name: 'quizDiscoverDesign',
      desc: '',
      args: [],
    );
  }

  /// `Select multiple answers`
  String get quizSelectMultiple {
    return Intl.message(
      'Select multiple answers',
      name: 'quizSelectMultiple',
      desc: '',
      args: [],
    );
  }

  /// `Analyzing style...`
  String get quizAnalyzingStyle {
    return Intl.message(
      'Analyzing style...',
      name: 'quizAnalyzingStyle',
      desc: '',
      args: [],
    );
  }

  /// `Finding matching colors...`
  String get quizFindingColors {
    return Intl.message(
      'Finding matching colors...',
      name: 'quizFindingColors',
      desc: '',
      args: [],
    );
  }

  /// `Matching with nail collection...`
  String get quizMatchingCollections {
    return Intl.message(
      'Matching with nail collection...',
      name: 'quizMatchingCollections',
      desc: '',
      args: [],
    );
  }

  /// `Almost done...`
  String get quizAlmostDone {
    return Intl.message(
      'Almost done...',
      name: 'quizAlmostDone',
      desc: '',
      args: [],
    );
  }

  /// `Nailify has found the perfect matching nail designs just for you!`
  String get quizBannerFound {
    return Intl.message(
      'Nailify has found the perfect matching nail designs just for you!',
      name: 'quizBannerFound',
      desc: '',
      args: [],
    );
  }

  /// `If you haven't found the right design, Nailify can help.`
  String get quizBannerNotFound {
    return Intl.message(
      'If you haven\'t found the right design, Nailify can help.',
      name: 'quizBannerNotFound',
      desc: '',
      args: [],
    );
  }

  /// `VIEW PERFECT MATCH RESULTS`
  String get quizBannerViewResults {
    return Intl.message(
      'VIEW PERFECT MATCH RESULTS',
      name: 'quizBannerViewResults',
      desc: '',
      args: [],
    );
  }

  /// `Retake Quiz`
  String get quizBannerRetake {
    return Intl.message(
      'Retake Quiz',
      name: 'quizBannerRetake',
      desc: '',
      args: [],
    );
  }

  /// `Design Your Own`
  String get quizBannerDesign {
    return Intl.message(
      'Design Your Own',
      name: 'quizBannerDesign',
      desc: '',
      args: [],
    );
  }

  /// `Take Quiz`
  String get quizBannerTake {
    return Intl.message(
      'Take Quiz',
      name: 'quizBannerTake',
      desc: '',
      args: [],
    );
  }

  /// `Design Details`
  String get nailDetailsTitle {
    return Intl.message(
      'Design Details',
      name: 'nailDetailsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Nail Variants`
  String get nailVariantsLabel {
    return Intl.message(
      'Nail Variants',
      name: 'nailVariantsLabel',
      desc: '',
      args: [],
    );
  }

  /// `Cannot load design details.`
  String get nailDetailsError {
    return Intl.message(
      'Cannot load design details.',
      name: 'nailDetailsError',
      desc: '',
      args: [],
    );
  }

  /// `Color tone {color} matches your preferred color.`
  String colorMatchReason(Object color) {
    return Intl.message(
      'Color tone $color matches your preferred color.',
      name: 'colorMatchReason',
      desc: '',
      args: [color],
    );
  }

  /// `EXCLUSIVE FOR YOU`
  String get forYouTitle {
    return Intl.message(
      'EXCLUSIVE FOR YOU',
      name: 'forYouTitle',
      desc: '',
      args: [],
    );
  }

  /// `Style Recommendation`
  String get styleRecommendation {
    return Intl.message(
      'Style Recommendation',
      name: 'styleRecommendation',
      desc: '',
      args: [],
    );
  }

  /// `Your personal style: `
  String get yourPersonalStyle {
    return Intl.message(
      'Your personal style: ',
      name: 'yourPersonalStyle',
      desc: '',
      args: [],
    );
  }

  /// `DESIGN YOUR OWN NAIL`
  String get designYourOwnNail {
    return Intl.message(
      'DESIGN YOUR OWN NAIL',
      name: 'designYourOwnNail',
      desc: '',
      args: [],
    );
  }

  /// `Premium nail design`
  String get premiumNailDesign {
    return Intl.message(
      'Premium nail design',
      name: 'premiumNailDesign',
      desc: '',
      args: [],
    );
  }

  /// `Why it fits your style`
  String get styleFitReasons {
    return Intl.message(
      'Why it fits your style',
      name: 'styleFitReasons',
      desc: '',
      args: [],
    );
  }

  /// `You may also like`
  String get youMayAlsoLike {
    return Intl.message(
      'You may also like',
      name: 'youMayAlsoLike',
      desc: '',
      args: [],
    );
  }

  /// `Other designs matching your style`
  String get otherStyleFits {
    return Intl.message(
      'Other designs matching your style',
      name: 'otherStyleFits',
      desc: '',
      args: [],
    );
  }

  /// `Try another design`
  String get tryAnotherDesign {
    return Intl.message(
      'Try another design',
      name: 'tryAnotherDesign',
      desc: '',
      args: [],
    );
  }

  /// `No matching designs found`
  String get noMatchingFound {
    return Intl.message(
      'No matching designs found',
      name: 'noMatchingFound',
      desc: '',
      args: [],
    );
  }

  /// `We couldn't find any nail designs matching your attributes. Please try retaking the style quiz.`
  String get noMatchingDesc {
    return Intl.message(
      'We couldn\'t find any nail designs matching your attributes. Please try retaking the style quiz.',
      name: 'noMatchingDesc',
      desc: '',
      args: [],
    );
  }

  /// `Month`
  String get monthHint {
    return Intl.message('Month', name: 'monthHint', desc: '', args: []);
  }

  /// `Year`
  String get yearHint {
    return Intl.message('Year', name: 'yearHint', desc: '', args: []);
  }

  /// `All Months`
  String get allMonths {
    return Intl.message('All Months', name: 'allMonths', desc: '', args: []);
  }

  /// `All Years`
  String get allYears {
    return Intl.message('All Years', name: 'allYears', desc: '', args: []);
  }

  /// `Month {m}`
  String monthFormat(Object m) {
    return Intl.message('Month $m', name: 'monthFormat', desc: '', args: [m]);
  }

  /// `Year {y}`
  String yearFormat(Object y) {
    return Intl.message('Year $y', name: 'yearFormat', desc: '', args: [y]);
  }

  /// `All`
  String get allStatus {
    return Intl.message('All', name: 'allStatus', desc: '', args: []);
  }

  /// `Pending Approval`
  String get statusPending {
    return Intl.message(
      'Pending Approval',
      name: 'statusPending',
      desc: '',
      args: [],
    );
  }

  /// `Ready to Book`
  String get statusApproved {
    return Intl.message(
      'Ready to Book',
      name: 'statusApproved',
      desc: '',
      args: [],
    );
  }

  /// `Artist Assigned`
  String get statusAssigned {
    return Intl.message(
      'Artist Assigned',
      name: 'statusAssigned',
      desc: '',
      args: [],
    );
  }

  /// `Checked In`
  String get statusCheckedIn {
    return Intl.message(
      'Checked In',
      name: 'statusCheckedIn',
      desc: '',
      args: [],
    );
  }

  /// `In Progress`
  String get statusInProgress {
    return Intl.message(
      'In Progress',
      name: 'statusInProgress',
      desc: '',
      args: [],
    );
  }

  /// `Completed`
  String get statusCompleted {
    return Intl.message(
      'Completed',
      name: 'statusCompleted',
      desc: '',
      args: [],
    );
  }

  /// `Artist Reviewed`
  String get statusReviewed {
    return Intl.message(
      'Artist Reviewed',
      name: 'statusReviewed',
      desc: '',
      args: [],
    );
  }

  /// `Repaired`
  String get statusRepaired {
    return Intl.message('Repaired', name: 'statusRepaired', desc: '', args: []);
  }

  /// `Rejected`
  String get statusRejected {
    return Intl.message('Rejected', name: 'statusRejected', desc: '', args: []);
  }

  /// `Cancelled`
  String get statusCancelled {
    return Intl.message(
      'Cancelled',
      name: 'statusCancelled',
      desc: '',
      args: [],
    );
  }

  /// `Scheduled`
  String get bookingTabScheduled {
    return Intl.message(
      'Scheduled',
      name: 'bookingTabScheduled',
      desc: '',
      args: [],
    );
  }

  /// `Waitlist`
  String get bookingTabWaitlist {
    return Intl.message(
      'Waitlist',
      name: 'bookingTabWaitlist',
      desc: '',
      args: [],
    );
  }

  /// `Rescheduled`
  String get bookingTabReschedule {
    return Intl.message(
      'Rescheduled',
      name: 'bookingTabReschedule',
      desc: '',
      args: [],
    );
  }

  /// `Warranty`
  String get warrantyButton {
    return Intl.message('Warranty', name: 'warrantyButton', desc: '', args: []);
  }

  /// `Services`
  String get servicesLabel {
    return Intl.message('Services', name: 'servicesLabel', desc: '', args: []);
  }

  /// `Completed`
  String get completedLabel {
    return Intl.message(
      'Completed',
      name: 'completedLabel',
      desc: '',
      args: [],
    );
  }

  /// `View All Services`
  String get viewAllServices {
    return Intl.message(
      'View All Services',
      name: 'viewAllServices',
      desc: '',
      args: [],
    );
  }

  /// `Find Nearby Salons (View Map)`
  String get findNearbySalons {
    return Intl.message(
      'Find Nearby Salons (View Map)',
      name: 'findNearbySalons',
      desc: '',
      args: [],
    );
  }

  /// `Book This Design`
  String get bookThisDesign {
    return Intl.message(
      'Book This Design',
      name: 'bookThisDesign',
      desc: '',
      args: [],
    );
  }

  /// `Take Another Analysis`
  String get takeAnotherAnalysis {
    return Intl.message(
      'Take Another Analysis',
      name: 'takeAnotherAnalysis',
      desc: '',
      args: [],
    );
  }

  /// `Nail Shape`
  String get tryOnTabShape {
    return Intl.message(
      'Nail Shape',
      name: 'tryOnTabShape',
      desc: '',
      args: [],
    );
  }

  /// `Nail Surface`
  String get tryOnTabSurface {
    return Intl.message(
      'Nail Surface',
      name: 'tryOnTabSurface',
      desc: '',
      args: [],
    );
  }

  /// `Nail Color`
  String get tryOnTabColor {
    return Intl.message(
      'Nail Color',
      name: 'tryOnTabColor',
      desc: '',
      args: [],
    );
  }

  /// `Accessories`
  String get tryOnTabAccessories {
    return Intl.message(
      'Accessories',
      name: 'tryOnTabAccessories',
      desc: '',
      args: [],
    );
  }

  /// `Personal Nail Design`
  String get designPageTitle {
    return Intl.message(
      'Personal Nail Design',
      name: 'designPageTitle',
      desc: '',
      args: [],
    );
  }

  /// `AUTOMATIC FIT DESIGN`
  String get automaticFitDesign {
    return Intl.message(
      'AUTOMATIC FIT DESIGN',
      name: 'automaticFitDesign',
      desc: '',
      args: [],
    );
  }

  /// `Bloom will automatically analyze your skin tone, hand shape, occupation, and preferences from your personality quiz to create a perfect 5-layer nail design.`
  String get automaticFitDesignDesc {
    return Intl.message(
      'Bloom will automatically analyze your skin tone, hand shape, occupation, and preferences from your personality quiz to create a perfect 5-layer nail design.',
      name: 'automaticFitDesignDesc',
      desc: '',
      args: [],
    );
  }

  /// `Suggest nail shapes matching your hand structure`
  String get designFeatureShape {
    return Intl.message(
      'Suggest nail shapes matching your hand structure',
      name: 'designFeatureShape',
      desc: '',
      args: [],
    );
  }

  /// `Match skin-toning colors based on Warm/Cool tone`
  String get designFeatureColor {
    return Intl.message(
      'Match skin-toning colors based on Warm/Cool tone',
      name: 'designFeatureColor',
      desc: '',
      args: [],
    );
  }

  /// `Auto-select exquisite patterns & accessories`
  String get designFeatureAccessories {
    return Intl.message(
      'Auto-select exquisite patterns & accessories',
      name: 'designFeatureAccessories',
      desc: '',
      args: [],
    );
  }

  /// `GENERATE DESIGN`
  String get generateDesignButton {
    return Intl.message(
      'GENERATE DESIGN',
      name: 'generateDesignButton',
      desc: '',
      args: [],
    );
  }

  /// `Tap the arrow button on the right to show the design panel`
  String get tryOnHintText {
    return Intl.message(
      'Tap the arrow button on the right to show the design panel',
      name: 'tryOnHintText',
      desc: '',
      args: [],
    );
  }

  /// `Regenerate`
  String get reGenerateButton {
    return Intl.message(
      'Regenerate',
      name: 'reGenerateButton',
      desc: '',
      args: [],
    );
  }

  /// `Save Design`
  String get saveDesignButton {
    return Intl.message(
      'Save Design',
      name: 'saveDesignButton',
      desc: '',
      args: [],
    );
  }

  /// `Try-on setup saved successfully.`
  String get saveDesignSuccess {
    return Intl.message(
      'Try-on setup saved successfully.',
      name: 'saveDesignSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Please select a nail shape.`
  String get selectNailShapeWarn {
    return Intl.message(
      'Please select a nail shape.',
      name: 'selectNailShapeWarn',
      desc: '',
      args: [],
    );
  }

  /// `Applied this finger's design to all fingers!`
  String get applyToAllSuccess {
    return Intl.message(
      'Applied this finger\'s design to all fingers!',
      name: 'applyToAllSuccess',
      desc: '',
      args: [],
    );
  }

  /// `New matching nail design generated!`
  String get reGenSuccess {
    return Intl.message(
      'New matching nail design generated!',
      name: 'reGenSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Error regenerating design: {error}`
  String reGenError(Object error) {
    return Intl.message(
      'Error regenerating design: $error',
      name: 'reGenError',
      desc: '',
      args: [error],
    );
  }

  /// `System Models`
  String get systemModels {
    return Intl.message(
      'System Models',
      name: 'systemModels',
      desc: '',
      args: [],
    );
  }

  /// `My Components`
  String get myComponents {
    return Intl.message(
      'My Components',
      name: 'myComponents',
      desc: '',
      args: [],
    );
  }

  /// `No accessory selected on nail`
  String get noAccessorySelected {
    return Intl.message(
      'No accessory selected on nail',
      name: 'noAccessorySelected',
      desc: '',
      args: [],
    );
  }

  /// `Add to nail`
  String get addToNail {
    return Intl.message('Add to nail', name: 'addToNail', desc: '', args: []);
  }

  /// `GENERATING PERSONALIZED DESIGN`
  String get generatingPersonalizedDesign {
    return Intl.message(
      'GENERATING PERSONALIZED DESIGN',
      name: 'generatingPersonalizedDesign',
      desc: '',
      args: [],
    );
  }

  /// `Failed to generate design`
  String get failedGenerateDesign {
    return Intl.message(
      'Failed to generate design',
      name: 'failedGenerateDesign',
      desc: '',
      args: [],
    );
  }

  /// `An error occurred while fetching recommended nail design based on your preferences.`
  String get failedGenerateDesignDesc {
    return Intl.message(
      'An error occurred while fetching recommended nail design based on your preferences.',
      name: 'failedGenerateDesignDesc',
      desc: '',
      args: [],
    );
  }

  /// `Try changing the month, year, or status filter.`
  String get tryChangeFilter {
    return Intl.message(
      'Try changing the month, year, or status filter.',
      name: 'tryChangeFilter',
      desc: '',
      args: [],
    );
  }

  /// `Book a nail appointment now to get started!`
  String get bookNowHint {
    return Intl.message(
      'Book a nail appointment now to get started!',
      name: 'bookNowHint',
      desc: '',
      args: [],
    );
  }

  /// `Explore Services`
  String get exploreServices {
    return Intl.message(
      'Explore Services',
      name: 'exploreServices',
      desc: '',
      args: [],
    );
  }

  /// `Nail Service`
  String get nailServiceDefault {
    return Intl.message(
      'Nail Service',
      name: 'nailServiceDefault',
      desc: '',
      args: [],
    );
  }

  /// `Any Artist`
  String get anyArtist {
    return Intl.message('Any Artist', name: 'anyArtist', desc: '', args: []);
  }

  /// `Error: This booking is missing an ID from the system.`
  String get bookingMissingId {
    return Intl.message(
      'Error: This booking is missing an ID from the system.',
      name: 'bookingMissingId',
      desc: '',
      args: [],
    );
  }

  /// `Warranty Service`
  String get warrantyServiceDefault {
    return Intl.message(
      'Warranty Service',
      name: 'warrantyServiceDefault',
      desc: '',
      args: [],
    );
  }

  /// `Warranty`
  String get warrantyPrefix {
    return Intl.message('Warranty', name: 'warrantyPrefix', desc: '', args: []);
  }

  /// `Waitlist cancelled successfully.`
  String get waitlistCancelSuccess {
    return Intl.message(
      'Waitlist cancelled successfully.',
      name: 'waitlistCancelSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Error cancelling waitlist: {error}`
  String waitlistCancelError(Object error) {
    return Intl.message(
      'Error cancelling waitlist: $error',
      name: 'waitlistCancelError',
      desc: '',
      args: [error],
    );
  }

  /// `Booking confirmed successfully!`
  String get waitlistConfirmSuccess {
    return Intl.message(
      'Booking confirmed successfully!',
      name: 'waitlistConfirmSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Confirm error: {error}`
  String waitlistConfirmError(Object error) {
    return Intl.message(
      'Confirm error: $error',
      name: 'waitlistConfirmError',
      desc: '',
      args: [error],
    );
  }

  /// `Unable to load waitlist`
  String get waitlistLoadError {
    return Intl.message(
      'Unable to load waitlist',
      name: 'waitlistLoadError',
      desc: '',
      args: [],
    );
  }

  /// `No waitlists`
  String get waitlistEmpty {
    return Intl.message(
      'No waitlists',
      name: 'waitlistEmpty',
      desc: '',
      args: [],
    );
  }

  /// `When a slot opens for your registered time,\nthe record will appear here.`
  String get waitlistEmptyDesc {
    return Intl.message(
      'When a slot opens for your registered time,\nthe record will appear here.',
      name: 'waitlistEmptyDesc',
      desc: '',
      args: [],
    );
  }

  /// `WAITING`
  String get waitlistStatusPending {
    return Intl.message(
      'WAITING',
      name: 'waitlistStatusPending',
      desc: '',
      args: [],
    );
  }

  /// `SLOT AVAILABLE`
  String get waitlistStatusOpened {
    return Intl.message(
      'SLOT AVAILABLE',
      name: 'waitlistStatusOpened',
      desc: '',
      args: [],
    );
  }

  /// `Hold time has expired`
  String get waitlistHoldExpired {
    return Intl.message(
      'Hold time has expired',
      name: 'waitlistHoldExpired',
      desc: '',
      args: [],
    );
  }

  /// `Hold ends in: `
  String get waitlistHoldEndsIn {
    return Intl.message(
      'Hold ends in: ',
      name: 'waitlistHoldEndsIn',
      desc: '',
      args: [],
    );
  }

  /// `Registered: `
  String get waitlistRegisteredAt {
    return Intl.message(
      'Registered: ',
      name: 'waitlistRegisteredAt',
      desc: '',
      args: [],
    );
  }

  /// `{n} minutes ago`
  String waitlistMinutesAgo(Object n) {
    return Intl.message(
      '$n minutes ago',
      name: 'waitlistMinutesAgo',
      desc: '',
      args: [n],
    );
  }

  /// `{n} hours ago`
  String waitlistHoursAgo(Object n) {
    return Intl.message(
      '$n hours ago',
      name: 'waitlistHoursAgo',
      desc: '',
      args: [n],
    );
  }

  /// `{n} days ago`
  String waitlistDaysAgo(Object n) {
    return Intl.message(
      '$n days ago',
      name: 'waitlistDaysAgo',
      desc: '',
      args: [n],
    );
  }

  /// `Cancel Wait`
  String get waitlistCancelBtn {
    return Intl.message(
      'Cancel Wait',
      name: 'waitlistCancelBtn',
      desc: '',
      args: [],
    );
  }

  /// `Decline`
  String get waitlistDeclineBtn {
    return Intl.message(
      'Decline',
      name: 'waitlistDeclineBtn',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Booking`
  String get waitlistConfirmBookBtn {
    return Intl.message(
      'Confirm Booking',
      name: 'waitlistConfirmBookBtn',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Cancel Wait`
  String get waitlistCancelDialogTitle {
    return Intl.message(
      'Confirm Cancel Wait',
      name: 'waitlistCancelDialogTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to leave the waitlist at {time}?\nYou will lose your position in the queue.`
  String waitlistCancelDialogContent(Object time) {
    return Intl.message(
      'Are you sure you want to leave the waitlist at $time?\nYou will lose your position in the queue.',
      name: 'waitlistCancelDialogContent',
      desc: '',
      args: [time],
    );
  }

  /// `Keep`
  String get waitlistKeepBtn {
    return Intl.message('Keep', name: 'waitlistKeepBtn', desc: '', args: []);
  }

  /// `Reschedule accepted successfully`
  String get rescheduleAcceptSuccess {
    return Intl.message(
      'Reschedule accepted successfully',
      name: 'rescheduleAcceptSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to accept reschedule`
  String get rescheduleAcceptFail {
    return Intl.message(
      'Failed to accept reschedule',
      name: 'rescheduleAcceptFail',
      desc: '',
      args: [],
    );
  }

  /// `Reschedule declined successfully`
  String get rescheduleDeclineSuccess {
    return Intl.message(
      'Reschedule declined successfully',
      name: 'rescheduleDeclineSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to decline reschedule`
  String get rescheduleDeclineFail {
    return Intl.message(
      'Failed to decline reschedule',
      name: 'rescheduleDeclineFail',
      desc: '',
      args: [],
    );
  }

  /// `Processing...`
  String get rescheduleProcessing {
    return Intl.message(
      'Processing...',
      name: 'rescheduleProcessing',
      desc: '',
      args: [],
    );
  }

  /// `Filter by date`
  String get rescheduleFilterByDate {
    return Intl.message(
      'Filter by date',
      name: 'rescheduleFilterByDate',
      desc: '',
      args: [],
    );
  }

  /// `Date: {date}`
  String rescheduleFilterDate(Object date) {
    return Intl.message(
      'Date: $date',
      name: 'rescheduleFilterDate',
      desc: '',
      args: [date],
    );
  }

  /// `Clear date filter`
  String get rescheduleClearFilter {
    return Intl.message(
      'Clear date filter',
      name: 'rescheduleClearFilter',
      desc: '',
      args: [],
    );
  }

  /// `No reschedule requests on this day`
  String get rescheduleEmptyFiltered {
    return Intl.message(
      'No reschedule requests on this day',
      name: 'rescheduleEmptyFiltered',
      desc: '',
      args: [],
    );
  }

  /// `No reschedule requests`
  String get rescheduleEmptyAll {
    return Intl.message(
      'No reschedule requests',
      name: 'rescheduleEmptyAll',
      desc: '',
      args: [],
    );
  }

  /// `Try selecting a different date or clear the filter.`
  String get rescheduleEmptyFilteredDesc {
    return Intl.message(
      'Try selecting a different date or clear the filter.',
      name: 'rescheduleEmptyFilteredDesc',
      desc: '',
      args: [],
    );
  }

  /// `When a reschedule request from the Salon or\nyour reschedule request is being processed,\nthe record will appear here.`
  String get rescheduleEmptyAllDesc {
    return Intl.message(
      'When a reschedule request from the Salon or\nyour reschedule request is being processed,\nthe record will appear here.',
      name: 'rescheduleEmptyAllDesc',
      desc: '',
      args: [],
    );
  }

  /// `New`
  String get rescheduleNew {
    return Intl.message('New', name: 'rescheduleNew', desc: '', args: []);
  }

  /// `New suggested time from salon:`
  String get rescheduleSuggestedTime {
    return Intl.message(
      'New suggested time from salon:',
      name: 'rescheduleSuggestedTime',
      desc: '',
      args: [],
    );
  }

  /// `Time you requested to reschedule:`
  String get rescheduleRequestedTime {
    return Intl.message(
      'Time you requested to reschedule:',
      name: 'rescheduleRequestedTime',
      desc: '',
      args: [],
    );
  }

  /// `Old schedule: `
  String get rescheduleOldSchedule {
    return Intl.message(
      'Old schedule: ',
      name: 'rescheduleOldSchedule',
      desc: '',
      args: [],
    );
  }

  /// `Reason: `
  String get rescheduleReason {
    return Intl.message(
      'Reason: ',
      name: 'rescheduleReason',
      desc: '',
      args: [],
    );
  }

  /// `Waiting for salon to respond to your reschedule request`
  String get reschedulePendingMsg {
    return Intl.message(
      'Waiting for salon to respond to your reschedule request',
      name: 'reschedulePendingMsg',
      desc: '',
      args: [],
    );
  }

  /// `Decline`
  String get rescheduleDeclineBtn {
    return Intl.message(
      'Decline',
      name: 'rescheduleDeclineBtn',
      desc: '',
      args: [],
    );
  }

  /// `Accept Reschedule`
  String get rescheduleAcceptBtn {
    return Intl.message(
      'Accept Reschedule',
      name: 'rescheduleAcceptBtn',
      desc: '',
      args: [],
    );
  }

  /// `My Studio`
  String get myStudioTitle {
    return Intl.message('My Studio', name: 'myStudioTitle', desc: '', args: []);
  }

  /// `My Nails`
  String get myNailsTab {
    return Intl.message('My Nails', name: 'myNailsTab', desc: '', args: []);
  }

  /// `Accessories`
  String get accessoriesTab {
    return Intl.message(
      'Accessories',
      name: 'accessoriesTab',
      desc: '',
      args: [],
    );
  }

  /// `Requests`
  String get requestsTab {
    return Intl.message('Requests', name: 'requestsTab', desc: '', args: []);
  }

  /// `All`
  String get studioAllTab {
    return Intl.message('All', name: 'studioAllTab', desc: '', args: []);
  }

  /// `Processing`
  String get studioProcessingTab {
    return Intl.message(
      'Processing',
      name: 'studioProcessingTab',
      desc: '',
      args: [],
    );
  }

  /// `Approved`
  String get studioApprovedTab {
    return Intl.message(
      'Approved',
      name: 'studioApprovedTab',
      desc: '',
      args: [],
    );
  }

  /// `Rejected`
  String get studioRejectedTab {
    return Intl.message(
      'Rejected',
      name: 'studioRejectedTab',
      desc: '',
      args: [],
    );
  }

  /// `No approval requests yet.`
  String get studioNoRequests {
    return Intl.message(
      'No approval requests yet.',
      name: 'studioNoRequests',
      desc: '',
      args: [],
    );
  }

  /// `Create New`
  String get studioCreateNew {
    return Intl.message(
      'Create New',
      name: 'studioCreateNew',
      desc: '',
      args: [],
    );
  }

  /// `Booking Successful!`
  String get bookingSuccessTitle {
    return Intl.message(
      'Booking Successful!',
      name: 'bookingSuccessTitle',
      desc: '',
      args: [],
    );
  }

  /// `Thank you for trusting Nailify. Here are the details of your appointment.`
  String get bookingSuccessSubtitle {
    return Intl.message(
      'Thank you for trusting Nailify. Here are the details of your appointment.',
      name: 'bookingSuccessSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Service`
  String get bookingInfoService {
    return Intl.message(
      'Service',
      name: 'bookingInfoService',
      desc: '',
      args: [],
    );
  }

  /// `Appointment Date`
  String get bookingInfoDate {
    return Intl.message(
      'Appointment Date',
      name: 'bookingInfoDate',
      desc: '',
      args: [],
    );
  }

  /// `Time`
  String get bookingInfoTime {
    return Intl.message('Time', name: 'bookingInfoTime', desc: '', args: []);
  }

  /// `Staff`
  String get bookingInfoStaff {
    return Intl.message('Staff', name: 'bookingInfoStaff', desc: '', args: []);
  }

  /// `Original Price`
  String get bookingInfoOriginalPrice {
    return Intl.message(
      'Original Price',
      name: 'bookingInfoOriginalPrice',
      desc: '',
      args: [],
    );
  }

  /// `Total Payment`
  String get bookingInfoTotal {
    return Intl.message(
      'Total Payment',
      name: 'bookingInfoTotal',
      desc: '',
      args: [],
    );
  }

  /// `Pay Now`
  String get bookingPayBtn {
    return Intl.message('Pay Now', name: 'bookingPayBtn', desc: '', args: []);
  }

  /// `View Booking`
  String get bookingViewBtn {
    return Intl.message(
      'View Booking',
      name: 'bookingViewBtn',
      desc: '',
      args: [],
    );
  }

  /// `Go to Home`
  String get bookingGoHome {
    return Intl.message(
      'Go to Home',
      name: 'bookingGoHome',
      desc: '',
      args: [],
    );
  }

  /// `Unable to create payment: {error}`
  String bookingPaymentError(Object error) {
    return Intl.message(
      'Unable to create payment: $error',
      name: 'bookingPaymentError',
      desc: '',
      args: [error],
    );
  }

  /// `Discount`
  String get bookingDiscount {
    return Intl.message(
      'Discount',
      name: 'bookingDiscount',
      desc: '',
      args: [],
    );
  }

  /// `Cancel Booking`
  String get cancelBookingTitle {
    return Intl.message(
      'Cancel Booking',
      name: 'cancelBookingTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to cancel this booking?`
  String get cancelBookingConfirmMsg {
    return Intl.message(
      'Are you sure you want to cancel this booking?',
      name: 'cancelBookingConfirmMsg',
      desc: '',
      args: [],
    );
  }

  /// `Enter reason for cancellation (max 50 words)`
  String get cancelBookingReasonHint {
    return Intl.message(
      'Enter reason for cancellation (max 50 words)',
      name: 'cancelBookingReasonHint',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a reason`
  String get cancelBookingReasonRequired {
    return Intl.message(
      'Please enter a reason',
      name: 'cancelBookingReasonRequired',
      desc: '',
      args: [],
    );
  }

  /// `Reason cannot exceed 50 words`
  String get cancelBookingReasonTooLong {
    return Intl.message(
      'Reason cannot exceed 50 words',
      name: 'cancelBookingReasonTooLong',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancelBtn {
    return Intl.message('Cancel', name: 'cancelBtn', desc: '', args: []);
  }

  /// `Confirm`
  String get confirmBtn {
    return Intl.message('Confirm', name: 'confirmBtn', desc: '', args: []);
  }

  /// `Search nail designs...`
  String get searchNailHint {
    return Intl.message(
      'Search nail designs...',
      name: 'searchNailHint',
      desc: '',
      args: [],
    );
  }

  /// `Search components...`
  String get searchComponentHint {
    return Intl.message(
      'Search components...',
      name: 'searchComponentHint',
      desc: '',
      args: [],
    );
  }

  /// `All`
  String get filterAll {
    return Intl.message('All', name: 'filterAll', desc: '', args: []);
  }

  /// `Public`
  String get filterPublic {
    return Intl.message('Public', name: 'filterPublic', desc: '', args: []);
  }

  /// `Private`
  String get filterPrivate {
    return Intl.message('Private', name: 'filterPrivate', desc: '', args: []);
  }

  /// `Type`
  String get filterType {
    return Intl.message('Type', name: 'filterType', desc: '', args: []);
  }

  /// `Create New`
  String get createNewBtn {
    return Intl.message('Create New', name: 'createNewBtn', desc: '', args: []);
  }

  /// `Delete Nail Design`
  String get deleteNailTitle {
    return Intl.message(
      'Delete Nail Design',
      name: 'deleteNailTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete "{name}"?`
  String deleteNailConfirm(Object name) {
    return Intl.message(
      'Are you sure you want to delete "$name"?',
      name: 'deleteNailConfirm',
      desc: '',
      args: [name],
    );
  }

  /// `Delete Component`
  String get deleteComponentTitle {
    return Intl.message(
      'Delete Component',
      name: 'deleteComponentTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete "{name}"?`
  String deleteComponentConfirm(Object name) {
    return Intl.message(
      'Are you sure you want to delete "$name"?',
      name: 'deleteComponentConfirm',
      desc: '',
      args: [name],
    );
  }

  /// `Delete`
  String get deleteBtn {
    return Intl.message('Delete', name: 'deleteBtn', desc: '', args: []);
  }

  /// `Retry`
  String get retryBtn {
    return Intl.message('Retry', name: 'retryBtn', desc: '', args: []);
  }

  /// `No nail designs yet`
  String get noNailDesigns {
    return Intl.message(
      'No nail designs yet',
      name: 'noNailDesigns',
      desc: '',
      args: [],
    );
  }

  /// `Create New Nail Design`
  String get createNewNailBtn {
    return Intl.message(
      'Create New Nail Design',
      name: 'createNewNailBtn',
      desc: '',
      args: [],
    );
  }

  /// `No components yet`
  String get noComponents {
    return Intl.message(
      'No components yet',
      name: 'noComponents',
      desc: '',
      args: [],
    );
  }

  /// `All statuses`
  String get filterAllStatus {
    return Intl.message(
      'All statuses',
      name: 'filterAllStatus',
      desc: '',
      args: [],
    );
  }

  /// `No requests yet.`
  String get noRequests {
    return Intl.message(
      'No requests yet.',
      name: 'noRequests',
      desc: '',
      args: [],
    );
  }

  /// `Send Request`
  String get sendRequestBtn {
    return Intl.message(
      'Send Request',
      name: 'sendRequestBtn',
      desc: '',
      args: [],
    );
  }

  /// `Send Design Request`
  String get sendRequestTitle {
    return Intl.message(
      'Send Design Request',
      name: 'sendRequestTitle',
      desc: '',
      args: [],
    );
  }

  /// `Nail Design *`
  String get selectNailLabel {
    return Intl.message(
      'Nail Design *',
      name: 'selectNailLabel',
      desc: '',
      args: [],
    );
  }

  /// `Select nail design...`
  String get selectNailHint {
    return Intl.message(
      'Select nail design...',
      name: 'selectNailHint',
      desc: '',
      args: [],
    );
  }

  /// `Select Salon branch...`
  String get selectSalonHint {
    return Intl.message(
      'Select Salon branch...',
      name: 'selectSalonHint',
      desc: '',
      args: [],
    );
  }

  /// `Send`
  String get sendBtn {
    return Intl.message('Send', name: 'sendBtn', desc: '', args: []);
  }

  /// `Request sent successfully.`
  String get sendRequestSuccess {
    return Intl.message(
      'Request sent successfully.',
      name: 'sendRequestSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to send request: {error}`
  String sendRequestFail(Object error) {
    return Intl.message(
      'Failed to send request: $error',
      name: 'sendRequestFail',
      desc: '',
      args: [error],
    );
  }

  /// `Unable to load form: {error}`
  String loadFormFail(Object error) {
    return Intl.message(
      'Unable to load form: $error',
      name: 'loadFormFail',
      desc: '',
      args: [error],
    );
  }

  /// `Select Nail Design`
  String get selectNailTitle {
    return Intl.message(
      'Select Nail Design',
      name: 'selectNailTitle',
      desc: '',
      args: [],
    );
  }

  /// `No nail designs found`
  String get noNailFound {
    return Intl.message(
      'No nail designs found',
      name: 'noNailFound',
      desc: '',
      args: [],
    );
  }

  /// `Select Salon Branch`
  String get selectSalonTitle {
    return Intl.message(
      'Select Salon Branch',
      name: 'selectSalonTitle',
      desc: '',
      args: [],
    );
  }

  /// `No salons found`
  String get noSalonFound {
    return Intl.message(
      'No salons found',
      name: 'noSalonFound',
      desc: '',
      args: [],
    );
  }

  /// `Address updating`
  String get addressUpdating {
    return Intl.message(
      'Address updating',
      name: 'addressUpdating',
      desc: '',
      args: [],
    );
  }

  /// `Pending review`
  String get statusPendingReview {
    return Intl.message(
      'Pending review',
      name: 'statusPendingReview',
      desc: '',
      args: [],
    );
  }

  /// `Under Review`
  String get statusReview {
    return Intl.message(
      'Under Review',
      name: 'statusReview',
      desc: '',
      args: [],
    );
  }

  /// `Quoted`
  String get statusQuoted {
    return Intl.message('Quoted', name: 'statusQuoted', desc: '', args: []);
  }

  /// `Select Salon`
  String get bookingStepSelectSalon {
    return Intl.message(
      'Select Salon',
      name: 'bookingStepSelectSalon',
      desc: '',
      args: [],
    );
  }

  /// `Services`
  String get bookingStepServices {
    return Intl.message(
      'Services',
      name: 'bookingStepServices',
      desc: '',
      args: [],
    );
  }

  /// `Book`
  String get bookingStepBook {
    return Intl.message('Book', name: 'bookingStepBook', desc: '', args: []);
  }

  /// `Completed`
  String get bookingStepCompleted {
    return Intl.message(
      'Completed',
      name: 'bookingStepCompleted',
      desc: '',
      args: [],
    );
  }

  /// `Please select a salon branch.`
  String get bookingValidateSalon {
    return Intl.message(
      'Please select a salon branch.',
      name: 'bookingValidateSalon',
      desc: '',
      args: [],
    );
  }

  /// `Please select or remove the empty service.`
  String get bookingValidateService {
    return Intl.message(
      'Please select or remove the empty service.',
      name: 'bookingValidateService',
      desc: '',
      args: [],
    );
  }

  /// `Please select at least one service.`
  String get bookingValidateServiceMin {
    return Intl.message(
      'Please select at least one service.',
      name: 'bookingValidateServiceMin',
      desc: '',
      args: [],
    );
  }

  /// `Please fill in date, artist and time slot.`
  String get bookingValidateDateTime {
    return Intl.message(
      'Please fill in date, artist and time slot.',
      name: 'bookingValidateDateTime',
      desc: '',
      args: [],
    );
  }

  /// `Branch`
  String get bookingSummaryBranch {
    return Intl.message(
      'Branch',
      name: 'bookingSummaryBranch',
      desc: '',
      args: [],
    );
  }

  /// `Date`
  String get bookingSummaryDate {
    return Intl.message('Date', name: 'bookingSummaryDate', desc: '', args: []);
  }

  /// `Time`
  String get bookingSummaryTime {
    return Intl.message('Time', name: 'bookingSummaryTime', desc: '', args: []);
  }

  /// `Artist`
  String get bookingSummaryArtist {
    return Intl.message(
      'Artist',
      name: 'bookingSummaryArtist',
      desc: '',
      args: [],
    );
  }

  /// `Auto-assign`
  String get bookingAutoAssign {
    return Intl.message(
      'Auto-assign',
      name: 'bookingAutoAssign',
      desc: '',
      args: [],
    );
  }

  /// `Payment Details`
  String get bookingPaymentDetails {
    return Intl.message(
      'Payment Details',
      name: 'bookingPaymentDetails',
      desc: '',
      args: [],
    );
  }

  /// `Add-on: {name}`
  String bookingExtraService(String name) {
    return Intl.message(
      'Add-on: $name',
      name: 'bookingExtraService',
      desc: '',
      args: [name],
    );
  }

  /// `Total`
  String get bookingTotal {
    return Intl.message('Total', name: 'bookingTotal', desc: '', args: []);
  }

  /// `Nail Variant`
  String get bookingNailVariantDefault {
    return Intl.message(
      'Nail Variant',
      name: 'bookingNailVariantDefault',
      desc: '',
      args: [],
    );
  }

  /// `Nail Component`
  String get bookingComponentDefault {
    return Intl.message(
      'Nail Component',
      name: 'bookingComponentDefault',
      desc: '',
      args: [],
    );
  }

  /// `Promotion`
  String get bookingPromotion {
    return Intl.message(
      'Promotion',
      name: 'bookingPromotion',
      desc: '',
      args: [],
    );
  }

  /// `No promotion applied`
  String get bookingNoPromotion {
    return Intl.message(
      'No promotion applied',
      name: 'bookingNoPromotion',
      desc: '',
      args: [],
    );
  }

  /// `No promotions available.`
  String get bookingNoPromotionAvailable {
    return Intl.message(
      'No promotions available.',
      name: 'bookingNoPromotionAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Apply ({count})`
  String bookingApplyPromotion(String count) {
    return Intl.message(
      'Apply ($count)',
      name: 'bookingApplyPromotion',
      desc: '',
      args: [count],
    );
  }

  /// `No promotion`
  String get bookingNoApply {
    return Intl.message(
      'No promotion',
      name: 'bookingNoApply',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get bookingBackBtn {
    return Intl.message('Back', name: 'bookingBackBtn', desc: '', args: []);
  }

  /// `Continue`
  String get bookingContinueBtn {
    return Intl.message(
      'Continue',
      name: 'bookingContinueBtn',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Booking`
  String get bookingConfirmBtn {
    return Intl.message(
      'Confirm Booking',
      name: 'bookingConfirmBtn',
      desc: '',
      args: [],
    );
  }

  /// `Select Date`
  String get bookingSelectDateTitle {
    return Intl.message(
      'Select Date',
      name: 'bookingSelectDateTitle',
      desc: '',
      args: [],
    );
  }

  /// `{month}/{year}`
  String bookingMonthYear(String month, String year) {
    return Intl.message(
      '$month/$year',
      name: 'bookingMonthYear',
      desc: '',
      args: [month, year],
    );
  }

  /// `No branches available.`
  String get bookingNoBranch {
    return Intl.message(
      'No branches available.',
      name: 'bookingNoBranch',
      desc: '',
      args: [],
    );
  }

  /// `Find Nearby Salons (View Map)`
  String get bookingFindNearby {
    return Intl.message(
      'Find Nearby Salons (View Map)',
      name: 'bookingFindNearby',
      desc: '',
      args: [],
    );
  }

  /// `Main Service`
  String get bookingMainService {
    return Intl.message(
      'Main Service',
      name: 'bookingMainService',
      desc: '',
      args: [],
    );
  }

  /// `Select warranty service`
  String get bookingWarrantyService {
    return Intl.message(
      'Select warranty service',
      name: 'bookingWarrantyService',
      desc: '',
      args: [],
    );
  }

  /// `Warranty Service`
  String get bookingWarrantyDefault {
    return Intl.message(
      'Warranty Service',
      name: 'bookingWarrantyDefault',
      desc: '',
      args: [],
    );
  }

  /// `Free warranty • Qty: {qty}`
  String bookingWarrantyFree(String qty) {
    return Intl.message(
      'Free warranty • Qty: $qty',
      name: 'bookingWarrantyFree',
      desc: '',
      args: [qty],
    );
  }

  /// `Add-on Services`
  String get bookingAddonServices {
    return Intl.message(
      'Add-on Services',
      name: 'bookingAddonServices',
      desc: '',
      args: [],
    );
  }

  /// `Selected: {count}`
  String bookingSelectedCount(String count) {
    return Intl.message(
      'Selected: $count',
      name: 'bookingSelectedCount',
      desc: '',
      args: [count],
    );
  }

  /// `No add-on services available.`
  String get bookingNoAddon {
    return Intl.message(
      'No add-on services available.',
      name: 'bookingNoAddon',
      desc: '',
      args: [],
    );
  }

  /// `Quantity`
  String get bookingQtyLabel {
    return Intl.message(
      'Quantity',
      name: 'bookingQtyLabel',
      desc: '',
      args: [],
    );
  }

  /// `Add Service`
  String get bookingAddService {
    return Intl.message(
      'Add Service',
      name: 'bookingAddService',
      desc: '',
      args: [],
    );
  }

  /// `Add Add-on Service`
  String get bookingAddServiceTitle {
    return Intl.message(
      'Add Add-on Service',
      name: 'bookingAddServiceTitle',
      desc: '',
      args: [],
    );
  }

  /// `Select Artist`
  String get bookingSelectArtistTitle {
    return Intl.message(
      'Select Artist',
      name: 'bookingSelectArtistTitle',
      desc: '',
      args: [],
    );
  }

  /// `Please select a date first`
  String get bookingArtistNoDate {
    return Intl.message(
      'Please select a date first',
      name: 'bookingArtistNoDate',
      desc: '',
      args: [],
    );
  }

  /// `No artists available on this date.`
  String get bookingNoArtistAvailable {
    return Intl.message(
      'No artists available on this date.',
      name: 'bookingNoArtistAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Artist`
  String get bookingArtistTab {
    return Intl.message('Artist', name: 'bookingArtistTab', desc: '', args: []);
  }

  /// `No preference`
  String get bookingNoArtistTab {
    return Intl.message(
      'No preference',
      name: 'bookingNoArtistTab',
      desc: '',
      args: [],
    );
  }

  /// `Available Slots`
  String get bookingAvailableSlots {
    return Intl.message(
      'Available Slots',
      name: 'bookingAvailableSlots',
      desc: '',
      args: [],
    );
  }

  /// `Please select an artist (or "No preference") to see available slots.`
  String get bookingSelectArtistFirst {
    return Intl.message(
      'Please select an artist (or "No preference") to see available slots.',
      name: 'bookingSelectArtistFirst',
      desc: '',
      args: [],
    );
  }

  /// `This artist has no schedule on this date.`
  String get bookingNoSchedule {
    return Intl.message(
      'This artist has no schedule on this date.',
      name: 'bookingNoSchedule',
      desc: '',
      args: [],
    );
  }

  /// `This time has passed, please choose another.`
  String get bookingSlotPast {
    return Intl.message(
      'This time has passed, please choose another.',
      name: 'bookingSlotPast',
      desc: '',
      args: [],
    );
  }

  /// `You have joined the waitlist for {time}`
  String bookingWaitlistJoined(String time) {
    return Intl.message(
      'You have joined the waitlist for $time',
      name: 'bookingWaitlistJoined',
      desc: '',
      args: [time],
    );
  }

  /// `Select Promotion`
  String get bookingSelectPromotion {
    return Intl.message(
      'Select Promotion',
      name: 'bookingSelectPromotion',
      desc: '',
      args: [],
    );
  }

  /// `Clear all`
  String get bookingClearAll {
    return Intl.message(
      'Clear all',
      name: 'bookingClearAll',
      desc: '',
      args: [],
    );
  }

  /// `{value}% off`
  String bookingDiscountPercent(String value) {
    return Intl.message(
      '$value% off',
      name: 'bookingDiscountPercent',
      desc: '',
      args: [value],
    );
  }

  /// `{value} off`
  String bookingDiscountFixed(String value) {
    return Intl.message(
      '$value off',
      name: 'bookingDiscountFixed',
      desc: '',
      args: [value],
    );
  }

  /// `No promotions available`
  String get bookingNoPromotions {
    return Intl.message(
      'No promotions available',
      name: 'bookingNoPromotions',
      desc: '',
      args: [],
    );
  }

  /// `Retry`
  String get bookingRetry {
    return Intl.message('Retry', name: 'bookingRetry', desc: '', args: []);
  }

  /// `Error joining waitlist: {error}`
  String bookingWaitlistError(String error) {
    return Intl.message(
      'Error joining waitlist: $error',
      name: 'bookingWaitlistError',
      desc: '',
      args: [error],
    );
  }

  /// `{price} / piece`
  String bookingUnitPrice(String price) {
    return Intl.message(
      '$price / piece',
      name: 'bookingUnitPrice',
      desc: '',
      args: [price],
    );
  }

  /// `Transaction Details`
  String get transactionDetails {
    return Intl.message(
      'Transaction Details',
      name: 'transactionDetails',
      desc: '',
      args: [],
    );
  }

  /// `Refund Information`
  String get refundInfo {
    return Intl.message(
      'Refund Information',
      name: 'refundInfo',
      desc: '',
      args: [],
    );
  }

  /// `Payment`
  String get paymentTitle {
    return Intl.message('Payment', name: 'paymentTitle', desc: '', args: []);
  }

  /// `Book Custom Nail`
  String get bookCustomNailTitle {
    return Intl.message(
      'Book Custom Nail',
      name: 'bookCustomNailTitle',
      desc: '',
      args: [],
    );
  }

  /// `Request Detail`
  String get requestDetailTitle {
    return Intl.message(
      'Request Detail',
      name: 'requestDetailTitle',
      desc: '',
      args: [],
    );
  }

  /// `Authentication Required`
  String get loginRequiredTitle {
    return Intl.message(
      'Authentication Required',
      name: 'loginRequiredTitle',
      desc: '',
      args: [],
    );
  }

  /// `Please sign in or register an account to use this feature.`
  String get loginRequiredMessage {
    return Intl.message(
      'Please sign in or register an account to use this feature.',
      name: 'loginRequiredMessage',
      desc: '',
      args: [],
    );
  }

  /// `Please sign in to view your personal profile`
  String get pleaseLoginToViewProfile {
    return Intl.message(
      'Please sign in to view your personal profile',
      name: 'pleaseLoginToViewProfile',
      desc: '',
      args: [],
    );
  }

  /// `Language`
  String get languageLabel {
    return Intl.message('Language', name: 'languageLabel', desc: '', args: []);
  }

  /// `Forgot password?`
  String get forgotPassword {
    return Intl.message(
      'Forgot password?',
      name: 'forgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Don't have an account? `
  String get dontHaveAccount {
    return Intl.message(
      "Don't have an account? ",
      name: 'dontHaveAccount',
      desc: '',
      args: [],
    );
  }

  /// `Register now`
  String get registerNow {
    return Intl.message(
      'Register now',
      name: 'registerNow',
      desc: '',
      args: [],
    );
  }

  /// `Please enter both Email and Password`
  String get loginRequiredFields {
    return Intl.message(
      'Please enter both Email and Password',
      name: 'loginRequiredFields',
      desc: '',
      args: [],
    );
  }

  /// `Logged in successfully`
  String get loginSuccess {
    return Intl.message(
      'Logged in successfully',
      name: 'loginSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Already have an account? `
  String get alreadyHaveAccount {
    return Intl.message(
      'Already have an account? ',
      name: 'alreadyHaveAccount',
      desc: '',
      args: [],
    );
  }

  /// `Please fill in all required fields`
  String get registerRequiredFields {
    return Intl.message(
      'Please fill in all required fields',
      name: 'registerRequiredFields',
      desc: '',
      args: [],
    );
  }

  /// `Confirm password does not match`
  String get passwordMismatch {
    return Intl.message(
      'Confirm password does not match',
      name: 'passwordMismatch',
      desc: '',
      args: [],
    );
  }

  /// `You must agree to the terms of service to continue`
  String get agreeToTermsError {
    return Intl.message(
      'You must agree to the terms of service to continue',
      name: 'agreeToTermsError',
      desc: '',
      args: [],
    );
  }

  /// `Account registered successfully`
  String get registerSuccess {
    return Intl.message(
      'Account registered successfully',
      name: 'registerSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Register Account`
  String get registerTitle {
    return Intl.message(
      'Register Account',
      name: 'registerTitle',
      desc: '',
      args: [],
    );
  }

  /// `First Name`
  String get firstNameHint {
    return Intl.message(
      'First Name',
      name: 'firstNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Last Name`
  String get lastNameHint {
    return Intl.message('Last Name', name: 'lastNameHint', desc: '', args: []);
  }

  /// `Confirm Password`
  String get confirmPasswordHint {
    return Intl.message(
      'Confirm Password',
      name: 'confirmPasswordHint',
      desc: '',
      args: [],
    );
  }

  /// `I agree to the terms of service`
  String get agreeToTermsText {
    return Intl.message(
      'I agree to the terms of service',
      name: 'agreeToTermsText',
      desc: '',
      args: [],
    );
  }

  /// `Artist`
  String get bookingArtistDefault {
    return Intl.message(
      'Artist',
      name: 'bookingArtistDefault',
      desc: '',
      args: [],
    );
  }

  /// `Loading artist list...`
  String get bookingLoadingArtists {
    return Intl.message(
      'Loading artist list...',
      name: 'bookingLoadingArtists',
      desc: '',
      args: [],
    );
  }

  /// `Click to choose performing artist`
  String get bookingClickToSelectArtist {
    return Intl.message(
      'Click to choose performing artist',
      name: 'bookingClickToSelectArtist',
      desc: '',
      args: [],
    );
  }

  /// `Auto-assignment by system`
  String get bookingAutoAssignTitle {
    return Intl.message(
      'Auto-assignment by system',
      name: 'bookingAutoAssignTitle',
      desc: '',
      args: [],
    );
  }

  /// `Time displayed based on salon schedule. Artist will be auto-assigned.`
  String get bookingAutoAssignDesc {
    return Intl.message(
      'Time displayed based on salon schedule. Artist will be auto-assigned.',
      name: 'bookingAutoAssignDesc',
      desc: '',
      args: [],
    );
  }

  /// `General Information`
  String get bookingGeneralInfo {
    return Intl.message(
      'General Information',
      name: 'bookingGeneralInfo',
      desc: '',
      args: [],
    );
  }

  /// `Branch`
  String get bookingBranchLabel {
    return Intl.message(
      'Branch',
      name: 'bookingBranchLabel',
      desc: '',
      args: [],
    );
  }

  /// `Stylist`
  String get bookingStylistLabel {
    return Intl.message(
      'Stylist',
      name: 'bookingStylistLabel',
      desc: '',
      args: [],
    );
  }

  /// `Date`
  String get bookingDateLabel {
    return Intl.message('Date', name: 'bookingDateLabel', desc: '', args: []);
  }

  /// `Start Time`
  String get bookingStartTimeLabel {
    return Intl.message(
      'Start Time',
      name: 'bookingStartTimeLabel',
      desc: '',
      args: [],
    );
  }

  /// `Duration`
  String get bookingDurationLabel {
    return Intl.message(
      'Duration',
      name: 'bookingDurationLabel',
      desc: '',
      args: [],
    );
  }

  /// `{minutes} minutes`
  String bookingDurationValue(Object minutes) {
    return Intl.message(
      '$minutes minutes',
      name: 'bookingDurationValue',
      desc: '',
      args: [minutes],
    );
  }

  /// `Services Booked`
  String get bookingServicesBooked {
    return Intl.message(
      'Services Booked',
      name: 'bookingServicesBooked',
      desc: '',
      args: [],
    );
  }

  /// `Qty: {qty}`
  String bookingQuantityLabel(Object qty) {
    return Intl.message(
      'Qty: $qty',
      name: 'bookingQuantityLabel',
      desc: '',
      args: [qty],
    );
  }

  /// `Original Price:`
  String get bookingOriginalPriceLabel {
    return Intl.message(
      'Original Price:',
      name: 'bookingOriginalPriceLabel',
      desc: '',
      args: [],
    );
  }

  /// `Discount:`
  String get bookingDiscountLabel {
    return Intl.message(
      'Discount:',
      name: 'bookingDiscountLabel',
      desc: '',
      args: [],
    );
  }

  /// `Total Payment:`
  String get bookingTotalPaymentLabel {
    return Intl.message(
      'Total Payment:',
      name: 'bookingTotalPaymentLabel',
      desc: '',
      args: [],
    );
  }

  /// `Review`
  String get bookingReviewTitle {
    return Intl.message(
      'Review',
      name: 'bookingReviewTitle',
      desc: '',
      args: [],
    );
  }

  /// `Rating Details`
  String get bookingRatingDetails {
    return Intl.message(
      'Rating Details',
      name: 'bookingRatingDetails',
      desc: '',
      args: [],
    );
  }

  /// `Overall`
  String get ratingOverall {
    return Intl.message('Overall', name: 'ratingOverall', desc: '', args: []);
  }

  /// `Service Quality`
  String get ratingServiceQuality {
    return Intl.message(
      'Service Quality',
      name: 'ratingServiceQuality',
      desc: '',
      args: [],
    );
  }

  /// `Punctuality`
  String get ratingPunctuality {
    return Intl.message(
      'Punctuality',
      name: 'ratingPunctuality',
      desc: '',
      args: [],
    );
  }

  /// `Cleanliness`
  String get ratingCleanliness {
    return Intl.message(
      'Cleanliness',
      name: 'ratingCleanliness',
      desc: '',
      args: [],
    );
  }

  /// `Could not load rating information.`
  String get ratingLoadError {
    return Intl.message(
      'Could not load rating information.',
      name: 'ratingLoadError',
      desc: '',
      args: [],
    );
  }

  /// `Booking information not found.`
  String get bookingNotFound {
    return Intl.message(
      'Booking information not found.',
      name: 'bookingNotFound',
      desc: '',
      args: [],
    );
  }

  /// `Paid:`
  String get bookingPaidAmount {
    return Intl.message('Paid:', name: 'bookingPaidAmount', desc: '', args: []);
  }

  /// `Remaining:`
  String get bookingRemainingAmount {
    return Intl.message(
      'Remaining:',
      name: 'bookingRemainingAmount',
      desc: '',
      args: [],
    );
  }

  /// `Your Rating`
  String get bookingYourRating {
    return Intl.message(
      'Your Rating',
      name: 'bookingYourRating',
      desc: '',
      args: [],
    );
  }

  /// `Check-in Code`
  String get bookingCheckInCode {
    return Intl.message(
      'Check-in Code',
      name: 'bookingCheckInCode',
      desc: '',
      args: [],
    );
  }

  /// `Show this code to the receptionist`
  String get bookingCheckInInstruction {
    return Intl.message(
      'Show this code to the receptionist',
      name: 'bookingCheckInInstruction',
      desc: '',
      args: [],
    );
  }

  /// `Reschedule request sent successfully`
  String get bookingRescheduleSuccess {
    return Intl.message(
      'Reschedule request sent successfully',
      name: 'bookingRescheduleSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to send reschedule request`
  String get bookingRescheduleFail {
    return Intl.message(
      'Failed to send reschedule request',
      name: 'bookingRescheduleFail',
      desc: '',
      args: [],
    );
  }

  /// `Booking cancelled successfully`
  String get bookingCancelSuccess {
    return Intl.message(
      'Booking cancelled successfully',
      name: 'bookingCancelSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Failed to cancel booking`
  String get bookingCancelFail {
    return Intl.message(
      'Failed to cancel booking',
      name: 'bookingCancelFail',
      desc: '',
      args: [],
    );
  }

  /// `Cancel Booking`
  String get bookingCancelBtnLabel {
    return Intl.message(
      'Cancel Booking',
      name: 'bookingCancelBtnLabel',
      desc: '',
      args: [],
    );
  }

  /// `Reschedule Appointment`
  String get bookingRescheduleBtnLabel {
    return Intl.message(
      'Reschedule Appointment',
      name: 'bookingRescheduleBtnLabel',
      desc: '',
      args: [],
    );
  }

  /// `Error displaying QR code`
  String get bookingQrError {
    return Intl.message(
      'Error displaying QR code',
      name: 'bookingQrError',
      desc: '',
      args: [],
    );
  }

  /// `fingers`
  String get bookingFingersLabel {
    return Intl.message(
      'fingers',
      name: 'bookingFingersLabel',
      desc: '',
      args: [],
    );
  }

  /// `Clear filter`
  String get clearFilter {
    return Intl.message(
      'Clear filter',
      name: 'clearFilter',
      desc: '',
      args: [],
    );
  }

  /// `Cannot load nail designs.`
  String get nailLoadError {
    return Intl.message(
      'Cannot load nail designs.',
      name: 'nailLoadError',
      desc: '',
      args: [],
    );
  }

  /// `Recommended`
  String get recommended {
    return Intl.message('Recommended', name: 'recommended', desc: '', args: []);
  }

  /// `Nail design`
  String get nailDesignFallback {
    return Intl.message(
      'Nail design',
      name: 'nailDesignFallback',
      desc: '',
      args: [],
    );
  }

  /// `Introduction`
  String get introduction {
    return Intl.message(
      'Introduction',
      name: 'introduction',
      desc: '',
      args: [],
    );
  }

  /// `Premium artistic nail designs...`
  String get nailDescriptionDefault {
    return Intl.message(
      'Premium artistic nail designs meticulously crafted by top nail artists, bringing a glamorous, attractive, and personal look for women.',
      name: 'nailDescriptionDefault',
      desc: '',
      args: [],
    );
  }

  /// `Available variants`
  String get availableVariants {
    return Intl.message(
      'Available variants',
      name: 'availableVariants',
      desc: '',
      args: [],
    );
  }

  /// `There are currently no variants available for this design.`
  String get noVariantsAvailable {
    return Intl.message(
      'There are currently no variants available for this design.',
      name: 'noVariantsAvailable',
      desc: '',
      args: [],
    );
  }

  /// `Book`
  String get bookBtn {
    return Intl.message('Book', name: 'bookBtn', desc: '', args: []);
  }

  /// `Shape`
  String get nailShapeLabel {
    return Intl.message('Shape', name: 'nailShapeLabel', desc: '', args: []);
  }

  /// `Surface`
  String get nailSurfaceLabel {
    return Intl.message(
      'Surface',
      name: 'nailSurfaceLabel',
      desc: '',
      args: [],
    );
  }

  /// `None`
  String get noneLabel {
    return Intl.message('None', name: 'noneLabel', desc: '', args: []);
  }

  /// `Price from {min} - {max}`
  String priceFromTo(Object min, Object max) {
    return Intl.message(
      'Price from $min - $max',
      name: 'priceFromTo',
      desc: '',
      args: [min, max],
    );
  }

  /// `{count} variants`
  String variantsCount(Object count) {
    return Intl.message(
      '$count variants',
      name: 'variantsCount',
      desc: '',
      args: [count],
    );
  }

  /// `Available for try-on`
  String get availableForTryOn {
    return Intl.message(
      'Available for try-on',
      name: 'availableForTryOn',
      desc: '',
      args: [],
    );
  }

  /// `Error loading data: {error}`
  String loadDataError(Object error) {
    return Intl.message(
      'Error loading data: $error',
      name: 'loadDataError',
      desc: '',
      args: [error],
    );
  }

  /// `Variant Details`
  String get variantDetailsTitle {
    return Intl.message(
      'Variant Details',
      name: 'variantDetailsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Collection: {name}`
  String collectionLabel(Object name) {
    return Intl.message(
      'Collection: $name',
      name: 'collectionLabel',
      desc: '',
      args: [name],
    );
  }

  /// `Nail form`
  String get nailFormLabel {
    return Intl.message('Nail form', name: 'nailFormLabel', desc: '', args: []);
  }

  /// `{minutes} mins`
  String minutesLabel(Object minutes) {
    return Intl.message(
      '$minutes mins',
      name: 'minutesLabel',
      desc: '',
      args: [minutes],
    );
  }

  /// `Colors`
  String get colorLabel {
    return Intl.message('Colors', name: 'colorLabel', desc: '', args: []);
  }

  /// `Design components`
  String get designComponentsLabel {
    return Intl.message(
      'Design components',
      name: 'designComponentsLabel',
      desc: '',
      args: [],
    );
  }

  /// `Shared`
  String get sharedLabel {
    return Intl.message('Shared', name: 'sharedLabel', desc: '', args: []);
  }

  /// `Book now`
  String get bookAppointmentNow {
    return Intl.message(
      'Book now',
      name: 'bookAppointmentNow',
      desc: '',
      args: [],
    );
  }

  /// `Form shaping method`
  String get shapeMethodLabel {
    return Intl.message(
      'Form shaping method',
      name: 'shapeMethodLabel',
      desc: '',
      args: [],
    );
  }

  /// `Decoration`
  String get decorationLabel {
    return Intl.message(
      'Decoration',
      name: 'decorationLabel',
      desc: '',
      args: [],
    );
  }

  /// `Component {id}`
  String componentNameFallback(Object id) {
    return Intl.message(
      'Component $id',
      name: 'componentNameFallback',
      desc: '',
      args: [id],
    );
  }

  /// `Thumb`
  String get fingerThumb {
    return Intl.message('Thumb', name: 'fingerThumb', desc: '', args: []);
  }

  /// `Index`
  String get fingerIndex {
    return Intl.message('Index', name: 'fingerIndex', desc: '', args: []);
  }

  /// `Middle`
  String get fingerMiddle {
    return Intl.message('Middle', name: 'fingerMiddle', desc: '', args: []);
  }

  /// `Ring`
  String get fingerRing {
    return Intl.message('Ring', name: 'fingerRing', desc: '', args: []);
  }

  /// `Pinky`
  String get fingerPinky {
    return Intl.message('Pinky', name: 'fingerPinky', desc: '', args: []);
  }

  /// `Finger {index}`
  String fingerOther(Object index) {
    return Intl.message(
      'Finger $index',
      name: 'fingerOther',
      desc: '',
      args: [index],
    );
  }

  /// `Seasonal`
  String get seasonalTitle {
    return Intl.message('Seasonal', name: 'seasonalTitle', desc: '', args: []);
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'vi'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
