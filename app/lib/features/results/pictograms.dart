import 'package:material_ui/material_ui.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';

/// Image et mots courts d'un indice ou d'un geste : ce que l'utilisateur
/// voit d'abord, avant toute phrase.
typedef Pictogram = ({IconData icon, String label});

/// Pictogramme d'un indice, d'après son code stable ; `null` si le code
/// n'a pas de pictogramme (la phrase complète est alors affichée).
Pictogram? signalPictogram(String code, AppLocalizations l10n) {
  Pictogram p(IconData icon, String label) => (icon: icon, label: label);
  return switch (code) {
    'URL_REPORTED' => p(Icons.gpp_bad_outlined, l10n.sigReported),
    'URL_DOMAIN_NEW' => p(Icons.fiber_new_outlined, l10n.sigDomainNew),
    'URL_DOMAIN_NOT_FOUND' => p(
      Icons.cloud_off_outlined,
      l10n.sigDomainNotFound,
    ),
    'URL_USER_CONTENT' => p(Icons.groups_outlined, l10n.sigUserContent),
    'URL_SHARED_HOSTING' => p(Icons.apartment_outlined, l10n.sigSharedHosting),
    'URL_BRAND_LOOKALIKE' => p(
      Icons.content_copy_outlined,
      l10n.sigBrandLookalike,
    ),
    'URL_BRAND_TYPO' => p(Icons.spellcheck, l10n.sigBrandTypo),
    'URL_BRAND_IN_DOMAIN' ||
    'URL_BRAND_IN_SUBDOMAIN' ||
    'URL_BRAND_DOMAIN_IN_SUBDOMAIN' ||
    'URL_BRAND_IN_PATH' ||
    'URL_BRAND_OTHER_SUFFIX' => p(Icons.storefront_outlined, l10n.sigBrandName),
    'URL_SHORTENER' => p(Icons.visibility_off_outlined, l10n.sigShortener),
    'URL_REDIRECT_PARAMETER' => p(Icons.alt_route, l10n.sigRedirect),
    'URL_APK_DOWNLOAD' => p(Icons.install_mobile_outlined, l10n.sigApk),
    'URL_BAIT_WORDS' => p(Icons.phishing_outlined, l10n.sigBaitWords),
    'URL_CREDENTIALS' || 'URL_CREDENTIALS_DECEPTIVE' => p(
      Icons.masks_outlined,
      l10n.sigDeceptiveAddress,
    ),
    'URL_IP_LITERAL' ||
    'URL_IP_UNUSUAL_NOTATION' => p(Icons.pin_outlined, l10n.sigNumericAddress),
    'URL_MIXED_SCRIPTS' ||
    'URL_IMITATES_LATIN' ||
    'URL_INTERNATIONALIZED' ||
    'URL_HOST_PUNYCODE' ||
    'URL_UNUSUAL_HOST_CHARACTERS' ||
    'URL_INVISIBLE_CHARACTERS' ||
    'URL_ENCODED_HOST' => p(Icons.translate, l10n.sigTrickLetters),
    'URL_UNENCRYPTED' => p(Icons.lock_open_outlined, l10n.sigUnencrypted),
    'URL_UNUSUAL_PORT' ||
    'URL_MANY_SUBDOMAINS' ||
    'URL_UNLISTED_SUFFIX' ||
    'URL_SINGLE_LABEL_HOST' ||
    'URL_UNUSUAL_SLASHES' ||
    'URL_PERCENT_ENCODED' => p(Icons.help_center_outlined, l10n.sigOddAddress),
    'URL_TOO_LONG' => p(Icons.straighten, l10n.sigTooLong),
    'URL_EMAIL_ADDRESS' => p(Icons.alternate_email, l10n.sigEmail),
    'URL_NON_WEB_SCHEME' ||
    'URL_NOT_A_URL' ||
    'URL_EMPTY' ||
    'URL_INVALID_HOST' ||
    'URL_INVALID_PORT' ||
    'URL_NOT_ANALYZED' => p(Icons.block_outlined, l10n.sigNotWeb),
    'URL_SCHEME_ADDED' ||
    'URL_SCHEME_ASSUMED' ||
    'URL_DEFAULT_PORT_REMOVED' ||
    'URL_DOT_SEGMENTS_RESOLVED' ||
    'URL_HOST_CHARS_NORMALIZED' ||
    'URL_HOST_PERCENT_DECODED' ||
    'URL_INVISIBLE_CHARS_REMOVED' ||
    'URL_SLASHES_NORMALIZED' ||
    'URL_TRAILING_DOT_REMOVED' ||
    'URL_WHITESPACE_REMOVED' => p(
      Icons.auto_fix_high_outlined,
      l10n.sigCorrected,
    ),
    'MSG_CREDENTIALS_REQUEST' => p(Icons.password, l10n.sigAskCode),
    'MSG_SECRET_ENTRY' => p(Icons.dialpad, l10n.sigSecretEntry),
    'MSG_MISTAKEN_TRANSFER' => p(
      Icons.currency_exchange,
      l10n.sigMistakenTransfer,
    ),
    'MSG_USSD_TRANSFER' => p(Icons.dialpad, l10n.sigUssd),
    'MSG_PAYMENT_REQUEST' => p(Icons.payments_outlined, l10n.sigPayment),
    'MSG_PRIZE' => p(Icons.redeem, l10n.sigPrize),
    'MSG_ACCOUNT_THREAT' => p(Icons.lock_clock_outlined, l10n.sigAccountThreat),
    'MSG_OFF_CHANNEL' => p(Icons.forum_outlined, l10n.sigOffChannel),
    'MSG_LINK_BRAND_MISMATCH' => p(Icons.link_off, l10n.sigLinkMismatch),
    'MSG_SELECTION' => p(Icons.work_outline, l10n.sigSelection),
    'MSG_IMPERSONATION' => p(Icons.badge_outlined, l10n.sigImpersonation),
    'MSG_CALL_NUMBER' => p(Icons.phone_forwarded_outlined, l10n.sigCallNumber),
    'MSG_URGENCY' => p(Icons.timer_outlined, l10n.sigUrgency),
    'MSG_LINK_ACTION' => p(Icons.touch_app_outlined, l10n.sigLinkAction),
    'MSG_DEFANGED_LINK' => p(Icons.link, l10n.sigDefanged),
    _ => null,
  };
}

