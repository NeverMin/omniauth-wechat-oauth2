require "omniauth-oauth2"
require "omniauth/strategies/wecom_validation"

module OmniAuth
  module Strategies
    class QiyeWeb < OmniAuth::Strategies::OAuth2
      include WecomValidation

      option :name, 'qiye_web'

      option :client_options, { site: 'https://qyapi.weixin.qq.com',
                                authorize_url: 'https://login.work.weixin.qq.com/wwlogin/sso/login',
                                token_url: '/cgi-bin/gettoken',
                                token_method: :get }

      option :authorize_options, %i[agentid state login_type]
      option :token_params, { parse: :json }
      option :agentid, nil

      uid do
        raw_info
      end

      info do
        { userid: uid }
      end

      extra do
        { raw_info: nil }
      end

      # Inherit OAuth2#callback_phase so state, provider errors, and failures are
      # checked before an authentication hash can reach the application.
      def request_phase
        raise ArgumentError, 'agentid is required for QiyeWeb strategy' if options.agentid.to_i <= 0

        ap = authorize_params
        params = {
          'login_type' => ap[:login_type] || 'CorpApp',
          'appid' => client.id,
          'agentid' => options.agentid,
          'redirect_uri' => callback_url,
          'state' => ap[:state]
        }

        redirect client.authorize_url(params)
      end

      def raw_info
        @uid ||= begin
          access_token.options[:mode] = :query
          response = access_token.get('/cgi-bin/auth/getuserinfo',
                                      params: { 'code' => authorization_code }, parse: :json)
          wecom_userid(wecom_response(response))
        end
      end
    end
  end
end
