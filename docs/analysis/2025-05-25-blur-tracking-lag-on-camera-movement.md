# カメラ移動時のモザイク追従遅れ 分析レポート

**日付:** 2025-05-25
**対象:** VideoFrameProcessor / BlurProcessingService / OneEuroFilter
**症状:** カメラを動かすとモザイクが顔の位置から遅れてずれ、顔が一瞬露出する
**前提:** 前回のチラつき改修（1-Euro Filter導入 + テンポラルマスクブレンド）後に発生

---

## 現状の問題

### 症状の詳細

- **静止時**: モザイクは安定しチラつきなし（前回改修は成功）
- **カメラ移動時**: モザイクが顔位置から遅延してずれる → 顔が一瞬見える
- **プライバシーアプリとして致命的**: 他人の顔が露出してはならないという要件に反する

### 直前の改修内容（原因の候補）

| 改修 | 箇所 | 目的 |
|---|---|---|
| smoothBox を 1-Euro フィルタに置換 | OneEuroFilter.swift / VideoFrameProcessor L377-384 | チラつき抑制 |
| マスクテンポラルブレンド追加 | BlurProcessingService L98-121 | マスク境界のチラつき抑制 |
| マスクパディング 15% → 35% | BlurProcessingService L188-189 | ブラー境界を顔外側に配置 |

---

## 原因分析

コードを精査した結果、追従遅れの原因は **3つの遅延要因が複合的に積み重なった結果** であると判断する。いずれも前回のチラつき対策で導入・強化されたものである。

### 原因1（主因）: 1-Euro フィルタの beta 値が極端に小さい

**OneEuroFilter.swift L17, VideoFrameProcessor.swift L379:**

```
beta: 0.007
```

1-Euro フィルタの公式チューニングガイド（gery.casiez.net/1euro/）によれば:

> "if high speed lag is a problem, **increase beta**"
> "do not hesitate to start with values like 0.001 or 0.0001"

beta は「速度に対するカットオフ周波数の感度」を制御する。現在の `beta=0.007` は、高速移動時でもカットオフ周波数がほぼ mincutoff（0.5Hz）のまま変化しない設定である。

**比較: MediaPipe の 1-Euro フィルタ設定（Google 公式ソースコード）:**

| 用途 | min_cutoff | beta | 備考 |
|---|---|---|---|
| Normalized Landmarks | 0.05 | **80.0** | 顔ランドマーク位置の安定化 |
| World Landmarks | 0.1 | **40.0** | 3D空間座標の安定化 |
| Auxiliary Landmarks | 0.01 | **10.0** | 補助ランドマーク |
| **blurCam（現在）** | **0.5** | **0.007** | **betaが4桁低い** |

beta=0.007 では、顔が正規化座標で 0.1/frame（画面幅の10%/frame）動いても、cutoff の増加分はわずか `0.007 * 0.1 = 0.0007Hz` にしかならない。つまり **フィルタは速度に応じた適応をほぼ行えておらず、常に強い平滑化（= 大きなラグ）を適用している状態** である。

同時に mincutoff=0.5 は MediaPipe の 0.05~0.1 と比較して5~10倍大きい。これは静止時のジッタ抑制が弱いことを意味するが、beta が極端に小さいことでカットオフがほぼ固定されているため、移動時のラグだけが目立つ結果になっている。

**技術的計算:**

1-Euro フィルタの alpha（追従度）を計算:
- 静止時 (speed=0): cutoff = 0.5, te = 1/30, tau = 1/(2*pi*0.5) = 0.318, **alpha = 1/(1+0.318/0.033) = 0.094** → 新しい値の9.4%しか反映しない
- 高速移動時 (speed=0.1/frame): cutoff = 0.5 + 0.007*3.0 = 0.521, alpha ≈ 0.098 → ほぼ変化なし

alpha=0.094 は、フィルタ出力が入力に追いつくのに約 10 フレーム（~330ms at 30fps）かかることを意味する。これはカメラ移動時の追従遅れとして知覚される典型的な遅延量である。

### 原因2（増幅要因）: マスクテンポラルブレンドが遅延をさらに増大

**BlurProcessingService.swift L98-121:**

1-Euro フィルタでバウンディングボックスが遅延した上に、さらにマスク画像レベルで `alpha=0.35` のテンポラルブレンドを行っている。これは:

```
stableMask = currentMask * 0.35 + previousMask * 0.65
```

