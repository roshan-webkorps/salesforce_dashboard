class User < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :app_type, presence: true

  # Associations
  has_many :owned_accounts, -> { where("owner_salesforce_id = users.salesforce_id") },
           class_name: "Account", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id"
  has_many :owned_opportunities, -> { where("owner_salesforce_id = users.salesforce_id") },
           class_name: "Opportunity", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id"
  has_many :owned_leads, -> { where("owner_salesforce_id = users.salesforce_id") },
           class_name: "Lead", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id"
  has_many :owned_cases, -> { where("owner_salesforce_id = users.salesforce_id") },
           class_name: "Case", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id"

  # Manager relationship
  belongs_to :manager, class_name: "User", foreign_key: "manager_salesforce_id",
             primary_key: "salesforce_id", optional: true
  has_many :direct_reports, class_name: "User", foreign_key: "manager_salesforce_id",
           primary_key: "salesforce_id"

  scope :active, -> { where(is_active: true) }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_role, ->(role) { where(role: role) }
end
