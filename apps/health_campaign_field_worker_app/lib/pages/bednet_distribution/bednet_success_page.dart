import 'package:flutter/material.dart';

import '../../router/app_router.dart';

class BednetSuccessPage extends StatelessWidget {
  final String eToken;
  final int itnForDelivery;

  const BednetSuccessPage({
    super.key,
    required this.eToken,
    required this.itnForDelivery,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final successBlockHeight = screenHeight * 0.30;
    const primaryOrange = Color(0xFFCC4C02);
    const headerBlue = Color(0xFF005A7A);

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Container(
            height: kToolbarHeight,
            color: headerBlue,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Row(
              children: [
                Icon(Icons.menu, color: Colors.white, size: 20),
                Spacer(),
                Text(
                  'Help',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                SizedBox(width: 4),
                Icon(Icons.help_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Settlement One',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFE6E6E6),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: successBlockHeight,
                          color: const Color(0xFF2E9138),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 20,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  'Give - $itnForDelivery Bednets',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 50 / 2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 52,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'E-Token',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34 / 2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                eToken,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 62 / 2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.center,
                          child: Text(
                            'Bednets Delivered Successfully.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryOrange,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'View Household Details',
                              style: TextStyle(fontSize: 28 / 2, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryOrange,
                              side: const BorderSide(color: primaryOrange),
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => context.router.replaceAll([HomeRoute()]),
                            child: const Text(
                              'Back to Search',
                              style: TextStyle(fontSize: 28 / 2, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
