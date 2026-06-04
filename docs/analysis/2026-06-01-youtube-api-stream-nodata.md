# YouTube Data API v3 RTMP ストリーム noData 問題 分析レポート

## 現状の問題

YouTube Data API v3 で `liveStreams.insert` により作成したストリームに RTMP でデータを送信しているが、YouTube 側で `streamStatus: "inactive"`, `healthStatus: "noData"` のままデータが認識されない。

一方、**YouTube Studio のエンコーダー配信画面から手動でコピーしたストリームキー**を使って同じ `StreamingService`（HaishinKit v1.9.9）、同じ RTMP URL（`rtmp://a.rtmp.youtube.com/live2`）で配信すると正常に映像が表示される。

### 症状の整理

| 項目 | 手動ストリームキー | API作成ストリームキー |
|---|---|---|
| RTMP接続 | 成功 | 成功 |
| Publish.Start | 受信 | 受信 |
| フレーム送信 | 30fps | 30fps |
| YouTube streamStatus | active | inactive/ready |
| YouTube healthStatus | good/ok | noData |
| 映像表示 | 表示される | 表示されない |

## 原因分析

### 根本原因: `listStreams(mine=true)` が API 作成済みストリームを返し、それを「既存のデフォルトストリーム」と誤認してバインドしている

コードの流れを詳細に追跡すると、以下の問題が浮かび上がる。

#### 1. ストリーム再利用ロジックのバグ

`YouTubeAPIService.setupLiveStream()` の Step 2（L194-221）では:

```swift
// Step 2: Find existing default stream or create new one
let existingStreams = try await listStreams(accessToken: accessToken)

// Prefer a stream that is "ready"
if let readyStream = existingStreams.first(where: {
    $0.status?.streamStatus == "ready" &&
    $0.cdn?.ingestionInfo?.ingestionAddress != nil &&
    $0.cdn?.ingestionInfo?.streamName != nil
}) ?? existingStreams.first(where: {
    $0.cdn?.ingestionInfo?.ingestionAddress != nil &&
    $0.cdn?.ingestionInfo?.streamName != nil
}) {
    stream = readyStream  // <-- これが問題
} else {
    stream = try await createStream(config: streamConfig, accessToken: accessToken)
}
```

**重要な事実**: `liveStreams.list(mine=true)` は **reusable ストリームのみ**を返す（YouTube 公式ドキュメント）。API で作成したストリームはデフォルトで `isReusable: true` であるため、**前回の API 呼び出しで作成されたストリームが返される**。

つまり:
1. 最初の配信で API がストリーム A を作成
2. 2回目の配信で `listStreams` がストリーム A を返す（reusable なので）
3. コードはストリーム A を「既存のデフォルトストリーム」と判断して再利用
4. しかしストリーム A は**前回のブロードキャストにバインドされたまま**であり、新しいブロードキャストとのバインドが想定通りに機能しない可能性がある

#### 2. YouTube Studio のストリームキーとの根本的な違い

YouTube Studio で表示されるストリームキーは YouTube が内部的に管理する**デフォルトストリーム**のキーである。このデフォルトストリームは:
- `snippet.isDefaultStream: true`
- YouTube の RTMP インジェストサーバーで**常にプロビジョニング済み**
- ストリームステータスが `ready` で常に待機している

API で新規作成したストリームは:
- `snippet.isDefaultStream: false`
- YouTube のインジェストサーバーで**新たにプロビジョニングが必要**
- プロビジョニング完了まで RTMP データを受け付けない可能性がある

#### 3. `isDefaultStream` のストリームが `listStreams` で取得できない問題

重要な発見: `isDefaultStream` は 2020年9月に**非推奨**となった。しかし、YouTube Studio の「エンコーダー配信」で作成・管理されるストリームキーは YouTube が内部で管理するストリームであり、**API の `liveStreams.list(mine=true)` では取得できない可能性が高い**。

このため、コードの `listStreams` は YouTube Studio のストリームキーを見つけられず、代わりに以前 API で作成したストリーム（noData 問題が再現するもの）を返している。

#### 4. ストリームプロビジョニングの遅延

YouTube 公式の「Life of a Broadcast」ドキュメントによると、RTMP 送信を開始する前に `status.streamStatus` が `active` になることを確認する必要がある。現在のコードでは 10秒の固定待ちの後に RTMP 接続しているが、これは API 作成ストリームのプロビジョニングが完了している保証にならない。

#### 5. RTMP 接続先の問題はない（排除）

HaishinKit の接続方法を確認したところ:
- `RTMPConnection.connect("rtmp://a.rtmp.youtube.com/live2")` -- 接続先 URL
- `RTMPStream.publish("ストリームキー")` -- パブリッシュ名としてストリームキー使用

