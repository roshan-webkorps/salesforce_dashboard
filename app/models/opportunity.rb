class Opportunity < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: { scope: :app_type }
  validates :name, presence: true
  validates :app_type, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :probability, numericality: { in: 0..100 }, allow_nil: true

  # ALL ASSOCIATIONS OPTIONAL - store everything, link what we can
  belongs_to :account, foreign_key: "account_salesforce_id", primary_key: "salesforce_id", optional: true
  belongs_to :owner, class_name: "User", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", optional: true

  scope :open, -> { where(is_closed: false) }
  scope :closed_won, -> { where(is_closed: true, is_won: true) }
  scope :closed_lost, -> { where(is_closed: true, is_won: false) }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_stage, ->(stage) { where(stage_name: stage) }
  scope :by_lead_source, ->(source) { where(lead_source: source) }
  scope :with_account, -> { joins(:account) }
  scope :with_owner, -> { joins(:owner) }

  # Add callbacks for data consistency
  before_save :set_defaults, :calculate_expected_revenue

  def days_in_stage
    return nil unless salesforce_created_date
    (Date.current - salesforce_created_date.to_date).to_i
  end

  def is_stale?
    return false unless salesforce_created_date
    days_in_stage > 90
  end

  private

  def set_defaults
    self.stage_name ||= "Prospecting"
    self.opportunity_type ||= "New Business"
    self.lead_source ||= "Unknown"
    self.close_date ||= (salesforce_created_date || Date.current) + 90.days
  end

  def calculate_expected_revenue
    if amount.present? && probability.present?
      self.expected_revenue = amount * (probability / 100.0)
    elsif expected_revenue.blank?
      self.expected_revenue = amount || 0
    end
  end
end
