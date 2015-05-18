require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class WechatQiye < OmniAuth::Strategies::OAuth2
      option :name, "wechat_qiye"

      option :client_options, {
                                :site => "https://qyapi.weixin.qq.com",
                                authorize_url: "https://open.weixin.qq.com/connect/oauth2/authorize#wechat_redirect",
                                token_url:     "/cgi-bin/gettoken",
                                token_method:  :get,
                                connection_opts: {
                                    ssl: { verify: false }
                                }
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
        # step 2: get userid via code and access_token
        @code ||= access_token[:code]

        # step 3: get user info via userid
        @uid ||= begin
          access_token.options[:mode] = :query
          response = access_token.get('/cgi-bin/user/getuserinfo', :params => {'code' => @code}, parse: :json)
          response.parsed['UserId']
        end

        @raw_info ||= begin
          access_token.options[:mode] = :query
          response = access_token.get("/cgi-bin/user/get", :params => {"userid" => @uid}, parse: :json)
          response.parsed
        end
      end

      protected
      def build_access_token
        # step 0: wechat respond code
        code = request.params['code']

        # step 1: get access token
        params = {
            'corpid' => client.id,
            'corpsecret' => client.secret,
        }.merge(token_params.to_hash(symbolize_keys: true))
        client.get_token(params, deep_symbolize(options.auth_token_params.merge({code: code})))
      end
    end
  end
end
