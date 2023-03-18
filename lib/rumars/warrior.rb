# frozen_string_literal: true

require_relative 'parser'

module RuMARS
  # This class handles a MARS program, called a warrior. Inside of MARS
  # programs fight against each other by trying to destroy the other
  # programs.
  class Warrior
    attr_reader :task_queue
    attr_accessor :pid

    def initialize(name)
      @task_queue = [0]
      @name = name
      @program = nil
      @pid = nil
    end

    def start_address=(address)
      @task_queue = [address]
    end

    def parse(program)
      @program = Parser.new.parse(program)
    end

    def parse_file(file_name)
      begin
        file = File.read(file_name)
      rescue IOError
        puts "Cannot open file #{file_name}"
        return false
      end

      begin
        parse(file)
        puts "File #{file_name} loaded"
      rescue Parser::ParseError => e
        puts e
        return false
      end

      true
    end

    def load_program(start_address, memory_core)
      raise 'No program available for loading' unless @program

      @program.load(start_address, memory_core, @pid)
    end

    # Pull the next PC from the queue and return it.
    def next_task
      @task_queue.shift
    end

    def append_tasks(tasks)
      @task_queue += tasks
    end

    # A warrior is considered alive as long as its task queue is not empty.
    def alive?
      !@task_queue.empty?
    end
  end
end
