import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import '../constants.dart';

class NavProvider extends ChangeNotifier {
  late Box box;
  late int _index;

  NavProvider() {
    box = Hive.box(Constants.box);
    _index = box.get(Constants.indexKey, defaultValue: 1);
  }


  int get index => _index;

  void setIndex(int index) {
    _index = index;
    if (box.isOpen) box.put(Constants.indexKey, index);
    notifyListeners();
  }
}
