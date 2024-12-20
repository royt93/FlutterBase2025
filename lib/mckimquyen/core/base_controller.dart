import 'package:get/get.dart';

class BaseController extends GetxController {}

class AppLoading {
  AppLoading(
    this.isLoading,
    this.isSuccess,
  );

  bool isLoading;
  bool isSuccess;
}
