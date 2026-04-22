import 'package:digit_data_model/data_model.dart';

/// Utility class for calculating stock metrics.
///
/// This provides common stock calculation methods that can be reused across
/// different widgets like StockReconciliationCard and ProductSelectionCard.
class StockCalculationUtils {
  /// Extracts a value from a StockModel's additionalFields by key.
  /// Returns uppercase string value or empty string if not found.
  static String _getAdditionalFieldValue(StockModel stock, String key) {
    final fields = stock.additionalFields?.fields;
    if (fields == null) return '';
    for (final field in fields) {
      if (field.key == key) {
        return field.value?.toString().toUpperCase() ?? '';
      }
    }
    return '';
  }

  /// Extracts the stockEntryType from a StockModel's additionalFields.
  /// Returns uppercase value (e.g., 'RECEIPT', 'ISSUED', 'RETURNED', 'DAMAGED', 'LOSS')
  /// or empty string if not found.
  static String _getStockEntryType(StockModel stock) {
    return _getAdditionalFieldValue(stock, 'stockEntryType');
  }

  /// Calculates stock metrics for a given facility and product from a list of stocks.
  ///
  /// Parameters:
  /// - [stockList]: List of StockModel entries to calculate from
  /// - [facilityId]: The facility ID to filter stocks by (as sender or receiver)
  /// - [productId]: The product variant ID to filter stocks by
  /// - [loggedInUserUuid]: Optional user UUID to filter stocks created by this user
  ///
  /// Returns a Map with the following keys:
  /// - stockReceived: Total quantity received
  /// - stockIssued: Total quantity issued/dispatched
  /// - stockReturned: Total quantity returned
  /// - stockLost: Total quantity lost
  /// - stockDamaged: Total quantity damaged
  /// - stockInHand: Calculated as (received) - (issued + returned + damaged + lost). Excess/less are tracked but do not affect balance.
  static Map<String, double> calculateStockMetrics({
    required List<StockModel> stockList,
    required String facilityId,
    required String productId,
    String? loggedInUserUuid,
    bool isDistributor = false,
  }) {
    // Filter stocks matching the criteria
    final filteredStock = stockList.where((stock) {
      // Must match product
      if (stock.productVariantId != productId) return false;

      // For distributors: match by receiverId only (user UUID)
      // For warehouse managers: match by facilityId (either as receiver or sender)
      if (isDistributor) {
        final matchesReceiver = stock.receiverId == facilityId;
        final matchesSender = stock.senderId == facilityId;
        if (!matchesReceiver && !matchesSender) return false;
      } else {
        final matchesReceiver = stock.receiverId == facilityId;
        final matchesSender = stock.senderId == facilityId;
        if (!matchesReceiver && !matchesSender) return false;
      }

      return true;
    }).toList();

    // Calculate metrics following StockReconciliationBloc pattern
    double stockReceived = 0;
    double stockIssued = 0;
    double stockReturned = 0;
    double stockLost = 0;
    double stockDamaged = 0;
    double stockExcess = 0;
    double stockLess = 0;

    for (final stock in filteredStock) {
      final transactionType = stock.transactionType?.toUpperCase() ?? '';
      final transactionReason = stock.transactionReason?.toUpperCase() ?? '';
      final quantity = num.tryParse(stock.quantity ?? '0') ?? 0.0;
      final status = _getAdditionalFieldValue(stock, 'status');
      final stockEntryType = _getStockEntryType(stock);

      // For distributors: only receiverId is used (user UUID)
      // senderId = delivery team UUID, receiverId = distributor UUID
      final isReceiver = stock.receiverId == facilityId;
      final isSender = stock.senderId == facilityId;

      // Distributor calculations
      if (isDistributor) {
        // Distributors: received stocks are counted, LOSS/DAMAGED are counted as lost/damaged
        if (transactionType == 'RECEIVED') {
          if (transactionReason == 'RETURNED' || stockEntryType == 'RETURNED') {
            stockReturned += quantity;
          } else if (stockEntryType == 'EXCESS') {
            stockExcess += quantity;
          } else if (stockEntryType == 'LESS') {
            stockLess += quantity;
          } else {
            stockReceived += quantity;
          }
        } else if (transactionType == 'DISPATCHED') {
          // For DISPATCHED: LOSS/DAMAGED are counted against distributor
          if (status == 'ACCEPTED' &&
              !(transactionReason == 'RETURNED' ||
                  stockEntryType == 'RETURNED')) {
            stockReceived += quantity;
          }
          // Count LOSS/DAMAGED as lost/damaged
          if (stockEntryType == 'LOSS') {
            stockLost += quantity;
          } else if (stockEntryType == 'DAMAGED') {
            stockDamaged += quantity;
          }
          if (transactionReason == 'RETURNED' || stockEntryType == 'RETURNED') {
            stockReturned += quantity;
          }
        }
        continue;
      }

      // Warehouse Manager calculations
      if (isReceiver && transactionType == 'RECEIVED') {
        if (transactionReason == 'RETURNED' || stockEntryType == 'RETURNED') {
          stockReturned += quantity;
        } else if (stockEntryType == 'EXCESS') {
          stockExcess += quantity;
        } else if (stockEntryType == 'LESS') {
          stockLess += quantity;
        } else if (transactionReason.isEmpty ||
            transactionReason == 'RECEIVED') {
          stockReceived += quantity;
        }
      } else if (isSender && stockEntryType == 'LOSS') {
        stockLost += quantity;
      } else if (isSender && stockEntryType == 'DAMAGED') {
        stockDamaged += quantity;
      } else if (isSender && transactionType == 'DISPATCHED') {
        if (status == 'REJECTED') {
          // Skip - rejected stock is not subtracted from sender's balance
        } else if (transactionReason == 'LOST_IN_TRANSIT' ||
            transactionReason == 'LOST_IN_STORAGE' ||
            stockEntryType == 'LOSS') {
          stockLost += quantity;
        } else if (transactionReason == 'DAMAGED_IN_TRANSIT' ||
            transactionReason == 'DAMAGED_IN_STORAGE' ||
            stockEntryType == 'DAMAGED') {
          stockDamaged += quantity;
        } else if (stockEntryType == 'RETURNED') {
          stockReturned += quantity;
        } else {
          stockIssued += quantity;
        }
      } else if (isReceiver && transactionType == 'DISPATCHED') {
        if (status == 'ACCEPTED') {
          stockReceived += quantity;
        }
      }
    }

    // Stock in hand = (received + returned) - (issued + damaged + lost)
    // Note: excess and less are tracked for backend reporting only and do not affect balance
    final stockInHand = stockReceived +
        stockExcess -
        (stockIssued + stockReturned + stockDamaged + stockLost + stockLess);

    return {
      'stockReceived': stockReceived,
      'stockIssued': stockIssued,
      'stockReturned': stockReturned,
      'stockLost': stockLost,
      'stockDamaged': stockDamaged,
      'stockExcess': stockExcess,
      'stockLess': stockLess,
      'stockInHand': stockInHand,
    };
  }

