import 'dart:convert';
import 'dart:isolate';

import 'package:auto_route/auto_route.dart';
import 'package:digit_crud_bloc/digit_crud_bloc.dart';
import 'package:digit_flow_builder/data/digit_crud_service.dart';
import 'package:digit_flow_builder/flow_builder.dart';
import 'package:digit_flow_builder/router/flow_builder_routes.gm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for a module's flow navigation
class FlowModuleConfig {
  /// The key used to retrieve schema from app_config_schemas (e.g., 'COMPLAINTS', 'CLOSEHOUSEHOLD')
  final String schemaKey;

  /// Sample flows to use as fallback when schema is not available
  final dynamic sampleFlows;

  /// Relationship mappings for the CRUD service
  final List<RelationshipMapping> relationshipMappings;

  /// Nested model mappings for the CRUD service
  final List<NestedModelMapping> nestedModelMappings;

  const FlowModuleConfig({
    required this.schemaKey,
    this.sampleFlows,
    this.relationshipMappings = const [],
    this.nestedModelMappings = const [],
  });
}

/// Utility class for handling flow-based module navigation
class FlowNavigationUtils {
  static Future<List<Map<String, dynamic>>> _parseFlows(dynamic rawFlows) {
    return Isolate.run(() => _parseFlowsInIsolate(rawFlows));
  }

  static Future<void> _navigate(
      BuildContext context, Map<String, dynamic> configData) async {
    List<Map<String, dynamic>> flowsData =
        await _parseFlows(configData['flows'] as List<dynamic>?);
    FlowRegistry.setConfig(flowsData);
    NavigationRegistry.setupNavigation(context);

    context.router.push(
      FlowBuilderHomeRoute(pageName: configData["initialPage"]),
    );
  }

  /// Navigates to a flow-based module with the given configuration
  ///
  /// This handles:
  /// - Setting up CrudBlocSingleton with DigitCrudService
  /// - Initializing WidgetRegistry
  /// - Loading schema from SharedPreferences or using sample flows as fallback
  /// - Navigating to the FlowBuilderHomeRoute
  static Future<void> navigateToFlowModule({
    required BuildContext context,
    required FlowModuleConfig config,
  }) async {
    try {
      // Set up CRUD service
      CrudBlocSingleton().setData(
        crudService: DigitCrudService(
          context: context,
          relationshipMap: config.relationshipMappings,
          nestedModelMappings: config.nestedModelMappings,
          searchEntityRepository: context.read<SearchEntityRepository>(),
        ),
        dynamicEntityModelListener: EntityModelMapMapper(),
      );

      // Initialize widget registry
      WidgetRegistry.initialize();

      // // Get schema from shared preferences
      // final prefs = await SharedPreferences.getInstance();
      // final schemaJsonRaw = prefs.getString('app_config_schemas');

      // if (schemaJsonRaw != null && config.schemaKey != "ATTENDANCE") {
      //   final allSchemas = json.decode(schemaJsonRaw) as Map<String, dynamic>;
      //   final moduleSchema = allSchemas[config.schemaKey];

      //   if (moduleSchema != null) {
      //     Map<String, dynamic> configData = moduleSchema['data'];
      //     await _navigate(context, configData);
      //     return;
      //   }
      // }

      if (config.sampleFlows != null) {
        await _navigate(context, config.sampleFlows);
        return;
      }

      Map<String, dynamic> localConfig =
          await FlowModuleUtils.loadLocalFlows(config.schemaKey);
      await _navigate(context, localConfig);
    } catch (e) {
      debugPrint('FlowNavigationUtils error: $e');
    }
  }
}

List<Map<String, dynamic>> _parseFlowsInIsolate(dynamic rawFlows) {
  final flows = rawFlows as List<dynamic>? ?? const [];
  return flows.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

class FlowModuleUtils {
  /// Loads a JSON config file from assets/configs/json and stores it
  /// directly from bundled assets.
  ///
  /// [configJsonName] can be passed with or without `.json` extension.
  /// Returns the loaded schema JSON map.
  static Future<Map<String, dynamic>> loadLocalFlows(
      String configJsonName) async {
    const configDirectory = 'assets/configs/json';
    final assetPath = '$configDirectory/$configJsonName.json';

    try {
      final fileContent = await rootBundle.loadString(assetPath);
      final schemaJson = json.decode(fileContent) as Map<String, dynamic>;
      return schemaJson;
    } catch (e) {
      debugPrint('FlowModuleUtils: failed to load $assetPath: $e');
      rethrow;
    }
  }
}
