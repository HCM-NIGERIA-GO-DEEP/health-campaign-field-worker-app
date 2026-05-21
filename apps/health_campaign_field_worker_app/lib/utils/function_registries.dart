import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:digit_crud_bloc/digit_crud_bloc.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_flow_builder/flow_builder.dart';
import 'package:digit_flow_builder/utils/function_registry.dart';
import 'package:digit_flow_builder/utils/interpolation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/entities/roles_type.dart';
import 'extensions/extensions.dart';
import 'facility_usage_filter.dart';
import 'product_variant_usage_filter.dart';

class FunctionRegistries {
  final BuildContext context;

  FunctionRegistries(this.context);

  void registerAll() {
    _registerGenerateFunctions();
    _registerInventoryFunctions();
    _registerTransactionFunctions();
    _registerFacilityFunctions();
    _registerStockFunctions();
    _registerItnFunctions();
    _registerViewTransactionFunctions();
  }

  void _registerGenerateFunctions() {
    FunctionRegistry.register('generateUniqueMaterialNoteNumber',
        (args, stateData) {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      String userUuid = context.loggedInUserUuid;
      String combinedId = '$userUuid$timestamp';
      List<int> bytes = utf8.encode(combinedId);
      Digest sha256Hash = sha256.convert(bytes);
      String hashString = sha256Hash.toString();
      String uniqueId = hashString.substring(0, 12).toUpperCase();
      String formattedUniqueId = uniqueId.replaceAllMapped(
        RegExp(r'.{1,4}'),
        (match) => '${match.group(0)}-',
      );
      formattedUniqueId =
          formattedUniqueId.substring(0, formattedUniqueId.length - 1);
      if (kDebugMode) {
        print('uniqueId : $formattedUniqueId');
      }
      return formattedUniqueId;
    });
  }

  void _registerInventoryFunctions() {
    FunctionRegistry.register('getQuantityLabel', (args, stateData) {
      if (args.isEmpty) return 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL';
      final sku = args.first?.toString() ?? '';
      if (sku.trim().toString() == 'SPAQ - 250 mg' ||
          sku.trim().toString() == 'SPAQ - 500 mg') {
        return 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL';
      }
      return 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL';
    });

    FunctionRegistry.register('getStockQuantityLabel', (args, stateData) {
      if (args.isEmpty) return 'APPONE_INVENTORY_QUANTITY_LABEL';
      final stockEntryType = args.first?.toString().toUpperCase() ?? '';
      const labels = {
        'RECEIPT': 'APPONE_INVENTORY_QUANTITY_RECEIVED_LABEL',
        'RETURNED': 'APPONE_INVENTORY_QUANTITY_RETURNED_LABEL',
        'ISSUED': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
        'DISPATCH': 'APPONE_INVENTORY_QUANTITY_SENT_LABEL',
        'LOSS': 'APPONE_INVENTORY_QUANTITY_LOST_LABEL',
        'DAMAGED': 'APPONE_INVENTORY_QUANTITY_DAMAGED_LABEL'
      };
      return labels[stockEntryType] ?? 'APPONE_INVENTORY_QUANTITY_LABEL';
    });

    FunctionRegistry.register('getReportTitle', (args, stateData) {
      if (args.isEmpty) return '';
      final reportType = args.first?.toString() ?? '';
      const titles = {
        'receipt': 'INVENTORY_REPORT_DETAILS_RECEIPT_REPORT_TITLE',
        'dispatch': 'INVENTORY_REPORT_DETAILS_DISPATCH_REPORT_TITLE',
        'returned': 'INVENTORY_REPORT_DETAILS_RETURNED_REPORT_TITLE',
        'damage': 'INVENTORY_REPORT_DETAILS_DAMAGE_REPORT_TITLE',
        'loss': 'INVENTORY_REPORT_DETAILS_LOSS_REPORT_TITLE',
        'reconciliation': 'INVENTORY_REPORT_DETAILS_RECONCILIATION_REPORT_TITLE'
      };
      return titles[reportType] ?? '';
    });

    FunctionRegistry.register('getTransactingPartyLabel', (args, stateData) {
      if (args.isEmpty) return '';
      final reportType = args.first?.toString() ?? '';
      const labels = {
        'receipt': 'INVENTORY_REPORT_DETAILS_RECEIPT_TRANSACTING_PARTY_LABEL',
        'dispatch': 'INVENTORY_REPORT_DETAILS_DISPATCH_TRANSACTING_PARTY_LABEL',
        'returned': 'INVENTORY_REPORT_DETAILS_RETURNED_TRANSACTING_PARTY_LABEL',
        'damage': 'INVENTORY_REPORT_DETAILS_DAMAGED_TRANSACTING_PARTY_LABEL',
        'loss': 'INVENTORY_REPORT_DETAILS_LOSS_TRANSACTING_PARTY_LABEL'
      };
      return labels[reportType] ?? '';
    });

    FunctionRegistry.register('getTransactingParty', (args, stateData) {
      if (args.length < 2) return '';
      final reportType = args[0]?.toString() ?? '';
      final item = args[1];
      if (item == null) return '';
      if (reportType == 'dispatch') {
        return item['receiverId']?.toString() ??
            item['receiverType']?.toString() ??
            '';
      }
      return item['senderId']?.toString() ??
          item['senderType']?.toString() ??
          '';
    });
  }

