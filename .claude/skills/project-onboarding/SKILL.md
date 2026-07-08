---
name: project-onboarding
description: Lumina Reserveプロジェクトの開始時に読むオンボーディング。リポジトリの前提、docsを読む順番、着手前に確認すべきことをまとめる。プロジェクトに初めて触れるとき、または文脈を失ったときに使う。
---

# Project Onboarding — Lumina Reserve

## まず把握すること

- このプロジェクトは美容室「Lumière」の予約管理システム「Lumina Reserve」を、仕様リポジトリのdocsとissueだけを頼りに実装する課題です。
- 仕様リポジトリには実装コードを置きません。実装は受講者自身のリポジトリ(このテンプレートから作成)で行います。
- 仕様の「正」は `docs/requirements.md` です。ドキュメント間で矛盾があればrequirements.mdを優先します。
- スタックは自由です(推奨: NestJS / Spring Boot / FastAPI / Laravel / Gin / Rails + React)。**受講者がどのスタックを選んだかを最初に確認してください。**

## docsを読む順番

| 順 | ドキュメント | 読む目的 |
|---|---|---|
| 1 | `docs/requirements.md` | 機能要件(F-1〜F-9)、ビジネスルール(24時間ルール、30分刻み、当日+60分)、用語集 |
| 2 | `docs/database.md` | 全12テーブルの定義、ステータス遷移、二重予約防止の方針 |
| 3 | `docs/api.md` | エンドポイント一覧、Cookie + JWT認証、エラーコード(`code`)の一覧 |
| 4 | `docs/screens.md` | 画面ID(C-01〜C-11、A-01〜A-10)と画面遷移 |
| 5 | `docs/infra.md` | docker compose(PostgreSQL + MailHog)、本番想定AWS構成 |
| 6 | `docs/development-flow.md` | 1 issue = 1 branch = 1 PR、Definition of Done、セルフレビュー観点 |

すべてを暗記する必要はありません。「どこに何が書いてあるか」を掴み、実装中に該当セクションへ戻れれば十分です。

## 着手前に受講者と確認すること

1. スタック(バックエンド言語・ORM・テストフレームワーク)は何か
2. `gh auth status` が通るか、issueの複製は済んでいるか(まだならこの後 setup-github-project スキルで複製する)
3. docker composeでPostgreSQLとMailHogが起動するか
4. どのissueから始めるか(原則M1-01から番号順)

## このプロジェクト固有の注意

- 日時の扱い: DBはUTC(`TIMESTAMPTZ`)、営業時間・シフトはJSTの `TIME`、APIはISO 8601(+09:00)。混同するとM2で必ず事故ります。
- 空き枠計算と二重予約防止には専用スキル `reservation-domain` があります。M2-04、M3-01の着手前に必ず読んでください。
- 名前(テーブル・カラム・パス・JSONキー・エラーコード)はdocsの表記に一字一句合わせます。「より良い名前」への変更は禁止です。
