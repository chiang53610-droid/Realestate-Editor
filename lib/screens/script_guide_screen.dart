import 'package:flutter/material.dart';
import '../models/shooting_script.dart';
import 'camera_screen.dart';

class ScriptGuideScreen extends StatelessWidget {
  const ScriptGuideScreen({super.key});

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
                  '選擇模板，跟著腳本拍攝',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '拍攝時會有 AI 提詞機引導你說什麼',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),

          // 模板選擇列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ScriptTemplates.all.length,
              itemBuilder: (context, index) {
                final script = ScriptTemplates.all[index];
                return _buildTemplateCard(context, script);
              },
            ),
          ),

          // 底部「自由拍攝」按鈕（不使用腳本）
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  );
                },
                icon: const Icon(Icons.videocam),
                label: const Text('自由拍攝（無腳本）', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 單一模板卡片
  Widget _buildTemplateCard(BuildContext context, ShootingScript script) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showScriptDetail(context, script),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // 左側圖示
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.description, size: 28, color: Colors.blueAccent),
              ),
              const SizedBox(width: 14),

              // 中間文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      script.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      script.description,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 6),
                    // 小標籤
                    Row(
                      children: [
                        _buildInfoChip('${script.steps.length} 站', Colors.blue),
                        const SizedBox(width: 6),
                        _buildInfoChip('${script.totalDuration} 秒', Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }

  /// 小標籤元件
  Widget _buildInfoChip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color[700], fontWeight: FontWeight.bold),
      ),
    );
  }

  /// 點擊模板 → 顯示步驟詳情底部彈窗
  void _showScriptDetail(BuildContext context, ShootingScript script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // 拖曳把手
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 標題區
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      script.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildInfoChip('${script.steps.length} 站', Colors.blue),
                  const SizedBox(width: 6),
                  _buildInfoChip('${script.totalDuration} 秒', Colors.orange),
                ],
              ),
            ),

            const Divider(),

            // 步驟列表
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: script.steps.length,
                itemBuilder: (_, index) {
                  final step = script.steps[index];
                  return _buildStepRow(index + 1, step);
                },
              ),
            ),

            // 底部「開始拍攝」按鈕
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx); // 關閉底部彈窗
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraScreen(script: script),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam, size: 28),
                  label: const Text('依照此腳本開始拍攝', style: TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 單一步驟的行
  Widget _buildStepRow(int number, ScriptStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步驟編號
          CircleAvatar(
            backgroundColor: Colors.blueAccent,
            radius: 16,
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),

          // 步驟內容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${step.durationSecs} 秒',
                        style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.description,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
