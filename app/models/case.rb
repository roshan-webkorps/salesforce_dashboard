class Case < ApplicationRecord
  validates :salesforce_id, presence: true, uniqueness: { scope: :app_type }
  validates :app_type, presence: true

  # All associations optional
  belongs_to :account, foreign_key: "account_salesforce_id", primary_key: "salesforce_id", optional: true
  belongs_to :owner, class_name: "User", foreign_key: "owner_salesforce_id", primary_key: "salesforce_id", optional: true

  scope :open, -> { where.not(status: [ "Closed", "Solved" ]) }
  scope :closed, -> { where(status: [ "Closed", "Solved" ]) }
  scope :by_app_type, ->(type) { where(app_type: type) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :with_account, -> { joins(:account) }
  scope :with_owner, -> { joins(:owner) }

  def resolution_time_days
    return nil unless closed_date && salesforce_created_date
    (closed_date.to_date - salesforce_created_date.to_date).to_i
  end

  def is_open?
    ![ "Closed", "Solved" ].include?(status)
  end
end
