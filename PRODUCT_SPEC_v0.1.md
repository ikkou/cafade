# Cafade product spec v0.4

この文書は、カフェイン残量アプリの初回実装に使う基準文書です。

正式名称は **Cafade** とします。

`caffeine` と `fade` を組み合わせた造語で、飲料の種類をコーヒーに限定せず、時間とともにカフェインが減るアプリの役割を表します。

以前の作業名 `Linger` は、米国App Storeに同名の音楽アプリがあり、アプリ内課金も提供されているため候補から外しました。

参照：<https://apps.apple.com/us/app/linger-music-discovery/id6748237784>

アプリのbundle identifier、GitHubリポジトリ名、サイトのサブドメインは `cafade` に揃えます。

| 項目 | 決定 |
|---|---|
| 初回市場 | United States |
| 初回言語 | English |
| 対応端末 | iPhone |
| 対応OS | iOS 26以降 |
| 画面方向 | 縦向きのみ |
| データ保存 | ローカル優先 |
| HealthKit | 任意 |
| 課金 | 7日間の無料トライアル付き Pro サブスクリプション |
| 価格目標 | 月額300円、年額3,000円 |
| カフェイン値 | 推定値または公式値 |
| ソースコード | `github.com/ikkou/cafade` |
| 公式サイト | `https://cafade.oneshotstar.com` |
| 公開方法 | GitHubのproduction branchからCloudflare Pagesへ自動デプロイ |

## 製品の約束

```text
Know what you drank. See what remains.
```

飲んだものを数秒で記録し、現在のカフェイン残量を時間軸で確認できるようにします。

アプリは医療上の安全基準を提示しません。

画面では `Estimated caffeine` や `Approximate value` を使い、測定値のように見せないことを固定します。

## アプリ名称

正式名称は **Cafade** です。

`caffeine` と `fade` を短く組み合わせた名前で、カフェインが時間とともに減るアプリの役割を説明しやすく、飲料の種類をコーヒーだけに限定しません。

候補の比較は次のとおりです。

| 候補 | 印象 | 良い点 | 注意点 |
|---|---|---|---|
| **Cafade** | 静か、直接的 | カフェインと減衰が伝わる | 造語なので初見の説明が必要 |
| **Cafternoon** | 軽い、親しみやすい | 午後のカフェインという利用場面が浮かぶ | 朝や夜の記録まで名前が広がりにくい |
| **Fadeline** | 端正、抽象的 | グラフの線と減衰を表現できる | カフェインのアプリだと名前だけでは分からない |

App Store、ドメイン、商標の確認は初回リリース前にも継続します。

GitHubリポジトリは `github.com/ikkou/cafade`、公式サイトは `https://cafade.oneshotstar.com` とします。

## ナビゲーション

タブは `Today`、`History`、`Settings` の3つにします。

`Log caffeine` はタブではなく、`Today` の主要アクションです。

AppleのHIGに合わせ、タブバーは画面間の移動に使い、記録の追加はシートで処理します。

参照：<https://developer.apple.com/design/human-interface-guidelines/tab-bars>

| 画面 | 役割 | 初回リリースの範囲 |
|---|---|---|
| Today | 現在の推定値と直近の記録 | 無料 |
| Log caffeine | 飲料を検索して記録 | 無料 |
| Drink detail | サイズとカフェイン値を確認 | 無料 |
| History | 過去の記録を確認 | 7日間は無料、30日間以上はPro |
| Settings | モデル、HealthKit、購入を管理 | 無料 |
| How the estimate works | 半減期モデルを説明 | 無料 |
| Sleep comparison | 就寝時の残量を比較 | Pro |
| Insights | 週次の傾向を表示 | Pro |

## リポジトリと公式サイト

正式名称のslugを使い、アプリ本体と公式サイトを一つのGitHubリポジトリで管理します。

```text
github.com/ikkou/cafade

/app
/site
```

`site`にはトップページ、サポートページ、プライバシーポリシーを置きます。

