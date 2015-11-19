require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class WechatQr < Wechat
      option :client_options, {
        site:          "https://api.weixin.qq.com",
        authorize_url: "https://open.weixin.qq.com/connect/qrconnect#wechat_redirect",
        token_url:     "/sns/oauth2/access_token",
        token_method:  :get
      }

      option :authorize_params, {scope: "snsapi_login"}

    end
  end
end
