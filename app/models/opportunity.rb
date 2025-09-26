class Opportunity < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: { scope: :app_type }
  validates :name, presence: true
  validates :app_type, presence: true
  # Remove required validations for foreign keys

  # ALL ASSOCIATIONS OPTIONAL - store everything, link what we can
  belongs_to :account, foreign_key: "account_salesforce_id", primary_key: "salesforce_id", optional: true
  belongs_to :owner, class_name: "User", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", optional: true

  scope :open, -> { where(is_closed: false) }
  scope :closed_won, -> { where(is_closed: true, is_won: true) }
  scope :closed_lost, -> { where(is_closed: true, is_won: false) }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_stage, ->(stage) { where(stage_name: stage) }
  scope :with_account, -> { joins(:account) }  # For analytics when you need account data
  scope :with_owner, -> { joins(:owner) }      # For analytics when you need owner data

  def days_in_stage
    return nil unless salesforce_created_date
    (Date.current - salesforce_created_date.to_date).to_i
  end
end
