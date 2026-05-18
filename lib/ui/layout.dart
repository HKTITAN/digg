import 'package:flutter/widgets.dart';

bool isCompactWidth(BuildContext context) => MediaQuery.sizeOf(context).width < 390;

bool isNarrowWidth(BuildContext context) => MediaQuery.sizeOf(context).width < 340;
