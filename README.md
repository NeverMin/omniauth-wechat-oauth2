mniauth-wechat-oauth2
======================

Wechat OAuth2 Strategy for OmniAuth 1.0. 

You need to get a wechat API key at: http://mp.weixin.qq.com

Wechat oauth2 specification can be found at: http://mp.weixin.qq.com/wiki/index.php?title=%E7%BD%91%E9%A1%B5%E6%8E%88%E6%9D%83%E8%8E%B7%E5%8F%96%E7%94%A8%E6%88%B7%E5%9F%BA%E6%9C%AC%E4%BF%A1%E6%81%AF

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

* `scope`: Default is "snsapi_userinfo". It can either be *snsapi_base* or *snsapi_userinfo*. When scope is "snsapi_userinfo", after wechat user is authenticated, app can query userinfo using the acuired access_token.

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
        :expires_at => 1354920555,
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




