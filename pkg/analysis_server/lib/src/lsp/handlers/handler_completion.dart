// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:analysis_server/lsp_protocol/protocol_generated.dart';
import 'package:analysis_server/lsp_protocol/protocol_special.dart';
import 'package:analysis_server/protocol/protocol_generated.dart';
import 'package:analysis_server/src/domains/completion/available_suggestions.dart';
import 'package:analysis_server/src/lsp/handlers/handlers.dart';
import 'package:analysis_server/src/lsp/lsp_analysis_server.dart';
import 'package:analysis_server/src/lsp/mapping.dart';
import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/services/completion/completion_core.dart';
import 'package:analysis_server/src/services/completion/completion_performance.dart';
import 'package:analysis_server/src/services/completion/dart/completion_manager.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/src/services/available_declarations.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;

// If the client does not provide capabilities.completion.completionItemKind.valueSet
// then we must never send a kind that's not in this list.
final defaultSupportedCompletionKinds = HashSet<CompletionItemKind>.of([
  CompletionItemKind.Text,
  CompletionItemKind.Method,
  CompletionItemKind.Function,
  CompletionItemKind.Constructor,
  CompletionItemKind.Field,
  CompletionItemKind.Variable,
  CompletionItemKind.Class,
  CompletionItemKind.Interface,
  CompletionItemKind.Module,
  CompletionItemKind.Property,
  CompletionItemKind.Unit,
  CompletionItemKind.Value,
  CompletionItemKind.Enum,
  CompletionItemKind.Keyword,
  CompletionItemKind.Snippet,
  CompletionItemKind.Color,
  CompletionItemKind.File,
  CompletionItemKind.Reference,
]);

