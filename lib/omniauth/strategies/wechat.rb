require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class Wechat < OmniAuth::Strategies::OAuth2
      option :name, "wechat"

      option :client_options, {
        site:          "https://api.weixin.qq.com",
        authorize_url: "https://open.weixin.qq.com/connect/oauth2/authorize#wechat_redirect",
        token_url:     "/sns/oauth2/access_token",
        token_method:  :get
      }

      option :authorize_params, {scope: "snsapi_userinfo"}

      option :token_params, {parse: :json}

      uid do
        raw_info['openid']
      end

      info do
        {
          nickname:   raw_info['nickname'],
          name: raw_info['name'],
          sex:        raw_info['sex'],
          province:   raw_info['province'],
          city:       raw_info['city'],
          country:    raw_info['country'],
          headimgurl: raw_info['headimgurl'],
          image: raw_info['headimgurl']
        }
      end

      extra do
        {raw_info: raw_info}
      end

      def request_phase
        params = client.auth_code.authorize_params.merge(redirect_uri: callback_url).merge(authorize_params)
        params["appid"] = params.delete("client_id")
        redirect client.authorize_url(params)
      end

      def raw_info
        @uid ||= access_token["openid"]
        @raw_info ||= begin
          access_token.options[:mode] = :query
          if access_token["scope"] == "snsapi_userinfo"
            response = access_token.get("/sns/userinfo", :params => {"openid" => @uid}, parse: :text)
            @raw_info = JSON.parse(response.body.gsub(/[\u0000-\u001f]+/, ''))
          else
            @raw_info = {"openid" => @uid }
            @raw_info.merge!("unionid" => access_token["unionid"]) if access_token["unionid"]
            @raw_info
          end
        end
      end

      protected
      def build_access_token
        params = {
          'appid' => client.id, 
          'secret' => client.secret,
          'code' => request.params['code'],
          'grant_type' => 'authorization_code' 
          }.merge(token_params.to_hash(symbolize_keys: true))
        client.get_token(params, deep_symbolize(options.auth_token_params))
      end

    end
  end
end
