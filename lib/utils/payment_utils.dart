import '../l10n/app_localizations.dart';

/// Returns the localized display label for a canonical payment method key
/// (as stored in the database).  Falls back to the original [method] string
/// when no mapping is found, so unknown future methods still display.
String localizePaymentMethod(String method, AppLocalizations l10n) {
  switch (method) {
    case 'Cash':
      return l10n.paymentMethodCash;
    case 'Card':
      return l10n.paymentMethodCard;
    case 'EC-Karte':
      return l10n.paymentMethodEcKarte;
    case 'PayPal':
      return l10n.paymentMethodPayPal;
    case 'Apple Pay':
      return l10n.paymentMethodApplePay;
    case 'Google Pay':
      return l10n.paymentMethodGooglePay;
    case 'Invoice':
      return l10n.paymentMethodInvoice;
    default:
      return method;
  }
}
