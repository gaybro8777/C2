describe StepManager do
  describe "#add_initial_step" do
    it "creates a new step series with the steps" do
      proposal = create(:proposal)
      expect(proposal.steps).to be_empty
      new_step1 = create(:approval)
      new_step2 = create(:approval)
      proposal.add_initial_steps([new_step1, new_step2])

      aggregate_failures "testing steps" do
        expect(proposal.steps.first).to be_a Steps::Serial
        expect(proposal.steps.first).to be_actionable
        expect(proposal.steps.first.child_approvals).to include(new_step1, new_step2)
        expect(proposal.steps.last).to eq new_step2
        expect(new_step1).to be_actionable
      end
    end
  end

  describe "#root_step=" do
    it "sets initial approvers" do
      proposal = create(:proposal)
      approvers = create_list(:user, 3)
      individuals = approvers.map{ |user| build(:approval_step, assignee: user) }

      proposal.root_step = build(:parallel_step, child_approvals: individuals)

      expect(proposal.steps.count).to be 4
      expect(proposal.approvers).to eq approvers
    end

    it "initates parallel" do
      assignees = create_list(:user, 3)
      proposal = create(:proposal)
      individuals = assignees.map { |user| build(:approval_step, assignee: user) }

      proposal.root_step = build(:parallel_step, child_approvals: individuals)

      expect(proposal.approvers.count).to be 3
      expect(proposal.steps.count).to be 4
      expect(proposal.individual_steps.actionable.count).to be 3
      expect(proposal.steps.actionable.count).to be 4
    end

    it "initates linear" do
      assignees = create_list(:user, 3)
      proposal = create(:proposal)
      individuals = assignees.map { |user| build(:approval_step, assignee: user) }

      proposal.root_step = build(:serial_step, child_approvals: individuals)

      expect(proposal.approvers.count).to be 3
      expect(proposal.steps.count).to be 4
      expect(proposal.individual_steps.actionable.count).to be 1
      expect(proposal.steps.actionable.count).to be 2
    end

    it "fixes modified parallel proposal approvals" do
      assignees = create_list(:user, 3)
      proposal = create(:proposal)
      individual = [build(:approval_step, assignee: assignees[0])]
      proposal.root_step = build(:parallel_step, child_approvals: individual)

      expect(proposal.steps.actionable.count).to be 2
      expect(proposal.individual_steps.actionable.count).to be 1

      individuals = assignees.map { |user| build(:approval_step, assignee: user) }
      proposal.root_step = build(:parallel_step, child_approvals: individuals)

      expect(proposal.steps.actionable.count).to be 4
      expect(proposal.individual_steps.actionable.count).to be 3
    end

    it "fixes modified linear proposal approvals" do
      assignees = create_list(:user, 3)
      proposal = create(:proposal)
      individuals = [assignees[0], assignees[1]].map { |user| build(:approval_step, assignee: user) }
      proposal.root_step = build(:serial_step, child_approvals: individuals)

      expect(proposal.steps.actionable.count).to be 2
      expect(proposal.individual_steps.actionable.count).to be 1

      individuals.first.approve!
      individuals[1] = build(:approval_step, assignee: assignees[2])
      proposal.root_step = build(:serial_step, child_approvals: individuals)

      expect(proposal.steps.approved.count).to be 1
      expect(proposal.steps.actionable.count).to be 2
      expect(proposal.individual_steps.actionable.count).to be 1
      expect(proposal.individual_steps.actionable.first.assignee).to eq assignees[2]
    end

    it "does not modify a full approved parallel proposal" do
      assignees = create_list(:user, 2)
      proposal = create(:proposal)
      individuals = assignees.map { |user| build(:approval_step, assignee: user) }
      proposal.root_step = build(:parallel_step, child_approvals: individuals)

      proposal.individual_steps.first.approve!
      proposal.individual_steps.second.approve!

      expect(proposal.steps.actionable).to be_empty
    end

    it "does not modify a full approved linear proposal" do
      assignees = create_list(:user, 2)
      proposal = create(:proposal)
      individuals = assignees.map { |user| build(:approval_step, assignee: user) }
      proposal.root_step = build(:serial_step, child_approvals: individuals)

      proposal.individual_steps.first.approve!
      proposal.individual_steps.second.approve!

      expect(proposal.steps.actionable).to be_empty
    end

    it "deletes approvals" do
      proposal = create(:proposal, :with_parallel_approvers)
      approval1, approval2 = proposal.individual_steps
      proposal.root_step = build(:serial_step, child_approvals: [approval2])

      expect(Step.exists?(approval1.id)).to be false
    end
  end
end
