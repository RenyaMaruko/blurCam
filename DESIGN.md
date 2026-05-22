# Design Rules

UI/デザインに関わるコード変更時は、必ず `/docs/design-tokens.md` を参照すること。

## 必須ルール

- カラー、フォント、スペーシング、角丸、シャドウ、ブラーの値は `/docs/design-tokens.md` で定義されたトークンを使う。ハードコードしない
- ダークUI（#000000ベース）を基本とし、Apple Human Interface Guidelines に準拠する
- カメラ映像が主役。UIを重ねすぎない
- AI処理を感じさせない自然なUX
- アニメーションはiOSらしく滑らかに。過剰な演出禁止

## デザイントークン参照先

全てのビジュアル値は以下に定義:

| カテゴリ | 参照セクション |
|---|---|
| カラー（背景・テキスト・アクセント・ボーダー） | Color System |
| フォント（ファミリー・サイズ・ウェイト） | Typography |
| 余白 | Spacing System |
| 角丸 | Radius System |
| 影 | Shadow System |
| ぼかし | Blur System |
| アニメーション | Motion Design |

## やってはいけないこと

- デザイントークンに定義されていない色・サイズを勝手に使う
- 機能追加・ロジック変更をデザイン修正に混ぜる
- SNS機能、複雑な編集、大量のフィルター追加
