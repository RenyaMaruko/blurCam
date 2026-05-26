# FaceNet から ArcFace への顔認識モデル移行 分析レポート

**日付**: 2025-05-26
**対象**: blurCam - 顔認識モデル移行の技術分析

---

## 現状の問題

### 現在のモデル: FaceNet (ONNX → CoreML 変換)

| 項目 | 値 |
|------|-----|
| モデルサイズ | 43.7MB (weight.bin) |
| 入力 | 160x160x3 NHWC, [-1, 1] 正規化 |
| 出力 | 128次元 embedding (`var_1980`) |
| 入力名 | `face_image` |
| 比較方法 | L2正規化後のコサイン類似度（ドット積） |
| 変換ツール | coremltools (torch → ONNX → CoreML) |
| 変換日 | 2026-05-22 |

### Similarity の分布問題

- **未登録者**: similarity 0.30 ~ 0.65（散らばりが大きい）
- **登録者**: similarity 0.47 ~ 0.81（ピークが低い）
- **重なりゾーン**: 0.30 ~ 0.65 の広範囲で重複
- 閾値をどこに設定しても、偽陽性（false positive）か偽陰性（false negative）が発生する

### 現在のヒステリシス設定

```swift
// TrackedFace のデフォルト値
enter: 0.55  // 登録者と判定する閾値
exit: 0.25   // 登録解除する閾値
window: 15   // 平滑化ウィンドウ
initialBlurFrames: 10  // 初期ブラー期間
```

ヒステリシスで多少の安定化はできているが、モデル自体の分離性能が低すぎるため根本解決にはなっていない。

---

## 原因分析

### 1. モデルアーキテクチャの限界

FaceNet (2015年, Google) は Triplet Loss で学習されたモデルで、以下の構造的弱点がある:

- **128次元 embedding**: 表現力が限定的。ArcFace の 512次元と比較して情報量が 1/4
- **Triplet Loss の収束困難**: 学習時にハードネガティブマイニングが必要で、損失関数の安定性が低い
- **入力サイズ 160x160**: ArcFace の 112x112 より大きいが、モデル設計が古いため精度向上に直結していない

### 2. ONNX → CoreML 変換の劣化リスク

MEMORYに「ONNX→CoreML変換時に重みが一部不一致だった可能性」と記録されている。
MobileFaceNet.mlpackage が存在するが「weights didn't load correctly - unused」とあり、変換プロセスの信頼性に疑問がある。

### 3. 学習データの世代差

FaceNet の公開モデルは MS-Celeb-1M や VGGFace2 等の比較的古いデータセットで学習されている。
一方、InsightFace の w600k モデルは WebFace600K (60万ID, 1,000万枚超) で学習されており、データ量・多様性で圧倒的な差がある。

---

## 調査結果

### ArcFace / InsightFace のベストプラクティス

#### 推奨モデル（モバイル向け）

| モデル | バックボーン | 学習データ | ONNXサイズ | Embedding | LFW | CFP-FP | AgeDB-30 | IJB-C(E4) |
|--------|-------------|-----------|----------|-----------|-----|--------|----------|-----------|
| **w600k_mbf** | MobileFaceNet | WebFace600K | ~13MB | 512次元 | 99.70% | 98.00% | 96.58% | 95.02% |
| w600k_r50 | ResNet50 | WebFace600K | ~166MB | 512次元 | 99.80% | 99.20% | 98.10% | 97.12% |
| glint360k_r100 | ResNet100 | Glint360K | ~249MB | 512次元 | 99.82% | 99.14% | 98.45% | 97.13% |

**w600k_mbf（MobileFaceNet + ArcFace Loss + WebFace600K）が最適解。**

理由:
- ONNX ファイルサイズ 13MB（現在の FaceNet 43.7MB の約 1/3）
- 512次元 embedding で高い弁別性能
- 450M FLOPs でモバイル端末向けに設計
- MobileFaceNet のモバイル推論速度: ~18ms（原著論文）

#### 入力/出力仕様の違い

