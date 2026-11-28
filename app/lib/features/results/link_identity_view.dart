import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/theme/safelink_colors.dart';
import 'package:safelink/core/widgets/surfaces.dart';
import 'package:safelink/features/results/reason_tiles.dart';
import 'package:safelink/l10n/generated/app_localizations.dart';
import 'package:safelink_engine/safelink_engine.dart';

/// Ce qu'est un lien, dit simplement : titre court, phrase, et au besoin
/// une mise en garde. Rien n'y rassure : la nature d'un lien n'est pas un
/// verdict.
@immutable
final class IdentityText {
  /// Crée le texte ; `spokenSentence` remplace [sentence] à l'oral (sans
  /// numéro masqué à épeler).
  const new({
    required this.title,
    required this.sentence,
    this.note,
    this._spokenSentence,
  });

  /// Décrit [identity] en français.
  factory of(AppLocalizations l10n, LinkIdentity identity) {
    final service = identity.service ?? '';
    final detail = identity.detail;
    final hostNote = identity.service == null
        ? null
        : l10n.identityHostNote(service);
    return switch (identity.kind) {
      LinkKind.sharedFile => IdentityText(
        title: l10n.identitySharedFileTitle(service),
        sentence: l10n.identitySharedFile(service),
        note: hostNote,
      ),
      LinkKind.sharedFolder => IdentityText(
        title: l10n.identitySharedFolderTitle(service),
        sentence: l10n.identitySharedFolder(service),
        note: hostNote,
      ),
      LinkKind.document => IdentityText(
        title: l10n.identityDocumentTitle(service),
        sentence: l10n.identityDocument(service),
        note: hostNote,
      ),
      LinkKind.form => IdentityText(
        title: l10n.identityFormTitle(service),
        sentence: l10n.identityForm(service),
        note: l10n.identityFormNote,
      ),
      LinkKind.map => IdentityText(
        title: l10n.identityMapTitle(service),
        sentence: l10n.identityMap,
      ),
      LinkKind.appStore => IdentityText(
        title: l10n.identityAppStoreTitle(service),
        sentence: detail == null
            ? l10n.identityAppStore(service)
            : l10n.identityAppStoreApp(service, detail),
        note: l10n.identityAppStoreNote,
      ),
      LinkKind.appFile => IdentityText(
        title: l10n.identityAppFileTitle,
        sentence: identity.service == null
            ? l10n.identityAppFile(detail ?? 'apk')
            : l10n.identityAppFileOn(detail ?? 'apk', service),
        note: l10n.identityAppFileNote,
      ),
      LinkKind.file => _fileText(l10n, identity),
      LinkKind.video => IdentityText(
        title: l10n.identityVideoTitle(service),
        sentence: l10n.identityVideo(service),
      ),
      LinkKind.chat => IdentityText(
        title: l10n.identityChatTitle(service),
        sentence: switch (detail) {
          null => l10n.identityChat(service),
          final number when number.startsWith('+') => l10n.identityChatWith(
            service,
            formatPhone(number),
          ),
          final name => l10n.identityChatName(service, name),
        },
        spokenSentence: detail != null && detail.startsWith('+')
            ? l10n.identityChatNumber(service)
            : null,
        note: identity.prefilledMessage ? l10n.identityPrefilledNote : null,
      ),
      LinkKind.groupInvite => IdentityText(
        title: l10n.identityGroupInviteTitle(service),
        sentence: l10n.identityGroupInvite(service),
        note: l10n.identityGroupNote,
      ),
      LinkKind.channel => IdentityText(
        title: l10n.identityChannelTitle(service),
        sentence: detail == null
            ? l10n.identityChannel(service)
            : l10n.identityChannelName(detail, service),
      ),
      LinkKind.post => IdentityText(
        title: l10n.identityPostTitle(service),
        sentence: l10n.identityPost(service),
      ),
      LinkKind.group => IdentityText(
        title: l10n.identityGroupTitle(service),
        sentence: l10n.identityGroup(service),
        note: l10n.identityGroupNote,
      ),
      LinkKind.profile => IdentityText(
        title: l10n.identityProfileTitle(service),
        sentence: l10n.identityProfile(service),
        note: l10n.identityProfileNote,
      ),
      LinkKind.job => IdentityText(
        title: l10n.identityJobTitle(service),
        sentence: l10n.identityJob(service),
        note: l10n.identityJobNote,
      ),
      LinkKind.linkPage => IdentityText(
        title: l10n.identityLinkPageTitle,
        sentence: l10n.identityLinkPage(service),
        note: l10n.identityLinkPageNote,
      ),
      LinkKind.shortLink => IdentityText(
        title: l10n.identityShortLinkTitle,
        sentence: l10n.identityShortLink(service),
      ),
      LinkKind.userPage => IdentityText(
        title: l10n.identityUserPageTitle(service),
        sentence: l10n.identityUserPage(service),
        note: hostNote,
      ),
      LinkKind.officialSite => IdentityText(
        title: l10n.identityOfficialTitle(detail ?? ''),
        sentence: l10n.identityOfficial(detail ?? ''),
        note: l10n.identityOfficialNote,
      ),
      LinkKind.imitation => IdentityText(
        title: l10n.identityImitationTitle(detail ?? ''),
        sentence: l10n.identityImitation(detail ?? ''),
      ),
      LinkKind.ipAddress => IdentityText(
        title: l10n.identityIpTitle,
        sentence: l10n.identityIp(detail ?? ''),
        note: l10n.identityIpNote,
      ),
      LinkKind.website => IdentityText(
        title: l10n.identityWebsiteTitle,
        sentence: l10n.identityWebsite(detail ?? ''),
      ),
    };
  }

