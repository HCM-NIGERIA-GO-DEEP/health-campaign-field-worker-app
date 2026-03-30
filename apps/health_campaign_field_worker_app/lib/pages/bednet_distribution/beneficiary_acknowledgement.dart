import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../widgets/localized.dart';
import 'bednet_distribution_acknowledgement.dart';

/// Kept for [BeneficiaryAcknowledgementRoute] / tooling compatibility.
/// Renders the same flow as [BednetDistributionAcknowledgementPage] (no
/// registration_delivery dependency).
@RoutePage()
class BeneficiaryAcknowledgementPage extends LocalizedStatefulWidget {
  final bool? enableViewHousehold;

  const BeneficiaryAcknowledgementPage({
    super.key,
    super.appLocalizations,
    this.enableViewHousehold,
  });

  @override
  State<BeneficiaryAcknowledgementPage> createState() =>
      _BeneficiaryAcknowledgementPageState();
}

class _BeneficiaryAcknowledgementPageState
    extends LocalizedState<BeneficiaryAcknowledgementPage> {
  @override
  Widget build(BuildContext context) {
    return const BednetDistributionAcknowledgementPage();
  }
}
