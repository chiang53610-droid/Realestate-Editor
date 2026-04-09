# TODOS

## 設計改善

### TODO-D01: 首頁 → OneTapScreen 淡入黑色過渡動畫
**What:** 在 HomeScreen 導航到 OneTapScreen 時，加入自訂 PageRoute fade-to-black 動畫。
**Why:** 目前用戶從白底淺色漸層首頁直接跳入 #121212 純黑，視覺衝擊明顯。這會在 TestFlight 回饋中被提到。
**Pros:** 消除主題切換的突兀感，讓 EditorTheme 的深色沉浸感有更好的進場鋪墊。
**Cons:** 約 20 行自訂 PageRoute 程式碼，需確認 iOS back-swipe gesture 的動畫相容性。
**Context:** HomeScreen 使用 AppTheme（淺色），OneTapScreen/EditorScreen 使用 EditorTheme（深色）。過渡動畫只需要在進入深色畫面時加，退出時用系統預設即可。
**Depends on:** 無。

### TODO-D02: 撰寫 DESIGN.md 記錄 EditorTheme
**What:** 建立 `DESIGN.md`，記錄 EditorTheme 的顯色系統、token 使用規則、組件設計決策。
**Why:** 目前設計規格只存在 `editor_theme.dart` 的程式碼註解中，沒有可供參考的設計文件。下一個開發者（或 3 個月後的自己）很難快速了解設計意圖。
**Pros:** 讓 /plan-design-review 等 gstack 工具有設計基準可參考，提升審查精確度。
**Cons:** 需要花 1-2 小時整理現有設計決策並記錄。
**Context:** EditorTheme 參考 CapCut/DaVinci Resolve 深色語言。目前定義了 bg/surface/surfaceCard/surfaceRaised 四層深度、accent cyan、accentGold/Red/Green、文字三階層。
**Depends on:** 無。