つまり **前フレームのマスクが65%の重みで残留する**。カメラが動いて顔の位置が変わっても、マスクの65%は前フレームの位置に固定されたままである。

1-Euro フィルタの遅延（alpha≈0.094）と、マスクブレンドの遅延（alpha=0.35）が **直列に接続されている** ため、遅延は加算的に蓄積する。

概算の合成遅延:
- 1-Euro フィルタの実効 alpha ≈ 0.094
- マスクブレンドの alpha = 0.35
- 合成 alpha ≈ 0.094 * 0.35 ≈ 0.033 → 入力の3.3%しかフレームごとに反映されない
- 追従に約 30 フレーム（1秒）かかる計算

### 原因3（構造的問題）: 毎フレーム VNDetectFaceRectanglesRequest の処理遅延

**VideoFrameProcessor.swift L419-458:**

毎フレームで `VNDetectFaceRectanglesRequest` を同期実行している。Vision の顔検出はミリ秒単位とはいえ、フレーム処理パイプラインに直列に含まれるため、検出結果は常に「そのフレームの入力画像」に対するものであり、表示されるまでに少なくとも1フレーム分のレイテンシがある。これは 1-Euro フィルタやマスクブレンドの遅延と加算される。

### 遅延の連鎖まとめ

```
顔の実際の位置
  ↓ [+1フレーム] VNDetectFaceRectanglesRequest の検出遅延
  ↓ [+~10フレーム] 1-Euro フィルタの過度な平滑化 (beta=0.007)
  ↓ [+~3フレーム] マスクテンポラルブレンド (alpha=0.35)
  = 合計 ~14フレーム（~470ms）の遅延
```

470ms の遅延は、カメラを適度な速度で動かした場合に顔が画面幅の 5-15% ずれることに相当し、顔が完全にモザイクの外に出る距離である。

---

## 調査結果

### 1-Euro フィルタのパラメータチューニング（公式ガイド）

公式サイト（gery.casiez.net/1euro/）のチューニング手順:

1. **Step 1**: beta=0 にして、mincutoff だけで静止時のジッタを許容レベルまで下げる
2. **Step 2**: 高速に動かしながら beta を上げ、ラグが許容レベルになるまで調整
3. beta の初期値は「0.001 や 0.0001 から始めて、効果が見えるまで10倍ずつ上げる」

MediaPipe の実績値（Google公式リポジトリ mediapipe/modules/pose_landmark/pose_landmark_filtering.pbtxt）:
- 正規化座標のランドマーク: **mincutoff=0.05, beta=80.0**
- ワールド座標: **mincutoff=0.1, beta=40.0**

FreeFaceMoCap プロジェクトでの実績値:
- **mincutoff=0.00001, beta=20**

いずれも beta は現在の blurCam の値（0.007）より **3~4桁大きい**。

### VNTrackObjectRequest ハイブリッドアプローチ

前回の分析レポートで推奨した方針。stash に WIP 実装が存在することを確認した。このアプローチは:
- 毎フレームの検出を廃止し、Apple の光学フローベースのトラッキングを使用
- 検出は N フレームごとに実行（再検出）
- トラッキング結果は検出よりもバウンディングボックスの時間的連続性が高い

### マスクの方向性拡張（Motion-Aware Mask Dilation）

産業用プライバシーカメラ（AXIS Live Privacy Shield 等）で使われる手法:
- 顔の移動方向を検出し、移動方向側のマスクパディングを追加拡大
- フィルタの遅延による「追従遅れ」の方向がわかるため、その方向にマスクを事前拡張
- 遅延自体を解消するのではなく、遅延があっても顔がマスク内に留まるようにする

---

## 修正方針の選択肢

### 方針A: 1-Euro フィルタの beta パラメータ修正 + マスクブレンド条件付き無効化

**概要:**
最も工数が小さく即効性のある修正。beta を MediaPipe の実績値を参考に 3-4 桁上げ、マスクテンポラルブレンドを速度に応じて無効化（高速時はブレンドをスキップ）する。

**技術的根拠:**
- 現在の beta=0.007 は 1-Euro フィルタの速度適応機能をほぼ無効化している
- MediaPipe は正規化座標に対して beta=40~80 を使用しており、同様の座標系（Vision の正規化座標 0.0~1.0）を使う blurCam にも適用可能
- マスクテンポラルブレンドは静止時には有効だが、移動時には遅延の原因にしかならない

**実装の要点:**

