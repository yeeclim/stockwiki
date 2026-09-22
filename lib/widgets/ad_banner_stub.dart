import 'package:flutter/widgets.dart';

/// 웹이 아닌 플랫폼에는 AdSense 가 없다(앱은 AdMob 을 써야 한다).
class AdBanner extends StatelessWidget {
  const AdBanner({super.key, required this.slot});

  final String slot;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
