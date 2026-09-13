# Interactive capture acceptance checks

Use the final app binary. Automated tests inject the capture transport and cannot confirm consent in macOS dialogs.

1. With no grant, launch: only Allow screen access appears; no automatic permission request or overlay.
2. Click it: system request and Screen & System Audio Recording settings appear. Denial must never enable the effect.
3. Enable the exact MacOS Duo copy being used. Return: the single action is Restart MacOS Duo.
4. Restart (unless macOS already did so). The old process exits and the same bundle reopens once, without a loop.
5. Automatic screenshot verification replaces artwork and changes the button to Test effect. The built-in display is selected automatically.
6. Test, dismiss with Escape, test again: no new access request.
7. Quit with Command-Q and reopen: the unchanged authorized build verifies automatically.
8. Revoke access and return: effects stop. Failed captures must not repeatedly retry or prompt.
9. Repeat setup in French and English, and after sleep/wake.

`--restart-test` exercises the relaunch helper without requesting consent. The next process opens normally without test arguments. `--integration-test` checks single-button states and verifies capture is blocked while waiting for restart, using injected transport.

Ad-hoc signing does not provide stable identity across rebuilt binaries. Developer ID signing and notarization require a signing identity not included in this repository. A grant for an older or different copy is not evidence that the current build is authorized.
