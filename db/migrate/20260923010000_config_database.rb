class ConfigDatabase < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # schema extcare must already exist 
    execute "ALTER DATABASE #{connection.quote_table_name(connection.current_database)} SET search_path TO extcare, public"
    execute "ALTER DATABASE #{connection.quote_table_name(connection.current_database)} SET timezone TO 'America/Los_Angeles'"
  end

end
