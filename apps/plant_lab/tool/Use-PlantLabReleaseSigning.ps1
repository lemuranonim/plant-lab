[CmdletBinding(DefaultParameterSetName = 'Verify')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Create')][switch] $Create,
    [Parameter(Mandatory, ParameterSetName = 'Run')][scriptblock] $Run,
    [string] $AndroidJdk = 'C:\Program Files\Android\Android Studio\jbr'
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    throw 'This signing helper requires Windows DPAPI. It must not export credentials on another OS.'
}
$android = (Resolve-Path -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'android')).Path
$signing = Join-Path $android '.signing'
$store = Join-Path $signing 'advanta-plant-lab-release.p12'
$protectedCredential = Join-Path $signing 'release-credential.clixml'
$certificate = Join-Path $signing 'advanta-plant-lab-release.cer'
$keyAlias = 'advanta-plant-lab-release'
$keytool = Join-Path $AndroidJdk 'bin/keytool.exe'
if (-not (Test-Path -LiteralPath $keytool -PathType Leaf)) { throw 'The Android JDK keytool is unavailable.' }

function Assert-NoReparsePoint([string] $Path) {
    $entry = Get-Item -LiteralPath $Path -Force
    if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Refusing to read or write signing material through a junction or symlink.'
    }
}

function Invoke-Keytool([string[]] $Arguments) {
    # Do not pass secret values in argv or emit the credential to a tool log.
    & $keytool '-J-Duser.language=en' '-J-Duser.country=US' @Arguments
    if ($LASTEXITCODE -ne 0) { throw "keytool failed ($LASTEXITCODE)." }
}

Assert-NoReparsePoint $android
if ($Create) {
    if ((Test-Path -LiteralPath $signing) -or (Test-Path -LiteralPath (Join-Path $android 'key.properties'))) {
        throw 'Signing files already exist. Nothing was overwritten. Verify or recover the existing key first.'
    }
    # Create a private folder before generating either the key or its password.
    $owner = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($owner)
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($identity in @($owner, $system)) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            $identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        [void] $acl.AddAccessRule($rule)
    }
    New-Item -ItemType Directory -Path $signing | Out-Null
    Set-Acl -LiteralPath $signing -AclObject $acl
    Assert-NoReparsePoint $signing

    $random = [Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = [byte[]]::new(48)
    try {
        $random.GetBytes($bytes)
        $securedPassword = ConvertTo-SecureString -String ([Convert]::ToBase64String($bytes)) -AsPlainText -Force
        $localCredential = [PSCredential]::new($keyAlias, $securedPassword)
        $localCredential | Export-Clixml -LiteralPath $protectedCredential -NoClobber
    } finally {
        [Array]::Clear($bytes, 0, $bytes.Length)
        $random.Dispose()
    }
}

Assert-NoReparsePoint $signing
Assert-NoReparsePoint $protectedCredential
$localCredential = Import-Clixml -LiteralPath $protectedCredential
if ($localCredential -isnot [PSCredential] -or $localCredential.UserName -cne $keyAlias) {
    throw 'Unexpected signing credential. Nothing was changed.'
}

$signingValues = @{
    PLANT_LAB_RELEASE_STORE_FILE = $store
    PLANT_LAB_RELEASE_STORE_TYPE = 'PKCS12'
    PLANT_LAB_RELEASE_STORE_PASSWORD = $localCredential.GetNetworkCredential().Password
    PLANT_LAB_RELEASE_KEY_ALIAS = $keyAlias
    PLANT_LAB_RELEASE_KEY_PASSWORD = $localCredential.GetNetworkCredential().Password
    JAVA_HOME = $AndroidJdk
}
$previous = @{}
try {
    foreach ($name in $signingValues.Keys) {
        $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $signingValues[$name], 'Process')
    }
    $storeArgs = @('-keystore', $store, '-storetype', 'PKCS12', '-alias', $keyAlias,
        '-storepass:env', 'PLANT_LAB_RELEASE_STORE_PASSWORD')
    if ($Create) {
        Invoke-Keytool (@('-genkeypair', '-keyalg', 'RSA', '-keysize', '4096', '-sigalg', 'SHA256withRSA',
            '-validity', '10950', '-dname', 'CN=Advanta Plant Lab Android Release,O=Advanta Seeds Indonesia,C=ID') + $storeArgs)
        Invoke-Keytool (@('-exportcert', '-file', $certificate) + $storeArgs)
    }
    Assert-NoReparsePoint $store
    Assert-NoReparsePoint $certificate
    $entry = Invoke-Keytool (@('-list', '-v') + $storeArgs)
    if (-not ($entry -match 'PrivateKeyEntry')) { throw 'The keystore entry is not a private signing key.' }
    $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::new($certificate)
    $fingerprint = (Get-FileHash -LiteralPath $certificate -Algorithm SHA256).Hash
    $entryFingerprint = $entry | Select-String '^\s*SHA256:\s*(?<hash>[A-Fa-f0-9:]+)' | Select-Object -First 1
    if (-not $entryFingerprint -or ($entryFingerprint.Matches[0].Groups['hash'].Value -replace ':','') -ne $fingerprint) {
        throw 'The public certificate does not match the signing key.'
    }
    $signedRequest = Invoke-Keytool (@('-certreq', '-sigalg', 'SHA256withRSA',
        '-keypass:env', 'PLANT_LAB_RELEASE_KEY_PASSWORD') + $storeArgs)
    if (-not ($signedRequest -match '^-----BEGIN (NEW )?CERTIFICATE REQUEST-----$')) {
        throw 'The private signing key did not sign a test certificate request.'
    }

    if ($Run) {
        & $Run
    } else {
        Push-Location $android
        try {
            & .\gradlew.bat :app:validateSigningPlantRelease :app:validateSigningLabRelease --offline --no-daemon --no-build-cache --console=plain
            if ($LASTEXITCODE -ne 0) { throw "Gradle signing validation failed ($LASTEXITCODE)." }
        } finally {
            Pop-Location
        }
        [PSCustomObject]@{
            Signing = 'PASS'
            KeyAlias = $keyAlias
            ValidUntilUtc = $cert.NotAfter.ToUniversalTime().ToString('yyyy-MM-dd')
            PublicCertificateSha256 = $fingerprint
            Flavors = 'plant, lab'
        }
    }
} finally {
    foreach ($name in $previous.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
    $signingValues.Clear()
}