  /// Titre court (« Fichier Google Drive »).
  final String title;

  /// Phrase qui dit ce qu'ouvrirait le lien.
  final String sentence;

  /// Mise en garde liée à cette nature de lien, s'il y en a une.
  final String? note;

  final String? _spokenSentence;

  /// Texte complet, pour la lecture à voix haute et TalkBack.
  String get spoken => [_spokenSentence ?? sentence, ?note].join(' ');
}

/// Fichier à télécharger : la mise en garde dépend de son type.
IdentityText _fileText(AppLocalizations l10n, LinkIdentity identity) {
  final extension = (identity.detail ?? '').toUpperCase();
  final service = identity.service;
  final note = switch (identity.detail) {
    'exe' ||
    'msi' ||
    'bat' ||
    'scr' ||
    'jar' ||
    'dmg' ||
    'ipa' => l10n.identityProgramNote,
    'zip' || 'rar' || '7z' => l10n.identityArchiveNote,
    _ => null,
  };
  return IdentityText(
    title: l10n.identityFileTitle(extension),
    sentence: service == null
        ? l10n.identityFile(extension)
        : l10n.identityFileOn(extension, service),
    note: note,
  );
}

/// Numéro international lisible et masqué au milieu, comme partout dans
/// SafeLink : `+22670123456` → `+226 70 •• •• 56`. Assez pour reconnaître
/// un contact, pas pour lire le numéro par-dessus l'épaule.
String formatPhone(String number) {
  final digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('226') && digits.length == 11) {
    final local = digits.substring(3);
    return '+226 ${local.substring(0, 2)} •• •• ${local.substring(6)}';
  }
  if (digits.length <= 6) return '+$digits';
  return '+${digits.substring(0, 4)}•••${digits.substring(digits.length - 2)}';
}

/// Pictogramme d'une nature de lien.
IconData identityIcon(LinkKind kind) => switch (kind) {
  LinkKind.sharedFile => Icons.insert_drive_file_outlined,
  LinkKind.sharedFolder => Icons.folder_shared_outlined,
  LinkKind.document => Icons.description_outlined,
  LinkKind.form => Icons.assignment_outlined,
  LinkKind.map => Icons.place_outlined,
  LinkKind.appStore => Icons.shop_outlined,
  LinkKind.appFile => Icons.android,
  LinkKind.file => Icons.download_outlined,
  LinkKind.video => Icons.play_circle_outline,
  LinkKind.chat => Icons.chat_outlined,
  LinkKind.groupInvite => Icons.group_add_outlined,
  LinkKind.channel => Icons.campaign_outlined,
  LinkKind.post => Icons.article_outlined,
  LinkKind.group => Icons.groups_outlined,
  LinkKind.profile => Icons.account_circle_outlined,
  LinkKind.job => Icons.work_outline,
  LinkKind.linkPage => Icons.list_alt,
  LinkKind.shortLink => Icons.link,
  LinkKind.userPage => Icons.web_outlined,
  LinkKind.officialSite => Icons.verified_outlined,
  LinkKind.imitation => Icons.theater_comedy_outlined,
  LinkKind.ipAddress => Icons.pin_outlined,
  LinkKind.website => Icons.language,
};

/// Natures qui sont déjà, en elles-mêmes, une alerte.
bool identityWarns(LinkKind kind) =>
    kind == LinkKind.imitation ||
    kind == LinkKind.appFile ||
    kind == LinkKind.ipAddress;

/// Carte « Ce lien est… » : pictogramme, titre court, phrase et mise en
/// garde.
class LinkIdentityCard extends StatelessWidget {
  const new({required this.identity, super.key});

  final LinkIdentity identity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SafeLinkColors.of(context);
    final text = IdentityText.of(l10n, identity);
    final color = identityWarns(identity.kind)
        ? colors.warning
        : theme.colorScheme.primary;
    return SoftCard(
      child: Semantics(
        container: true,
        label: '${text.title}. ${text.spoken}',
        child: ExcludeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PictoBadge(icon: identityIcon(identity.kind), color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(text.sentence, style: theme.textTheme.bodyLarge),
                    if (text.note case final note?) ...[
                      const SizedBox(height: 6),
                      Text(
                        note,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