この方式は YouTube RTMP の仕様（ingestionAddress にストリーム名を publish name として送る）と一致しており、技術的に正しい。手動ストリームキーで動作していることからも確認済み。

## 調査結果

### YouTube 公式ドキュメントからの知見

1. **Life of a Broadcast**: RTMP 送信前に `streamStatus` が `active` であることを確認すべき。`active` は「YouTube サーバーがエンコーダーからデータを正しく受信している」ことを意味する。

2. **liveStreams リソース**: `streamStatus` の値は `active`, `created`, `error`, `inactive`, `ready` の5つ。`ready` は「有効な CDN 設定がある」、`inactive` は「データを受信していない」。

3. **デフォルトストリーム非推奨**: 2020年10月以降、デフォルトストリームは新規作成されない。既存のデフォルトストリームは引き続き存在するが、非推奨。

4. **ストリーム再利用**: `isReusable: true`（デフォルト）のストリームは `listStreams(mine=true)` で取得可能。`isReusable: false` のストリームは取得できない。

5. **ingestionAddress と streamName**: ドキュメントには「エンコーダーによっては `STREAM_URL/STREAM_NAME` の形式で連結が必要」との記述がある。ただし HaishinKit は `connect(URL)` + `publish(streamName)` で正しく分離処理している。

### 他の開発者の事例

- **CrowCam プロジェクト (GitHub)**: デフォルトストリーム非推奨への対応として、毎回新規でブロードキャストとストリームを作成するように書き換え。RTMP インジェストの問題は報告なし。

- **HaishinKit Discussion #1361**: RTMP Connection Success だが YouTube に映像が表示されない問題。原因は「ストリーム名に任意の値を設定」していたこと。YouTube が発行したストリームキーを使う必要がある。

- **HaishinKit Discussion #1585**: YouTube RTMP が自プロジェクトで動作しない問題。原因は HaishinKit のバージョン問題（v2.x beta）。v1.9.x では問題なし。

### YouTube Studio のストリームキーの正体

YouTube Studio の「エンコーダー配信」で表示されるストリームキーは、YouTube が内部管理するカスタムストリームキー（reusable）であり、形式は `xxxx-xxxx-xxxx-xxxx-xxxx`。このキーは YouTube RTMP サーバーに**事前プロビジョニング**されており、即座にデータ受信が可能。

API で `liveStreams.insert` で作成したストリームも同じ形式のキーを返すが、**YouTube RTMP サーバー側でのプロビジョニングが完了するまでデータを受け付けない**可能性がある。

## 修正方針の選択肢

### 方針A: YouTube Studio のストリームキーを API で取得して再利用する

- **概要**: YouTube Studio で手動作成されたストリームキー（カスタムストリームキー）を API で特定し、そのストリームを再利用する。`listStreams` で取得したストリームの中から `isDefaultStream` や `snippet.title` の特徴で YouTube Studio のストリームを識別する。
- **技術的根拠**: 手動ストリームキーで正常動作することが確認済み。YouTube Studio のストリームキーは YouTube RTMP サーバーに常時プロビジョニングされているため、プロビジョニング遅延の問題を完全に回避できる。
- **メリット**:
  - 問題の根本原因（プロビジョニング遅延）を回避
  - YouTube Studio と API の整合性が保たれる
  - ユーザーが YouTube Studio で設定を管理できる
- **デメリット**:
  - YouTube Studio のストリームが `listStreams` で取得できない場合がある（non-reusable の場合）
  - ストリームの識別ロジックが不確実（API では YouTube Studio ストリームを確実に区別する方法がない）
  - YouTube Studio でストリームキーを変更すると動作しなくなる
