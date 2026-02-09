# Phase 14: Apple HIG & Liquid Glass UI Refinement

## 概要
AppleのHuman Interface Guidelines (HIG) および "Liquid Glass" (Modern macOS Design) の原則に基づき、アプリケーションのUI/UXを刷新します。標準コンポーネントを最大限活用し、システムネイティブな質感（Translucency, Vibrancy）と流動性を取り入れます。

## 前提
- **Target OS**: macOS 26 (Tahoe) / iOS 26
- **Design Reference**: Apple HIG, Liquid Glass guidelines
- **Focus**: `NavigationSplitView`, Material effects, SF Symbols, Typography

## タスク一覧

### 1. レイアウト構造の刷新 (Navigation & Window)
- [ ] **NavigationSplitViewへの移行**
    - **内容**: `MainView` のレイアウトを `NavigationView` (Deprecated) やカスタムHStackから、最新の `NavigationSplitView` に変更する。
    - **目的**: macOS標準のサイドバー挙動（Collapsible, Translucent）とツールバー統合を自動的に得るため。
    - **詳細**:
        - Sidebar: ファイル/プロジェクト管理、あるいはインスペクタ（現在は右側だが、HIG的には左側、または右側のInspectorパネルとしての標準実装を検討）
        - Detail: 波形編集エリア

### 2. マテリアルと背景の適用 (Materials & Vibrancy)
- [ ] **Window Background & Materials**
    - **内容**: 背景色固定（`Color.black`等）を廃止し、標準の `.background(.background)` や `.background(.thinMaterial)` / `.ultraThinMaterial` を適用する。
    - **場所**:
        - インスペクタパネル（右側）
        - トランスポートバー（下部または上部フローティング）
        - サイドバー

### 3. ツールバーとアイコンの標準化 (Toolbar & Icons)
- [ ] **Unified Toolbarの採用**
    - **内容**: ウィンドウタイトルとツールバーが一体化した "Unified" スタイルを適用する（SwiftUIではデフォルトだが、明示的な配置を確認）。
    - **項目**: 再生コントロール、ツール切り替え、エクスポートボタンを `ToolbarItem(placement: ...)` で適切に配置。
    - **アイコン**: SF Symbols の最新バージョン（階層化カラー、アニメーション対応）を確認し、適切なWeightとScaleで適用する。

### 4. コントロールとタイポグラフィの調整 (Controls & Typography)
- [ ] **標準コントロールの採用**
    - **内容**: カスタムボタンデザインを極力減らし、`.buttonStyle(.bordered)` や `.buttonStyle(.plain)` などの標準スタイルを使用する。
    - **目的**: システムのフォーカスリングやホバー効果、Liquid Glassの質感を自動的に適用させるため。
- [ ] **Dynamic Type & Typography**
    - **内容**: 固定フォントサイズを廃止し、`.font(.headline)`, `.font(.body)`, `.font(.caption)` などのセマンティックな指定に統一する。

### 5. ダークモードとアクセシビリティの検証
- [ ] **Color Semantic Audit**
    - **内容**: 色指定をシステムカラー（`.blue`, `.secondary` 等）またはAsset CatalogのSemantic Colorに統一し、ライトモード/ダークモード双方で美しく見えるか確認する。特に波形のコントラスト比に注意。

## 参考資料
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- [Human Interface Guidelines - macOS](https://developer.apple.com/design/human-interface-guidelines/macos)
