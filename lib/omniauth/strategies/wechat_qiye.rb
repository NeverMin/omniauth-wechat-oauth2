require "omniauth-oauth2"
require "omniauth/strategies/wecom_validation"

module OmniAuth
  module Strategies
    class WechatQiye < OmniAuth::Strategies::OAuth2
      include WecomValidation

      option :name, "wechat_qiye"

      option :client_options, {
                                :site => "https://qyapi.weixin.qq.com",
                                authorize_url: "https://open.weixin.qq.com/connect/oauth2/authorize#wechat_redirect",
                                token_url:     "/cgi-bin/gettoken",
                                token_method:  :get
                              }

      option :authorize_params, {scope: "snsapi_userinfo"}
      option :token_params, {parse: :json}

      uid do
        raw_info['userid']
      end

      info do
        {
            userid:     raw_info['userid'],
            name:       raw_info['name'],
            department: raw_info['department'],
            gender:     raw_info['gender'],
            weixinid:   raw_info['weixinid'],
            avatar:     raw_info['avatar'],
            status:     raw_info['status'],
            extattr:    raw_info['extattr']
        }
      end

      extra do
        { raw_info: raw_info }
      end

      def request_phase
        params = client.auth_code.authorize_params.merge(redirect_uri: callback_url).merge(authorize_params)
        params["appid"] = params.delete("client_id")
        redirect client.authorize_url(params)
      end

      def raw_info
        @uid ||= begin
          access_token.options[:mode] = :query
          response = access_token.get('/cgi-bin/user/getuserinfo',
                                      :params => {'code' => authorization_code}, parse: :json)
          wecom_userid(wecom_response(response))
        end

        @raw_info ||= begin
          access_token.options[:mode] = :query
          response = access_token.get("/cgi-bin/user/get", :params => {"userid" => @uid}, parse: :json)
          data = wecom_response(response)
          unless wecom_userid(data).casecmp(@uid).zero?
            raise CallbackError.new(:invalid_uid, 'WeCom member profile does not match the authenticated userid')
          end
          data
        end
      end
    end
  end
end
