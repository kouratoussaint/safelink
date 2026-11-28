import 'dart:async';

import 'package:safelink/features/analysis/analysis_service.dart';
import 'package:safelink/features/quick/quick_platform.dart';
import 'package:safelink/features/share/shared_content.dart';

/// Panneau rapide simulé : `initial` comme lu à l'ouverture, puis [send]
/// quand la bulle est touchée de nouveau ; garde les fermetures et les
/// ouvertures dans l'application.
class FakeQuickPlatform implements QuickPlatform {
  new([List<SharedContent> initial = const []]) {
    initial.forEach(_controller.add);
  }

  final _controller = StreamController<SharedContent>();

  /// Nombre de fermetures demandées.
  int closes = 0;

  /// Vérifications ouvertes dans l'application, avec leur identifiant
  /// d'historique.
  final opened = <(AnalysisRequest, String?)>[];

  @override
  Stream<SharedContent> contents() => _controller.stream;

  /// Simule une nouvelle lecture du texte copié.
  void send(SharedContent content) => _controller.add(content);

  @override
  Future<void> close() async => closes++;

  @override
  Future<bool> openInApp(AnalysisRequest request, {String? historyId}) async {
    opened.add((request, historyId));
    return true;
  }
}
