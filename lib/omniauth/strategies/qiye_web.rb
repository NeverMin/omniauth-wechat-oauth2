require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class QiyeWeb < OmniAuth::Strategies::OAuth2
      option :name, "qiye_web"

      option :client_options, {
                                site: "https://qyapi.weixin.qq.com",
                                authorize_url: "https://login.work.weixin.qq.com/wwlogin/sso/login",
                                token_url: "/cgi-bin/gettoken",
                                token_method: :get,
                                connection_opts: {
                                  ssl: { verify: false }
                                }
                              }

      # Allow passing these via strategy options or per-request params
      option :authorize_options, [:agentid, :state, :login_type, :lang, :href]

      option :token_params, { parse: :json }

      # Required option for WeCom web login
      option :agentid, nil

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
        # Build WeCom web login URL per docs
        # https://developer.work.weixin.qq.com/document/path/98152#2-构造企业微信登录链接
        ap = authorize_params.dup

        raise ArgumentError, 'agentid is required for QiyeWeb strategy' if options.agentid.zero?

        params = {
          'login_type' => ap['login_type'] || 'CorpApp',
          'appid' => client.id,
          'agentid' => options.agentid,
          'redirect_uri' => callback_url,
          'state' => ap['state']
        }

        redirect client.authorize_url(params)
      end

      def raw_info
        # step 2: get userid via code and access_token
        @code ||= access_token[:code]

        # step 3: get user info via userid
        @uid ||= begin
          access_token.options[:mode] = :query
          response = access_token.get('/cgi-bin/user/getuserinfo', params: { 'code' => @code }, parse: :json)
          response.parsed['UserId']
        end

        @raw_info ||= begin
          access_token.options[:mode] = :query
          response = access_token.get('/cgi-bin/user/get', params: { 'userid' => @uid }, parse: :json)
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
          'corpsecret' => client.secret
        }.merge(token_params.to_hash(symbolize_keys: true))

        client.get_token(params, deep_symbolize(options.auth_token_params.merge({ code: code })))
      end
    end
  end
end


