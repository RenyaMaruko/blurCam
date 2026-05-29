## Sprint 10: Google Sign-In認証とYouTube APIサービス基盤

### 実装する機能

- **F18 Google Sign-In認証**: Google Sign-In SDKを導入し、Googleアカウントでのログイン・ログアウト・トークン管理を実装する。YouTube Data API v3に必要なOAuth 2.0スコープを取得し、アクセストークンの自動リフレッシュを行う。

- **F19 YouTube APIサービス（broadcast/stream作成）**: YouTube Data API v3のLive Streaming APIを呼び出すサービス層を実装する。liveBroadcasts.insert、liveStreams.insert、liveBroadcasts.bind の各APIを呼び出し、配信枠とストリームを作成・紐付けする。APIレスポンスからRTMP URLとストリームキーを取得する。

- **F20 RTMP自動接続**: YouTube APIで取得したRTMP URLとストリームキーを既存のStreamingService（HaishinKit）に渡し、手動入力なしで配信を開始する。既存のstartStreaming(url:streamKey:)メソッドを活用する。

### スプリント契約（完了条件）
以下の全条件を満たした場合のみ、このスプリントは完了とする。

#### Google Sign-In
- [ ] Google Sign-In SDKがSPMでプロジェクトに追加されている
- [ ] GIDSignInの設定に必要なGoogleService-Info.plistまたはClient IDの設定箇所が用意されている（実際のClient IDはユーザーが設定する前提で、プレースホルダーまたは設定ガイドがある）
- [ ] ログインボタンをタップするとGoogleのOAuth認証画面が表示される
- [ ] 認証成功後、ユーザーのGoogleアカウント情報（表示名、メールアドレス、プロフィール画像URL）が取得できる
- [ ] YouTube Data APIに必要なスコープ（youtube、youtube.upload、youtube.force-ssl）がリクエストされている
- [ ] ログアウトボタンをタップするとGoogleアカウントからサインアウトし、保持していたトークンが破棄される
- [ ] アプリ再起動時にサインイン状態が復元される（前回ログイン済みならトークンが有効な状態で復帰する）
- [ ] トークン失効時に自動でリフレッシュが試みられ、リフレッシュ失敗時は再ログインを促すメッセージが表示される

#### YouTube APIサービス
- [ ] YouTubeAPIServiceクラス（またはプロトコル+実装）が存在し、liveBroadcasts.insert を呼び出してbroadcastを作成できる
- [ ] liveStreams.insert を呼び出してstreamを作成できる
- [ ] liveBroadcasts.bind を呼び出してbroadcastとstreamを紐付けできる
- [ ] APIレスポンスからRTMP ingestion URL（例: rtmp://a.rtmp.youtube.com/live2）とストリームキー（stream name）を正しく取得できる
- [ ] API呼び出し失敗時（ネットワークエラー、認証エラー、quota超過）にエラー種別を判定し、適切なエラーオブジェクトを返す

#### RTMP自動接続
- [ ] YouTube API経由で取得したRTMP URLとストリームキーが、既存のStreamingService.startStreaming(url:streamKey:width:height:)に正しく渡される
- [ ] YouTube API配信フローを選択しても、既存のTwitch/カスタムRTMP手動設定フローは引き続き動作する（回帰テスト）

### 対象ファイル（参考 - 新規作成が中心）
- 新規: GoogleAuthService（Google Sign-In管理）
- 新規: YouTubeAPIService（YouTube Data API呼び出し）
- 新規: YouTubeAPIModels（API request/responseのモデル）
- 変更: CameraViewModel（YouTube配信開始フローの追加）
- 変更: StreamingPlatform（YouTube API連携の選択肢追加）
