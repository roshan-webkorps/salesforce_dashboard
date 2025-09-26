# app/services/base_salesforce_service.rb
class BaseSalesforceService
  include HTTParty

  def initialize
    @instance_url = nil
    @access_token = nil
    authenticate!
  end

  def fetch_users(since = nil)
    fetch_records_paginated("User", user_fields, since)
  end

  def fetch_accounts(since = nil)
    fetch_records_paginated("Account", account_fields, since)
  end

  def fetch_opportunities(since = nil)
    fetch_records_paginated("Opportunity", opportunity_fields, since)
  end

  def fetch_leads(since = nil)
    fetch_records_paginated("Lead", lead_fields, since)
  end

  def fetch_cases(since = nil)
    fetch_records_paginated("Case", case_fields, since)
  end

  protected

  def get_credentials
    raise NotImplementedError, "Subclasses must implement get_credentials"
  end

  private

  def authenticate!
    creds = get_credentials

    response = self.class.post(
      "https://#{creds[:host]}/services/oauth2/token",
      body: {
        grant_type: "password",
        client_id: creds[:client_id],
        client_secret: creds[:client_secret],
        username: creds[:username],
        password: creds[:password_token]
      }
    )

    if response.success?
      @access_token = response["access_token"]
      @instance_url = response["instance_url"]
      Rails.logger.info "Salesforce authentication successful"
    else
      error_msg = "Salesforce auth failed: #{response.code} #{response.message}"
      Rails.logger.error error_msg
      raise StandardError, error_msg
    end
  end

  def fetch_records_paginated(object_type, fields, since = nil, batch_size = 2000)
    all_records = []
    last_id = nil
    page_count = 0

    loop do
      page_count += 1
      query = build_cursor_query(object_type, fields, since, last_id, batch_size)

      response = execute_query(query)
      return response if response.is_a?(Hash) && response[:error]

      records = response["records"]
      break if records.empty?

      all_records.concat(records)
      last_id = records.last["Id"]

      break if records.count < batch_size
    end

    Rails.logger.info "#{object_type}: #{all_records.count} total records fetched"
    all_records
  end

  def build_cursor_query(object_type, fields, since, last_id, limit)
    where_clauses = []

    if since
      if since <= 7.days.ago
        where_clauses << "CreatedDate >= #{format_datetime(since)}"
      else
        where_clauses << "(CreatedDate >= #{format_datetime(since)} OR LastModifiedDate >= #{format_datetime(since)})"
      end
    end

    where_clauses << "Id > '#{last_id}'" if last_id
    where_clauses << "IsActive = true" if object_type == "User"

    where_clause = where_clauses.any? ? "WHERE #{where_clauses.join(' AND ')}" : ""

    "SELECT #{fields} FROM #{object_type} #{where_clause} ORDER BY Id ASC LIMIT #{limit}"
  end

  def execute_query(soql)
    return { error: "Not authenticated" } unless @access_token

    response = self.class.get(
      "#{@instance_url}/services/data/v41.0/query/",
      query: { q: soql },
      headers: {
        "Authorization" => "Bearer #{@access_token}",
        "Content-Type" => "application/json"
      }
    )

    if response.success?
      response.parsed_response
    else
      error_msg = response["message"] || "HTTP #{response.code}"
      Rails.logger.error "Salesforce query failed: #{error_msg}"
      { error: error_msg }
    end
  end

  def format_datetime(datetime)
    datetime.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def account_fields
    %w[
      Id Name Type Industry AnnualRevenue BillingCountry BillingState
      BillingCity Phone OwnerId CreatedDate LastModifiedDate
      Asset_Panda_Status__c ARR__c MRR__c Records_Bought__c
      Amount_Paid__c Account_Expires__c Valid_Subscription__c
    ].join(", ")
  end

  def opportunity_fields
    %w[
      Id Name AccountId OwnerId StageName Amount CloseDate CreatedDate
      LastModifiedDate IsClosed IsWon Type LeadSource Probability
      ForecastCategory ForecastCategoryName
    ].join(", ")
  end

  def lead_fields
    %w[
      Id FirstName LastName Company Email Phone Status LeadSource
      OwnerId CreatedDate LastModifiedDate IsConverted ConvertedDate Industry
    ].join(", ")
  end

  def case_fields
    %w[
      Id AccountId OwnerId Status Priority Type CreatedDate
      LastModifiedDate ClosedDate Subject
    ].join(", ")
  end

  def user_fields
    %w[
      Id Name Email IsActive UserRole.Name ManagerId Phone
      LastLoginDate CreatedDate
    ].join(", ")
  end
end
