class Opportunity < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :account_salesforce_id, presence: true
  validates :owner_salesforce_id, presence: true
  validates :stage_name, presence: true
  validates :app_type, presence: true

  # Associations
  belongs_to :account, foreign_key: "account_salesforce_id", primary_key: "salesforce_id"
  belongs_to :owner, class_name: "User", foreign_key: "owner_salesforce_id",
             primary_key: "salesforce_id"

  scope :open, -> { where(is_closed: false) }
  scope :closed_won, -> { where(is_closed: true, is_won: true) }
  scope :closed_lost, -> { where(is_closed: true, is_won: false) }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_stage, ->(stage) { where(stage_name: stage) }

  # Calculated fields
  def days_in_stage
    return nil unless salesforce_created_date
    (Date.current - salesforce_created_date.to_date).to_i
  end
end
