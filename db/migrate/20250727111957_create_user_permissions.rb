class CreateUserPermissions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_permissions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :permission, null: false, foreign_key: true, type: :uuid
      t.uuid :granted_by
      t.datetime :granted_at, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :user_permissions, [ :user_id, :permission_id ], unique: true
    add_index :user_permissions, :granted_by
  end
end
