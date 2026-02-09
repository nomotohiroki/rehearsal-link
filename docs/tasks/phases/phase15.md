# Phase 15: 機能拡張とUI改善 (Feature & UI Refinement)

## 概要
ユーザーからのフィードバックに基づき、ライトモード時の視認性向上、エクスポート機能の明確化、および文字起こし対象の拡大を行います。これらは既存機能の使い勝手を向上させるための重要な改善です。

## タスク一覧

### 1. UIの視認性向上
- [ ] **ライトモード時の波形カラー調整**
    - **現状**: ライトモードにおいて、会話(Conversation)、無音(Silence)、演奏(Performance)のセグメント色分けのコントラストが低く、判別が困難。
    - **対応**: `WaveformView` および関連するカラー定義を見直し、ライトモードでも明確に区別できる配色（または境界線の強化）を適用する。アクセシビリティコントラスト比を考慮する。

### 2. 機能拡張
- [ ] **演奏セグメントの文字起こし対応**
    - **現状**: 文字起こし機能（Batch Transcribe含む）は「会話(Conversation)」セグメントのみを対象としている。
    - **対応**: ユーザーが演奏中のMCや歌詞のメモ等を残せるよう、「演奏(Performance)」セグメントも文字起こしおよびBatch Transcribeの対象に含めるようにロジックを変更する。

### 3. UI表記の改善
- [ ] **エクスポートボタンの拡張子表記**
    - **現状**: "Export Text (.txt)" には拡張子があるが、"Export Performance" や "Export Conversation" にはない。
    - **対応**: ユーザーが出力形式を直感的に理解できるよう、ボタンラベルを以下のように変更する。
        - "Export Performance" -> "Export Performance (.m4a)"
        - "Export Conversation" -> "Export Conversation (.m4a)"