/// Pictogramme d'un geste recommandé ; `forbid` marque une interdiction
/// (« ne … pas »), dessinée en rouge. `null` si le code est inconnu.
({IconData icon, String label, bool forbid})? actionPictogram(
  String code,
  AppLocalizations l10n,
) {
  ({IconData icon, String label, bool forbid}) p(
    IconData icon,
    String label, {
    bool forbid = false,
  }) => (icon: icon, label: label, forbid: forbid);
  return switch (code) {
    'DO_NOT_OPEN' => p(
      Icons.do_not_touch_outlined,
      l10n.actDoNotOpen,
      forbid: true,
    ),
    'DELETE_MESSAGE' => p(Icons.delete_outline, l10n.actDeleteMessage),
    'IF_ALREADY_OPENED' => p(Icons.lock_reset, l10n.actIfAlreadyOpened),
    'NEVER_SHARE_CODES' => p(
      Icons.password,
      l10n.actNeverShareCodes,
      forbid: true,
    ),
    'VERIFY_OFFICIAL_CHANNEL' => p(Icons.support_agent, l10n.actVerifyOfficial),
    'OPEN_ONLY_IF_EXPECTED' => p(
      Icons.mark_email_read_outlined,
      l10n.actOpenOnlyIfExpected,
    ),
    'CHECK_BALANCE_OFFICIAL' => p(
      Icons.account_balance_wallet_outlined,
      l10n.actCheckBalance,
    ),
    'DO_NOT_DIAL' => p(
      Icons.phone_disabled_outlined,
      l10n.actDoNotDial,
      forbid: true,
    ),
    'DO_NOT_PAY' => p(Icons.money_off, l10n.actDoNotPay, forbid: true),
    'REPORT_AND_BLOCK' => p(Icons.block, l10n.actReportAndBlock),
    'STAY_ALERT' => p(Icons.visibility_outlined, l10n.actStayAlert),
    'STAY_ON_OFFICIAL_CHANNELS' => p(
      Icons.verified_user_outlined,
      l10n.actStayOfficial,
    ),
    'PASTE_MESSAGE' => p(Icons.content_paste, l10n.actPasteMessage),
    _ => null,
  };
}
