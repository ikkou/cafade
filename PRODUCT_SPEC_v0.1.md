# Cafade product spec v0.5

この文書は、カフェイン残量アプリの初回実装に使う基準文書です。

最終更新日は2026年8月15日です。

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
| 価格 | 米国は月額$2.99、年額$29.99。日本展開時の目標は月額300円、年額3,000円 |
| カフェイン値 | 推定値または公式値 |
| ソースコード | `github.com/ikkou/cafade` |
| 公式サイト | `https://cafade.oneshotstar.com` |
| 公開方法 | GitHubのproduction branchからCloudflare Pagesへ自動デプロイ |

初回版の画面文言は英語に統一します。

日付、曜日、時刻もアプリの対応言語で表示し、端末の言語設定によって一部だけ別言語にならないようにします。

初回版のSwiftUI環境は`en-US`へ統一し、DatePickerなどのシステムコントロールだけが別言語になる状態も避けます。日本語版ではアプリ全体のLocaleを切り替えます。

## 製品の約束

```text
Know what you drank. See what remains.
```

飲んだものを数秒で記録し、現在のカフェイン残量を時間軸で確認できるようにします。

アプリは医療上の安全基準を提示しません。

画面では `Estimated caffeine` や `Approximate value` を使い、測定値のように見せないことを固定します。

当日の記録が450mgを超えた場合は、摂取を控えることを命令せず、FDAが多くの成人について示す400mg/日の一般的な文脈と個人差を案内します。

参照：<https://www.fda.gov/consumers/consumer-updates/spilling-beans-how-much-caffeine-too-much>

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

iOS 26以降では、Todayの右下、システムタブバーの上に44pt以上の独立した追加ボタンを置きます。

アクセシビリティ用の文字サイズでは、追加ボタンを本文と重ねず、Today上部の全幅ボタンへ切り替えます。

追加ボタンにラベル付きの全幅バーや独自のタブ背景は敷きません。

記録直後だけ、追加ボタンの位置に商品名と`Undo`を含む一時通知を表示します。

一時通知は通常10秒、アクセシビリティ文字サイズでは20秒表示し、読み取りとUndo操作の時間を確保します。

シート、アラート、一時通知が表示されている間は、背後の液体アニメーションを止めます。シート表示中の背面画面はVoiceOverの読み上げ対象から外します。

AppleのHIGに合わせ、タブバーは画面間の移動に使い、記録の追加はシートで処理します。

参照：<https://developer.apple.com/design/human-interface-guidelines/tab-bars>

| 画面 | 役割 | 初回リリースの範囲 |
|---|---|---|
| Today | 現在の推定値と直近の記録 | 無料 |
| Log caffeine | 飲料を検索して記録 | 無料 |
| Drink detail | サイズとカフェイン値を確認 | 無料 |
| History | 過去の記録を確認 | 7日間は無料、30日・90日はPro |
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

問い合わせ先は `i+cafade@oneshotstar.com` とします。

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
| 主要ボタン | 右下の追加ボタンからLogシートを開く | VoiceOver: `Log caffeine` |
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
Suggested or Recent item
  ↓
Log immediately
  ↓
Today

Search result
  ↓
Drink detail
  ↓
Adjust size, quantity, or time
  ↓
Log
  ↓
Today
```

シートを開いた時点では検索欄へ自動フォーカスしません。

SuggestedとRecentを選んだ場合は、キーボードを表示せず、現在時刻と1杯分で記録します。

即時記録の直後は、商品名と結果をToday上に短く表示し、`Undo`を提供します。

検索結果を選んだ場合はDrink detailへ進み、サイズ、量、時刻を確認してから記録します。

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
| Caffeine | Yes | 1から1,000mgまでの整数 |
| Serving note | No | `12 fl oz can` など |
| Consumed at | Yes | 初期値はNow |
| Save to recents | Yes | 初回リリースでは常に保存 |

医薬品も同じ手動登録で扱います。

初回リリースでは薬の成分データベースを提供しません。

倍率を適用した後の最終量も1から1,000mgに収めます。

0mgの記録は曲線に影響せず履歴だけを増やすため、保存しません。

Nameは前後の空白を除いて1から80文字、Serving noteは120文字までとします。

保存時刻より未来のConsumed atは拒否します。

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

直近7日間の記録、日別合計、7日平均、最高日の合計、最後に記録した時刻を表示します。

7日平均は、記録がない日も0mgとして含めます。

`Highest day`は期間内で最も多く記録した日の合計です。最大の単品摂取量には使いません。

暦週ではないため、見出しは`Last 7 days`とします。

### Pro範囲

30日・90日の履歴、週次の平均、曜日ごとの傾向、睡眠との比較、シナリオ比較を表示します。

```text
History

[ 7 days ] [ 30 days ] [ 90 days ]

Last 7 days
Daily average 214 mg
Highest day   428 mg
Last caffeine 3:42 PM

