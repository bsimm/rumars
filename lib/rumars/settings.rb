#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

module RuMARS
  Settings = Struct.new(:core_size, :max_cycles, :max_processes, :max_length,
                        :min_distance, :read_limit, :write_limit, :rounds,
                        :mode)
end
