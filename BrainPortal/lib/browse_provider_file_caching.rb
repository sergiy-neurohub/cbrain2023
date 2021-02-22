
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
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

# A stupid class to provide methods to cache
# the browsing results of a data provider into
class BrowseProviderFileCaching

  Revision_info = CbrainFileRevision[__FILE__] #:nodoc:

  # How long we cache the results of provider_list_all();
  BROWSE_CACHE_EXPIRATION = 60.seconds #:nodoc:
  RACE_CONDITION_DELAY    = nil        # Short delay for a concurrent threads

  # Contacts the +provider+ side with provider_list_all(as_user) and
  # caches the resulting array of FileInfo objects for 60 seconds.
  # Returns that array. If refresh is set to true, it will force the
  # refresh of the array, otherwise any array that was generated less
  # than 60 seconds ago is returned again.
  def self.get_recent_provider_list_all(provider, as_user = current_user, refresh = false) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    if refresh
      save_cache(as_user, provider)
    else
      Rails.cache.fetch(provider_key(as_user, provider), expires_in: BROWSE_CACHE_EXPIRATION, race_condition_ttl: RACE_CONDITION_DELAY) do
        return save_cache(as_user, provider)
      end
    end

  end

  # Saves FileInfo cache
  def self.save_cache(user, provider) #:nodoc:
    # Get info from provider
    fileinfolist = provider.provider_list_all(user)
    # Write a new cached copy
    Rails.cache.write(provider_key(user, provider), fileinfolist, expires_in: BROWSE_CACHE_EXPIRATION)
    # return it
    fileinfolist
  end

  # Clear the cache file.
  def self.clear_cache(user, provider) #:nodoc:
    Rails.cache.delete(provider_key(user, provider))
  end

  private

  def self.provider_key(user, provider)
    "dp_file_list_#{user.try(:id)}_#{provider.id}"
  end

end