class CompletionHandler
    extends MessageHandler<CompletionParams, List<CompletionItem>>
    with LspPluginRequestHandlerMixin {
  final bool suggestFromUnimportedLibraries;
  CompletionHandler(
      LspAnalysisServer server, this.suggestFromUnimportedLibraries)
      : super(server);

  @override
  Method get handlesMessage => Method.textDocument_completion;

  @override
  LspJsonHandler<CompletionParams> get jsonHandler =>
      CompletionParams.jsonHandler;

  @override
  Future<ErrorOr<List<CompletionItem>>> handle(
      CompletionParams params, CancellationToken token) async {
    final completionCapabilities =
        server?.clientCapabilities?.textDocument?.completion;

    final clientSupportedCompletionKinds =
        completionCapabilities?.completionItemKind?.valueSet != null
            ? HashSet<CompletionItemKind>.of(
                completionCapabilities.completionItemKind.valueSet)
            : defaultSupportedCompletionKinds;

    final includeSuggestionSets = suggestFromUnimportedLibraries &&
        server?.clientCapabilities?.workspace?.applyEdit == true;

    final pos = params.position;
    final path = pathOfDoc(params.textDocument);
    final unit = await path.mapResult(requireResolvedUnit);

    final lineInfo = unit.map<ErrorOr<LineInfo>>(
      // If we don't have a unit, we can still try to obtain the line info for
      // plugin contributors.
      (error) => path.mapResult(getLineInfo),
      (unit) => success(unit.lineInfo),
    );
    final offset =
        await lineInfo.mapResult((lineInfo) => toOffset(lineInfo, pos));

    return offset.mapResult((offset) {
      if (unit.isError) {
        return _getItemsFromPluginsOnly(
          completionCapabilities,
          clientSupportedCompletionKinds,
          lineInfo.result,
          path.result,
          offset,
          token,
        );
      } else {
        return _getItems(
          completionCapabilities,
          clientSupportedCompletionKinds,
          includeSuggestionSets,
          unit.result,
          offset,
          token,
        );
      }
    });
  }

  /// Build a list of existing imports so we can filter out any suggestions
  /// that resolve to the same underlying declared symbol.
  /// Map with key "elementName/elementDeclaringLibraryUri"
  /// Value is a set of imported URIs that import that element.
  Map<String, Set<String>> _buildLookupOfImportedSymbols(
      ResolvedUnitResult unit) {
    final alreadyImportedSymbols = <String, Set<String>>{};
    final importElementList = unit.libraryElement.imports;
    for (var import in importElementList) {
      final importedLibrary = import.importedLibrary;
      if (importedLibrary == null) continue;

      for (var element in import.namespace.definedNames.values) {
        if (element.librarySource != null) {
          final declaringLibraryUri = element.librarySource.uri;
          final elementName = element.name;

          final key =
              _createImportedSymbolKey(elementName, declaringLibraryUri);
          alreadyImportedSymbols.putIfAbsent(key, () => <String>{});
          alreadyImportedSymbols[key]
              .add('${importedLibrary.librarySource.uri}');
        }
      }
    }
    return alreadyImportedSymbols;
  }

  String _createImportedSymbolKey(String name, Uri declaringUri) =>
      '$name/$declaringUri';

  Future<ErrorOr<List<CompletionItem>>> _getItems(
    TextDocumentClientCapabilitiesCompletion completionCapabilities,
    HashSet<CompletionItemKind> clientSupportedCompletionKinds,
    bool includeSuggestionSets,
    ResolvedUnitResult unit,
    int offset,
    CancellationToken token,
  ) async {
    final performance = CompletionPerformance();
    performance.path = unit.path;
    performance.setContentsAndOffset(unit.content, offset);
    server.performanceStats.completion.add(performance);

    final completionRequest = CompletionRequestImpl(
        unit, offset, server.options.useNewRelevance, performance);

    Set<ElementKind> includedElementKinds;
    Set<String> includedElementNames;
    List<IncludedSuggestionRelevanceTag> includedSuggestionRelevanceTags;
    if (includeSuggestionSets) {
      includedElementKinds = <ElementKind>{};
      includedElementNames = <String>{};
      includedSuggestionRelevanceTags = <IncludedSuggestionRelevanceTag>[];
    }

    try {
      CompletionContributor contributor = DartCompletionManager(
        dartdocDirectiveInfo:
            server.getDartdocDirectiveInfoFor(completionRequest.result),
        includedElementKinds: includedElementKinds,
        includedElementNames: includedElementNames,
        includedSuggestionRelevanceTags: includedSuggestionRelevanceTags,
      );

      final suggestions = await Future.wait([
        contributor.computeSuggestions(completionRequest),
        _getPluginSuggestions(unit.path, offset),
      ]);
      final serverSuggestions = suggestions[0];
      final pluginSuggestions = suggestions[1];

      if (token.isCancellationRequested) {
        return cancelled();
      }

      final results = serverSuggestions
          .map(
            (item) => toCompletionItem(
              completionCapabilities,
              clientSupportedCompletionKinds,
              unit.lineInfo,
              item,
              completionRequest.replacementOffset,
              completionRequest.replacementLength,
            ),
          )
          .followedBy(
            _pluginResultsToItems(
              completionCapabilities,
              clientSupportedCompletionKinds,
              unit.lineInfo,
              pluginSuggestions,
            ),
          )
          .toList();

      // Now compute items in suggestion sets.
      var includedSuggestionSets = <IncludedSuggestionSet>[];
      if (includedElementKinds != null && unit != null) {
        computeIncludedSetList(
          server.declarationsTracker,
          unit,
          includedSuggestionSets,
          includedElementNames,
        );
      }

      // Build a fast lookup for imported symbols so that we can filter out
      // duplicates.
      final alreadyImportedSymbols = _buildLookupOfImportedSymbols(unit);

      includedSuggestionSets.forEach((includedSet) {
        final library = server.declarationsTracker.getLibrary(includedSet.id);
        if (library == null) {
          return;
        }

        // Make a fast lookup for tag relevance.
        final tagBoosts = <String, int>{};
        includedSuggestionRelevanceTags
            .forEach((t) => tagBoosts[t.tag] = t.relevanceBoost);

        // Only specific types of child declarations should be included.
        // This list matches what's in _protocolAvailableSuggestion in
        // the DAS implementation.
        bool shouldIncludeChild(Declaration child) =>
            child.kind == DeclarationKind.CONSTRUCTOR ||
            child.kind == DeclarationKind.ENUM_CONSTANT ||
            (child.kind == DeclarationKind.GETTER && child.isStatic) ||
            (child.kind == DeclarationKind.FIELD && child.isStatic);

        // Collect declarations and their children.
        final allDeclarations = library.declarations
            .followedBy(library.declarations
                .expand((decl) => decl.children.where(shouldIncludeChild)))
            .toList();

        final setResults = allDeclarations
            // Filter to only the kinds we should return.
            .where((item) =>
                includedElementKinds.contains(protocolElementKind(item.kind)))
            .where((item) {
          // Check existing imports to ensure we don't already import
          // this element (this exact element from its declaring
          // library, not just something with the same name). If we do
          // we'll want to skip it.
          final declaringUri = item.parent != null
              ? item.parent.locationLibraryUri
              : item.locationLibraryUri;

          // For enums and named constructors, only the parent enum/class is in
          // the list of imported symbols so we use the parents name.
          final nameKey = item.kind == DeclarationKind.ENUM_CONSTANT ||
                  item.kind == DeclarationKind.CONSTRUCTOR
              ? item.parent.name
              : item.name;
          final key = _createImportedSymbolKey(nameKey, declaringUri);
          final importingUris = alreadyImportedSymbols[key];

          // Keep it only if there are either:
          // - no URIs importing it
          // - the URIs importing it include this one
          return importingUris == null ||
              importingUris.contains('${library.uri}');
        }).map((item) => declarationToCompletionItem(
                  completionCapabilities,
                  clientSupportedCompletionKinds,
                  unit.path,
                  offset,
                  includedSet,
                  library,
                  tagBoosts,
                  unit.lineInfo,
                  item,
                  completionRequest.replacementOffset,
                  completionRequest.replacementLength,
                ));
        results.addAll(setResults);
      });

      performance.notificationCount = 1;
      performance.suggestionCountFirst = results.length;
      performance.suggestionCountLast = results.length;
      performance.complete();

      return success(results);
    } on AbortCompletion {
      return success([]);
    }
  }

  Future<ErrorOr<List<CompletionItem>>> _getItemsFromPluginsOnly(
    TextDocumentClientCapabilitiesCompletion completionCapabilities,
    HashSet<CompletionItemKind> clientSupportedCompletionKinds,
    LineInfo lineInfo,
    String path,
    int offset,
    CancellationToken token,
  ) async {
    final pluginResults = await _getPluginSuggestions(path, offset);

    if (token.isCancellationRequested) {
      return cancelled();
    }

    return success(_pluginResultsToItems(
      completionCapabilities,
      clientSupportedCompletionKinds,
      lineInfo,
      pluginResults,
    ).toList());
  }

  Future<List<plugin.CompletionGetSuggestionsResult>> _getPluginSuggestions(
    String path,
    int offset,
  ) async {
    final requestParams = plugin.CompletionGetSuggestionsParams(path, offset);
    final responses = await requestFromPlugins(path, requestParams);

    return responses
        .map((e) => plugin.CompletionGetSuggestionsResult.fromResponse(e))
        .toList();
  }

  Iterable<CompletionItem> _pluginResultsToItems(
    TextDocumentClientCapabilitiesCompletion completionCapabilities,
    HashSet<CompletionItemKind> clientSupportedCompletionKinds,
    LineInfo lineInfo,
    List<plugin.CompletionGetSuggestionsResult> pluginResults,
  ) {
    return pluginResults.expand((result) {
      return result.results.map(
        (item) => toCompletionItem(
          completionCapabilities,
          clientSupportedCompletionKinds,
          lineInfo,
          item,
          result.replacementOffset,
          result.replacementLength,
        ),
      );
    });
  }
}
