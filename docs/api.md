# API設計書 — Lumina Reserve

REST APIの設計書です。パス・メソッド・リクエスト/レスポンスの形はスタックに依存せず固定します。フレームワーク内部の実装(コントローラ分割、バリデーション方法など)は自由です。

- ベースパスは `/api` です。レスポンスはすべてJSONです。
- 日時はISO 8601のタイムゾーン付き文字列で返します(例: `"2026-07-15T10:00:00+09:00"`)。リクエストの日時も同形式で受け付けます。
- JSONのキーはsnake_caseに統一します(DBカラム名と一致させ、スタック間の差異をなくすため)。

## 認証方式

SNSカリキュラムと同じ **HttpOnly Cookie + JWT** 方式です。ログイン成功時にJWT(ペイロード: `sub` = user id、`role`、`exp`)を発行し、HttpOnly Cookieに保存します。以後のリクエストではCookieを自動送信し、サーバーはJWTを検証して現在のユーザーを復元します。

| 項目 | 開発環境 | 本番環境 |
|---|---|---|
| Cookie名 | `lumina_session` | `lumina_session` |
| HttpOnly | `true` | `true` |
| Secure | `false` | `true` |
| SameSite | `Lax` | `Lax` |
| Path | `/` | `/` |
| 有効期限 | 7日 | 7日 |

- ReactからのfetchにはすべてSNSカリキュラムと同様 `credentials: "include"` を付け、API側はCORSでフロントエンドのoriginを固定して許可します。
- CSRF対策は第1段階として `SameSite=Lax` + CORS許可オリジン固定 + JSONのみ受け付け、で構いません。
- ロール判定はJWTの `role` クレームではなく、**リクエストごとにDBから取得したユーザーのroleを正**としてください(招待直後のロール変更や無効化に追従するため。JWTの `role` はUI出し分けのヒント扱い)。

## エラーフォーマット

エラーレスポンスは全エンドポイントで次の形に統一します。SNSカリキュラムの `{"message": "..."}` 形式に、プログラムで分岐するための `code` を追加した形です。

```json
{
  "message": "選択された時間帯は既に予約が入っています。別の時間帯をお選びください",
  "code": "RESERVATION_CONFLICT"
}
```

- `message`: 人間(画面)向けの日本語メッセージ。フロントはそのまま表示してよい。
- `code`: 機械判定用の定数文字列。フロントの分岐・テストのアサーションはこちらを使う。
- バリデーションエラーで項目別の詳細を返したい場合のみ、任意で `fields` を追加できます(`{"fields": {"email": "..."}}`)。

### エラーコード一覧

| code | HTTP | 意味 |
|---|---|---|
| `VALIDATION_ERROR` | 400 | 入力値の形式不正(必須欠落、型不正、範囲外など) |
| `UNAUTHENTICATED` | 401 | 未ログイン、またはCookie/JWTが無効 |
| `INVALID_CREDENTIALS` | 401 | メールアドレスまたはパスワードが違う |
| `EMAIL_NOT_VERIFIED` | 403 | メール未確認のユーザーがログインしようとした |
| `FORBIDDEN` | 403 | ロール不足、または他人のリソースへの操作 |
| `NOT_FOUND` | 404 | リソースが存在しない(他人の予約IDなど、存在を隠したい場合も404) |
| `EMAIL_TAKEN` | 409 | メールアドレスが登録済み |
| `MENU_IN_USE` | 409 | 予約実績のあるメニューを削除しようとした |
| `RESERVATION_CONFLICT` | 409 | 既存の `confirmed` 予約と時間帯が重複した |
| `TOKEN_INVALID` | 400 | 確認・招待トークンが存在しない、期限切れ、または使用済み |
| `SLOT_UNAVAILABLE` | 422 | 指定枠が空き枠ルールを満たさない(営業時間・シフト外、30分グリッド外、当日+60分ルール違反、スタッフがメニュー未対応など) |
| `CANCEL_DEADLINE_PASSED` | 422 | 開始24時間前を過ぎた変更・キャンセル |
| `INVALID_STATUS_TRANSITION` | 422 | 許可されないステータス遷移(cancelled済み予約の再キャンセルなど) |

