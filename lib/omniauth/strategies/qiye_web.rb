require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class QiyeWeb < OmniAuth::Strategies::OAuth2
      option :name, 'qiye_web'

      option :client_options, { site: 'https://qyapi.weixin.qq.com',
                                authorize_url: 'https://login.work.weixin.qq.com/wwlogin/sso/login',
                                token_url: '/cgi-bin/gettoken',
                                token_method: :get,
                                connection_opts: {
                                  ssl: { verify: false }
                                } }

      # Allow passing these via strategy options or per-request params
      option :authorize_options, %i[agentid state login_type]

      option :token_params, { parse: :json }

      # Required option for WeCom web login
      option :agentid, nil

      uid do
        u = @uid || raw_info
        Rails.logger.info("[OmniAuth::QiyeWeb] uid=#{u.inspect}") if defined?(Rails) && Rails.respond_to?(:logger)
        u
      end

      info do
        info_hash = { userid: uid }
        Rails.logger.info("[OmniAuth::QiyeWeb] info=#{info_hash.inspect}") if defined?(Rails) && Rails.respond_to?(:logger)
        info_hash
      end

      extra do
        { raw_info: nil }
      end

      def callback_phase
        begin
          params_for_log = request.params.dup
          params_for_log['code'] = '[FILTERED]' if params_for_log['code']
          Rails.logger.info("[OmniAuth::QiyeWeb] callback_phase params=#{params_for_log.inspect} session_state=#{session['omniauth.state']} provider_ignores_state=#{options.provider_ignores_state}") if defined?(Rails) && Rails.respond_to?(:logger)
        rescue StandardError => e
          Rails.logger.info("[OmniAuth::QiyeWeb] callback_phase prelog error=#{e.class}: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
        end
        super
      rescue StandardError => e
        Rails.logger.info("[OmniAuth::QiyeWeb] callback_phase error=#{e.class}: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
        raise
      end

      def request_phase
        # Build WeCom web login URL per docs
        # https://developer.work.weixin.qq.com/document/path/98152#2-构造企业微信登录链接
        ap = authorize_params.dup

        raise ArgumentError, 'agentid is required for QiyeWeb strategy' if options.agentid.to_i <= 0

        params = {
          'login_type' => ap['login_type'] || 'CorpApp',
          'appid' => client.id,
          'agentid' => options.agentid,
          'redirect_uri' => callback_url,
          'state' => ap['state']
        }

        url = client.authorize_url(params)
        Rails.logger.info("[OmniAuth::QiyeWeb] request_phase redirect_to=#{url} params=#{params.inspect}") if defined?(Rails) && Rails.respond_to?(:logger)
        redirect url
      end

      def raw_info
        # step 2: get userid via code and access_token
        @code ||= request.params['code']

        Rails.logger.info("[OmniAuth::QiyeWeb] raw_info start code_present=#{!@code.to_s.empty?}") if defined?(Rails) && Rails.respond_to?(:logger)

        # step 3: get user info via userid
        @uid ||= begin
          access_token.options[:mode] = :query
          response = access_token.get('/cgi-bin/auth/getuserinfo', params: { 'code' => @code }, parse: :json)
          Rails.logger.info("[OmniAuth::QiyeWeb] getuserinfo status=#{response.status} body_keys=#{response.parsed.is_a?(Hash) ? response.parsed.keys : response.parsed.class}") if defined?(Rails) && Rails.respond_to?(:logger)
          # Support both key variants returned by different endpoints
          response.parsed['userid'] || response.parsed['UserId']
        end
      rescue ::OAuth2::Error => e
        Rails.logger.info("[OmniAuth::QiyeWeb] raw_info oauth2_error status=#{e.response&.status} body=#{e.response&.body}") if defined?(Rails) && Rails.respond_to?(:logger)
        raise
      rescue StandardError => e
        Rails.logger.info("[OmniAuth::QiyeWeb] raw_info error=#{e.class}: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
        raise
      end

      protected

      def build_access_token
        # step 1: get access token
        params = {
          'corpid' => client.id,
          'corpsecret' => client.secret
        }.merge(token_params.to_hash(symbolize_keys: true))

        # Fetch access_token via gettoken without using the OAuth code
        Rails.logger.info("[OmniAuth::QiyeWeb] build_access_token token_url=#{client.token_url} token_method=#{client.options[:token_method]} params_keys=#{params.keys}") if defined?(Rails) && Rails.respond_to?(:logger)
        token = client.get_token(params, deep_symbolize(options.auth_token_params))
        Rails.logger.info("[OmniAuth::QiyeWeb] build_access_token success token_present=#{!token.token.to_s.empty?} expires_in=#{token.expires_in}") if defined?(Rails) && Rails.respond_to?(:logger)
        token
      rescue ::OAuth2::Error => e
        Rails.logger.info("[OmniAuth::QiyeWeb] build_access_token oauth2_error status=#{e.response&.status} body=#{e.response&.body}") if defined?(Rails) && Rails.respond_to?(:logger)
        raise
      rescue StandardError => e
        Rails.logger.info("[OmniAuth::QiyeWeb] build_access_token error=#{e.class}: #{e.message}") if defined?(Rails) && Rails.respond_to?(:logger)
        raise
      end
    end
  end
end


