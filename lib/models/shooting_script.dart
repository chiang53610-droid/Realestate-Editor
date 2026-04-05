/// 單一拍攝步驟
class ScriptStep {
  final String title;       // 例：客廳全景
  final int durationSecs;   // 建議秒數
  final String description; // 拍攝說明
  final String promptText;  // 提詞機顯示的台詞

  const ScriptStep({
    required this.title,
    required this.durationSecs,
    required this.description,
    required this.promptText,
  });
}

/// 拍攝腳本模板（包含多個步驟）
class ShootingScript {
  final String name;           // 模板名稱
  final String description;    // 模板簡介
  final List<ScriptStep> steps;

  const ShootingScript({
    required this.name,
    required this.description,
    required this.steps,
  });

  int get totalDuration =>
      steps.fold(0, (sum, step) => sum + step.durationSecs);
}

/// 預設的腳本模板庫
class ScriptTemplates {
  static const standard2b1l = ShootingScript(
    name: '標準兩房一廳',
    description: '適合一般公寓，約 100 秒完成拍攝',
    steps: [
      ScriptStep(
        title: '開場介紹',
        durationSecs: 15,
        description: '站在門口，面對鏡頭自我介紹',
        promptText: '大家好，我是 OO 房屋的 XXX，今天帶大家來看這間位於 OO 路的溫馨兩房物件。',
      ),
      ScriptStep(
        title: '客廳全景',
        durationSecs: 20,
        description: '從大門走進客廳，緩慢環繞拍攝',
        promptText: '一進門就是寬敞的客廳，採光非常好，面寬約 X 米，可以放下大型沙發組。',
      ),
      ScriptStep(
        title: '廚房介紹',
        durationSecs: 15,
        description: '拍攝廚房設備與檯面',
        promptText: '廚房配備全新的系統櫃和三機，檯面空間充足，非常適合喜歡下廚的朋友。',
      ),
      ScriptStep(
        title: '主臥室',
        durationSecs: 15,
        description: '拍攝主臥空間與窗景',
        promptText: '主臥室可以擺放標準雙人床，還有大面窗戶，每天起床都能看到好景色。',
      ),
      ScriptStep(
        title: '次臥室',
        durationSecs: 10,
        description: '拍攝次臥空間',
        promptText: '第二間臥室也有不錯的空間，可以當作小孩房或書房使用。',
      ),
      ScriptStep(
        title: '衛浴空間',
        durationSecs: 10,
        description: '簡短展示衛浴設備',
        promptText: '衛浴有乾濕分離設計，設備都保養得很好。',
      ),
      ScriptStep(
        title: '結尾呼籲',
        durationSecs: 10,
        description: '面對鏡頭做結尾',
        promptText: '以上就是今天的物件介紹，有興趣的朋友歡迎私訊或來電預約看房，謝謝大家！',
      ),
    ],
  );

  static const studio = ShootingScript(
    name: '套房 / 開放式',
    description: '適合小坪數套房，約 60 秒完成拍攝',
    steps: [
      ScriptStep(
        title: '開場介紹',
        durationSecs: 10,
        description: '站在門口自我介紹',
        promptText: '大家好，今天帶大家看這間精緻套房，地點便利、機能完善。',
      ),
      ScriptStep(
        title: '室內全景',
        durationSecs: 20,
        description: '從門口慢慢掃過整個空間',
        promptText: '整體空間規劃得很好，雖然是套房格局，但該有的機能一樣不少。',
      ),
      ScriptStep(
        title: '廚房與衛浴',
        durationSecs: 15,
        description: '拍攝廚房角落與衛浴',
        promptText: '廚房設備齊全，衛浴也有乾濕分離，生活品質完全不打折。',
      ),
      ScriptStep(
        title: '結尾呼籲',
        durationSecs: 10,
        description: '面對鏡頭做結尾',
        promptText: '喜歡這間套房的朋友，歡迎預約看房，我是 XXX，感謝收看！',
      ),
    ],
  );

  static const luxury3b = ShootingScript(
    name: '豪華三房兩廳',
    description: '適合大坪數物件，約 140 秒完成拍攝',
    steps: [
      ScriptStep(
        title: '開場介紹',
        durationSecs: 15,
        description: '站在大門口介紹物件',
        promptText: '大家好，今天要介紹的是這間位於 OO 的高級三房物件，坪數寬敞、視野開闊。',
      ),
      ScriptStep(
        title: '玄關與客廳',
        durationSecs: 20,
        description: '從玄關走入客廳全景拍攝',
        promptText: '一進門就是氣派的玄關，客廳面寬超大，可以規劃完整的客餐廳空間。',
      ),
      ScriptStep(
        title: '餐廳區域',
        durationSecs: 15,
        description: '拍攝餐廳與餐廚動線',
        promptText: '餐廳緊鄰廚房，動線流暢，很適合家庭聚餐。',
      ),
      ScriptStep(
        title: '廚房',
        durationSecs: 15,
        description: '拍攝廚房設備',
        promptText: '廚房是中島設計，配備進口品牌家電，料理空間非常充裕。',
      ),
      ScriptStep(
        title: '主臥套房',
        durationSecs: 20,
        description: '拍攝主臥室與主衛浴',
        promptText: '主臥室是套房設計，有獨立衛浴和更衣室，享受飯店級的居住體驗。',
      ),
      ScriptStep(
        title: '次臥一',
        durationSecs: 10,
        description: '拍攝第二間臥室',
        promptText: '第二間臥室空間也很寬敞，採光良好。',
      ),
      ScriptStep(
        title: '次臥二',
        durationSecs: 10,
        description: '拍攝第三間臥室',
        promptText: '第三間房間可以當書房或客房使用，彈性很大。',
      ),
      ScriptStep(
        title: '陽台景觀',
        durationSecs: 15,
        description: '走到陽台拍攝景觀',
        promptText: '陽台視野非常開闊，可以看到 OO 景觀，住在這裡心情每天都很好。',
      ),
      ScriptStep(
        title: '結尾呼籲',
        durationSecs: 10,
        description: '面對鏡頭做結尾',
        promptText: '以上就是這間豪華三房的完整介紹，心動的朋友趕快聯繫我預約看房！',
      ),
    ],
  );

  /// 所有可用模板
  static const List<ShootingScript> all = [standard2b1l, studio, luxury3b];
}
