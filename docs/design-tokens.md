# Privacy Camera App Design System

## Overview

iPhone標準カメラのような自然な体験をベースにした、
「リアルタイム顔保護カメラアプリ」のデザインシステム。

このアプリは、

- 登録した人物のみ自然表示
- その他人物は自動モザイク
- AI感を出しすぎない
- 誰でも直感的に使える

ことを目的とする。

---

# Design Philosophy

## Core Concept

> "Apple Camera × Privacy AI"

AIツール感ではなく、
「最初からiPhoneに入っていそうな自然さ」を目指す。

---

## UX Principles

### 1. Camera First

UIよりカメラ映像を主役にする。

- 余計なメニューを置かない
- 設定画面を極力減らす
- 撮影まで最短1タップ

---

### 2. Invisible AI

AIを見せない。

ユーザーに感じさせるのは、

- 安心感
- 自然さ
- シンプルさ

であり、
「AI処理しています感」は出さない。

---

### 3. Privacy by Default

最初から全員保護。

- 登録した人物のみ表示
- その他は自動モザイク
- 設定不要
- 誤操作による事故を防ぐ

---

### 4. Native iPhone Feeling

iOS標準アプリのような操作感。

- SF Proベース
- Apple Human Interface Guidelines準拠
- 滑らかなアニメーション
- 黒ベースの没入型UI

---

# Design Keywords

- minimal
- cinematic
- privacy-first
- immersive
- camera-native
- dark-ui
- smooth-motion
- focus-on-subject
- subtle-glassmorphism
- apple-like

---

# Color System

## Primary Colors

| Token | Value | Usage |
|---|---|---|
| Primary | #000000 | メイン背景 |
| Primary Hover | #1A1A1A | ボタン押下 |
| Background Secondary | #111111 | サブ背景 |
| Surface | rgba(255,255,255,0.06) | 半透明UI |

---

## Text Colors

| Token | Value | Usage |
|---|---|---|
| Text Primary | #FFFFFF | メイン文字 |
| Text Secondary | rgba(255,255,255,0.72) | 補足 |
| Text Tertiary | rgba(255,255,255,0.45) | 非アクティブ |

---

## Accent Colors

| Token | Value | Usage |
|---|---|---|
| Accent | #0A84FF | CTA |
| Accent Hover | #409CFF | Hover |
| Success | #30D158 | 成功 |
| Error | #FF453A | エラー |
| Warning | #FFD60A | 注意 |

---

## Border Colors

| Token | Value |
|---|---|
| Border | rgba(255,255,255,0.08) |
| Border Strong | rgba(255,255,255,0.16) |

---

# Typography

## Font Family

### Primary

- SF Pro Display
- SF Pro Text
- -apple-system

### Monospace

- SF Mono
- JetBrains Mono

---

## Font Sizes

| Token | Size |
|---|---|
| XS | 11px |
| SM | 13px |
| Base | 16px |
| LG | 18px |
| XL | 22px |
| 2XL | 28px |
| 3XL | 34px |
| 4XL | 42px |

---

## Font Weight

| Token | Weight |
|---|---|
| Normal | 400 |
| Medium | 500 |
| Semibold | 600 |
| Bold | 700 |

---

# Spacing System

| Token | Size |
|---|---|
| Space 1 | 4px |
| Space 2 | 8px |
| Space 3 | 12px |
| Space 4 | 16px |
| Space 5 | 20px |
| Space 6 | 24px |
| Space 8 | 32px |
| Space 10 | 40px |
| Space 12 | 48px |
| Space 16 | 64px |

---

# Radius System

| Token | Value |
|---|---|
| Small | 8px |
| Medium | 14px |
| Large | 20px |
| XL | 28px |
| Full | 9999px |

---

# Shadow System

## Small

軽い浮き上がり。

主にカードUI。

---

## Medium

モーダル・ボタン。

---

## Large

重要なフォーカスUI。

---

## Glow

アクセント色にのみ使用。

使いすぎ禁止。

---

# Blur System

| Token | Usage |
|---|---|
| Light Blur | 軽い背景UI |
| Medium Blur | モーダル |
| Heavy Blur | フルスクリーン |

---

# Motion Design

## Principles

- iOSらしい滑らかさ
- 強すぎる演出禁止
- バウンス弱め
- AI処理を感じさせない

---

## Timing

| Type | Duration |
|---|---|
| Fast | 120ms |
| Normal | 220ms |
| Slow | 420ms |

---

# Camera UI Rules

## Layout

### Top Area

最小限のみ表示。

- Flash
- Settings
- Status

のみ。

---

### Center Area

カメラ映像を最優先。

UIを重ねすぎない。

---

### Bottom Area

iPhoneカメラ風。

- 大型シャッターボタン
- モード切替
- ギャラリー

のみ。

---

# Face Recognition UI

## Registered Face

- 自然表示
- 軽い白枠
- 過剰演出禁止

---

## Unregistered Face

- ソフトモザイク
- またはGaussian Blur
- 「怖さ」より「自然さ」

---

# Onboarding Rules

## Principles

- 1画面1目的
- 長文禁止
- ワンタップ中心
- 安心感を与える

---

## Initial Flow

### 1. Welcome

「あなたの顔を登録します」

---

### 2. Face Capture

正面撮影。

---

### 3. Complete

「これ以降、あなた以外は自動保護されます」

---

# Privacy Rules

## Important Philosophy

顔データは端末内処理。

- クラウド送信なし
- サーバー保存なし
- ローカルAI処理

を明確に伝える。

---

# Recommended Features

## MVP

- 顔登録
- リアルタイムモザイク
- 写真撮影
- 動画撮影

のみ。

---

## Avoid

- SNS機能
- 複雑な編集
- フィルター大量追加
- 不要なAI機能

---

# Suggested Naming Direction

## Naming Tone

- 静か
- シンプル
- 無機質
- Appleっぽい

---

## Example Names

- OnlyMe
- BlurCam
- Silent
- Persona
- MonoCam
- GhostLens
- PrivateShot
- Focus
- Cloak

---

# Final Experience Goal

ユーザーに感じさせるべきなのは、

「AIを使っている」

ではなく、

> "普通に撮っただけなのに、
> 周囲が自然に保護されている"

という体験。