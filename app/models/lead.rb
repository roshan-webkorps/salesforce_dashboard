class Lead < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: { scope: :app_type }
  validates :name, presence: true
  validates :status, presence: true
  validates :app_type, presence: true

  # Optional owner association
  belongs_to :owner, class_name: "User", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", optional: true

  scope :converted, -> { where(is_converted: true) }
  scope :open, -> { where(is_converted: false) }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_lead_source, ->(source) { where(lead_source: source) }
  scope :with_owner, -> { joins(:owner) }

  # Add callback for data quality
  before_save :set_defaults

  def days_since_created
    return nil unless salesforce_created_date
    (Date.current - salesforce_created_date.to_date).to_i
  end

  def conversion_time_days
    return nil unless is_converted? && conversion_date && salesforce_created_date
    (conversion_date.to_date - salesforce_created_date.to_date).to_i
  end

  def is_stale?
    return false if is_converted?
    days_since_created && days_since_created > 30
  end

  private

  def set_defaults
    self.status ||= "Open - Not Contacted"
    self.lead_source ||= "Unknown"
  end
end
