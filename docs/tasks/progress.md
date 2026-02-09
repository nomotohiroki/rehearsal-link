# RehearsalLink 進捗管理

このファイルでプロジェクトの現在進行中のタスクを管理します。
完了したフェーズの詳細は [completed.md](./completed.md) を参照してください。

## 進行中のフェーズ



### Phase 13: AIによるテキスト正規化・要約機能 (AI Text Processing)

- [ ] **LLM APIクライアントとプロンプト管理の実装**

    - **内容**: OpenAI, Anthropic, Gemini APIと連携し、文字起こしテキストの正規化 （句読点、誤字修正）および要約（要点、短縮、詳細）を行う機能を実装する。UI実装およびテスト含む。詳細は [phase13.md](./phases/phase13.md) を参照。



## 完了したフェーズ



### Phase 14: Apple HIG & Liquid Glass UI Refinement

- [x] **UI/UXの刷新 (Liquid Glass / Modern macOS)**

    - **内容**: AppleのHIGおよび最新のデザイン原則に基づき、`NavigationSplitView` の採用、Material背景の適用、ツールバーの標準化を行う。詳細は [phase14.md](./phases/phase14.md) を参照。



### Phase 12: 音声認識精度の向上 (Audio Preprocessing)

- [x] **オーディオゲイン正規化処理の実装**

    - **内容**: 音声認識の前処理としてオーディオゲインを正規化し、音量不足による誤判定を防ぐ。詳細は [phase12.md](./phases/phase12.md) を参照。



### Phase 11: 開発環境の整備 (Lint/Format/Hook)
- [x] **Lint/Formatツールの導入と設定**
  - **内容**: SwiftLint, SwiftFormatをインストールし、プロジェクトに適した設定ファイル(.swiftlint.yml等)を作成する。
- [x] **Lefthookの導入と設定**
  - **内容**: Lefthookをインストールし、pre-commitフックでLint, Format, Testを実行するように設定する。

### Phase 10: ユーザーガイドの作成
- [x] **スクリーンショット撮影と機能解説ドキュメントの作成**
  - **内容**: 実際のアプリ操作画面を撮影し、各機能（再生、編集、エクスポート等）の使いかたをまとめたドキュメントを作成する。
... (以下略)