```text
https://cafade.oneshotstar.com/
https://cafade.oneshotstar.com/support/
https://cafade.oneshotstar.com/privacy/
https://cafade.oneshotstar.com/terms/
```

### Support page

サポートページには、記録の追加と編集、カタログ値、半減期モデル、HealthKit、購読とRestore、データ削除の説明を置きます。

問い合わせ先は `i@oneshotstar.com` とします。

### Privacy page

プライバシーポリシーには、アカウントを作らないこと、記録を端末内に保存すること、HealthKitへ書き込むデータ、購読処理をAppleが扱うこと、第三者への販売や広告目的の利用をしないことを、実際の実装に合わせて記載します。

HealthKitを使うアプリには、App Store上から確認できるWebベースのプライバシーポリシーが必要です。

参照：<https://developer.apple.com/design/human-interface-guidelines/healthkit>

Termsリンクは、初回リリースではAppleの標準利用規約を使います。

<https://www.apple.com/legal/internet-services/itunes/dev/stdeula/>

Cloudflare PagesはGitHubリポジトリのproduction branchに接続し、pushのたびにサイトをデプロイします。

Cloudflare PagesではGitHub連携による自動デプロイとpreview deploymentを設定できます。

参照：<https://developers.cloudflare.com/pages/configuration/git-integration/github-integration/>

サブドメインはCloudflare PagesのCustom domainsで登録します。

参照：<https://developers.cloudflare.com/pages/configuration/custom-domains/>

一度だけ必要になる作業は、Cloudflare Pagesプロジェクトの作成、GitHub連携、production branchの指定、`cafade.oneshotstar.com`のサブドメイン設定です。

正式名称が確定したため、この外部設定を作成します。

## Today画面

### 画面要素

| 要素 | 仕様 | 英語UI |
|---|---|---|
| ナビゲーションタイトル | 現在の日付を表示し、長い説明は置かない | `Today` |
| 主表示 | 現在時刻の推定残量をmgで表示 | `Estimated caffeine remaining` |
| 補足 | 記録から算出した推定値であることを示す | `Based on your logged drinks` |
| グラフ | 直近24時間の減衰曲線を表示 | `Today` |
| 目安 | ユーザーが目標を設定した場合だけ表示 | `Below your personal target by 8:40 PM` |
| 主要ボタン | Logシートを開く | `Log caffeine` |
| 直近記録 | 商品名、時刻、mg、Repeatを表示 | `Recent`, `Repeat` |

### 状態

| 状態 | 主表示 | 補助文言 |
|---|---|---|
| 記録なし | 空の曲線 | `Log a drink to see your estimate.` |
| 通常 | 現在の残量と曲線 | `Based on your logged drinks` |
| 目標未設定 | 曲線だけ | 目標に関する文言を表示しない |
| HealthKit未接続 | アプリ内記録だけで表示 | HealthKitの警告を出さない |
| 今日の残量がほぼゼロ | `0 mg` に近い表示 | `No caffeine is estimated right now.` |

`Today` はHealthKitを許可しなくても成立させます。

記録を追加した直後だけ曲線を短くアニメーションさせ、Reduce Motionが有効な場合は静的に更新します。

## Log caffeineシート

### 操作順

```text
Today
  ↓
Log caffeine sheet
  ↓
Search or Recent item
  ↓
Drink detail
  ↓
Log now
  ↓
Today
```

検索を目的とするシートでは、表示時に検索欄へフォーカスします。

参照：<https://developer.apple.com/design/human-interface-guidelines/search-fields>

| 要素 | 仕様 | 英語UI |
|---|---|---|
| 検索欄 | ブランド名、商品名、一般名を検索 | `Search drinks` |
| 検索例 | プレースホルダーに例を置く | `Starbucks, Red Bull, coffee...` |
| 候補 | よく使う一般名と商品を表示 | `Suggested` |
| 最近の記録 | 直近5件を表示 | `Recent` |
| 手動登録 | 商品名とmgを入力 | `Custom drink` |
| 量 | 半分、1杯、2杯を選択 | `0.5x`, `1x`, `2x` |
| 時刻 | 初期値は現在時刻、変更可能 | `Consumed at`, `Now` |
| 確定 | 選択値と時刻で記録 | `Log 205 mg` |

