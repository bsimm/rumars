#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

require_relative 'instruction'
require_relative 'format'

module RuMARS
  # This class represents the core memory of the simulator. The size determines
  # how many instructions can be stored at most. When an instruction is
  # addressed, the address space wraps around so that the memory appears as a
  # circular space.
  class MemoryCore
    attr_reader :warriors, :settings
    attr_accessor :tracer, :io_trace

    include Format

    @size = 8000

    IoOperation = Struct.new(:address, :pid, :operation, :hit)

    # Accessor for size
    class << self
      attr_accessor :size
    end

    def initialize(settings)
      @settings = settings
      MemoryCore.size = @settings[:core_size]
      @instructions = []
      @warriors = []
      @tracer = nil
      @io_trace = nil
      MemoryCore.size.times do |address|
        poke(address, default_instruction(0, address))
      end
    end

    def self.fold(address)
      (MemoryCore.size + address) % MemoryCore.size
    end

    def pid(warrior)
      (pid = @warriors.index(warrior)) ? pid + 1 : nil
    end

    def load_warrior(warrior)
      # Make sure the warrior has a valid program
      return nil unless warrior.program

      return nil unless (base_address = find_base_address(warrior.size))

      @warriors << warrior

      address = base_address
      # The program ID is the index in the loaded warrior list (+1).
      pid = @warriors.length
      warrior.program.instructions.each do |instruction|
        instruction_copy = instruction.deep_copy
        instruction_copy.address = address
        instruction_copy.pid = pid
        poke(address, instruction_copy)

        address = MemoryCore.fold(address + 1)
      end
      warrior.restart(base_address, pid)

      base_address
    end

    def save_warrior(file_name, start_address, end_address)
      begin
        file = File.open(file_name, 'w')

        file.puts(';redcode-94')

        start_address.upto(end_address) do |address|
          instruction = @instructions[address]
          file.puts("#{' ' * 12}#{instruction}")
        end
        file.close
      rescue IOError => e
        puts "Error writing file '#{file_name}': #{e.message}"
        return false
      end

      true
    end

    def save_coredump(file_name)
      begin
        file = File.open(file_name, 'w')

        MemoryCore.size.times do |address|
          instruction = @instructions[address]
          # Only save instructions that contain non-default values
          file.puts("#{aformat(address)}: #{instruction}") unless instruction.pid.zero?
        end
        file.close
      rescue IOError => e
        puts "Error writing file '#{file_name}': #{e.message}"
        return false
      end

      true
    end

    def peek(address, pid = nil)
      raise ArgumentError, "address #{address} out of range" if address.negative? || address >= MemoryCore.size

      trace_io(address, pid, :pc) if pid

      @instructions[address]
    end

    def poke(address, instruction)
      raise ArgumentError, "address #{address} out of range" if address.negative? || address >= MemoryCore.size

      instruction.address = address
      @instructions[address] = instruction
    end

    # This method must be used for all memory reads by an instruction.
    def load_relative(base_address, program_counter, address, pid)
      return default_instruction(pid, address) unless check_limit(:read_limit, 0, address)

      core_address = MemoryCore.fold(base_address + program_counter + address)
      trace_io(core_address, pid, :read)
      instruction = peek(core_address)
      @tracer&.log_load(core_address, instruction.to_s)
      instruction
    end

    # This method must be used for all memory writes by an instruction.
    def store_relative(base_address, program_counter, address, instruction, pid)
      core_address = MemoryCore.fold(base_address + program_counter + address)
      trace_io(core_address, pid, :write)
      instruction.pid = pid
      @tracer&.log_store(core_address, instruction.to_s)
      poke(core_address, instruction)
    end

    def check_limit(limit, src_address, dst_address)
      distance1 = MemoryCore.fold(src_address - dst_address)
      distance2 = MemoryCore.fold(dst_address - src_address)

      [distance1, distance2].min <= @settings[limit]
    end

    def find_base_address(size)
      # The first warrior is always loaded to absolute address 0.
      return 0 if @warriors.empty?

      i = 0
      loop do
        address = rand(MemoryCore.size)

        return address unless too_close_to_other_warriors?(address, address + size)

        if (i += 1) > 1000
          return nil
        end
      end
    end

    def too_close_to_other_warriors?(start_address, end_address)
      # All warriors must fit into the core without wrapping around.
      return true if end_address >= MemoryCore.size

      @warriors.each do |warrior|
        # Ignore warriors that have not been loaded yet
        next unless warrior.base_address

        warrior_zone_start = warrior.base_address - @settings.min_distance
        warrior_zone_end = warrior.base_address + warrior.size + @settings.min_distance

        if (start_address >= warrior_zone_start && start_address <= warrior_zone_end) ||
           (end_address >= warrior_zone_start && end_address <= warrior_zone_end)
          return true
        end
      end

      false
    end

    def trace_io(address, pid, operation)
      return unless @io_trace

      raise ArgumentError, "Unknown PID #{pid}" if @warriors.length.positive? && pid.zero?
      raise ArgumentError, "Unknown operation #{operation}" unless %i[read write pc].include?(operation)

      hit = false
      if operation == :write && @instructions[address]
        old_pid = @instructions[address].pid
        if old_pid.positive? && old_pid != pid
          # One warrior is overwriting an instruction of another warrior. We call
          # this a hit!
          @warriors[pid - 1].hits += 1
          hit = true
        end
      end

      @io_trace.push(IoOperation.new(address, pid, operation, hit))
    end

    def default_instruction(pid, address)
      Instruction.new(pid, 'DAT', 'F', Operand.new('', 0), Operand.new('', 0), address)
    end
  end
end
