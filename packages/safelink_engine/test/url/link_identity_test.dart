import 'package:safelink_engine/safelink_engine.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = UrlAnalyzer();
  final context = AnalysisContext(clock: () => DateTime.utc(2026, 11, 28));

  LinkIdentity identify(String link) {
    final identity = analyzer.analyze(link, context).identity;
    expect(identity, isNotNull, reason: link);
    return identity!;
  }

  void expectIdentity(
    String link,
    LinkKind kind, {
    String? service,
    String? detail,
    bool prefilled = false,
  }) {
    expect(
      identify(link),
      LinkIdentity(
        kind,
        service: service,
        detail: detail,
        prefilledMessage: prefilled,
      ),
      reason: link,
    );
  }

  group('Google', () {
    test('Drive : fichier ou dossier', () {
      expectIdentity(
        'https://drive.google.com/file/d/1AbCdEf/view?usp=sharing',
        LinkKind.sharedFile,
        service: 'Google Drive',
      );
      expectIdentity(
        'https://drive.google.com/drive/folders/1AbCdEf',
        LinkKind.sharedFolder,
        service: 'Google Drive',
      );
      expectIdentity(
        'https://drive.google.com/uc?export=download&id=1AbCdEf',
        LinkKind.sharedFile,
        service: 'Google Drive',
      );
    });

    test('documents et formulaires', () {
      expectIdentity(
        'https://docs.google.com/document/d/1x/edit',
        LinkKind.document,
        service: 'Google Docs',
      );
      expectIdentity(
        'https://docs.google.com/spreadsheets/d/1x',
        LinkKind.document,
        service: 'Google Sheets',
      );
      expectIdentity(
        'https://docs.google.com/presentation/d/1x',
        LinkKind.document,
        service: 'Google Slides',
      );
      expectIdentity(
        'https://docs.google.com/forms/d/e/1FAIpQ/viewform',
        LinkKind.form,
        service: 'Google Forms',
      );
      expectIdentity(
        'https://forms.gle/AbCdEf123',
        LinkKind.form,
        service: 'Google Forms',
      );
      expectIdentity(
        'https://sites.google.com/view/promo-orange',
        LinkKind.userPage,
        service: 'Google Sites',
      );
    });

    test('Google Play, avec l’application', () {
      expectIdentity(
        'https://play.google.com/store/apps/details?id=com.orange.myorange.ocm',
        LinkKind.appStore,
        service: 'Google Play',
        detail: 'com.orange.myorange.ocm',
      );
      expectIdentity(
        'https://play.google.com/store',
        LinkKind.appStore,
        service: 'Google Play',
      );
    });

    test('cartes', () {
      for (final link in [
        'https://maps.app.goo.gl/AbCd',
        'https://goo.gl/maps/AbCd',
        'https://www.google.com/maps/place/Ouagadougou',
        'https://maps.google.com/?q=12.37,-1.53',
      ]) {
        expectIdentity(link, LinkKind.map, service: 'Google Maps');
      }
    });

    test('stockage Google Cloud', () {
      expectIdentity(
        'https://storage.googleapis.com/bucket/page',
        LinkKind.sharedFile,
        service: 'Google Cloud',
      );
    });

    test('autre page de Google : site officiel', () {
      expectIdentity(
        'https://www.google.com/',
        LinkKind.officialSite,
        detail: 'Google',
      );
    });
  });

  group('messageries', () {
    test('WhatsApp : discussion avec un numéro', () {
      expectIdentity(
        'https://wa.me/22670123456',
        LinkKind.chat,
        service: 'WhatsApp',
        detail: '+22670123456',
      );
      expectIdentity(
        'https://wa.me/22670123456?text=Bonjour%20je%20veux%20le%20bonus',
        LinkKind.chat,
        service: 'WhatsApp',
        detail: '+22670123456',
        prefilled: true,
      );
      expectIdentity(
        'https://api.whatsapp.com/send?phone=22670123456&text=Salut',
        LinkKind.chat,
        service: 'WhatsApp',
        detail: '+22670123456',
        prefilled: true,
      );
      expectIdentity(
        'https://wa.me/message/ABCDEF123',
        LinkKind.chat,
        service: 'WhatsApp',
      );
      // Pas un numéro : pas de précision.
      expectIdentity('https://wa.me/bonus', LinkKind.chat, service: 'WhatsApp');
    });

    test('WhatsApp : groupe, chaîne, site', () {
      expectIdentity(
        'https://chat.whatsapp.com/AbCdEfGh123',
        LinkKind.groupInvite,
        service: 'WhatsApp',
      );
      expectIdentity(
        'https://whatsapp.com/channel/0029VaAbc',
        LinkKind.channel,
        service: 'WhatsApp',
      );
      expectIdentity(
        'https://www.whatsapp.com/',
        LinkKind.officialSite,
        detail: 'WhatsApp',
      );
    });

    test('Telegram et Messenger', () {
      expectIdentity(
        'https://t.me/+AbCdEf123',
        LinkKind.groupInvite,
        service: 'Telegram',
      );
      expectIdentity(
        'https://t.me/joinchat/AbCdEf',
        LinkKind.groupInvite,
        service: 'Telegram',
      );
      expectIdentity(
        'https://t.me/bonus_orange_bf',
        LinkKind.channel,
        service: 'Telegram',
        detail: '@bonus_orange_bf',
      );
      expectIdentity(
        'https://t.me/s/infos',
        LinkKind.channel,
        service: 'Telegram',
        detail: '@infos',
      );
      expectIdentity(
        'https://m.me/pagepromo',
        LinkKind.chat,
        service: 'Messenger',
        detail: 'pagepromo',
      );
      expectIdentity(
        'https://www.messenger.com/t/123',
        LinkKind.chat,
        service: 'Messenger',
      );
    });
  });

  group('réseaux sociaux et vidéos', () {
    test('Facebook', () {
      expectIdentity(
        'https://www.facebook.com/groups/123456',
        LinkKind.group,
        service: 'Facebook',
      );
      expectIdentity(
        'https://www.facebook.com/share/p/AbCd/',
        LinkKind.post,
        service: 'Facebook',
      );
      expectIdentity(
        'https://m.facebook.com/story.php?story_fbid=1&id=2',
        LinkKind.post,
        service: 'Facebook',
      );
      expectIdentity(
        'https://www.facebook.com/share/v/AbCd/',
        LinkKind.video,
        service: 'Facebook',
      );
      expectIdentity(
        'https://fb.watch/AbCd/',
        LinkKind.video,
        service: 'Facebook',
      );
      expectIdentity(
        'https://www.facebook.com/marketplace/item/123',
        LinkKind.post,
        service: 'Facebook Marketplace',
      );
      expectIdentity(
        'https://web.facebook.com/OrangeBurkina',
        LinkKind.profile,
        service: 'Facebook',
      );
    });

    test('Instagram, TikTok, X, LinkedIn, Snapchat', () {
      expectIdentity(
        'https://www.instagram.com/reel/AbCd/',
        LinkKind.video,
        service: 'Instagram',
      );
      expectIdentity(
        'https://www.instagram.com/p/AbCd/',
        LinkKind.post,
        service: 'Instagram',
      );
      expectIdentity(
        'https://www.instagram.com/orange_bf/',
        LinkKind.profile,
        service: 'Instagram',
      );
      expectIdentity(
        'https://vm.tiktok.com/ZMabc/',
        LinkKind.video,
        service: 'TikTok',
      );
      expectIdentity(
        'https://www.tiktok.com/@user/video/123',
        LinkKind.video,
        service: 'TikTok',
      );
      expectIdentity(
        'https://www.tiktok.com/@user',
        LinkKind.profile,
        service: 'TikTok',
      );
      expectIdentity(
        'https://x.com/user/status/123',
        LinkKind.post,
        service: 'X',
      );
      expectIdentity(
        'https://twitter.com/user',
        LinkKind.profile,
        service: 'X',
      );
      expectIdentity(
        'https://www.linkedin.com/jobs/view/123',
        LinkKind.job,
        service: 'LinkedIn',
      );
      expectIdentity(
        'https://www.linkedin.com/in/someone',
        LinkKind.profile,
        service: 'LinkedIn',
      );
      expectIdentity(
        'https://www.linkedin.com/posts/someone_123',
        LinkKind.post,
        service: 'LinkedIn',
      );
      expectIdentity(
        'https://www.snapchat.com/add/someone',
        LinkKind.profile,
        service: 'Snapchat',
      );
    });

    test('YouTube', () {
      expectIdentity(
        'https://youtu.be/dQw4w9WgXcQ',
        LinkKind.video,
        service: 'YouTube',
      );
      expectIdentity(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        LinkKind.video,
        service: 'YouTube',
      );
      expectIdentity(
        'https://www.youtube.com/shorts/abc',
        LinkKind.video,
        service: 'YouTube',
      );
      expectIdentity(
        'https://www.youtube.com/@chaine',
        LinkKind.channel,
        service: 'YouTube',
      );
      expectIdentity(
        'https://www.youtube.com/',
        LinkKind.officialSite,
        detail: 'YouTube',
      );
    });

    test('magasin d’Apple', () {
      expectIdentity(
        'https://apps.apple.com/fr/app/id123',
        LinkKind.appStore,
        service: 'App Store',
      );
    });

    test('page d’accueil d’un réseau : site officiel', () {
      expectIdentity(
        'https://www.facebook.com/',
        LinkKind.officialSite,
        detail: 'Facebook',
      );
      expectIdentity(
        'https://www.instagram.com/',
        LinkKind.officialSite,
        detail: 'Instagram',
      );
      expectIdentity(
        'https://x.com/',
        LinkKind.officialSite,
        detail: 'X (Twitter)',
      );
    });
  });

  group('partage de fichiers et pages', () {
    test('services de partage', () {
      expectIdentity(
        'https://www.dropbox.com/scl/fi/abc/facture?dl=0',
        LinkKind.sharedFile,
        service: 'Dropbox',
      );
      expectIdentity(
        'https://www.dropbox.com/sh/abc/def',
        LinkKind.sharedFolder,
        service: 'Dropbox',
      );
      expectIdentity(
        'https://1drv.ms/b/s!AbC',
        LinkKind.sharedFile,
        service: 'OneDrive',
      );
      expectIdentity(
        'https://onedrive.live.com/?id=abc',
        LinkKind.sharedFile,
        service: 'OneDrive',
      );
      expectIdentity(
        'https://contoso.sharepoint.com/:b:/s/abc',
        LinkKind.sharedFile,
        service: 'SharePoint',
      );
      expectIdentity(
        'https://we.tl/t-AbCd',
        LinkKind.sharedFile,
        service: 'WeTransfer',
      );
      expectIdentity(
        'https://mega.nz/folder/AbCd',
        LinkKind.sharedFolder,
        service: 'MEGA',
      );
      expectIdentity(
        'https://mega.nz/file/AbCd',
        LinkKind.sharedFile,
        service: 'MEGA',
      );
      expectIdentity(
        'https://www.mediafire.com/file/abc/doc',
        LinkKind.sharedFile,
        service: 'MediaFire',
      );
      expectIdentity(
        'https://www.mediafire.com/folder/abc',
        LinkKind.sharedFolder,
        service: 'MediaFire',
      );
    });

    test('formulaires et pages ouvertes à tous', () {
      expectIdentity(
        'https://forms.office.com/r/AbCd',
        LinkKind.form,
        service: 'Microsoft Forms',
      );
      expectIdentity(
        'https://form.jotform.com/123',
        LinkKind.form,
        service: 'Jotform',
      );
      expectIdentity(
        'https://abc.typeform.com/to/xyz',
        LinkKind.form,
        service: 'Typeform',
      );
      expectIdentity(
        'https://linktr.ee/promo',
        LinkKind.linkPage,
        service: 'Linktree',
      );
      expectIdentity(
        'https://telegra.ph/Bonus-11-28',
        LinkKind.userPage,
        service: 'Telegraph',
      );
      expectIdentity(
        'https://promo.notion.site/page',
        LinkKind.userPage,
        service: 'Notion',
      );
      expectIdentity(
        'https://bonus.canva.site/',
        LinkKind.userPage,
        service: 'Canva',
      );
    });

    test('page sur une plateforme d’hébergement ouverte à tous', () {
      expectIdentity(
        'https://cadeaux-noel.blogspot.com/',
        LinkKind.userPage,
        service: 'blogspot.com',
      );
      expectIdentity(
        'https://quelquun.github.io/page',
        LinkKind.userPage,
        service: 'github.io',
      );
    });
  });

  group('fichiers à télécharger', () {
    test('application Android à installer', () {
      expectIdentity(
        'http://promo-bf.top/MaxIt-Bonus.apk',
        LinkKind.appFile,
        detail: 'apk',
      );
      // Sur un service connu : le service est dit aussi.
      expectIdentity(
        'https://www.mediafire.com/file/abc/bonus.apk',
        LinkKind.appFile,
        service: 'MediaFire',
        detail: 'apk',
      );
    });

    test('documents, archives, programmes', () {
      expectIdentity(
        'https://exemple.com/facture.PDF',
        LinkKind.file,
        detail: 'pdf',
      );
      expectIdentity(
        'https://exemple.com/dl/setup.exe',
        LinkKind.file,
        detail: 'exe',
      );
      expectIdentity(
        'https://exemple.com/photos.zip',
        LinkKind.file,
        detail: 'zip',
      );
    });

    test('pages web ordinaires : pas un fichier', () {
      expectIdentity(
        'https://lefaso.net/spip.php?article1',
        LinkKind.website,
        detail: 'lefaso.net',
      );
      expectIdentity(
        'https://exemple.com/page.html',
        LinkKind.website,
        detail: 'exemple.com',
      );
      expectIdentity(
        'https://exemple.com/v1.2/',
        LinkKind.website,
        detail: 'exemple.com',
      );
    });
  });

  group('sites', () {
    test('lien raccourci', () {
      expectIdentity(
        'https://bit.ly/3AbCdEf',
        LinkKind.shortLink,
        service: 'bit.ly',
      );
      expectIdentity(
        'https://tinyurl.com/abc',
        LinkKind.shortLink,
        service: 'tinyurl.com',
      );
    });

    test('site officiel d’une marque de référence', () {
      expectIdentity(
        'https://www.orange.bf/fr/offres',
        LinkKind.officialSite,
        detail: 'Orange',
      );
      expectIdentity(
        'https://www.sonabel.bf/',
        LinkKind.officialSite,
        detail: 'SONABEL',
      );
    });

    test('imitation d’une marque', () {
      expectIdentity(
        'http://orange-gain.xyz/retrait',
        LinkKind.imitation,
        detail: 'Orange',
      );
      expectIdentity(
        'https://www.paypal.com.connexion-securite.top/',
        LinkKind.imitation,
        detail: 'PayPal',
      );
      expectIdentity(
        'https://faceb00k-login.com/',
        LinkKind.imitation,
        detail: 'Facebook',
      );
    });

    test('adresse IP', () {
      expectIdentity(
        'http://192.168.1.20/login',
        LinkKind.ipAddress,
        detail: '192.168.1.20',
      );
    });

    test('site ordinaire, nom lisible', () {
      expectIdentity(
        'https://lefaso.net/',
        LinkKind.website,
        detail: 'lefaso.net',
      );
      expectIdentity(
        'https://xn--caf-dma.fr/',
        LinkKind.website,
        detail: 'café.fr',
      );
    });

    test('texte qui n’est pas un lien : pas de description', () {
      expect(analyzer.analyze('bonjour', context).identity, isNull);
    });
  });

  test('égalité et texte de débogage', () {
    const a = LinkIdentity(LinkKind.chat, service: 'WhatsApp', detail: '+226');
    expect(
      a,
      const LinkIdentity(LinkKind.chat, service: 'WhatsApp', detail: '+226'),
    );
    expect(a.hashCode, isA<int>());
    expect(a, isNot(const LinkIdentity(LinkKind.chat, service: 'WhatsApp')));
    expect('$a', 'LinkIdentity(chat, WhatsApp)');
  });
}
