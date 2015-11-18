Omniauth-wechat-oauth2
======================

[![Build Status](https://travis-ci.org/skinnyworm/omniauth-wechat-oauth2.svg)](https://travis-ci.org/skinnyworm/omniauth-wechat-oauth2) [![Gem Version](https://badge.fury.io/rb/omniauth-wechat-oauth2.png)](http://badge.fury.io/rb/omniauth-wechat-oauth2)

Wechat OAuth2 Strategy for OmniAuth 1.0. 

You need to get a wechat API key at: http://mp.weixin.qq.com

Wechat oauth2 specification can be found at: [网页授权获取用户基本信息](http://mp.weixin.qq.com/wiki/17/c0f37d5704f0b64713d5d2c37b468d75.html)
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
      headimgurl: "http://image_url"
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
          headimgurl: "http://image_url"
        }
    }
}
```




