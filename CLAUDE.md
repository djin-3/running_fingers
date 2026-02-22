# CLAUDE.md

## プロジェクト概要
指を足に見立ててタップで走るモバイルゲーム「Running Fingers」

## 現在の状況
- Phase 0（環境構築）: 完了
- Phase 1（プロトタイプ）: 完了
- Phase 2（コア機能実装）: 完了
- Phase 3（データ保存・リザルト）: 完了
- **次: Phase 4（UI/UX・エフェクト）**
- 詳細なロードマップはREADME.mdに記載

## 技術スタック
- Flutter / Dart
- データ保存: SharedPreferences（ローカル）
- 本番ターゲット: Android → iOS
- テスト確認: GitHub Pages にWebデプロイ（本番ではWeb版は作らない）

## ビルド・デプロイ
- GitHub Pagesへのデプロイは GitHub Actions で自動（masterへのpush時）
- ローカルPC（Windows）にFlutter SDK環境あり
- このVPS上にはFlutter環境なし（設計・ドキュメント編集のみ）

## ブランチ運用
- メインブランチ: `master`（mainではない）
- 開発は feature ブランチで行い、PRでマージ

## コードの場所
- ゲーム本体: `lib/`
- エントリポイント: `lib/main.dart`
- GitHub Pagesデプロイ設定: `.github/workflows/`

## 開発ルール
- 詳細なゲーム仕様・設計はREADME.mdに記載
- タップ精度が最重要（連打ゲームのため）
- 目標: スイカゲームのように「シンプルだけど面白い」

## 開発指針
- 3ステップ以上のタスクは必ずプランモードで計画してから実装
- バグ修正は応急処置をせず根本原因を特定してから修正
- 変更は最小限に留め、タスク完了前に動作確認を行う

## 自己改善
- ユーザーから修正・指摘を受けたら `tasks/lessons.md` に記録する
- セッション開始時に `tasks/lessons.md` を確認する
