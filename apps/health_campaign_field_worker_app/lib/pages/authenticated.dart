import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:digit_data_model/models/entities/attendance_register.dart';
import 'package:digit_data_model/models/entities/attendee.dart';
import 'package:digit_face_verification/digit_face_verification.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/hf_referral.dart';
import 'package:digit_forms_engine/blocs/forms/forms.dart';
import 'package:digit_showcase/showcase_widget.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/component_utils.dart';
import 'package:digit_ui_components/widgets/atoms/digit_loader.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/helper_widget/digit_profile.dart';
import 'package:digit_ui_components/widgets/molecules/hamburger.dart';
import 'package:digit_ui_components/widgets/molecules/show_pop_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:isar/isar.dart';
import 'package:location/location.dart';
import '../services/location_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:survey_form/survey_form.dart';
import 'package:sync_service/sync_service_lib.dart';
import 'package:transit_post/data/repositories/local/user_action.dart';
import 'package:transit_post/data/repositories/remote/user_action.dart';

import '../blocs/app_initialization/app_initialization.dart';
import '../blocs/auth/auth.dart';
import '../blocs/face_auth/face_gate_bloc.dart';
import '../blocs/face_auth/reverification_bloc.dart';
import '../blocs/hf_referral_downsync/hf_referral_downsync.dart';
import '../blocs/localization/app_localization.dart';
import '../blocs/localization/localization.dart';
import '../blocs/projects_beneficiary_downsync/project_beneficiaries_downsync.dart';
import '../blocs/stock_downsync/stock_downsync.dart';
import '../data/local_store/no_sql/schema/service_registry.dart';
import '../data/local_store/secure_store/secure_store.dart';
import '../blocs/push_notification/push_notification.dart';
import '../data/local_store/app_shared_preferences.dart';
import '../data/local_store/no_sql/schema/app_configuration.dart';
import '../data/remote_client.dart';
import '../data/repositories/remote/bandwidth_check.dart';
import '../models/downsync/downsync.dart';
import '../models/entities/notification_data.dart';
import '../models/entities/roles_type.dart';
import '../notification_handlers/notification_handler.dart';
import '../notification_service.dart';
import '../router/app_router.dart';
import '../router/authenticated_route_observer.dart';
import '../services/face_auth_config.dart';
import '../services/reverification_scheduler.dart';
import '../services/worker_registry_service.dart';
import '../widgets/face_auth/face_verification_dialog.dart';
import '../widgets/face_auth/reverification_popup.dart';
import '../utils/analytics_sync_service.dart';
import '../utils/environment_config.dart';
import '../utils/i18_key_constants.dart' as i18;
import '../utils/utils.dart';
import '../widgets/error_screen.dart';
import 'error_boundary.dart';

@RoutePage()
class AuthenticatedPageWrapper extends StatefulWidget {
  const AuthenticatedPageWrapper({super.key});

  @override
  State<AuthenticatedPageWrapper> createState() =>
      _AuthenticatedPageWrapperState();
}

