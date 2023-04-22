# frozen_string_literal: true

require 'optparse'

require_relative 'version'
require_relative 'settings'

module RuMARS
  class CommandlineArgumentsParser
    def initialize(settings)
      @settings = settings
      declare_options
    end

    def parse(argv)
      @parser.parse(argv)
    end

    private

    def declare_options
      @parser = OptionParser.new do |p|
        p.banner = <<~"BANNER"
          Ruby Memory Array Simulator RuMARS #{VERSION}
          Copyright (c) 2023 Chris Schlaeger

          Usage: rumars [options]

        BANNER

        p.on('--coresize N', '-s N', Integer, "Size of core [#{@settings[:core_size]}]") do |int|
          @settings[:core_size] = int
        end

        p.on('--maxcycles N', '-c N', Integer, "Cycles until tie [#{@settings[:max_cycles]}]") do |int|
          @settings[:max_cycles] = int
        end

        p.on('--maxprocesses N', '-p N', Integer, "Max. processes [#{@settings[:max_processes]}]") do |int|
          @settings[:max_processes] = int
        end

        p.on('--maxlength N', '-l N', Integer, "Max. warrior length [#{@settings[:max_length]}]") do |int|
          @settings[:max_length] = int
        end

        p.on('--mindistance N', '-d', Integer, "Min. warriors distance [#{@settings[:min_distance]}]") do |int|
          @settings[:min_distance] = int
        end

        p.on('--rounds N', '-r', Integer, "Rounds to play [#{@settings[:rounds]}]") do |int|
          @settings[:rounds] = int
        end

        p.on('--readlimit N', '-d', Integer, "Max. distance for reads [#{@settings[:read_limit]}]") do |int|
          @settings[:read_limit] = int
        end

        p.on('--writelimit N', '-d', Integer, "Max. distance for writes [#{@settings[:write_limit]}]") do |int|
          @settings[:write_limit] = int
        end

        p.on('-h', '--help', 'Print this help') do
          puts p
          exit
        end
      end
    end
  end
end
