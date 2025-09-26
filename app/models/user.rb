class User < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: { scope: :app_type }
  validates :name, presence: true
  validates :app_type, presence: true

  # All associations - for analytics queries
  has_many :owned_accounts, foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", class_name: "Account"
  has_many :owned_opportunities, foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", class_name: "Opportunity"
  has_many :owned_leads, foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", class_name: "Lead"
  has_many :owned_cases, foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", class_name: "Case"

  # Manager relationship
  belongs_to :manager, class_name: "User", foreign_key: "manager_salesforce_id", primary_key: "salesforce_id", optional: true
  has_many :direct_reports, class_name: "User", foreign_key: "manager_salesforce_id", primary_key: "salesforce_id"

  scope :active, -> { where(is_active: true) }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_role, ->(role) { where(role: role) }
end
