import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/registration_deliver/beneficiary_registration/beneficiary_registration.dart';
import '../../pages/registration_deliver_pages/beneficiary_registration/individual_details.dart';
import '../../utils/registration_deliver_utils/extensions/extensions.dart';
import '../../utils/registration_deliver_utils/utils.dart';

/// Provides [BeneficiaryRegistrationBloc] for [IndividualDetailsPage] inside
/// the bednet household overview nested stack.
@RoutePage()
class BednetIndividualDetailsWrapperPage extends StatelessWidget
    implements AutoRouteWrapper {
  final HouseholdModel householdModel;
  final AddressModel addressModel;
  final IndividualModel? individualModel;
  final ProjectBeneficiaryModel? projectBeneficiaryModel;
  final bool isHeadOfHousehold;

  const BednetIndividualDetailsWrapperPage({
    super.key,
    required this.householdModel,
    required this.addressModel,
    this.individualModel,
    this.projectBeneficiaryModel,
    this.isHeadOfHousehold = false,
  });

  @override
  Widget wrappedRoute(BuildContext context) {
    final beneficiaryType = RegistrationDeliverySingleton().beneficiaryType!;
    final individual =
        context.repository<IndividualModel, IndividualSearchModel>(context);
    final household =
        context.repository<HouseholdModel, HouseholdSearchModel>(context);
    final householdMember = context
        .repository<HouseholdMemberModel, HouseholdMemberSearchModel>(context);
    final projectBeneficiary = context.repository<
        ProjectBeneficiaryModel, ProjectBeneficiarySearchModel>(context);
    final task = context.repository<TaskModel, TaskSearchModel>(context);

    final BeneficiaryRegistrationState initialState = individualModel != null
        ? BeneficiaryRegistrationState.editIndividual(
            householdModel: householdModel,
            individualModel: individualModel!,
            addressModel: addressModel,
            projectBeneficiaryModel: projectBeneficiaryModel,
          )
        : BeneficiaryRegistrationState.addMember(
            addressModel: addressModel,
            householdModel: householdModel,
            isHeadOfHousehold: isHeadOfHousehold,
          );

    return BlocProvider(
      create: (_) => BeneficiaryRegistrationBloc(
        initialState,
        individualRepository: individual,
        householdRepository: household,
        householdMemberRepository: householdMember,
        projectBeneficiaryRepository: projectBeneficiary,
        taskDataRepository: task,
        beneficiaryType: beneficiaryType,
      ),
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IndividualDetailsPage(
      isHeadOfHousehold: isHeadOfHousehold,
    );
  }
}