商品が見つからない場合は検索結果の末尾に `Custom drink` を残します。

### Custom drink

| フィールド | 必須 | 仕様 |
|---|---:|---|
| Name | Yes | 1文字以上 |
| Caffeine | Yes | 0から2,000mgまでの整数 |
| Serving note | No | `12 fl oz can` など |
| Consumed at | Yes | 初期値はNow |
| Save to recents | Yes | 初回リリースでは常に保存 |

医薬品も同じ手動登録で扱います。

初回リリースでは薬の成分データベースを提供しません。

## Drink detail画面

```text
Starbucks Cold Brew

Approximate caffeine
205 mg

Size
[ Tall ] [ Grande ] [ Venti ] [ Trenta ]

This estimate is based on the US recipe.
Actual caffeine may vary by size and preparation.

[ Log now ]
```

公式値を確認できたサイズだけを選択可能にします。

Grandeの値からVentiを比例計算して表示しません。

サイズ値が未登録の商品は、確認できた基準サイズだけを表示し、別サイズは `Custom drink` に誘導します。

## History画面

### 無料範囲

7日間の記録、日別合計、日別の最高値、最後に記録した時刻を表示します。

### Pro範囲

30日間以上の履歴、週次の平均、曜日ごとの傾向、睡眠との比較、シナリオ比較を表示します。

```text
History

[ 7 days ] [ 30 days ]

This week
Average       214 mg
Highest       428 mg
Last caffeine 3:42 PM

Today
9:14 AM   Cold Brew             205 mg
1:05 PM   Diet Coke               46 mg
```

記録の行をタップすると、編集と削除を選べます。

## Settings画面

```text
Settings

Caffeine model
  Half-life                 4 hours
  How the model works       >

Daily target
  Personal target           Not set

Sleep
  Typical bedtime           11:00 PM

Health
  Apple Health              Not connected >

Appearance
  Units                     US customary
  Reduce motion             On

Subscription
  Cafade Pro                >
  Restore purchases         >

About
  Privacy
  Export data
  Delete all data
```

日次目標の初期値は設定しません。

ユーザーが入力した目標は比較用の値として扱い、安全基準のように表示しません。

半減期の選択肢は `2 hours`、`4 hours`、`6 hours`、`8 hours` とします。

初期値は4時間です。

## 半減期モデル

各記録のカフェイン量を、次の式で現在時刻まで減衰させます。

```text
remaining(t) = Σ amountᵢ × 0.5 ^ ((t - consumedAtᵢ) / halfLife)
```

範囲値を持つ商品は、下限と上限を別々に計算します。

画面には単一値だけを出す場合でも、元データが範囲であることを保持します。

ユーザーが半減期を変更した場合、過去の記録にも現在の設定を適用します。

設定ページの説明文は次の内容にします。

```text
How the estimate works

Caffeine leaves the body gradually.

Cafade uses a simple half-life model. After each half-life, the estimated amount is reduced by half.

Your selected half-life changes the shape of the estimate. It does not measure your personal metabolism.

This is an estimate, not a measurement or medical advice.
```

過去の記録より前の時刻は計算しません。

将来時刻の記録は保存前に拒否します。

## データ定義

### CatalogItem

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| id | String | Yes | アプリ内で不変の識別子 |
| marketCode | String | Yes | 初回値は `US` |
| brand | String | No | ブランド名 |
| productName | String | Yes | 表示名 |
| variant | String | No | `hot`、`iced`、`original` など |
| servingLabel | String | Yes | `Grande / 16 fl oz` など |
| servingMl | Int | Yes | 正規化したml値 |
| valueKind | Enum | Yes | `exact`、`approximate`、`range` |
| typicalMg | Int | No | 代表値 |
| minMg | Int | No | 範囲の下限 |
| maxMg | Int | No | 範囲の上限 |
| sourceURL | URL | Yes | 公式情報のURL |
| verifiedAt | Date | Yes | 値を確認した日 |
| isActive | Bool | Yes | カタログに表示するか |

