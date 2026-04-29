# YACOS web page

YACOS FORTUNE TELLINGの公開ページです。`privacy_policy.html`をGoogle Play等に提出するプライバシーポリシーURLとして使えるよう、アプリ紹介とポリシー本文を1ページに統合しています。

## Files

- `privacy_policy.html`: アプリ紹介とプライバシーポリシー本体
- `index.html`: ルートURLから`privacy_policy.html`へ移動する入口
- `assets/promo/yacos-hero.jpg`: ヒーロー背景と画面イメージに使うアプリ由来のビジュアル
- `assets/promo/yacos-icon.webp`: faviconとブランド表示に使うアプリアイコン
- `assets/promo/yacos-ogp.jpg`: SNS等のプレビューで使う横長画像

## Update Notes

- アプリ側で外部送信、広告SDK、外部分析SDK、ログ送信、アカウント機能などを追加した場合は、`privacy_policy.html`の「保存場所と第三者提供」を必ず更新してください。
- カメラ以外の権限を追加した場合は、権限の目的をプライバシーポリシーへ追記してください。
- 共有文に含める情報を変えた場合は、「共有機能」の説明をアプリ実装に合わせて更新してください。
