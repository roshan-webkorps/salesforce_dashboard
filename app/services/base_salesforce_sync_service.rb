# app/services/base_salesforce_sync_service.rb
class BaseSalesforceSyncService
  def initialize
    @salesforce = get_salesforce_service
  end

  def sync_all_data(since = 1.year.ago)
    Rails.logger.info "Starting #{self.class.name} data sync since #{since}..."

    results = {
      users: sync_users(since),
      accounts: sync_accounts(since),
      opportunities: sync_opportunities(since),
      leads: sync_leads(since),
      cases: sync_cases(since)
    }

    Rails.logger.info "#{self.class.name} data sync completed"

    {
      users: User.where(app_type: get_app_type).count,
      accounts: Account.where(app_type: get_app_type).count,
      opportunities: Opportunity.where(app_type: get_app_type).count,
      leads: Lead.where(app_type: get_app_type).count,
      cases: Case.where(app_type: get_app_type).count,
      errors: results.values.select { |r| r.is_a?(Hash) && r[:error] }
    }
  end

  def sync_users(since = 1.year.ago)
    Rails.logger.info "Syncing users since #{since}..."

    users_data = @salesforce.fetch_users(since)
    return users_data if users_data.is_a?(Hash) && users_data[:error]

    count = 0
    users_data.each do |user_data|
      # Only sync active sales/support users, skip system users
      next unless should_sync_user?(user_data)

      user = upsert_user(user_data)
      count += 1 if user.persisted?
    end

    Rails.logger.info "Synced #{count} users"
    { count: count }
  end

  def sync_accounts(since = 1.year.ago)
    Rails.logger.info "Syncing accounts since #{since}..."

    accounts_data = @salesforce.fetch_accounts(since)
    return accounts_data if accounts_data.is_a?(Hash) && accounts_data[:error]

    count = 0
    accounts_data.each do |account_data|
      account = upsert_account(account_data)
      count += 1 if account.persisted?
    end

    Rails.logger.info "Synced #{count} accounts"
    { count: count }
  end

  def sync_opportunities(since = 1.year.ago)
    Rails.logger.info "Syncing opportunities since #{since}..."

    opportunities_data = @salesforce.fetch_opportunities(since)
    return opportunities_data if opportunities_data.is_a?(Hash) && opportunities_data[:error]

    count = 0
    opportunities_data.each do |opp_data|
      opportunity = upsert_opportunity(opp_data)
      count += 1 if opportunity.persisted?
    end

    Rails.logger.info "Synced #{count} opportunities"
    { count: count }
  end

  def sync_leads(since = 1.year.ago)
    Rails.logger.info "Syncing leads since #{since}..."

    leads_data = @salesforce.fetch_leads(since)
    return leads_data if leads_data.is_a?(Hash) && leads_data[:error]

    count = 0
    leads_data.each do |lead_data|
      lead = upsert_lead(lead_data)
      count += 1 if lead.persisted?
    end

    Rails.logger.info "Synced #{count} leads"
    { count: count }
  end

  def sync_cases(since = 1.year.ago)
    Rails.logger.info "Syncing cases since #{since}..."

    cases_data = @salesforce.fetch_cases(since)
    return cases_data if cases_data.is_a?(Hash) && cases_data[:error]

    count = 0
    cases_data.each do |case_data|
      case_record = upsert_case(case_data)
      count += 1 if case_record.persisted?
    end

    Rails.logger.info "Synced #{count} cases"
    { count: count }
  end

  protected

  # Abstract methods to be implemented by subclasses
  def get_salesforce_service
    raise NotImplementedError, "Subclasses must implement get_salesforce_service"
  end

  def get_app_type
    raise NotImplementedError, "Subclasses must implement get_app_type"
  end

  private

  def should_sync_user?(user_data)
    # Only sync active users and filter out system/integration users
    return false unless user_data["IsActive"]

    # Skip system users (you can customize this logic)
    email = user_data["Email"]
    return false if email.nil? || email.include?("noreply") || email.include?("system")

    true
  end

  def upsert_user(user_data)
    user = User.find_or_initialize_by(
      salesforce_id: user_data["Id"],
      app_type: get_app_type
    )

    user.assign_attributes(
      name: user_data["Name"],
      email: user_data["Email"],
      role: extract_user_role(user_data),
      is_active: user_data["IsActive"],
      manager_salesforce_id: user_data["ManagerId"]
    )

    user.save
    user
  end

  def upsert_account(account_data)
    account = Account.find_or_initialize_by(
      salesforce_id: account_data["Id"],
      app_type: get_app_type
    )

    account.assign_attributes(
      name: account_data["Name"],
      owner_salesforce_id: account_data["OwnerId"],
      salesforce_created_date: parse_datetime(account_data["CreatedDate"]),
      arr: account_data["ARR__c"],
      status: account_data["Asset_Panda_Status__c"],
      industry: account_data["Industry"],
      segment: nil, # Field doesn't exist, set to nil
      employee_count: nil # Field doesn't exist, set to nil
    )

    account.save
    account
  end

  def upsert_opportunity(opp_data)
    opportunity = Opportunity.find_or_initialize_by(
      salesforce_id: opp_data["Id"],
      app_type: get_app_type
    )

    opportunity.assign_attributes(
      name: opp_data["Name"],
      account_salesforce_id: opp_data["AccountId"],
      owner_salesforce_id: opp_data["OwnerId"],
      stage_name: opp_data["StageName"],
      amount: opp_data["Amount"],
      close_date: parse_date(opp_data["CloseDate"]),
      salesforce_created_date: parse_datetime(opp_data["CreatedDate"]),
      is_closed: opp_data["IsClosed"],
      is_won: opp_data["IsWon"],
      opportunity_type: opp_data["Type"],
      lead_source: opp_data["LeadSource"]
    )

    opportunity.save
    opportunity
  end

  def upsert_lead(lead_data)
    lead = Lead.find_or_initialize_by(
      salesforce_id: lead_data["Id"],
      app_type: get_app_type
    )

    name = "#{lead_data['FirstName']} #{lead_data['LastName']}".strip

    lead.assign_attributes(
      name: name,
      company: lead_data["Company"],
      email: lead_data["Email"],
      status: lead_data["Status"],
      lead_source: lead_data["LeadSource"],
      owner_salesforce_id: lead_data["OwnerId"],
      salesforce_created_date: parse_datetime(lead_data["CreatedDate"]),
      is_converted: lead_data["IsConverted"],
      conversion_date: parse_datetime(lead_data["ConvertedDate"]),
      industry: lead_data["Industry"]
    )

    lead.save
    lead
  end

  def upsert_case(case_data)
    case_record = Case.find_or_initialize_by(
      salesforce_id: case_data["Id"],
      app_type: get_app_type
    )

    case_record.assign_attributes(
      account_salesforce_id: case_data["AccountId"],
      owner_salesforce_id: case_data["OwnerId"],
      status: case_data["Status"],
      priority: case_data["Priority"],
      case_type: case_data["Type"],
      salesforce_created_date: parse_datetime(case_data["CreatedDate"]),
      closed_date: parse_datetime(case_data["ClosedDate"])
    )

    case_record.save
    case_record
  end

  def extract_user_role(user_data)
    role_name = user_data.dig("UserRole", "Name")
    return "Unknown" unless role_name

    # Map Salesforce roles to simplified roles
    case role_name.downcase
    when /account.executive/, /ae/
      "Account Executive"
    when /sdr/, /sales.development/
      "SDR"
    when /manager/, /director/
      "Manager"
    when /support/, /success/
      "Support"
    else
      role_name
    end
  end

  def parse_datetime(datetime_string)
    return nil if datetime_string.blank?
    Time.parse(datetime_string)
  rescue
    nil
  end

  def parse_date(date_string)
    return nil if date_string.blank?
    Date.parse(date_string)
  rescue
    nil
  end
end
