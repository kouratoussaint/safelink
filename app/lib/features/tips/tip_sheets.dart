import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/speech/speaker.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Ligne d'une fiche : pictogramme, mots courts ; `forbid` pour une
/// interdiction (« ne … jamais »), dessinée avec le signe interdit.
typedef TipLine = ({IconData icon, String text, bool forbid});

/// Fiche de prévention : le piège, ses signes, et que faire.
@immutable
final class TipSheet {
  const new({
    required this.id,
    required this.icon,
    required this.level,
    required this.title,
    required this.trap,
    required this.signs,
    required this.actions,
    this.signsTitle,
    this.actionsTitle,
  });

  /// Identifiant stable, utilisé dans l'adresse de la fiche.
  final String id;
  final IconData icon;

  /// Gravité du piège, qui fixe la couleur.
  final RiskLevel level;
  final String title;
  final String trap;
  final List<TipLine> signs;
  final List<TipLine> actions;

  /// Titres propres à une fiche (« Tout de suite », « Ensuite »).
  final String? signsTitle;
  final String? actionsTitle;

  /// Texte lu par « Écouter ».
  String speech(AppLocalizations l10n) => [
    title,
    trap,
    signsTitle ?? l10n.tipSigns,
    for (final s in signs) s.text,
    actionsTitle ?? l10n.tipActions,
    for (final a in actions) a.text,
  ].map(spokenSentence).join(' ');
}

TipLine _l(IconData icon, String text, {bool forbid = false}) =>
    (icon: icon, text: text, forbid: forbid);

