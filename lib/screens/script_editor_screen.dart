import 'package:flutter/material.dart';
import '../models/shooting_script.dart';
import '../services/storage_service.dart';

/// 自訂腳本編輯頁面 — 新增或編輯腳本模板
class ScriptEditorScreen extends StatefulWidget {
  /// 傳入現有腳本 = 編輯模式；不傳 = 新增模式
  final ShootingScript? existingScript;

  const ScriptEditorScreen({super.key, this.existingScript});

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  final StorageService _storage = StorageService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // 步驟列表（可動態新增/刪除/排序）
  final List<_StepData> _steps = [];

  bool get _isEditMode => widget.existingScript != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final s = widget.existingScript!;
      _nameCtrl.text = s.name;
      _descCtrl.text = s.description;
      for (final step in s.steps) {
        _steps.add(_StepData(
          title: step.title,
          duration: step.durationSecs,
          description: step.description,
          promptText: step.promptText,
        ));
      }
    } else {
      // 新增模式預設給 2 個空步驟
      _steps.add(_StepData(title: '開場介紹', duration: 15, description: '站在門口自我介紹', promptText: ''));
      _steps.add(_StepData(title: '結尾呼籲', duration: 10, description: '面對鏡頭做結尾', promptText: ''));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// 儲存腳本
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showMessage('請輸入模板名稱');
      return;
    }
    if (_steps.isEmpty) {
      _showMessage('至少需要一個步驟');
      return;
    }

    final steps = _steps
        .map((s) => ScriptStep(
              title: s.title.isEmpty ? '未命名' : s.title,
              durationSecs: s.duration,
              description: s.description,
              promptText: s.promptText,
            ))
        .toList();

    final script = ShootingScript(
      id: _isEditMode
          ? widget.existingScript!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: _descCtrl.text.trim().isEmpty
          ? '${steps.length} 個步驟，約 ${steps.fold(0, (sum, s) => sum + s.durationSecs)} 秒'
          : _descCtrl.text.trim(),
      steps: steps,
    );

    if (_isEditMode) {
      await _storage.updateCustomScript(script);
    } else {
      await _storage.addCustomScript(script);
    }

    if (!mounted) return;
    _showMessage(_isEditMode ? '腳本已更新' : '腳本已建立');
    Navigator.pop(context, true); // 回傳 true 表示有變更
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDuration = _steps.fold(0, (sum, s) => sum + s.duration);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '編輯腳本' : '新增腳本'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('儲存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 表單區（可捲動）
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 模板名稱
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: '模板名稱',
                      hintText: '例：三房兩廳含車位',
                      prefixIcon: const Icon(Icons.title, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 模板說明
                  TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      labelText: '簡短說明（選填）',
                      hintText: '例：適合中型物件',
                      prefixIcon: const Icon(Icons.notes, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 步驟列表標題
                  Row(
                    children: [
                      const Icon(Icons.list_alt, size: 20, color: Color(0xFF1A56DB)),
                      const SizedBox(width: 6),
                      const Text(
                        '拍攝步驟',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A56DB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_steps.length} 步 / $totalDuration 秒',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 可拖曳排序的步驟列表
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _steps.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _steps.removeAt(oldIndex);
                        _steps.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildStepCard(index, key: ValueKey('step_$index'));
                    },
                  ),

                  const SizedBox(height: 12),

                  // 新增步驟按鈕
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _steps.add(_StepData(title: '', duration: 15, description: '', promptText: ''));
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('新增步驟', style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 單一步驟卡片
  Widget _buildStepCard(int index, {required Key key}) {
    final step = _steps[index];

    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 步驟標題列
            Row(
              children: [
                // 拖曳把手
                const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                const SizedBox(width: 6),
                // 步驟編號
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 14,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                // 步驟名稱輸入
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: step.title),
                    onChanged: (v) => step.title = v,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '步驟名稱',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                // 刪除按鈕
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.red),
                  onPressed: () => setState(() => _steps.removeAt(index)),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Column(
                children: [
                  // 建議秒數
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      const Text('建議秒數', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: Slider(
                          value: step.duration.toDouble(),
                          min: 5,
                          max: 60,
                          divisions: 11,
                          label: '${step.duration} 秒',
                          onChanged: (v) => setState(() => step.duration = v.round()),
                        ),
                      ),
                      Text(
                        '${step.duration} 秒',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),

                  // 拍攝說明
                  TextField(
                    controller: TextEditingController(text: step.description),
                    onChanged: (v) => step.description = v,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '拍攝說明（例：從門口慢慢走進客廳）',
                      prefixIcon: Icon(Icons.description, size: 16),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),

                  // 提詞機台詞
                  TextField(
                    controller: TextEditingController(text: step.promptText),
                    onChanged: (v) => step.promptText = v,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '提詞機台詞（拍攝時顯示在畫面上）',
                      prefixIcon: Icon(Icons.auto_awesome, size: 16),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
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

/// 步驟暫存資料（可修改的）
class _StepData {
  String title;
  int duration;
  String description;
  String promptText;

  _StepData({
    required this.title,
    required this.duration,
    required this.description,
    required this.promptText,
  });
}
