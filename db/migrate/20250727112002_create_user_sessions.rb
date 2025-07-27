class CreateUserSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_sessions, id: :uuid do |t|
      t.references :company, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :session_token, null: false
      t.string :device_fingerprint, null: false
      t.string :ip_address, null: false
      t.text :user_agent
      t.datetime :last_activity_at
      t.datetime :expired_at
      t.datetime :logged_out_at

      t.timestamps
    end

    add_index :user_sessions, :session_token, unique: true
    add_index :user_sessions, [ :user_id, :device_fingerprint ]
    add_index :user_sessions, :expired_at
    add_index :user_sessions, :logged_out_at
    add_index :user_sessions, :last_activity_at
    add_index :user_sessions, [ :user_id, :expired_at, :logged_out_at ], name: 'index_user_sessions_active'
  end
end