/// Fiches de prévention, la fiche d'urgence d'abord.
List<TipSheet> tipSheets(AppLocalizations l10n) => [
  TipSheet(
    id: 'victime',
    icon: Icons.emergency_outlined,
    level: RiskLevel.danger,
    title: l10n.tipVictimeTitle,
    trap: l10n.tipVictimeTrap,
    signsTitle: l10n.tipVictimNow,
    actionsTitle: l10n.tipVictimThen,
    signs: [
      _l(Icons.lock_reset, l10n.tipVictimeSign1),
      _l(Icons.support_agent, l10n.tipVictimeSign2),
      _l(Icons.delete_outline, l10n.tipVictimeSign3),
    ],
    actions: [
      _l(Icons.campaign_outlined, l10n.tipVictimeAction1),
      _l(Icons.save_outlined, l10n.tipVictimeAction2),
      _l(Icons.groups_outlined, l10n.tipVictimeAction3),
    ],
  ),
  TipSheet(
    id: 'codes',
    icon: Icons.password,
    level: RiskLevel.danger,
    title: l10n.tipCodesTitle,
    trap: l10n.tipCodesTrap,
    signs: [
      _l(Icons.sms_outlined, l10n.tipCodesSign1),
      _l(Icons.badge_outlined, l10n.tipCodesSign2),
      _l(Icons.timer_outlined, l10n.tipCodesSign3),
    ],
    actions: [
      _l(Icons.password, l10n.tipCodesAction1, forbid: true),
      _l(Icons.call_end_outlined, l10n.tipCodesAction2),
      _l(Icons.support_agent, l10n.tipCodesAction3),
    ],
  ),
  TipSheet(
    id: 'transfert',
    icon: Icons.currency_exchange,
    level: RiskLevel.danger,
    title: l10n.tipTransfertTitle,
    trap: l10n.tipTransfertTrap,
    signs: [
      _l(Icons.sms_outlined, l10n.tipTransfertSign1),
      _l(Icons.account_balance_wallet_outlined, l10n.tipTransfertSign2),
      _l(Icons.phone_in_talk_outlined, l10n.tipTransfertSign3),
    ],
    actions: [
      _l(Icons.account_balance_wallet_outlined, l10n.tipTransfertAction1),
      _l(Icons.money_off, l10n.tipTransfertAction2, forbid: true),
      _l(Icons.support_agent, l10n.tipTransfertAction3),
    ],
  ),
  TipSheet(
    id: 'ussd',
    icon: Icons.dialpad,
    level: RiskLevel.danger,
    title: l10n.tipUssdTitle,
    trap: l10n.tipUssdTrap,
    signs: [
      _l(Icons.dialpad, l10n.tipUssdSign1),
      _l(Icons.badge_outlined, l10n.tipUssdSign2),
      _l(Icons.redeem, l10n.tipUssdSign3),
    ],
    actions: [
      _l(Icons.phone_disabled_outlined, l10n.tipUssdAction1, forbid: true),
      _l(Icons.call_end_outlined, l10n.tipUssdAction2),
      _l(Icons.support_agent, l10n.tipUssdAction3),
    ],
  ),
  TipSheet(
    id: 'agents',
    icon: Icons.support_agent,
    level: RiskLevel.danger,
    title: l10n.tipAgentsTitle,
    trap: l10n.tipAgentsTrap,
    signs: [
      _l(Icons.person_search_outlined, l10n.tipAgentsSign1),
      _l(Icons.password, l10n.tipAgentsSign2),
      _l(Icons.lock_clock_outlined, l10n.tipAgentsSign3),
    ],
    actions: [
      _l(Icons.call_end_outlined, l10n.tipAgentsAction1),
      _l(Icons.support_agent, l10n.tipAgentsAction2),
      _l(Icons.password, l10n.tipAgentsAction3, forbid: true),
    ],
  ),
  TipSheet(
    id: 'applis',
    icon: Icons.install_mobile_outlined,
    level: RiskLevel.danger,
    title: l10n.tipApplisTitle,
    trap: l10n.tipApplisTrap,
    signs: [
      _l(Icons.install_mobile_outlined, l10n.tipApplisSign1),
      _l(Icons.admin_panel_settings_outlined, l10n.tipApplisSign2),
      _l(Icons.redeem, l10n.tipApplisSign3),
    ],
    actions: [
      _l(Icons.shop_outlined, l10n.tipApplisAction1),
      _l(Icons.delete_outline, l10n.tipApplisAction2),
      _l(Icons.groups_outlined, l10n.tipApplisAction3),
    ],
  ),
  TipSheet(
    id: 'gains',
    icon: Icons.redeem,
    level: RiskLevel.attention,
    title: l10n.tipGainsTitle,
    trap: l10n.tipGainsTrap,
    signs: [
      _l(Icons.emoji_events_outlined, l10n.tipGainsSign1),
      _l(Icons.payments_outlined, l10n.tipGainsSign2),
      _l(Icons.password, l10n.tipGainsSign3),
    ],
    actions: [
      _l(Icons.money_off, l10n.tipGainsAction1, forbid: true),
      _l(Icons.delete_outline, l10n.tipGainsAction2),
      _l(Icons.block, l10n.tipGainsAction3),
    ],
  ),
  TipSheet(
    id: 'emploi',
    icon: Icons.work_outline,
    level: RiskLevel.attention,
    title: l10n.tipEmploiTitle,
    trap: l10n.tipEmploiTrap,
    signs: [
      _l(Icons.work_outline, l10n.tipEmploiSign1),
      _l(Icons.payments_outlined, l10n.tipEmploiSign2),
      _l(Icons.forum_outlined, l10n.tipEmploiSign3),
    ],
    actions: [
      _l(Icons.money_off, l10n.tipEmploiAction1, forbid: true),
      _l(Icons.verified_outlined, l10n.tipEmploiAction2),
      _l(Icons.groups_outlined, l10n.tipEmploiAction3),
    ],
  ),
  TipSheet(
    id: 'liens',
    icon: Icons.link_rounded,
    level: RiskLevel.attention,
    title: l10n.tipLiensTitle,
    trap: l10n.tipLiensTrap,
    signs: [
      _l(Icons.spellcheck, l10n.tipLiensSign1),
      _l(Icons.visibility_off_outlined, l10n.tipLiensSign2),
      _l(Icons.touch_app_outlined, l10n.tipLiensSign3),
    ],
    actions: [
      _l(Icons.shield_outlined, l10n.tipLiensAction1),
      _l(Icons.do_not_touch_outlined, l10n.tipLiensAction2, forbid: true),
      _l(Icons.apps, l10n.tipLiensAction3),
    ],
  ),
  TipSheet(
    id: 'qr',
    icon: Icons.qr_code_2,
    level: RiskLevel.attention,
    title: l10n.tipQrTitle,
    trap: l10n.tipQrTrap,
    signs: [
      _l(Icons.qr_code_2, l10n.tipQrSign1),
      _l(Icons.payments_outlined, l10n.tipQrSign2),
      _l(Icons.timer_outlined, l10n.tipQrSign3),
    ],
    actions: [
      _l(Icons.search, l10n.tipQrAction1),
      _l(Icons.money_off, l10n.tipQrAction2, forbid: true),
      _l(Icons.storefront_outlined, l10n.tipQrAction3),
    ],
  ),
  TipSheet(
    id: 'urgence',
    icon: Icons.timer_outlined,
    level: RiskLevel.attention,
    title: l10n.tipUrgenceTitle,
    trap: l10n.tipUrgenceTrap,
    signs: [
      _l(Icons.timer_outlined, l10n.tipUrgenceSign1),
      _l(Icons.lock_clock_outlined, l10n.tipUrgenceSign2),
      _l(Icons.touch_app_outlined, l10n.tipUrgenceSign3),
    ],
    actions: [
      _l(Icons.hourglass_empty, l10n.tipUrgenceAction1),
      _l(Icons.shield_outlined, l10n.tipUrgenceAction2),
      _l(Icons.groups_outlined, l10n.tipUrgenceAction3),
    ],
  ),
];
