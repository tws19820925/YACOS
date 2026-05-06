# YACOS web page

YACOS FORTUNE TELLINGの公開ページです。`privacy_policy.html` は、アプリ紹介、安全な使い方、プライバシーポリシーを1ページにまとめた公開URLとして利用します。

## Files

- `privacy_policy.html`: アプリ紹介、安全な使い方、プライバシーポリシー本文
- `index.html`: ルートURLから `privacy_policy.html` へ移動する入口
- `assets/promo/yacos-hero-image2.jpg`: ヒーローで使う占いイメージ画像
- `assets/promo/yacos-icon.webp`: faviconとブランド表示に使うアプリアイコン
- `assets/promo/yacos-ogp.jpg`: SNSなどのプレビューで使うOGP画像
- `assets/screenshots/*.jpg`: アプリ紹介に掲載する画面画像

## Screenshot Update Checklist

- [ ] `assets/screenshots/screenshot_manifest.json` の `updatedAt`、`capturedAt`、`versionName`、`versionCode` を更新する。
- [ ] 現在のAndroidアプリの主要導線と一致する画面を使う。
- [ ] 生年月日、名前、手の画像、相談本文、メモ本文などの個人情報を含めない。
- [ ] 画面内の占い結果が医療、法律、投資、結婚、転職などの断定に見えない。
- [ ] alt属性が画面内容を短く説明している。
- [ ] 画像容量が過大ではなく、モバイルでも読み込みやすい。
- [ ] `privacy_policy.html` 内の `src` 参照先が存在する。
- [ ] `powershell -ExecutionPolicy Bypass -File scripts/verify_public_assets.ps1` が成功する。

## Safety Copy Checklist

- [ ] 占い結果はエンターテインメントと自己理解のヒントとして説明している。
- [ ] 重要な判断では専門家や信頼できる情報も大切にする旨を書いている。
- [ ] 共有文に含まれる情報と含まれない情報が、Androidアプリの実装と一致している。
- [ ] 通知本文に個人情報や相談本文を含めない説明がある。
- [ ] カメラ権限の用途が手相撮影に限られていることを説明している。

## Local Verification

PowerShellで公開ページのローカル参照先を確認します。

公開スクリーンショットの鮮度、寸法、容量、HTML参照、alt文言は次のコマンドで確認します。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_public_assets.ps1
```

手動で参照先だけを確認したい場合は次のスニペットを使います。

```powershell
$files = @('privacy_policy.html','index.html')
$missing = @()
foreach ($file in $files) {
  $text = Get-Content -Raw -Path $file
  [regex]::Matches($text, '(?:src|href)="([^"]+)"') | ForEach-Object {
    $ref = $_.Groups[1].Value
    if ($ref -match '^(#|mailto:|https?:)') { return }
    if (-not (Test-Path (Join-Path (Split-Path $file) $ref))) {
      $missing += "$file -> $ref"
    }
  }
}
if ($missing.Count -eq 0) { 'All local asset links exist.' } else { $missing }
```

文字化けが戻っていないかも確認します。典型的な mojibake 断片が本文に混ざっていないか、README、`privacy_policy.html`、`index.html` を検索してください。

## Update Notes

- Androidアプリ側で共有文、履歴、入力項目、カメラ利用、通知利用を変更した場合は、公開ページの説明と矛盾しないか確認してください。
- スクリーンショットを差し替える場合は、個人情報や実在する相談本文が含まれていない画像を使ってください。
- 公開ページの画像は、アプリの現在の主要導線と一致するものを優先してください。
