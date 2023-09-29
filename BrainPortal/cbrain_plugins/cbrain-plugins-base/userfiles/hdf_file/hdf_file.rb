
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# This model represents a single HDF file
# HDF is used to store a large amount of scientific data in files and folders
# and resemble a file system image with POSIX-like resource paths syntax
class HDFImage < FilesystemImage

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'File Info', :partial  => :info, :if => :is_viewable?

  def self.file_name_pattern #:nodoc:
    /\.h(df)?[4-5]|\.hdf\z|\.he[25]\z\z/i
  end

  def self.pretty_type #:nodoc:
    "HDF File"
  end  

  def is_viewable? #:nodoc:
    if ! self.has_hdf_support?
      return [ "The local portal doesn't support inspecting HDF files." ]
    elsif ! self.is_locally_synced?
      return [ "hdf image file not yet synchronized" ]
    else
      true
    end
  end

  def has_hdf_support? #:nodoc:
    self.class.has_hdf_support?
  end

  # Detects if the system has the hdf command.
  # Caches the result in the class so it won't need to
  # be detected again after the first time, for the life
  # of the current process.
  def self.has_hdf_support? #:nodoc:
    return @_has_hdf_support if ! @_has_hdf_support.nil?
    out = IO.popen("bash -c 'type -p h5stat'","r") { |f| f.read }
    @_has_hdf_support = out.present?
  end

end

