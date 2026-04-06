import 'package:flutter/material.dart';
import '../models/shooting_script.dart';
import '../services/storage_service.dart';
import 'camera_screen.dart';
import 'script_editor_screen.dart';

class ScriptGuideScreen extends StatefulWidget {
  const ScriptGuideScreen({super.key});

  @override
  State<ScriptGuideScreen> createState() => _ScriptGuideScreenState();
}

class _ScriptGuideScreenState extends State<ScriptGuideScreen> {
  final StorageService _storage = StorageService();
  List<ShootingScript> _customScripts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomScripts();
  }

  Future<void> _loadCustomScripts() async {
    final scripts = await _storage.loadCustomScripts();
    setState(() {
      _customScripts = scripts;
      _isLoading = false;
    });
  }

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

          // 模板列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ====== 自訂模板區 ======
                      if (_customScripts.isNotEmpty) ...[
                        _buildSectionTitle('我的模板', showAdd: true),
                        const SizedBox(height: 8),
                        ..._customScripts.map((s) => _buildTemplateCard(context, s, isCustom: true)),
                        const SizedBox(height: 16),
                      ],

                      // ====== 新增模板按鈕（沒有自訂模板時顯示在最上方）======
                      if (_customScripts.isEmpty) ...[
                        _buildCreateButton(),
                        const SizedBox(height: 16),
                      ],

                      // ====== 內建模板區 ======
                      _buildSectionTitle('內建模板', showAdd: _customScripts.isNotEmpty),
                      const SizedBox(height: 8),
                      ...ScriptTemplates.all.map((s) => _buildTemplateCard(context, s)),
                    ],
                  ),
          ),

          // 底部「自由拍攝」按鈕
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

  /// 區塊標題 + 新增按鈕
  Widget _buildSectionTitle(String title, {bool showAdd = false}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const Spacer(),
        if (showAdd)
          TextButton.icon(
            onPressed: _navigateToEditor,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('新增'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1A56DB),
            ),
          ),
      ],
    );
  }

  /// 新增模板按鈕（大型卡片樣式）
  Widget _buildCreateButton() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _navigateToEditor,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add, size: 32, color: Color(0xFF1A56DB)),
              ),
              const SizedBox(height: 12),
              const Text(
                '建立自訂腳本模板',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '自訂步驟、秒數和提詞機台詞',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 導航到腳本編輯頁面
  Future<void> _navigateToEditor({ShootingScript? script}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScriptEditorScreen(existingScript: script),
      ),
    );
    if (result == true) {
      _loadCustomScripts();
    }
  }

  /// 單一模板卡片
  Widget _buildTemplateCard(BuildContext context, ShootingScript script, {bool isCustom = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showScriptDetail(context, script, isCustom: isCustom),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // 左側圖示
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isCustom ? Colors.purple[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCustom ? Icons.edit_note : Icons.description,
                  size: 28,
                  color: isCustom ? Colors.purple : Colors.blueAccent,
                ),
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
                    Row(
                      children: [
                        _buildInfoChip('${script.steps.length} 站', Colors.blue),
                        const SizedBox(width: 6),
                        _buildInfoChip('${script.totalDuration} 秒', Colors.orange),
                        if (isCustom) ...[
                          const SizedBox(width: 6),
                          _buildInfoChip('自訂', Colors.purple),
                        ],
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

  /// 點擊模板 → 步驟詳情底部彈窗
  void _showScriptDetail(BuildContext context, ShootingScript script, {bool isCustom = false}) {
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

            // 自訂模板的編輯/刪除按鈕
            if (isCustom)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToEditor(script: script);
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('編輯'),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(ctx, script),
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text('刪除', style: TextStyle(color: Colors.red)),
                    ),
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
                    Navigator.pop(ctx);
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

  /// 確認刪除對話框
  void _confirmDelete(BuildContext sheetCtx, ShootingScript script) {
    showDialog(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除腳本'),
        content: Text('確定要刪除「${script.name}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);       // 關閉對話框
              Navigator.pop(sheetCtx);  // 關閉底部彈窗
              await _storage.deleteCustomScript(script.id);
              _loadCustomScripts();
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(int number, ScriptStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blueAccent,
            radius: 16,
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
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