409は「他のデータとの衝突」、422は「入力形式は正しいがビジネスルールに違反」という使い分けです。

## エンドポイント一覧

「認証」列: 不要=未ログインで呼べる / 要=ログイン必須。「ロール」列は許可するロール(adminはstaffの上位互換として、staff可の操作はすべて実行可能)。

### 認証(/api/auth)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| POST | `/api/auth/signup` | 不要 | — | customer登録。確認メールを送信する |
| GET | `/api/auth/verify-email?token=...` | 不要 | — | メール確認を完了し `email_verified_at` を設定する |
| POST | `/api/auth/login` | 不要 | — | ログイン。`lumina_session` Cookieを発行する |
| POST | `/api/auth/logout` | 要 | 全ロール | Cookieを失効させる |
| GET | `/api/auth/me` | 要 | 全ロール | ログイン中ユーザー(id, name, email, role)を返す |

### 招待(/api/invitations)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| POST | `/api/invitations` | 要 | admin | staff/admin招待を発行し、招待メールを送信する |
| GET | `/api/invitations` | 要 | admin | 招待一覧(使用済み・期限切れ含む)を返す |
| POST | `/api/invitations/accept` | 不要 | — | トークン+名前+パスワードで登録を完了する。role=staffならstaff_profilesも自動作成(active=false) |

### メニュー(/api/menus)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/menus` | 不要 | — | 有効メニュー一覧(sort_order昇順)。admin/staffは `?include_inactive=true` で無効分も取得可 |
| POST | `/api/menus` | 要 | admin | メニュー作成 |
| PATCH | `/api/menus/:id` | 要 | admin | メニュー更新(部分更新) |
| DELETE | `/api/menus/:id` | 要 | admin | メニュー削除。予約実績があれば `409 MENU_IN_USE` |

### スタッフ(/api/staff)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/staff` | 不要 | — | 有効スタッフ一覧(指名用)。対応メニューid配列を含む |
| GET | `/api/staff/:id` | 不要 | — | スタッフ詳細 |
| PATCH | `/api/staff/:id` | 要 | admin / 本人staff | プロフィール更新(display_name, bio, image_url, active)。activeの変更はadminのみ |
| PUT | `/api/staff/:id/menus` | 要 | admin | 対応メニューの一括設定(menu_idの配列で全置換) |

### 営業時間(/api/business-hours)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/business-hours` | 不要 | — | 7曜日分の営業時間を返す |
| PUT | `/api/business-hours` | 要 | admin | 7曜日分を一括更新する |

### シフト(/api/shifts)

staffは自分(`staff_id` = 自分のuser id)の分のみ操作できます。adminは全スタッフ分を操作できます。

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/shifts/patterns?staff_id=...` | 要 | staff / admin | 指定スタッフの週次パターン一覧 |
| PUT | `/api/shifts/patterns/:staff_id` | 要 | staff(本人) / admin | 週次パターンの一括置換(曜日ごとの配列を渡す) |
| GET | `/api/shifts/exceptions?staff_id=...&from=...&to=...` | 要 | staff / admin | 期間内のシフト例外一覧 |
| POST | `/api/shifts/exceptions` | 要 | staff(本人) / admin | シフト例外の作成。同一(staff_id, date)が既にあれば `409` |
| DELETE | `/api/shifts/exceptions/:id` | 要 | staff(本人) / admin | シフト例外の削除 |

### 空き枠(/api/availability)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/availability?date=...&menu_ids=...&staff_id=...` | 不要 | — | 指定日の空き枠一覧(30分刻み)。`staff_id` は任意(指名) |

### 予約 — customer(/api/reservations)

