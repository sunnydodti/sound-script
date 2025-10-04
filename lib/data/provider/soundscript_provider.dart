// import 'package:flutter/material.dart';
// import 'package:hive_ce/hive.dart';

// import '../constants.dart';
// import '../../models/short_url.dart';
// import '../../models/url_history.dart';

// class UrlProvider with ChangeNotifier {
//   UrlProvider() {
//     loadUrls();
//   }

//   final List<ShortUrl> _urls = [];

//   List<ShortUrl> get urls => List.unmodifiable(_urls);

//   Future<void> loadUrls() async {
//     final box = Hive.box(Constants.box);
//     _urls.clear();
//     final urlHistoryMap = box.get(Constants.urlHistoryKey, defaultValue: {
//       'shortUrls': [],
//     });
//     final urlHistory =
//         UrlHistory.fromMap(Map<String, dynamic>.from(urlHistoryMap));
//     _urls.addAll(urlHistory.shortUrls);
//     notifyListeners();
//   }

//   Future<void> addUrl(String shortened, String original) async {
//     final box = Hive.box(Constants.box);
//     final newUrl = ShortUrl(originalUrl: original, shortUrl: shortened);
//     _urls.add(newUrl);

//     final urlHistory = UrlHistory(shortUrls: _urls);
//     await box.put(Constants.urlHistoryKey, urlHistory.toMap());
//     notifyListeners();
//   }

//   Future<void> deleteUrl(int index) async {
//     final box = Hive.box(Constants.box);
//     _urls.removeAt(index);

//     final urlHistory = UrlHistory(shortUrls: _urls);
//     await box.put(Constants.urlHistoryKey, urlHistory.toMap());
//     notifyListeners();
//   }

//   static Future<void> addNewUrl(ShortUrl url) async {
//     final box = Hive.box(Constants.box);
//     final urlHistoryMap = box.get(Constants.urlHistoryKey, defaultValue: {
//       'shortUrls': [],
//     });
//     final urlHistory =
//         UrlHistory.fromMap(Map<String, dynamic>.from(urlHistoryMap));
//     urlHistory.shortUrls.add(url);
//     await box.put(Constants.urlHistoryKey, urlHistory.toMap());
//   }
// }