| 項目 | 現在 (FaceNet) | 移行先 (ArcFace w600k_mbf) |
|------|---------------|--------------------------|
| 入力サイズ | 160x160 | **112x112** |
| 入力フォーマット | NHWC (1, 160, 160, 3) | **NCHW (1, 3, 112, 112)** |
| 正規化 | (pixel / 127.5) - 1.0 → [-1, 1] | **(pixel - 127.5) / 127.5** → [-1, 1] (実質同一) |
| 色空間 | RGB | **RGB** |
| 出力次元 | 128次元 | **512次元** |
| 出力名 | `var_1980` | 変換時に指定（例: `embedding`） |
| 出力正規化 | モデル外で L2 正規化 | **モデル内で BatchNorm1d** (追加の L2 正規化推奨) |
| 比較方法 | コサイン類似度 | **コサイン類似度**（同一） |

#### 閾値の目安

InsightFace 公式ガイドの推奨:
- **典型的な 1:1 閾値**: コサイン類似度 **0.30 ~ 0.45** (FMR = 1e-4 ~ 1e-5)
- **同一人物のスコア**: 一般的に 0.5 ~ 0.9+ に集中
- **異なる人物のスコア**: 一般的に -0.1 ~ 0.3 に集中
- **分離マージン**: FaceNet と比較して大幅に改善される見込み

重要: 閾値はデータセット固有であり、実データでの calibration が必須。

#### CoreML 変換の手順

**推奨パス: PyTorch → CoreML（直接変換）**

coremltools の ONNX コンバーターは **Opset 10 以下のみサポート**で、開発が停止している。
InsightFace の ONNX エクスポートは Opset 11 を使用するため、ONNX 経由の変換は非推奨。

```python
# 推奨: PyTorch から直接変換
import torch
import coremltools as ct
from insightface.recognition.arcface_torch.backbones import get_model

# 1. モデルロード
model = get_model("mbf", fp16=False)  # MobileFaceNet
model.load_state_dict(torch.load("w600k_mbf.pt"))
model.eval()

# 2. トレース
dummy = torch.randn(1, 3, 112, 112)
traced = torch.jit.trace(model, dummy)

# 3. CoreML 変換
mlmodel = ct.convert(
    traced,
    convert_to="mlprogram",
    inputs=[ct.TensorType(name="face_image", shape=(1, 3, 112, 112))],
    minimum_deployment_target=ct.target.iOS15,
    compute_units=ct.ComputeUnit.ALL,  # CPU + GPU + Neural Engine
)
mlmodel.save("ArcFace.mlpackage")
```

**代替パス: ONNX → CoreML（onnx-coreml 経由）**

もし PyTorch 直接変換で問題が出た場合:
```python
# ONNX 経由（非推奨だが実績あり）
import onnx
from onnx_coreml import convert as onnx_to_coreml

onnx_model = onnx.load("w600k_mbf.onnx")
coreml_model = onnx_to_coreml(onnx_model)
coreml_model.save("ArcFace.mlmodel")
```

---

## 修正方針の選択肢

### 方針A: InsightFace w600k_mbf (MobileFaceNet + ArcFace) への全面移行

- **概要**: 現在の FaceNet を InsightFace の w600k_mbf モデルに完全に置き換える。入力パイプライン（前処理、アライメント、推論、後処理）を 112x112 / NCHW / 512次元に合わせて全面改修する。

- **技術的根拠**:
  - ArcFace Loss は Angular Margin を直接最適化するため、embedding 空間での同一人物/別人の分離性能が Triplet Loss より構造的に優れている
  - 512次元 embedding は 128次元に対して約 4 倍の表現容量を持ち、微細な顔の差異を捉えられる
  - WebFace600K は 60 万 ID/1,000 万枚超のデータで学習されており、データ多様性が高い
  - MobileFaceNet バックボーンは 450M FLOPs で iPhone の Neural Engine に最適化されやすい

- **メリット**:
  - モデルサイズが 43.7MB → ~13MB に削減（アプリサイズ改善）
  - LFW 99.70%、CFP-FP 98.00% の高い公称精度
  - 分離マージンの大幅改善が期待できる（学術ベンチマークで検証済み）
  - InsightFace コミュニティが活発で、モデルの信頼性が高い

- **デメリット**:
  - 入力仕様の変更（160x160→112x112, NHWC→NCHW）により `FaceRecognitionService` の前処理を全面改修
  - CoreML 変換の成功が保証されない（変換後の精度検証が必須）
  - 閾値の再調整が必要（ヒステリシスの enter/exit 値の見直し）
  - アライメント処理の変更（5点アライメントが推奨だが、現在は2点（目）ベース）