customerは自分の予約のみ操作できます。他人の予約IDは `404 NOT_FOUND` を返します(存在を隠します)。

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| POST | `/api/reservations` | 要 | customer | 予約作成(二重予約防止トランザクション) |
| GET | `/api/reservations?type=upcoming\|past` | 要 | customer | 自分の予約一覧。upcoming=confirmedかつ未来(昇順) / past=それ以外(降順) |
| GET | `/api/reservations/:id` | 要 | customer | 自分の予約詳細(メニュー内訳含む) |
| PATCH | `/api/reservations/:id` | 要 | customer | 予約変更(start_at / staff_id / menu_ids / customer_note)。開始24時間前まで |
| DELETE | `/api/reservations/:id` | 要 | customer | キャンセル(status=cancelledへ変更)。開始24時間前まで。bodyで `cancel_reason` を任意指定可 |

### 予約 — 店舗側(/api/admin/reservations)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/admin/reservations?date=YYYY-MM-DD` | 要 | staff / admin | 指定日の全予約(予約ボード用)。全スタッフ分+顧客名を含む |
| POST | `/api/admin/reservations` | 要 | staff / admin | 電話予約の手動登録。`customer_id` 指定または `new_customer` で簡易顧客登録。当日+60分ルールは適用しない |
| PATCH | `/api/admin/reservations/:id/status` | 要 | staff / admin | ステータス変更(completed / no_show / cancelled)。遷移ルールはDB設計書参照 |

### 顧客管理(/api/customers)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/customers?q=...` | 要 | staff / admin | 顧客一覧。名前・メールアドレスの部分一致検索 |
| GET | `/api/customers/:id` | 要 | staff / admin | 顧客詳細(予約履歴サマリ含む) |
| GET | `/api/customers/:id/notes` | 要 | staff / admin | カルテ一覧(visited_at降順) |
| POST | `/api/customers/:id/notes` | 要 | staff / admin | カルテ作成 |

### 売上(/api/admin/summary)

| メソッド | パス | 認証 | ロール | 概要 |
|---|---|---|---|---|
| GET | `/api/admin/summary?month=YYYY-MM` | 要 | admin | 指定月の売上サマリ(completed予約の合計。日別内訳付き) |

## 主要APIの詳細

### GET /api/availability — 空き枠検索

