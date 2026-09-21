# BatteryCheck

macOS 選單列小工具：顯示已配對藍牙鍵盤／滑鼠電量。

## 功能

- 選單列左側為裝置圖示（鍵盤／滑鼠），右側為電量百分比
- 每天約 **09:30**（本機時區）自動更新
- 若 09:30 當時未開機／休眠，喚醒後每 **30 分鐘**補查，成功後恢復每日排程
- 點選選單「立即更新電量」可手動刷新

## 需求

- macOS 14+
- Xcode 15+（建議使用目前安裝的 Xcode）

## 建置與執行

```bash
cd battery-check
xcodegen generate
open BatteryCheck.xcodeproj
```

在 Xcode 選 target `BatteryCheck` → Run。

或命令列：

```bash
xcodegen generate
xcodebuild -scheme BatteryCheck -destination 'platform=macOS' build
```

## 測試

```bash
xcodegen generate
xcodebuild -scheme BatteryCheck -destination 'platform=macOS' test
```

- **Unit tests**（`BatteryCheckCoreTests`）：排程邏輯、電量文字格式、裝置類型推論
- **Integration tests**（`BatteryCheckIntegrationTests`）：以假資料驅動 `AppModel` 刷新流程；並對 IORegistry 讀取做不拋錯煙霧測試（不要求實際裝置）

## 權限說明

App 以非 App Sandbox 建置並宣告藍牙用途說明。電量來源依序為：IORegistry `BatteryPercent`、已連線藍牙裝置清單，以及 BLE 標準 Battery Service（0x180F）。若系統提示藍牙權限，請允許。

## 專案結構

- `Sources/BatteryCheckCore`：排程、模型、IORegistry 電量讀取
- `Sources/BatteryCheckApp`：選單列 UI（SwiftUI `MenuBarExtra`）
- `Tests/`：單元與整合測試
