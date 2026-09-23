class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_enum :role_enum, [ "Admin", "User" ]

    create_table :users do |t|
      t.text :email, null: false
      t.enum :role, enum_type: :role_enum, null: false, default: "User"
      t.string :password_digest, null: false
      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
