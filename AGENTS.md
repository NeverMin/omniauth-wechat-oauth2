# Repository Guidelines

## Project Structure & Module Organization

This Ruby gem provides OmniAuth strategies for WeChat and WeCom. The entry point is `lib/omniauth-wechat-oauth2.rb`; strategy implementations live in `lib/omniauth/strategies/`. `wechat.rb` handles consumer accounts, while `wechat_qiye.rb` and `qiye_web.rb` handle enterprise authentication. Shared WeCom response validation lives in `wecom_validation.rb`.

RSpec tests live under `spec/omniauth/strategies/`, with shared setup in `spec/spec_helper.rb`. `README.md` documents integration and configuration. `VERSION` and `omniauth-wechat-oauth2.gemspec` define release metadata; `certs/` contains the gem signing certificate. There is no standalone application or asset pipeline.

## Build, Test, and Development Commands

- `bundle install`: install runtime and development dependencies.
- `bundle exec rake`: run the default RSpec suite.
- `bundle exec rspec spec/omniauth/strategies/wecom_callback_spec.rb`: run enterprise callback regression tests.
- `bundle exec rake build`: package the gem into `pkg/` using Bundler's gem tasks.

The gemspec declares Ruby `>= 2.4.0`; preserve compatibility when changing syntax. Gem signing references `~/.ssh/gem-private_key.pem`, so packaging may require that private key. Exercise application integration through a host Rails or Rack application using the README examples.

## Coding Style & Naming Conventions

Use two-space indentation, `snake_case` for methods and filenames, and `CamelCase` for classes beneath `OmniAuth::Strategies`. Follow the surrounding file's quote and hash syntax; existing files use both older and newer Ruby hash styles. Keep provider-specific behavior in its strategy and shared validation in the existing helper. No formatter or lint configuration is checked in.

## Testing Guidelines

Use RSpec 3.13 and name test files `*_spec.rb`. Add regression examples for changed authorization parameters, identity mapping, and callback failures. Stub provider HTTP requests with Faraday's test adapter, as the callback suite does, rather than contacting live APIs. No numerical coverage threshold is configured. Run the full suite before submitting changes.

## Commit & Pull Request Guidelines

Git history uses short, free-form subjects rather than a consistent Conventional Commits format. Write a concise subject describing the change, such as `Fix WeCom callback state validation`.

Describe the affected strategy, behavior change, and test commands/results in each pull request. Link relevant issues and update README examples when configuration or authentication behavior changes.

## Security & Configuration Tips

Keep credentials in environment variables and never commit secrets or signing keys. Preserve TLS verification, session-bound state checks, and rejection of unsuccessful API responses or blank member IDs. Avoid logging access tokens or complete authentication hashes.
