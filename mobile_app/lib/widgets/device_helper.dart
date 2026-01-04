import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';


Future<String> getDeviceId() async {
  final info = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final android = await info.androidInfo;
    return android.id;
  } else if (Platform.isIOS) {
    final ios = await info.iosInfo;
    return ios.identifierForVendor ?? "unknown-ios-device";
  } else {
    return "unknown-device";
  }
}
