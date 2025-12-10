import 'package:flutter/foundation.dart';

class UiRouter {
  static final UiRouter _instance = UiRouter._internal();
  factory UiRouter() => _instance;
  UiRouter._internal();

  final ValueNotifier<int> index = ValueNotifier<int>(0);
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  void go(int i, {int max = 15}) {
    index.value = i. clamp(0, max - 1);
  }

  void setUnread(int count) {
    unread.value = count;
  }
}