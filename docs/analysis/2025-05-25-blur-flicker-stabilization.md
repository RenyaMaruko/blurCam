# リアルタイム顔モザイクのチラつき問題 分析レポート

**日付:** 2025-05-25
**対象:** VideoFrameProcessor / BlurProcessingService / ProcessedCameraPreviewView
**症状:** モザイク枠が微妙に震えてチラチラ見える。追従遅れが発生する場合がある。

---

## 現状の問題

### 1. 症状の詳細

- モザイクの付与/解除は安定している（認識判定の問題ではない）
- **モザイクの矩形自体が毎フレーム微妙に振動**し、視覚的にチラつく
- カメラを動かした際に追従が遅れる場合がある

### 2. 既に実装済みの対策

| 対策 | 実装箇所 | 効果 |
|---|---|---|
| 速度適応型lerp (t=0.25~0.85) | `smoothBox()` in VideoFrameProcessor L379-424 | 部分的 |
| 1フレーム先の位置予測 | `smoothBox()` 内の velocity prediction | 部分的 |
| 量子化 (0.003刻みスナップ) | `smoothBox()` 内の quantization | 部分的 |
| IoUトラッキング + ヒステリシス | FaceTracker + TrackedFace | 安定 |
| ロスト・トレランス (8フレーム) | TrackedFace.markMissed() | 安定 |
| Vision/FaceNet 分離スレッド | recognitionQueue | 安定 |

---

## 原因分析

コードを精査した結果、チラつきの原因は **単一のボトルネックではなく、パイプライン全体にわたる複数の問題の複合** であると判断する。

### 原因1: VNDetectFaceRectanglesRequest を毎フレーム実行している（根本原因）

**VideoFrameProcessor.swift L457-499**: 毎フレームで `VNDetectFaceRectanglesRequest` を実行している。Vision の顔検出は **検出器** であり **トラッカー** ではない。検出器はフレーム間の時間的連続性を一切考慮しないため、同じ顔でもフレームごとにバウンディングボックスが 1-3 ピクセル（正規化座標で 0.001-0.005 程度）ノイズ的に変動する。

現在の smoothBox() の lerp でこのノイズを抑制しようとしているが、**ノイズの根本原因を放置したまま後段で平滑化する**アプローチには限界がある。特に:
- `t=0.25` (静止時) でも 25% のノイズが通過する
- 量子化ステップ 0.003 は、検出ノイズの振幅と同程度かそれより小さいため、量子化しても振動が残る

### 原因2: 平滑化フィルタの設計が不適切

現在の速度適応型 lerp は「速度が大きいほど追従を強くする」設計だが、以下の問題がある:

1. **速度の推定がノイジー**: `movement = hypot(predicted.midX - previous.midX, ...)` は、検出ノイズ自体を「動き」と誤認する。顔が静止していてもノイズで movement > 0 となり、t が上昇して平滑化が弱まる悪循環が発生する
2. **予測がノイズを増幅**: `prevRawBoxes` から速度を計算して外挿しているが、raw な検出結果からの速度自体がノイジーなので、予測値がさらに振れる
3. **単純 lerp の限界**: 指数平滑化（EMA）は低域通過フィルタとしてはカットオフ周波数が固定で、ジッタ除去と追従性のトレードオフを柔軟に制御できない

### 原因3: フレームと顔データの非同期性

**VideoFrameProcessor.swift L530-562**: `cachedFaces` は Vision 検出のたびに更新され、ブラー適用は同じフレームの `cachedFaces` を使う。ここまでは同期的。しかし:

- **FramePublisher**: `updateFrame()` と `updateFaces()` がそれぞれ別の `DispatchQueue.main.async` で発火する（ProcessedCameraPreviewView.swift L37-47）。フレームと顔データのメインスレッド到着タイミングが1フレームずれる可能性がある
- **CATransaction アニメーション**: `updateFaceOverlays()` で `CATransaction.setAnimationDuration(0.12)` を使っているが、これはオーバーレイ（登録済み顔の枠）のみに影響し、**ブラー領域自体には影響しない**

### 原因4: ブラーマスクの形状がバウンディングボックスに直結

