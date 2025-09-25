# app/services/base_salesforce_service.rb
class BaseSalesforceService
  def initialize(client)
    @client = client
  end

  def fetch_users(since = nil)
    query = build_user_query(since)
    execute_query(query, "User")
  end

  def fetch_accounts(since = nil)
    query = build_account_query(since)
    execute_query(query, "Account")
  end

  def fetch_opportunities(since = nil)
    query = build_opportunity_query(since)
    execute_query(query, "Opportunity")
  end

  def fetch_leads(since = nil)
    query = build_lead_query(since)
    execute_query(query, "Lead")
  end

  def fetch_cases(since = nil)
    query = build_case_query(since)
    execute_query(query, "Case")
  end

  private

  def execute_query(query, object_name)
    Rails.logger.info "Executing #{object_name} query: #{query}"

    all_records = []
    begin
      result = @client.query(query)
      all_records = result.to_a

      # Handle pagination - fixed method name
      while result.next_page
        result = result.next_page
        all_records.concat(result.to_a)
      end

      Rails.logger.info "Fetched #{all_records.count} #{object_name} records"
      all_records
    rescue => e
      Rails.logger.error "Salesforce API error for #{object_name}: #{e.message}"
      { error: e.message }
    end
  end

  def build_user_query(since = nil)
    fields = %w[
      Id Name Email IsActive UserRole.Name
      ManagerId Phone LastLoginDate CreatedDate
    ].join(", ")

    query = "SELECT #{fields} FROM User WHERE IsActive = true"
    query += " AND CreatedDate >= #{format_datetime(since)}" if since
    query += " ORDER BY CreatedDate DESC"
    query
  end

  def build_account_query(since = nil)
    # Removed fields that don't exist: NumberofLocations__c, Segment__c, Retention_Status__c
    fields = %w[
      Id Name Type Industry AnnualRevenue
      BillingCountry BillingState BillingCity Phone
      OwnerId CreatedDate Asset_Panda_Status__c
      ARR__c MRR__c Records_Bought__c Amount_Paid__c
      Account_Expires__c Valid_Subscription__c
    ].join(", ")

    query = "SELECT #{fields} FROM Account"
    query += " WHERE CreatedDate >= #{format_datetime(since)}" if since
    query += " ORDER BY CreatedDate DESC"
    query
  end

  def build_opportunity_query(since = nil)
    # Removed fields that might not exist and kept core fields
    fields = %w[
      Id Name AccountId OwnerId StageName Amount CloseDate
      CreatedDate IsClosed IsWon Type LeadSource
    ].join(", ")

    query = "SELECT #{fields} FROM Opportunity"
    query += " WHERE CreatedDate >= #{format_datetime(since)}" if since
    query += " ORDER BY CreatedDate DESC"
    query
  end

  def build_lead_query(since = nil)
    # Removed custom fields that might not exist
    fields = %w[
      Id FirstName LastName Company Email Phone Status
      LeadSource OwnerId CreatedDate IsConverted
      ConvertedDate Industry
    ].join(", ")

    query = "SELECT #{fields} FROM Lead"
    query += " WHERE CreatedDate >= #{format_datetime(since)}" if since
    query += " ORDER BY CreatedDate DESC"
    query
  end

  def build_case_query(since = nil)
    # Removed custom fields that might not exist
    fields = %w[
      Id AccountId OwnerId Status Priority Type
      CreatedDate ClosedDate Subject
    ].join(", ")

    query = "SELECT #{fields} FROM Case"
    query += " WHERE CreatedDate >= #{format_datetime(since)}" if since
    query += " ORDER BY CreatedDate DESC"
    query
  end

  def format_datetime(datetime)
    return nil unless datetime
    datetime.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
  end
end