### IntakeEvent

| フィールド | 型 | 必須 | 説明 |
|---|---|---:|---|
| id | UUID | Yes | 記録の識別子 |
| catalogItemID | String | No | カタログ商品への参照 |
| customName | String | No | 手動登録名 |
| caffeineMg | Int | Yes | この記録に含まれる量 |
| minMg | Int | No | 範囲値の下限 |
| maxMg | Int | No | 範囲値の上限 |
| quantityMultiplier | Decimal | Yes | `0.5`、`1`、`2` など |
| consumedAt | Date | Yes | 飲んだ時刻 |
| servingNote | String | No | サイズや補足 |
| sourceKind | Enum | Yes | `catalog`、`custom`、`healthKit` |
| createdAt | Date | Yes | 保存時刻 |
| updatedAt | Date | Yes | 更新時刻 |

### UserSettings

| フィールド | 型 | 初期値 |
|---|---|---|
| marketCode | String | `US` |
| languageCode | String | `en-US` |
| unitSystem | Enum | `usCustomary` |
| halfLifeHours | Int | `4` |
| dailyTargetMg | Int? | `nil` |
| typicalBedtime | LocalTime? | `nil` |
| reduceMotion | Bool | System setting |
| healthKitWriteEnabled | Bool | `false` |

量は内部ではmlに統一し、表示時にUS customaryへ変換します。

カフェイン量のmgは市場や単位によって変換しません。

市場、言語、単位、タイムゾーンは別々の設定として保持します。

## USカタログ初期値

値の出典を確認できない商品は、出荷用カタログに入れません。

画面では値の種類に応じて `Exact`、`Approximate`、`Typical range` を表示します。

### 一般カテゴリ

| ID | 表示名 | 基準量 | カフェイン | 種類 |
|---|---|---:|---:|---|
| generic.brewed-coffee | Brewed Coffee | 12 fl oz | 113–247mg | range |
| generic.black-tea | Black Tea | 12 fl oz | 71mg | approximate |
| generic.green-tea | Green Tea | 12 fl oz | 37mg | approximate |
| generic.decaf-coffee | Decaf Coffee | 8 fl oz | 2–15mg | range |

出典：<https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much>

### Starbucks

| ID | 表示名 | 基準量 | カフェイン |
|---|---|---:|---:|
| starbucks.blonde-roast.grande | Blonde Roast | Grande / 16 fl oz | 315–390mg |
| starbucks.pike-place.grande | Pike Place Roast | Grande / 16 fl oz | 315–390mg |
| starbucks.americano.grande | Caffè Americano | Grande / 16 fl oz | 約225mg |
| starbucks.latte.grande | Caffè Latte | Grande / 16 fl oz | 約150mg |
| starbucks.caramel-macchiato.grande | Caramel Macchiato | Grande / 16 fl oz | 約150mg |
| starbucks.cold-brew.grande | Cold Brew | Grande / 16 fl oz | 約205mg |
| starbucks.nitro-cold-brew.grande | Nitro Cold Brew | Grande / 16 fl oz | 約280mg |
| starbucks.iced-coffee.grande | Iced Coffee | Grande / 16 fl oz | 約185mg |
| starbucks.iced-latte.grande | Iced Caffè Latte | Grande / 16 fl oz | 約150mg |
| starbucks.iced-shaken-espresso.grande | Iced Shaken Espresso | Grande / 16 fl oz | 約225mg |
| starbucks.brown-sugar-oatmilk.grande | Iced Brown Sugar Oatmilk Shaken Espresso | Grande / 16 fl oz | 約255mg |
| starbucks.iced-mocha.grande | Iced Caffè Mocha | Grande / 16 fl oz | 約175mg |

出典：<https://www.starbucks.com/menu/drinks/hot-coffee>、<https://www.starbucks.com/menu/drinks/cold-coffee>

商品値の例：<https://www.starbucks.com/menu/product/480/hot/nutrition>、<https://www.starbucks.com/menu/product/2121255/iced/nutrition?=___psv__p_37571244__t_a_>