- **工数目安**: 中
- **参考リンク**: [YouTube liveStreams リソース](https://developers.google.com/youtube/v3/live/docs/liveStreams)

### 方針B: 毎回新規ストリームを作成し、プロビジョニング完了をポーリングで待つ

- **概要**: `listStreams` による既存ストリーム再利用を廃止し、毎回 `liveStreams.insert` で新規ストリームを作成する。RTMP 接続前に `liveStreams.list(id=streamId)` で `streamStatus` をポーリングし、`ready` 状態を確認してから接続する。さらに RTMP 接続後も `streamStatus` が `active` になるまで待機する。
- **技術的根拠**: YouTube 公式「Life of a Broadcast」ドキュメントでは、RTMP 送信開始後に `streamStatus` が `active` になることを確認してからブロードキャストを `testing` に遷移するよう記載されている。現在のコードは固定 10秒待ちだが、新規ストリームのプロビジョニングには数十秒かかる場合がある。
- **メリット**:
  - 古いストリームの再利用による問題を完全に排除
  - プロビジョニング完了を確実に検知
  - YouTube 公式の推奨フローに準拠
- **デメリット**:
  - 配信開始まで時間がかかる（プロビジョニング待ち）
  - API quota を消費する（毎回ストリーム作成 + 定期ポーリング）
  - プロビジョニングが完了しないケース（YouTube 側の問題）への対応が必要
- **工数目安**: 小〜中
- **参考リンク**: [Life of a Broadcast](https://developers.google.com/youtube/v3/live/life-of-a-broadcast)

### 方針C: ユーザーに YouTube Studio のストリームキーを手動入力させ、API はブロードキャスト管理のみ行う（ハイブリッド方式）

- **概要**: ストリームの作成・管理は YouTube Studio に任せ、API は `liveBroadcasts.insert` + `liveBroadcasts.bind` + `liveBroadcasts.transition` のみ行う。ユーザーは初回のみ YouTube Studio からストリームキーを入力し、以降はそのキーを再利用する。ストリーム ID の取得は `liveStreams.list` で行う。
- **技術的根拠**: 手動ストリームキーで動作実績がある。YouTube Studio が管理するストリームは確実にプロビジョニングされており、プロビジョニング遅延が発生しない。ブロードキャスト管理は API で自動化しつつ、RTMP 接続の信頼性を最大化する。
- **メリット**:
  - RTMP 接続が確実に動作する（実績あり）
  - ブロードキャスト管理（作成・遷移・完了）は自動化
  - API quota の消費が最小限（ストリーム作成不要）
  - プロビジョニング待ちが不要で即座に配信開始
- **デメリット**:
  - ユーザーが初回に YouTube Studio からストリームキーを手動コピーする必要がある
  - 完全自動化ではない（UX がやや低下）
  - ストリームキーの管理がユーザー責任
- **工数目安**: 小
- **参考リンク**: [YouTube Studio エンコーダー配信](https://support.google.com/youtube/answer/2907883?hl=en)

### 方針D: API 作成ストリームの RTMPS 接続に切り替え + 積極的なプロビジョニング待ち

- **概要**: RTMP (`rtmp://a.rtmp.youtube.com/live2`) から RTMPS (`rtmps://a.rtmps.youtube.com/live2`) に切り替える。加えて、ストリーム作成後に `streamStatus` が `ready` になるまでポーリングし、RTMP 接続後は `active` になるまで最大60秒待機する。
- **技術的根拠**: YouTube の RTMPS ドキュメントでは、RTMPS が推奨プロトコルとされている。また、一部の環境では RTMP（暗号化なし）での接続がファイアウォールやプロバイダによってブロックされる可能性がある。RTMPS に切り替えることで接続の信頼性が向上する可能性がある。ただし、手動ストリームキーでは RTMP で動作しているため、これが直接の原因である可能性は低い。
- **メリット**:
  - セキュリティ向上（TLS暗号化）
  - YouTube の推奨に準拠
  - プロビジョニング完了確認のロジックが堅牢
- **デメリット**:
  - HaishinKit v1.9.9 が RTMPS を完全サポートしているか確認が必要
  - 問題の根本原因がプロトコルでない場合、効果がない
  - 実装の複雑さが増す
- **工数目安**: 中〜大
- **参考リンク**: [YouTube RTMPS Ingestion Guide](https://developers.google.com/youtube/v3/live/guides/rtmps-ingestion)

## 推奨

**方針B（毎回新規ストリーム作成 + プロビジョニング待ちポーリング）を第一選択として推奨する。**

理由:

1. **問題の根本原因に対処**: 現在のコードの最大の問題は、`listStreams` で取得した古いストリームを再利用していることである。YouTube RTMP サーバーは、ストリームキーとブロードキャストのバインディングが正しい状態でないとデータを受け付けない可能性がある。毎回新規作成すれば、この問題を排除できる。

2. **公式推奨フローに準拠**: YouTube 公式ドキュメントの「Life of a Broadcast」で示されたフロー（create -> bind -> send data -> confirm active -> transition）に完全に従う。

3. **既存コードへの影響が小さい**: `setupLiveStream()` の Step 2 を「常に新規作成」に変更し、`startYouTubeAPIStreaming()` のプロビジョニング待ちを固定10秒からポーリングに変更するだけ。

**具体的な実装方針:**

```
1. setupLiveStream() の Step 2 を変更:
   - listStreams による既存ストリーム検索を削除
   - 常に createStream() で新規ストリームを作成
   - isReusable: false を CDN 設定に追加（使い捨て）

2. RTMP 接続前にストリーム状態を確認:
   - getStreamHealth() で streamStatus をポーリング
   - "ready" になるまで最大30秒待機
   - timeout 時はエラーを表示

3. RTMP 接続後にデータ受信を確認:
   - streamStatus が "active" になるまで最大30秒ポーリング
   - "active" 確認後に testing/live 遷移を開始
   - 現行の lifecycleManager.startLifecycle() のロジックをそのまま活用

4. エラーハンドリング:
   - プロビジョニングタイムアウト → ユーザーに retry を促す
   - ストリームが active にならない → 手動ストリームキー使用を提案
```

**方針C をフォールバックとして併用することも推奨する。** 方針B でプロビジョニングが完了しない場合に備え、ユーザーが手動ストリームキーを入力できる UI は維持すべきである（現在の手動 RTMP フローがこれに該当するため、追加実装は不要）。

## 注意事項

### 実装時のリスク

1. **API Quota**: YouTube Data API v3 は 1日あたり 10,000 units の quota がある。`liveStreams.insert` は 50 units、`liveStreams.list` は 1 unit。配信テストを繰り返す場合は quota 消費に注意。

2. **プロビジョニング時間の不確実性**: YouTube がストリームを RTMP サーバーにプロビジョニングするまでの時間は公式に明示されていない。テスト環境で実測して適切なタイムアウト値を設定する必要がある。

3. **RTMP vs RTMPS**: 現在 `rtmp://` を使用しているが、YouTube は `rtmps://` を推奨している。将来的に `rtmp://` が廃止される可能性があるため、HaishinKit v1.9.9 の RTMPS 対応状況を調査しておくべき。

4. **reusable ストリームのクリーンアップ**: 方針B で毎回新規作成する場合、`isReusable: true`（デフォルト）のまま作成すると古いストリームが蓄積する。`isReusable: false` を設定するか、定期的に古いストリームを削除するロジックが必要。ただし YouTube API のストリーム削除には quota がかかる。

5. **既存の再利用ロジックの問題**: 現在の `listStreams` は前回 API で作成した reusable ストリームを返す可能性が高い。このストリームが前回の完了したブロードキャストにバインドされたままの場合、新しいブロードキャストとのバインドが意図通り動作しない可能性がある。これが noData の直接原因と考えられる。

### デバッグのポイント

問題の切り分けのために、以下のログを追加して確認することを推奨する:

- `listStreams` が返すストリームの `snippet.isDefaultStream` の値
- 使用するストリームの `id` と `cdn.ingestionInfo.streamName` の完全な値
- `streamStatus` の遷移タイミング（ready -> active の遷移にかかる時間）
- バインド後のブロードキャストの `contentDetails.boundStreamId` が正しいか

### テスト方針

1. **方針B の最小実装をまず試す**: `setupLiveStream` の Step 2 で `listStreams` を削除し、常に `createStream` を呼ぶ。10秒の固定待ちを30秒のポーリング待ちに変更。これだけで問題が解決するか確認。

2. **解決しない場合**: ストリーム作成後の `streamStatus` の遷移を詳細にログ出力し、YouTube 側でのプロビジョニングが実際に完了しているかを確認する。

3. **それでも解決しない場合**: 方針C（ハイブリッド方式）に切り替える。

Sources:
- [YouTube Live Streaming API Overview](https://developers.google.com/youtube/v3/live/getting-started)
- [LiveStreams Resource](https://developers.google.com/youtube/v3/live/docs/liveStreams)
- [Life of a Broadcast](https://developers.google.com/youtube/v3/live/life-of-a-broadcast)
- [Migration Guide: Default Broadcasts](https://developers.google.com/youtube/v3/live/guides/migration-guide-default-broadcasts)
- [RTMPS Ingestion Guide](https://developers.google.com/youtube/v3/live/guides/rtmps-ingestion)
- [YouTube API Errors](https://developers.google.com/youtube/v3/live/docs/errors)
- [LiveBroadcasts: bind](https://developers.google.com/youtube/v3/live/docs/liveBroadcasts/bind)
- [HaishinKit Discussion #1361](https://github.com/HaishinKit/HaishinKit.swift/discussions/1361)
- [HaishinKit Discussion #1585](https://github.com/shogo4405/HaishinKit.swift/discussions/1585)
- [CrowCam Issue #69](https://github.com/tfabris/CrowCam/issues/69)
- [YouTube Live Streaming via API (dev.to)](https://dev.to/toshvelaga/how-to-livestream-to-youtube-using-the-youtube-live-streaming-api-4klp)
- [YouTube API Revision History](https://developers.google.com/youtube/v3/live/revision_history)
