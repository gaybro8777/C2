describe Steps::Individual do
  describe "#completed_by" do
    it "identifies completed_by" do
      approval = create(:approval)
      delegate = create(:user)
      approval.completer = delegate
      approval.save!
      approval_self = create(:approval)

      expect(approval.completed_by).to eq delegate
      expect(approval_self.completed_by).to eq approval_self.assignee
    end
  end

  describe "#restart!" do
    it "expires the API token" do
      approval = create(:approval, status: "actionable")
      token = approval.create_api_token!
      expect(token.expired?).to eq(false)
      approval.restart!
      expect(token.expired?).to eq(true)
    end

    it "handles a missing API token" do
      approval = create(:approval, status: "actionable")
      expect {
        approval.restart!
      }.to_not raise_error
    end
  end
end
