$ErrorActionPreference = "Stop"

$publisher = "CN=B7B226EF-AAE5-43BA-8F9E-880DB742EFD0"
$certPath = "build\windows\msix\VynodyTest.pfx"
$cerPath = "build\windows\msix\VynodyTest.cer"
$pwd = ConvertTo-SecureString -String "123456" -Force -AsPlainText

# 1. 查找或创建测试自签名证书
$cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $publisher } | Select-Object -First 1

if (-not $cert) {
    Write-Host "Creating self-signed test certificate..."
    $cert = New-SelfSignedCertificate -Type Custom `
        -Subject $publisher `
        -KeyUsage DigitalSignature `
        -FriendlyName "Vynody Test Cert" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3") `
        -NotAfter (Get-Date).AddYears(5)
}

# 导出证书文件
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $pwd -Force | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null

# 2. 导入到当前用户的受信任根证书机构（CurrentUser 不需要管理员提权）
Import-Certificate -FilePath $cerPath -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
Write-Host "Certificate installed into Trusted Root Certification Authorities."

# 3. 查找 signtool.exe
$signtool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe"
if (-not (Test-Path $signtool)) {
    $signtool = (Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin" -Filter "signtool.exe" -Recurse | Select-Object -First 1).FullName
}

# 4. 签名 MSIX
$msixPath = "build\windows\msix\Vynody.msix"
if (Test-Path $msixPath) {
    & $signtool sign /fd SHA256 /a /f $certPath /p "123456" $msixPath
    Write-Host "Successfully signed $msixPath!"
} else {
    Write-Host "MSIX file not found at $msixPath"
}
