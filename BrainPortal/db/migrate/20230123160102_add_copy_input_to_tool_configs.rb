class AddCopyInputToToolConfigs < ActiveRecord::Migration[5.0]
  def change
    add_column :tool_configs, :copy_input, :boolean, default: false, null: false
  end
end