**BlurProcessingService.swift L157-177**: `createEllipticalMask()` で `CIRadialGradient` を使い、バウンディングボックスの center/radius からマスクを生成している。バウンディングボックスが 1 ピクセルでも動けば、マスクの中心と半径が変わり、ブラー境界が移動して視認できるチラつきになる。

### 原因5: レンダリングパイプラインの二重フレームレート

- **MTKView**: `preferredFramesPerSecond = 30` (ProcessedCameraPreviewView.swift L147)
- **CADisplayLink**: `preferredFrameRateRange(minimum: 20, maximum: 30, preferred: 30)` (L171)
- **カメラ出力**: デバイスによって 24/30/60 fps

MTKView の描画コールバックと CADisplayLink のフレーム取得が独立して動作しており、MTKView が描画する時点で `currentImage` が最新とは限らない。これが「同じ画像が2回描画 → 次の画像に飛ぶ」というフレームスキッピング的なチラつきを生む。

---

## 調査結果

### ベストプラクティス: Apple VNTrackObjectRequest

Apple 公式の「Tracking the User's Face in Real Time」サンプルコード（参考: [tiagomartinho/VisionAppleSample](https://github.com/tiagomartinho/VisionAppleSample)）では、以下のハイブリッドアプローチを推奨:

1. **VNDetectFaceRectanglesRequest** で初回/定期的に顔を検出
2. 検出結果から **VNTrackObjectRequest** を生成
3. 以降のフレームでは VNSequenceRequestHandler + VNTrackObjectRequest で **トラッキング**
4. confidence が 0.3 以下に落ちたら再検出

これにより、検出ノイズではなく **光学フロー** ベースの滑らかなバウンディングボックス更新が得られる。

### ベストプラクティス: 1-Euro フィルタ

