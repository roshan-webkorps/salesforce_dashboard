module Legacy
  class SalesforceService < BaseSalesforceService
    def initialize
      client = Restforce.new(
        api_version: "41.0",
        username: ENV["LEGACY_SALESFORCE_USERNAME"],
        password: ENV["LEGACY_SALESFORCE_PASSWORD_TOKEN"],
        client_id: ENV["LEGACY_SALESFORCE_CLIENT_ID"],
        client_secret: ENV["LEGACY_SALESFORCE_CLIENT_SECRET"],
        host: ENV["LEGACY_SALESFORCE_HOST"] || ENV["SALESFORCE_HOST"]
      )
      super(client)
    end
  end
end
