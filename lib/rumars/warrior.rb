#
# Copyright (c) Chris Schlaeger <cs@taskjuggler.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# frozen_string_literal: true

require_relative 'parser'

module RuMARS
  # This class handles a MARS program, called a warrior. Inside of MARS
  # programs fight against each other by trying to destroy the other
  # programs.
  class Warrior
    attr_reader :task_queue, :base_address, :name, :program, :pid
    attr_accessor :max_tasks, :file_name, :hits, :kills, :wins

    def initialize(name)
      @task_queue = []
      @max_tasks = 800
      @name = name
      @file_name = nil
      @program = nil
      @timestamp = nil
      @base_address = nil
      @pid = nil
      reset_scores
    end

    def reset_scores
      @hits = 0
      @kills = 0
      @wins = 0
    end

    def parse(redcode, settings, logger)
      begin
        @program = Parser.new(settings, logger).preprocess_and_parse(redcode)

        if @program.size.zero?
          @program = nil
          logger.puts "No valid redcode found in file #{@file_name}"
          return false
        end
      rescue Parser::ParseError => e
        logger.puts e
        @program = nil
        return false
      end

      @name = @program.name unless @program&.name.empty?

      true
    end

    def parse_file(file_name, settings, logger)
      @file_name = file_name

      begin
        redcode = File.read(file_name)
      rescue Errno::ENOENT, IOError
        logger.puts "Cannot open file #{file_name}"
        return false
      end
      @timestamp = Time.now

      if parse(redcode, settings, logger)
        logger.puts "Redcode file #{file_name} loaded"
        return true
      end

      false
    end

    def reload(settings, logger)
      return unless @file_name

      begin
        modification_time = File.mtime(@file_name)
      rescue Errno::ENOENT
        logger.puts "File #{@file_name} has disappeared"
        unload_program
        @program = nil
        return false
      end

      return true if @file_name.nil? || @timestamp.nil? || modification_time < @timestamp

      parse_file(@file_name, settings, logger)
    end

    # Notify the warrior that it was reloaded into the core at a new address
    # and with a new pid. Load the task queue with the program start address.
    # @param [Integer] base_address
    # @param [Integer] pid
    def restart(base_address, pid)
      @base_address = base_address
      @pid = pid

      # Load the program start address into the task queue. We always start with
      # a single thread.
      @task_queue = [@program.start_address]

      @hits = 0
      @kills = 0
    end

    # Change the current PC to the new address.
    def goto(address)
      @task_queue[0] = address
    end

    def unload_program
      @base_address = nil
      @pid = nil
      @task_queue = []
    end

    def size
      @program&.size
    end

    # Pull the next PC from the queue and return it.
    def next_task
      @task_queue.shift
    end

    def append_tasks(tasks)
      raise ArgumentError, 'Task list must be an Array' unless tasks.respond_to?(:each)

      tasks.each do |task|
        raise ArgumentError, 'Task list must contain only Interger addresses' unless task.is_a?(Integer)
      end

      if @task_queue.length > @max_tasks - 2
        # If the task queue is already full, we only append the current
        # thread again. The new thread is ignored.
        @task_queue.push(tasks.first)
      else
        @task_queue += tasks
      end
    end

    # A warrior is considered alive as long as its task queue is not empty.
    def alive?
      !@task_queue.empty?
    end

    def resolve_address(address)
      @program&.resolve_address(address - @base_address) || ''
    end

    def score
      # We'll have to figure out what the right balance is. Kills are much
      # harder to get, so we weight them stronger.
      (@kills * 20) + @hits
    end
  end
end
