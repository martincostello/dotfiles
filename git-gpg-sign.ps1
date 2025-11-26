#! /usr/bin/env pwsh

# We want the GnuPG version, not the version bundled with Git
$gpg = (where.exe gpg | Select-Object -Last 1)

if ($args.Contains("--sign")) {
    $passphrase = (git config --get gpg.passphrase)
    & "${gpg}" --batch --pinentry-mode=loopback --passphrase "${passphrase}" $args
}
else {
  & "${gpg}" $args
}
