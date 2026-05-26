# 静止した顔のモザイクが一瞬外れる問題 分析レポート

**日付**: 2025-05-26
**課題**: ほとんど動いていない顔でもモザイクが一瞬外れてしまう（誤判定）
**深刻度**: Critical（プライバシーアプリとして致命的）

---

## 現状の問題

### 症状
- 未登録の顔がほぼ静止しているにもかかわらず、モザイクが一瞬外れる
- 外れた直後にすぐ復帰する（チラつき/フリッカー）
- プライバシー保護アプリとして「1フレームでも他人の顔が露出する」ことは許容できない

### 現在のパイプライン概要
```
カメラフレーム (30fps)
    |
    +---> [毎フレーム] Vision VNDetectFaceRectanglesRequest (位置検出のみ)
    |         |
    |         +---> displayTracker.assign() (IoU トラッキング)
    |         +---> 1-Euro フィルタで BBox 平滑化
    |         +---> TrackedFace.isRegistered を参照してブラー判定
    |
    +---> [~10fps, 別スレッド] FaceRecognitionService.detectAndIdentifyFaces()
              |
              +---> VNDetectFaceLandmarksRequest (ランドマーク検出)
              +---> FaceNet CoreML (128次元 embedding, cosine similarity)
              +---> FaceTracker (内部) のヒステリシス判定
              +---> displayTracker へ結果伝搬 (similarity=1.0 or 0.0)
```

---

## 原因分析

コードを精査した結果、**複数の脆弱性が連鎖的に作用して**この問題を引き起こしていると判断する。

### 根本原因 1: FaceNet の similarity がノイジーでスパイク的に高くなる

**MEMORYより**: FaceNet の cosine similarity は登録済み顔に対して自分自身でも ~0.43-0.59 であり、閾値 0.4 を使っている。この閾値に対するマージンが極めて小さい。

未登録の顔が照明変化・微妙な角度変化・ランドマーク検出のゆらぎにより embedding が一時的に変動し、cosine similarity が 0.4 を超えるスパイクが発生しうる。特に以下の要因でembeddingが不安定になる:

- **アライメントのゆらぎ**: `alignFace()` は目のランドマーク重心で回転・スケールするが、Vision のランドマーク座標はフレームごとに微妙に変動する。160x160 の入力画像がわずかにシフトするだけで embedding は大きく変わりうる
- **登録写真が1枚**: 単一の embedding との比較では、特定の角度・照明で偶然 similarity が上がる

### 根本原因 2: displayTracker への結果伝搬ロジックの設計上の欠陥

`VideoFrameProcessor.swift` L476-479:
```swift
// Feed similarity=1.0 for registered, 0.0 for unregistered
_ = displayFace.update(similarity: faces[i].isRegistered ? 1.0 : 0.0)
```

**問題点**: ここで `displayTracker` の `TrackedFace` に 1.0 または 0.0 のバイナリ値を渡している。FaceRecognitionService 内部の `faceTracker` はヒステリシス（enter=0.75, exit=0.60, window=7）で安定化しているが、その結果を **再度** displayTracker のヒステリシスに通すという二重構造になっている。

1.0 を受け取った displayTracker の TrackedFace は、window=7 のうち enter=0.75 を超えるには 7 フレーム中 6 回以上 1.0 が必要（平均 0.75 以上）。しかし、FaceRecognitionService 側で一瞬 `isRegistered=true` になると、displayTracker 側にも 1.0 が注入される。

**さらに問題なのは**: FaceRecognitionService 内部の `faceTracker` と VideoFrameProcessor の `displayTracker` は **別インスタンス** であり、**別のトラック ID 体系** を持つ。認識結果の IoU マッチングで誤ったトラックに結果が伝搬するリスクがある。

### 根本原因 3: 認識サービス内部のヒステリシスウィンドウの不十分さ

