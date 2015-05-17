require 'spec_helper'

describe OmniAuth::Strategies::WechatQiye do
  let(:request) { double('Request', :params => {}, :cookies => {}, :env => {}, :scheme=>"http", :url=>"localhost") }
  let(:app) { ->{[200, {}, ["Hello."]]}}
  let(:client){OAuth2::Client.new('corpid', 'corpsecret')}

  subject do
    OmniAuth::Strategies::WechatQiye.new(app, 'corpid', 'corpsecret', @options || {}).tap do |strategy|
      allow(strategy).to receive(:request) {
        request
      }
    end
  end

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.test_mode = false
  end

  describe '#client_options' do
    specify 'has site' do
      expect(subject.client.site).to eq('https://qyapi.weixin.qq.com')
    end

    specify 'has authorize_url' do
      expect(subject.client.options[:authorize_url]).to eq('https://open.weixin.qq.com/connect/oauth2/authorize#wechat_redirect')
    end

    specify 'has token_url' do
      expect(subject.client.options[:token_url]).to eq('/cgi-bin/gettoken')
    end
  end

  describe "#authorize_params" do
    specify "default scope is snsapi_userinfo" do
      expect(subject.authorize_params[:scope]).to eq("snsapi_userinfo")
    end
  end

  describe "#token_params" do
    specify "token response should be parsed as json" do
      expect(subject.token_params[:parse]).to eq(:json)
    end
  end

  describe 'state' do
    specify 'should set state params for request as a way to verify CSRF' do
      expect(subject.authorize_params['state']).not_to be_nil
      expect(subject.authorize_params['state']).to eq(subject.session['omniauth.state'])
    end
  end

  describe "#request_phase" do
    specify "redirect uri includes 'appid', 'redirect_uri', 'response_type', 'scope', 'state' and 'wechat_redirect' fragment " do
      callback_url = "http://exammple.com/callback"

      subject.stub(:callback_url=>callback_url)
      subject.should_receive(:redirect).with do |redirect_url|
        uri = URI.parse(redirect_url)
        expect(uri.fragment).to eq("wechat_redirect")
        params = CGI::parse(uri.query)
        expect(params["appid"]).to eq(['corpid'])
        expect(params["redirect_uri"]).to eq([callback_url])
        expect(params["response_type"]).to eq(['code'])
        expect(params["scope"]).to eq(['snsapi_userinfo'])
        expect(params["state"]).to eq([subject.session['omniauth.state']])
      end

      subject.request_phase
    end
  end

  describe "#build_access_token" do
    specify "request includes 'corpid', 'corpsecret' and will parse response as json"do
      subject.stub(:client => client, :request=>double("request", params:{ "code" => "server_code"}))
      client.should_receive(:get_token).with({
        "corpid" => "corpid",
        "corpsecret" => "corpsecret",
        :parse => :json
      },{:code => "server_code"})
      subject.send(:build_access_token)
    end
  end

  describe "#raw_info" do
    let(:access_token) { OAuth2::AccessToken.from_hash(client, {
      "expires_in"=>"expires_in",
      "access_token"=>"access_token",
      :code => "server_code"
    })}
    before { subject.stub(:access_token => access_token) }

    specify "will query for user info" do
      response_hash = {
        "userid" => "USERID",
        "name" => "NAME",
        "department" => [2],
        "gender" => "1",
        "weixinid" => "WXID",
        "avatar" => "AVATAR",
        "status" => "STATUS",
        "extattr" => {"foo" => "bar"}
      }

      userid_response = double("response", body: {"UserId" => 'USERID'}.to_json)
      userid_response.stub(:parsed).and_return({"UserId" => 'USERID'})

      userinfo_params = {params: {"code"=> "server_code", "access_token"=> "access_token"}, parse: :json}
      client.should_receive(:request).with(:get, "/cgi-bin/user/getuserinfo", userinfo_params)
                                     .and_return(userid_response)

      userinfo_response = double("response", body: response_hash.to_json)
      (userinfo_response).stub(:parsed).and_return(response_hash)

      get_params = {params: { "userid"=> "USERID", "access_token"=> "access_token" }, parse: :json}
      client.should_receive(:request).with(:get, "/cgi-bin/user/get", get_params)
                                     .and_return(userinfo_response)

      expect(subject.uid).to eq("USERID")
      expect(subject.raw_info).to eq(response_hash)
      expect(subject.extra).to eq(raw_info: subject.raw_info)
    end

  end

end
