# @todo Rename
class CartsController < ApplicationController
  before_filter :authenticate_user!
  before_filter ->{authorize self.cart.proposal}, only: [:show]
  rescue_from Pundit::NotAuthorizedError, with: :auth_errors
  CLOSED_CART_LIMIT = 10

  def show
    @cart = self.cart.decorate
    @proposal = self.cart.proposal
    @show_comments = true
  end

  def index
    @proposals = Proposal.where(requester: current_user).order('created_at DESC')
  end

  def archive
    @closed_proposals_full_list = Proposal.where(requester: current_user).closed.order('created_at DESC')
  end

  protected
  def cart
    @cached_cart ||= Cart.find params[:id]
  end

  def auth_errors(exception)
    redirect_to carts_path, :alert => "You are not allowed to see that cart"
  end
end