  void _registerTransactionFunctions() {
    FunctionRegistry.register('getTransactionType', (args, stateData) {
      if (args.isEmpty) return [];
      final reportType = args.first?.toString() ?? '';
      const types = {
        'receipt': ['RECEIVED'],
        'dispatch': ['DISPATCHED'],
        'returned': ['RECEIVED'],
        'damage': ['DISPATCHED'],
        'loss': ['DISPATCHED']
      };
      return types[reportType] ?? [];
    });

    FunctionRegistry.register('getTransactionReason', (args, stateData) {
      if (args.isEmpty) return [];
      final reportType = args.first?.toString() ?? '';
      const reasons = {
        'receipt': ['RECEIVED'],
        'dispatch': [],
        'returned': ['RETURNED'],
        'damage': ['DAMAGED_IN_STORAGE', 'DAMAGED_IN_TRANSIT'],
        'loss': ['LOST_IN_STORAGE', 'LOST_IN_TRANSIT']
      };
      return reasons[reportType] ?? [];
    });

    FunctionRegistry.register('getStockEntryType', (args, stateData) {
      // Try to get reportType from navigation params first
      final context = FunctionRegistry.context;
      if (context != null) {
        final compositeKey = getCompositeKey(context);
        final navigationParams = compositeKey != null
            ? FlowCrudStateRegistry().getNavigationParams(compositeKey)
            : null;
        if (navigationParams != null &&
            navigationParams['reportType'] != null) {
          final reportType = navigationParams['reportType'].toString();
          const entryTypes = {
            'receipt': 'ISSUED',
            'dispatch': 'ISSUED',
            'returned': 'RETURNED',
            'damage': 'DAMAGED',
            'loss': 'LOSS',
            'excess': 'EXCESS',
            'less': 'LESS',
          };
          return entryTypes[reportType] ?? '';
        }
      }
    });

    FunctionRegistry.register('getSenderOrReceiver', (args, stateData) {
      // Try to get reportType from navigation params first
      final context = FunctionRegistry.context;
      if (context != null) {
        final compositeKey = getCompositeKey(context);
        final navigationParams = compositeKey != null
            ? FlowCrudStateRegistry().getNavigationParams(compositeKey)
            : null;
        if (navigationParams != null &&
            navigationParams['reportType'] != null) {
          final reportType = navigationParams['reportType'].toString();
          const senderTypes = {
            'dispatch',
            'damage',
            'loss',
            'returned',
            'less',
            'excess'
          };
          return senderTypes.contains(reportType) ? 'senderId' : 'receiverId';
        }
      }
    });

    FunctionRegistry.register('sortBy', (args, stateData) {
      if (args.isEmpty || args[0] is! List) return args.isEmpty ? [] : args[0];
      final list = List<dynamic>.from(args[0] as List);
      final field = args.length > 1 ? args[1]?.toString() ?? '' : '';
      final descending = args.length > 2 ? args[2]?.toString() != 'asc' : true;
      if (field.isEmpty) return list;

      dynamic getField(dynamic item) {
        if (item is Map) return item[field];
        if (item is EntityModel) return item.toMap()[field];
        return null;
      }

      list.sort((a, b) {
        final aVal = getField(a);
        final bVal = getField(b);
        int cmp;
        if (aVal is num && bVal is num) {
          cmp = aVal.compareTo(bVal);
        } else if (aVal == null && bVal == null) {
          cmp = 0;
        } else if (aVal == null) {
          cmp = -1;
        } else if (bVal == null) {
          cmp = 1;
        } else {
          cmp = aVal.toString().compareTo(bVal.toString());
        }
        return descending ? -cmp : cmp;
      });
      return list;
    });

    FunctionRegistry.register('getAuditFilterKey', (args, stateData) {
      if (args.isEmpty) return 'clientCreatedBy';
      final reportType = args.first?.toString() ?? '';
      return reportType == 'receipt' ? 'clientModifiedBy' : 'clientCreatedBy';
    });

    FunctionRegistry.register('getSecondaryType', (args, stateData) {
      if (args.isEmpty) return 'WAREHOUSE';
      final facilityFromWhich = args.first?.toString() ?? '';
      return facilityFromWhich == 'DELIVERY_TEAM' ? 'STAFF' : 'WAREHOUSE';
    });

    FunctionRegistry.register('getTransactionStatusType', (args, stateData) {
      if (args.isEmpty) return 'default';
      final transactionType = args.first?.toString().toUpperCase() ?? '';
      switch (transactionType) {
        case 'DISPATCHED':
          return 'warning';
        case 'RECEIVED':
          return 'success';
        case 'RETURNED':
          return 'info';
        case 'DAMAGED':
        case 'LOSS':
          return 'error';
        default:
          return 'default';
      }
    });
  }

