# 環境つまずき集 — Lumina Reserve

実装スタックや開発環境に起因する「仕様ではないが必ず誰かがつまずく」問題のリストです。エラーに遭遇したら、まずここに同じ症状がないか確認してください(先輩受講者の実走で実際に発生したものだけを載せています)。各項目は「症状 → 原因 → 対処」の形式です。

## pnpm 10がビルドスクリプトをブロックする

- 症状: `pnpm install` 後にPrisma等が動かず、「Ignored build scripts: ...」の警告が出る。
- 原因: pnpm 10からセキュリティ強化のため、依存パッケージのビルドスクリプト(postinstall等)が既定で実行されなくなりました。
- 対処: `package.json` に `"pnpm": { "onlyBuiltDependencies": ["prisma", "@prisma/client", "@prisma/engines", "bcrypt"] }` のように許可リストを追加して `pnpm install` し直します(`pnpm approve-builds` でも可)。

## Prisma 7でクライアント初期化が失敗する(adapter-pg必須)

- 症状: `new PrismaClient()` が「driver adapterが必要」という趣旨のエラーで落ちる。
- 原因: Prisma 7からRust製クエリエンジンが廃止され、driver adapter経由の接続が必須になりました。
- 対処: `@prisma/adapter-pg` を追加し、`new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) })` の形で初期化します。

## Prisma 7の生成コードがESMでNestJSのCJSビルドと衝突する

- 症状: ビルドまたは起動時に `ERR_REQUIRE_ESM` や import関連のエラーが出る。
- 原因: Prisma 7の生成クライアント(`prisma-client` generator)は既定でESMを出力し、NestJSの既定ビルド(CommonJS)と噛み合いません。
- 対処: `schema.prisma` のgeneratorに `moduleFormat = "cjs"` を指定して再生成します。

## Prismaのseedが動かない(prisma.config.ts)

- 症状: `prisma db seed` がseedスクリプトを見つけられない。
- 原因: Prisma 7では `package.json` の `"prisma"` セクションが廃止され、設定は `prisma.config.ts` に移りました。
- 対処: ルートに `prisma.config.ts` を作り、`migrations.seed` にseedコマンドを定義します。あわせて `prisma.config.ts` は `tsconfig.build.json` の `exclude` に追加してください(次項参照)。

## NestJSのビルド出力が `dist/main.js` ではなく `dist/src/main.js` になる

- 症状: `node dist/main.js` や `nest start` が「ファイルが見つからない」で失敗する。
- 原因: `prisma.config.ts` などルート直下の `.ts` ファイルがコンパイル対象に含まれると、tscが共通ルートを繰り上げて出力が `dist/src/` 配下にずれます。
- 対処: `tsconfig.build.json` の `exclude` に `prisma.config.ts` を追加するか、起動パスを `dist/src/main.js` に合わせます(除外して `dist/main.js` に戻すのを推奨)。

## `prisma migrate reset` がAIエージェントにブロックされる

- 症状: Claude Code等がmigrationの検証のために `prisma migrate reset` を実行しようとして、破壊的コマンドとしてブロック(または確認待ち)になる。
- 原因: `reset` は開発DBを丸ごと消すため、エージェント側の安全機構に引っかかります。
- 対処: 開発DBをresetする代わりに、一時DB(例: `createdb lumina_reserve_check`)を作って `prisma migrate deploy` を流し、まっさらなDBでmigrationが一発で通ることを検証してから一時DBを削除します。

## Apple SiliconでMailHogが起動しない

- 症状: `docker compose up` でmailhogコンテナが起動直後に落ちる、またはplatform警告が出る。
- 原因: `mailhog/mailhog` はamd64イメージしか提供されておらず、Apple Silicon(arm64)ではそのまま動きません。
- 対処: composeのmailhogサービスに `platform: linux/amd64` を指定します(エミュレーションで動きます)。arm64ネイティブが良ければ後継のMailpit(`axllent/mailpit`)への置き換えも可です([インフラ設計書](./infra.md))。

## ホスト側のポートが既に使われている(5432など)

- 症状: `docker compose up` が「port is already allocated」で失敗する。
- 原因: ローカルの別プロジェクトやネイティブのPostgreSQLが同じポートを使っています。
- 対処: composeのports左側(ホスト側)を環境変数で上書きします(例: `"${POSTGRES_PORT:-5432}:5432"` にして `.env` で `POSTGRES_PORT=15432`)。規範はコンテナ側ポートなので、接続文字列のポートだけ合わせれば仕様への影響はありません。

## TS1272: 型のimportがエラーになる

- 症状: `error TS1272: A type referenced in a decorated signature must be imported with 'import type' ...` が出る。
- 原因: `isolatedModules` + デコレータ環境(NestJS)では、型としてしか使わないimportを通常のimportで書けません。
- 対処: `import type { Response } from "express"` のように `import type` に書き換えます。

## ログアウトしてもCookieが消えない

- 症状: `res.clearCookie("lumina_session")` を呼んでもブラウザにCookieが残り、ログアウト後も `GET /api/auth/me` が200を返す。
- 原因: Cookieの削除は「同じ属性(path、sameSite、httpOnly、secure)で上書き」した場合にだけ効きます。属性が発行時と違うと別Cookie扱いになります。
- 対処: `clearCookie` に発行時と同じ属性オプションを渡します(`maxAge`/`expires` 以外は完全一致させる)。

## React StrictModeでuseEffectが2回走る

- 症状: 開発モードで起動時のAPIが2回呼ばれる。GETでトークンを消費する実装だと2回目が `400 TOKEN_INVALID` になり、メール確認が常に失敗して見える。
- 原因: React 18+のStrictModeは開発時にeffectを意図的に2回実行します(バグではありません)。
- 対処: StrictModeは外さず、二重実行に耐える設計にします。トークン消費など1回きりの副作用は、ボタンクリックで実行する・refで実行済みフラグを持つ等で1回に抑えます(本プロジェクトのメール確認をPOST+画面起点にしているのはこのためです。[API設計書](./api.md))。
