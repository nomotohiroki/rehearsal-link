# RehearsalLink 進捗管理

このファイルでプロジェクトの現在進行中のタスクを管理します。
完了したフェーズの詳細は [completed.md](./completed.md) を参照してください。

## 進行中のフェーズ

### Phase 15: 機能拡張とUI改善 (Feature & UI Refinement)
- [x] **ライトモード時の波形視認性向上**
    - **内容**: 会話・無音・演奏セグメントの配色を見直し、ライトモードでの区別を明確にする。
- [x] **演奏セグメントの文字起こし対応**
    - **内容**: Batch Transcribe等の対象に演奏セグメントを含めるようロジックを変更する。
- [x] **エクスポートボタンの表記改善**
    - **内容**: Performance/Conversationのエクスポートボタンにファイル拡張子(.m4a)を明記する。
- [x] **AIシステムプロンプトのカスタマイズ機能**
    - **内容**: 設定画面から要約や文字起こし修正用のプロンプトを編集可能にする。
- [ ] **AIモデル一覧への外部リンク追加**
    - **内容**: 設定画面に各AIプロバイダーのモデル一覧ページへのリンクを追加する。
    - 詳細は [phase15.md](./phases/phase15.md) を参照。

### Phase 16: ドキュメントと品質保証 (Documentation & QA)
- [x] **User Guide의全面刷新**
    - **内容**: 最新UIに合わせてガイド記述とスクリーンショットを更新する。
- [ ] **テストコードの拡充**
    - **内容**: テスト不足箇所を特定し、カバレッジを向上させる。
    - 詳細は [phase16.md](./phases/phase16.md) を参照。

## 完了したフェーズ

- **Phase 14**: Apple HIG & Liquid Glass UI Refinement
- **Phase 13**: AIによるテキスト正規化・要約機能 (AI Text Processing)
- **Phase 12**: 音声認識精度の向上 (Audio Preprocessing)
- **Phase 11**: 開発環境の整備 (Lint/Format/Hook)
- **Phase 10**: ユーザーガイドの作成
- **Phase 1〜9**: 基盤実装からUI/UX改善まで (詳細は completed.md 参照)