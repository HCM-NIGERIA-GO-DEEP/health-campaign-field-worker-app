import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/address_type.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/services/location_bloc.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../registration_deliver_pages/beneficiary_registration/household_details.dart';
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/i18_key_constants.dart' as i18;
import '../../utils/registration_deliver_utils/utils.dart';
import '../../widgets/registartion_deliver/back_navigation_help_header.dart';
import '../../widgets/registartion_deliver/localized.dart';

class BednetHouseholdLocationPage extends LocalizedStatefulWidget {
  const BednetHouseholdLocationPage({super.key, super.appLocalizations});

  @override
  State<BednetHouseholdLocationPage> createState() =>
      _BednetHouseholdLocationPageState();
}

class _BednetHouseholdLocationPageState
    extends LocalizedState<BednetHouseholdLocationPage> {
  final TextEditingController _settlementController = TextEditingController();
  final TextEditingController _gpsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<LocationBloc>().add(const LoadLocationEvent());
    _settlementController.text =
        RegistrationDeliverySingleton().boundary?.name ?? '';
  }

  @override
  void dispose() {
    _settlementController.dispose();
    _gpsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return Scaffold(
      body: BlocBuilder<LocationBloc, LocationState>(
        builder: (context, locationState) {
          return ScrollableContent(
            enableFixedDigitButton: true,
            header: const Padding(
              padding: EdgeInsets.only(bottom: spacer2),
              child: BackNavigationHelpHeaderWidget(showHelp: false),
            ),
            footer: DigitCard(
              margin: const EdgeInsets.only(top: spacer2),
              children: [
                DigitButton(
                  label: localizations.translate(i18.common.coreCommonNext),
                  type: DigitButtonType.primary,
                  size: DigitButtonSize.large,
                  mainAxisSize: MainAxisSize.max,
                  isDisabled: locationState.accuracy == null,
                  onPressed: () {
                    final createdAt = context.millisecondsSinceEpoch();
                    final userUuid =
                        RegistrationDeliverySingleton().loggedInUserUuid ?? '';
                    final gpsAccuracy =
                        double.tryParse(_gpsController.text.trim());

                    final addressModel = AddressModel(
                      type: AddressType.correspondence,
                      latitude: locationState.latitude,
                      longitude: locationState.longitude,
                      locationAccuracy: gpsAccuracy ?? locationState.accuracy,
                      addressLine1: _settlementController.text.trim().isEmpty
                          ? RegistrationDeliverySingleton().boundary?.name
                          : _settlementController.text.trim(),
                      locality: LocalityModel(
                        code: RegistrationDeliverySingleton().boundary?.code ??
                            '',
                        name: RegistrationDeliverySingleton().boundary?.name ??
                            '',
                      ),
                      tenantId: RegistrationDeliverySingleton().tenantId,
                      rowVersion: 1,
                      auditDetails: AuditDetails(
                        createdBy: userUuid,
                        createdTime: createdAt,
                        lastModifiedBy: userUuid,
                        lastModifiedTime: createdAt,
                      ),
                      clientAuditDetails: ClientAuditDetails(
                        createdBy: userUuid,
                        createdTime: createdAt,
                        lastModifiedBy: userUuid,
                        lastModifiedTime: createdAt,
                      ),
                    );
                    final registrationBloc =
                        context.read<BeneficiaryRegistrationBloc>();
                    registrationBloc.add(
                      BeneficiaryRegistrationEvent.saveAddress(addressModel),
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: registrationBloc,
                          child: const HouseHoldDetailsPage(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            slivers: [
              SliverToBoxAdapter(
                child: DigitCard(
                  margin: const EdgeInsets.all(spacer2),
                  children: [
                    Text(
                      localizations.translate(
                        i18.householdLocation.householdLocationLabelText,
                      ),
                      style: textTheme.headingXl.copyWith(
                        color: const Color(0xFF005A7A),
                      ),
                    ),
                    LabeledField(
                      label: localizations.translate(
                        i18.householdLocation.administrationAreaFormLabel,
                      ),
                      child: DigitTextFormInput(
                        readOnly: true,
                        controller: _settlementController,
                      ),
                    ),
                    LabeledField(
                      label: localizations
                          .translate(i18.householdLocation.gpsAccuracyLabel),
                      capitalizedFirstLetter: false,
                      child: DigitTextFormInput(
                        readOnly: true,
                        controller: _gpsController
                          ..text = _gpsController.text.isEmpty
                              ? (locationState.accuracy?.toStringAsFixed(6) ??
                                  '')
                              : _gpsController.text,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
