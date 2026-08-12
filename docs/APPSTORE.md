# Shipping Deep Contract to the App Store

Everything except signing and delivery already runs in CI. This document covers
the parts that need an Apple account, and the answers to give App Review.

## What the pipeline does

```
Godot (Linux runner)  ->  Xcode project  ->  macOS runner  ->  fastlane  ->  TestFlight
```

Godot exports a complete Xcode project on any operating system, because the iOS
preset has `application/export_project_only` set. Only the steps after that —
code signing, `xcodebuild`, and the upload — need macOS, and the
`iOS TestFlight` workflow runs those on a hosted `macos-15` runner.

You therefore do **not** need a Mac. You do need an Apple Developer Program
membership, which costs 99 USD a year.

Run the workflow from the Actions tab. It is manual on purpose: macOS runner
minutes bill at ten times the Linux rate, and every successful run consumes a
TestFlight build number.

## Verifying on iOS without an Apple account

Simulator builds are not signed, so the `iOS Simulator` workflow needs no
membership and no secrets. It runs on every push: exports the Xcode project on
a Linux runner, builds it on a macOS one, boots a simulator, installs the game,
launches it, and captures the result. The captures land in the run's artifacts.

It has already earned its keep. The first capture showed the interface drawing
over an empty grey field, and the diagnostics it collects said why: the rig
layout was missing from every export, because `.map` is not a format Godot
recognises as a resource and `all_resources` had quietly skipped it.

**What it covers**: the app builds, launches, and does not crash; the world,
sprites and fonts render; the touch controls land inside a real device's safe
area, clear of the Dynamic Island; the exported build contains its data.

**What it does not cover**:

- **The renderer.** A simulator has no Vulkan, so Godot falls back to OpenGL ES
  there. A device uses the mobile backend through MoltenVK. Anything specific to
  that path is unverified until a real build runs.
- **Performance.** The simulator uses Apple's software renderer on a shared CI
  machine; its frame rate says nothing about a phone's.
- **Touch feel.** simctl cannot tap, so the capture reaches the game through a
  launch flag rather than by playing it. Whether the stick sits comfortably
  under a thumb is a question only a device answers.

The job runs on `macos-15-intel` deliberately. Godot's official iOS templates
ship a simulator library containing x86_64 only - the xcframework directory is
named `ios-arm64_x86_64-simulator` but the archive inside holds one
architecture - so an Apple Silicon runner has nothing to link against. That
label is GitHub's last x86_64 macOS image and retires in August 2027. Device
builds are unaffected: those are arm64 and cross-compile from any host.

## One-time setup

