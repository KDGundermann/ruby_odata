require 'spec_helper'

module OData
  describe Service do

    describe "handling of Microsoft Dynamics Nav OData WebService" do

      before(:each) do
        # Required for the build_classes method
        base_uri = "http://test.com/NAV-WEB/OData"

        username = "blabla"
        password = ""
        auth_string = "#{username}:#{password}"
        authorization_header = { authorization: "Basic #{Base64::encode64(auth_string).strip}" }
        etag_header = { etag: "ETAG_WILL_BE_IGNORED" }
        headers = DEFAULT_HEADERS.merge(authorization_header)

        stub_request(:get, "#{base_uri}/$metadata").
          with(:headers => headers).
          to_return(:status => 200, :body => Fixtures.load("/ms_dynamics_nav/edmx_ms_dynamics_nav.xml"), :headers => {})

        stub_request(:get, "#{base_uri}/Customer").
          with(:headers => headers).
          to_return(:status => 200, :body => Fixtures.load("/ms_dynamics_nav/result_customer.xml"), :headers => {})

        stub_request(:get, "#{base_uri}/Customer('10000')").
          with(:headers => headers).
          to_return(:status => 200, :body => Fixtures.load("/ms_dynamics_nav/result_customer.xml"), :headers => etag_header)

        stub_request(:get, "#{base_uri}/Customer(10000)").
          with(:headers => headers).
          to_return(:status => 400, :body => Fixtures.load("/ms_dynamics_nav/result_customer_error.xml"), :headers => {})

        stub_request(:get, "#{base_uri}/SalesOrder(Document_Type='Order',No='AB-1600013')").
          with(:headers => headers).
          to_return(:status => 200, :body => Fixtures.load("/ms_dynamics_nav/result_sales_order.xml"), :headers => etag_header)

        stub_request(:put, "#{base_uri}/Customer('10000')").
          with(:headers => headers).
          to_return{ |request|
            if request.headers.has_key?('If-Match') && request.headers['If-Match'] == "W/\"'28%3BEgAAAAJ7BTEAMAAwADAAMAAAAAAA8%3B791241770%3B'\""
              {:status => 204, :body => ""}
            else
              {:status => 412, :body => Fixtures.load("/ms_dynamics_nav/result_update_error_etag.xml") }
            end
          }

        @service = OData::Service.new base_uri, { :username => username, :password => password, :verify_ssl => false }

      end

      after(:each) do
        remove_classes @service
      end

      context "find Entities with string id" do
        it "should successfully parse null valued string properties" do
          @service.Customer
          results = @service.execute
          results.first.should be_a_kind_of(Customer)
        end

        it "should successfully return a customer by its string id" do
          @service.Customer('10000')
          results = @service.execute
          results.first.should be_a_kind_of(Customer)
          results.first.Name.should eq 'Contoso AG'
        end

        it "should cast to string if a customer is accessed with integer id" do
          @service.Customer(10000)
          results = @service.execute
          results.first.should be_a_kind_of(Customer)
          results.first.Name.should eq 'Contoso AG'
        end

        it "should successfully return a sales_order by its composite string ids" do
          @service.SalesOrder(Document_Type: 'Order', No: 'AB-1600013')
          results = @service.execute
          results.first.should be_a_kind_of(SalesOrder)
          results.first.No.should eq 'AB-1600013'
        end
      end

      context "update a Customer", focus: true do
        subject {
          @service.Customer('10000')
          @service.execute.first
        }

        it "customer has an etag value" do
          expect(subject.__etag).to eq "W/\"'28%3BEgAAAAJ7BTEAMAAwADAAMAAAAAAA8%3B791241770%3B'\""
        end

        it "will raise an error without an etag" do
          subject.__etag = nil
          subject.Address = "@Home"

          expect(subject.__etag).to be_nil
          @service.update_object subject
          lambda {
            @service.save_changes
          }.should raise_error(OData::ServiceError, /client concurrency token/ )
        end

        it "will not raise an error with an etag" do

          subject.Address = "@Home"

          expect(subject.__etag).not_to be_nil
          @service.update_object subject
          lambda {
            @service.save_changes
          }.should_not raise_error
        end

        it "will save_changes" do
          subject.Address = "@Home"
          @service.update_object subject
          expect( @service.save_changes )
        end

      end
    end
  end
end