計算ルールは [要件定義書 F-5](./requirements.md#f-5-空き枠検索customer未ログインでも可) と [reservation-domainスキル](../.claude/skills/reservation-domain/SKILL.md) の定義に従います。

リクエスト:

```text
GET /api/availability?date=2026-07-15&menu_ids=1,4&staff_id=3
```

| パラメータ | 必須 | 説明 |
|---|---|---|
| `date` | 必須 | 対象日(`YYYY-MM-DD`、JST)。過去日は `400 VALIDATION_ERROR` |
| `menu_ids` | 必須 | メニューIDのカンマ区切り。1つ以上。無効・存在しないIDを含む場合は `422 SLOT_UNAVAILABLE` |
| `staff_id` | 任意 | 指名スタッフのuser id。省略時は対応可能な全スタッフを横断 |

レスポンス `200 OK`(例: カット60分+トリートメント30分=90分、スタッフ3を指名):

```json
{
  "date": "2026-07-15",
  "total_duration_min": 90,
  "total_price": 8250,
  "slots": [
    {
      "start_at": "2026-07-15T10:00:00+09:00",
      "end_at": "2026-07-15T11:30:00+09:00",
      "staff": [
        { "id": 3, "display_name": "AOI" }
      ]
    },
    {
      "start_at": "2026-07-15T10:30:00+09:00",
      "end_at": "2026-07-15T12:00:00+09:00",
      "staff": [
        { "id": 3, "display_name": "AOI" }
      ]
    },
    {
      "start_at": "2026-07-15T14:00:00+09:00",
      "end_at": "2026-07-15T15:30:00+09:00",
      "staff": [
        { "id": 3, "display_name": "AOI" }
      ]
    }
  ]
}
```

- `slots` は開始時刻の昇順です。空きが1つもない日は `"slots": []` を返します(エラーではありません)。
- 指名なしの場合、同じ `start_at` の枠は1要素にまとめ、`staff` 配列に対応可能な全スタッフを入れます。
- 定休日・全スタッフ勤務なしの日も `"slots": []` の200で返します。

エラー例(`422 Unprocessable Entity`。指名スタッフが選択メニューに未対応):

```json
{
  "message": "指名されたスタッフはこのメニューに対応していません",
  "code": "SLOT_UNAVAILABLE"
}
```

### POST /api/reservations — 予約作成

リクエスト:

```json
{
  "staff_id": 3,
  "menu_ids": [1, 4],
  "start_at": "2026-07-15T10:00:00+09:00",
  "customer_note": "前回より少し短めにしたいです"
}
```

サーバー側の処理(この順序を守ること):

1. 入力検証(メニューが1つ以上、start_atが30分グリッド上、など)。
2. `total_duration_min`・`total_price`・`end_at` を**サーバー側で再計算**する(クライアントから金額・終了時刻を受け取らない)。
3. 空き枠ルール(営業時間∩シフト、当日+60分)を検証 → 違反は `422 SLOT_UNAVAILABLE`。
4. トランザクション内で `staff_profiles` の行を `SELECT ... FOR UPDATE` でロック → 重複チェック → INSERT(reservations + reservation_menus)。重複時は `409 RESERVATION_CONFLICT`。

レスポンス `201 Created`:

```json
{
  "id": 42,
  "customer_id": 10,
  "staff": { "id": 3, "display_name": "AOI" },
  "start_at": "2026-07-15T10:00:00+09:00",
  "end_at": "2026-07-15T11:30:00+09:00",
  "status": "confirmed",
  "total_price": 8250,
  "total_duration_min": 90,
  "customer_note": "前回より少し短めにしたいです",
  "created_by": "customer",
  "menus": [
    { "menu_id": 1, "name": "カット", "price_at_booking": 4950, "duration_min_at_booking": 60 },
    { "menu_id": 4, "name": "トリートメント", "price_at_booking": 3300, "duration_min_at_booking": 30 }
  ]
}
```

エラー例(`409 Conflict`。直前に他の顧客が同じ枠を確定した):

```json
{
  "message": "選択された時間帯は既に予約が入っています。別の時間帯をお選びください",
  "code": "RESERVATION_CONFLICT"
}
```

エラー例(`422 Unprocessable Entity`。当日+60分ルール違反):

```json
{
  "message": "当日のご予約は開始60分前まで受け付けています",
  "code": "SLOT_UNAVAILABLE"
}
```

### DELETE /api/reservations/:id — キャンセル

リクエストbody(任意):

```json
{
  "cancel_reason": "予定が入ったため"
}
```

レスポンス `200 OK`(更新後の予約を返す):

```json
{
  "id": 42,
  "status": "cancelled",
  "cancelled_at": "2026-07-13T09:12:00+09:00",
  "cancel_reason": "予定が入ったため"
}
```

エラー例(`422 Unprocessable Entity`):

```json
{
  "message": "開始24時間前を過ぎたため、キャンセルは店舗へお電話でご連絡ください",
  "code": "CANCEL_DEADLINE_PASSED"
}
```

### GET /api/admin/reservations — 予約ボード一覧

リクエスト:

```text
GET /api/admin/reservations?date=2026-07-15
```

レスポンス `200 OK`(スタッフごとにグループ化して返す):

```json
{
  "date": "2026-07-15",
  "staff": [
    {
      "id": 3,
      "display_name": "AOI",
      "working_window": { "start": "10:00", "end": "19:00" },
      "reservations": [
        {
          "id": 42,
          "customer": { "id": 10, "name": "山田 花子" },
          "start_at": "2026-07-15T10:00:00+09:00",
          "end_at": "2026-07-15T11:30:00+09:00",
          "status": "confirmed",
          "total_price": 8250,
          "created_by": "customer",
          "menus": [
            { "menu_id": 1, "name": "カット" },
            { "menu_id": 4, "name": "トリートメント" }
          ]
        }
      ]
    },
    {
      "id": 5,
      "display_name": "REN",
      "working_window": null,
      "reservations": []
    }
  ]
}
```

- `working_window` はその日の勤務ウィンドウ(営業時間∩シフト、JSTの時刻文字列)。勤務なしの日は `null` です。タイムライン描画に使います。
- その日の `cancelled` 予約も含めて返します(画面側で打ち消し表示)。表示不要なら `?include_cancelled=false` を任意実装しても構いません。

### POST /api/admin/reservations — 電話予約の手動登録

既存顧客の場合:

```json
{
  "customer_id": 10,
  "staff_id": 3,
  "menu_ids": [2],
  "start_at": "2026-07-15T14:00:00+09:00",
  "customer_note": "電話予約。カラーは前回と同じ色で"
}
```

新規顧客(簡易登録)の場合は `customer_id` の代わりに `new_customer` を渡します:

```json
{
  "new_customer": { "name": "佐々木 健", "email": "sasaki@example.com" },
  "staff_id": 3,
  "menu_ids": [2],
  "start_at": "2026-07-15T14:00:00+09:00"
}
```

- `new_customer.email` が登録済みの場合は `409 EMAIL_TAKEN` を返し、画面は既存顧客の検索を促します。
- 簡易登録した顧客はランダムパスワードのcustomerとして作成します(`email_verified_at` はNULLのまま)。
- 予約は `created_by = "admin"` で作成され、レスポンスは `POST /api/reservations` と同形式(`201 Created`)です。
- 空き枠ルールのうち「当日+60分」だけは適用しません。二重予約防止は同一のトランザクション処理を必ず通します。

### GET /api/admin/summary — 売上サマリ

```text
GET /api/admin/summary?month=2026-07
```

レスポンス `200 OK`:

```json
{
  "month": "2026-07",
  "total_sales": 254100,
  "completed_count": 38,
  "no_show_count": 2,
  "daily": [
    { "date": "2026-07-01", "sales": 13750, "completed_count": 3 },
    { "date": "2026-07-02", "sales": 8800, "completed_count": 1 }
  ]
}
```

- 集計対象は `status = 'completed'` の予約の `total_price` 合計です。日付は `start_at` のJST日付で集計します。
- `daily` は売上が0の日を含めなくて構いません(含めても可。画面側で補完します)。

## 権限マトリクス(テスト観点)

ロール別アクセス制御は自動テストで担保します(非機能要件)。最低限、次の組み合わせを確認してください。

| 操作 | 未ログイン | customer | staff | admin |
|---|---|---|---|---|
| GET /api/menus, /api/staff, /api/business-hours, /api/availability | ○ | ○ | ○ | ○ |
| POST /api/reservations | 401 | ○ | 403 | 403 |
| GET /api/reservations/:id(他人の予約) | 401 | 404 | — | — |
| POST /api/menus, PUT /api/staff/:id/menus | 401 | 403 | 403 | ○ |
| PUT /api/shifts/patterns/:staff_id(他人の分) | 401 | 403 | 403 | ○ |
| GET /api/admin/reservations, /api/customers | 401 | 403 | ○ | ○ |
| POST /api/invitations, GET /api/admin/summary | 401 | 403 | 403 | ○ |

- staffによる予約作成は `/api/admin/reservations`(手動登録)を使うため、customer用の `POST /api/reservations` は403とします。
- 「—」は前提が成立しない組み合わせ(staff/adminはcustomer用予約APIを使わない)です。
