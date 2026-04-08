import 'dart:math';

import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';

import '../../widgets/header/back_navigation_help_header.dart';
import 'bednet_inform_household.dart';

class BednetHouseholdReviewPage extends StatelessWidget {
  final String headName;
  final int memberCount;
  final String? mobileNumber;

  const BednetHouseholdReviewPage({
    super.key,
    required this.headName,
    required this.memberCount,
    this.mobileNumber,
  });

  int get _itnForDelivery => max(1, (memberCount / 2).ceil());

  String get _token {
    final random = Random(headName.hashCode + memberCount);
    final part1 = (100 + random.nextInt(900)).toString();
    final part2 = (100 + random.nextInt(900)).toString();
    return 'E$part1-$part2';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);
    return Scaffold(
      body: ScrollableContent(
        enableFixedDigitButton: true,
        header: const BackNavigationHelpHeaderWidget(showHelp: true),
        footer: DigitCard(
          margin: const EdgeInsets.only(top: spacer2),
          children: [
            DigitButton(
              label: 'Next',
              type: DigitButtonType.primary,
              size: DigitButtonSize.large,
              mainAxisSize: MainAxisSize.max,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BednetInformHouseholdPage(
                      eToken: _token,
                      itnForDelivery: _itnForDelivery,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(spacer2),
              child: Column(
                children: [
                  DigitCard(
                    children: [
                      Text(
                        'Household Details',
                        style: textTheme.headingXl.copyWith(
                          color: theme.colorTheme.primary.primary2,
                        ),
                      ),
                      const SizedBox(height: spacer2),
                      _kv('Household Head', headName),
                      _kv('Member Count', memberCount.toString().padLeft(2, '0')),
                      _kv('Number Of ITN For Delivery', _itnForDelivery.toString()),
                    ],
                  ),
                  const SizedBox(height: spacer2),
                  DigitCard(
                    children: [
                      _kv('Mobile Number', mobileNumber?.isNotEmpty == true ? mobileNumber! : '--'),
                      _kv('E-Token', _token),
                    ],
                  ),
                  const SizedBox(height: spacer2),
                  DigitCard(
                    children: [
                      Container(
                        width: double.infinity,
                        color: Colors.red[700],
                        padding: const EdgeInsets.all(spacer2),
                        child: Text(
                          'Ensure that $_itnForDelivery Bednets are given to $headName and proper Health Talk is provided!',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: spacer2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(key, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: spacer2),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
