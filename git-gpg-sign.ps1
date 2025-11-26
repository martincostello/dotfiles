#! /usr/bin/env pwsh
$passphrase = (git config --get gpg.passphrase)
& gpg --batch --pinentry-mode=loopback --passphrase "${passphrase}" $args