Starbucksの公式説明でも、カフェイン量はレシピ、比率、抽出方法で変わるとされています。

出典：<https://about.starbucks.com/stories/2026/coffee-science-which-starbucks-drink-has-the-most-caffeine/>

### Starbucksのサイズ

初期データでは、Starbucksの商品をGrandeで登録します。

Grande以外に検証するサイズは次の6種類です。

| 提供方法 | サイズ | 容量 |
|---|---|---:|
| Hot | Short | 8 fl oz |
| Hot | Tall | 12 fl oz |
| Hot | Venti | 20 fl oz |
| Iced | Tall | 12 fl oz |
| Iced | Venti | 24 fl oz |
| Iced | Trenta | 30 fl oz |

v1.0では、利用頻度と確認コストを考えてHotのTallとVenti、IcedのTallとVentiを優先します。

ShortとTrentaは、公式値を確認できた商品から順に追加します。

容量だけを使ってGrandeの値から別サイズの値を推定しません。

### エナジードリンク

| ID | 表示名 | 基準量 | カフェイン |
|---|---|---:|---:|
| redbull.original.8-4 | Red Bull Original | 8.4 fl oz | 80mg |
| redbull.original.12 | Red Bull Original | 12 fl oz | 114mg |
| redbull.original.16 | Red Bull Original | 16 fl oz | 151mg |
| redbull.original.20 | Red Bull Original | 20 fl oz | 198mg |
| monster.original-green.16 | Monster Original Green | 16 fl oz | 160mg |
| celsius.original.can | CELSIUS | 1 can | 200mg |
| celsius.essentials.can | CELSIUS Essentials | 1 can | 270mg |

出典：<https://www.redbull.com/us-en/energydrink/questions/how-much-caffeine-is-in-a-can-of-red-bull-energy-drink>、<https://www.monsterenergy.com/en-us/energy-drinks/monster-energy/original-green/>、<https://www.celsius.com/essential-facts/>

### ソフトドリンク

| ID | 表示名 | 基準量 | カフェイン |
|---|---|---:|---:|
| coca-cola.original.12 | Coca-Cola Original | 12 fl oz | 34mg |
| coca-cola.zero.12 | Coca-Cola Zero Sugar | 12 fl oz | 34mg |
| diet-coke.original.12 | Diet Coke | 12 fl oz | 46mg |
| pepsi.original.12 | Pepsi | 12 fl oz | 38mg |
| diet-pepsi.original.12 | Diet Pepsi | 12 fl oz | 35mg |

出典：<https://www.coca-cola.com/us/en/about-us/faq/what-is-caffeine>、<https://www.pepsi.com/faq>

`Pepsi Zero Sugar` は候補に残しますが、現行ラベルまたは公式栄養情報を確認するまで `isActive = false` とします。

### 保留項目

| 商品群 | 保留理由 |
|---|---|
| Starbucksの全サイズ | サイズごとの公式値の確認が必要 |
| Dunkinの主要商品 | 現行ページで商品別カフェイン値を確認できていない |
| McDonald’s Coffee | 公式FAQがカフェイン量を掲載していない |
| 市販薬 | 商品名と成分表をユーザーが登録する方針 |
| MatchaとChai | 商品やレシピによる差が大きい |

## 課金範囲

初回起動直後に課金画面を出しません。

ユーザーが現在値を見て、履歴や睡眠との比較を使いたくなった時点でProを提示します。

| 機能 | Free | Pro |
|---|---:|---:|
| 飲料の記録 | Yes | Yes |
| USカタログ | Yes | Yes |
| Custom drink | Yes | Yes |
| 現在の残量 | Yes | Yes |
| 半減期の説明 | Yes | Yes |
| 7日履歴 | Yes | Yes |
| 30日以上の履歴 | No | Yes |
| 週次インサイト | No | Yes |
| 睡眠との比較 | No | Yes |
| 就寝時シナリオ | No | Yes |
| HealthKit連携 | Yes | Yes |

RevenueCatの仮IDは次のとおりです。

