# frozen_string_literal: true

class Email < ApplicationRecord
  self.primary_key = :address

  has_one :user, foreign_key: "id"
  has_one :staff, foreign_key: "id"

  validates :address, length: 3..255,
                      format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i },
                      uniqueness: { case_sensitive: false }

  # ToDo: write Kafka as job
end
