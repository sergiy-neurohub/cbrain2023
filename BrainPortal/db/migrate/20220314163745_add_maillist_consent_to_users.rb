class AddMaillistConsentToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :maillist_consent, :string
  end
end
