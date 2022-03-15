class AddMaillistConsentToSignups < ActiveRecord::Migration[5.0]
  def change
    add_column :signups, :maillist_consent, :string
  end
end
