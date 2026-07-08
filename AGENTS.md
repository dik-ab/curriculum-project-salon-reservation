# AGENTS.md — Lumina Reserve プロジェクトガイド(Codex等のAIエージェント向け)

## このリポジトリの性質

- ここは美容室予約管理システム「Lumina Reserve」のリポジトリで、**2つの顔**があります。テンプレート元(`dik-ab/curriculum-project-salon-reservation`)は仕様書のみのリポジトリで、実装コードはコミットされません。一方、受講者が「Use this template」から作ったリポジトリでは、**このリポジトリ自体に実装コードを追加していきます**(`docs/` の仕様はそのまま残し、実装と共存させます)。
- あなた(AI)として作業する場合: リモートが `dik-ab/` 以外なら受講者の実装リポジトリとして振る舞い、実装・テスト・コミットを普通に行ってください。実装を手伝う相手は受講者であり、AIの出力の責任は受講者が持ちます。
- 仕様の「正」は `docs/` です。このリポジトリ内のドキュメント同士が矛盾して見える場合は `docs/requirements.md` を最優先し、矛盾はissueとして報告してください。

## docsを読む順番

1. `docs/requirements.md` — 要件・ビジネスルール・用語集。**最初に必ず読む**
2. `docs/database.md` — テーブル定義・ステータス遷移・二重予約防止の方針
3. `docs/api.md` — エンドポイント・エラーコード・認証方式(Cookie + JWT)
4. `docs/screens.md` — 画面ID(C-xx / A-xx)と遷移
5. `docs/infra.md` — ローカル構成と本番想定AWS構成
6. `docs/development-flow.md` — issue駆動の進め方・Definition of Done

## 実装を手伝うときの原則

- **仕様に書いていないことを勝手に決めない。** 選択肢を挙げて受講者に確認する。決めた内容はissueコメントかPRに記録するよう促す。
- テーブル名・カラム名・APIパス・JSONキー・エラーコードは `docs/` の表記と**一字一句一致**させる。独自の命名に「改善」しない。
- 空き枠計算(M2-04)と二重予約防止(M3-01)は `.agents/skills/reservation-domain` を読んでから実装する。
- 受入条件に「テストで検証」とある項目は、テストなしで完了扱いにしない。
- コードを生成したら、受講者が理解すべきポイント(トランザクション境界、境界値など)を短く説明する。丸投げされたら「レビューは受講者の責任」であることを思い出させる。

## スキル一覧と使いどころ

スキルは `.agents/skills/` にあります(`.claude/skills/` と同一内容のミラーです)。

| スキル | 使いどころ |
|---|---|
| `.agents/skills/project-onboarding` | プロジェクト開始時・文脈を失ったとき。全体像の再取得 |
| `.agents/skills/setup-github-project` | 最初の1回。label / milestone / issueを受講者のリポジトリへ複製 |
| `.agents/skills/issue-workflow` | 各issueの着手時。読解→仕様特定→計画→実装→テスト→PRの型 |
| `.agents/skills/spec-compliance` | PR作成前。docsとの突合チェックリストを出力 |
| `.agents/skills/reservation-domain` | M2-04・M3-01と、空き枠/予約に関わるすべての実装 |