`TrackedFace` のパラメータ:
- `enterThreshold: 0.75`, `exitThreshold: 0.60`, `windowSize: 7`

window=7 で ~10fps の認識頻度だと、約 0.7 秒分のヒストリしかない。FaceNet の similarity がスパイク的に高くなるケースでは:
- 3-4 フレーム連続で similarity > 0.4 → FaceRecognitionService 内で `isRegistered=true`
- すると displayTracker にも 1.0 が注入される
- **一瞬でもモザイクが外れる**

### 根本原因 4: cachedFaces の上書きタイミング

`VideoFrameProcessor.swift` L483:
```swift
self?.cachedFaces = faces
```

認識スレッドが完了すると `cachedFaces` を直接上書きする。この `faces` は FaceRecognitionService の判定結果であり、displayTracker のヒステリシスとは独立している。つまり、FaceRecognitionService が一瞬 `isRegistered=true` を返すと、その結果が次のフレーム描画にそのまま使われる。

### 根本原因 5: 「安全側フォールバック」の設計思想の欠如

現在のコードには「迷ったらブラーする」という安全側の設計原則が徹底されていない。例えば:
- FaceNet が nil を返した場合は similarity=0（安全側）だが
- FaceNet が偽陽性で高い similarity を返した場合のガード機構がない
- 「一度でもブラーされた顔は、十分な確信がない限りブラーし続ける」というポリシーがない

---

## 調査結果

### ベストプラクティス: テンポラル多数決投票

学術研究（CHI、CVPR等）では、ビデオベースの顔認識でフリッカーを防ぐために **テンポラル多数決投票（temporal majority voting）** が標準手法である。直近 N フレームの判定結果を集計し、M 回以上「登録済み」と判定された場合のみ登録済みとする。

- 参考: "A Sliding Window Based Approach With Majority Voting" (ACM 2022)
- 参考: "Video-Based Face Recognition Using Probabilistic Appearance Manifolds" (CVPR 2003)

### VNDetectFaceCaptureQualityRequest の活用

Apple Vision Framework には `VNDetectFaceCaptureQualityRequest` がある。顔の品質スコア（0.0-1.0）を返し、照明・ブレ・ポーズを評価する。**品質が低いフレームでの認識結果を無視する**ことで、ノイジーな embedding によるスパイクを防げる。

- 参考: [Apple Developer Documentation - VNDetectFaceCaptureQualityRequest](https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest)

### より優れた顔認識モデル

現在の MobileFaceNet (foamliu版) は LFW で 99.55%、MegaFace で 92.59% (TAR@FAR1e-6)。しかし:

- **ArcFace/InsightFace**: ONNX 対応、CoreML 変換可能。LFW 99.83%、MegaFace 98.35%。
- **AdaFace**: 画像品質が低い場面で特に強い。カメラアプリの現実的な使用条件に適合。
- **EdgeFace**: モバイルデバイス向けに最適化。