class _AuthenticatedPageWrapperState extends State<AuthenticatedPageWrapper>
    with WidgetsBindingObserver {
  final StreamController<bool> _drawerVisibilityController =
      StreamController.broadcast();
  StreamController<HFReferralProgressData> _hfReferralProgress =
      StreamController<HFReferralProgressData>.broadcast();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOfflineDialogShowing = false;
  bool _isPrivacyNoticeDialogShowing = false;

  // ── Face-auth / re-verification state ──
  FaceAuthConfig _faceAuthConfig = const FaceAuthConfig();
  bool _configFromRegister = false;
  bool _coWorkerEmbeddingsPrefetched = false;
  ReVerificationScheduler? _reVerificationScheduler;
  StreamSubscription<ReVerificationTrigger>? _reVerificationSubscription;
  StreamSubscription<ReVerificationState>? _reVerStateSubscription;
  ReVerificationBloc? _reVerificationBloc;
  // Held so we can push MDMS-derived threshold/maxAttempts into the live bloc
  // when config resolves AFTER the BlocProvider has created it.
  FaceGateBloc? _faceGateBloc;
  // Index of the trigger currently being prompted; cleared on terminal state.
  int? _activeTriggerIndex;
  final StreamController<List<DateTime>> _scheduleController =
      StreamController<List<DateTime>>.broadcast();
  final ValueNotifier<ReVerificationState?> _reVerStateNotifier =
      ValueNotifier(null);
  bool _lastEnrollmentActive = false;
  bool _lastConnectivityOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
    _startReVerificationScheduler();
    // When face enrollment finishes (notifier flips true → false) regenerate
    // the schedule so prompts are relative to enrollment end, not app launch.
    faceEnrollmentActiveNotifier.addListener(_onEnrollmentActiveChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPrivacyNoticeIfRequired();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    faceEnrollmentActiveNotifier.removeListener(_onEnrollmentActiveChanged);
    _reVerificationSubscription?.cancel();
    _reVerStateSubscription?.cancel();
    _reVerStateNotifier.dispose();
    _reVerificationScheduler?.dispose();
    _scheduleController.close();
    _connectivitySubscription.cancel();
    _drawerVisibilityController.close();
    _hfReferralProgress.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reVerificationScheduler?.checkNow();
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    final isOnline = result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.mobile);
    final isOffline = !isOnline;

    if (isOffline && !_isOfflineDialogShowing && mounted) {
      _showNoInternetDialog();
    } else if (!isOffline && _isOfflineDialogShowing && mounted) {
      _dismissNoInternetDialog();
    }

    if (isOnline) {
      unawaited(AnalyticsSyncService().flushPendingEvents());
      // Retry the worker-registry queue on every offline → online transition.
      if (!_lastConnectivityOnline && mounted) {
        debugPrint(
            'AuthenticatedPage: connectivity restored — retrying pending worker registry sync');
        _retryPendingWorkerRegistrySync();
      }
    }
    _lastConnectivityOnline = isOnline;
  }

  void _showNoInternetDialog() {
    _isOfflineDialogShowing = true;
    showCustomPopup(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Popup(
        title: AppLocalizations.of(context).translate(
          i18.common.connectionLabel,
        ),
        description: AppLocalizations.of(context).translate(
          i18.common.connectionContent,
        ),
        actions: [
          DigitButton(
            label: AppLocalizations.of(context).translate(
              i18.common.coreCommonOk,
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _isOfflineDialogShowing = false;
            },
            type: DigitButtonType.primary,
            size: DigitButtonSize.large,
          ),
        ],
      ),
    );
  }

  void _dismissNoInternetDialog() {
    if (_isOfflineDialogShowing) {
      Navigator.of(context, rootNavigator: true).pop();
      _isOfflineDialogShowing = false;
    }
  }

  void _onEnrollmentActiveChanged() async {
    final now = faceEnrollmentActiveNotifier.value;
    if (_lastEnrollmentActive == true && now == false) {
      try {
        await _reVerificationScheduler?.regenerate();
        if (mounted && _reVerificationScheduler != null) {
          _scheduleController.add(_reVerificationScheduler!.currentSchedule);
        }
      } catch (e) {
        debugPrint(
            'AuthenticatedPage: failed to regenerate schedule after enrollment: $e');
      }
    }
    _lastEnrollmentActive = now;
  }

  void _checkFaceEnrollment() {
    // Scheduler is started in initState; nothing to do here.
  }

  Future<void> _initConfigFromRegister() async {
    if (_configFromRegister) return;
    try {
      if (!mounted) return;
      final individualId = context.loggedInIndividualId;
      if (individualId == null) return;

      final registerRepo = context
          .repository<AttendanceRegisterModel, AttendanceRegisterSearchModel>();
      final now = DateTime.now();
      final registers = await registerRepo
          .search(AttendanceRegisterSearchModel(attendeeId: individualId));
      if (!mounted) return;

      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd = todayStart + const Duration(days: 1).inMilliseconds - 1;

      final mdmsState =
          context.read<AppInitializationBloc>().state as AppInitialized?;
      final mdmsFaceConfig = mdmsState?.appConfiguration.faceAuthMdmsConfig;
      for (final r in registers) {
        final start = r.startDate ?? 0;
        final end = r.endDate ?? 0;
        if (start <= todayEnd && end >= todayStart) {
          _configFromRegister = true;
          _faceAuthConfig =
              _buildConfigFromRegister(r, mdmsConfig: mdmsFaceConfig);
          break;
        }
      }

      if (!_configFromRegister && mdmsFaceConfig != null) {
        final d = _faceAuthConfig;
        _faceAuthConfig = FaceAuthConfig(
          startHour: mdmsFaceConfig.startHour ?? d.startHour,
          endHour: mdmsFaceConfig.endHour ?? d.endHour,
          promptCount: mdmsFaceConfig.promptCount ?? d.promptCount,
          minGapMinutes: mdmsFaceConfig.minGapMinutes ?? d.minGapMinutes,
          countdownDuration: Duration(
              minutes: mdmsFaceConfig.countdownDurationMinutes ??
                  d.countdownDuration.inMinutes),
          maxFaceAttempts: mdmsFaceConfig.maxFaceAttempts ?? d.maxFaceAttempts,
          faceMatchThreshold:
              mdmsFaceConfig.faceMatchThreshold ?? d.faceMatchThreshold,
        );
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: _initConfigFromRegister failed: $e');
    }
  }

  Future<void> _startReVerificationScheduler(
      {bool immediateFirstTrigger = false}) async {
    if (_reVerificationScheduler != null) return;

    try {
      final isSupervisor = _faceIsSupervisor(context);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('face_reverify_skip', isSupervisor);
      if (isSupervisor) {
        return;
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: supervisor flag write failed: $e');
    }

    await _initConfigFromRegister();

    if (_reVerificationBloc != null && !_reVerificationBloc!.isClosed) {
      _reVerificationBloc!.updateConfig(_faceAuthConfig);
    }
    if (_faceGateBloc != null && !_faceGateBloc!.isClosed) {
      _faceGateBloc!.updateConfig(
        threshold: _faceAuthConfig.faceMatchThreshold,
        maxAttempts: _faceAuthConfig.maxFaceAttempts,
      );
    }

    _reVerificationScheduler = ReVerificationScheduler(config: _faceAuthConfig);
    _reVerificationScheduler!.isForeground = () =>
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _reVerificationScheduler!
        .start(immediateFirstTrigger: immediateFirstTrigger)
        .then((_) {
      if (mounted) {
        _scheduleController.add(_reVerificationScheduler!.currentSchedule);
        _checkNotificationLaunch();
      }
    }).catchError((e) {
      debugPrint('AuthenticatedPage: scheduler start failed: $e');
    });
    _reVerificationSubscription =
        _reVerificationScheduler!.triggers.listen((trigger) {
      _dispatchTrigger(trigger);
    });
  }

  Future<void> _checkNotificationLaunch() async {
    try {
      final details = await NotificationService()
          .flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      final payload = details.notificationResponse?.payload;
      if (payload == null ||
          !payload.startsWith(NotificationService.reVerifyPayloadPrefix)) {
        return;
      }
      final indexStr =
          payload.substring(NotificationService.reVerifyPayloadPrefix.length);
      final index = int.tryParse(indexStr);
      if (index == null) return;
      if (mounted) {
        _dispatchTrigger(ReVerificationTrigger(
          scheduledTime: DateTime.now(),
          triggerIndex: index,
        ));
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: _checkNotificationLaunch failed: $e');
    }
  }

  void _markTriggerHandledByApp(int triggerIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing =
          (prefs.getStringList('face_reverification_bg_notified') ?? [])
              .toSet();
      existing.add(triggerIndex.toString());
      await prefs.setStringList(
          'face_reverification_bg_notified', existing.toList());
    } catch (e) {
      debugPrint('_markTriggerHandledByApp: $e');
    }
  }

  void _dispatchTrigger(ReVerificationTrigger trigger) async {
    final now = DateTime.now();
    try {
      final isar = context.read<Isar>();
      final repository = FaceEmbeddingRepository(isar);
      final enrollmentCount = await repository.count();
      if (enrollmentCount == 0) {
        _reVerificationScheduler?.markPending(trigger.triggerIndex);
        return;
      }
    } catch (e) {
      _reVerificationScheduler?.markPending(trigger.triggerIndex);
      return;
    }

    if (!mounted) return;

    try {
      final individualId = context.loggedInIndividualId;
      if (individualId != null) {
        final registerRepo = context.repository<AttendanceRegisterModel,
            AttendanceRegisterSearchModel>();
        final registers = await registerRepo.search(
          AttendanceRegisterSearchModel(attendeeId: individualId),
        );

        final todayStart =
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        final todayEnd =
            todayStart + const Duration(days: 1).inMilliseconds - 1;

        AttendanceRegisterModel? activeRegister;
        for (final r in registers) {
          final start = r.startDate ?? 0;
          final end = r.endDate ?? 0;
          if (start <= todayEnd && end >= todayStart) {
            activeRegister = r;
            break;
          }
        }

        if (activeRegister == null && registers.isNotEmpty) {
          _reVerificationScheduler?.markPending(trigger.triggerIndex);
          return;
        }

        if (!_configFromRegister && activeRegister != null) {
          _configFromRegister = true;
          final mdmsState =
              context.read<AppInitializationBloc>().state as AppInitialized?;
          final mdmsFaceConfig = mdmsState?.appConfiguration.faceAuthMdmsConfig;
          final newConfig = _buildConfigFromRegister(
            activeRegister,
            mdmsConfig: mdmsFaceConfig,
          );
          final configChanged =
              newConfig.startHour != _faceAuthConfig.startHour ||
                  newConfig.endHour != _faceAuthConfig.endHour ||
                  newConfig.promptCount != _faceAuthConfig.promptCount ||
                  newConfig.minGapMinutes != _faceAuthConfig.minGapMinutes;
          if (!_coWorkerEmbeddingsPrefetched) {
            _prefetchCoWorkerEmbeddings(context);
          }
          if (configChanged) {
            final newDayEnd =
                DateTime(now.year, now.month, now.day, newConfig.endHour);
            if (now.isAfter(newDayEnd)) {
              _restartSchedulerWithConfig(newConfig,
                  immediateFirstTrigger: false);
              return;
            } else {
              _restartSchedulerWithConfig(newConfig);
            }
          }
        }
      }
    } catch (e) {
      debugPrint(
          'AuthenticatedPage: attendance check threw: $e — failing open');
    }

    if (!mounted) return;

    final topRoute = context.router.topRoute.name;
    if (topRoute == FaceGateRoute.name ||
        topRoute == NonMobileFaceEnrollRoute.name) {
      _reVerificationScheduler?.markPending(trigger.triggerIndex);
      return;
    }

    if (_reVerificationBloc != null && !_reVerificationBloc!.isClosed) {
      _activeTriggerIndex = trigger.triggerIndex;
      _reVerificationBloc!.add(
        ReVerificationEvent.triggered(trigger: trigger),
      );
      _markTriggerHandledByApp(trigger.triggerIndex);
      _reVerificationScheduler?.clearPending();
    } else {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _dispatchTrigger(trigger);
      });
    }
    if (mounted) {
      _scheduleController.add(_reVerificationScheduler!.currentSchedule);
    }
  }

  FaceAuthConfig _buildConfigFromRegister(
    AttendanceRegisterModel register, {
    FaceAuthMdmsConfig? mdmsConfig,
  }) {
    const d = FaceAuthConfig();
    final details = register.additionalDetails;
    return FaceAuthConfig(
      startHour: (details?['startHour'] as num?)?.toInt() ??
          mdmsConfig?.startHour ??
          d.startHour,
      endHour: (details?['endHour'] as num?)?.toInt() ??
          mdmsConfig?.endHour ??
          d.endHour,
      promptCount: mdmsConfig?.promptCount ?? d.promptCount,
      minGapMinutes: mdmsConfig?.minGapMinutes ?? d.minGapMinutes,
      countdownDuration: Duration(
          minutes: mdmsConfig?.countdownDurationMinutes ??
              d.countdownDuration.inMinutes),
      maxFaceAttempts: mdmsConfig?.maxFaceAttempts ?? d.maxFaceAttempts,
      faceMatchThreshold:
          mdmsConfig?.faceMatchThreshold ?? d.faceMatchThreshold,
    );
  }

  Future<void> _prefetchCoWorkerEmbeddings(BuildContext context) async {
    if (_coWorkerEmbeddingsPrefetched) return;
    try {
      if (!mounted) return;
      final individualId = context.loggedInIndividualId;
      if (individualId == null) return;

      final repository = context.read<FaceEmbeddingRepository>();
      final registerRepo = context
          .repository<AttendanceRegisterModel, AttendanceRegisterSearchModel>();
      final individualRepo =
          context.repository<IndividualModel, IndividualSearchModel>();

      final registers = await registerRepo
          .search(AttendanceRegisterSearchModel(attendeeId: individualId));
      if (!mounted) return;

      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final todayEnd = todayStart + const Duration(days: 1).inMilliseconds - 1;

      for (final r in registers) {
        final start = r.startDate ?? 0;
        final end = r.endDate ?? 0;
        if (!(start <= todayEnd && end >= todayStart)) continue;

        _coWorkerEmbeddingsPrefetched = true;

        final eligibleRawIds = (r.attendees ?? <AttendeeModel>[])
            .where((a) =>
                a.denrollmentDate == null ||
                (a.denrollmentDate ?? now.millisecondsSinceEpoch) >=
                    now.millisecondsSinceEpoch)
            .map((a) => a.individualId)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();

        if (eligibleRawIds.isEmpty) break;

        final individuals = await individualRepo
            .search(IndividualSearchModel(id: eligibleRawIds));
        if (!mounted) return;

        final coWorkerIds = individuals
            .where(
                (i) => i.id != null && i.id!.isNotEmpty && i.id != individualId)
            .map((i) => i.id!)
            .toList();

        if (coWorkerIds.isEmpty) break;

        final service = WorkerRegistryService(
          dio: DioClient().dio,
          tenantId: envConfig.variables.tenantId,
        );

        for (final id in coWorkerIds) {
          if (!mounted) return;
          final hasLocal = await repository.hasEmbedding(id);
          if (!hasLocal) {
            await service.syncEnrollmentFromRegistry(
                individualId: id, repository: repository);
          }
        }
        break;
      }
    } catch (e) {
      debugPrint('AuthenticatedPage: _prefetchCoWorkerEmbeddings failed: $e');
    }
  }

  void _restartSchedulerWithConfig(FaceAuthConfig newConfig,
      {bool immediateFirstTrigger = true}) {
    _reVerificationSubscription?.cancel();
    _reVerificationSubscription = null;
    _reVerificationScheduler?.dispose();
    _reVerificationScheduler = null;
    _faceAuthConfig = newConfig;
    _reVerificationBloc?.updateConfig(newConfig);
    _faceGateBloc?.updateConfig(
      threshold: newConfig.faceMatchThreshold,
      maxAttempts: newConfig.maxFaceAttempts,
    );
    _startReVerificationScheduler(immediateFirstTrigger: immediateFirstTrigger);
  }

  Future<void> _retryPendingWorkerRegistrySync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingIds = <String>{};
      final legacySingle = prefs.getString('face_registry_sync_pending');
      if (legacySingle != null && legacySingle.isNotEmpty) {
        pendingIds.add(legacySingle);
      }
      pendingIds.addAll(
          prefs.getStringList('face_registry_sync_pending_ids') ?? const []);
      if (pendingIds.isEmpty) return;
      if (!mounted) return;

      final isar = context.read<Isar>();
      final repository = FaceEmbeddingRepository(isar);
      final service = WorkerRegistryService(
        dio: DioClient().dio,
        tenantId: envConfig.variables.tenantId,
      );

      final remaining = <String>{};
      for (final id in pendingIds) {
        final ok = await service.updateWorkerWithFaceEnrollment(
          individualId: id,
          repository: repository,
        );
        if (!ok) remaining.add(id);
      }

      await prefs.setStringList(
          'face_registry_sync_pending_ids', remaining.toList());
      await prefs.remove('face_registry_sync_pending');
    } catch (e) {
      debugPrint('AuthenticatedPage: worker registry sync retry failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ShowcaseWidget(
      enableAutoScroll: true,
      builder: Builder(
        builder: (context) {
          return StreamBuilder<bool>(
            stream: _drawerVisibilityController.stream,
            builder: (context, snapshot) {
              final showDrawer = snapshot.data ?? false;

              return Portal(
                child: Scaffold(
                  backgroundColor: theme.colorTheme.generic.background,
                  appBar: AppBar(
                    backgroundColor: theme.colorTheme.primary.primary2,
                    foregroundColor: theme.colorTheme.paper.primary,
                    title: ValueListenableBuilder<ReVerificationState?>(
                      valueListenable: _reVerStateNotifier,
                      builder: (context, state, _) {
                        if (state is! ReVerificationPromptedState) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          'Attempt ${state.iteration} of ${state.maxIterations}',
                          style: TextStyle(
                            color: theme.colorTheme.paper.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    actions: null,
                  ),
                  drawer: showDrawer ? drawerWidget(context) : null,
                  body: MultiRepositoryProvider(
                    providers: [
                      RepositoryProvider<FaceModelService>(
                        create: (_) => FaceModelService()..initialize(),
                      ),
                      RepositoryProvider<FaceEmbeddingRepository>(
                        create: (ctx) => FaceEmbeddingRepository(
                          ctx.read<Isar>(),
                        ),
                      ),
                    ],
                    child: MultiBlocProvider(
                      providers: [
                        // Face-auth blocs
                        BlocProvider(
                          create: (ctx) {
                            _faceGateBloc = FaceGateBloc(
                              repository: ctx.read<FaceEmbeddingRepository>(),
                              workerRegistryService: WorkerRegistryService(
                                dio: DioClient().dio,
                                tenantId: envConfig.variables.tenantId,
                              ),
                              similarityThreshold:
                                  _faceAuthConfig.faceMatchThreshold,
                              maxAttempts: _faceAuthConfig.maxFaceAttempts,
                            );
                            return _faceGateBloc!;
                          },
                        ),
                        BlocProvider(
                          create: (ctx) => FaceVerificationBloc(
                            faceModelService: ctx.read<FaceModelService>(),
                            embeddingRepository:
                                ctx.read<FaceEmbeddingRepository>(),
                            similarityThreshold:
                                _faceAuthConfig.faceMatchThreshold,
                          ),
                        ),
                        BlocProvider(
                          create: (_) => LivenessBloc(),
                        ),
                        BlocProvider(
                          lazy: false,
                          create: (ctx) {
                            _reVerificationBloc = ReVerificationBloc(
                              repository: ctx.read<FaceEmbeddingRepository>(),
                              config: _faceAuthConfig,
                              currentUserIndividualId:
                                  context.loggedInIndividualId ?? '',
                            );
                            _reVerStateSubscription?.cancel();
                            _reVerStateSubscription =
                                _reVerificationBloc!.stream.listen((state) {
                              _reVerStateNotifier.value = state;
                              final terminal = state.maybeWhen(
                                verified: (_, __) => true,
                                missed: (_) => true,
                                orElse: () => false,
                              );
                              if (terminal && _activeTriggerIndex != null) {
                                final idx = _activeTriggerIndex!;
                                _reVerificationScheduler?.markCompleted(idx);
                                _activeTriggerIndex = null;
                              }
                            });
                            return _reVerificationBloc!;
                          },
                        ),
                        // INFO : Need to add bloc of package Here
                        BlocProvider(
                          create: (context) {
                            final userId = context.loggedInUserUuid;

                            final isar = context.read<Isar>();
                            final bloc = SyncBloc(
                              isar: isar,
                              syncService: SyncService(),
                            );

                            if (!bloc.isClosed) {
                              bloc.add(SyncRefreshEvent(userId));
                            }
                            /* Every time when the user changes the screen
     this will refresh the data of sync count */
                            isar.opLogs
                                .filter()
                                .createdByEqualTo(userId)
                                .syncedUpEqualTo(false)
                                .watch()
                                .listen(
                              (event) {
                                if (!bloc.isClosed) {
                                  triggerSyncRefreshEvent(bloc, userId, event);
                                }
                              },
                            );

                            isar.opLogs
                                .filter()
                                .createdByEqualTo(userId)
                                .syncedUpEqualTo(true)
                                .syncedDownEqualTo(false)
                                .watch()
                                .listen(
                              (event) {
                                if (!bloc.isClosed) {
                                  triggerSyncRefreshEvent(bloc, userId, event);
                                }
                              },
                            );

                            return bloc;
                          },
                        ),
                        BlocProvider(
                          create: (_) {
                            final bloc = LocationBloc(
                                location: LocationService.instance.location)
                              ..add(const LoadLocationEvent());
                            bloc.stream
                                .firstWhere((s) => s.hasPermissions)
                                .then((_) =>
                                    LocationService.instance.ensureTracking())
                                .catchError((_) {});
                            return bloc;
                          },
                        ),
                        BlocProvider(
                          create: (ctx) => BeneficiaryDownSyncBloc(
                            bandwidthCheckRepository: BandwidthCheckRepository(
                              DioClient().dio,
                              bandwidthPath:
                                  envConfig.variables.checkBandwidthApiPath,
                            ),
                            individualLocalRepository: ctx.read<
                                LocalRepository<IndividualModel,
                                    IndividualSearchModel>>(),
                            downSyncRemoteRepository: ctx.read<
                                RemoteRepository<DownsyncModel,
                                    DownsyncSearchModel>>(),
                            downSyncLocalRepository: ctx.read<
                                LocalRepository<DownsyncModel,
                                    DownsyncSearchModel>>(),
                            householdLocalRepository: ctx.read<
                                LocalRepository<HouseholdModel,
                                    HouseholdSearchModel>>(),
                            householdMemberLocalRepository: ctx.read<
                                LocalRepository<HouseholdMemberModel,
                                    HouseholdMemberSearchModel>>(),
                            projectBeneficiaryLocalRepository: ctx.read<
                                LocalRepository<ProjectBeneficiaryModel,
                                    ProjectBeneficiarySearchModel>>(),
                            taskLocalRepository: ctx.read<
                                LocalRepository<TaskModel, TaskSearchModel>>(),
                            sideEffectLocalRepository: ctx.read<
                                LocalRepository<SideEffectModel,
                                    SideEffectSearchModel>>(),
                            referralLocalRepository: ctx.read<
                                LocalRepository<ReferralModel,
                                    ReferralSearchModel>>(),
                            hfReferralLocalRepository: ctx.read<
                                LocalRepository<HFReferralModel,
                                    HFReferralSearchModel>>(),
                            serviceLocalRepository: ctx.read<
                                LocalRepository<ServiceModel,
                                    ServiceSearchModel>>(),
                          ),
                        ),
                        BlocProvider(
                          create: (ctx) => StockDownSyncBloc(
                            context: context,
                            localSecureStore: LocalSecureStore.instance,
                            bandwidthCheckRepository: BandwidthCheckRepository(
                              DioClient().dio,
                              bandwidthPath:
                                  envConfig.variables.checkBandwidthApiPath,
                            ),
                            projectFacilityLocalRepository: ctx.read<
                                LocalRepository<ProjectFacilityModel,
                                    ProjectFacilitySearchModel>>(),
                            facilityLocalRepository: ctx.read<
                                LocalRepository<FacilityModel,
                                    FacilitySearchModel>>(),
                            stockRemoteRepository: ctx.read<
                                RemoteRepository<StockModel,
                                    StockSearchModel>>(),
                            stockLocalRepository: ctx.read<
                                LocalRepository<StockModel,
                                    StockSearchModel>>(),
                            projectResourceLocalRepository: ctx.read<
                                LocalRepository<ProjectResourceModel,
                                    ProjectResourceSearchModel>>(),
                            downSyncLocalRepository: ctx.read<
                                LocalRepository<DownsyncModel,
                                    DownsyncSearchModel>>(),
                            userActionRemoteRepository:
                                ctx.read<UserActionRemoteRepository>(),
                            userActionLocalRepository:
                                ctx.read<UserActionLocalRepository>(),
                          ),
                        ),
                        BlocProvider(
                          create: (ctx) => HFReferralDownSyncBloc(
                            bandwidthCheckRepository: BandwidthCheckRepository(
                              DioClient().dio,
                              bandwidthPath:
                                  envConfig.variables.checkBandwidthApiPath,
                            ),
                            hfReferralLocalRepository: ctx.read<
                                LocalRepository<HFReferralModel,
                                    HFReferralSearchModel>>(),
                            hfReferralRemoteRepository: ctx.read<
                                RemoteRepository<HFReferralModel,
                                    HFReferralSearchModel>>(),
                            downSyncLocalRepository: ctx.read<
                                LocalRepository<DownsyncModel,
                                    DownsyncSearchModel>>(),
                            projectFacilityLocalRepository: ctx.read<
                                LocalRepository<ProjectFacilityModel,
                                    ProjectFacilitySearchModel>>(),
                          ),
                        ),
                        BlocProvider(
                          create: (_) => ServiceBloc(
                            const ServiceEmptyState(),
                            serviceDataRepository: context
                                .repository<ServiceModel, ServiceSearchModel>(),
                          ),
                        ),
                        BlocProvider(
                          create: (_) => FormsBloc(),
                        ),
                      ],
                      child: MultiBlocListener(
                        listeners: [
                          BlocListener<PushNotificationBloc,
                              PushNotificationState>(
                            listener: (context, state) {
                              if (state is PushNotificationTappedState) {
                                final notificationData =
                                    NotificationData.fromMap(state.data);

                                NotificationHandlerFactory.getHandler(
                                        notificationData.notificationType)
                                    ?.handle(context, notificationData.payload);
                              }
                            },
                          ),
                          BlocListener<AppInitializationBloc,
                              AppInitializationState>(
                            listenWhen: (prev, curr) => curr is AppInitialized,
                            listener: (context, state) async {
                              if (state is! AppInitialized) return;
                              if (_reVerificationScheduler == null) return;
                              final mdmsFaceConfig =
                                  state.appConfiguration.faceAuthMdmsConfig;
                              if (mdmsFaceConfig == null) return;
                              final merged = FaceAuthConfig(
                                startHour: mdmsFaceConfig.startHour ??
                                    _faceAuthConfig.startHour,
                                endHour: mdmsFaceConfig.endHour ??
                                    _faceAuthConfig.endHour,
                                promptCount: mdmsFaceConfig.promptCount ??
                                    _faceAuthConfig.promptCount,
                                minGapMinutes: mdmsFaceConfig.minGapMinutes ??
                                    _faceAuthConfig.minGapMinutes,
                                countdownDuration: Duration(
                                    minutes: mdmsFaceConfig
                                            .countdownDurationMinutes ??
                                        _faceAuthConfig
                                            .countdownDuration.inMinutes),
                                maxFaceAttempts:
                                    mdmsFaceConfig.maxFaceAttempts ??
                                        _faceAuthConfig.maxFaceAttempts,
                                faceMatchThreshold:
                                    mdmsFaceConfig.faceMatchThreshold ??
                                        _faceAuthConfig.faceMatchThreshold,
                              );
                              final changed = merged.startHour !=
                                      _faceAuthConfig.startHour ||
                                  merged.endHour != _faceAuthConfig.endHour ||
                                  merged.promptCount !=
                                      _faceAuthConfig.promptCount ||
                                  merged.minGapMinutes !=
                                      _faceAuthConfig.minGapMinutes ||
                                  merged.countdownDuration !=
                                      _faceAuthConfig.countdownDuration;
                              if (changed) {
                                _restartSchedulerWithConfig(merged);
                              }
                            },
                          ),
                          BlocListener<HFReferralDownSyncBloc,
                              HFReferralDownSyncState>(
                            listener: (context, hfDownSyncState) {
                              final localizations =
                                  AppLocalizations.of(context);
                              final appConfiguration = (context
                                      .read<AppInitializationBloc>()
                                      .state as AppInitialized)
                                  .appConfiguration;
                              hfDownSyncState.maybeWhen(
                                orElse: () {},
                                loading: () {
                                  DigitSyncDialog.show(
                                    context,
                                    type: DialogType.inProgress,
                                    label: localizations.translate(
                                      i18.beneficiaryDetails
                                          .dataDownloadInProgress,
                                    ),
                                    barrierDismissible: false,
                                  );
                                },
                                dataFound: (newCount, serverTotalCount) {
                                  Navigator.of(context, rootNavigator: true)
                                      .popUntil(
                                          (route) => route is! PopupRoute);
                                  showCustomPopup(
                                    barrierDismissible: false,
                                    context: context,
                                    builder: (ctx) => Popup(
                                      title: localizations.translate(
                                        newCount > 0
                                            ? i18.beneficiaryDetails.dataFound
                                            : i18
                                                .beneficiaryDetails.noDataFound,
                                      ),
                                      titleIcon: Icon(
                                        Icons.info_outline_rounded,
                                        color: Theme.of(context)
                                            .colorTheme
                                            .text
                                            .primary,
                                      ),
                                      description: localizations.translate(
                                        newCount > 0
                                            ? i18.beneficiaryDetails
                                                .dataFoundContent
                                            : i18.beneficiaryDetails
                                                .noDataFoundContent,
                                      ),
                                      actions: [
                                        DigitButton(
                                          label: localizations.translate(
                                            newCount > 0
                                                ? i18.common.coreCommonDownload
                                                : i18.common.coreCommonGoback,
                                          ),
                                          onPressed: () {
                                            if (newCount > 0) {
                                              context
                                                  .read<
                                                      HFReferralDownSyncBloc>()
                                                  .add(
                                                    HFReferralDownSyncDownloadEvent(
                                                      projectId:
                                                          context.projectId,
                                                      appConfiguration: [
                                                        appConfiguration
                                                      ],
                                                      totalCount: newCount,
                                                      serverTotalCount:
                                                          serverTotalCount,
                                                    ),
                                                  );
                                            } else {
                                              Navigator.of(context,
                                                      rootNavigator: true)
                                                  .pop();
                                              context.router
                                                  .replaceAll([HomeRoute()]);
                                            }
                                          },
                                          type: DigitButtonType.primary,
                                          size: DigitButtonSize.medium,
                                        ),
                                        if (newCount > 0)
                                          DigitButton(
                                            label: localizations.translate(
                                              i18.beneficiaryDetails
                                                  .proceedWithoutDownloading,
                                            ),
                                            onPressed: () {
                                              Navigator.of(context,
                                                      rootNavigator: true)
                                                  .pop();
                                              context.router
                                                  .replaceAll([HomeRoute()]);
                                            },
                                            type: DigitButtonType.secondary,
                                            size: DigitButtonSize.medium,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                                inProgress: (syncedCount, totalCount) {
                                  final progressData = HFReferralProgressData(
                                    progress: totalCount == 0
                                        ? 0
                                        : (syncedCount / totalCount)
                                            .clamp(0.0, 1.0),
                                    syncedCount: syncedCount,
                                    totalCount: totalCount,
                                  );
                                  if (syncedCount < 1) {
                                    if (_hfReferralProgress.isClosed) {
                                      _hfReferralProgress = StreamController<
                                          HFReferralProgressData>.broadcast();
                                    }
                                    showHFReferralProgressDialog(
                                      context,
                                      title: localizations.translate(
                                        i18.beneficiaryDetails
                                            .dataDownloadInProgress,
                                      ),
                                      progressController: _hfReferralProgress,
                                      initialData: progressData,
                                    );
                                  }
                                  if (!_hfReferralProgress.isClosed) {
                                    _hfReferralProgress.add(progressData);
                                  }
                                },
                                success: (syncedCount, totalCount) {
                                  Navigator.of(context, rootNavigator: true)
                                      .popUntil(
                                          (route) => route is! PopupRoute);
                                  DigitSyncDialog.show(
                                    context,
                                    type: DialogType.complete,
                                    label: localizations.translate(
                                      i18.beneficiaryDetails
                                          .referralDownloadCompleted,
                                    ),
                                    primaryAction: DigitDialogActions(
                                      label: localizations.translate(
                                        i18.acknowledgementSuccess.goToHome,
                                      ),
                                      action: (ctx) {
                                        Navigator.of(context,
                                                rootNavigator: true)
                                            .pop();
                                        context.router
                                            .replaceAll([HomeRoute()]);
                                      },
                                    ),
                                  );
                                },
                                failed: () {
                                  Navigator.of(context, rootNavigator: true)
                                      .popUntil(
                                          (route) => route is! PopupRoute);
                                  DigitSyncDialog.show(
                                    context,
                                    type: DialogType.failed,
                                    label: localizations.translate(
                                      i18.common.coreCommonDownloadFailed,
                                    ),
                                    primaryAction: DigitDialogActions(
                                      label: localizations.translate(
                                        i18.syncDialog.retryButtonLabel,
                                      ),
                                      action: (ctx) {
                                        Navigator.of(context,
                                                rootNavigator: true)
                                            .pop();
                                        context
                                            .read<HFReferralDownSyncBloc>()
                                            .add(
                                              HFReferralDownSyncStartEvent(
                                                projectId: context.projectId,
                                                appConfiguration: [
                                                  appConfiguration
                                                ],
                                              ),
                                            );
                                      },
                                    ),
                                    secondaryAction: DigitDialogActions(
                                      label: localizations.translate(
                                        i18.beneficiaryDetails
                                            .proceedWithoutDownloading,
                                      ),
                                      action: (ctx) {
                                        Navigator.of(context,
                                                rootNavigator: true)
                                            .pop();
                                        context.router
                                            .replaceAll([HomeRoute()]);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                        child: ErrorBoundary(builder: (context, error) {
                          if (error == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _checkFaceEnrollment();
                              _prefetchCoWorkerEmbeddings(context);
                              _retryPendingWorkerRegistrySync();
                            });
                          }
                          return error != null
                              ? const ErrorScreen()
                              : ReVerificationListener(
                                  child: Column(
                                    children: [
                                      const _ReVerificationCountdownBanner(),
                                      Expanded(
                                        child: AutoRouter(
                                          navigatorObservers: () => [
                                            AuthenticatedRouteObserver(
                                              onNavigated: () {
                                                bool shouldShowDrawer;
                                                switch (context
                                                    .router.topRoute.name) {
                                                  case ProjectSelectionRoute
                                                        .name:
                                                  case BoundarySelectionRoute
                                                        .name:
                                                  case PermissionsRoute.name:
                                                  case FaceGateRoute.name:
                                                    shouldShowDrawer = false;
                                                    break;
                                                  default:
                                                    shouldShowDrawer = true;
                                                }

                                                _drawerVisibilityController
                                                    .add(shouldShowDrawer);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                        }),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void triggerSyncRefreshEvent(
      SyncBloc bloc, String userId, List<OpLog> event) {
    bloc.add(
      SyncRefreshEvent(
        userId,
        SyncServiceSingleton().entityMapper!.getSyncCount(event),
      ),
    );
  }

  Widget drawerWidget(BuildContext context) {
    final appInitializationBloc = context.read<AppInitializationBloc>();
    final appConfig =
        (appInitializationBloc.state as AppInitialized).appConfiguration;
    final languages = appConfig.languages;
    final localizationModulesList = appConfig.backendInterface;
    final authBloc = context.read<AuthBloc>();
    bool isDistributor = authBloc.state != const AuthState.unauthenticated()
        ? context.loggedInUserRoles
            .where(
              (role) => role.code == RolesType.distributor.toValue(),
            )
            .toList()
            .isNotEmpty
        : false;

    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      return BlocListener<LocalizationBloc, LocalizationState>(
        listener: (context, state) {
          if (state.loading == false) {
            Navigator.of(context, rootNavigator: true).pop();
          } else {
            DigitLoaders.overlayLoader(context: context);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: kToolbarHeight),
            child: SideBar(
              profile: state.maybeMap(
                authenticated: (value) {
                  String qrData =
                      "${value.userModel.userName}||${context.loggedInUserUuid}";
                  return ProfileWidget(
                    leading: GestureDetector(
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        context.router.push(UserQRDetailsRoute());
                      },
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 150.0,
                      ),
                    ),
                    title: value.userModel.name.toString(),
                    description: value.userModel.mobileNumber.toString(),
                  );
                },
                orElse: () => null,
              ),
              sidebarItems: [
                SidebarItem(
                  title: AppLocalizations.of(context).translate(
                    i18.common.coreCommonHome,
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    context.router.replaceAll([HomeRoute()]);
                  },
                  icon: Icons.home,
                ),
                if (isDistributor) ...[
                  SidebarItem(
                    title: AppLocalizations.of(context).translate(
                      i18.common.coreCommonViewDownloadedData,
                    ),
                    icon: Icons.download,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      context.router.push(const BeneficiariesReportRoute());
                    },
                  ),
                  SidebarItem(
                    title: AppLocalizations.of(context).translate(
                      i18.nonMobileUser.nonMobileUserLabel,
                    ),
                    icon: Icons.people_outline,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      context.router.navigate(const NonMobileUserListRoute());
                    },
                  ),
                ],
              ],
              logOutDigitButtonLabel: AppLocalizations.of(context)
                  .translate(i18.common.coreCommonLogout),
              onLogOut: () async {
                final isConnected = await getIsConnected();
                if (context.mounted) {
                  if (isConnected) {
                    await showCustomPopup(
                      context: context,
                      builder: (ctx) => Popup(
                        title: AppLocalizations.of(context).translate(
                          i18.common.coreCommonWarning,
                        ),
                        description: AppLocalizations.of(context).translate(
                          i18.common.logOutWarningMsg,
                        ),
                        onOutsideTap: () {
                          Navigator.of(ctx).pop();
                        },
                        type: PopUpType.simple,
                        actions: [
                          DigitButton(
                              label: AppLocalizations.of(context).translate(
                                i18.common.coreCommonOk,
                              ),
                              onPressed: () async {
                                final isar = context.read<Isar>();
                                final serviceRegistry = await isar
                                    .serviceRegistrys
                                    .where()
                                    .findAll();
                                final apiEndPoint =
                                    Constants.getNotificationEndPoint(
                                  serviceRegistry: serviceRegistry,
                                  service: 'NOTIFICATION',
                                  action: ApiOperation.unRegister.toValue(),
                                  entityName: 'NotificationToken',
                                );

                                if (context.mounted) {
                                  context.read<PushNotificationBloc>().add(
                                        PushNotificationEvent.logout(
                                          apiEndPoint: apiEndPoint,
                                        ),
                                      );
                                  context
                                      .read<BoundaryBloc>()
                                      .add(const BoundaryResetEvent());
                                  context.read<LocalizationBloc>().add(
                                        LocalizationEvent.onLoadLocalization(
                                          module: Constants
                                              .homeLocalizationModules
                                              .join(','),
                                          tenantId:
                                              envConfig.variables.tenantId,
                                          locale: AppSharedPreferences()
                                                  .getSelectedLocale ??
                                              '',
                                          path: Constants.localizationApiPath,
                                        ),
                                      );
                                  context
                                      .read<AuthBloc>()
                                      .add(const AuthLogoutEvent());
                                }
                              },
                              type: DigitButtonType.secondary,
                              size: DigitButtonSize.large),
                          DigitButton(
                              label: AppLocalizations.of(context).translate(
                                i18.common.coreCommonNo,
                              ),
                              onPressed: () {
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop(true);
                              },
                              type: DigitButtonType.primary,
                              size: DigitButtonSize.large)
                        ],
                      ),
                    );
                  } else {
                    Toast.showToast(
                      context,
                      message: AppLocalizations.of(context).translate(
                        i18.login.noInternetError,
                      ),
                      type: ToastType.error,
                    );
                  }
                }
              },
              footer: PoweredByDigit(
                version: Constants().version,
              ),
            ),
          ),
        ),
      );
    });
  }

  List<SidebarItem>? buildLanguage(
      BackendInterface localizationModulesList,
      List<Languages>? languages,
      BuildContext context,
      AppConfiguration appConfig) {
    final state = context.read<AppInitializationBloc>().state as AppInitialized;
    return languages
        ?.map((e) => SidebarItem(
              title: e.label,
              onPressed: () async {
                DigitLoaders.overlayLoader(context: context);

                int index = languages.indexWhere(
                  (ele) => ele.value.toString() == e.value.toString(),
                );

                /// TODO: NEED TO CHECK HOW CAN WE UPDATE THE LOCALIZATION BASED ON THE FLOW
                // String? dynamicModule;
                // final isInRegistrationFlow = context.router.current.name
                //     .contains(RegistrationDeliveryWrapperRoute.name);
                //
                // if (isInRegistrationFlow) {
                //   final prefs = await SharedPreferences.getInstance();
                //   final schemaJsonRaw = prefs.getString('app_config_schemas');
                //
                //   if (schemaJsonRaw != null) {
                //     final allSchemas =
                //         json.decode(schemaJsonRaw) as Map<String, dynamic>;
                //     final projectId = context.selectedProject.referenceID;
                //
                //     // Initialize empty list to collect modules
                //     final List<String> modules = [];
                //
                //     // Handle registrationflow
                //     final registrationSchemaEntry =
                //         allSchemas['REGISTRATIONFLOW'] as Map<String, dynamic>?;
                //     final registrationSchemaData =
                //         registrationSchemaEntry?['data'];
                //     final registrationFlowName = registrationSchemaData?['name']
                //         ?.toString()
                //         .toLowerCase();
                //     if (registrationFlowName != null && projectId != null) {
                //       modules.add('hcm-$registrationFlowName-$projectId');
                //     }
                //
                //     // Handle deliveryflow
                //     final deliverySchemaEntry =
                //         allSchemas['DELIVERYFLOW'] as Map<String, dynamic>?;
                //     final deliverySchemaData = deliverySchemaEntry?['data'];
                //     final deliveryFlowName =
                //         deliverySchemaData?['name']?.toString().toLowerCase();
                //     if (deliveryFlowName != null && projectId != null) {
                //       modules.add('hcm-$deliveryFlowName-$projectId');
                //     }
                //
                //     // Combine into a single string
                //     dynamicModule = modules.join(',');
                //   }
                // }
                //
                // final staticModules = localizationModulesList.interfaces
                //     .where((element) =>
                //         element.type == Modules.localizationModule &&
                //         Constants.homeLocalizationModules
                //             .contains(element.name.toString()))
                //     .map((e) => e.name.toString())
                //     .followedBy([
                //   'hcm-boundary-${envConfig.variables.hierarchyType}'
                // ]).join(',');
                //
                // final combinedModules = dynamicModule != null
                //     ? '$dynamicModule,$staticModules'
                //     : staticModules;
                //
                // context
                //     .read<LocalizationBloc>()
                //     .add(LocalizationEvent.onLoadLocalization(
                //       module: combinedModules,
                //       tenantId: appConfig.tenantId ?? "default",
                //       locale: e.value.toString(),
                //       path: Constants.localizationApiPath,
                //     ));

                context.read<LocalizationBloc>().add(
                      OnUpdateLocalizationIndexEvent(
                        index: index,
                        code: e.value.toString(),
                      ),
                    );
              },
              initiallySelected: getSelectedLanguage(
                  state,
                  languages.indexWhere(
                    (ele) => ele.value.toString() == e.value.toString(),
                  )),
            ))
        .toList();
  }
}

class _PrivacyNoticeFullscreenPopup extends StatefulWidget {
  final Map<String, dynamic> flow;
  final Future<void> Function() onProceed;

  const _PrivacyNoticeFullscreenPopup({
    required this.flow,
    required this.onProceed,
  });

  @override
  State<_PrivacyNoticeFullscreenPopup> createState() =>
      _PrivacyNoticeFullscreenPopupState();
}

class _PrivacyNoticeFullscreenPopupState
    extends State<_PrivacyNoticeFullscreenPopup> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReachedEnd = false;

  Future<void> _openExternalUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildTextWithOptionalLink({
    required String value,
    required TextStyle style,
  }) {
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final match = urlRegex.firstMatch(value);

    if (match == null) {
      return Text(value, style: style);
    }

    final before = value.substring(0, match.start);
    final url = value.substring(match.start, match.end);
    final after = value.substring(match.end);

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _openExternalUrl(url),
              child: Text(
                url,
                style: style.copyWith(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (_scrollController.position.maxScrollExtent <= 0) {
        setState(() {
          _hasReachedEnd = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _hasReachedEnd) return;
    final position = _scrollController.position;
    if (position.pixels >= (position.maxScrollExtent - 16)) {
      setState(() {
        _hasReachedEnd = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalizationBloc, LocalizationState>(
      buildWhen: (previous, current) {
        // Rebuild only after localization load settles to avoid showing keys.
        if (previous.loading != current.loading) {
          return current.loading == false;
        }

        return previous.index != current.index && current.loading == false;
      },
      builder: (context, _) {
        final theme = Theme.of(context);
        final textTheme = theme.digitTextTheme(context);
        final bodyItems = widget.flow['body'] as List<dynamic>? ?? const [];

        return PopScope(
          canPop: false,
          child: Material(
            color: theme.colorTheme.generic.background,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(spacer2),
                      child: DigitCard(
                        margin: EdgeInsets.zero,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate(
                                widget.flow['heading'] as String? ??
                                    'PRIVACY_NOTICE'),
                            style: textTheme.headingXl.copyWith(
                              color: theme.colorTheme.primary.primary2,
                            ),
                          ),
                          ...bodyItems.map((item) {
                            final content = item is Map
                                ? Map<String, dynamic>.from(item)
                                : <String, dynamic>{};
                            final format =
                                content['format'] as String? ?? 'text';
                            final value = content['value'] as String? ?? '';
                            final isBold = content['bold'] as bool? ?? false;
                            final isCompact =
                                content['compact'] as bool? ?? false;

                            if (format == 'heading') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 0),
                                child: Text(
                                  value,
                                  style: isCompact
                                      ? textTheme.bodyS.copyWith(
                                          color:
                                              theme.colorTheme.primary.primary2,
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                        )
                                      : textTheme.headingM.copyWith(
                                          color:
                                              theme.colorTheme.primary.primary2,
                                          height: 1.0,
                                        ),
                                ),
                              );
                            }

                            if (format == 'bullet') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: textTheme.bodyS.copyWith(
                                        color:
                                            theme.colorTheme.primary.primary2,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        value,
                                        style: textTheme.bodyS.copyWith(
                                          color:
                                              theme.colorTheme.primary.primary2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: spacer1),
                              child: _buildTextWithOptionalLink(
                                value: value,
                                style: textTheme.bodyS.copyWith(
                                  color: theme.colorTheme.primary.primary2,
                                  fontWeight: isBold ? FontWeight.w700 : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  DigitCard(
                    margin: const EdgeInsets.only(top: spacer2),
                    children: [
                      DigitButton(
                        mainAxisSize: MainAxisSize.max,
                        isDisabled: !_hasReachedEnd,
                        label: AppLocalizations.of(context).translate(
                          widget.flow['proceedLabel'] as String? ?? 'PROCEED',
                        ),
                        type: DigitButtonType.primary,
                        size: DigitButtonSize.large,
                        onPressed: () {
                          widget.onProceed();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
