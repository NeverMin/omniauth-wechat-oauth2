Omniauth-wechat-oauth2
======================

[![Gem Version](https://img.shields.io/gem/v/omniauth-wechat-oauth2.svg)][gem]
[![Security Check](https://hakiri.io/github/NeverMin/omniauth-wechat-oauth2/master.svg)][security]
[![Build Status](https://app.travis-ci.com/Eric-Guo/omniauth-wechat-oauth2.svg?branch=master)][travis]

[gem]: https://rubygems.org/gems/omniauth-wechat-oauth2
[security]: https://hakiri.io/github/NeverMin/omniauth-wechat-oauth2/master
[travis]: https://app.travis-ci.com/github/Eric-Guo/omniauth-wechat-oauth2


Wechat OAuth2 Strategy for OmniAuth 1.0.

You need to get a wechat API key at: https://mp.weixin.qq.com

* Wechat oauth2 specification can be found at: https://mp.weixin.qq.com/wiki/index.php?title=网页授权获取用户基本信息
* Wechat Qiye oauth2 specification can be found at: http://qydev.weixin.qq.com/wiki/index.php?title=OAuth验证接口

## Installation

Add to your `Gemfile`:

```ruby
gem "omniauth-wechat-oauth2"
```

Then `bundle install`.


## Usage

Here's an example for adding the middleware to a Rails app in `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :wechat, ENV["WECHAT_APP_ID"], ENV["WECHAT_APP_SECRET"]
end
```

You can now access the OmniAuth Wechat OAuth2 URL: `/auth/wechat`

## Configuration

You can configure several options, which you pass in to the `provider` method via a hash:

* `scope`: Default is "snsapi_userinfo". It can either be *snsapi_base* or *snsapi_userinfo*. When scope is "snsapi_userinfo", after wechat user is authenticated, app can query userinfo using the acquired access_token.

For devise user, you can set up scope in your devise.rb as following.

```ruby
config.omniauth :wechat, ENV["WECHAT_APP_ID"], ENV["WECHAT_APP_SECRET"],
    :authorize_params => {:scope => "snsapi_base"}
```

## Auth Hash

Here's an example of an authentication hash available in the callback by accessing `request.env["omniauth.auth"]`:

```ruby
{
    :provider => "wechat",
    :uid => "123456789",
    :info => {
      nickname:   "Nickname",
      sex:        1,
      province:   "Changning",
      city:       "Shanghai",
      country:    "China",
      headimgurl: "http://image_url",
      unionid:    'unionid'
    },
    :credentials => {
        :token => "token",
        :refresh_token => "another_token",
        :expires_at => 7200,
        :expires => true
    },
    :extra => {
        :raw_info => {
          openid:     "openid"
          nickname:   "Nickname",
          sex:        1,
          province:   "Changning",
          city:       "Shanghai",
          country:    "China",
          headimgurl: "http://image_url",
          unionid:    'unionid'
        }
    }
}
```

## Wechat Qiye OAuth2

Both enterprise strategies (`qiye_web` and `wechat_qiye`) require a successful
WeCom API response (`errcode: 0`) and a nonempty member `userid`. A corporate
access token does not authenticate a user: the callback's authorization code
must also resolve to a member. Invalid codes, API errors, malformed responses,
and nonmember identities fail authentication without invoking the application
callback. TLS certificate verification is enabled by default.

### WeCom web login

```ruby
config.omniauth :qiye_web, ENV['WECOM_CORP_ID'], ENV['WECOM_CORP_SECRET'],
    agentid: ENV['WECOM_AGENT_ID']
```

Start login through OmniAuth's POST request phase with your application's CSRF
protection. Keep `provider_ignores_state` at its default (`false`): the callback
must return the generated state in the same browser session. State is consumed
when checked, so a completed callback cannot be replayed. If valid logins fail
with `csrf_detected`, check the session cookie, callback host, and proxy/HTTPS
configuration instead of disabling state validation.

When upgrading an existing deployment, publish or pin the fixed gem revision,
update the application's lockfile, and restart its processes. A Bundler local
override only changes the developer's checkout. This fix does not invalidate
previously issued application sessions or tokens; revoke those associated with
any confirmed unauthorized login separately. Applications should also reject
blank `auth.uid` values before looking up local accounts and avoid logging the
full authentication hash, which contains credentials.

### Legacy enterprise OAuth2

Wechat Qiey usage and configuration are the same with normal account above.

```ruby
config.omniauth :wechat_qiye, ENV["WECHAT_APP_ID"], ENV["WECHAT_APP_SECRET"],
    :authorize_params => {:scope => "snsapi_base"}
```

Auth hash `request.env["omniauth.auth"]`

```ruby
{
    :provider => "wechat_qiye",
    :uid => "123456789",
    :info => {
      userid: "userid",
      name: "name",
      department: [2],
      gender: "1",
      weixinid: "weixinid",
      avatar: "avatar",
      status: 1,
      extattr: {"foo" => "bar"}
    },
    :credentials => {
        :token => "token",
        :refresh_token => "another_token",
        :expires_at => 7200,
        :expires => true
    },
    :extra => {
        :raw_info => {
          userid: "userid",
          name: "name",
          department: [2],
          gender: "1",
          weixinid: "weixinid",
          avatar: "avatar",
          status: 1,
          extattr: {"foo" => "bar"}}
        }
    }
}
```