参考: [InsightFace GitHub](https://github.com/deepinsight/insightface), [AdaFace Paper](https://arxiv.org/abs/2311.15326)

### VNTrackObjectRequest による追跡

現在の IoU ベーストラッキングを Apple の `VNTrackObjectRequest` に置き換えることで、Vision Framework のネイティブトラッキング（テンポラル情報を活用）を利用でき、トラック ID の安定性が向上する。

---

## 修正方針の選択肢

### 方針A: 安全側フォールバック + ヒステリシス強化（判定ロジックの根本改修）

**概要**: 「blur-by-default」原則を徹底し、判定ロジックを根本から再設計する。FaceNet の精度改善はせず、既存モデルの出力をより安全に使う。

**具体的な変更**:

1. **非対称ヒステリシスの大幅強化**
   - `enterThreshold`: 0.75 → 0.85（登録済みと判定するハードルを上げる）
   - `exitThreshold`: 0.60 → 0.40（一度登録と判定したら離脱しにくくする）
   - `windowSize`: 7 → 15（約1.5秒分のヒストリに拡大）

2. **「blur-by-default」ガードの追加**
   - 新規トラックは最初の N フレーム（例: 10フレーム）は**必ずブラー**
   - `isRegistered` を true にするには、連続 M 回以上（例: 8回連続）similarity > threshold が必要
   - `isRegistered` が true になった後も、similarity が 1 回でも threshold を大きく下回ったら即座に false に戻す

3. **二重トラッカー構造の統合**
   - FaceRecognitionService 内の `faceTracker` と VideoFrameProcessor の `displayTracker` を統合
   - 認識結果はバイナリ (1.0/0.0) ではなく、**実際の similarity 値**を displayTracker に渡す
   - displayTracker 側で一元的にヒステリシス判定を行う

4. **cachedFaces の直接上書き禁止**
   - 認識結果は displayTracker の状態更新にのみ使い、描画は常に displayTracker の状態から生成

**技術的根拠**: 現在の問題は判定ロジックの構造的欠陥（二重トラッカー、バイナリ値伝搬、不十分なウィンドウ）が主因。モデルを変えなくても、判定ロジックの改善だけでフリッカーの大半を解消できる。

**メリット**:
- モデル変更不要、純粋なロジック改修のみ
- 既存のテストを大きく壊さない
- 実装工数が最も小さい
- 最悪ケース（モデルが間違えた場合）でも安全側に倒れる

**デメリット**:
- 登録済み顔の認識にかかる時間が長くなる（初回ブラーが1-2秒続く）
- FaceNet 自体の精度問題は解決しない
- threshold のチューニングが必要

**工数目安**: 小（1-2日）

### 方針B: 顔品質フィルタ + テンポラル多数決投票の導入

**概要**: Apple の VNDetectFaceCaptureQualityRequest で各フレームの顔品質を評価し、品質が低いフレームの認識結果を棄却する。さらにテンポラル多数決投票で最終判定の安定性を高める。

**具体的な変更**:

1. **VNDetectFaceCaptureQualityRequest の統合**
   - 各認識フレームで顔品質スコアを取得
   - 品質スコアが閾値（例: 0.3）未満のフレームでは embedding 計算をスキップ
   - 品質スコアで similarity に重み付け（高品質な判定結果ほど信頼度が高い）

2. **テンポラル多数決投票の実装**
   - 直近 N フレーム（例: 20フレーム = 約2秒）の判定結果をリングバッファに保持
   - 「登録済み」判定が M 回以上（例: 15/20 = 75%以上）の場合のみブラー解除
   - 「未登録」判定への遷移は N/2 回未満で即座に実行（安全側に非対称）

3. **品質重み付き投票**
   - 各投票に品質スコアを重みとして付加
   - 高品質フレームの判定結果ほど投票の影響力が大きい
   - 低品質フレームでの偽陽性の影響を自然に抑制

**技術的根拠**: FaceNet の embedding がフレームごとにノイジーなのは、入力画像の品質（ブレ、照明、ポーズ）が不安定なことが主因。品質フィルタリングにより、ノイジーな embedding が判定に影響するのを事前に防げる。多数決投票は学術的にも実証済みの手法。

**メリット**:
- 偽陽性の根本原因（低品質フレームでのノイジーな embedding）に対処
- Apple 純正 API を活用するため追加のモデル不要
- 品質スコアは Vision Framework が提供するため計算コスト低い
- 学術的に裏付けのある手法

**デメリット**:
- VNDetectFaceCaptureQualityRequest のオーバーヘッド（ただし軽量）
- 品質閾値のチューニングが必要
- FaceNet モデル自体の精度限界は変わらない

**工数目安**: 中（2-3日）

**参考リンク**:
- [VNDetectFaceCaptureQualityRequest - Apple](https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest)
- [Selecting a selfie based on capture quality - Apple](https://developer.apple.com/documentation/Vision/selecting-a-selfie-based-on-capture-quality)

### 方針C: ArcFace/AdaFace モデルへの置き換え + 方針A の併用

**概要**: FaceNet を InsightFace の ArcFace (または AdaFace) に置き換えることで、embedding の品質と弁別力を根本的に改善する。加えて方針A の安全側フォールバックも適用する。

**具体的な変更**:

1. **ArcFace モデルの CoreML 変換と統合**
   - InsightFace の ArcFace (r50 or r18) を PyTorch → ONNX → CoreML で変換
   - 入力サイズ 112x112、出力 512次元 embedding
   - Apple Neural Engine 対応の CoreML 最適化

2. **AdaFace の検討**
   - カメラの画質が安定しない環境では AdaFace が優位
   - 品質適応型のマージンペナルティにより、低品質画像での False Positive Rate が低い

3. **閾値の再設定**
   - ArcFace は同一人物の cosine similarity が 0.6-0.8 程度（FaceNet の 0.43-0.59 より高い）
   - enter threshold を 0.55-0.65 に設定でき、マージンが大きくなる
   - 他人の similarity は 0.1-0.3 程度まで下がるため、偽陽性の可能性が大幅に減少

4. **方針A の安全側ロジックを併用**

**技術的根拠**: 現在の MobileFaceNet (foamliu版) は similarity のマージンが非常に小さい (自分: 0.43-0.59, 閾値: 0.4)。ArcFace は Angular Margin Loss により embedding 空間でのクラス間分離が大きく、同一条件でのマージンが 2-3 倍になる。LFW 99.83%, MegaFace 98.35% の精度は MobileFaceNet を大きく上回る。

**メリット**:
- 根本的に embedding の品質が向上し、偽陽性率が桁違いに改善
- 閾値のマージンが大きくなり、パラメータチューニングに対してロバスト
- Apple Neural Engine で高速推論可能
- 512次元 embedding により弁別力が向上

**デメリット**:
- モデル変換パイプライン（PyTorch → ONNX → CoreML）の構築が必要
- モデルサイズが大きくなる可能性（r50: ~166MB、r18: ~92MB）
- 入出力の前処理・後処理コードの書き換えが必要
- テストの大幅な修正が必要

**工数目安**: 大（5-7日）

**参考リンク**:
- [InsightFace GitHub](https://github.com/deepinsight/insightface)
- [ArcFace Paper](https://arxiv.org/abs/1801.07698)
- [AdaFace Paper](https://arxiv.org/abs/2311.15326)
- [EdgeFace Paper](https://arxiv.org/abs/2307.01838)

---

## 推奨

### 推奨: 方針A を即座に実施し、その後 方針B を追加、余裕があれば方針C

**理由**:

1. **方針A は即効性がある**: 現在の最大の問題は FaceNet の精度ではなく、**判定ロジックの構造的欠陥**である。二重トラッカー、バイナリ値伝搬、不十分なウィンドウサイズ、安全側フォールバックの欠如 -- これらは全てロジック改修だけで修正できる。1-2日で実装可能。

2. **方針B はコストパフォーマンスが良い**: VNDetectFaceCaptureQualityRequest は Apple の純正 API であり、追加のモデル不要で品質ベースのフィルタリングが可能。方針A と組み合わせることで、偽陽性をさらに減少できる。

3. **方針C は必要に応じて**: ArcFace への置き換えは効果が最も大きいが、工数も大きい。方針A+B で許容範囲に入らなかった場合の最終手段として位置づける。

### 実施優先順位

```
Phase 1 (即時, 1-2日): 方針A - 判定ロジックの根本改修
    -> これだけでフリッカーの大半が解消されるはず

Phase 2 (次週, 2-3日): 方針B - 品質フィルタ + 多数決投票
    -> Phase 1 で解消しきれない低品質フレーム起因の問題に対処

Phase 3 (将来, 5-7日): 方針C - ArcFace 導入
    -> Phase 1+2 でも不十分な場合、または精度をさらに追求する場合
```

---

## 注意事項

### 実装時に気をつけるべきこと

1. **二重トラッカー統合時のスレッドセーフティ**: 現在 `displayTracker` は processingQueue、`faceTracker` は recognitionQueue で操作されている。統合する際にはロックまたはシリアルキューによる排他制御が必須。

2. **初回ブラー期間のUX**: 方針A で新規トラックを N フレームブラーにすると、登録済みユーザーも最初の 1-2 秒ブラーされる。これはプライバシーアプリとしては正しい動作（安全側に倒している）だが、ユーザー体験としてはトレードオフ。許容範囲かどうかは実機テストで確認が必要。

3. **パラメータのハードコード回避**: ヒステリシス閾値、ウィンドウサイズ、品質閾値はデバイスやユースケースによって最適値が異なる。設定画面から変更可能にするか、少なくとも定数として一箇所に集約すべき。

4. **回帰テスト**: 方針A の二重トラッカー統合は `VideoFrameProcessorTests` と `FaceRecognitionServiceTests` の双方に影響する。テスト修正を忘れないこと。

5. **ログの強化**: 現在 `print` で similarity をログ出力しているが、デバッグ効率のために以下の情報も出力すべき:
   - フレーム番号
   - 品質スコア（方針B導入時）
   - ヒステリシスウィンドウの現在の平均値
   - 状態遷移（blur→unblur, unblur→blur）のタイミング

6. **「モザイクが外れてはならない」の定量的基準**: 現在の要件は定性的。定量的な基準（例: False Unblur Rate < 0.01%、つまり 10,000 フレームに 1 回未満）を定めて、テストで検証可能にすべき。

### 既知のリスク

- **方針A の閾値調整**: enterThreshold を上げすぎると、登録済みユーザーの顔もブラーされ続ける可能性がある。FaceNet の similarity が 0.43-0.59 という現状では、enterThreshold=0.85（バイナリ 1.0/0.0 の場合）は妥当だが、実際の similarity 値を渡すように変更した場合は 0.50 程度まで下げる必要がある。
- **方針C のモデル変換**: PyTorch → ONNX → CoreML の変換パイプラインで、特に量子化や型変換での精度劣化に注意。変換後の embedding の品質を Python 環境と iOS 環境で比較検証すべき。
- **MobileFaceNet.mlpackage の既知問題**: MEMORY によると、MobileFaceNet.mlpackage は「重みが正しくロードされなかった」とあり、未使用。別モデルへの移行時に同様の問題が起きないよう、変換パイプラインの検証を慎重に行うこと。

---

## 参考リンク

- [MobileFaceNets Paper (arXiv)](https://arxiv.org/pdf/1804.07573)
- [ArcFace Paper (arXiv)](https://arxiv.org/abs/1801.07698)
- [InsightFace GitHub](https://github.com/deepinsight/insightface)
- [AdaFace / LittleFaceNet (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11766931/)
- [EdgeFace Paper (arXiv)](https://arxiv.org/html/2307.01838v2)
- [VNDetectFaceCaptureQualityRequest - Apple Developer](https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest)
- [Selecting a selfie based on capture quality - Apple Developer](https://developer.apple.com/documentation/Vision/selecting-a-selfie-based-on-capture-quality)
- [Temporal Majority Voting for Action Recognition (ACM 2022)](https://dl.acm.org/doi/10.1145/3529399.3529425)
- [A Survey of Face Recognition (arXiv)](https://arxiv.org/pdf/2212.13038)
- [Face Recognition Systems Comparison 2026](https://facecheck.id/Face-Search-face-recognition-api)
- [BLUFADER: Privacy-friendly Continuous Authentication](https://www.sciencedirect.com/science/article/pii/S1574119223000597)
- [Verkada Live Face Blur](https://www.verkada.com/blog/announcing-live-face-blur/)