1. **OneEuroFilter のパラメータ修正**:
   - `mincutoff`: 0.5 → **0.05**（静止時のジッタ抑制を強化）
   - `beta`: 0.007 → **10.0 ~ 50.0**（高速移動時の追従を大幅改善）
   - `dcutoff`: 1.0 → 1.0（変更なし）
   - チューニングは実機テストで 10.0 から開始し、ジッタとラグのバランスを確認

2. **マスクテンポラルブレンドの速度適応化**:
   - バウンディングボックスの移動速度（前フレームとの差分）を計算
   - 閾値（例: 正規化座標で 0.02/frame）を超えたらブレンドを無効化（alpha=1.0）
   - 静止時のみブレンドを有効にして残留ジッタを吸収

3. **パディングの移動方向拡張**:
   - 顔の移動方向（velocity vector）に対して、移動先方向のパディングを 1.5~2.0 倍にする
   - フィルタの残留ラグ分をカバーする安全マージンとして機能

**メリット:**
- 工数が非常に小さい（パラメータ変更 + 条件分岐追加のみ）
- 既存アーキテクチャを一切変更しない
- 1-Euro フィルタの本来の設計意図に沿った修正であり、理論的にも正しい
- 静止時のチラつき抑制効果は維持（mincutoff を下げるため、むしろ改善）

**デメリット:**
- beta の最適値は実機テストでの調整が必要
- 毎フレーム VNDetectFaceRectanglesRequest の CPU 負荷は解消しない
- 検出器ノイズ自体は残るため、beta を上げすぎるとジッタが復活する可能性
- マスクブレンドの速度閾値のチューニングが必要

**工数目安:** 小（1-2時間）

