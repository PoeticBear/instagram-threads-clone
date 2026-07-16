fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios upload_listing

```sh
[bundle exec] fastlane ios upload_listing
```

Push metadata + screenshots to App Store Connect (no binary, no submit)

### ios fill_review_detail

```sh
[bundle exec] fastlane ios fill_review_detail
```

Fill 25+ app review questions for current version (call before submit_for_review)

### ios clean_screenshots

```sh
[bundle exec] fastlane ios clean_screenshots
```

Delete all screenshot sets for version 1.0.0 (use when stuck in AWAITING_UPLOAD)

### ios submit_for_review

```sh
[bundle exec] fastlane ios submit_for_review
```

Submit current build for App Store review

### ios appstore_full_release

```sh
[bundle exec] fastlane ios appstore_full_release
```

Full App Store release: upload_listing + fill_review_detail + submit_for_review

### ios debug_screenshots

```sh
[bundle exec] fastlane ios debug_screenshots
```

Debug: list all screenshots and their states

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
