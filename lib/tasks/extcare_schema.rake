# lib/tasks/extcare_schema.rake
Rake::Task["db:create"].enhance do
  ActiveRecord::Base.establish_connection
  conn = ActiveRecord::Base.connection
  conn.create_schema("extcare", if_not_exists: true) unless conn.schema_exists?("extcare")
end

Rake::Task["db:prepare"].enhance do
  ActiveRecord::Base.establish_connection
  conn = ActiveRecord::Base.connection
  conn.create_schema("extcare", if_not_exists: true) unless conn.schema_exists?("extcare")
end

Rake::Task["db:test:prepare"].enhance do
  ActiveRecord::Base.establish_connection
  conn = ActiveRecord::Base.connection
  conn.create_schema("extcare", if_not_exists: true) unless conn.schema_exists?("extcare")
end