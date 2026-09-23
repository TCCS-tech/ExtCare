class SetDatabaseTimezone < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      ALTER DATABASE #{connection.quote_table_name(connection.current_database)}
      SET timezone TO 'America/Los_Angeles'
    SQL
  end

  def down
  end
end
