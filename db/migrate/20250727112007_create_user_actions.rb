class CreateUserActions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_actions, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :user, null: true, foreign_key: true, type: :uuid # Allow null for failed login attempts
      t.references :user_session, null: true, foreign_key: true, type: :uuid # Allow null for sessionless actions
      t.string :action, null: false
      t.string :resource_type, null: false
      t.string :resource_id
      t.json :details, default: {}
      t.string :ip_address, null: false
      t.text :user_agent
      t.boolean :success, default: true, null: false

      t.timestamps
    end

    add_index :user_actions, [ :user_id, :created_at ]
    add_index :user_actions, [ :user_session_id, :created_at ]
    add_index :user_actions, :action
    add_index :user_actions, [ :resource_type, :resource_id ]
    add_index :user_actions, :success
    add_index :user_actions, [ :action, :success ]
  end
end