- **工数目安**: 中（3-5日）
  - モデル変換・検証: 1-2日
  - FaceRecognitionService 改修: 1日
  - 閾値チューニング・テスト: 1-2日

- **影響範囲**:
  - `blurCam/Services/FaceRecognitionService.swift`: 全面改修
    - `loadModel()`: モデル名・設定変更
    - `computeAlignedEmbedding()`: 入力サイズ(160→112)、MLMultiArray形状(NHWC→NCHW)
    - `pixelBufferToMultiArray()`: BGRA→RGB変換 + NCHW レイアウトに変更
    - `alignFace()`: 出力サイズ 160→112、アイポイント位置の再調整
    - `simpleCrop()`: 出力サイズ変更
    - MLDictionaryFeatureProvider の入力名・出力名変更
  - `blurCam/Services/FaceRecognitionService.swift` の `TrackedFace`: 閾値 enter/exit の再調整
  - `blurCam/Resources/`: FaceNet.mlpackage を ArcFace.mlpackage に置換
  - テストコード: `TrackedFaceTests.swift` の閾値関連テスト更新

- **参考リンク**:
  - [InsightFace Model Zoo](https://github.com/deepinsight/insightface/blob/master/model_zoo/README.md)
  - [ArcFace PyTorch Implementation](https://github.com/deepinsight/insightface/blob/master/recognition/arcface_torch/README.md)
  - [MobileFaceNet Architecture](https://github.com/deepinsight/insightface/blob/master/recognition/arcface_torch/backbones/mobilefacenet.py)
  - [InsightFace Model Selection Guide](https://www.insightface.ai/guides/choose-face-recognition-model-and-evaluate)

---

### 方針B: InsightFace w600k_r50 (ResNet50 + ArcFace) への移行

- **概要**: より高精度な ResNet50 バックボーンの w600k_r50 モデルを使用する。精度を最優先し、モデルサイズとレイテンシはトレードオフとして受け入れる。

- **技術的根拠**:
  - ResNet50 は MobileFaceNet より表現力が高く、IJB-C(E4) で 97.12% vs 95.02% と約 2% の精度差がある
  - 特に難しい条件（横顔、照明変動、低解像度）での性能差が顕著
  - 512次元 embedding + ArcFace Loss の恩恵は方針 A と同等

- **メリット**:
  - 最高クラスの精度（LFW 99.80%、CFP-FP 99.20%）
  - 閾値設定のマージンがさらに広く、誤判定のリスクが最小

- **デメリット**:
  - ONNX ファイルサイズ ~166MB（現在の 43.7MB の約 4 倍）
  - アプリサイズが大幅に増加
  - 推論レイテンシが MobileFaceNet の数倍に増加する可能性
  - iPhone のリアルタイム処理（10fps 認識）に支障をきたす可能性
  - Neural Engine での推論効率が MobileFaceNet より劣る可能性

- **工数目安**: 中（3-5日）　※方針 A とほぼ同等

- **参考リンク**:
  - [InsightFace Model Zoo](https://github.com/deepinsight/insightface/blob/master/model_zoo/README.md)

---

### 方針C: ハイブリッド方式（ArcFace + 既存アライメント最適化）

- **概要**: w600k_mbf モデルに移行しつつ、InsightFace 推奨の 5点アライメント（両目、鼻、口の左右端）を実装し、前処理パイプラインも最適化する。最も根本的な改善を目指す。

- **技術的根拠**:
  - InsightFace の公式前処理は「RetinaFace/SCRFD 検出 → 5点アライメント → 112x112 RGB crop」
  - 現在の 2点（目）アライメントは鼻や口の位置を考慮しないため、顔の上下位置のずれに弱い
  - 5点アライメントにより、学習時と推論時の顔の正規化が一致し、embedding の品質が向上
  - ただし、Vision Framework の `VNDetectFaceLandmarksRequest` は 76点ランドマークを返すため、InsightFace の 5点に対応するポイントの選定が必要

- **メリット**:
  - モデル変換 + 前処理最適化で、期待できる精度改善が最大
  - InsightFace の公式パイプラインに最も近い実装になるため、公称精度に近づける
  - 将来のモデルアップデートにも対応しやすい

- **デメリット**:
  - 実装工数が最も大きい（5点アライメントの新規実装が必要）
  - Vision Framework のランドマークから InsightFace の 5点への変換マッピングの検証が必要
  - アライメント精度がランドマーク検出の精度に依存する

- **工数目安**: 大（5-8日）
  - モデル変換・検証: 1-2日
  - 5点アライメント実装: 2-3日
  - FaceRecognitionService 改修: 1日
  - 閾値チューニング・テスト: 1-2日

- **参考リンク**:
  - [InsightFace Mobile Deployment Best Practices](https://www.insightface.ai/guides/choose-face-recognition-model-and-evaluate)
  - [ArcFace for Face Recognition (LearnOpenCV)](https://learnopencv.com/face-recognition-with-arcface/)
  - [CoreML Tools PyTorch Conversion](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch.html)

---

## 推奨

### 第一推奨: 方針A（w600k_mbf への全面移行）

理由:

1. **コストパフォーマンスが最も高い**: 中程度の工数で、モデル性能の大幅改善が見込める
2. **モバイル最適化**: 13MB のモデルサイズは 43.7MB から大幅削減。MobileFaceNet は iPhone の Neural Engine に最適化されやすく、リアルタイム性を維持できる
3. **リスクが管理可能**: 入力サイズとレイアウトの変更は mechanical な作業であり、既存のアーキテクチャ（Protocol、Tracker、Hysteresis）はそのまま再利用可能
4. **段階的に方針 C へ拡張可能**: まず方針 A でモデル移行を完了し、精度が不十分であれば 5 点アライメントを追加実装する

方針 B（ResNet50）は精度は最高だが、166MB のモデルサイズと推論レイテンシがリアルタイムカメラアプリには不適切。方針 C は理想的だが、まずモデル移行だけで十分な改善が得られる可能性が高い。

### 段階的移行ロードマップ

```
Step 1: モデル変換 (Python環境)
  - w600k_mbf の PyTorch weights 取得
  - torch.jit.trace → ct.convert → .mlpackage 生成
  - 変換後モデルの embedding 精度検証（Python上で既知の顔ペアで検証）

Step 2: FaceRecognitionService 改修 (Swift)
  - 入力パイプライン: 112x112, NCHW, [-1,1] 正規化
  - 出力パイプライン: 512次元 embedding, L2正規化
  - MLDictionaryFeatureProvider の入出力名更新

Step 3: 閾値チューニング
  - 実機で similarity 分布を計測
  - TrackedFace の enter/exit 閾値を再調整
  - ヒステリシスの window サイズを必要に応じて調整

Step 4: (オプション) 5点アライメント追加
  - 方針 C のアライメント改善を追加実装
  - Step 3 の結果が不十分な場合のみ実施
```

---

## 注意事項

### CoreML 変換時のリスク

1. **ONNX 経由は避ける**: coremltools の ONNX コンバーターは Opset 10 以下のみサポート。InsightFace は Opset 11 でエクスポートするため、PyTorch からの直接変換を推奨。ただし、前回の FaceNet 変換で「ONNX → CoreML 変換時に重みが一部不一致」の問題が発生しているため、変換後の精度検証は必須。

2. **PyTorch 直接変換の注意点**:
   - `model.eval()` を忘れると BatchNorm が学習モードで動作し、推論結果が不安定になる
   - `torch.jit.trace` は動的な制御フロー（if 文等）を正しくキャプチャしない。MobileFaceNet のアーキテクチャは基本的に静的だが、fp16 関連の条件分岐に注意

3. **変換後の精度検証方法**:
   - Python 上で同一の入力画像に対し、PyTorch 推論と CoreML 推論の embedding を比較
   - L2 距離が 1e-4 以下であることを確認
   - 最低 10 ペアの同一人物/別人テストを実施

### 入力フォーマットの変更

現在の `pixelBufferToMultiArray` は NHWC (1, 160, 160, 3) で書かれている。ArcFace は NCHW (1, 3, 112, 112) を要求するため、ピクセルのメモリレイアウトを変更する必要がある:

```
現在: multiArray[y * width * 3 + x * 3 + c]  (NHWC)
変更: multiArray[c * height * width + y * width + x]  (NCHW)
```

ただし、CoreML の Unified Converter は `ct.ImageType` で入力を指定すると自動的にチャネル変換を行うオプションがある。変換時に ImageType を使えば、Swift 側の前処理を簡素化できる可能性がある。

### 正規化の互換性

- 現在の FaceNet: `pixel / 127.5 - 1.0` → [-1, 1]
- ArcFace: `(pixel - 127.5) / 127.5` → [-1, 1]

数学的に同一であるため、正規化ロジック自体は変更不要。ただし、ArcFace の一部モデルでは `(pixel - 127.5) / 128.0` を使用する場合もあるため、使用するモデルの公式前処理に厳密に従うこと。

### アライメントの互換性

現在の実装は 2点（左目・右目の中心）ベースのアフィン変換を使用している。InsightFace の公式パイプラインは 5点（両目、鼻、口左、口右）ベースの similarity transform を推奨している。

2点アライメントでも動作はするが、公称精度から若干の劣化が予想される。方針 A でまず移行し、精度が不十分であれば 5点アライメント（方針 C）を追加する段階的アプローチを推奨。

### 既存テストへの影響

- `TrackedFaceTests.swift`: ヒステリシスのロジックテストは閾値のデフォルト値変更の影響を受ける。新しい閾値に合わせてテストケースを更新する必要がある
- `MockFaceRecognitionService.swift`: Protocol は変更不要のため、モックも影響なし
- `VideoFrameProcessorTests.swift`: FaceRecognitionService はモック経由のため影響なし

### パフォーマンスの期待値

| 指標 | FaceNet (現在) | ArcFace w600k_mbf (予想) |
|------|---------------|--------------------------|
| モデルサイズ | 43.7MB | ~13MB |
| Embedding 次元 | 128 | 512 |
| 入力サイズ | 160x160 | 112x112 (ピクセル数 51% 削減) |
| 推論速度 | 不明 | ~18ms (原著論文, モバイル) |
| FLOPs | 不明 | 450M |
| 期待される分離マージン | ~0.15 (overlap zone) | ~0.30+ (大幅改善見込み) |

---

## 参考文献・リンク

- [InsightFace Model Zoo](https://github.com/deepinsight/insightface/blob/master/model_zoo/README.md)
- [ArcFace PyTorch (arcface_torch)](https://github.com/deepinsight/insightface/blob/master/recognition/arcface_torch/README.md)
- [MobileFaceNet Backbone](https://github.com/deepinsight/insightface/blob/master/recognition/arcface_torch/backbones/mobilefacenet.py)
- [ArcFace ONNX Inference](https://github.com/deepinsight/insightface/blob/master/python-package/insightface/model_zoo/arcface_onnx.py)
- [torch2onnx.py Export Script](https://github.com/deepinsight/insightface/blob/master/recognition/arcface_torch/torch2onnx.py)
- [InsightFace Model Selection Guide](https://www.insightface.ai/guides/choose-face-recognition-model-and-evaluate)
- [ArcFace Paper (arXiv:1801.07698)](https://arxiv.org/pdf/1801.07698)
- [MobileFaceNet Paper (arXiv:1804.07573)](https://arxiv.org/pdf/1804.07573)
- [Face Recognition with ArcFace (LearnOpenCV)](https://learnopencv.com/face-recognition-with-arcface/)
- [ArcFace vs CosFace Deep Dive (didit.me)](https://didit.me/blog/arcface-vs-cosface-deep-dive-into-face-matching-algorithms/)
- [CoreML Tools PyTorch Conversion](https://apple.github.io/coremltools/docs-guides/source/convert-pytorch.html)
- [CoreML Tools New Features](https://apple.github.io/coremltools/docs-guides/source/new-features.html)
- [CoreML Tools Unified Converter API](https://apple.github.io/coremltools/source/coremltools.converters.convert.html)
- [ONNX to CoreML (legacy)](https://pypi.org/project/onnx-coreml/)
- [buffalo_sc on HuggingFace](https://huggingface.co/WePrompt/buffalo_sc/blob/229b65be0dc7f8f33b55478772e8d3289580c356/w600k_mbf.onnx)
- [InsightFace CoreML Issue #2238](https://github.com/deepinsight/insightface/issues/2238)
- [MobileFaceNet Tutorial (PyTorch)](https://github.com/xuexingyu24/MobileFaceNet_Tutorial_Pytorch)
- [FaceNet vs ArcFace Comparison Study](https://www.researchgate.net/publication/370987773_Comparison_of_Face_Recognition_Accuracy_of_ArcFace_Facenet_and_Facenet512_Models_on_Deepface_Framework)