  void _registerFacilityFunctions() {
    FacilityUsageResolution issuedSourceUsageResolution() {
      final roles = context.loggedInUserRoles;
      final isWarehouseManager = roles.any(
        (role) => role.code == RolesType.warehouseManager.toValue(),
      );
      final isHfs = roles.any(
        (role) =>
            role.code == RolesType.healthFacilitySupervisor.toValue() ||
            role.code == RolesType.healthFacilityWorker.toValue(),
      );

      return resolveFacilityUsageForInventory(
        stockEntryType: 'ISSUED',
        transactionType: 'DISPATCHED',
        isToField: false,
        isFromField: true,
        boundaryType: context.selectedProject.address?.boundaryType,
        isWareHouseMgr: isWarehouseManager,
        isDistributor: false,
        isCommunityDistributor: false,
        isHfs: isHfs,
      );
    }

    String? mapFacilityUsage(dynamic facility) {
      if (facility is FacilityModel) return facility.usage;
      if (facility is Map) return facility['usage']?.toString();
      return null;
    }

    String? mapFacilityId(dynamic facility) {
      if (facility is FacilityModel) return facility.id;
      if (facility is Map) return facility['id']?.toString();
      return null;
    }

    String? mapProjectFacilityId(dynamic projectFacility) {
      if (projectFacility is ProjectFacilityModel) {
        return projectFacility.facilityId;
      }
      if (projectFacility is Map) {
        return projectFacility['facilityId']?.toString();
      }
      return null;
    }

    bool isCurrentProjectFacility(dynamic projectFacility) {
      if (projectFacility is ProjectFacilityModel) {
        final facilityLevel = projectFacility.additionalFields?.fields
            .where((f) => f.key == 'facilityLevel')
            .firstOrNull
            ?.value;
        return facilityLevel == null || facilityLevel == 'current';
      }
      if (projectFacility is! Map) return false;
      final additionalFields =
          projectFacility['additionalFields'] as Map<String, dynamic>?;
      if (additionalFields == null) return true;
      final fields = additionalFields['fields'] as List?;
      if (fields == null) return true;
      for (final field in fields) {
        if (field is Map && field['key'] == 'facilityLevel') {
          final value = field['value'];
          return value == null || value == 'current';
        }
      }
      return true;
    }

    FunctionRegistry.register('getUsageFilteredReportFacilities',
        (args, stateData) {
      try {
        final projectFacilities =
            args.isNotEmpty ? args[0] as List<dynamic>? : null;
        final facilities = args.length > 1 ? args[1] as List<dynamic>? : null;
        if (projectFacilities == null ||
            projectFacilities.isEmpty ||
            facilities == null ||
            facilities.isEmpty) {
          return <dynamic>[];
        }

        final usageResolution = issuedSourceUsageResolution();
        final primaryUsage = usageResolution.usage.trim();
        final additionalUsage = usageResolution.additionalUsage?.trim();
        if (primaryUsage.isEmpty) {
          return projectFacilities.where(isCurrentProjectFacility).toList();
        }
        if (primaryUsage == 'None') return <dynamic>[];

        final allowedFacilityIds = facilities
            .where((facility) {
              final usage = (mapFacilityUsage(facility) ?? '').trim();
              return usage == primaryUsage ||
                  (additionalUsage != null &&
                      additionalUsage.isNotEmpty &&
                      usage == additionalUsage);
            })
            .map(mapFacilityId)
            .whereType<String>()
            .toSet();

        return projectFacilities
            .where(isCurrentProjectFacility)
            .where((projectFacility) {
          final facilityId = mapProjectFacilityId(projectFacility);
          return facilityId != null && allowedFacilityIds.contains(facilityId);
        }).toList();
      } catch (e) {
        debugPrint('getUsageFilteredReportFacilities error: $e');
        return <dynamic>[];
      }
    });

    FunctionRegistry.register('getUsageFilteredReportProductVariants',
        (args, stateData) {
      try {
        final productVariants =
            args.isNotEmpty ? args[0] as List<dynamic>? : null;
        if (productVariants == null || productVariants.isEmpty) {
          return <dynamic>[];
        }

        final usage = issuedSourceUsageResolution().usage;
        return productVariants.where((variant) {
          final product = variant is ProductVariantModel
              ? variant
              : ProductVariantModelMapper.fromMap(
                  variant as Map<String, dynamic>,
                );
          return ProductVariantUsageFilter.matchesUsage(product, usage);
        }).toList();
      } catch (e) {
        debugPrint('getUsageFilteredReportProductVariants error: $e');
        return <dynamic>[];
      }
    });

    FunctionRegistry.register('getUserFacilityId', (args, stateData) {
      final isDistributor = context.loggedInUserRoles
          .where((role) => role.code == RolesType.distributor.toValue())
          .toList()
          .isNotEmpty;
      final isWareHouseMgr = context.loggedInUserRoles
          .where((role) => role.code == RolesType.warehouseManager.toValue())
          .toList()
          .isNotEmpty;
      if (isDistributor && !isWareHouseMgr) {
        return context.loggedInUserUuid ?? '';
      }
      try {
        List<Map<String, dynamic>>? projectFacilities;
        if (stateData?.modelMap != null) {
          projectFacilities = stateData!.modelMap['ProjectFacilityModel'];
        }
        if (projectFacilities == null || projectFacilities.isEmpty) {
          final manageStockState = FlowCrudStateRegistry().get('manageStock');
          final base = manageStockState?.base;
          if (base is CrudStateLoaded) {
            final pfModels = base.results['projectFacility'];
            if (pfModels != null && pfModels.isNotEmpty) {
              projectFacilities = pfModels
                  .whereType<ProjectFacilityModel>()
                  .map((pf) => <String, dynamic>{
                        'facilityId': pf.facilityId,
                      })
                  .toList();
            }
          }
        }
        if (projectFacilities == null || projectFacilities.isEmpty) {
          return '';
        }
        for (var facility in projectFacilities) {
          final facilityId = facility['facilityId']?.toString() ?? '';
          if (facilityId.isNotEmpty) {
            return facilityId;
          }
        }
        return '';
      } catch (e) {
        debugPrint('getUserFacilityId error: $e');
        return '';
      }
    });

    FunctionRegistry.register('getProjectFacilities', (args, stateData) {
      try {
        List<Map<String, dynamic>>? projectFacilities;
        if (stateData?.modelMap != null) {
          projectFacilities = stateData!.modelMap['ProjectFacilityModel'];
        }
        if (projectFacilities == null || projectFacilities.isEmpty) {
          final manageStockState = FlowCrudStateRegistry().get('manageStock');
          final base = manageStockState?.base;
          if (base is CrudStateLoaded) {
            final pfModels = base.results['projectFacility'];
            if (pfModels != null && pfModels.isNotEmpty) {
              projectFacilities = pfModels
                  .whereType<ProjectFacilityModel>()
                  .where((pf) {
                    final facilityLevel = pf.additionalFields?.fields
                        .where((f) => f.key == 'facilityLevel')
                        .firstOrNull
                        ?.value;
                    return facilityLevel == null || facilityLevel == 'current';
                  })
                  .map((pf) => <String, dynamic>{
                        'facilityId': pf.facilityId,
                      })
                  .toList();
            }
          }
        }
        if (projectFacilities == null || projectFacilities.isEmpty) {
          return <Map<String, dynamic>>[];
        }
        final filtered = projectFacilities.where((pf) {
          final additionalFields =
              pf['additionalFields'] as Map<String, dynamic>?;
          if (additionalFields == null) return true;
          final fields = additionalFields['fields'] as List?;
          if (fields == null) return true;
          for (final field in fields) {
            if (field is Map &&
                field['key'] == 'facilityLevel' &&
                field['value'] != null) {
              return field['value'] == 'current';
            }
          }
          return true;
        }).toList();
        return filtered
            .map((pf) => {
                  'code': pf['facilityId']?.toString() ?? '',
                  'name': 'FAC_${pf['facilityId']?.toString() ?? ''}',
                })
            .where((item) => item['code']!.isNotEmpty)
            .toList();
      } catch (e) {
        debugPrint('getProjectFacilities error: $e');
        return <Map<String, dynamic>>[];
      }
    });

    FunctionRegistry.register('getProjectProductVariantIds', (args, stateData) {
      try {
        List<Map<String, dynamic>>? productVariants;
        if (stateData?.modelMap != null) {
          productVariants = stateData!.modelMap['ProductVariantModel'];
        }
        if (productVariants == null || productVariants.isEmpty) {
          final manageStockState = FlowCrudStateRegistry().get('manageStock');
          final base = manageStockState?.base;
          if (base is CrudStateLoaded) {
            final pvModels = base.results['productVariant'];
            if (pvModels != null && pvModels.isNotEmpty) {
              productVariants = pvModels
                  .whereType<ProductVariantModel>()
                  .map((pv) => <String, dynamic>{'id': pv.id})
                  .toList();
            }
          }
        }
        if (productVariants == null || productVariants.isEmpty) {
          return '';
        }
        return productVariants
            .map((pv) => pv['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .join(',');
      } catch (e) {
        debugPrint('getProjectProductVariantIds error: $e');
        return '';
      }
    });

    FunctionRegistry.register('getCurrentFacilities', (args, stateData) {
      try {
        List<dynamic>? projectFacilities;

        if (args.isNotEmpty && args.first != null) {
          projectFacilities = args.first as List<dynamic>?;
        }

        if (projectFacilities == null || projectFacilities.isEmpty) {
          return <Map<String, dynamic>>[];
        }

        final currentFacilities = projectFacilities.where((pf) {
          if (pf is! Map) return false;
          final additionalFields =
              pf['additionalFields'] as Map<String, dynamic>?;
          if (additionalFields == null) return true;
          final fields = additionalFields['fields'] as List?;
          if (fields == null) return true;
          for (final field in fields) {
            if (field is Map && field['key'] == 'facilityLevel') {
              final value = field['value'];
              return value == null || value == 'current';
            }
          }
          return true;
        }).toList();

        return currentFacilities;
      } catch (e) {
        debugPrint('getCurrentFacilities error: $e');
        return <Map<String, dynamic>>[];
      }
    });

    FunctionRegistry.register('getFacilityName', (args, stateData) {
      if (args.isEmpty) return '';
      final facilityId = args.first?.toString() ?? '';
      if (facilityId.isEmpty) return '';
      return facilityId.contains('F') ? 'FAC_$facilityId' : facilityId;
    });

    FunctionRegistry.register('hasResults', (args, stateData) {
      if (args.isEmpty) return false;
      final modelKey = args.first?.toString() ?? '';
      if (modelKey.isEmpty || stateData?.modelMap == null) return false;
      final results = stateData!.modelMap[modelKey];
      return results != null && results.isNotEmpty;
    });
  }

  void _registerStockFunctions() {
    FunctionRegistry.register('hasStockForDelivery', (args, stateData) {
      if (args.isEmpty) return true;
      final eligibleProducts = args.first;
      if (eligibleProducts == null) return true;
      List<dynamic> productList = [];
      if (eligibleProducts is List) {
        productList = eligibleProducts;
      } else if (eligibleProducts is Map) {
        productList = [eligibleProducts];
      }
      if (productList.isEmpty) return true;
      final cache = StockBalanceCache.instance;
      if (cache.facilityId.isEmpty) return true;
      final List<Map<String, dynamic>> insufficientProducts = [];
      for (final product in productList) {
        if (product is! Map) continue;
        final productVariantsList = product['ProductVariants'];
        if (productVariantsList is! List) continue;
        for (final variant in productVariantsList) {
          if (variant is! Map) continue;
          final productId = variant['productVariantId']?.toString();
          final productName =
              variant['name']?.toString() ?? productId ?? 'Unknown';
          if (productId == null || productId.isEmpty) continue;
          final quantity =
              double.tryParse(variant['quantity']?.toString() ?? '1') ?? 1.0;
          final key = productId;
          final balance = cache.cache[key] ?? 0.0;
          if (balance < quantity) {
            insufficientProducts.add({
              'name': productName,
              'required': quantity,
              'available': balance,
            });
          }
        }
      }
      if (insufficientProducts.isEmpty) {
        cache.setStockCheckResult(null);
        return true;
      }
      cache.setStockCheckResult({
        'key': 'INSUFFICIENT_STOCK',
        'products': insufficientProducts,
      });
      return false;
    });

    FunctionRegistry.register('getInsufficientStockMessage', (args, stateData) {
      final result = StockBalanceCache.instance.stockCheckResult;
      if (result is Map) {
        final key = result['key'] as String?;
        final products = result['products'] as List?;
        if (key == 'INSUFFICIENT_STOCK' && products != null) {
          String message = '';
          for (int i = 0; i < products.length; i++) {
            final p = products[i] as Map<String, dynamic>;
            final name = p['name'] ?? 'Unknown';
            final required = p['required'] ?? 0;
            final available = p['available'] ?? 0;
            message += '\n$name: $required REQUIRED, $available AVAILABLE';
          }
          return '$key$message';
        }
      }
      return '';
    });
  }

  void _registerViewTransactionFunctions() {
    String getStockEntryTypeFromFields(dynamic fields) {
      if (fields == null) return '';
      if (fields is List) {
        for (var field in fields) {
          if (field is Map && field['key'] == 'stockEntryType') {
            return field['value']?.toString().toUpperCase() ?? '';
          }
        }
      }
      return '';
    }

    FunctionRegistry.register('getFirstPagePartyLabel', (args, stateData) {
      if (args.isEmpty) return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      final stockEntryType = getStockEntryTypeFromFields(args.first);
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          return 'INVENTORY_SENDER_LABEL';
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          return 'INVENTORY_RECEIVER_LABEL';
        default:
          return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      }
    });

    FunctionRegistry.register('getFirstPageParty', (args, stateData) {
      if (args.length < 3) return '';
      final stockEntryType = getStockEntryTypeFromFields(args[0]);
      final senderId = args[1]?.toString() ?? '';
      final receiverId = args[2]?.toString() ?? '';
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          return senderId;
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          return receiverId;
        default:
          return senderId;
      }
    });

    FunctionRegistry.register('getSecondPagePartyLabel', (args, stateData) {
      if (args.isEmpty) return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      final stockEntryType = getStockEntryTypeFromFields(args.first);
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          return 'INVENTORY_RECEIVER_LABEL';
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          return 'INVENTORY_SENDER_LABEL';
        default:
          return 'INVENTORY_TRANSACTING_PARTY_LABEL';
      }
    });

