class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, id: :uuid do |t|
      t.uuid :company_id, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.integer :role, null: false, default: 0
      t.boolean :active, default: true, null: false
      t.datetime :last_login_at
      t.string :last_login_ip
      t.datetime :deleted_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :users, [ :company_id, :email ], unique: true, where: "deleted_at IS NULL"
    add_index :users, [ :company_id, :role ]
    add_index :users, [ :company_id, :active ]
    add_index :users, :deleted_at
    add_index :users, :last_login_at
  end
end