```text
entitlement: pro
monthly: cafade_pro_monthly
yearly: cafade_pro_yearly
```

### RevenueCatの役割

アプリ内の購入状態はRevenueCatから取得します。

画面はRevenueCatのSDKを直接呼ばず、`EntitlementService`を経由してPro状態を読み取ります。

| RevenueCat設定 | 値 |
|---|---|
| Offering | `default` |
| Entitlement | `pro` |
| Package | 月額、年額 |
| App User ID | 匿名ユーザーを初期値とする |

`EntitlementService`は、購入、Restore、期限切れ、ネットワークエラー、商品未取得を別々の状態として扱います。

PaywallにはRevenueCatから取得した現地価格と、ユーザーが無料トライアルの対象かどうかを表示します。

Appleの無料トライアルはApp Store側で適用され、RevenueCatはその商品と購入状態を扱います。

参照：<https://www.revenuecat.com/docs/subscription-guidance/subscription-offers>、<https://www.revenuecat.com/docs/getting-started/restoring-purchases>

RevenueCatのDashboard用シークレットやAppleの秘密鍵はGitHubへ保存しません。

公開SDKキーと環境設定は、正式なbundle identifierとRevenueCatプロジェクトを作成してから登録します。

日本の価格目標は月額300円、年額3,000円です。

7日間の無料トライアルは、月額商品と年額商品の両方に設定します。

App Storeでは、同じサブスクリプショングループの無料トライアルを一人のユーザーが複数回使うことはできません。

初回市場は米国なので、米国ストアでは米ドルの現地価格を表示します。

App Store Connectでは国や地域ごとに価格を設定でき、基準地域から他地域の比較価格を作成できます。

参照：<https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions>、<https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions>

### Paywall文言

```text
See your patterns

Go beyond today with Cafade Pro.

• 30-day and longer history
• Weekly caffeine patterns
• Sleep comparison
• What-if previews for your last drink

[ Start Pro ]
[ Restore purchases ]

Terms  Privacy  Not now
```

箇条書きの表示は、最終画面ではAppleの標準的なList表現に合わせます。

無料範囲の記録機能を隠して課金を迫る設計にはしません。

## HealthKit

アプリ内の記録を正規データとして保存し、HealthKitへの書き込みは任意の複製処理にします。

初回リリースでは、書き込み対象を `dietaryCaffeine` に絞ります。

睡眠データの読み取りは初回リリースに含めません。

睡眠比較は、初回リリースではSettingsに入力した就寝時刻を使います。

`sleepAnalysis` の読み取りは、HealthKit書き込みが安定してから追加する機能とします。

権限リクエストは初回起動で表示しません。

最初の記録を保存した後、Todayに一度だけ次の案内を表示します。

```text
Save your caffeine to Apple Health?

Cafade can add your logged caffeine to Apple Health. This is optional.

[ Connect Apple Health ]
[ Not now ]
```

ユーザーが `Connect Apple Health` を押したときだけ、Appleの標準権限画面を表示します。

Settingsにも同じ導線を置きます。

Appleは、HealthKitへのアクセスを必要な場面で求め、起動直後に求めないよう案内しています。

参照：<https://developer.apple.com/design/human-interface-guidelines/healthkit>

HealthKitを拒否した場合は、アプリ内の就寝時刻設定で予測を続けます。

```text
Write caffeine to Apple Health

Cafade can save your caffeine entries as Dietary Caffeine in Apple Health.
This is optional and can be changed in Settings.
```

初回リリースでは書き込みだけを使うため、HealthKitの読み取り目的を説明する権限文言は追加しません。

アプリがHealthKitへ書き込むサンプルには、アプリ内記録のIDをmetadataとして保持し、編集時は既存サンプルを削除して新しい値を書き込みます。

HealthKitの利用目的とプライバシー説明は、実装時にAppleの現行ドキュメントとApp Review Guidelinesを再確認します。

参照：<https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/dietarycaffeine>、<https://developer.apple.com/documentation/healthkit/protecting-user-privacy>、<https://developer.apple.com/app-store/review/guidelines/>

