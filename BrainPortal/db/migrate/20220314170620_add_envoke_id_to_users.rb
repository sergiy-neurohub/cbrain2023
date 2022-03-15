class AddEnvokeIdToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :envoke_id, :string
  end
end
