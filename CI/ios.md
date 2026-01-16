# GitHub Actions iOS 构建说明

本仓库已添加两个 GitHub Actions Workflow：

- `.github/workflows/ios-build.yml`：在 `macos-latest` runner 上构建并导出 iOS IPA（上传为 artifact）。
- `.github/workflows/ios-deploy.yml`：在构建后使用 `fastlane` 将 IPA 上传到 App Store（需要额外的 App Store Connect API Key secrets）。

必需的 GitHub 仓库 Secrets（请在仓库 Settings → Secrets 中添加）：

- `IOS_P12_BASE64`：签名证书（.p12）文件的 base64 编码内容。
- `IOS_P12_PASSWORD`：.p12 的密码（如果没有密码请留空字符串）。
- `IOS_PROVISIONING_BASE64`：对应的 `.mobileprovision` 文件的 base64 编码内容。

如何生成 base64（示例）：

macOS / Linux:
```bash
base64 -i cert.p12 | tr -d "\n" > cert.p12.base64.txt
base64 -i MyProvisioningProfile.mobileprovision | tr -d "\n" > profile.mobileprovision.base64.txt
```

Windows PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('cert.p12')) > cert.p12.base64.txt
[Convert]::ToBase64String([IO.File]::ReadAllBytes('MyProvisioningProfile.mobileprovision')) > profile.mobileprovision.base64.txt
```

填充上述 Secrets 后，可在 Actions 页面手动触发或 push 到 `main` 分支来运行构建工作流。构建成功时，IPA 会作为 artifact 上传，名为 `ios-ipa`，可在 workflow 运行页面的 Artifacts 下载。

自动上传到 App Store 的额外 Secrets：

- `APP_STORE_CONNECT_API_KEY_JSON_BASE64`：App Store Connect API key JSON 的 base64 编码（JSON 包含 `key_id`, `issuer_id`, `key` 字段，其中 `key` 为 p8 的内容）。
- `APP_SPECIFIC_PASSWORD`：可选，用于一些 fastlane 操作的应用专用密码（非必须）。

如何生成 App Store Connect API key JSON（示例）：
1. 在 App Store Connect → Users and Access → Keys 创建 API Key，会下载一个 `.p8` 文件；记录 `Key ID` 和 `Issuer ID`。
2. 创建一个 JSON 文件（例如 `app_store_connect_key.json`），内容示例：

```json
{
  "key_id": "<KEY_ID>",
  "issuer_id": "<ISSUER_ID>",
  "key": "-----BEGIN PRIVATE KEY-----\\n...p8 content...\\n-----END PRIVATE KEY-----"
}
```

3. 将该 JSON 文件 base64 编码并添加为 `APP_STORE_CONNECT_API_KEY_JSON_BASE64` Secret：

macOS / Linux:
```bash
base64 -i app_store_connect_key.json | tr -d "\n" > app_store_connect_key.json.base64.txt
```

Windows PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('app_store_connect_key.json')) > app_store_connect_key.json.base64.txt
```

工作流 `ios-deploy.yml` 会解码该 JSON、安装证书并使用 `fastlane deliver` 上传 IPA。工作流内也包含签名/描述文件检查步骤，会打印 `security find-identity`、解析并显示描述文件的 `TeamIdentifier` 与 `UUID`，以便在 Actions 日志中诊断签名问题。

常见注意事项：
- 请确保 `ios/ExportOptions.plist` 中的 `teamID` 已替换为你的 Apple Team ID，或根据需要调整 `method`（`app-store`/`ad-hoc`/`development`）。
- 若使用 Xcode 自动签名（Automatic Signing），建议切换到 `fastlane match` 或通过 App Store Connect API 管理签名；当前示例假定你使用手动签名（手动提供 p12 + mobileprovision）。
- 如果 Actions 日志显示 `No valid code signing certificates were found` 或 `No development certificates available`：请检查 p12 是否正确、密码是否匹配、描述文件是否包含与你的 App Bundle ID 对应的 App ID，并检查 provisioning profile 的 TeamIdentifier 是否与证书匹配。

如果你愿意，我可以：
- 帮你把 `ios/ExportOptions.plist` 中的 `YOUR_TEAM_ID` 替换为实际 Team ID（你提供），
- 或将工作流切换为 `fastlane match`（需要一个存放证书的 Git 存储库或使用 GitHub Secrets），
- 或把 `fastlane` 配置（Fastfile）添加到仓库以支持自定义的上架流程（截图、元数据等）。
# GitHub Actions iOS 构建说明

本仓库已添加一个 GitHub Actions Workflow：`.github/workflows/ios-build.yml`，用于在 `macos-latest` runner 上构建并导出 iOS IPA。

必要的 GitHub 仓库 Secrets（请在仓库 Settings → Secrets 中添加）：

- `IOS_P12_BASE64`：签名证书（.p12）文件的 base64 编码内容。
- `IOS_P12_PASSWORD`：.p12 的密码（如果没有密码请留空字符串）。
- `IOS_PROVISIONING_BASE64`：对应的 `.mobileprovision` 文件的 base64 编码内容。

如何生成 base64（示例）：

macOS / Linux:
```bash
base64 -i cert.p12 | tr -d "\n" > cert.p12.base64.txt
base64 -i MyProvisioningProfile.mobileprovision | tr -d "\n" > profile.mobileprovision.base64.txt
```

Windows PowerShell:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('cert.p12')) > cert.p12.base64.txt
[Convert]::ToBase64String([IO.File]::ReadAllBytes('MyProvisioningProfile.mobileprovision')) > profile.mobileprovision.base64.txt
```

填写 Secrets 后，可在 Actions 页面手动触发或 push 到 `main` 分支来运行工作流。

产物位置：工作流成功后，IPA 会作为 artifact 上传，名为 `ios-ipa`，可以在 workflow 运行页面的 Artifacts 下载。

常见注意事项：
- 请确保 `ios/ExportOptions.plist` 中的 `teamID` 已替换为你的 Apple Team ID，或根据需要调整 `method`（`app-store`/`ad-hoc`/`development`）。
- 若使用自动签名（Xcode 自动管理），需要调整 workflow 流程使用 fastlane 或 match 来管理签名。当前 workflow 假定手动签名（manual）。
- 如果构建失败，请查看 Actions 日志中关于 codesign 或 provisioning 的错误，通常是证书/描述文件不匹配或 keychain 未正确导入导致。
