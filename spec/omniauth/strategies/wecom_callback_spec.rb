require 'spec_helper'
require 'logger'
require 'stringio'

[OmniAuth::Strategies::QiyeWeb, OmniAuth::Strategies::WechatQiye].each do |strategy_class|
  RSpec.describe strategy_class, 'callback authentication' do
    let(:name) { described_class.default_options[:name] }
    let(:web_login) { name == 'qiye_web' }
    let(:identity_path) { web_login ? '/cgi-bin/auth/getuserinfo' : '/cgi-bin/user/getuserinfo' }
    let(:identity_response) { { 'errcode' => 0, 'userid' => 'employee' } }
    let(:profile_response) { { 'errcode' => 0, 'userid' => 'employee', 'name' => 'Employee' } }
    let(:token_response) { { 'errcode' => 0, 'access_token' => 'corporate-token', 'expires_in' => 7200 } }
    let(:api_calls) { [] }
    let(:session) { { 'omniauth.state' => 'session-state' } }
    let(:params) { { 'state' => 'session-state', 'code' => 'authorization-code' } }
    let(:options) { { agentid: 123 } }
    let(:app) { ->(env) { env['downstream.called'] = true; [200, {}, ['authenticated']] } }
    let(:strategy) { described_class.new(app, 'corp-id', 'corp-secret', options) }
    let(:client) do
      strategy.client.tap do |oauth_client|
        oauth_client.connection = Faraday.new(oauth_client.site) do |builder|
          builder.adapter :test do |stub|
            stub.get('/cgi-bin/gettoken') do |env|
              api_calls << env
              [200, { 'Content-Type' => 'application/json' }, token_response.to_json]
            end
            stub.get(identity_path) do |env|
              api_calls << env
              [200, { 'Content-Type' => 'application/json' }, identity_response.to_json]
            end
            stub.get('/cgi-bin/user/get') do |env|
              api_calls << env
              [200, { 'Content-Type' => 'application/json' }, profile_response.to_json]
            end
          end
        end
      end
    end

    around do |example|
      previous = [OmniAuth.config.on_failure, OmniAuth.config.test_mode, OmniAuth.config.logger,
                  OmniAuth.config.request_validation_phase, Faraday.default_adapter]
      OmniAuth.config.on_failure = ->(_env) { [401, {}, ['authentication failed']] }
      OmniAuth.config.test_mode = false
      OmniAuth.config.logger = Logger.new(StringIO.new)
      OmniAuth.config.request_validation_phase = ->(_env) {}
      # Unexpected provider requests must fail locally, never use the network.
      Faraday.default_adapter = :test
      example.run
    ensure
      OmniAuth.config.on_failure, OmniAuth.config.test_mode, OmniAuth.config.logger,
        OmniAuth.config.request_validation_phase, Faraday.default_adapter = previous
    end

    before do
      configured_client = client
      allow(strategy).to receive(:client).and_return(configured_client)
    end

    def callback(method = 'GET')
      env = Rack::MockRequest.env_for("/auth/#{name}/callback", method: method, params: params)
      env['rack.session'] = session
      response = strategy.call!(env)
      [response, env]
    end

    def expect_rejection(error, method = 'GET')
      response, env = callback(method)
      expect(response.first).to eq(401)
      expect(env['omniauth.error.type']).to eq(error)
      expect(env['omniauth.auth']).to be_nil
      expect(env['downstream.called']).to be_nil
    end

    it 'generates a fresh state bound to the browser session' do
      env = Rack::MockRequest.env_for("/auth/#{name}", method: 'POST', params: { state: 'attacker-state' })
      env['rack.session'] = session
      response = strategy.call!(env)
      query = Rack::Utils.parse_query(URI(response[1]['location'] || response[1]['Location']).query)

      expect(response.first).to eq(302)
      expect(query['state']).to eq(session['omniauth.state'])
      expect(query['state']).to match(/\A[0-9a-f]{48}\z/)
      expect(query['state']).not_to eq('session-state')
      expect(query['state']).not_to eq('attacker-state')
      expect(query['appid']).to eq('corp-id')
    end

    %w[GET POST].each do |method|
      it "rejects the reported forged #{method} callback without a prior session" do
        session.clear
        params.merge!('code' => 'forged-code', 'state' => 'forged-state')
        expect_rejection(:csrf_detected, method)
        expect(api_calls).to be_empty
      end

      it "authenticates a valid #{method} callback and consumes its state" do
        response, env = callback(method)
        expect(response.first).to eq(200)
        expect(env['omniauth.auth'].uid).to eq('employee')
        expect(env['downstream.called']).to eq(true)
        expect(session).not_to have_key('omniauth.state')
        identity_request = api_calls.find { |call| call.url.path == identity_path }
        expect(Rack::Utils.parse_query(identity_request.url.query)).to include(
          'code' => 'authorization-code', 'access_token' => 'corporate-token'
        )
      end
    end

    [nil, '', 'wrong-state', ['session-state'], { 'value' => 'session-state' }].each do |state|
      it "rejects invalid request state #{state.inspect} before calling WeCom" do
        params['state'] = state
        expect_rejection(:csrf_detected)
        expect(api_calls).to be_empty
      end
    end

    [nil, '', 'different-session-state'].each do |state|
      it "rejects missing or mismatched session state #{state.inspect}" do
        session['omniauth.state'] = state
        expect_rejection(:csrf_detected)
        expect(api_calls).to be_empty
      end
    end

    [nil, '', '  ', ['code'], { 'value' => 'code' }].each do |code|
      it "rejects an absent or malformed authorization code #{code.inspect}" do
        params['code'] = code
        expect_rejection(:invalid_credentials)
        expect(api_calls).to be_empty
      end
    end

    it 'rejects provider denial before exchanging credentials' do
      params['error'] = 'access_denied'
      expect_rejection(:access_denied)
      expect(api_calls).to be_empty
    end

    it 'rejects callback replay without another API call' do
      expect(callback.first.first).to eq(200)
      api_calls.clear
      expect_rejection(:csrf_detected)
      expect(api_calls).to be_empty
    end

    [nil, '', '  ', 123, false, [], {}].each do |userid|
      context "with an invalid userid #{userid.inspect}" do
        let(:identity_response) { { 'errcode' => 0, 'userid' => userid } }

        it 'never passes an authentication hash to the application' do
          expect_rejection(:invalid_credentials)
          expect(api_calls.map { |call| call.url.path }).not_to include('/cgi-bin/user/get')
        end
      end
    end

    [
      { 'errcode' => 40029, 'errmsg' => 'invalid code' },
      { 'errcode' => 40029, 'userid' => 'employee' },
      { 'errcode' => 0, 'openid' => 'external-user' },
      { 'userid' => 'employee' },
      nil, [], 'invalid response'
    ].each do |body|
      context "with an unsuccessful identity response #{body.inspect}" do
        let(:identity_response) { body }

        it 'fails authentication' do
          expect_rejection(:invalid_credentials)
        end
      end
    end

    context 'when state validation is explicitly disabled' do
      let(:options) { { agentid: 123, provider_ignores_state: true } }
      let(:identity_response) { { 'errcode' => 40029, 'errmsg' => 'invalid code' } }

      it 'still refuses an invalid code' do
        session.clear
        expect_rejection(:invalid_credentials)
      end
    end

    context 'when obtaining a corporate token fails' do
      let(:token_response) { { 'errcode' => 40013, 'errmsg' => 'invalid corpid' } }

      it 'fails before looking up an identity' do
        expect_rejection(:invalid_credentials)
        expect(api_calls.map { |call| call.url.path }).to eq(['/cgi-bin/gettoken'])
      end
    end

    context 'when a token accompanies an API error' do
      let(:token_response) { { 'errcode' => 40013, 'access_token' => 'corporate-token' } }

      it 'rejects the response even though it contains a token' do
        expect_rejection(:invalid_credentials)
        expect(api_calls.map { |call| call.url.path }).to eq(['/cgi-bin/gettoken'])
      end
    end

    context 'with the legacy UserId spelling in the identity response' do
      let(:identity_response) { { 'errcode' => 0, 'UserId' => 'employee' } }

      it 'accepts the verified member identity after OAuth2 key normalization' do
        response, env = callback
        expect(response.first).to eq(200)
        expect(env['omniauth.auth'].uid).to eq('employee')
      end
    end

    it 'verifies TLS certificates by default' do
      connection = described_class.new(app, 'corp-id', 'corp-secret', options).client.connection
      expect(connection.ssl.verify?).to eq(true)
      expect(strategy.options.client_options.dig(:connection_opts, :ssl, :verify)).not_to eq(false)
    end

    unless strategy_class == OmniAuth::Strategies::QiyeWeb
      context 'when the member profile response fails' do
        let(:profile_response) { { 'errcode' => 40003, 'userid' => 'employee' } }

        it('rejects the callback') { expect_rejection(:invalid_credentials) }
      end

      context 'when the member profile belongs to another user' do
        let(:profile_response) { { 'errcode' => 0, 'userid' => 'another-employee' } }

        it('rejects the callback') { expect_rejection(:invalid_credentials) }
      end
    end
  end
end
