class StepBelongsToAssignee < ActiveRecord::Migration
  def up
    rename_column :steps, :user_id, :assignee_id
    add_column :steps, :assignee_type, :string

    execute <<-SQL
      UPDATE steps SET assignee_type = 'User'
    SQL
  end

  def down
    rename_column :steps, :assignee_id, :user_id
    remove_column :steps, :assignee_type
  end
end
