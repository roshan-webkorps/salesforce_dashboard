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
  scope :with_owner, -> { joins(:owner) }

  def days_since_created
    return nil unless salesforce_created_date
    (Date.current - salesforce_created_date.to_date).to_i
  end

  def conversion_time_days
    return nil unless is_converted? && conversion_date && salesforce_created_date
    (conversion_date.to_date - salesforce_created_date.to_date).to_i
  end
end
