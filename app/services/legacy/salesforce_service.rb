# app/services/legacy/salesforce_service.rb
module Legacy
  class SalesforceService < BaseSalesforceService
    protected

    def get_credentials
      {
        host: ENV["LEGACY_SALESFORCE_HOST"],
        client_id: ENV["LEGACY_SALESFORCE_CLIENT_ID"],
        client_secret: ENV["LEGACY_SALESFORCE_CLIENT_SECRET"],
        username: ENV["LEGACY_SALESFORCE_USERNAME"],
        password_token: ENV["LEGACY_SALESFORCE_PASSWORD_TOKEN"]
      }
    end
  end
end
