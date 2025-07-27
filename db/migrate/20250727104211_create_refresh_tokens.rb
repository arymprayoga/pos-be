class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens, id: :uuid do |t|
      t.uuid :user_id, null: false
      t.uuid :company_id, null: false
      t.string :token_hash, null: false
      t.string :device_fingerprint
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.uuid :created_by
      t.uuid :updated_by

      t.timestamps
    end

    add_index :refresh_tokens, [ :company_id, :user_id ]
    add_index :refresh_tokens, :token_hash, unique: true
    add_index :refresh_tokens, :expires_at
    add_index :refresh_tokens, :revoked_at
  end
end
