require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class QiyeWeb < OmniAuth::Strategies::OAuth2
      option :name, "qiye_web"

      option :client_options, {
                                site: "https://qyapi.weixin.qq.com",
                                authorize_url: "https://open.work.weixin.qq.com/wwopen/sso/qrConnect",
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
        # Build WeCom web login URL per docs: qrConnect requires appid (corp id), agentid, redirect_uri, state, etc.
        ap = authorize_params.dup
        ap['agentid'] ||= options.agentid
        ap['login_type'] ||= 'CorpApp'

        raise ArgumentError, 'agentid is required for QiyeWeb strategy' if ap['agentid'].to_s.strip.empty?

        params = {
          'appid' => client.id,
          'agentid' => ap['agentid'],
          'redirect_uri' => callback_url
        }
        params['state'] = ap['state'] if ap['state']
        params['login_type'] = ap['login_type'] if ap['login_type']
        params['lang'] = ap['lang'] if ap['lang']
        params['href'] = ap['href'] if ap['href']

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


