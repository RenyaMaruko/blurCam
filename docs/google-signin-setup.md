# Google Sign-In Setup Guide

## 概要

blurCamのYouTube API連携機能を使用するには、Google Cloud ConsoleでOAuth 2.0クライアントIDを取得し、アプリに設定する必要があります。

## 手順

### 1. Google Cloud Consoleでプロジェクトを作成

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 新しいプロジェクトを作成（または既存プロジェクトを選択）
3. プロジェクト名: `blurCam` など

### 2. YouTube Data API v3 を有効化

1. 「APIとサービス」>「ライブラリ」へ移動
2. 「YouTube Data API v3」を検索
3. 「有効にする」をクリック

### 3. OAuth同意画面を設定

1. 「APIとサービス」>「OAuth同意画面」へ移動
2. 「外部」を選択して「作成」
3. アプリ情報を入力:
   - アプリ名: `blurCam`
   - ユーザーサポートメール: あなたのメールアドレス
   - デベロッパーの連絡先情報: あなたのメールアドレス
4. スコープを追加:
   - `https://www.googleapis.com/auth/youtube`
   - `https://www.googleapis.com/auth/youtube.upload`
   - `https://www.googleapis.com/auth/youtube.force-ssl`
5. テストユーザーを追加（開発中はテストモード）

### 4. OAuth 2.0 クライアントIDを作成

1. 「APIとサービス」>「認証情報」へ移動
2. 「認証情報を作成」>「OAuthクライアントID」
3. アプリケーションの種類: **iOS**
4. 名前: `blurCam iOS`
5. バンドルID: `com.renyamaruko.blurCam.app`
6. 「作成」をクリック
7. 表示されたクライアントIDをコピー

### 5. アプリに設定

#### Info.plist の更新

`blurCam/Resources/Info.plist` の以下の箇所を実際のクライアントIDに置き換えてください:

```xml
<key>GIDClientID</key>
<string>YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com</string>
```

#### URL Scheme の更新

同じく Info.plist の URL Scheme も更新:

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>com.googleusercontent.apps.YOUR_ACTUAL_CLIENT_ID</string>
</array>
```

**注意**: URL SchemeはクライアントIDの逆順です。例えば、クライアントIDが
`123456789-abcdef.apps.googleusercontent.com` の場合、
URL Schemeは `com.googleusercontent.apps.123456789-abcdef` になります。

### 6. 動作確認

1. アプリをビルド・実行
2. 設定 > YouTube配信（API連携）をタップ
3. 「Googleでログイン」をタップ
4. Googleアカウントでサインイン
5. YouTube APIの権限を許可
6. 配信タイトル等を設定して「YouTube配信を開始」

## トラブルシューティング

- **サインインエラー**: クライアントIDとバンドルIDが一致しているか確認
- **スコープエラー**: OAuth同意画面でYouTubeスコープが追加されているか確認
- **quota超過**: YouTube Data APIのquota制限に達している可能性があります（デフォルト10,000ユニット/日）
