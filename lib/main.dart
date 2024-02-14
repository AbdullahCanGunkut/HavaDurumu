import 'package:path_provider/path_provider.dart';

import 'weatherAPI.dart';
import 'ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();//Widgets'ların temel verilerini kurar.
  initializeDateFormatting('tr_TR');//Tarihten çekeceğimiz verilerin hangi dilde olacağını ayarladı.
  print(await initaliaze_API());
  runApp(const MyHomePage(title: "Hava Durumu"));
}
