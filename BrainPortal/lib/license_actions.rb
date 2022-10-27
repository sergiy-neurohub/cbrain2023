
#
# NeuroHub Project
#
# Copyright (C) 2022
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# License controller actions to be used by subportal controllers (CBRAIN, NeuroHub)
module LicenseActions

  def show_license #:nodoc:

    @license = params[:license].gsub(/[^\w\/-]+/, "")

    render :show_infolicense if @license&.end_with? "_info" # info license does not require to accept it
  end

  def sign_license(on_agree=:start_page_path, on_disagree='/logout', portalname='CBRAIN') #:nodoc:
    @license = params[:license]

    unless params.has_key?(:agree) # no validation for info pages
      flash[:error] = "#{portalname} cannot be used without signing the End User Licence Agreement."
      redirect_to on_disagree
      return
    end
    num_checkboxes = params[:num_checkboxes].to_i
    if num_checkboxes > 0
      num_checks = params.keys.grep(/\Alicense_check/).size
      if num_checks < num_checkboxes
        flash[:error] = "There was a problem with your submission. Please read the agreement and check all checkboxes."
        redirect_to :action => :show_license, :license => @license
        return
      end
    end
    signed_agreements = current_user.meta[:signed_license_agreements] || []
    signed_agreements << @license
    current_user.meta[:signed_license_agreements] = signed_agreements
    current_user.addlog("Signed license agreement '#{@license}'.")
    redirect_to self.send(on_agree)
  end

end
