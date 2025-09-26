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
  scope :with_owner, -> { joins(:owner) }  # For analytics when you need owner data

  def total_opportunity_value
    opportunities.sum(:amount) || 0
  end

  def won_opportunity_value
    opportunities.where(is_closed: true, is_won: true).sum(:amount) || 0
  end
end
