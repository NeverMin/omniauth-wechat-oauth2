module OmniAuth
  module Strategies
    # WeCom returns API failures as HTTP 200 responses. A corporate access token
    # alone does not authenticate the user presenting the callback code.
    module WecomValidation
      protected

      def secure_compare(left, right)
        return false unless left.is_a?(String) && right.is_a?(String)

        super
      end

      def authorization_code
        code = request.params['code']
        unless code.is_a?(String) && !code.strip.empty?
          raise OAuth2::CallbackError.new(:invalid_code, 'Missing or invalid WeCom authorization code')
        end

        code
      end

      def build_access_token
        authorization_code
        params = {
          'corpid' => client.id,
          'corpsecret' => client.secret
        }.merge(token_params.to_hash(symbolize_keys: true))

        client.get_token(params, deep_symbolize(options.auth_token_params)).tap do |token|
          unless token && token.token.is_a?(String) && !token.token.strip.empty?
            raise OAuth2::CallbackError.new(:invalid_token, 'Missing WeCom access token')
          end
          validate_wecom_response(token.params)
        end
      end

      def wecom_response(response)
        validate_wecom_response(response.parsed)
      end

      def validate_wecom_response(data)
        unless data.is_a?(Hash) && data['errcode'] == 0
          raise OAuth2::CallbackError.new(:invalid_response, 'WeCom API did not return a successful response')
        end

        data
      end

      def wecom_userid(data)
        # Support both the current API and the legacy UserId response. OAuth2's
        # SnakyHash also accepts the original spelling of normalized keys.
        userid = data['userid'] || data['UserId']
        unless userid.is_a?(String) && !userid.strip.empty?
          raise OAuth2::CallbackError.new(:invalid_uid, 'WeCom did not return a member userid')
        end

        userid
      end
    end
  end
end
