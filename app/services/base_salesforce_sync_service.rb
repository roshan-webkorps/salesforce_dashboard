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

    created = updated = errors = 0
    error_details = []

    data.each do |record_data|
      next unless should_sync_record?(record_data, entity_type)

      begin
        record = find_or_build_record(entity_type.classify.constantize, record_data["Id"])
        was_new_record = record.new_record?

        assign_attributes(record, record_data, entity_type)

        if record.valid?
          record.save!
          was_new_record ? created += 1 : updated += 1
        else
          errors += 1
          error_details << "#{entity_type} #{record_data['Id']}: #{record.errors.full_messages.join(', ')}"
          Rails.logger.warn "Validation failed for #{entity_type} #{record_data['Id']}: #{record.errors.full_messages}"
        end
      rescue => e
        errors += 1
        error_details << "#{entity_type} #{record_data['Id']}: #{e.message}"
        Rails.logger.error "Error syncing #{entity_type} #{record_data['Id']}: #{e.message}"
      end
    end

    Rails.logger.info "#{entity_type.pluralize.capitalize}: #{created} created, #{updated} updated, #{errors} errors"
    Rails.logger.warn "Error details: #{error_details.join('; ')}" if errors > 0

    { created: created, updated: updated, errors: errors, total: created + updated }
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
      annual_revenue: parse_decimal(data["AnnualRevenue"]), # Use standard SF field
      mrr: parse_decimal(data["MRR__c"]),
      amount_paid: parse_decimal(data["Amount_Paid__c"]),
      status: data["Asset_Panda_Status__c"] || data["Type"], # Fallback to Type
      industry: data["Industry"],
      segment: determine_account_segment(data), # New helper method
      employee_count: data["NumberOfEmployees"] # Standard SF field
    )
  end

  def assign_opportunity_attributes(opportunity, data)
    amount = parse_decimal(data["Amount"])
    probability = parse_decimal(data["Probability"])

    expected_revenue = if amount && probability
      amount * (probability / 100.0)
    else
      amount || 0
    end

    opportunity.assign_attributes(
      name: data["Name"].presence || "Unknown Opportunity",
      account_salesforce_id: data["AccountId"],
      owner_salesforce_id: data["OwnerId"],
      stage_name: data["StageName"] || "Prospecting",
      amount: amount,
      probability: probability,
      expected_revenue: expected_revenue,
      forecast_category: data["ForecastCategory"] || data["ForecastCategoryName"],
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
      status: data["Status"] || "New", # Better default
      priority: data["Priority"] || "Medium", # Better default
      case_type: data["Type"] || "Question", # Better default
      salesforce_created_date: parse_datetime(data["CreatedDate"]),
      closed_date: parse_datetime(data["ClosedDate"])
    )
  end

  def extract_user_role(user_data)
    # Enhanced role extraction with better fallbacks
    role_sources = [
      user_data["Title"],
      user_data.dig("UserRole", "Name"),
      user_data.dig("Profile", "Name"),
      user_data["Department"],
      user_data["Division"]
    ]

    role_name = role_sources.find(&:present?)

    return "Unknown" unless role_name

    # Clean and standardize role names
    cleaned_role = role_name.strip.humanize.titleize

    # Map common variations to standard roles
    role_mapping = {
      /account.executive|ae/i => "Account Executive",
      /sales.development|sdr|bdr/i => "Sales Development Representative",
      /customer.success|cs/i => "Customer Success Manager",
      /sales.manager|sales.director/i => "Sales Manager",
      /marketing/i => "Marketing",
      /support|customer.support/i => "Customer Support",
      /engineer|developer/i => "Engineer"
    }

    role_mapping.each do |pattern, standard_role|
      return standard_role if role_name.match?(pattern)
    end

    cleaned_role
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

  def determine_account_segment(data)
    employee_count = data["NumberOfEmployees"].to_i
    annual_revenue = parse_decimal(data["AnnualRevenue"]) || 0

    return "Enterprise" if employee_count > 1000 || annual_revenue > 10_000_000
    return "Mid-Market" if employee_count > 100 || annual_revenue > 1_000_000
    return "SMB" if employee_count > 10 || annual_revenue > 100_000
    "Startup"
  end

  def calculate_default_close_date(data)
    created_date = parse_date(data["CreatedDate"])
    return Date.current + 90.days unless created_date

    created_date + 90.days
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
