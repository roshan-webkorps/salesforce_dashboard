class Account < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :app_type, presence: true

  # Associations
  belongs_to :owner, class_name: "User", foreign_key: "owner_salesforce_id",
             primary_key: "salesforce_id", optional: true
  has_many :opportunities, foreign_key: "account_salesforce_id", primary_key: "salesforce_id"
  has_many :cases, foreign_key: "account_salesforce_id", primary_key: "salesforce_id"

  scope :active, -> { where(status: "Active") }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_owner, ->(owner_id) { where(owner_salesforce_id: owner_id) }

  # Calculated fields
  def total_opportunity_value
    opportunities.sum(:amount)
  end

  def won_opportunity_value
    opportunities.closed_won.sum(:amount)
  end
end