  /// Calculates stock in hand for multiple products at once.
  ///
  /// Parameters:
  /// - [stockList]: List of StockModel entries to calculate from
  /// - [facilityId]: The facility ID to filter stocks by
  /// - [productIds]: List of product variant IDs to calculate for
  /// - [loggedInUserUuid]: Optional user UUID to filter stocks
  ///
  /// Returns a Map where keys are productIds and values are stockInHand quantities.
  static Map<String, double> calculateStockInHandForProducts({
    required List<StockModel> stockList,
    required String facilityId,
    required List<String> productIds,
    String? loggedInUserUuid,
    bool isDistributor = false,
  }) {
    final result = <String, double>{};

    for (final productId in productIds) {
      final metrics = calculateStockMetrics(
        stockList: stockList,
        facilityId: facilityId,
        productId: productId,
        loggedInUserUuid: loggedInUserUuid,
        isDistributor: isDistributor,
      );
      result[productId] = metrics['stockInHand'] ?? 0.0;
    }

    return result;
  }

  /// Calculates consumed quantities from bednet administration tasks.
  ///
  /// A task is treated as a bednet administration task when:
  /// [bednetStatusKey] in additionalFields equals [bednetSuccessStatus].
  /// Consumption is read from task resources by product variant id.
  /// If resources are absent, optional [fallbackPupilsPresentKey] is used and
  /// attributed to [singleFallbackProductId] (used for single-product validation).
  static Map<String, double> calculateBednetConsumedByProduct({
    required List<TaskModel> tasks,
    required String loggedInUserUuid,
    required String bednetStatusKey,
    required String bednetSuccessStatus,
    String? fallbackPupilsPresentKey,
    String? fallbackItnDeliveredKey,
    String? singleFallbackProductId,
  }) {
    bool isBednetTask(TaskModel task) {
      for (final field
          in task.additionalFields?.fields ?? const <AdditionalField>[]) {
        if (field.key == bednetStatusKey &&
            field.value?.toString() == bednetSuccessStatus) {
          return true;
        }
      }
      return false;
    }

    final consumed = <String, double>{};
    for (final task in tasks) {
      if (task.createdBy != loggedInUserUuid) continue;
      if (!isBednetTask(task)) continue;

      var hasResource = false;
      for (final resource in task.resources ?? const <TaskResourceModel>[]) {
        final productId = resource.productVariantId;
        if (productId == null || productId.isEmpty) continue;
        final qty = num.tryParse(resource.quantity ?? '')?.toDouble() ?? 0;
        consumed[productId] = (consumed[productId] ?? 0) + qty;
        hasResource = true;
      }
      if (hasResource) continue;

      if (singleFallbackProductId != null &&
          singleFallbackProductId.isNotEmpty) {
        for (final field
            in task.additionalFields?.fields ?? const <AdditionalField>[]) {
          if ((fallbackPupilsPresentKey != null &&
                  field.key == fallbackPupilsPresentKey) ||
              (fallbackItnDeliveredKey != null &&
                  field.key == fallbackItnDeliveredKey)) {
            final qty =
                num.tryParse(field.value?.toString() ?? '')?.toDouble() ?? 0;
            consumed[singleFallbackProductId] =
                (consumed[singleFallbackProductId] ?? 0) + qty;
            break;
          }
        }
      }
    }

    return consumed;
  }