Today
9:14 AM   Cold Brew             205 mg
1:05 PM   Diet Coke               46 mg
```

記録の行をタップすると、編集と削除を選べます。

範囲値を編集した場合、量を変更しなければ元の範囲を保持します。

量を変更した場合は、入力した単一値の`approximate`記録へ変換し、古い下限と上限を残しません。

編集後は常に`minMg <= caffeineMg <= maxMg`が成り立つようにします。

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

初回版は吸収時間をモデル化せず、記録した時刻から全量の減衰を開始します。血中濃度、覚醒度、個人の代謝を測定する表示にはしません。

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
| valueKind | Enum | Yes | 保存時点の`exact`、`approximate`、`range` |
| quantityMultiplier | Decimal | Yes | `0.5`、`1`、`2` など |
| consumedAt | Date | Yes | 飲んだ時刻 |
| consumedTimeZoneIdentifier | String | Yes | 記録または編集時のタイムゾーン |
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

IntakeEventは、カタログの商品が後から非表示または削除されても、保存時点の値の種類と範囲を失わないようにします。

既存記録の日別表示は端末の現在のタイムゾーンで再計算します。

記録時のタイムゾーンもエクスポートし、将来、記録時の現地日付表示へ移行できるようにします。

旧版からの更新時は摂取履歴を変更しません。起動時に設定値だけを検査し、未対応の地域と言語はUS・英語、未対応の単位はUS customary、未対応の半減期は4時間、範囲外の就寝時刻は未設定へ戻します。旧版で1,000mgを超えて保存された個人目標は1,000mgへ収め、0以下は未設定として扱います。

## USカタログ初期値

値の出典を確認できない商品は、出荷用カタログに入れません。

出荷用カタログはバージョン管理したJSONへ保存します。

アプリ起動時にIDの重複、URL、値の範囲、`min <= typical <= max`、市場コードを検証します。

商品追加や市場追加ではSwiftUIや計算コードを変更しません。

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
| 30日・90日の履歴 | No | Yes |
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

Pro権利の確認はOffering取得と独立して行います。

起動時、フォアグラウンド復帰時、RevenueCatからCustomerInfo更新を受けた時に権利を更新します。

Offering取得に失敗した場合、仮の商品名や仮価格を購入画面へ表示しません。

画面にはエラー内容と`Try again`を表示し、実Packageを取得するまで購入ボタンを無効にします。

PaywallにはRevenueCatから取得した現地価格と、ユーザーが無料トライアルの対象かどうかを表示します。

初期選択は取得した実Packageの年額、年額がなければ先頭の商品とします。

選択状態はVoiceOverにも伝えます。

無料トライアルの期間と適用資格はRevenueCatとStoreKitの実データから表示します。

固定の`7-day trial`を、資格未確認または対象外の利用者へ表示しません。

購入ボタンの近くに、トライアル後または即時に請求される更新価格と自動更新であることを表示します。

Pro利用中は販売用Paywallではなく、Appleのサブスクリプション管理画面への導線を表示します。

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

• 30- and 90-day history
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

ローカル保存に失敗した場合は画面を閉じず、再試行できるエラーを表示します。

ローカル保存後にHealthKit同期だけが失敗した場合は、記録を残したまま同期失敗を知らせます。

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

接続後は`Sync saved entries`で、権限拒否や一時的な失敗の間にHealthKitへ書けなかった記録を再同期できます。

`Stop saving new entries`でCafadeからの新規書き込みを停止できます。停止しても既存のHealthKitサンプルは削除せず、`Resume Apple Health`で再開します。

OS側の権限を取り消す場合はHealthまたはiPhone Settingsで変更します。拒否後もアプリ内ログは使えます。

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

アプリがHealthKitへ書き込むサンプルには、アプリ内記録のIDを`HKMetadataKeySyncIdentifier`として保持し、`updatedAt`から単調増加する`HKMetadataKeySyncVersion`を付けます。

編集時は同じ同期IDと新しいバージョンで保存し、HealthKitの置換動作を使います。この方法では、Cafade自身の記録を編集するためだけに読み取り権限を追加しません。

参照：<https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier>

一括削除のHealthKit処理に失敗した場合は未完了状態を端末に保持し、Settingsから再試行できるようにします。

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

## 共有カード

共有カードには、その日の総記録件数、現在の推定値、実データから計算した24時間曲線、直近4件を表示します。

一覧を4件に省略しても、総記録件数は実際の件数を使います。

前日以前の記録が現在値へ寄与している場合は、`Curve includes caffeine carried over from earlier logs`と表示します。

カードの高さはログ件数と補足行に応じて変えます。情報が少ない日の下余白を抑え、内訳や持ち越し表示が多い日は内容を切らない範囲まで広げます。

画像はシートを開いた後に一度だけ生成して再利用し、生成中と失敗を画面に表示します。

共有とPhotosへの保存は別の操作として提供します。

## アクセシビリティとHIG

本文と数値にはDynamic Type対応のテキストスタイルを使います。

最大のアクセシビリティ文字サイズでは、横並びの見出し、指標、Settings行を縦並びへ切り替えます。

本文は縮小しません。固定幅の装飾アイコンだけに拡大上限を設け、本文へ重ならない幅を確保します。

数値の主表示も最大のアクセシビリティ文字サイズではSemantic Fontへ切り替え、横に収まらない場合は縦へ組み替えます。

シート表示中は背面画面をVoiceOverの読み上げ対象から外し、モーダル内だけを移動できるようにします。

情報カードに固定高さを使わず、内容に応じて広がるようにします。

小さい文字は背景とのコントラスト比4.5:1以上を確保します。

明るいオレンジは液体や大きな装飾に使い、小さい文字には濃いオレンジを使います。

Liquid Glassはタブ、主要操作、ナビゲーションなどの機能層へ限定します。

通常の情報カードは不透明な紙面表現とし、同じスクロール内へ多数のGlass効果を重ねません。

端末のReduce Motionを常に尊重します。

SettingsからはAppleの説明ページを開けますが、非公開URLでシステム設定の特定階層へ直接移動しません。

## 性能要件

Todayは減衰計算に必要な直近期間、Historyは最大91日、Insightsは直近7日だけを取得します。

Settingsは表示時に全履歴を取得せず、エクスポート、HealthKit同期、一括削除を実行した時だけ取得します。

Todayの現在値、曲線、マーカー、目標到達時刻は、時刻または記録が変わった時に一度計算して再利用します。

目標到達時刻は5分刻みの総当たりを使わず、半減期の式から求めます。

Todayが表示されていない時またはアプリがバックグラウンドにある時は、液体の反復アニメーションを止めます。

## Privacy Manifest

アプリ本体の`PrivacyInfo.xcprivacy`をターゲットのリソースへ含めます。

アプリ内だけで使う`UserDefaults`は、Required Reason APIの`CA92.1`として申告します。

アプリ本体は追跡を行わず、追跡ドメインを持ちません。第三者SDKの申告は各SDKに同梱されたPrivacy Manifestと、Archive時に生成するPrivacy Reportでも確認します。

独自暗号方式は実装せず、OSのHTTPSとStoreKitを使います。`ITSAppUsesNonExemptEncryption`は`false`として、Archiveごとに実際の依存関係と一致することを確認します。

## App Storeのプライバシー回答

初回版はアカウント、独自のUser ID、広告ID、分析SDKを使いません。RevenueCatには匿名App User IDを使い、カフェイン記録とHealthKitデータを送りません。

App Store ConnectのApp Privacyでは、RevenueCatの現行案内に従って`Purchases > Purchase History`を申告します。用途は`App Functionality`と`Analytics`、実ユーザーには`Not linked`、広告目的の`Tracking`はなしとします。

この回答は提出時にRevenueCatの案内、同梱SDKのPrivacy Manifest、XcodeのPrivacy Reportと照合します。SDK設定、連携先、データ送信内容を変えた場合は、そのまま流用しません。

参照：<https://www.revenuecat.com/docs/platform-resources/apple-platform-resources/apple-app-privacy>

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
| 範囲値の編集 | 量を変更した場合は古い範囲を残さない |
| 入力上限 | 倍率適用後も1から1,000mgに収まる |
| 保存失敗 | 画面を閉じず、入力を保ったまま再試行できる |
| 日付変更 | 深夜の記録が翌日に正しく表示される |
| 単位変更 | US customaryとmetricを切り替えられる |
| HealthKit拒否 | アプリ内記録がそのまま使える |
| 睡眠データなし | 就寝時刻の手動設定へ戻れる |
| 購入失敗 | 無料範囲へ戻り、再試行とRestoreを提供できる |
| 商品未取得 | 仮価格を表示せず、購入ボタンを無効にする |
| 既存Proと通信失敗 | Offeringが取れなくても取得済みの権利を維持する |
| トライアル | 実際の期間と資格に一致する場合だけ表示する |
| Reduce Motion | グラフが静的に更新される |
| VoiceOver | 商品名、mg、時刻、ボタンの役割を読み上げられる |
| Larger Text | 最大のアクセシビリティ文字サイズでも重なりや見切れがない |
| Settingsの読み上げ | 各行が名称と説明を持ち、モデル説明へVoiceOverでも移動できる |
| 共有カード | 5件以上でも総件数と実際の曲線が正しい |
| カタログ出典 | 有効な商品は公式URLと確認日を持つ |

## 外部サービスで確認する項目

- 米国ストアで表示する月額と年額
- App Store Connectでの7日間トライアル設定
- RevenueCatのOffering、Entitlement、Package対応
- Sandboxでの購入、キャンセル、Restore、期限切れ
- Cloudflare Pagesのproduction branchとCustom domain

コード上の完了と外部サービスの確認は別々に記録します。
