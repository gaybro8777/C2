describe Ncr::ApprovalManager do
  describe '#setup_approvals_and_observers' do
    let (:ba61_tier_one) { Ncr::Mailboxes.ba61_tier1_budget }
    let (:ba61_tier_two) { Ncr::Mailboxes.ba61_tier2_budget }

    it "creates approvers when not an emergency" do
      wo = create(:ncr_work_order, expense_type: 'BA61')
      manager = Ncr::ApprovalManager.new(wo)
      manager.setup_approvals_and_observers
      expect(wo.observations.length).to eq(0)
      expect(wo.approvers).to eq([
        wo.approving_official,
        ba61_tier_one,
        ba61_tier_two
      ])
      wo.reload
      expect(wo.approved?).to eq(false)
    end

    it "reuses existing approvals" do
      wo = create(:ncr_work_order, expense_type: 'BA61')
      manager = Ncr::ApprovalManager.new(wo)
      manager.setup_approvals_and_observers
      first_approval = wo.individual_steps.first

      wo.reload.setup_approvals_and_observers
      expect(wo.individual_steps.first).to eq(first_approval)
    end

    it "creates observers when in an emergency" do
      wo = create(:ncr_work_order, expense_type: 'BA61', emergency: true)
      manager = Ncr::ApprovalManager.new(wo)
      manager.setup_approvals_and_observers
      expect(wo.observers).to match_array([
        wo.approving_official,
        ba61_tier_one,
        ba61_tier_two
      ].uniq)
      expect(wo.steps.length).to eq(0)
      wo.clear_association_cache
      expect(wo.approved?).to eq(true)
    end

    it "accounts for approver transitions when nothing's approved" do
      email = "ao@example.com"
      approving_official = create(:user, email_address: email)
      organization = create(:whsc_organization)
      ba80_budget = Ncr::Mailboxes.ba80_budget
      wo = create(
        :ncr_work_order,
        approving_official: approving_official,
        expense_type: "BA61",
      )
      manager = Ncr::ApprovalManager.new(wo)
      manager.setup_approvals_and_observers
      expect(wo.approvers).to eq [
        approving_official,
        ba61_tier_one,
        ba61_tier_two
      ]
      wo.update(ncr_organization: organization)
      manager.setup_approvals_and_observers
      expect(wo.reload.approvers).to eq [
        approving_official,
        ba61_tier_two
      ]

      approving_official_2 = create(:user, email_address: "ao2@example.com")
      wo.update(approving_official: approving_official_2)
      manager.setup_approvals_and_observers
      expect(wo.reload.approvers).to eq [
        approving_official_2,
        ba61_tier_two
      ]

      wo.update(approving_official: approving_official)
      wo.update(expense_type: "BA80")
      manager.setup_approvals_and_observers
      expect(wo.reload.approvers).to eq [
        approving_official,
        ba80_budget
      ]
    end

    it "unsets the approval status" do
      ba80_budget = Ncr::Mailboxes.ba80_budget
      wo = create(:ba80_ncr_work_order)
      manager = Ncr::ApprovalManager.new(wo)
      manager.setup_approvals_and_observers
      expect(wo.approvers).to eq [
        wo.approving_official,
        ba80_budget
      ]

      wo.individual_steps.first.approve!
      wo.individual_steps.second.approve!
      expect(wo.reload.approved?).to be true

      wo.update(expense_type: 'BA61')
      manager.setup_approvals_and_observers
      expect(wo.reload.pending?).to be true
    end

    it "does not re-add observers on emergencies" do
      wo = create(:ncr_work_order, expense_type: 'BA61', emergency: true)
      manager = Ncr::ApprovalManager.new(wo)
      manager.setup_approvals_and_observers

      expect(wo.steps).to be_empty
      expect(wo.observers.count).to be 3

      manager.setup_approvals_and_observers
      wo.reload
      expect(wo.steps).to be_empty
      expect(wo.observers.count).to be 3
    end

    it "handles the delegate then update scenario" do
      wo = create(:ba80_ncr_work_order)
      manager = Ncr::ApprovalManager.new(wo)
      manager.setup_approvals_and_observers
      delegate = create(:user)
      wo.approvers.second.add_delegate(delegate)
      wo.individual_steps.second.update(user: delegate)

      wo.individual_steps.first.approve!
      wo.individual_steps.second.approve!

      manager.setup_approvals_and_observers
      wo.reload
      expect(wo.approved?).to be true
      expect(wo.approvers.second).to eq delegate
    end
  end

  describe '#system_approvers' do
    context "for a BA61 request" do
      let (:ba61_tier_one) { Ncr::Mailboxes.ba61_tier1_budget }
      let (:ba61_tier_two) { Ncr::Mailboxes.ba61_tier2_budget }

      it "skips the Tier 1 budget approver for WHSC" do
        ncr_organization =  create(:whsc_organization)
        work_order = create(
          :ncr_work_order,
          expense_type: "BA61",
          ncr_organization: ncr_organization
        )
        manager = Ncr::ApprovalManager.new(work_order)
        expect(manager.system_approvers).to eq([
          ba61_tier_two
        ])
      end

      it "includes the Tier 1 budget approver for an unknown organization" do
        work_order = create(:ncr_work_order, expense_type: "BA61")
        manager = Ncr::ApprovalManager.new(work_order)
        expect(manager.system_approvers).to eq([
          ba61_tier_one,
          ba61_tier_two
        ])
      end
    end

    context "for a BA80 request" do
      it "uses the general budget email" do
        ba80_budget = Ncr::Mailboxes.ba80_budget
        work_order = create(:ba80_ncr_work_order)
        manager = Ncr::ApprovalManager.new(work_order)
        expect(manager.system_approvers).to eq([ba80_budget])
      end

      it "uses the OOL budget email for their org code" do
        budget = Ncr::Mailboxes.ool_ba80_budget
        ool_organization = create(:ool_organization)
        work_order = create(:ba80_ncr_work_order, ncr_organization: ool_organization)

        manager = Ncr::ApprovalManager.new(work_order)
        expect(manager.system_approvers).to eq([budget])
      end
    end
  end
end
