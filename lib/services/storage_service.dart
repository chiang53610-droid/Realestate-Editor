import 'package:shared_preferences/shared_preferences.dart';
import '../models/work_item.dart';
import '../models/business_card.dart';

class StorageService {
  static const String _key = 'my_works';
  static const String _cardKey = 'business_card';

  // 讀取所有作品紀錄
  Future<List<WorkItem>> loadWorks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return [];
    return WorkItem.decodeList(jsonString);
  }

  // 新增一筆作品紀錄
  Future<void> saveWork(WorkItem work) async {
    final works = await loadWorks();
    works.insert(0, work); // 最新的排最前面
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, WorkItem.encodeList(works));
  }

  // 刪除一筆作品紀錄
  Future<void> deleteWork(String id) async {
    final works = await loadWorks();
    works.removeWhere((w) => w.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, WorkItem.encodeList(works));
  }

  // 儲存名片資料
  Future<void> saveBusinessCard(BusinessCard card) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cardKey, card.encode());
  }

  // 讀取名片資料
  Future<BusinessCard> loadBusinessCard() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cardKey);
    if (jsonString == null) return const BusinessCard();
    return BusinessCard.decode(jsonString);
  }
}
