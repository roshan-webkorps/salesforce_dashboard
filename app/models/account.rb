class Account < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: { scope: :app_type }
  validates :name, presence: true
  validates :app_type, presence: true

  # ALL ASSOCIATIONS OPTIONAL - for maximum data retention
  belongs_to :owner, class_name: "User", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", optional: true
  has_many :opportunities, foreign_key: "account_salesforce_id", primary_key: "salesforce_id"
  has_many :cases, foreign_key: "account_salesforce_id", primary_key: "salesforce_id"

  scope :active, -> { where(status: "Active") }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_owner, ->(owner_id) { where(owner_salesforce_id: owner_id) }
  scope :with_owner, -> { joins(:owner) }
  scope :by_industry, ->(industry) { where(industry: industry) }
  scope :by_segment, ->(segment) { where(segment: segment) }

  # Add callback to set defaults for better data quality
  before_save :set_defaults

  def total_opportunity_value
    opportunities.sum(:amount) || 0
  end

  def won_opportunity_value
    opportunities.where(is_closed: true, is_won: true).sum(:amount) || 0
  end

  private

  def set_defaults
    self.status ||= "Active"
    self.industry ||= "Unknown"
    self.segment ||= determine_segment
  end

  def determine_segment
    return "Enterprise" if employee_count.to_i > 1000 || annual_revenue.to_f > 10_000_000
    return "Mid-Market" if employee_count.to_i > 100 || annual_revenue.to_f > 1_000_000
    return "SMB" if employee_count.to_i > 10 || annual_revenue.to_f > 100_000
    "Startup"
  end
end