## App Store初稿

### Metadata

| 項目 | 初稿 |
|---|---|
| App name | `Cafade` |
| Subtitle | `See what caffeine remains` |
| Promotional text | `Log coffee, tea, soda, and energy drinks. See your estimated caffeine fade through the day.` |
| Category candidate | Health & Fitness |
| Keywords draft | `caffeine,coffee,tea,energy drink,sleep,tracker,half-life` |

### Description

```text
Know what you drank. See what remains.

Cafade turns coffee, tea, soda, energy drinks, and custom entries into a calm estimate of caffeine remaining throughout your day.

Log in seconds
Search the US catalog, repeat a recent drink, or enter a custom caffeine amount.

See the curve
Watch each drink fade over time with a simple half-life model.

Plan your last cup
Set a personal bedtime and see when your estimated caffeine is likely to fall below it.

Look back with Cafade Pro
Unlock longer history, weekly patterns, sleep comparison, and what-if previews.

Private by default
Cafade works without an account. Your entries stay on your device unless you choose to connect Apple Health.

Caffeine values can vary by product, size, recipe, and preparation. Cafade provides estimates for personal tracking and is not medical advice.
```

### Screenshot copy

| 順番 | 見出し | 補足 |
|---:|---|---|
| 1 | `Know what remains.` | `A calm view of your caffeine through the day.` |
| 2 | `Log in seconds.` | `Coffee, tea, energy drinks, or your own entry.` |
| 3 | `Watch it fade.` | `A simple estimate based on caffeine half-life.` |
| 4 | `Plan your last cup.` | `See your estimated caffeine around bedtime.` |
| 5 | `See your patterns.` | `Unlock longer history with Cafade Pro.` |

### App Review notes初稿

```text
Cafade is a local-first caffeine tracking app.

The app works without an account and without HealthKit permission.
HealthKit access is optional. When enabled, Cafade can write caffeine entries to Dietary Caffeine. The first release does not read health data.

Caffeine values are estimates or official product values and may vary by product, size, recipe, and preparation.
The app does not provide medical advice or a safety limit.

Pro features are available through the monthly and yearly subscription products.
Restore purchases is available from Settings and the paywall.
```

## 実装順序

1. 半減期計算、ローカル保存、Today、Log、編集、削除を作る。
2. USカタログとCustom drinkを追加する。
3. History、Settings、モデル説明を追加する。
4. HealthKitの任意書き込みを追加する。
5. RevenueCatのPro権限とPaywallを追加する。
6. Reduce Motion、VoiceOver、端末サイズ、空状態、権限拒否を確認する。
7. App Store素材、プライバシー説明、TestFlight用のレビュー手順を整える。

## 出荷前の判定項目

| 判定 | 合格条件 |
|---|---|
| 初回起動 | 権限や購入を許可しなくてもTodayを表示できる |
| 初回記録 | 最近の飲料なら短い操作で記録できる |
| 不明商品 | Custom drinkへ迷わず移動できる |
| 半分だけ飲んだ場合 | `0.5x` で量を記録できる |
| 編集と削除 | 過去記録を変更して曲線も更新される |
| 範囲値 | 画面に推定値であることが残る |
| 日付変更 | 深夜の記録が翌日に正しく表示される |
| 単位変更 | US customaryとmetricを切り替えられる |
| HealthKit拒否 | アプリ内記録がそのまま使える |
| 睡眠データなし | 就寝時刻の手動設定へ戻れる |
| 購入失敗 | 無料範囲へ戻り、再試行とRestoreを提供できる |
| Reduce Motion | グラフが静的に更新される |
| VoiceOver | 商品名、mg、時刻、ボタンの役割を読み上げられる |
| カタログ出典 | 有効な商品は公式URLと確認日を持つ |

## 実装前に残す判断

- 月額と年額の米国ストア価格
- サポートURL、プライバシーポリシーURL、利用規約URL
- Cloudflare PagesのGitHub連携とサブドメイン設定

この3項目以外は、v0.2の画面とデータ定義で実装を始められます。