    FunctionRegistry.register('getSecondPageParty', (args, stateData) {
      if (args.length < 3) return '';
      final stockEntryType = getStockEntryTypeFromFields(args[0]);
      final senderId = args[1]?.toString() ?? '';
      final receiverId = args[2]?.toString() ?? '';
      switch (stockEntryType) {
        case 'RECEIPT':
        case 'RETURNED':
          return receiverId;
        case 'ISSUED':
        case 'DAMAGED':
        case 'LOSS':
          return senderId;
        default:
          return receiverId;
      }
    });
  }

  void _registerItnFunctions() {
    FunctionRegistry.register('isSmcPresent', (args, stateData) {
      final project = FlowBuilderSingleton().selectedProject;
      if (project == null) return false;
      final primary = project.additionalDetails?.projectType?.type;
      final additional = project.additionalDetails?.additionalProjectType?.type;
      return primary == null || primary == 'SMC_ITN' || additional == 'SMC_ITN';
      // return true;
    });

    FunctionRegistry.register('calculateItnCount', (args, stateData) {
      final memberCount = int.tryParse(args.first?.toString() ?? '') ?? 0;
      if (memberCount <= 0) return 0;
      return min(4, (memberCount / 2).ceil());
    });

    FunctionRegistry.register('getEToken', (args, stateData) {
      if (args.isEmpty) return null;
      final individual = args.first;
      if (individual == null) return null;

      final List<IdentifierModel>? identifiers;
      if (individual is IndividualModel) {
        identifiers = individual.identifiers;
      } else if (individual is Map) {
        final List? rawIds = individual['identifiers'];
        identifiers = rawIds?.map((id) {
          if (id is IdentifierModel) return id;
          return IdentifierModelMapper.fromMap(Map<String, dynamic>.from(id));
        }).toList();
      } else {
        identifiers = null;
      }

      if (identifiers == null) return null;

      return identifiers
          .firstWhereOrNull((id) => id.identifierType == 'E_TOKEN')
          ?.identifierId;
    });

    FunctionRegistry.register('getBeneficiaryId', (args, stateData) {
      if (args.isEmpty) return null;
      var individual = args.first;
      if (individual == null) return null;

      if (individual is List) {
        individual = individual.firstWhereOrNull((e) =>
            e is IndividualModel ||
            (e is Map && e['__type'] == 'IndividualModel'));
      }

      if (individual == null) return null;

      final List<IdentifierModel>? identifiers;
      if (individual is IndividualModel) {
        identifiers = individual.identifiers;
      } else if (individual is Map) {
        final List? rawIds = individual['identifiers'];
        identifiers = rawIds?.map((id) {
          if (id is IdentifierModel) return id;
          return IdentifierModelMapper.fromMap(Map<String, dynamic>.from(id));
        }).toList();
      } else {
        identifiers = null;
      }

      if (identifiers == null) return null;

      return identifiers
          .firstWhereOrNull(
              (id) => id.identifierType == 'UNIQUE_BENEFICIARY_ID')
          ?.identifierId;
    });

    FunctionRegistry.register('getBeneficiaryName', (args, stateData) {
      if (args.isEmpty) return null;
      var individual = args.first;
      if (individual == null) return null;

      if (individual is List) {
        individual = individual.firstWhereOrNull((e) =>
            e is IndividualModel ||
            (e is Map && e['__type'] == 'IndividualModel'));
      }

      if (individual == null) return null;

      if (individual is IndividualModel) {
        return '${individual.name?.givenName ?? ''} ${individual.name?.familyName ?? ''}'
            .trim();
      } else if (individual is Map) {
        final name = individual['name'];
        if (name != null) {
          return '${name['givenName'] ?? ''} ${name['familyName'] ?? ''}'
              .trim();
        }
      }

      return null;
    });

    FunctionRegistry.register('isItnDelivered', (args, stateData) {
      if (args.isEmpty) return false;
      final tasks = args.first;
      if (tasks == null) return false;
      final rawList = tasks is List ? tasks : [tasks];

      // item.task may contain TaskModel objects — convert to Map following isRedoseCompleted pattern
      final taskList = rawList.map<Map<String, dynamic>>((item) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
        try {
          // ignore: avoid_dynamic_calls
          return (item as dynamic).toMap() as Map<String, dynamic>;
        } catch (_) {
          try {
            // ignore: avoid_dynamic_calls
            return (item as dynamic).toJson() as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        }
      }).toList();

      for (final task in taskList) {
        final additionalFields = task['additionalFields'];
        final fields = additionalFields is Map
            ? additionalFields['fields'] as List?
            : additionalFields is List
                ? additionalFields
                : null;
        if (fields == null) continue;
        for (final field in fields) {
          if (field is Map &&
              field['key'] == 'taskType' &&
              field['value'] == 'ITN_DELIVERY') {
            return true;
          }
        }
      }
      return false;
    });

    FunctionRegistry.register('allMembersHaveSmcTasks', (args, stateData) {
      // args[0]: head's projectBeneficiaryClientReferenceId (to exclude head's tasks)
      final headPbRef = args.first;
      final headHfRef = args[1];

      // Read childrenCount from HouseholdModel's additionalFields
      // (childrenCount is not a direct HouseholdModel property, so it lives in additionalFields.fields)
      int childrenCount = 0;
      outer:
      for (final list in stateData.modelMap.values) {
        for (final map in list) {
          if (!map.containsKey('memberCount'))
            continue; // HouseholdModel has memberCount
          final additionalFields = map['additionalFields'];
          final fields = additionalFields is Map
              ? additionalFields['fields'] as List?
              : additionalFields is List
                  ? additionalFields
                  : null;
          if (fields == null) continue;
          for (final field in fields) {
            if (field is Map && field['key'] == 'childrenCount') {
              childrenCount =
                  int.tryParse(field['value']?.toString() ?? '') ?? 0;
              break outer;
            }
          }
        }
      }

      if (childrenCount <= 0) return true;

      // Flatten all modelMap entries and filter by the task-identifying field,
      // avoiding dependence on a specific key name that varies across flows
      final allTasks = stateData.modelMap.values
          .expand((list) => list)
          .where(
              (map) => map.containsKey('projectBeneficiaryClientReferenceId'))
          .toList();

      // Count distinct non-head members with ANY task (SMC, Unable to Deliver, etc.)
      final Set<String> nonHeadWithAnyTask = {};
      for (final task in allTasks) {
        final pbRef = task['projectBeneficiaryClientReferenceId']?.toString();
        if (pbRef == null || pbRef.isEmpty) continue;
        if (headPbRef != null && pbRef == headPbRef) continue;
        nonHeadWithAnyTask.add(pbRef);
      }

      // Also check for hfReferral (for beneficiaryReferred cases where referral is created instead of task)
      final hfReferrals = stateData.modelMap.values
          .expand((list) => list)
          .where((map) => map.containsKey('referralCode'))
          .toList();

      for (final referral in hfReferrals) {
        final pbRef = referral['referralCode']?.toString();
        if (pbRef == null || pbRef.isEmpty) continue;
        if (headHfRef != null && pbRef == headHfRef) continue;
        nonHeadWithAnyTask.add(pbRef);
      }

      return nonHeadWithAnyTask.length >= childrenCount;
    });

    FunctionRegistry.register('getNonHeadWithAnyTaskCount', (args, stateData) {
      // args[0]: head's projectBeneficiaryClientReferenceId (to exclude head's tasks)
      // args[1]: head's beneficiaryClientReferenceId (for hfReferral matching)
      // args[2]: contextData (optional, used when stateData is not available)
      // args[3]: item (optional, the current item being processed)

      final headPbRef = args.first;
      final headHfRef = args[1];
      final contextData = args[2];

      // Use stateData if available, otherwise extract from contextData/item
      Map<String, dynamic> modelMap;

      if (stateData.modelMap.isNotEmpty) {
        modelMap = stateData.modelMap;
      } else if (contextData != null) {
        // Extract modelMap from contextData structure
        // contextData has structure with household, members, etc.
        modelMap = {};

        // Add household
        if (contextData is Map && contextData['household'] != null) {
          final household = contextData['household'];
          if (household is List && household.isNotEmpty) {
            modelMap['HouseholdModel'] = household;
          }
        }

        // Add members
        if (contextData is Map && contextData['members'] != null) {
          final members = contextData['members'];
          if (members is List) {
            modelMap['HouseholdMemberModel'] = members;
          }
        }

        // Add tasks from members
        if (contextData is Map && contextData['members'] != null) {
          final members = contextData['members'];
          if (members is List) {
            final tasks = <Map<String, dynamic>>[];
            for (final member in members) {
              if (member is! Map) continue;
              final memberMap = member as Map<String, dynamic>;
              if (memberMap['task'] != null) {
                final task = memberMap['task'];
                if (task is List && task.isNotEmpty) {
                  for (final t in task) {
                    Map<String, dynamic>? taskMap;
                    if (t is Map<String, dynamic>) {
                      taskMap = t;
                    } else {
                      try {
                        taskMap =
                            (t as dynamic).toMap() as Map<String, dynamic>;
                      } catch (_) {
                        continue;
                      }
                    }
                    tasks.add(taskMap);
                  }
                }
              }
            }
            if (tasks.isNotEmpty) {
              modelMap['TaskModel'] = tasks;
            }
          }
        }

        // Add hfReferrals from members
        if (contextData is Map && contextData['members'] != null) {
          final members = contextData['members'];
          if (members is List) {
            final referrals = <Map<String, dynamic>>[];
            for (final member in members) {
              if (member is! Map) continue;
              final memberMap = member as Map<String, dynamic>;
              if (memberMap['hFReferral'] != null) {
                final referral = memberMap['hFReferral'];
                if (referral is List && referral.isNotEmpty) {
                  for (final r in referral) {
                    Map<String, dynamic>? referralMap;
                    if (r is Map<String, dynamic>) {
                      referralMap = r;
                    } else {
                      try {
                        referralMap =
                            (r as dynamic).toMap() as Map<String, dynamic>;
                      } catch (_) {
                        continue;
                      }
                    }
                    referrals.add(referralMap);
                  }
                }
              }
            }
            if (referrals.isNotEmpty) {
              modelMap['HFReferralModel'] = referrals;
            }
          }
        }
      } else {
        modelMap = {};
      }

      // Flatten all modelMap entries and filter by the task-identifying field
      final allTasks = modelMap.values
          .expand((list) => list)
          .whereType<Map<String, dynamic>>()
          .where(
              (map) => map.containsKey('projectBeneficiaryClientReferenceId'))
          .toList();

      // Count distinct non-head members with ANY task (SMC, Unable to Deliver, etc.)
      final Set<String> nonHeadWithAnyTask = {};
      for (final task in allTasks) {
        final pbRef = task['projectBeneficiaryClientReferenceId']?.toString();
        if (pbRef == null || pbRef.isEmpty) continue;
        if (headPbRef != null && pbRef == headPbRef) continue;
        nonHeadWithAnyTask.add(pbRef);
      }

      // Also check for hfReferral (for beneficiaryReferred cases where referral is created instead of task)
      final hfReferrals = modelMap.values
          .expand((list) => list)
          .whereType<Map<String, dynamic>>()
          .where((map) => map.containsKey('referralCode'))
          .toList();

      for (final referral in hfReferrals) {
        final pbRef = referral['referralCode']?.toString();
        if (pbRef == null || pbRef.isEmpty) continue;
        if (headHfRef != null && pbRef == headHfRef) continue;
        nonHeadWithAnyTask.add(pbRef);
      }

      return nonHeadWithAnyTask.length;
    });

    FunctionRegistry.register('getChildrenCount', (args, stateData) {
      // args[0]: contextData (optional, used when stateData is not available)
      final contextData = args.isNotEmpty ? args.first : null;

      int childrenCount = 0;

      // Use stateData if available, otherwise extract from contextData
      if (stateData.modelMap.isNotEmpty) {
        outer:
        for (final list in stateData.modelMap.values) {
          for (final map in list) {
            if (!map.containsKey('memberCount')) {
              continue; // HouseholdModel has memberCount
            }
            final additionalFields = map['additionalFields'];
            final fields = additionalFields is Map
                ? additionalFields['fields'] as List?
                : additionalFields is List
                    ? additionalFields
                    : null;
            if (fields == null) continue;
            for (final field in fields) {
              if (field is Map && field['key'] == 'childrenCount') {
                childrenCount =
                    int.tryParse(field['value']?.toString() ?? '') ?? 0;
                break outer;
              }
            }
          }
        }
      } else if (contextData != null) {
        // Extract childrenCount from contextData structure
        dynamic household;
        if (contextData is Map) {
          household = contextData['household'];
          if (household is List && household.isNotEmpty) {
            household = household.first;
          }
        }

        if (household != null) {
          Map<String, dynamic>? householdMap;
          if (household is Map) {
            householdMap = Map<String, dynamic>.from(household);
          } else {
            try {
              householdMap =
                  (household as dynamic).toMap() as Map<String, dynamic>?;
            } catch (_) {
              householdMap = null;
            }
          }

          if (householdMap != null) {
            final additionalFields = householdMap['additionalFields'];
            final fields = additionalFields is Map
                ? additionalFields['fields'] as List?
                : additionalFields is List
                    ? additionalFields
                    : null;

            if (fields != null) {
              for (final field in fields) {
                if (field is Map && field['key'] == 'childrenCount') {
                  childrenCount =
                      int.tryParse(field['value']?.toString() ?? '') ?? 0;
                  break;
                }
              }
            }
          }
        }
      }

      return childrenCount;
    });

    FunctionRegistry.register('isChildSmcRemaining', (args, stateData) {
      // args[0]: childrenCount
      // args[1]: nonHeadWithAnyTaskLength
      final childrenCount = int.tryParse(args[0]?.toString() ?? '') ?? 0;
      final nonHeadWithAnyTaskLength =
          int.tryParse(args[1]?.toString() ?? '') ?? 0;

      // Check if nonHeadWithAnyTaskLength + 1 >= childrenCount
      return (nonHeadWithAnyTaskLength + 1) < childrenCount;
    });

    FunctionRegistry.register('hasStockForItnDelivery', (args, stateData) {
      if (args.length < 2) return true;
      final memberCount = int.tryParse(args[0]?.toString() ?? '') ?? 0;
      final eligibleProducts = args[1];
      if (eligibleProducts == null) return true;
      final required = min(4, (memberCount / 2).ceil()).toDouble();

      // Validate that required quantity is greater than 0
      if (required <= 0) {
        final cache = StockBalanceCache.instance;
        cache.setStockCheckResult({
          'key': 'INVALID_QUANTITY',
          'message':
              'ITN count must be greater than 0. Household member count: $memberCount',
        });
        return false;
      }

      List<dynamic> productList = [];
      if (eligibleProducts is List) {
        productList = eligibleProducts;
      } else if (eligibleProducts is Map) {
        productList = [eligibleProducts];
      }

      // Validate that eligibleProductVariants is not empty and contains valid productVariantId
      if (productList.isEmpty) {
        final cache = StockBalanceCache.instance;
        cache.setStockCheckResult({
          'key': 'NO_ELIGIBLE_PRODUCTS',
          'message': 'No eligible product variants found for ITN delivery',
        });
        return false;
      }

      bool hasValidProductVariant = false;
      for (final product in productList) {
        if (product is! Map) continue;
        final productVariantsList = product['ProductVariants'];
        if (productVariantsList is! List) continue;
        for (final variant in productVariantsList) {
          if (variant is! Map) continue;
          final productId = variant['productVariantId']?.toString();
          if (productId != null && productId.isNotEmpty) {
            hasValidProductVariant = true;
            break;
          }
        }
        if (hasValidProductVariant) break;
      }

      if (!hasValidProductVariant) {
        final cache = StockBalanceCache.instance;
        cache.setStockCheckResult({
          'key': 'NO_PRODUCT_VARIANT',
          'message': 'No valid product variant found in eligible products',
        });
        return false;
      }

      final cache = StockBalanceCache.instance;
      if (cache.facilityId.isEmpty) return true;
      final List<Map<String, dynamic>> insufficientProducts = [];
      for (final product in productList) {
        if (product is! Map) continue;
        final productVariantsList = product['ProductVariants'];
        if (productVariantsList is! List) continue;
        for (final variant in productVariantsList) {
          if (variant is! Map) continue;
          final productId = variant['productVariantId']?.toString();
          final productName =
              variant['name']?.toString() ?? productId ?? 'Unknown';
          if (productId == null || productId.isEmpty) continue;
          final balance = cache.cache[productId] ?? 0.0;
          if (balance < required) {
            insufficientProducts.add({
              'name': productName,
              'required': required,
              'available': balance,
            });
          }
        }
      }
      if (insufficientProducts.isEmpty) {
        cache.setStockCheckResult(null);
        return true;
      }
      cache.setStockCheckResult({
        'key': 'INSUFFICIENT_STOCK',
        'products': insufficientProducts,
      });
      return false;
    });

    FunctionRegistry.register('canAddMember', (args, stateData) {
      if (args.length < 2) return true;

      final additionalFieldsArg = args[0];
      final individualsArg = args[1];

      int childrenCount = 0;

      // Extract childrenCount from additionalFields
      if (additionalFieldsArg != null && additionalFieldsArg is Map) {
        final fields = additionalFieldsArg['fields'];
        if (fields != null && fields is List) {
          for (var field in fields) {
            if (field is Map && field['key'] == 'childrenCount') {
              childrenCount = int.tryParse(field['value'].toString()) ?? 0;
              break;
            }
          }
        }
      }

      // If childrenCount is 0 or negative, allow adding
      if (childrenCount <= 0) return false;

      // If individuals is null, allow adding
      if (individualsArg == null) return true;

      int addedIndividualsCount = 0;
      int addedChildrenCount = 0;

      if (individualsArg is List) {
        addedIndividualsCount = individualsArg.length;
        // Subtract 1 for the head member (head is not a child)
        addedChildrenCount =
            addedIndividualsCount > 0 ? addedIndividualsCount - 1 : 0;
      }

      if (kDebugMode) {
        print(
            'canAddMember - childrenCount: $childrenCount, addedIndividualsCount: $addedIndividualsCount, addedChildrenCount: $addedChildrenCount');
      }

      return addedChildrenCount < childrenCount;
    });

    FunctionRegistry.register("isHouseholdWithoutMembers", (args, stateData) {
      if (args.isEmpty || args.first == null) {
        return false;
      }

      final item = args.first;

      // Check if it's a Map (household object)
      if (item is! Map) {
        return false;
      }

      // Check if household exists
      final household = item['HouseholdModel'];
      if (household == null) {
        return false;
      }

      // Check if members count is 0
      final members = item['members'];
      final membersCount = members is List ? members.length : 0;

      // Check if individuals count is 0
      final individuals = item['individuals'];
      final individualsCount = individuals is List ? individuals.length : 0;

      // Check if projectBeneficiaries count is 0
      final projectBeneficiaries = item['projectBeneficiaries'];
      final projectBeneficiariesCount =
          projectBeneficiaries is List ? projectBeneficiaries.length : 0;

      // Return true if household exists but has no members, individuals, or projectBeneficiaries
      return membersCount == 0 &&
          individualsCount == 0 &&
          projectBeneficiariesCount == 0;
    });

    FunctionRegistry.register("checkIfClosedHousehold", (args, stateData) {
      if (args.isEmpty || args.first == null) {
        return false;
      }

      final status = args.first;
      return status == 'CLOSED_HOUSEHOLD';
    });

    FunctionRegistry.register("checkBeneficiaryAbsentOrRefused",
        (args, stateData) {
      if (args.isEmpty) return false;

      final tasks = args.first;
      if (tasks is! List || tasks.isEmpty) return false;

      final statusesToCheck = ['BENEFICIARY_REFUSED', 'BENEFICIARY_ABSENT'];

      TaskModel task = tasks.last;
      final status = task.status;
      if (status != null && statusesToCheck.contains(status)) {
        return true;
      }

      return false;
    });
  }
}

class StockBalanceCache {
  StockBalanceCache._();
  static final StockBalanceCache _instance = StockBalanceCache._();
  static StockBalanceCache get instance => _instance;

  String _facilityId = '';
  final Map<String, double> _cache = {};
  dynamic _stockCheckResult;

  String get facilityId => _facilityId;
  Map<String, double> get cache => _cache;
  dynamic get stockCheckResult => _stockCheckResult;

  void setCache(String facilityId, Map<String, double> cache) {
    _facilityId = facilityId;
    _cache.clear();
    _cache.addAll(cache);
    _stockCheckResult = null;
  }

  void setStockCheckResult(dynamic result) {
    _stockCheckResult = result;
  }

  void clear() {
    _facilityId = '';
    _cache.clear();
    _stockCheckResult = null;
  }
}

@Deprecated('Use StockBalanceCache.instance.setCache instead')
void setStockBalanceCache(String facilityId, Map<String, double> cache) {
  StockBalanceCache.instance.setCache(facilityId, cache);
}
