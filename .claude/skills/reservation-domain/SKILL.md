---
name: reservation-domain
description: Lumina Reserveのドメイン核心部の実装ガイド。空き枠計算アルゴリズムの正確な仕様と、SELECT FOR UPDATEによる二重予約防止の実装指針・競合テストの書き方。M2-04(空き枠計算API)、M3-01(予約作成API)をはじめ、空き枠・予約に関わるすべての実装の前に読む。
---

# Reservation Domain — 空き枠計算と二重予約防止

このスキルは `docs/requirements.md`(F-5、F-6)と `docs/api.md` の仕様を実装者向けに展開したものです。矛盾があればrequirements.mdが正です。

## 1. 空き枠計算アルゴリズム

### 定義

ある日付 `date`、選択メニュー集合 `menus`、スタッフ `s` に対する空き枠とは、次をすべて満たす開始時刻 `t` です。

```text
total = Σ menus.duration_min                    … 合計所要時間(分)

(a) t は毎時00分または30分ちょうど(JST基準の30分グリッド)
(b) [t, t + total) ⊆ (営業時間 ∩ スタッフsのその日の勤務時間)
(c) [t, t + total) が スタッフsの status='confirmed' の既存予約と重ならない
(d) dateが当日のとき、t >= 現在時刻 + 60分
```

### 計算手順

```text
入力: date, menu_ids[], staff_id(任意)
出力: slots[] = [{start_at, end_at, staff[]}]

1. メニュー検証:
   menu_idsのメニューを取得。存在しない・active=falseが混じる → 422 SLOT_UNAVAILABLE
   total = duration_minの合計

2. 対象スタッフの決定:
   staff_id指定あり → そのスタッフ1名。active=false、または選択メニューの
     いずれかがstaff_menusに未登録 → 422 SLOT_UNAVAILABLE
   指定なし → active=true かつ 全menu_idsがstaff_menusに登録済みのスタッフ全員
     (0名なら slots=[] の200を返す)

3. 営業時間の取得:
   business_hoursからdateの曜日の行を取得。is_closed=true → slots=[]

4. スタッフごとの勤務ウィンドウ:
   shift_exceptionsに(staff_id, date)の行がある?
     ├ type='off'    → このスタッフは勤務なし
     ├ type='custom' → shift = [start_time, end_time)
     └ 行なし → shift_patternsの(staff_id, dateの曜日)の行。なければ勤務なし
   window = [max(open_time, shift.start), min(close_time, shift.end))
   windowが空(start >= end) → 勤務なし

5. グリッド生成と予約除外:
   そのスタッフのdateの予約を1クエリで取得(status='confirmed'のみ):
     WHERE staff_id = s AND status = 'confirmed'
       AND start_at < date翌日0:00(JST) AND end_at > date 0:00(JST)
   t = windowの開始以降で最初の00分/30分から、30分刻みでループ:
     t + total <= window終了 でなければ打ち切り
     [t, t+total) が既存予約[start_at, end_at)のいずれかと重なればスキップ
       (重なり判定: t < r.end_at AND t + total > r.start_at)
     当日なら t < now + 60分 をスキップ
     残った t を採用

6. 全スタッフ分をstart_atでマージ(同時刻はstaff配列に集約)し、昇順で返す
```

### 実装上の注意

- **N+1禁止**: 対象スタッフ全員のshift_patterns / shift_exceptions / 予約を、それぞれ**1クエリ**(`staff_id IN (...)`)で取得してからメモリ上で計算します。枠ごと・スタッフごとにクエリを発行しない設計にします。
- **タイムゾーン**: `business_hours` / シフトの `TIME` はJSTの壁時計、予約の `TIMESTAMPTZ` はUTC保存です。「dateのJST 0:00」をUTCへ変換してから予約を検索します。テストでタイムゾーンつきの時刻を固定して検証してください(サーバーのTZ設定に依存させない)。
- メニューの `duration_min` は30の倍数とは限りません。グリッドは**開始時刻のみ**の制約で、終了時刻は任意の分になり得ます(例: 10:00開始の45分メニュー → 10:45終了。次の空き枠候補は11:00からではなく、10:30が重なりで消えて11:00から)。
- 境界は半開区間 `[start, end)` で統一します。「10:00〜11:30の予約」と「11:30開始の候補」は**重なりません**。営業終了ちょうどに終わる枠(例: 19:00閉店で18:00開始の60分)は**有効**です。
- 過去日付のリクエストは `400 VALIDATION_ERROR` です(当日は(d)のルールで自然に絞られます)。

### テスト観点(M2-04の受入条件に対応)

1. 営業時間よりシフトが短い日 → windowがシフト側で切れる
2. シフト例外 `off` の日 → そのスタッフの枠が0件
3. シフト例外 `custom` の日 → パターンでなく例外の時間が使われる
4. 既存予約(confirmed)がある時間帯の枠が消える。cancelledの予約は枠を消さない
5. メニュー合計90分が閉店間際に収まらない → 収まる最後の開始時刻まで返る
6. 当日検索で now+60分より前の枠が返らない(時計を固定してテスト)
7. 指名なしで複数スタッフが同時刻に空いている → staff配列に集約される

