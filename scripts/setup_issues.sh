#!/usr/bin/env bash
#
# setup_issues.sh — scripts/issues.json のlabel・milestone・issueを
# 受講者自身のリポジトリに複製するスクリプト。
#
# 使い方:
#   ./scripts/setup_issues.sh [owner/repo]
#   (引数省略時はカレントディレクトリのリポジトリを対象にする)
#
# 冪等性: label は --force で上書き、milestone / issue は同名・同タイトルが
# あればスキップするため、途中で失敗しても再実行すれば続きから作成できる。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISSUES_JSON="${SCRIPT_DIR}/issues.json"

# ---- 前提チェック -----------------------------------------------------------

for cmd in gh jq; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    echo "エラー: ${cmd} が見つかりません。インストールしてから再実行してください。" >&2
    exit 1
  fi
done

if ! gh auth status > /dev/null 2>&1; then
  echo "エラー: gh の認証が通っていません。'gh auth login' を実行してください。" >&2
  exit 1
fi

if [ ! -f "$ISSUES_JSON" ]; then
  echo "エラー: ${ISSUES_JSON} が見つかりません。" >&2
  exit 1
fi

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

if [ "$REPO" = "dik-ab/curriculum-project-salon-reservation" ]; then
  echo "エラー: テンプレート元リポジトリ (${REPO}) が対象になっています。" >&2
  echo "       自分のリポジトリのcloneディレクトリで実行するか、引数で owner/repo を指定してください。" >&2
  exit 1
fi

echo "対象リポジトリ: ${REPO}"
echo

# ---- ラベル -----------------------------------------------------------------

echo "== ラベルを作成します =="
label_count=$(jq '.labels | length' "$ISSUES_JSON")
for i in $(seq 0 $((label_count - 1))); do
  name=$(jq -r ".labels[$i].name" "$ISSUES_JSON")
  color=$(jq -r ".labels[$i].color" "$ISSUES_JSON")
  description=$(jq -r ".labels[$i].description" "$ISSUES_JSON")
  gh label create "$name" --repo "$REPO" --color "$color" --description "$description" --force > /dev/null
  echo "  label: ${name} ... OK"
done
echo

# ---- マイルストーン ---------------------------------------------------------

echo "== マイルストーンを作成します =="
existing_milestones=$(gh api "repos/${REPO}/milestones?state=all" --paginate -q '.[].title')
milestone_count=$(jq '.milestones | length' "$ISSUES_JSON")
for i in $(seq 0 $((milestone_count - 1))); do
  title=$(jq -r ".milestones[$i].title" "$ISSUES_JSON")
  description=$(jq -r ".milestones[$i].description" "$ISSUES_JSON")
  if printf '%s\n' "$existing_milestones" | grep -Fxq "$title"; then
    echo "  milestone: ${title} ... 既にあるためスキップ"
  else
    gh api "repos/${REPO}/milestones" -f title="$title" -f description="$description" > /dev/null
    echo "  milestone: ${title} ... OK"
  fi
done
echo

# ---- issue ------------------------------------------------------------------

echo "== issueを作成します =="
existing_issues=$(gh issue list --repo "$REPO" --state all --limit 200 --json title -q '.[].title')
issue_count=$(jq '.issues | length' "$ISSUES_JSON")
created=0
skipped=0
for i in $(seq 0 $((issue_count - 1))); do
  title=$(jq -r ".issues[$i].title" "$ISSUES_JSON")
  if printf '%s\n' "$existing_issues" | grep -Fxq "$title"; then
    echo "  issue: ${title} ... 既にあるためスキップ"
    skipped=$((skipped + 1))
    continue
  fi

  body=$(jq -r ".issues[$i].body" "$ISSUES_JSON")
  milestone=$(jq -r ".issues[$i].milestone // empty" "$ISSUES_JSON")
  labels=$(jq -r ".issues[$i].labels | join(\",\")" "$ISSUES_JSON")

  args=(--repo "$REPO" --title "$title" --body "$body")
  if [ -n "$labels" ]; then
    args+=(--label "$labels")
  fi
  if [ -n "$milestone" ]; then
    args+=(--milestone "$milestone")
  fi

  gh issue create "${args[@]}" > /dev/null
  echo "  issue: ${title} ... OK"
  created=$((created + 1))
done
echo

echo "完了しました: issue作成 ${created} 件 / スキップ ${skipped} 件"
echo "確認: gh issue list --repo ${REPO} --limit 30"
