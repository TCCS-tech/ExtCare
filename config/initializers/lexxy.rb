# Use Lexxy's standalone form control with documents.body. Its Rails engine
# requires Action Text, which this app does not use.
lexxy_root = Gem.loaded_specs.fetch("lexxy").full_gem_path
Rails.application.config.assets.paths << File.join(lexxy_root, "app/assets/javascript")
Rails.application.config.assets.paths << File.join(lexxy_root, "app/assets/stylesheets")

# Match Lexxy's Rails integration: its highlight palette uses CSS variables.
Loofah::HTML5::SafeList::ALLOWED_CSS_FUNCTIONS << "var"
