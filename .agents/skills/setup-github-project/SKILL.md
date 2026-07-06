---
name: setup-github-project
description: scripts/setup_issues.sh を使って、受講者自身のリポジトリにlabel・milestone・issueを複製する手順。テンプレートからリポジトリを作った直後に1回だけ使う。
---

# Setup GitHub Project — issueの複製

テンプレートから作成したリポジトリにはissueがコピーされません(GitHubのテンプレート機能はコードのみ複製します)。`scripts/setup_issues.sh` で label 5種・milestone 4件・issue 27件を複製します。

## 前提の確認

実行前に、次を順に確認してください。

```bash
# 1. gh CLIが入っているか
gh --version

# 2. jqが入っているか
jq --version

# 3. ghの認証が通っているか(通っていなければ gh auth login)
gh auth status

# 4. カレントリポジトリが「自分の」リポジトリか(テンプレート元ではないこと!)
gh repo view --json nameWithOwner -q .nameWithOwner
```

4の出力が `dik-ab/curriculum-project-salon-reservation`(テンプレート元)の場合は実行しないでください。自分のリポジトリのcloneディレクトリで実行します。

## 実行

```bash
./scripts/setup_issues.sh
```

対象リポジトリを明示する場合は引数で渡します。

```bash
./scripts/setup_issues.sh <owner>/<repo>
```

## スクリプトがやること

| 対象 | 内容 | 冪等性 |
|---|---|---|
| label | `feature` `chore` `docs` `test` `advanced` を色・説明付きで作成 | `--force` で常に上書き(再実行安全) |
| milestone | `M1: 認証と管理基盤` 〜 `M4: 運用と仕上げ` を作成 | 同名があればスキップ |
| issue | M1-01〜M4-05の24件+ADV-01〜03の3件を、本文・label・milestone付きで作成 | 同タイトルがあればスキップ |

途中で失敗しても、そのまま再実行すれば作成済みのものはスキップされます。

## 実行後の確認

```bash
gh issue list --limit 30        # 27件あるか
gh api repos/{owner}/{repo}/milestones -q '.[].title'  # M1〜M4があるか
```

GitHub上でM1のissueを開き、本文の「仕様参照」リンクが自分のリポジトリのdocsに繋がることを確認したら、`M1-01` から開発を開始します(`issue-workflow` スキル参照)。

## よくあるトラブル

- `gh: Not Found` → 引数の `owner/repo` が間違っているか、privateリポジトリへの権限不足。`gh auth refresh -s repo` を試す。
- rate limitで途中失敗 → 数分待って再実行(冪等なので安全)。
- issueの並びがM1-01から始まらない → 作成順=issue番号順なので、途中失敗して再実行した場合でもタイトルのプレフィックス(M1-01等)で並び替えて確認する。
