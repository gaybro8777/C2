class ApprovalGroupsController < ApplicationController
  # before_filter :authenticate_user!

  def index
    @groups = ApprovalGroup.all
  end

  def show
    @approval_group = ApprovalGroup.find(params[:id])
  end

  def new
    @approval_group = ApprovalGroup.new
  end

  def create
    p_hash = params[:approval_group]
    @approval_group = ApprovalGroup.create!(name: p_hash[:name])
    @requester = User.find_or_create_by(email_address: p_hash[:requester])
    @approver1 = User.find_or_create_by(email_address: p_hash[:approver1])
    @approver2 = User.find_or_create_by(email_address: p_hash[:approver2])
    UserRole.create!(user_id: @approver1.id, approval_group_id: @approval_group.id, role: 'approver')
    UserRole.create!(user_id: @approver2.id, approval_group_id: @approval_group.id, role: 'approver')
    UserRole.create!(user_id: @requester.id, approval_group_id: @approval_group.id, role: 'requester')
    flash[:success] = "Group created successfully"
    redirect_to @approval_group
  end

  def search
    @groups = []
    user = User.find_by_email_address(params[:email])
    unless user.nil?
      roles = UserRole.where("user_id = ? AND role='requester'", user.id ).select(:approval_group_id).distinct.map(&:approval_group_id)
      @groups = ApprovalGroup.where(id: roles )
    end

    render :index
  end

  private
    def approval_group_params
      params.require(:approval_group).permit(:name, :requester, :@approver1, :@approver2)
    end

end