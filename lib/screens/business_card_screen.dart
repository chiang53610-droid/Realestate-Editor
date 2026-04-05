import 'package:flutter/material.dart';
import '../models/business_card.dart';
import '../services/storage_service.dart';
import '../widgets/business_card_preview.dart';

/// 名片片尾編輯頁面
class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  final StorageService _storage = StorageService();

  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();

  int _styleIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCard();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  /// 載入已儲存的名片資料
  Future<void> _loadCard() async {
    final card = await _storage.loadBusinessCard();
    _nameCtrl.text = card.name;
    _titleCtrl.text = card.title;
    _companyCtrl.text = card.company;
    _phoneCtrl.text = card.phone;
    _emailCtrl.text = card.email;
    _lineCtrl.text = card.line;
    _styleIndex = card.styleIndex;
    setState(() => _isLoading = false);
  }

  /// 取得目前表單的 BusinessCard
  BusinessCard get _currentCard => BusinessCard(
        name: _nameCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        line: _lineCtrl.text.trim(),
        styleIndex: _styleIndex,
      );

  /// 儲存名片
  Future<void> _saveCard() async {
    setState(() => _isSaving = true);
    await _storage.saveBusinessCard(_currentCard);
    setState(() => _isSaving = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('名片已儲存！匯出影片時會自動附加片尾'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('名片片尾設定')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('名片片尾設定')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ====== 即時預覽 ======
            _buildPreviewSection(),

            // ====== 樣式選擇 ======
            _buildStyleSelector(),

            const Divider(height: 32),

            // ====== 表單區 ======
            _buildFormSection(),

            // ====== 儲存按鈕 ======
            _buildSaveButton(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// 即時預覽區
  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            '預覽效果',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        // 名片預覽（會跟隨表單即時更新）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: BusinessCardPreview(card: _currentCard),
            ),
          ),
        ),
      ],
    );
  }

  /// 樣式選擇器
  Widget _buildStyleSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '選擇風格',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(BusinessCardStyles.names.length, (index) {
              final isSelected = _styleIndex == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _styleIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1A56DB)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        BusinessCardStyles.names[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 表單區
  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '填寫資料',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _nameCtrl,
            label: '姓名',
            icon: Icons.person,
            hint: '例：王小明',
          ),
          _buildTextField(
            controller: _titleCtrl,
            label: '職稱',
            icon: Icons.badge,
            hint: '例：資深經紀人',
          ),
          _buildTextField(
            controller: _companyCtrl,
            label: '公司名稱',
            icon: Icons.business,
            hint: '例：信義房屋',
          ),
          _buildTextField(
            controller: _phoneCtrl,
            label: '電話',
            icon: Icons.phone,
            hint: '例：0912-345-678',
            keyboardType: TextInputType.phone,
          ),
          _buildTextField(
            controller: _emailCtrl,
            label: 'Email（選填）',
            icon: Icons.email,
            hint: '例：agent@email.com',
            keyboardType: TextInputType.emailAddress,
          ),
          _buildTextField(
            controller: _lineCtrl,
            label: 'LINE ID（選填）',
            icon: Icons.chat,
            hint: '例：wang_agent',
          ),
        ],
      ),
    );
  }

  /// 單一輸入欄位
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}), // 即時更新預覽
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  /// 儲存按鈕
  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveCard,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(
            _isSaving ? '儲存中...' : '儲存名片',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
