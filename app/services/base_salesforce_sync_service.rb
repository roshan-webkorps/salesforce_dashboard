# app/services/base_salesforce_sync_service.rb
class BaseSalesforceSyncService
  def initialize
    @salesforce = get_salesforce_service
  end

  def sync_all_data(since = 1.year.ago)
    Rails.logger.info "Starting #{self.class.name} data sync since #{since}"

    results = {
      users: sync_users(since),
      accounts: sync_accounts(since),
      leads: sync_leads(since),
      cases: sync_cases(since),
      opportunities: sync_opportunities(since)
    }

    Rails.logger.info "#{self.class.name} data sync completed"
    build_summary(results)
  end

  def sync_users(since = 1.year.ago)
    Rails.logger.info "Syncing users..."
    sync_entity("user", @salesforce.fetch_users(since))
  end

  def sync_accounts(since = 1.year.ago)
    Rails.logger.info "Syncing accounts..."
    sync_entity("account", @salesforce.fetch_accounts(since))
  end

  def sync_opportunities(since = 1.year.ago)
    Rails.logger.info "Syncing opportunities..."
    sync_entity("opportunity", @salesforce.fetch_opportunities(since))
  end

  def sync_leads(since = 1.year.ago)
    Rails.logger.info "Syncing leads..."
    sync_entity("lead", @salesforce.fetch_leads(since))
  end

  def sync_cases(since = 1.year.ago)
    Rails.logger.info "Syncing cases..."
    sync_entity("case", @salesforce.fetch_cases(since))
  end

  protected

  def get_salesforce_service
    raise NotImplementedError, "Subclasses must implement get_salesforce_service"
  end

  def get_app_type
    raise NotImplementedError, "Subclasses must implement get_app_type"
  end

  private

  def sync_entity(entity_type, data)
    return data if data.is_a?(Hash) && data[:error]

    created = updated = 0

    data.each do |record_data|
      next unless should_sync_record?(record_data, entity_type)

      record = find_or_build_record(entity_type.classify.constantize, record_data["Id"])
      was_new_record = record.new_record?

      assign_attributes(record, record_data, entity_type)

      if record.save
        was_new_record ? created += 1 : updated += 1
      end
    end

    Rails.logger.info "#{entity_type.pluralize.capitalize}: #{created} created, #{updated} updated"
    { created: created, updated: updated, total: created + updated }
  end

  def should_sync_record?(record_data, entity_type)
    return should_sync_user?(record_data) if entity_type == "user"
    true
  end

  def should_sync_user?(user_data)
    return false unless user_data["IsActive"]

    email = user_data["Email"]
    return false if email&.include?("noreply") || email&.include?("system")

    true
  end

  def find_or_build_record(model_class, salesforce_id)
    model_class.find_or_initialize_by(
      salesforce_id: salesforce_id,
      app_type: get_app_type
    )
  end

  def assign_attributes(record, data, entity_type)
    case entity_type
    when "user" then assign_user_attributes(record, data)
    when "account" then assign_account_attributes(record, data)
    when "opportunity" then assign_opportunity_attributes(record, data)
    when "lead" then assign_lead_attributes(record, data)
    when "case" then assign_case_attributes(record, data)
    end
  end

  def assign_user_attributes(user, data)
    user.assign_attributes(
      name: data["Name"] || "Unknown User",
      email: data["Email"],
      role: extract_user_role(data),
      is_active: data["IsActive"],
      manager_salesforce_id: data["ManagerId"]
    )
  end

  def assign_account_attributes(account, data)
    account.assign_attributes(
      name: data["Name"].presence || "Unknown Account",
      owner_salesforce_id: data["OwnerId"],
      salesforce_created_date: parse_datetime(data["CreatedDate"]),
      arr: parse_decimal(data["ARR__c"]),
      status: data["Asset_Panda_Status__c"],
      industry: data["Industry"],
      segment: nil,
      employee_count: nil
    )
  end

  def assign_opportunity_attributes(opportunity, data)
    opportunity.assign_attributes(
      name: data["Name"].presence || "Unknown Opportunity",
      account_salesforce_id: data["AccountId"],
      owner_salesforce_id: data["OwnerId"],
      stage_name: data["StageName"] || "Unknown",
      amount: parse_decimal(data["Amount"]),
      close_date: parse_date(data["CloseDate"]),
      salesforce_created_date: parse_datetime(data["CreatedDate"]),
      is_closed: data["IsClosed"] || false,
      is_won: data["IsWon"] || false,
      opportunity_type: data["Type"],
      lead_source: data["LeadSource"]
    )
  end

  def assign_lead_attributes(lead, data)
    name = "#{data['FirstName']} #{data['LastName']}".strip.presence || "Unknown Lead"

    lead.assign_attributes(
      name: name,
      company: data["Company"],
      email: data["Email"],
      status: data["Status"] || "Unknown",
      lead_source: data["LeadSource"],
      owner_salesforce_id: data["OwnerId"],
      salesforce_created_date: parse_datetime(data["CreatedDate"]),
      is_converted: data["IsConverted"] || false,
      conversion_date: parse_datetime(data["ConvertedDate"]),
      industry: data["Industry"]
    )
  end

  def assign_case_attributes(case_record, data)
    case_record.assign_attributes(
      account_salesforce_id: data["AccountId"],
      owner_salesforce_id: data["OwnerId"],
      status: data["Status"],
      priority: data["Priority"],
      case_type: data["Type"],
      salesforce_created_date: parse_datetime(data["CreatedDate"]),
      closed_date: parse_datetime(data["ClosedDate"])
    )
  end

  def extract_user_role(user_data)
    role_name = user_data.dig("UserRole", "Name")
    return "Unknown" unless role_name

    case role_name.downcase
    when /account.executive/, /ae/ then "Account Executive"
    when /sdr/, /sales.development/ then "SDR"
    when /manager/, /director/ then "Manager"
    when /support/, /success/ then "Support"
    else role_name
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

  def parse_decimal(decimal_value)
    return nil if decimal_value.blank?
    return decimal_value if decimal_value.is_a?(Numeric)

    decimal_value.to_s.gsub(/[^\d.-]/, "").to_f
  rescue
    nil
  end

  def build_summary(results)
    {
      users: User.where(app_type: get_app_type).count,
      accounts: Account.where(app_type: get_app_type).count,
      opportunities: Opportunity.where(app_type: get_app_type).count,
      leads: Lead.where(app_type: get_app_type).count,
      cases: Case.where(app_type: get_app_type).count,
      sync_results: results
    }
  end
end
