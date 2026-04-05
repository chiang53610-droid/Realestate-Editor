import 'package:image_picker/image_picker.dart';

class VideoPickerService {
  final ImagePicker _picker = ImagePicker();

  // 從相簿選擇一段影片
  Future<XFile?> pickOneVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    return video;
  }

  // 從相機錄製一段影片
  Future<XFile?> recordVideo() async {
    final video = await _picker.pickVideo(source: ImageSource.camera);
    return video;
  }
}
