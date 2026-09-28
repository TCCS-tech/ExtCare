class Document < ApplicationRecord
  BODY_TAGS = %w[a p br strong b em i u s del blockquote pre code h1 h2 h3 h4 h5 h6 ul ol li table thead tbody tfoot tr th td span div hr mark].freeze
  BODY_ATTRIBUTES = %w[href title class style colspan rowspan start data-language].freeze

  normalizes :title, with: ->(title) { title.strip }
  normalizes :body, with: ->(body) {
    Rails::HTML5::SafeListSanitizer.new.sanitize(body, tags: BODY_TAGS, attributes: BODY_ATTRIBUTES)
  }

  validates :title, presence: true
end
