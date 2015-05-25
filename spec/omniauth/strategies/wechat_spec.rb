require 'spec_helper'

describe OmniAuth::Strategies::Wechat do
  let(:request) { double('Request', :params => {}, :cookies => {}, :env => {}, :scheme=>"http", :url=>"localhost") }
  let(:app) { ->{[200, {}, ["Hello."]]}}
  let(:client){OAuth2::Client.new('appid', 'secret')}

  subject do
    OmniAuth::Strategies::Wechat.new(app, 'appid', 'secret', @options || {}).tap do |strategy|
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
      expect(subject.client.site).to eq('https://api.weixin.qq.com')
    end

    specify 'has authorize_url' do
      expect(subject.client.options[:authorize_url]).to eq('https://open.weixin.qq.com/connect/qrconnect?#wechat_redirect')
    end

    specify 'has token_url' do
      expect(subject.client.options[:token_url]).to eq('/sns/oauth2/access_token')
    end
  end

  describe "#authorize_params" do
    specify "default scope is snsapi_login" do
      expect(subject.authorize_params[:scope]).to eq("snsapi_login")
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
        expect(params["appid"]).to eq(['appid'])
        expect(params["redirect_uri"]).to eq([callback_url])
        expect(params["response_type"]).to eq(['code'])
        expect(params["scope"]).to eq(['snsapi_login'])
        expect(params["state"]).to eq([subject.session['omniauth.state']])
      end

      subject.request_phase
    end
  end

  describe "#build_access_token" do
    specify "request includes 'appid', 'secret', 'code', 'grant_type' and will parse response as json"do 
      subject.stub(:client => client, :request=>double("request", params:{"code"=>"server_code"}))
      client.should_receive(:get_token).with({
        "appid" => "appid",
        "secret" => "secret",
        "code" => "server_code",
        "grant_type" => "authorization_code",
        :parse => :json
      },{})
      subject.send(:build_access_token)
    end
  end

  describe "#raw_info" do
    let(:access_token) { OAuth2::AccessToken.from_hash(client, {}) }
    before { subject.stub(:access_token => access_token) }

    context "when scope is snsapi_base" do
      let(:access_token) { OAuth2::AccessToken.from_hash(client, {
        "openid"=>"openid", 
        "scope"=>"snsapi_base", 
        "access_token"=>"access_token"
      })}

      specify "only have openid" do
        expect(subject.uid).to eq("openid")
        expect(subject.raw_info).to eq("openid" => "openid")
      end
    end

    context "when scope is snsapi_userinfo" do
      let(:access_token) { OAuth2::AccessToken.from_hash(client, {
        "openid"=>"openid", 
        "scope"=>"snsapi_userinfo", 
        "access_token"=>"access_token"
      })}

      specify "will query for user info" do
        response_body = %({"openid": "OPENID","nickname": "\x14\x1fNICKNAME", "sex": "1", "province": "PROVINCE", "city": "CITY", "country": "COUNTRY", "headimgurl": "header_image_url", "privilege": ["PRIVILEGE1", "PRIVILEGE2"]})

        response_hash = {
          "openid" => "OPENID",
          "nickname" => "NICKNAME",
          "sex" => "1",
          "province" => "PROVINCE",
          "city" => "CITY",
          "country" => "COUNTRY",
          "headimgurl" => "header_image_url", 
          "privilege" => ["PRIVILEGE1", "PRIVILEGE2"]
        }

        client.should_receive(:request).with do |verb, path, opts|
          expect(verb).to eq(:get)
          expect(path).to eq("/sns/userinfo")
          expect(opts[:params]).to eq("openid"=> "openid", "access_token"=> "access_token")
          expect(opts[:parse]).to eq(:text)
        end.and_return(double("response", body: response_body))

        expect(subject.raw_info).to eq(response_hash)
      end

    end

  end



end