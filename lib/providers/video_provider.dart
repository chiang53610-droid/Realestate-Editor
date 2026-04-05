import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VideoProvider extends ChangeNotifier {
  // 使用者選擇的影片列表
  final List<XFile> _selectedVideos = [];
  List<XFile> get selectedVideos => _selectedVideos;

  // 三個 AI 功能的開關
  bool _aiRemoveFiller = false;
  bool get aiRemoveFiller => _aiRemoveFiller;

  bool _aiSubtitle = false;
  bool get aiSubtitle => _aiSubtitle;

  bool _aiBusinessCard = false;
  bool get aiBusinessCard => _aiBusinessCard;

  // 新增一段影片
  void addVideo(XFile video) {
    _selectedVideos.add(video);
    notifyListeners();
  }

  // 移除一段影片
  void removeVideo(int index) {
    _selectedVideos.removeAt(index);
    notifyListeners();
  }

  // 清空所有已選影片
  void clearVideos() {
    _selectedVideos.clear();
    notifyListeners();
  }

  // 切換 AI 去冗言
  void toggleRemoveFiller() {
    _aiRemoveFiller = !_aiRemoveFiller;
    notifyListeners();
  }

  // 切換 AI 上字幕
  void toggleSubtitle() {
    _aiSubtitle = !_aiSubtitle;
    notifyListeners();
  }

  // 切換名片片尾
  void toggleBusinessCard() {
    _aiBusinessCard = !_aiBusinessCard;
    notifyListeners();
  }

  // 全部重置（匯出完成後）
  void reset() {
    _selectedVideos.clear();
    _aiRemoveFiller = false;
    _aiSubtitle = false;
    _aiBusinessCard = false;
    notifyListeners();
  }
}
