# Lumina Reserve — 美容室予約管理システム(仕様リポジトリ)

実務プロジェクト応用編 Project 01。架空のビューティーテック企業「株式会社Lumina」の美容室予約管理システムを、**要件定義とGitHub Issuesだけを頼りに**、AI駆動(Claude Code / Codex)で実装するプロジェクトです。

このリポジトリには**仕様(ドキュメント・issue定義・スキル)だけ**が入っています。実装コードは、あなたがこのテンプレートから作る自分のリポジトリに書きます。

## ストーリー

株式会社Luminaは、都内で美容室「Lumière(リュミエール)」1店舗を運営しています。予約管理は電話と紙台帳で、ダブルブッキングや無断キャンセルの管理に悩んでいます。

あなたは**Luminaに入社した1人目のエンジニア**です。手元にあるのは、店長へのヒアリングを経てまとめられた要件定義書・DB設計書・API設計書・画面定義書と、マイルストーンに分割されたissueだけ。ここから予約システム「Lumina Reserve」のMVPを1人で作り上げます。

- 顧客はWebでメニューとスタッフを選び、30分刻みの空き枠から予約する
- スタッフと店長は予約ボードで1日の予約を管理し、電話予約もその場で登録する
- 二重予約はトランザクションで**絶対に**防ぐ — このプロジェクトの心臓部です

## 学べること

- 空き枠計算・ステータス遷移などの**ドメインロジック**の設計と実装
- `SELECT FOR UPDATE` による**トランザクション制御**と競合テスト
- customer / staff / admin の**ロール別アクセス制御**
- 仕様書とissueを起点にAIへ的確に依頼し、出力に責任を持つ**AI駆動開発の型**

## このリポジトリの使い方

前提: [GitHub CLI(gh)](https://cli.github.com/) と jq、Docker、Node.js(または選択スタックのランタイム)。

1. **テンプレートから自分のリポジトリを作る**
   このページ右上の「Use this template」→「Create a new repository」で、自分のアカウントにリポジトリを作ります(publicにするとポートフォリオとして共有しやすいです)。
2. **cloneしてghの認証を確認する**
   ```bash
   git clone https://github.com/<あなたのアカウント>/<リポジトリ名>.git
   cd <リポジトリ名>
   gh auth status || gh auth login
   ```
3. **issueを複製する**
   Claude Codeで `.claude/skills/setup-github-project` スキルの手順に従うか、直接実行します。
   ```bash
   ./scripts/setup_issues.sh
   ```
   label 5種、milestone 4件、issue 27件(必須24+発展3)が自分のリポジトリに作成されます。
4. **M1のissueから開始する**
   進め方の全体像は [docs/development-flow.md](./docs/development-flow.md) を読んでください。Claude Codeを使う場合は、最初に `.claude/skills/project-onboarding` スキルを読ませると立ち上がりがスムーズです。

## ドキュメント一覧

実装中はここが「正」です。迷ったら必ず戻ってきてください。

| ドキュメント | 内容 |
|---|---|
| [docs/requirements.md](./docs/requirements.md) | 要件定義書。機能要件(Must/Should/Could)、ビジネスルール、ユースケース、用語集 |
| [docs/database.md](./docs/database.md) | DB設計書。ER図、全12テーブルの定義、二重予約防止の方針、ステータス遷移 |
| [docs/api.md](./docs/api.md) | API設計書。全エンドポイント、認証方式(Cookie + JWT)、エラーコード、主要APIのJSON例 |
| [docs/screens.md](./docs/screens.md) | 画面定義書。画面一覧(C-xx / A-xx)、予約フロー・予約ボードの構成、画面遷移図 |
| [docs/infra.md](./docs/infra.md) | インフラ設計書。docker compose構成、本番想定AWS構成図、コスト注意 |
| [docs/development-flow.md](./docs/development-flow.md) | 開発の進め方。issue駆動、ブランチ規約、Definition of Done、セルフレビュー観点 |

## 推奨スタック

仕様はスタック非依存です。カリキュラムで学んだ次の組み合わせを推奨します(それ以外も自由です)。

| レイヤー | 選択肢 |
|---|---|
| バックエンド | NestJS + Prisma / Spring Boot + JPA / FastAPI + SQLAlchemy / Laravel + Eloquent / Gin + GORM / Rails + Active Record |
| フロントエンド | React + Vite + TypeScript |
| DB / ミドルウェア | PostgreSQL 16、MailHog(docker compose) |

## 所要目安

**6〜8週間**(週10〜15時間想定)。マイルストーン構成: M1 認証と管理基盤(7 issues) → M2 シフトと空き枠(5) → M3 予約コア(7) → M4 運用と仕上げ(5) + 発展課題(3)。

## 関連リンク

- カリキュラム「実務プロジェクト応用編」: カリキュラムサイトの `/advanced/` セクション(SNS開発完了者向けPhase 10)
- カリキュラム本体リポジトリ: https://github.com/dik-ab/school-curriculum-platform
- 続編プロジェクト: Lumina ID(共通認証基盤 / Cognito)、Lumina Notify(メッセージ配信基盤 / SQS)

## ライセンス

MIT License([LICENSE](./LICENSE))
