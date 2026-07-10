# One-time: deploy SSH key to phones, enable sshd on boot.
# Prereq: mesh.env + mesh.secrets.env (PHONE_SSH_PASSWORD), openssh + passwd on phones.

$ErrorActionPreference = "Stop"
Import-Module (Join-Path $PSScriptRoot "remote\phone-remote.psm1") -Force
Install-PhoneSshKeys @("phone-a", "phone-b")