**参考リンク:**
- [1-Euro Filter 公式チューニングガイド](https://gery.casiez.net/1euro/)
- [MediaPipe Pose Landmark Filtering パラメータ](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/modules/pose_landmark/pose_landmark_filtering.pbtxt)
- [1-Euro Filter 論文 (CHI 2012)](https://dl.acm.org/doi/10.1145/2207676.2208639)

---

### 方針B: VNTrackObjectRequest ハイブリッド + 適正パラメータの 1-Euro フィルタ

**概要:**
毎フレームの VNDetectFaceRectanglesRequest を廃止し、Apple の VNTrackObjectRequest による光学フローベースのトラッキングに切り替える。さらに、適正なパラメータの 1-Euro フィルタで残留ジッタを除去する。（stash に WIP 実装が存在）

**技術的根拠:**
- VNTrackObjectRequest はフレーム間の画素レベルの対応関係を利用するため、検出器のような独立フレームごとのノイズが発生しにくい
- トラッキングはバウンディングボックスの連続性を保証するため、フィルタへの入力ノイズ自体が小さくなる → beta を上げてもジッタが増えにくい
- stash に既に VNTrackObjectRequest + 1-Euro フィルタの WIP 実装があり、この方針の基盤は存在する（ただし beta=0.007 のまま）

**実装の要点:**

1. **stash の WIP コードを復元・完成させる**:
   - `performFaceDetection()`: N フレームごとに VNDetectFaceRectanglesRequest で再検出
   - `performTracking()`: 中間フレームでは VNTrackObjectRequest で各顔をトラッキング
   - `buildFacesFromTrackers()`: トラッキング結果に 1-Euro フィルタを適用
   - `redetectionFrameInterval`: 再検出間隔（10フレーム = ~0.33秒）

2. **1-Euro フィルタのパラメータを方針Aと同様に修正**:
   - mincutoff=0.05, beta=10.0~50.0
   - VNTrackObjectRequest の出力はノイズが少ないため、方針Aより低い beta でも十分な追従が得られる可能性

3. **マスクテンポラルブレンドの alpha を上げる（0.35 → 0.5~0.7）**:
   - トラッキング + 適正 1-Euro の組み合わせで入力の安定性が高いため、ブレンドの必要性が下がる
   - alpha を上げることで追従性を改善

4. **新規顔検出のフォールバック**:
   - VNTrackObjectRequest の confidence が閾値（0.3）以下になったら即時再検出
   - 新しい顔がフレームに入った場合の検出ラグを最小化

**メリット:**
- 追従遅れの根本原因（毎フレーム検出 + 過度な平滑化）を両方解消
- CPU 負荷が大幅に減少（検出: 毎フレーム → 10フレームに1回、トラッキングは軽量）
- Apple 公式推奨のパターンに準拠
- stash に WIP があるため、ゼロからの実装ではない

**デメリット:**
- 方針Aより工数が大きい
- VNSequenceRequestHandler の状態管理が必要（カメラ切替・バックグラウンド復帰時のリセット）
- 新しい顔が画面に入ってから検出されるまで最大 0.33 秒のラグ
- WIP コードの品質検証・テストが必要

**工数目安:** 中（4-8時間）

**参考リンク:**
- [Apple: Tracking the User's Face in Real Time](https://developer.apple.com/documentation/vision/tracking-the-user-s-face-in-real-time)
- [VNTrackObjectRequest API](https://developer.apple.com/documentation/vision/vntrackobjectrequest)
- [VNDetectFaceRectanglesRequest API](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest)

---

### 方針C: マスクの動的拡張（Motion-Aware Mask Expansion）で遅延を隠蔽

**概要:**
フィルタリングやトラッキングの遅延自体は許容し、マスクの形状・サイズを動的に拡張することで、遅延があっても顔がマスク内に留まるようにする。

**技術的根拠:**
- プライバシーアプリの要件は「顔が見えないこと」であり、「マスクが正確に顔の位置にあること」ではない
- マスクを移動方向に十分大きくすれば、フィルタの遅延で位置がずれても顔はマスク内に残る
- 産業用プライバシーカメラ（AXIS, Verkada等）でも、マスクは顔より大幅に大きく設定される

**実装の要点:**

1. **顔の移動速度ベクトルの計算**:
   - 1-Euro フィルタの入力（raw検出）と出力（smoothed）の差分から速度を推定
   - または前フレームと現フレームのバウンディングボックス中心の差分

2. **速度に応じたマスク拡張**:
   - 静止時: 現在のパディング 35% をそのまま使用
   - 移動時: 移動方向のパディングを `35% + velocity * scale_factor` に拡張
   - scale_factor はフィルタの遅延フレーム数に基づいて算出（例: 10フレーム分の予測距離）

3. **全方向最小パディングの保証**:
   - 移動方向の逆側もパディングを維持（急な方向転換への対応）
   - 最小パディングは 35% を下回らない

4. **マスクテンポラルブレンドの無効化（オプション）**:
   - マスクが十分大きければ、テンポラルブレンドのメリット（エッジのチラつき抑制）より遅延のデメリットが大きい
   - 削除を検討

**メリット:**
- 根本的にアプローチが異なる（遅延を消すのではなく、遅延を許容する設計）
- フィルタのパラメータに依存せず、確実に顔を隠せる
- 実装が比較的シンプル
- 静止時のチラつき対策（1-Euro + テンポラルブレンド）を破壊しない

**デメリット:**
- マスクが顔より大幅に大きくなるため、不自然に見える可能性
- 高速移動時はマスクが非常に大きくなる（画面の1/3以上がブラーになる可能性）
- 遅延の根本原因は放置される
- パディングの計算ロジックのチューニングが必要

**工数目安:** 小~中（2-4時間）

**参考リンク:**
- [AXIS Live Privacy Shield](https://www.axis.com/products/axis-live-privacy-shield)
- [SmartBlur - Face & Body Blur Software](https://smartblur.app/)

---

## 推奨

**方針A を即座に実施し、必要に応じて方針B へ段階的に移行** することを推奨する。

### 理由

1. **方針A は即効性が高い**: beta パラメータの修正はコード1行の変更で、追従遅れの主因（alpha≈0.094 による ~330ms の遅延）を直接解消する。MediaPipe で実績のあるパラメータ値が存在し、手探りでのチューニングではない。

2. **方針A で十分な改善が得られる可能性が高い**: 現在の遅延の大部分は beta=0.007 という極端に小さいパラメータに起因している。beta を 10~50 に修正するだけで、高速移動時の alpha が 0.094 → 0.5~0.9 に跳ね上がり、追従遅延は ~330ms → ~30-60ms に短縮される。

3. **方針B は方針Aの結果を見てから判断すべき**: VNTrackObjectRequest の導入は正しい方向だが、方針Aだけで十分な品質が得られるなら不要なコスト。方針Aで不十分な場合（検出ノイズが依然として問題になる場合）にのみ方針Bに進む。

4. **方針C は最後の手段**: マスクの過度な拡大は視覚的品質を犠牲にする。方針A/Bで遅延を十分に削減した上で、安全マージンとして小規模に導入するのは有効だが、単独での採用は推奨しない。

### 具体的な実施手順

**Step 1（即時、方針A）:**
1. OneEuroFilter のパラメータを修正: `mincutoff=0.05, beta=10.0`
2. 実機テストで beta を 10 → 20 → 50 と段階的に上げ、ジッタとラグのバランスを確認
3. マスクテンポラルブレンドの alpha を 0.35 → 0.6 に上げる（または速度適応化）
4. 効果を実機で評価

**Step 2（方針Aで不十分な場合、方針B）:**
1. stash の VNTrackObjectRequest WIP コードを復元
2. 方針Aで決定したパラメータを適用
3. テスト・検証

---

## 注意事項

### 1. beta パラメータの単位依存性

1-Euro フィルタの beta は入力信号の単位に依存する。Vision の正規化座標（0.0~1.0）は MediaPipe の正規化座標と同様のスケールだが、顔検出のバウンディングボックスと細かいランドマークポイントではノイズ特性が異なる可能性がある。MediaPipe の値（40~80）をそのまま使うのではなく、10.0 から実機テストで段階的に上げることを推奨。

### 2. mincutoff と beta のバランス

mincutoff を 0.5 から 0.05 に下げると、静止時の alpha は 0.094 → 0.010 に低下する。これは静止時のジッタ抑制が大幅に強化される一方、beta が十分に高ければ移動時には即座にカットオフが上がって追従する。**mincutoff を下げ、beta を上げる** のが正しい調整方向。

### 3. マスクテンポラルブレンドの再評価

1-Euro フィルタのパラメータが適正化されれば、マスクテンポラルブレンドの必要性は低下する。ブレンドは遅延の原因であるため、まず **ブレンドを無効化** してテストし、ブレンドなしでも十分に安定していれば削除を検討すべき。

### 4. テスト項目

以下の4パターンを実機テストで評価すること:
- **静止した顔**: ジッタがないことを確認
- **ゆっくり動くカメラ**: モザイクが滑らかに追従すること
- **素早く動くカメラ**: モザイクが顔から外れないこと（最重要）
- **顔の出入り**: 新しい顔が画面に入った時に即座にモザイクがかかること

### 5. stash の WIP コード

`git stash list` に VNTrackObjectRequest の WIP 実装が存在する（stash@{0}）。方針B に進む場合はこれを基盤として使用できるが、1-Euro フィルタのパラメータ（beta=0.007）は方針A の結果に基づいて修正する必要がある。

### 6. チラつき vs 追従のトレードオフ

プライバシーアプリとして:
- **追従遅れ（顔が見える）** は致命的。プライバシー侵害に直結する
- **チラつき（モザイクが震える）** は不快だが、プライバシーは保護されている

したがって、チラつきと追従のトレードオフでは **常に追従を優先する** べき。beta を上げてジッタが多少増えても、顔が露出するよりはるかに望ましい。

---

## 参考リンク一覧

- [1-Euro Filter 公式サイト・チューニングガイド](https://gery.casiez.net/1euro/)
- [1-Euro Filter 論文 (CHI 2012)](https://dl.acm.org/doi/10.1145/2207676.2208639)
- [MediaPipe Pose Landmark Filtering（Google 公式パラメータ値）](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/modules/pose_landmark/pose_landmark_filtering.pbtxt)
- [MediaPipe One Euro Filter C++ 実装](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/util/filtering/one_euro_filter.cc)
- [FreeFaceMoCap 1-Euro Filter 解説](https://mohamedalirashad.github.io/FreeFaceMoCap/2021-12-25-filters-for-stability/)
- [Noise Filtering Using 1-Euro Filter（パラメータ解説）](https://jaantollander.com/post/noise-filtering-using-one-euro-filter/)
- [Apple: VNTrackObjectRequest API](https://developer.apple.com/documentation/vision/vntrackobjectrequest)
- [Apple: VNDetectFaceRectanglesRequest API](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest)
- [Apple: Tracking the User's Face in Real Time](https://developer.apple.com/documentation/vision/tracking-the-user-s-face-in-real-time)
- [VNCoreMLRequest output jitter（Apple Developer Forums）](https://developer.apple.com/forums/thread/104685)
- [AXIS Live Privacy Shield](https://www.axis.com/products/axis-live-privacy-shield)
- [Kalman Filter Multi-Face Tracker](https://github.com/zlingkang/multi_face_tracker)
- [mrousavy/FaceBlurApp（参考実装）](https://github.com/mrousavy/FaceBlurApp)