学術論文「1 Euro Filter: A Simple Speed-based Low-pass Filter for Noisy Input in Interactive Systems」（CHI 2012, [gery.casiez.net/1euro](https://gery.casiez.net/1euro/)）で提案されたフィルタ。MediaPipe の顔ランドマーク安定化にも採用されている。

特徴:
- 低速時はカットオフ周波数を下げてジッタを強力に除去
- 高速時はカットオフ周波数を上げてラグを最小化
- 現在の実装の「速度適応型 lerp」と目的は同じだが、**数学的により洗練された設計**で、パラメータチューニングが容易

Swift 実装: [masterchef8/OneEuroFilter](https://github.com/masterchef8/OneEuroFilter)

### ベストプラクティス: WWDC20 Core Image パイプライン最適化

[WWDC20 セッション 10008](https://developer.apple.com/videos/play/wwdc2020/10008/) の推奨:

- CIContext は **1つだけ** 作成し使い回す（現在のコードは VideoFrameProcessor と BlurProcessingService で **2つ** の CIContext を生成しており、非効率）
- Metal コマンドキューを CIContext と MTKView で **共有** すべき（現在は分離している）
- `CIRenderDestination` を活用し、GPU パイプラインバブルを削減

### 事例: FaceBlurApp (mrousavy)

[mrousavy/FaceBlurApp](https://github.com/mrousavy/FaceBlurApp) では:
- Frame Processor を C++ で実装し、検出と描画を同一スレッドで同期的に処理
- 「検出結果 → 即座にブラー適用 → 描画」を1つのパイプラインで完結させることでフレーム遅延ゼロを実現

### Kalman フィルタによるバウンディングボックス安定化

学術研究 ([ResearchGate](https://www.researchgate.net/publication/358558079_Bounding_Box_Stabilization_for_Visual_Object_Tracking_Using_Kalman_and_FIR_Filters)) で、Kalman フィルタによるバウンディングボックスの位置・サイズの安定化が有効であることが示されている。1-Euro フィルタより状態推定の精度は高いが、実装とチューニングが複雑。

---

## 修正方針の選択肢

### 方針A: VNTrackObjectRequest ハイブリッド + 1-Euro フィルタ（推奨）

**概要:**
毎フレームの VNDetectFaceRectanglesRequest を廃止し、Apple の VNTrackObjectRequest による光学フローベースのトラッキングに切り替える。さらに、トラッキング結果に 1-Euro フィルタを適用して残留ジッタを除去する。

**技術的根拠:**
- VNTrackObjectRequest はフレーム間の連続性を利用するため、検出器のようなフレーム単位のノイズが発生しない
- Apple 公式サンプルで推奨されている手法であり、Vision フレームワーク内で最適化されている
- 1-Euro フィルタは MediaPipe でも採用実績があり、速度適応の数学的基盤が確立されている
- 現在の自前 IoU トラッキング + lerp を、OS レベルのトラッキング + 学術的に裏付けられたフィルタに置き換えることになる

**実装の要点:**
1. `VNSequenceRequestHandler` をインスタンス変数として保持
2. N フレームごと（例: 10フレーム = ~0.33秒）に VNDetectFaceRectanglesRequest で再検出し、新しい顔の出現/消失を検知
3. 中間フレームでは VNTrackObjectRequest で各顔をトラッキング（`.fast` レベル）
4. トラッキング結果の x, y, width, height 各値に 1-Euro フィルタを適用（1顔あたり4つのフィルタインスタンス）
5. FaceNet 認識は現在のまま間引き実行（トラッキングの identity は VNTrackObjectRequest の trackID で維持）

**メリット:**
- チラつきの根本原因（毎フレーム検出）を解消
- CPU 負荷が大幅に減少（検出は毎フレーム → 10フレームに1回）
- Apple 公式推奨のパターンに準拠
- 1-Euro フィルタでトラッキング残留ノイズも除去可能

**デメリット:**
- VNSequenceRequestHandler の状態管理が必要（カメラ切替・画面遷移時のリセット）
- 新しい顔が画面に入ってから検出されるまで最大 0.33 秒のラグ（検出間隔に依存）
- VNTrackObjectRequest の confidence が低い場合のフォールバック処理が必要

**工数目安:** 中

**参考リンク:**
- [Apple: Tracking the User's Face in Real Time](https://developer.apple.com/documentation/vision/tracking-the-user-s-face-in-real-time)
- [VNTrackObjectRequest API](https://developer.apple.com/documentation/vision/vntrackobjectrequest)
- [Apple VisionFaceTrack サンプルコード](https://github.com/tiagomartinho/VisionAppleSample)
- [1-Euro Filter 公式](https://gery.casiez.net/1euro/)
- [1-Euro Filter Swift 実装](https://github.com/masterchef8/OneEuroFilter)

---

### 方針B: 1-Euro フィルタ導入 + パイプライン同期修正（中程度の改善）

**概要:**
現在の毎フレーム VNDetectFaceRectanglesRequest アーキテクチャは維持しつつ、smoothBox() を 1-Euro フィルタに置き換え、かつパイプラインの非同期問題を修正する。

**技術的根拠:**
- 現在の lerp は「ノイズを速度と誤認して追従を強める」悪循環がある。1-Euro フィルタは速度推定自体にもフィルタをかける（微分にも低域通過フィルタを適用）ため、この問題が起きにくい
- FramePublisher の updateFrame/updateFaces の非同期ずれを修正することで、「顔データが古いフレームに適用される」問題を解消

**実装の要点:**
1. `smoothBox()` を削除し、1-Euro フィルタに置き換え
   - 各 trackID に対して x, y, w, h 用の OneEuroFilter を4つ保持
   - 推奨パラメータ: `freq=30.0, mincutoff=0.5, beta=0.007, dcutoff=1.0` から調整開始
2. 位置予測（velocity extrapolation）を削除（1-Euro フィルタが速度適応を内包するため不要）
3. 量子化を削除（1-Euro フィルタが十分なジッタ除去を行うため不要）
4. FramePublisher で frame と faces をペアとして同期的に送信
   - `updateFrame(_ frame: CIImage, faces: [DetectedFace])` のようなシグネチャに変更
5. CIContext を1つに統合（VideoFrameProcessor と BlurProcessingService で共有）

**メリット:**
- 既存アーキテクチャを大きく変えない
- 1-Euro フィルタの導入自体は小さな変更
- パイプライン同期修正で追従遅れも改善
- CIContext 統合で GPU メモリ/パフォーマンス改善

**デメリット:**
- 毎フレーム検出の CPU 負荷は解消しない
- 検出器のノイズ自体は残るため、1-Euro フィルタに全面的に依存する（パラメータ調整がシビア）
- 「チラつきゼロ」の目標達成は方針Aより困難

**工数目安:** 小

**参考リンク:**
- [1-Euro Filter 論文 (CHI 2012)](https://dl.acm.org/doi/10.1145/2207676.2208639)
- [WWDC20: Optimize the Core Image pipeline](https://developer.apple.com/videos/play/wwdc2020/10008/)

---

### 方針C: フルフレームブラー + マスクテンポラル安定化（描画レイヤーで解決）

**概要:**
検出/トラッキングのアプローチは変更せず、ブラーの適用方法を根本的に変える。毎フレーム「全画面ブラー画像」を保持し、マスク側で安定化を行うことでチラつきを視覚的に解消する。

**技術的根拠:**
- 動画編集ソフトで「安定したモザイク」に見えるのは、ブラー画像自体は毎フレーム一定（全画面にかかっている）で、**マスクの移動だけが見える**から
- マスクの移動が滑らかであれば、ブラー境界のチラつきは知覚されない
- 現在の実装も「全画面ブラー + マスク合成」だが、マスクの radius0/radius1 がバウンディングボックスに直結しているため振動する

**実装の要点:**
1. **マスクの時間的ブレンド**: 現在のマスクと前フレームのマスクを alpha ブレンドする
   - `CIImage` レベルで前フレームマスクを保持
   - `blendedMask = previousMask * (1-alpha) + currentMask * alpha` (alpha = 0.3~0.5)
   - 効果: マスク境界の急激な変化が緩和され、滑らかに見える
2. **マスクの解像度を下げる**: マスク画像を元画像の 1/4 解像度で生成し、バイリニア補間で拡大
   - 効果: 高周波ジッタが物理的に表現できなくなる
3. **CIMaskedVariableBlur の活用**: `CIGaussianBlur` + `CIBlendWithMask` の代わりに `CIMaskedVariableBlur` を使用
   - マスクの輝度値でブラー量を制御するため、ソフトエッジが自然に出る
   - グラデーションマスクにより、ブラー境界の移動が目立ちにくい
4. **ブラーマスクの拡大パディング**: 顔矩形より 30-40% 大きいマスクを使用し、境界を顔の外側に置く
   - 顔の輪郭付近でブラー境界が動いても、すでにブラー領域内なので見えない

**メリット:**
- 検出/トラッキングのコードを一切変更しない
- マスクのテンポラルブレンドは実装が非常にシンプル（CIImage を1枚保持するだけ）
- 視覚的な安定感は方針A/Bより即効性がある
- 「完全にチラつきゼロ」に最も近い結果が得られる可能性が高い

**デメリット:**
- 前フレームマスク保持による GPU メモリ消費増加
- テンポラルブレンドにより、顔の急速移動時にマスクが遅れる（ゴースト現象）
- 検出の CPU 負荷は解消しない
- 根本原因（検出ノイズ）は隠蔽されるだけで解消されない

**工数目安:** 小~中

**参考リンク:**
- [CIMaskedVariableBlur API](https://developer.apple.com/documentation/coreimage/cimaskedvariableblur)
- [テンポラルスムージング手法](https://www.technetexperts.com/video-inpainting-ffmpeg-opencv/)

---

## 推奨

**方針A + 方針C の組み合わせ** を推奨する。

### 理由

1. **方針A (VNTrackObjectRequest + 1-Euro)** はチラつきの根本原因を解消する。毎フレーム検出という設計判断が問題の大元であり、Apple が用意した VNTrackObjectRequest こそが「フレーム間でバウンディングボックスを安定させる」ための API である。これを使わないのは車輪の再発明である。

2. **方針C (マスクテンポラル安定化)** は描画レイヤーで残留ジッタを吸収する最後の砦である。VNTrackObjectRequest + 1-Euro で 95% のジッタは消えるが、残り 5%（例: 顔検出の再実行タイミング、トラッキング confidence の揺れ）を完全に消すには、マスク側のテンポラルブレンドが有効。

3. 両方を組み合わせることで「チラつきゼロ」という目標に到達できる。

### 実装順序

1. **まず方針C のマスクテンポラルブレンドを実装**（工数: 小、即効性あり）
   - これだけでも体感の改善は大きい
   - 効果を実機で確認し、残留するチラつきの程度を評価
2. **次に方針A の VNTrackObjectRequest 導入**（工数: 中）
   - 根本的な改善
   - CPU 負荷の削減も期待できる
3. **最後に 1-Euro フィルタで仕上げ**
   - 方針A のトラッキング結果に残る微小ジッタを除去

---

## 注意事項

### 1. VNTrackObjectRequest のライフサイクル管理
- カメラ切替時、バックグラウンド復帰時に VNSequenceRequestHandler をリセットする必要がある
- トラッキングの confidence が低下した場合の再検出ロジックを確実に実装すること
- 複数の顔を同時にトラッキングする場合、各顔に独立した VNTrackObjectRequest が必要

### 2. 新規顔の検出ラグ
- VNTrackObjectRequest はトラッキングのみで新規顔を検出しない
- 定期的な VNDetectFaceRectanglesRequest の実行が必要（例: 0.3~0.5秒間隔）
- この間隔が長すぎると新しい人が画面に入っても一瞬ブラーなしになる

### 3. マスクテンポラルブレンドの alpha 値
- alpha が小さすぎる（0.1）: 安定するが追従が大幅に遅れ、顔の動きに対してブラーが「引きずられる」
- alpha が大きすぎる（0.8）: チラつき除去効果が薄い
- 推奨開始値: 0.3~0.4、実機テストで調整

### 4. CIContext の統合
- 現在 VideoFrameProcessor と BlurProcessingService が独立した CIContext を持っている
- WWDC20 の推奨に従い、Metal デバイスとコマンドキューを共有する1つの CIContext に統合すべき
- ProcessedPreviewUIView の MTKView と同じ Metal デバイスを使用すること

### 5. テスト戦略
- 実機テストが必須（シミュレータでは Vision の挙動が異なる）
- 「静止した顔」「ゆっくり動く顔」「素早く動く顔」「顔の出入り」の4パターンをテスト
- 録画して 1 フレームずつ確認し、ブラー境界の移動量を定量的に評価すること

### 6. FaceNet 認識との統合
- VNTrackObjectRequest の trackID と FaceNet の認識結果を紐付けるロジックが必要
- 現在の displayTracker (IoU ベース) は VNTrackObjectRequest に置き換わるため、TrackedFace のヒステリシスロジックは VNTrackObjectRequest の trackID に紐付けて保持する形に変更が必要

---

## 参考リンク一覧

- [Apple: Tracking the User's Face in Real Time](https://developer.apple.com/documentation/vision/tracking-the-user-s-face-in-real-time)
- [VNTrackObjectRequest API](https://developer.apple.com/documentation/vision/vntrackobjectrequest)
- [Apple VisionFaceTrack サンプルコード (GitHub)](https://github.com/tiagomartinho/VisionAppleSample)
- [1-Euro Filter 公式サイト](https://gery.casiez.net/1euro/)
- [1-Euro Filter 論文 (CHI 2012)](https://dl.acm.org/doi/10.1145/2207676.2208639)
- [1-Euro Filter Swift 実装](https://github.com/masterchef8/OneEuroFilter)
- [WWDC20: Optimize the Core Image pipeline for your video app](https://developer.apple.com/videos/play/wwdc2020/10008/)
- [CIMaskedVariableBlur API](https://developer.apple.com/documentation/coreimage/cimaskedvariableblur)
- [Kalman/FIR Filter による Bounding Box 安定化](https://www.researchgate.net/publication/358558079_Bounding_Box_Stabilization_for_Visual_Object_Tracking_Using_Kalman_and_FIR_Filters)
- [mrousavy/FaceBlurApp (参考実装)](https://github.com/mrousavy/FaceBlurApp)
- [Object Tracking on iOS (Vision)](https://medium.com/@rockyshikoku/object-tracking-on-ios-vision-58a6ad3ce968)
- [OneEuroFilter 解説 (FreeFaceMoCap)](https://mohamedalirashad.github.io/FreeFaceMoCap/2021-12-25-filters-for-stability/)
