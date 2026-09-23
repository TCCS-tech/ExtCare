# Match the schema: timestamps are timestamptz, read and written in Pacific.
ActiveSupport.on_load(:active_record_postgresqladapter) do
  self.datetime_type = :timestamptz
end
