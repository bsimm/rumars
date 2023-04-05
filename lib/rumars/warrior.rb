# frozen_string_literal: true

require_relative 'parser'

module RuMARS
  # This class handles a MARS program, called a warrior. Inside of MARS
  # programs fight against each other by trying to destroy the other
  # programs.
  class Warrior
    attr_reader :task_queue, :base_address, :name, :program, :pid
    attr_accessor :max_tasks, :file_name

    def initialize(name)
      @task_queue = []
      @max_tasks = 800
      @name = name
      @file_name = nil
      @program = nil
      @base_address = nil
      @pid = nil
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
        return false
      end

      @name = @program.name unless @program.name.empty?

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

      if parse(redcode, settings, logger)
        logger.puts "Redcode file #{file_name} loaded"
        return true
      end

      false
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
      @program.resolve_address(address - @base_address) || ''
    end
  end
end
