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