  /// Calculates effective stock in hand by subtracting bednet-consumed quantity.
  static Map<String, double> calculateEffectiveStockInHandForProducts({
    required List<StockModel> stockList,
    required List<TaskModel> tasks,
    required String facilityId,
    required List<String> productIds,
    required String loggedInUserUuid,
    required String bednetStatusKey,
    required String bednetSuccessStatus,
    String? fallbackPupilsPresentKey,
    String? fallbackItnDeliveredKey,
    String? singleFallbackProductId,
    bool isDistributor = false,
  }) {
    final rawBalances = calculateStockInHandForProducts(
      stockList: stockList,
      facilityId: facilityId,
      productIds: productIds,
      loggedInUserUuid: loggedInUserUuid,
      isDistributor: isDistributor,
    );
    final consumedByProduct = calculateBednetConsumedByProduct(
      tasks: tasks,
      loggedInUserUuid: loggedInUserUuid,
      bednetStatusKey: bednetStatusKey,
      bednetSuccessStatus: bednetSuccessStatus,
      fallbackPupilsPresentKey: fallbackPupilsPresentKey,
      fallbackItnDeliveredKey: fallbackItnDeliveredKey,
      singleFallbackProductId: singleFallbackProductId,
    );

    final effective = <String, double>{};
    for (final productId in productIds) {
      final raw = rawBalances[productId] ?? 0;
      final consumed = consumedByProduct[productId] ?? 0;
      effective[productId] = (raw - consumed).clamp(0, double.infinity);
    }
    return effective;
  }

  /// Returns empty/zero stock metrics map.
  static Map<String, double> get emptyMetrics => {
        'stockReceived': 0,
        'stockIssued': 0,
        'stockReturned': 0,
        'stockLost': 0,
        'stockDamaged': 0,
        'stockExcess': 0,
        'stockLess': 0,
        'stockInHand': 0,
      };

  /// Extracts StockModel list from FlowCrudState's stateWrapper.
  ///
  /// This helper method parses the stateWrapper structure to extract
  /// StockModel entries.
  static List<StockModel> extractStockListFromWrapper(
      List<dynamic>? stateWrapper) {
    if (stateWrapper == null || stateWrapper.isEmpty) return [];

    try {
      for (final wrapperMap in stateWrapper) {
        if (wrapperMap is Map) {
          // Check for both 'StockModel' and 'stock' keys (CrudBloc uses 'stock')
          List? stockData;
          if (wrapperMap.containsKey('StockModel')) {
            stockData = wrapperMap['StockModel'] as List?;
          } else if (wrapperMap.containsKey('stock')) {
            stockData = wrapperMap['stock'] as List?;
          }

          if (stockData != null && stockData.isNotEmpty) {
            return stockData
                .map((e) => e is StockModel
                    ? e
                    : StockModelMapper.fromMap(e as Map<String, dynamic>))
                .toList();
          }
        }
      }
    } catch (e) {
      // Silently handle parsing errors
    }

    return [];
  }
}
