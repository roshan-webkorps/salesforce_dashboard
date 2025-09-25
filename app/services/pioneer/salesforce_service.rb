module Pioneer
  class SalesforceService < BaseSalesforceService
    def initialize
      client = Restforce.new(
        api_version: "41.0",
        username: ENV["PIONEER_SALESFORCE_USERNAME"],
        password: ENV["PIONEER_SALESFORCE_PASSWORD_TOKEN"],
        client_id: ENV["PIONEER_SALESFORCE_CLIENT_ID"],
        client_secret: ENV["PIONEER_SALESFORCE_CLIENT_SECRET"],
        host: ENV["PIONEER_SALESFORCE_HOST"] || ENV["SALESFORCE_HOST"]
      )
      super(client)
    end
  end
end
