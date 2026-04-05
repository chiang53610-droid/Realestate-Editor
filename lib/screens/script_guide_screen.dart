import 'package:flutter/material.dart';

class ScriptGuideScreen extends StatelessWidget {
  const ScriptGuideScreen({super.key});

  // 預設的拍攝腳本步驟
  static const List<Map<String, String>> _steps = [
    {
      'title': '開場介紹',
      'duration': '15 秒',
      'description': '站在房屋門口，面對鏡頭自我介紹，說明物件地址與特色。',
      'tip': '保持微笑、語速放慢，讓觀眾記住你。',
    },
    {
      'title': '客廳全景',
      'duration': '20 秒',
      'description': '從大門走進客廳，緩慢環繞拍攝，展示空間大小與採光。',
      'tip': '手機橫拿、走路放慢，避免畫面晃動。',
    },
    {
      'title': '廚房介紹',
      'duration': '15 秒',
      'description': '拍攝廚房設備與檯面，介紹廚具品牌或特殊設計。',
      'tip': '開燈拍攝，特寫重點設備。',
    },
    {
      'title': '臥室展示',
      'duration': '15 秒',
      'description': '拍攝主臥室空間，展示衣櫃、窗景。',
      'tip': '先拍全景，再拍窗外景觀做為亮點。',
    },
    {
      'title': '衛浴空間',
      'duration': '10 秒',
      'description': '簡短展示衛浴設備與空間。',
      'tip': '注意鏡面反射，避免拍到自己。',
    },
    {
      'title': '陽台 / 景觀',
      'duration': '15 秒',
      'description': '走到陽台拍攝戶外景觀，強調周邊環境優勢。',
      'tip': '白天拍攝效果最好，展示遠景。',
    },
    {
      'title': '結尾呼籲',
      'duration': '10 秒',
      'description': '面對鏡頭做結尾，邀請觀眾預約看房，提供聯絡方式。',
      'tip': '語氣親切有力，搭配 App 自動生成的名片片尾。',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍攝腳本指引'),
      ),
      body: Column(
        children: [
          // 頂部說明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.blue[50],
            child: const Column(
              children: [
                Icon(Icons.tips_and_updates, size: 36, color: Colors.blueAccent),
                SizedBox(height: 8),
                Text(
                  '照著以下 7 個步驟拍攝',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '預計總時長約 100 秒，拍完後回首頁選擇影片一鍵剪輯',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 步驟列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return _buildStepCard(index + 1, step);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int number, Map<String, String> step) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左邊的步驟編號圓圈
            CircleAvatar(
              backgroundColor: Colors.blueAccent,
              radius: 18,
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // 右邊的內容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題 + 建議秒數
                  Row(
                    children: [
                      Text(
                        step['title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          step['duration']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 說明文字
                  Text(
                    step['description']!,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 6),

                  // 小提示
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          step['tip']!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