## 2. 二重予約防止(予約作成トランザクション)

### なぜ単純なチェックでは壊れるか

「重複予約をSELECTして、なければINSERT」を2つのリクエストが同時に実行すると、両方のSELECTが「重複なし」を見てから両方がINSERTし、二重予約が成立します。重複行を `SELECT ... FOR UPDATE` しても、**行が存在しない場合は何もロックされない**ため防げません(ファントム)。

### 実装指針(基本方針)

存在が保証されている親行 `staff_profiles` をロックして、スタッフ単位で予約作成を直列化します。

```text
BEGIN;

-- (1) スタッフ行をロック(同一スタッフへの予約作成をここで直列化)
SELECT user_id FROM staff_profiles WHERE user_id = :staff_id FOR UPDATE;

-- (2) ロック取得後に重複チェック(半開区間の重なり判定)
SELECT COUNT(*) FROM reservations
 WHERE staff_id = :staff_id
   AND status = 'confirmed'
   AND start_at < :end_at
   AND end_at   > :start_at;
-- 1件以上 → ROLLBACKして 409 RESERVATION_CONFLICT

-- (3) INSERT
INSERT INTO reservations (...) VALUES (...);
INSERT INTO reservation_menus (...) VALUES (...);  -- メニュー数ぶん

COMMIT;
```

- (1)〜(3)は**必ず同一トランザクション内**で実行します。ORMのトランザクションAPI(Prisma `$transaction` / JPA `@Transactional` + `@Lock` / SQLAlchemy `with_for_update` / Eloquent `lockForUpdate` / GORM `clause.Locking` / Active Record `lock`)を使います。
- 空き枠ルールの検証(営業時間∩シフト、グリッド、当日+60分)は(1)の前でも構いませんが、**重複チェック(2)は必ずロック(1)の後**に行います。ロック前のチェック結果は同時実行下では信用できません。
- 予約変更(PATCH)で時間帯やスタッフを変える場合も同じ手順を通します(変更対象自身の予約は重複チェックから除外: `AND id != :reservation_id`)。
- 店舗側の手動登録(`POST /api/admin/reservations`)も同一のトランザクション処理を共通利用します。入口(コントローラ)が違ってもドメインロジックは1つにします。

### 発展: PostgreSQLのEXCLUDE制約

`docs/database.md` に記載のとおり、btree_gist + `EXCLUDE USING gist (staff_id WITH =, tstzrange(start_at, end_at) WITH &&) WHERE (status = 'confirmed')` をDBに張ると多層防御になります。任意課題ですが、張った場合も上記ロック実装と競合テストは省略しません(制約違反は23P01エラーで飛んでくるため、409へのマッピングが別途必要です)。

### 競合テストの書き方(M3-01の受入条件に対応)

「同じ枠への同時リクエストで確定が1件のみ」を自動テストで検証します。

```text
1. 準備: スタッフ1名、60分メニュー1件、対象日の空き枠がある状態を作る
2. 同一の {staff_id, menu_ids, start_at} の予約作成を2本、並行に実行する
   - 別々の顧客アカウントで、DBコネクションも別にする(同一コネクションだと直列化されテストにならない)
   - 並行化の手段: Promise.all / ExecutorService / asyncio.gather / goroutine / スレッド
     (HTTPレイヤーごと並行に叩くE2E形式を推奨。難しければサービス層を並行呼び出し)
3. 検証:
   - 片方が 201、もう片方が 409 で code = "RESERVATION_CONFLICT"
   - DBの該当時間帯の confirmed 予約が「ちょうど1件」
4. 追加ケース:
   - 部分的に重なる時間帯(10:00-11:00 と 10:30-11:30)でも同様に片方だけ成立
   - 別スタッフへの同時刻予約は両方成功する(ロックがスタッフ単位である証明)
   - キャンセル済み(cancelled)と同時間帯の新規予約は成功する
```

テストが不安定(flaky)になったら、2本のリクエストが本当に同時にロック区間へ入っているかを確認します。片方のトランザクション内で人工的な待ち(テスト用フック)を入れて確実に競合させる方法も有効です。

## 3. 関連するビジネスルールの早見表

| ルール | 値 | 出典 |
|---|---|---|
| 空き枠のグリッド | 毎時00分・30分開始 | requirements.md F-5 |
| 所要時間 | 選択メニューのduration_min合計 | requirements.md F-5 |
| 当日予約の下限 | 現在時刻+60分以降(customerのみ。店舗側手動登録には適用しない) | requirements.md F-5 / F-8 |
| 変更・キャンセル期限 | 開始時刻の24時間前まで(ちょうどは可)。customerのみ | requirements.md F-6 |
| 枠をブロックするステータス | `confirmed` のみ | requirements.md F-5 |
| 重なり判定 | 半開区間 `[start_at, end_at)`、`start_at < :end AND end_at > :start` | 本スキル |
| 競合時のエラー | HTTP 409 / `RESERVATION_CONFLICT` | api.md |
| 枠ルール違反のエラー | HTTP 422 / `SLOT_UNAVAILABLE` | api.md |