### 1. Register the app

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. In [App Store Connect](https://appstoreconnect.apple.com), create a new app.
   - Platform: iOS
   - Bundle ID: a reverse-DNS identifier you own, e.g. `com.yourdomain.deepcontract`
   - SKU: anything unique to you
3. Note your **Team ID**: Apple Developer → Membership details. Ten characters.

### 2. Create an App Store Connect API key

Users and Access → Integrations → App Store Connect API → Team Keys → **+**

- Access: **App Manager**
- Download the `.p8` file. Apple only lets you download it once.
- Note the **Key ID** and the **Issuer ID** shown on the same page.

Base64-encode the key for storage in a secret:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

### 3. Create a private repository for match

fastlane match keeps the signing certificate and provisioning profile in a
private git repository, encrypted. Create an empty private repository, for
example `deepcontract-certificates`.

For the workflow to read it, create a GitHub personal access token with `repo`
scope and encode it:

```bash
echo -n "your-github-username:ghp_yourtoken" | base64
```

### 4. Add the repository secrets

Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | The ten-character Team ID |
| `IOS_BUNDLE_ID` | e.g. `com.yourdomain.deepcontract` |
| `APPLE_API_KEY_ID` | Key ID from step 2 |
| `APPLE_API_ISSUER_ID` | Issuer ID from step 2 |
| `APPLE_API_KEY_CONTENT` | Base64 of the `.p8` file |
| `MATCH_GIT_URL` | HTTPS URL of the private certificates repository |
| `MATCH_PASSWORD` | A passphrase you choose; match encrypts with it |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64 of `username:token` from step 3 |

Without `APPLE_API_KEY_ID` and `MATCH_GIT_URL` the signing job skips itself and
logs a warning, so the workflow stays green on a fork.

### 5. Generate the certificate, once

The signing job runs match in read-only mode, so the certificate has to exist
first. On any machine with Ruby and the repository checked out:

```bash
export APPLE_TEAM_ID=... IOS_BUNDLE_ID=... MATCH_GIT_URL=... MATCH_PASSWORD=...
export APPLE_API_KEY_ID=... APPLE_API_ISSUER_ID=... APPLE_API_KEY_CONTENT=...
bundle install
bundle exec fastlane ios certificates
```

This creates the distribution certificate and the `match AppStore <bundle-id>`
provisioning profile, and commits them encrypted to the certificates
repository. It only needs doing again when the certificate expires, after a
year.

If you have no Mac at all, run this step from the same workflow by temporarily
switching `readonly` to `false` in `fastlane/Matchfile`, or from any macOS
machine you can borrow. It does not have to be the machine that builds.

## The placeholders in the repository

`export_presets.cfg` is committed with `com.example.deepcontract` and
`APPLE_TEAM_ID` in it. `tools/export_ios.sh` substitutes the real values from
`IOS_BUNDLE_ID` and `APPLE_TEAM_ID` into a scratch copy at export time, so the
committed file never contains account details. Change the committed
placeholders only if you would rather not set the variables locally.

## Privacy manifest

The game collects nothing: no account, no analytics, no advertising, no network
access at all. Saves and settings are written to the app container.

Godot generates `PrivacyInfo.xcprivacy` during export from the `privacy/*`
options in the preset, all of which are set to "not collected". A reference
copy lives at [ios/PrivacyInfo.xcprivacy](../ios/PrivacyInfo.xcprivacy); it is
the same declaration plus an explicit empty `NSPrivacyCollectedDataTypes`. To
use it instead, drop it over the generated one after export and before signing.

The four declared API categories are the engine's, not the game's: file
timestamps, system boot time, free disk space, and user defaults.

## App Review answers

**App Privacy questionnaire** — answer "No" to data collection throughout. No
data is collected, so no data types need declaring and no tracking disclosure
is required.

**Age rating** — the questionnaire answers that apply:

| Question | Answer |
| --- | --- |
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Alcohol, Tobacco, or Drug Use | None |
| Simulated Gambling | None |
| Horror/Fear Themes | None |
| Unrestricted Web Access | No |
| Contests | No |

The game has no violence: being caught results in being escorted to a room and
losing your contraband. The expected rating is 4+.

**Export compliance** — the app uses no encryption beyond what iOS itself
provides. Answer "No" to the encryption question, or add
`ITSAppUsesNonExemptEncryption = false` via the preset's
`application/additional_plist_content`.

**Content rights** — all art, audio and code in this repository is original.
The art is generated by `tools/gen_art.py` and the audio by
`tools/gen_audio.py`; neither uses third-party assets. The engine is Godot,
under the MIT licence, and GUT (test framework, also MIT) is excluded from the
export by the preset's filter.

## Screenshots

App Store Connect requires screenshots at these sizes, in every language you
list:

| Device | Size (portrait / landscape) |
| --- | --- |
| iPhone 6.9" | 1320 x 2868 / 2868 x 1320 |
| iPhone 6.5" | 1242 x 2688 / 2688 x 1242 |
| iPad 13" | 2064 x 2752 / 2752 x 2064 |

The game is landscape-only. `tools/capture_scenarios.gd` stages and renders the
set, once per language:

```bash
xvfb-run -a .tools/godot --path . --resolution 2868x1320 \
    -s tools/capture_scenarios.gd -- build/screenshots/en en
xvfb-run -a .tools/godot --path . --resolution 2868x1320 \
    -s tools/capture_scenarios.gd -- build/screenshots/zh zh
```

Drop `xvfb-run` on a machine with a display.

## Store listing

- **Name**: Deep Contract
- **Subtitle**: Escape the rig, 1,800 m down
- **Category**: Games → Simulation (secondary: Strategy)
- **Languages**: English, Simplified Chinese
- **Price**: your call; the game has no in-app purchases and no ads

Suggested description:

> Your contract keeps renewing itself. The rig sits 1,800 metres below the
> surface, so there is no fence to climb and no gate to walk through — the only
> way out is to build something that floats.
>
> Work your shift, learn the roster, and use the parts of the day nobody is
> watching. Hide what you are building behind the panel in your locker, because
> the shelf is the first place they look. Two ways off the rig: rebuild the
> hangar's one-seat submersible, or walk onto the supply boat in a stolen
> uniform holding paperwork that says you are owed a berth.
>
> - A rigid daily schedule with musters you are counted at
> - Guards who patrol, notice, and take what they find
> - Crafting, lockers with hidden compartments, and shakedowns
> - Oxygen, pressure hatches, and blackouts that cut the cameras for
>   forty-five seconds twice a day
> - No accounts, no ads, no data collection, no network access

## Troubleshooting

**"App Store Team ID not specified"** — `APPLE_TEAM_ID` was empty when
`tools/export_ios.sh` ran.

**"No signing certificate found"** — step 5 has not been run, or
`MATCH_PASSWORD` does not match the one the certificates were encrypted with.

**"The bundle version must be higher than the previously uploaded version"** —
the workflow uses `github.run_number` as the build number. Re-running an old
run reuses its number; start a new run instead.

**Build stuck at the splash screen on device** — check that
`rendering/renderer/rendering_method.mobile` is still `mobile`. The
compatibility backend is for the browser build and does not behave on iOS.
