import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/share/share_source.dart';
import 'package:safelink/features/share/shared_content.dart';

/// Ce que le panneau rapide demande à Android (ADR 0015) ; remplacé par une
/// version simulée dans les tests.
abstract interface class QuickPlatform {
  /// Textes copiés lus pour le panneau : à l'ouverture, puis à chaque fois
  /// que la bulle ou la tuile est touchée de nouveau.
  Stream<SharedContent> contents();

  /// Ferme le panneau : on revient à l'application d'où l'on venait.
  Future<void> close();

  /// Ouvre [request] en entier dans SafeLink, puis ferme le panneau ;
  /// [historyId] est l'identifiant sous lequel le panneau l'a enregistrée,
  /// s'il l'a fait. `false` si SafeLink n'a pas pu s'ouvrir.
  Future<bool> openInApp(AnalysisRequest request, {String? historyId});
}

/// Panneau servi par `QuickCheckActivity` sur le canal
/// `com.fasosoft.safelink/quick`.
///
/// Les textes copiés suivent le même chemin que les partages (`take`, puis
/// `available` à chaud) : voir [PlatformShareSource].
final class PlatformQuick implements QuickPlatform {
  /// Crée l'accès ; [channel] remplace le canal dans les tests.
  new({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(name);

  /// Nom du canal.
  static const name = 'com.fasosoft.safelink/quick';

  final MethodChannel _channel;

  @override
  Stream<SharedContent> contents() =>
      PlatformShareSource(channel: _channel).shares();

  @override
  Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on PlatformException {
      await SystemNavigator.pop();
    } on MissingPluginException {
      await SystemNavigator.pop();
    }
  }

  @override
  Future<bool> openInApp(AnalysisRequest request, {String? historyId}) async {
    try {
      return await _channel.invokeMethod<bool>('openInApp', {
            'kind': request.kind.name,
            'text': request.text,
            'historyId': historyId,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Accès du panneau à Android ; remplacé dans les tests.
final quickPlatformProvider = Provider<QuickPlatform>((ref) => PlatformQuick());
