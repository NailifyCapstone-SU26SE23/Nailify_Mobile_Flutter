// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(count) => "Apply (${count})";

  static String m1(value) => "${value} off";

  static String m2(value) => "${value}% off";

  static String m3(name) => "Add-on: ${name}";

  static String m4(month, year) => "${month}/${year}";

  static String m5(error) => "Unable to create payment: ${error}";

  static String m6(count) => "Selected: ${count}";

  static String m7(price) => "${price} / piece";

  static String m8(error) => "Error joining waitlist: ${error}";

  static String m9(time) => "You have joined the waitlist for ${time}";

  static String m10(qty) => "Free warranty • Qty: ${qty}";

  static String m11(color) =>
      "Color tone ${color} matches your preferred color.";

  static String m12(name) => "Are you sure you want to delete \"${name}\"?";

  static String m13(name) => "Are you sure you want to delete \"${name}\"?";

  static String m14(error) => "Cannot load information: ${error}";

  static String m15(error) => "Unable to load form: ${error}";

  static String m16(m) => "Month ${m}";

  static String m17(error) => "Error regenerating design: ${error}";

  static String m18(date) => "Date: ${date}";

  static String m19(error) => "Failed to send request: ${error}";

  static String m20(error) => "Error creating nail profile: ${error}";

  static String m21(error) => "Update error: ${error}";

  static String m22(time) =>
      "Are you sure you want to leave the waitlist at ${time}?\nYou will lose your position in the queue.";

  static String m23(error) => "Error cancelling waitlist: ${error}";

  static String m24(error) => "Confirm error: ${error}";

  static String m25(n) => "${n} days ago";

  static String m26(n) => "${n} hours ago";

  static String m27(n) => "${n} minutes ago";

  static String m28(y) => "Year ${y}";

  static String m29(dynamic minutes) => "${minutes} minutes";

  static String m30(dynamic qty) => "Qty: ${qty}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "accessoriesTab": MessageLookupByLibrary.simpleMessage("Accessories"),
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "addToNail": MessageLookupByLibrary.simpleMessage("Add to nail"),
    "addressUpdating": MessageLookupByLibrary.simpleMessage("Address updating"),
    "allMonths": MessageLookupByLibrary.simpleMessage("All Months"),
    "allStatus": MessageLookupByLibrary.simpleMessage("All"),
    "allYears": MessageLookupByLibrary.simpleMessage("All Years"),
    "anyArtist": MessageLookupByLibrary.simpleMessage("Any Artist"),
    "appName": MessageLookupByLibrary.simpleMessage("Nailify"),
    "applyToAllSuccess": MessageLookupByLibrary.simpleMessage(
      "Applied this finger\'s design to all fingers!",
    ),
    "automaticFitDesign": MessageLookupByLibrary.simpleMessage(
      "AUTOMATIC FIT DESIGN",
    ),
    "automaticFitDesignDesc": MessageLookupByLibrary.simpleMessage(
      "Bloom will automatically analyze your skin tone, hand shape, occupation, and preferences from your personality quiz to create a perfect 5-layer nail design.",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "bookAppointment": MessageLookupByLibrary.simpleMessage("Book"),
    "bookAppointmentTitle": MessageLookupByLibrary.simpleMessage(
      "Book Appointment",
    ),
    "bookCustomNailTitle": MessageLookupByLibrary.simpleMessage(
      "Book Custom Nail",
    ),
    "bookNow": MessageLookupByLibrary.simpleMessage("Book Now"),
    "bookNowButton": MessageLookupByLibrary.simpleMessage("Book Now"),
    "bookNowHint": MessageLookupByLibrary.simpleMessage(
      "Book a nail appointment now to get started!",
    ),
    "bookServiceTitle": MessageLookupByLibrary.simpleMessage("Book Service"),
    "bookThisDesign": MessageLookupByLibrary.simpleMessage("Book This Design"),
    "bookingAddService": MessageLookupByLibrary.simpleMessage("Add Service"),
    "bookingAddServiceTitle": MessageLookupByLibrary.simpleMessage(
      "Add Add-on Service",
    ),
    "bookingAddonServices": MessageLookupByLibrary.simpleMessage(
      "Add-on Services",
    ),
    "bookingApplyPromotion": m0,
    "bookingArtistNoDate": MessageLookupByLibrary.simpleMessage(
      "Please select a date first",
    ),
    "bookingArtistTab": MessageLookupByLibrary.simpleMessage("Artist"),
    "bookingAutoAssign": MessageLookupByLibrary.simpleMessage("Auto-assign"),
    "bookingAvailableSlots": MessageLookupByLibrary.simpleMessage(
      "Available Slots",
    ),
    "bookingBackBtn": MessageLookupByLibrary.simpleMessage("Back"),
    "bookingClearAll": MessageLookupByLibrary.simpleMessage("Clear all"),
    "bookingComponentDefault": MessageLookupByLibrary.simpleMessage(
      "Nail Component",
    ),
    "bookingConfirmBtn": MessageLookupByLibrary.simpleMessage(
      "Confirm Booking",
    ),
    "bookingContinueBtn": MessageLookupByLibrary.simpleMessage("Continue"),
    "bookingDetailsTitle": MessageLookupByLibrary.simpleMessage(
      "Booking Details",
    ),
    "bookingDiscount": MessageLookupByLibrary.simpleMessage("Discount"),
    "bookingDiscountFixed": m1,
    "bookingDiscountPercent": m2,
    "bookingExtraService": m3,
    "bookingFindNearby": MessageLookupByLibrary.simpleMessage(
      "Find Nearby Salons (View Map)",
    ),
    "bookingGoHome": MessageLookupByLibrary.simpleMessage("Go to Home"),
    "bookingInfoDate": MessageLookupByLibrary.simpleMessage("Appointment Date"),
    "bookingInfoOriginalPrice": MessageLookupByLibrary.simpleMessage(
      "Original Price",
    ),
    "bookingInfoService": MessageLookupByLibrary.simpleMessage("Service"),
    "bookingInfoStaff": MessageLookupByLibrary.simpleMessage("Staff"),
    "bookingInfoTime": MessageLookupByLibrary.simpleMessage("Time"),
    "bookingInfoTotal": MessageLookupByLibrary.simpleMessage("Total Payment"),
    "bookingMainService": MessageLookupByLibrary.simpleMessage("Main Service"),
    "bookingMissingId": MessageLookupByLibrary.simpleMessage(
      "Error: This booking is missing an ID from the system.",
    ),
    "bookingMonthYear": m4,
    "bookingNailVariantDefault": MessageLookupByLibrary.simpleMessage(
      "Nail Variant",
    ),
    "bookingNoAddon": MessageLookupByLibrary.simpleMessage(
      "No add-on services available.",
    ),
    "bookingNoApply": MessageLookupByLibrary.simpleMessage("No promotion"),
    "bookingNoArtistAvailable": MessageLookupByLibrary.simpleMessage(
      "No artists available on this date.",
    ),
    "bookingNoArtistTab": MessageLookupByLibrary.simpleMessage("No preference"),
    "bookingNoBranch": MessageLookupByLibrary.simpleMessage(
      "No branches available.",
    ),
    "bookingNoPromotion": MessageLookupByLibrary.simpleMessage(
      "No promotion applied",
    ),
    "bookingNoPromotionAvailable": MessageLookupByLibrary.simpleMessage(
      "No promotions available.",
    ),
    "bookingNoPromotions": MessageLookupByLibrary.simpleMessage(
      "No promotions available",
    ),
    "bookingNoSchedule": MessageLookupByLibrary.simpleMessage(
      "This artist has no schedule on this date.",
    ),
    "bookingPayBtn": MessageLookupByLibrary.simpleMessage("Pay Now"),
    "bookingPaymentDetails": MessageLookupByLibrary.simpleMessage(
      "Payment Details",
    ),
    "bookingPaymentError": m5,
    "bookingPromotion": MessageLookupByLibrary.simpleMessage("Promotion"),
    "bookingQtyLabel": MessageLookupByLibrary.simpleMessage("Quantity"),
    "bookingRetry": MessageLookupByLibrary.simpleMessage("Retry"),
    "bookingSelectArtistFirst": MessageLookupByLibrary.simpleMessage(
      "Please select an artist (or \"No preference\") to see available slots.",
    ),
    "bookingSelectArtistTitle": MessageLookupByLibrary.simpleMessage(
      "Select Artist",
    ),
    "bookingSelectDateTitle": MessageLookupByLibrary.simpleMessage(
      "Select Date",
    ),
    "bookingSelectPromotion": MessageLookupByLibrary.simpleMessage(
      "Select Promotion",
    ),
    "bookingSelectedCount": m6,
    "bookingSlotPast": MessageLookupByLibrary.simpleMessage(
      "This time has passed, please choose another.",
    ),
    "bookingStepBook": MessageLookupByLibrary.simpleMessage("Book"),
    "bookingStepCompleted": MessageLookupByLibrary.simpleMessage("Completed"),
    "bookingStepSelectSalon": MessageLookupByLibrary.simpleMessage(
      "Select Salon",
    ),
    "bookingStepServices": MessageLookupByLibrary.simpleMessage("Services"),
    "bookingSuccessSubtitle": MessageLookupByLibrary.simpleMessage(
      "Thank you for trusting Nailify. Here are the details of your appointment.",
    ),
    "bookingSuccessTitle": MessageLookupByLibrary.simpleMessage(
      "Booking Successful!",
    ),
    "bookingSummaryArtist": MessageLookupByLibrary.simpleMessage("Artist"),
    "bookingSummaryBranch": MessageLookupByLibrary.simpleMessage("Branch"),
    "bookingSummaryDate": MessageLookupByLibrary.simpleMessage("Date"),
    "bookingSummaryTime": MessageLookupByLibrary.simpleMessage("Time"),
    "bookingTabReschedule": MessageLookupByLibrary.simpleMessage("Rescheduled"),
    "bookingTabScheduled": MessageLookupByLibrary.simpleMessage("Scheduled"),
    "bookingTabWaitlist": MessageLookupByLibrary.simpleMessage("Waitlist"),
    "bookingTotal": MessageLookupByLibrary.simpleMessage("Total"),
    "bookingUnitPrice": m7,
    "bookingValidateDateTime": MessageLookupByLibrary.simpleMessage(
      "Please fill in date, artist and time slot.",
    ),
    "bookingValidateSalon": MessageLookupByLibrary.simpleMessage(
      "Please select a salon branch.",
    ),
    "bookingValidateService": MessageLookupByLibrary.simpleMessage(
      "Please select or remove the empty service.",
    ),
    "bookingValidateServiceMin": MessageLookupByLibrary.simpleMessage(
      "Please select at least one service.",
    ),
    "bookingViewBtn": MessageLookupByLibrary.simpleMessage("View Booking"),
    "bookingWaitlistError": m8,
    "bookingWaitlistJoined": m9,
    "bookingWarrantyDefault": MessageLookupByLibrary.simpleMessage(
      "Warranty Service",
    ),
    "bookingWarrantyFree": m10,
    "bookingWarrantyService": MessageLookupByLibrary.simpleMessage(
      "Select warranty service",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelBookingConfirmMsg": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to cancel this booking?",
    ),
    "cancelBookingReasonHint": MessageLookupByLibrary.simpleMessage(
      "Enter reason for cancellation (max 50 words)",
    ),
    "cancelBookingReasonRequired": MessageLookupByLibrary.simpleMessage(
      "Please enter a reason",
    ),
    "cancelBookingReasonTooLong": MessageLookupByLibrary.simpleMessage(
      "Reason cannot exceed 50 words",
    ),
    "cancelBookingTitle": MessageLookupByLibrary.simpleMessage(
      "Cancel Booking",
    ),
    "cancelBtn": MessageLookupByLibrary.simpleMessage("Cancel"),
    "colorMatchReason": m11,
    "completedLabel": MessageLookupByLibrary.simpleMessage("Completed"),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmBtn": MessageLookupByLibrary.simpleMessage("Confirm"),
    "createNewBtn": MessageLookupByLibrary.simpleMessage("Create New"),
    "createNewNailBtn": MessageLookupByLibrary.simpleMessage(
      "Create New Nail Design",
    ),
    "deleteBtn": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteComponentConfirm": m12,
    "deleteComponentTitle": MessageLookupByLibrary.simpleMessage(
      "Delete Component",
    ),
    "deleteNailConfirm": m13,
    "deleteNailTitle": MessageLookupByLibrary.simpleMessage(
      "Delete Nail Design",
    ),
    "designFeatureAccessories": MessageLookupByLibrary.simpleMessage(
      "Auto-select exquisite patterns & accessories",
    ),
    "designFeatureColor": MessageLookupByLibrary.simpleMessage(
      "Match skin-toning colors based on Warm/Cool tone",
    ),
    "designFeatureShape": MessageLookupByLibrary.simpleMessage(
      "Suggest nail shapes matching your hand structure",
    ),
    "designPageTitle": MessageLookupByLibrary.simpleMessage(
      "Personal Nail Design",
    ),
    "designYourOwnNail": MessageLookupByLibrary.simpleMessage(
      "DESIGN YOUR OWN NAIL",
    ),
    "doQuizButton": MessageLookupByLibrary.simpleMessage("TAKE STYLE QUIZ NOW"),
    "done": MessageLookupByLibrary.simpleMessage("Done"),
    "editRating": MessageLookupByLibrary.simpleMessage("Edit Rating"),
    "email": MessageLookupByLibrary.simpleMessage("Email"),
    "error": MessageLookupByLibrary.simpleMessage("An error occurred"),
    "exploreGalleryButton": MessageLookupByLibrary.simpleMessage(
      "Explore Gallery",
    ),
    "exploreServices": MessageLookupByLibrary.simpleMessage("Explore Services"),
    "failedGenerateDesign": MessageLookupByLibrary.simpleMessage(
      "Failed to generate design",
    ),
    "failedGenerateDesignDesc": MessageLookupByLibrary.simpleMessage(
      "An error occurred while fetching recommended nail design based on your preferences.",
    ),
    "filterAll": MessageLookupByLibrary.simpleMessage("All"),
    "filterAllStatus": MessageLookupByLibrary.simpleMessage("All statuses"),
    "filterPrivate": MessageLookupByLibrary.simpleMessage("Private"),
    "filterPublic": MessageLookupByLibrary.simpleMessage("Public"),
    "filterType": MessageLookupByLibrary.simpleMessage("Type"),
    "findNearbySalons": MessageLookupByLibrary.simpleMessage(
      "Find Nearby Salons (View Map)",
    ),
    "forYouTitle": MessageLookupByLibrary.simpleMessage("EXCLUSIVE FOR YOU"),
    "fullName": MessageLookupByLibrary.simpleMessage("Full Name"),
    "generateDesignButton": MessageLookupByLibrary.simpleMessage(
      "GENERATE DESIGN",
    ),
    "generatingPersonalizedDesign": MessageLookupByLibrary.simpleMessage(
      "GENERATING PERSONALIZED DESIGN",
    ),
    "home": MessageLookupByLibrary.simpleMessage("Home"),
    "homeBannerSubtitle": MessageLookupByLibrary.simpleMessage(
      "Discover natural elegance through every touch",
    ),
    "homeBannerTitle": MessageLookupByLibrary.simpleMessage(
      "Beauty on your\nfingertips",
    ),
    "homeCtaButton": MessageLookupByLibrary.simpleMessage(
      "BOOK APPOINTMENT NOW",
    ),
    "homeCtaSubtitle": MessageLookupByLibrary.simpleMessage(
      "Book an appointment with Nailify — join us on the journey of exquisite nail art.",
    ),
    "homeCtaTitle": MessageLookupByLibrary.simpleMessage(
      "Book Appointment Now!",
    ),
    "homeQuizHeading": MessageLookupByLibrary.simpleMessage(
      "Find your perfect nail design",
    ),
    "homeQuizSubtitle": MessageLookupByLibrary.simpleMessage(
      "Take a quick Style Quiz to find the best nail design for your personal style.",
    ),
    "homeQuizTitle": MessageLookupByLibrary.simpleMessage("Nailify Match AI"),
    "loadFailure": m14,
    "loadFormFail": m15,
    "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
    "login": MessageLookupByLibrary.simpleMessage("Login"),
    "logout": MessageLookupByLibrary.simpleMessage("Logout"),
    "logoutSuccess": MessageLookupByLibrary.simpleMessage(
      "Logged out successfully!",
    ),
    "loyalCustomer": MessageLookupByLibrary.simpleMessage("Loyal Customer"),
    "monthFormat": m16,
    "monthHint": MessageLookupByLibrary.simpleMessage("Month"),
    "myBooking": MessageLookupByLibrary.simpleMessage("Bookings"),
    "myBookingsTitle": MessageLookupByLibrary.simpleMessage("My Bookings"),
    "myComponents": MessageLookupByLibrary.simpleMessage("My Components"),
    "myNailsTab": MessageLookupByLibrary.simpleMessage("My Nails"),
    "myStudio": MessageLookupByLibrary.simpleMessage("My Studio"),
    "myStudioTitle": MessageLookupByLibrary.simpleMessage("My Studio"),
    "nailDesignTitle": MessageLookupByLibrary.simpleMessage("Nail Design"),
    "nailDetailsError": MessageLookupByLibrary.simpleMessage(
      "Cannot load design details.",
    ),
    "nailDetailsTitle": MessageLookupByLibrary.simpleMessage("Design Details"),
    "nailGallerySubtitle": MessageLookupByLibrary.simpleMessage(
      "Discover the latest nail design trends",
    ),
    "nailGalleryTitle": MessageLookupByLibrary.simpleMessage("Nail Gallery"),
    "nailRecommendation": MessageLookupByLibrary.simpleMessage(
      "Best matching nail design",
    ),
    "nailServiceDefault": MessageLookupByLibrary.simpleMessage("Nail Service"),
    "nailVariantsLabel": MessageLookupByLibrary.simpleMessage("Nail Variants"),
    "newCustomer": MessageLookupByLibrary.simpleMessage("New Customer"),
    "newNotification": MessageLookupByLibrary.simpleMessage(
      "You have 1 new notification",
    ),
    "next": MessageLookupByLibrary.simpleMessage("Next"),
    "noAccessorySelected": MessageLookupByLibrary.simpleMessage(
      "No accessory selected on nail",
    ),
    "noComponents": MessageLookupByLibrary.simpleMessage("No components yet"),
    "noData": MessageLookupByLibrary.simpleMessage("No data available"),
    "noMatchingDesc": MessageLookupByLibrary.simpleMessage(
      "We couldn\'t find any nail designs matching your attributes. Please try retaking the style quiz.",
    ),
    "noMatchingFound": MessageLookupByLibrary.simpleMessage(
      "No matching designs found",
    ),
    "noNailDesigns": MessageLookupByLibrary.simpleMessage(
      "No nail designs yet",
    ),
    "noNailFound": MessageLookupByLibrary.simpleMessage(
      "No nail designs found",
    ),
    "noRequests": MessageLookupByLibrary.simpleMessage("No requests yet."),
    "noSalonFound": MessageLookupByLibrary.simpleMessage("No salons found"),
    "notifications": MessageLookupByLibrary.simpleMessage("Your Notifications"),
    "otherStyleFits": MessageLookupByLibrary.simpleMessage(
      "Other designs matching your style",
    ),
    "ourPromiseExpDesc": MessageLookupByLibrary.simpleMessage(
      "We bring a wealth of experience and artistry to the world of nail design.",
    ),
    "ourPromiseExpTitle": MessageLookupByLibrary.simpleMessage(
      "Years of Experience",
    ),
    "ourPromiseHeading": MessageLookupByLibrary.simpleMessage("Why Choose Us"),
    "ourPromiseQualityDesc": MessageLookupByLibrary.simpleMessage(
      "Only premium, non-toxic products are used to ensure your safety and satisfaction.",
    ),
    "ourPromiseQualityTitle": MessageLookupByLibrary.simpleMessage(
      "Best Quality",
    ),
    "ourPromiseSubtitle": MessageLookupByLibrary.simpleMessage(
      "At Nailify, we understand that you have many choices. Here is why we stand out:",
    ),
    "ourPromiseTechDesc": MessageLookupByLibrary.simpleMessage(
      "Our technicians are certified and trained to provide the most detailed nail care.",
    ),
    "ourPromiseTechTitle": MessageLookupByLibrary.simpleMessage(
      "Professional Technicians",
    ),
    "ourPromiseTitle": MessageLookupByLibrary.simpleMessage("OUR PROMISE"),
    "ourPromiseTrendDesc": MessageLookupByLibrary.simpleMessage(
      "We constantly update our collection with the latest techniques and global trends.",
    ),
    "ourPromiseTrendTitle": MessageLookupByLibrary.simpleMessage(
      "Always Trendy",
    ),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "paymentTitle": MessageLookupByLibrary.simpleMessage("Payment"),
    "perfectMatch": MessageLookupByLibrary.simpleMessage("Perfect Match"),
    "perfectMatchTitle": MessageLookupByLibrary.simpleMessage("Nailify Match"),
    "phoneNumber": MessageLookupByLibrary.simpleMessage("Phone Number"),
    "pointsLabel": MessageLookupByLibrary.simpleMessage("points"),
    "premiumNailDesign": MessageLookupByLibrary.simpleMessage(
      "Premium nail design",
    ),
    "profileTitle": MessageLookupByLibrary.simpleMessage("Personal Profile"),
    "quizAlmostDone": MessageLookupByLibrary.simpleMessage("Almost done..."),
    "quizAnalyzingStyle": MessageLookupByLibrary.simpleMessage(
      "Analyzing style...",
    ),
    "quizBannerDesign": MessageLookupByLibrary.simpleMessage("Design Your Own"),
    "quizBannerFound": MessageLookupByLibrary.simpleMessage(
      "Nailify has found the perfect matching nail designs just for you!",
    ),
    "quizBannerNotFound": MessageLookupByLibrary.simpleMessage(
      "If you haven\'t found the right design, Nailify can help.",
    ),
    "quizBannerRetake": MessageLookupByLibrary.simpleMessage("Retake Quiz"),
    "quizBannerTake": MessageLookupByLibrary.simpleMessage("Take Quiz"),
    "quizBannerViewResults": MessageLookupByLibrary.simpleMessage(
      "VIEW PERFECT MATCH RESULTS",
    ),
    "quizDiscoverDesign": MessageLookupByLibrary.simpleMessage(
      "Discover the design made for you",
    ),
    "quizFindingColors": MessageLookupByLibrary.simpleMessage(
      "Finding matching colors...",
    ),
    "quizMatchingCollections": MessageLookupByLibrary.simpleMessage(
      "Matching with nail collection...",
    ),
    "quizSelectMultiple": MessageLookupByLibrary.simpleMessage(
      "Select multiple answers",
    ),
    "rateService": MessageLookupByLibrary.simpleMessage("Rate Service"),
    "reGenError": m17,
    "reGenSuccess": MessageLookupByLibrary.simpleMessage(
      "New matching nail design generated!",
    ),
    "reGenerateButton": MessageLookupByLibrary.simpleMessage("Regenerate"),
    "refundInfo": MessageLookupByLibrary.simpleMessage("Refund Information"),
    "register": MessageLookupByLibrary.simpleMessage("Register"),
    "requestDetailTitle": MessageLookupByLibrary.simpleMessage(
      "Request Detail",
    ),
    "loginRequiredTitle": MessageLookupByLibrary.simpleMessage(
      "Authentication Required",
    ),
    "loginRequiredMessage": MessageLookupByLibrary.simpleMessage(
      "Please sign in or register an account to use this feature.",
    ),
    "pleaseLoginToViewProfile": MessageLookupByLibrary.simpleMessage(
      "Please sign in to view your personal profile",
    ),
    "languageLabel": MessageLookupByLibrary.simpleMessage("Language"),
    "forgotPassword": MessageLookupByLibrary.simpleMessage("Forgot password?"),
    "dontHaveAccount": MessageLookupByLibrary.simpleMessage(
      "Don't have an account? ",
    ),
    "registerNow": MessageLookupByLibrary.simpleMessage("Register now"),
    "loginRequiredFields": MessageLookupByLibrary.simpleMessage(
      "Please enter both Email and Password",
    ),
    "loginSuccess": MessageLookupByLibrary.simpleMessage(
      "Logged in successfully",
    ),
    "alreadyHaveAccount": MessageLookupByLibrary.simpleMessage(
      "Already have an account? ",
    ),
    "registerRequiredFields": MessageLookupByLibrary.simpleMessage(
      "Please fill in all required fields",
    ),
    "passwordMismatch": MessageLookupByLibrary.simpleMessage(
      "Confirm password does not match",
    ),
    "agreeToTermsError": MessageLookupByLibrary.simpleMessage(
      "You must agree to the terms of service to continue",
    ),
    "registerSuccess": MessageLookupByLibrary.simpleMessage(
      "Account registered successfully",
    ),
    "registerTitle": MessageLookupByLibrary.simpleMessage("Register Account"),
    "firstNameHint": MessageLookupByLibrary.simpleMessage("First Name"),
    "lastNameHint": MessageLookupByLibrary.simpleMessage("Last Name"),
    "confirmPasswordHint": MessageLookupByLibrary.simpleMessage(
      "Confirm Password",
    ),
    "agreeToTermsText": MessageLookupByLibrary.simpleMessage(
      "I agree to the terms of service",
    ),
    "bookingArtistDefault": MessageLookupByLibrary.simpleMessage("Artist"),
    "bookingLoadingArtists": MessageLookupByLibrary.simpleMessage(
      "Loading artist list...",
    ),
    "bookingClickToSelectArtist": MessageLookupByLibrary.simpleMessage(
      "Click to choose performing artist",
    ),
    "bookingAutoAssignTitle": MessageLookupByLibrary.simpleMessage(
      "Auto-assignment by system",
    ),
    "bookingAutoAssignDesc": MessageLookupByLibrary.simpleMessage(
      "Time displayed based on salon schedule. Artist will be auto-assigned.",
    ),
    "bookingGeneralInfo": MessageLookupByLibrary.simpleMessage(
      "General Information",
    ),
    "bookingBranchLabel": MessageLookupByLibrary.simpleMessage("Branch"),
    "bookingStylistLabel": MessageLookupByLibrary.simpleMessage("Stylist"),
    "bookingDateLabel": MessageLookupByLibrary.simpleMessage("Date"),
    "bookingStartTimeLabel": MessageLookupByLibrary.simpleMessage("Start Time"),
    "bookingDurationLabel": MessageLookupByLibrary.simpleMessage("Duration"),
    "bookingDurationValue": m29,
    "bookingServicesBooked": MessageLookupByLibrary.simpleMessage(
      "Services Booked",
    ),
    "bookingQuantityLabel": m30,
    "bookingOriginalPriceLabel": MessageLookupByLibrary.simpleMessage(
      "Original Price:",
    ),
    "bookingDiscountLabel": MessageLookupByLibrary.simpleMessage("Discount:"),
    "bookingTotalPaymentLabel": MessageLookupByLibrary.simpleMessage(
      "Total Payment:",
    ),
    "bookingReviewTitle": MessageLookupByLibrary.simpleMessage("Review"),
    "bookingRatingDetails": MessageLookupByLibrary.simpleMessage(
      "Rating Details",
    ),
    "ratingOverall": MessageLookupByLibrary.simpleMessage("Overall"),
    "ratingServiceQuality": MessageLookupByLibrary.simpleMessage(
      "Service Quality",
    ),
    "ratingPunctuality": MessageLookupByLibrary.simpleMessage("Punctuality"),
    "ratingCleanliness": MessageLookupByLibrary.simpleMessage("Cleanliness"),
    "ratingLoadError": MessageLookupByLibrary.simpleMessage(
      "Could not load rating information.",
    ),
    "bookingNotFound": MessageLookupByLibrary.simpleMessage(
      "Booking information not found.",
    ),
    "bookingPaidAmount": MessageLookupByLibrary.simpleMessage("Paid:"),
    "bookingRemainingAmount": MessageLookupByLibrary.simpleMessage(
      "Remaining:",
    ),
    "bookingYourRating": MessageLookupByLibrary.simpleMessage("Your Rating"),
    "bookingCheckInCode": MessageLookupByLibrary.simpleMessage("Check-in Code"),
    "bookingCheckInInstruction": MessageLookupByLibrary.simpleMessage(
      "Show this code to the receptionist",
    ),
    "bookingRescheduleSuccess": MessageLookupByLibrary.simpleMessage(
      "Reschedule request sent successfully",
    ),
    "bookingRescheduleFail": MessageLookupByLibrary.simpleMessage(
      "Failed to send reschedule request",
    ),
    "bookingCancelSuccess": MessageLookupByLibrary.simpleMessage(
      "Booking cancelled successfully",
    ),
    "bookingCancelFail": MessageLookupByLibrary.simpleMessage(
      "Failed to cancel booking",
    ),
    "bookingCancelBtnLabel": MessageLookupByLibrary.simpleMessage(
      "Cancel Booking",
    ),
    "bookingRescheduleBtnLabel": MessageLookupByLibrary.simpleMessage(
      "Reschedule Appointment",
    ),
    "bookingQrError": MessageLookupByLibrary.simpleMessage(
      "Error displaying QR code",
    ),
    "bookingFingersLabel": MessageLookupByLibrary.simpleMessage("fingers"),
    "requestsTab": MessageLookupByLibrary.simpleMessage("Requests"),
    "rescheduleAcceptBtn": MessageLookupByLibrary.simpleMessage(
      "Accept Reschedule",
    ),
    "rescheduleAcceptFail": MessageLookupByLibrary.simpleMessage(
      "Failed to accept reschedule",
    ),
    "rescheduleAcceptSuccess": MessageLookupByLibrary.simpleMessage(
      "Reschedule accepted successfully",
    ),
    "rescheduleClearFilter": MessageLookupByLibrary.simpleMessage(
      "Clear date filter",
    ),
    "rescheduleDeclineBtn": MessageLookupByLibrary.simpleMessage("Decline"),
    "rescheduleDeclineFail": MessageLookupByLibrary.simpleMessage(
      "Failed to decline reschedule",
    ),
    "rescheduleDeclineSuccess": MessageLookupByLibrary.simpleMessage(
      "Reschedule declined successfully",
    ),
    "rescheduleEmptyAll": MessageLookupByLibrary.simpleMessage(
      "No reschedule requests",
    ),
    "rescheduleEmptyAllDesc": MessageLookupByLibrary.simpleMessage(
      "When a reschedule request from the Salon or\nyour reschedule request is being processed,\nthe record will appear here.",
    ),
    "rescheduleEmptyFiltered": MessageLookupByLibrary.simpleMessage(
      "No reschedule requests on this day",
    ),
    "rescheduleEmptyFilteredDesc": MessageLookupByLibrary.simpleMessage(
      "Try selecting a different date or clear the filter.",
    ),
    "rescheduleFilterByDate": MessageLookupByLibrary.simpleMessage(
      "Filter by date",
    ),
    "rescheduleFilterDate": m18,
    "rescheduleNew": MessageLookupByLibrary.simpleMessage("New"),
    "rescheduleOldSchedule": MessageLookupByLibrary.simpleMessage(
      "Old schedule: ",
    ),
    "reschedulePendingMsg": MessageLookupByLibrary.simpleMessage(
      "Waiting for salon to respond to your reschedule request",
    ),
    "rescheduleProcessing": MessageLookupByLibrary.simpleMessage(
      "Processing...",
    ),
    "rescheduleReason": MessageLookupByLibrary.simpleMessage("Reason: "),
    "rescheduleRequestedTime": MessageLookupByLibrary.simpleMessage(
      "Time you requested to reschedule:",
    ),
    "rescheduleSuggestedTime": MessageLookupByLibrary.simpleMessage(
      "New suggested time from salon:",
    ),
    "retry": MessageLookupByLibrary.simpleMessage("Retry"),
    "retryBtn": MessageLookupByLibrary.simpleMessage("Retry"),
    "reviewHoangAnh": MessageLookupByLibrary.simpleMessage(
      "\"The best nail salon in the area. The attention to detail is incomparable, and my nails stayed on for weeks without chipping!\"",
    ),
    "reviewLinhMai": MessageLookupByLibrary.simpleMessage(
      "\"I absolutely love my nails! The staff here is very talented and the designs are gorgeous. I will definitely be back!\"",
    ),
    "reviewThuNga": MessageLookupByLibrary.simpleMessage(
      "\"The mirror (chrome) polish looks beautiful and the staff is extremely friendly.\"",
    ),
    "reviewsHeading": MessageLookupByLibrary.simpleMessage(
      "Our Lovely Customers",
    ),
    "reviewsTitle": MessageLookupByLibrary.simpleMessage("WHAT CLIENTS SAY"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveDesignButton": MessageLookupByLibrary.simpleMessage("Save Design"),
    "saveDesignSuccess": MessageLookupByLibrary.simpleMessage(
      "Try-on setup saved successfully.",
    ),
    "searchComponentHint": MessageLookupByLibrary.simpleMessage(
      "Search components...",
    ),
    "searchNailHint": MessageLookupByLibrary.simpleMessage(
      "Search nail designs...",
    ),
    "selectDate": MessageLookupByLibrary.simpleMessage("Select Date"),
    "selectNailHint": MessageLookupByLibrary.simpleMessage(
      "Select nail design...",
    ),
    "selectNailLabel": MessageLookupByLibrary.simpleMessage("Nail Design *"),
    "selectNailShapeWarn": MessageLookupByLibrary.simpleMessage(
      "Please select a nail shape.",
    ),
    "selectNailTitle": MessageLookupByLibrary.simpleMessage(
      "Select Nail Design",
    ),
    "selectSalon": MessageLookupByLibrary.simpleMessage("Select Salon"),
    "selectSalonHint": MessageLookupByLibrary.simpleMessage(
      "Select Salon branch...",
    ),
    "selectSalonTitle": MessageLookupByLibrary.simpleMessage(
      "Select Salon Branch",
    ),
    "selectService": MessageLookupByLibrary.simpleMessage("Select Service"),
    "selectTime": MessageLookupByLibrary.simpleMessage("Select Time"),
    "selectTryOnMethodTitle": MessageLookupByLibrary.simpleMessage(
      "Select Try-on Method",
    ),
    "sendBtn": MessageLookupByLibrary.simpleMessage("Send"),
    "sendRequestBtn": MessageLookupByLibrary.simpleMessage("Send Request"),
    "sendRequestFail": m19,
    "sendRequestSuccess": MessageLookupByLibrary.simpleMessage(
      "Request sent successfully.",
    ),
    "sendRequestTitle": MessageLookupByLibrary.simpleMessage(
      "Send Design Request",
    ),
    "serviceAcrylic": MessageLookupByLibrary.simpleMessage("Acrylic Extension"),
    "serviceArt": MessageLookupByLibrary.simpleMessage("Nail Art"),
    "serviceCare": MessageLookupByLibrary.simpleMessage("Nail Care & Cuticle"),
    "serviceGel": MessageLookupByLibrary.simpleMessage("Gel Polish"),
    "servicesLabel": MessageLookupByLibrary.simpleMessage("Services"),
    "servicesSubtitle": MessageLookupByLibrary.simpleMessage(
      "Premium salon-quality nail care experience",
    ),
    "servicesTitle": MessageLookupByLibrary.simpleMessage("Featured Services"),
    "statusApproved": MessageLookupByLibrary.simpleMessage("Ready to Book"),
    "statusAssigned": MessageLookupByLibrary.simpleMessage("Artist Assigned"),
    "statusCancelled": MessageLookupByLibrary.simpleMessage("Cancelled"),
    "statusCheckedIn": MessageLookupByLibrary.simpleMessage("Checked In"),
    "statusCompleted": MessageLookupByLibrary.simpleMessage("Completed"),
    "statusInProgress": MessageLookupByLibrary.simpleMessage("In Progress"),
    "statusLabel": MessageLookupByLibrary.simpleMessage("Status"),
    "statusPending": MessageLookupByLibrary.simpleMessage("Pending Approval"),
    "statusPendingReview": MessageLookupByLibrary.simpleMessage(
      "Pending Review",
    ),
    "statusQuoted": MessageLookupByLibrary.simpleMessage("Quoted"),
    "statusRejected": MessageLookupByLibrary.simpleMessage("Rejected"),
    "statusRepaired": MessageLookupByLibrary.simpleMessage("Repaired"),
    "statusReview": MessageLookupByLibrary.simpleMessage("Under Review"),
    "statusReviewed": MessageLookupByLibrary.simpleMessage("Artist Reviewed"),
    "studioAllTab": MessageLookupByLibrary.simpleMessage("All"),
    "studioApprovedTab": MessageLookupByLibrary.simpleMessage("Approved"),
    "studioCreateNew": MessageLookupByLibrary.simpleMessage("Create New"),
    "studioNoRequests": MessageLookupByLibrary.simpleMessage(
      "No approval requests yet.",
    ),
    "studioProcessingTab": MessageLookupByLibrary.simpleMessage("Processing"),
    "studioRejectedTab": MessageLookupByLibrary.simpleMessage("Rejected"),
    "styleFitReasons": MessageLookupByLibrary.simpleMessage(
      "Why it fits your style",
    ),
    "styleProfileSetup": MessageLookupByLibrary.simpleMessage(
      "Personal Style Settings",
    ),
    "styleRecommendation": MessageLookupByLibrary.simpleMessage(
      "Style Recommendation",
    ),
    "systemModels": MessageLookupByLibrary.simpleMessage("System Models"),
    "takeAnotherAnalysis": MessageLookupByLibrary.simpleMessage(
      "Take Another Analysis",
    ),
    "tierLabel": MessageLookupByLibrary.simpleMessage("Tier"),
    "totalPrice": MessageLookupByLibrary.simpleMessage("Total Price"),
    "transactionDetails": MessageLookupByLibrary.simpleMessage(
      "Transaction Details",
    ),
    "tryAnotherDesign": MessageLookupByLibrary.simpleMessage(
      "Try another design",
    ),
    "tryChangeFilter": MessageLookupByLibrary.simpleMessage(
      "Try changing the month, year, or status filter.",
    ),
    "tryOnHintText": MessageLookupByLibrary.simpleMessage(
      "Tap the arrow button on the right to show the design panel",
    ),
    "tryOnTabAccessories": MessageLookupByLibrary.simpleMessage("Accessories"),
    "tryOnTabColor": MessageLookupByLibrary.simpleMessage("Nail Color"),
    "tryOnTabShape": MessageLookupByLibrary.simpleMessage("Nail Shape"),
    "tryOnTabSurface": MessageLookupByLibrary.simpleMessage("Nail Surface"),
    "updateFailure": m20,
    "updateProfile": MessageLookupByLibrary.simpleMessage("Update"),
    "updateProfileError": m21,
    "updateSuccess": MessageLookupByLibrary.simpleMessage(
      "Successfully updated style profile and generated nail template!",
    ),
    "viewAllServices": MessageLookupByLibrary.simpleMessage(
      "View All Services",
    ),
    "viewDetail": MessageLookupByLibrary.simpleMessage("View Detail"),
    "vipCustomer": MessageLookupByLibrary.simpleMessage("VIP Customer"),
    "waitlistCancelBtn": MessageLookupByLibrary.simpleMessage("Cancel Wait"),
    "waitlistCancelDialogContent": m22,
    "waitlistCancelDialogTitle": MessageLookupByLibrary.simpleMessage(
      "Confirm Cancel Wait",
    ),
    "waitlistCancelError": m23,
    "waitlistCancelSuccess": MessageLookupByLibrary.simpleMessage(
      "Waitlist cancelled successfully.",
    ),
    "waitlistConfirmBookBtn": MessageLookupByLibrary.simpleMessage(
      "Confirm Booking",
    ),
    "waitlistConfirmError": m24,
    "waitlistConfirmSuccess": MessageLookupByLibrary.simpleMessage(
      "Booking confirmed successfully!",
    ),
    "waitlistDaysAgo": m25,
    "waitlistDeclineBtn": MessageLookupByLibrary.simpleMessage("Decline"),
    "waitlistEmpty": MessageLookupByLibrary.simpleMessage("No waitlists"),
    "waitlistEmptyDesc": MessageLookupByLibrary.simpleMessage(
      "When a slot opens for your registered time,\nthe record will appear here.",
    ),
    "waitlistHoldEndsIn": MessageLookupByLibrary.simpleMessage(
      "Hold ends in: ",
    ),
    "waitlistHoldExpired": MessageLookupByLibrary.simpleMessage(
      "Hold time has expired",
    ),
    "waitlistHoursAgo": m26,
    "waitlistKeepBtn": MessageLookupByLibrary.simpleMessage("Keep"),
    "waitlistLoadError": MessageLookupByLibrary.simpleMessage(
      "Unable to load waitlist",
    ),
    "waitlistMinutesAgo": m27,
    "waitlistRegisteredAt": MessageLookupByLibrary.simpleMessage(
      "Registered: ",
    ),
    "waitlistStatusOpened": MessageLookupByLibrary.simpleMessage(
      "SLOT AVAILABLE",
    ),
    "waitlistStatusPending": MessageLookupByLibrary.simpleMessage("WAITING"),
    "warrantyButton": MessageLookupByLibrary.simpleMessage("Warranty"),
    "warrantyPrefix": MessageLookupByLibrary.simpleMessage("Warranty"),
    "warrantyServiceDefault": MessageLookupByLibrary.simpleMessage(
      "Warranty Service",
    ),
    "yearFormat": m28,
    "yearHint": MessageLookupByLibrary.simpleMessage("Year"),
    "youMayAlsoLike": MessageLookupByLibrary.simpleMessage("You may also like"),
    "yourPersonalStyle": MessageLookupByLibrary.simpleMessage(
      "Your personal style: ",
    ),
    "clearFilter": MessageLookupByLibrary.simpleMessage("Clear filter"),
    "nailLoadError": MessageLookupByLibrary.simpleMessage(
      "Cannot load nail designs.",
    ),
    "recommended": MessageLookupByLibrary.simpleMessage("Recommended"),
    "nailDesignFallback": MessageLookupByLibrary.simpleMessage("Nail design"),
    "introduction": MessageLookupByLibrary.simpleMessage("Introduction"),
    "nailDescriptionDefault": MessageLookupByLibrary.simpleMessage(
      "Premium artistic nail designs meticulously crafted by top nail artists, bringing a glamorous, attractive, and personal look for women.",
    ),
    "availableVariants": MessageLookupByLibrary.simpleMessage(
      "Available variants",
    ),
    "noVariantsAvailable": MessageLookupByLibrary.simpleMessage(
      "There are currently no variants available for this design.",
    ),
    "bookBtn": MessageLookupByLibrary.simpleMessage("Book"),
    "nailShapeLabel": MessageLookupByLibrary.simpleMessage("Shape"),
    "nailSurfaceLabel": MessageLookupByLibrary.simpleMessage("Surface"),
    "noneLabel": MessageLookupByLibrary.simpleMessage("None"),
    "priceFromTo": (min, max) => "Price from ${min} - ${max}",
    "variantsCount": (count) => "${count} variants",
    "availableForTryOn": MessageLookupByLibrary.simpleMessage(
      "Available for try-on",
    ),
    "loadDataError": (error) => "Error loading data: ${error}",
    "variantDetailsTitle": MessageLookupByLibrary.simpleMessage(
      "Variant Details",
    ),
    "collectionLabel": (name) => "Collection: ${name}",
    "nailFormLabel": MessageLookupByLibrary.simpleMessage("Nail form"),
    "minutesLabel": (minutes) => "${minutes} mins",
    "colorLabel": MessageLookupByLibrary.simpleMessage("Colors"),
    "designComponentsLabel": MessageLookupByLibrary.simpleMessage(
      "Design components",
    ),
    "sharedLabel": MessageLookupByLibrary.simpleMessage("Shared"),
    "bookAppointmentNow": MessageLookupByLibrary.simpleMessage("Book now"),
    "shapeMethodLabel": MessageLookupByLibrary.simpleMessage(
      "Form shaping method",
    ),
    "ratingsTitle": MessageLookupByLibrary.simpleMessage("Ratings"),
    "nailNotRatedMessage": MessageLookupByLibrary.simpleMessage(
      "This nail hasn\'t been rated.",
    ),
    "decorationLabel": MessageLookupByLibrary.simpleMessage("Decoration"),
    "componentNameFallback": (id) => "Component ${id}",
    "fingerThumb": MessageLookupByLibrary.simpleMessage("Thumb"),
    "fingerIndex": MessageLookupByLibrary.simpleMessage("Index"),
    "fingerMiddle": MessageLookupByLibrary.simpleMessage("Middle"),
    "fingerRing": MessageLookupByLibrary.simpleMessage("Ring"),
    "fingerPinky": MessageLookupByLibrary.simpleMessage("Pinky"),
    "fingerOther": (index) => "Finger ${index}",
    "seasonalTitle": MessageLookupByLibrary.simpleMessage("Seasonal"),
  };
}
