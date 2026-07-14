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

### ios submit_for_review

```sh
[bundle exec] fastlane ios submit_for_review
```

Submit current build for App Store review

### ios appstore_full_release

```sh
[bundle exec] fastlane ios appstore_full_release
```

Full App Store release: upload_listing + submit_for_review (assumes IPA already uploaded)

### ios precheck

```sh
[bundle exec] fastlane ios precheck
```

Local precheck: verify metadata completeness and screenshot sizes

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
